package com.holox.ailand_pos

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.hardware.usb.UsbDevice
import android.hardware.usb.UsbManager
import android.os.Build
import android.view.KeyEvent
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/**
 * USB 键盘插件
 * 功能:
 * 1. 检测 USB HID 键盘设备插拔
 * 2. 请求和管理 USB 权限
 * 3. 捕获键盘输入事件
 * 4. 通过 EventChannel 将输入传递给 Flutter
 * 
 * 支持:
 * - 标准全键盘
 * - 数字小键盘
 */
class UsbKeyboardPlugin : FlutterPlugin, MethodCallHandler {
    private lateinit var methodChannel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private lateinit var context: Context
    private var eventSink: EventChannel.EventSink? = null
    private var usbManager: UsbManager? = null
    
    // 键盘输入缓冲区
    private val inputBuffer = StringBuilder()
    private var lastKeyTime = 0L
    private val KEY_TIMEOUT = 100L // 100ms 超时，认为输入完成
    
    companion object {
        private const val METHOD_CHANNEL_NAME = "com.holox.ailand_pos/usb_keyboard"
        private const val EVENT_CHANNEL_NAME = "com.holox.ailand_pos/usb_keyboard_events"
        private const val ACTION_USB_PERMISSION = "com.holox.ailand_pos.USB_KEYBOARD_PERMISSION"
        
        // HID 键盘的接口类型标识
        private const val USB_CLASS_HID = 3
        private const val USB_SUBCLASS_BOOT = 1
        private const val USB_PROTOCOL_KEYBOARD = 1
        private const val USB_PROTOCOL_NUMPAD = 2
    }
    
    // USB 广播接收器
    private val usbReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            when (intent.action) {
                // USB 设备插入
                UsbManager.ACTION_USB_DEVICE_ATTACHED -> {
                    val device: UsbDevice? = intent.getParcelableExtra(UsbManager.EXTRA_DEVICE)
                    device?.let {
                        if (isKeyboardDevice(it)) {
                            sendDeviceEvent("device_attached", it)
                        }
                    }
                }
                // USB 设备拔出
                UsbManager.ACTION_USB_DEVICE_DETACHED -> {
                    val device: UsbDevice? = intent.getParcelableExtra(UsbManager.EXTRA_DEVICE)
                    device?.let {
                        if (isKeyboardDevice(it)) {
                            sendDeviceEvent("device_detached", it)
                        }
                    }
                }
                // USB 权限响应
                ACTION_USB_PERMISSION -> {
                    synchronized(this) {
                        val device: UsbDevice? = intent.getParcelableExtra(UsbManager.EXTRA_DEVICE)
                        if (intent.getBooleanExtra(UsbManager.EXTRA_PERMISSION_GRANTED, false)) {
                            device?.let {
                                sendPermissionEvent(true, it)
                            }
                        } else {
                            sendPermissionEvent(false, device)
                        }
                    }
                }
            }
        }
    }
    
    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        
        // 设置 MethodChannel
        methodChannel = MethodChannel(binding.binaryMessenger, METHOD_CHANNEL_NAME)
        methodChannel.setMethodCallHandler(this)
        
        // 设置 EventChannel
        eventChannel = EventChannel(binding.binaryMessenger, EVENT_CHANNEL_NAME)
        eventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                eventSink = events
            }
            
            override fun onCancel(arguments: Any?) {
                eventSink = null
            }
        })
        
        usbManager = context.getSystemService(Context.USB_SERVICE) as UsbManager
        
        // 注册 USB 广播接收器
        registerUsbReceiver()
    }
    
    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel.setMethodCallHandler(null)
        eventSink = null
        
        // 注销广播接收器
        try {
            context.unregisterReceiver(usbReceiver)
        } catch (e: Exception) {
            // 忽略未注册的异常
        }
    }
    
    /**
     * 注册 USB 广播接收器
     */
    private fun registerUsbReceiver() {
        val filter = IntentFilter().apply {
            addAction(UsbManager.ACTION_USB_DEVICE_ATTACHED)
            addAction(UsbManager.ACTION_USB_DEVICE_DETACHED)
            addAction(ACTION_USB_PERMISSION)
        }
        context.registerReceiver(usbReceiver, filter)
    }
    
    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "getDeviceList" -> getDeviceList(result)
            "getKeyboardInfo" -> getKeyboardInfo(result)
            "requestPermission" -> requestPermission(call, result)
            "hasPermission" -> hasPermission(call, result)
            else -> result.notImplemented()
        }
    }
    
    /**
     * 获取所有 USB 键盘设备列表
     */
    private fun getDeviceList(result: Result) {
        try {
            val deviceList = usbManager?.deviceList ?: emptyMap()
            val keyboardDevices = deviceList.values.filter { device ->
                isKeyboardDevice(device)
            }.map { device ->
                mapOf(
                    "deviceName" to device.deviceName,
                    "vendorId" to device.vendorId,
                    "productId" to device.productId,
                    "deviceId" to device.deviceId,
                    "productName" to (device.productName ?: "Unknown"),
                    "manufacturerName" to (device.manufacturerName ?: "Unknown"),
                    "deviceType" to getKeyboardType(device),
                    "hasPermission" to (usbManager?.hasPermission(device) ?: false)
                )
            }
            
            result.success(keyboardDevices)
        } catch (e: Exception) {
            result.error("DEVICE_LIST_ERROR", "Failed to get device list: ${e.message}", null)
        }
    }
    
    /**
     * 获取当前连接的键盘信息
     */
    private fun getKeyboardInfo(result: Result) {
        try {
            val deviceList = usbManager?.deviceList ?: emptyMap()
            val keyboards = deviceList.values.filter { isKeyboardDevice(it) }
            
            if (keyboards.isEmpty()) {
                result.success(mapOf(
                    "connected" to false,
                    "message" to "未检测到 USB 键盘设备"
                ))
                return
            }
            
            // 返回第一个检测到的键盘设备信息
            val keyboard = keyboards.first()
            val hasPermission = usbManager?.hasPermission(keyboard) ?: false
            
            result.success(mapOf(
                "connected" to true,
                "deviceName" to keyboard.deviceName,
                "vendorId" to keyboard.vendorId,
                "productId" to keyboard.productId,
                "productName" to (keyboard.productName ?: "Unknown Keyboard"),
                "manufacturerName" to (keyboard.manufacturerName ?: "Unknown"),
                "deviceType" to getKeyboardType(keyboard),
                "interfaceCount" to keyboard.interfaceCount,
                "hasPermission" to hasPermission
            ))
        } catch (e: Exception) {
            result.error("KEYBOARD_INFO_ERROR", "Failed to get keyboard info: ${e.message}", null)
        }
    }
    
    /**
     * 请求 USB 设备权限
     */
    private fun requestPermission(call: MethodCall, result: Result) {
        try {
            val deviceName = call.argument<String>("deviceName")
            if (deviceName == null) {
                result.error("INVALID_ARGUMENT", "deviceName is required", null)
                return
            }
            
            val deviceList = usbManager?.deviceList ?: emptyMap()
            val device = deviceList.values.find { it.deviceName == deviceName }
            
            if (device == null) {
                result.error("DEVICE_NOT_FOUND", "Device not found: $deviceName", null)
                return
            }
            
            // 检查是否已有权限
            if (usbManager?.hasPermission(device) == true) {
                result.success(mapOf(
                    "granted" to true,
                    "message" to "已有权限"
                ))
                return
            }
            
            // 请求权限
            val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                PendingIntent.FLAG_MUTABLE
            } else {
                0
            }
            
            val permissionIntent = PendingIntent.getBroadcast(
                context,
                0,
                Intent(ACTION_USB_PERMISSION),
                flags
            )
            
            usbManager?.requestPermission(device, permissionIntent)
            
            result.success(mapOf(
                "granted" to false,
                "message" to "权限请求已发送"
            ))
            
        } catch (e: Exception) {
            result.error("REQUEST_PERMISSION_ERROR", "Failed to request permission: ${e.message}", null)
        }
    }
    
    /**
     * 检查是否有权限
     */
    private fun hasPermission(call: MethodCall, result: Result) {
        try {
            val deviceName = call.argument<String>("deviceName")
            if (deviceName == null) {
                result.error("INVALID_ARGUMENT", "deviceName is required", null)
                return
            }
            
            val deviceList = usbManager?.deviceList ?: emptyMap()
            val device = deviceList.values.find { it.deviceName == deviceName }
            
            if (device == null) {
                result.success(false)
                return
            }
            
            val hasPermission = usbManager?.hasPermission(device) ?: false
            result.success(hasPermission)
            
        } catch (e: Exception) {
            result.error("CHECK_PERMISSION_ERROR", "Failed to check permission: ${e.message}", null)
        }
    }
    
    /**
     * 判断是否为键盘设备
     * 检查 USB 接口的类、子类和协议
     */
    private fun isKeyboardDevice(device: UsbDevice): Boolean {
        for (i in 0 until device.interfaceCount) {
            val usbInterface = device.getInterface(i)
            
            // 检查是否为 HID 键盘
            if (usbInterface.interfaceClass == USB_CLASS_HID &&
                usbInterface.interfaceSubclass == USB_SUBCLASS_BOOT &&
                (usbInterface.interfaceProtocol == USB_PROTOCOL_KEYBOARD ||
                 usbInterface.interfaceProtocol == USB_PROTOCOL_NUMPAD)) {
                return true
            }
        }
        return false
    }
    
    /**
     * 获取键盘类型
     */
    private fun getKeyboardType(device: UsbDevice): String {
        for (i in 0 until device.interfaceCount) {
            val usbInterface = device.getInterface(i)
            
            if (usbInterface.interfaceClass == USB_CLASS_HID &&
                usbInterface.interfaceSubclass == USB_SUBCLASS_BOOT) {
                return when (usbInterface.interfaceProtocol) {
                    USB_PROTOCOL_KEYBOARD -> "标准键盘"
                    USB_PROTOCOL_NUMPAD -> "数字键盘"
                    else -> "未知类型"
                }
            }
        }
        return "未知类型"
    }
    
    /**
     * 处理键盘按键事件
     * 从 MainActivity.dispatchKeyEvent() 调用
     */
    fun handleKeyEvent(event: KeyEvent): Boolean {
        // 只处理按下事件
        if (event.action != KeyEvent.ACTION_DOWN) {
            return false
        }
        
        val currentTime = System.currentTimeMillis()
        
        // 检查是否超时（新的输入序列）
        if (currentTime - lastKeyTime > KEY_TIMEOUT && inputBuffer.isNotEmpty()) {
            flushInput()
        }
        
        lastKeyTime = currentTime
        
        // 获取按键字符
        val unicodeChar = event.unicodeChar
        if (unicodeChar != 0) {
            val char = unicodeChar.toChar()
            
            // Enter 键 - 发送当前缓冲区内容
            if (char == '\n' || char == '\r') {
                flushInput()
                return true
            }
            
            // 其他字符 - 添加到缓冲区
            inputBuffer.append(char)
            
            // 实时发送单个字符事件（用于实时显示）
            sendKeyEvent(char.toString(), false)
            
            return true
        }
        
        // 处理特殊键
        when (event.keyCode) {
            KeyEvent.KEYCODE_DEL -> {
                if (inputBuffer.isNotEmpty()) {
                    inputBuffer.deleteCharAt(inputBuffer.length - 1)
                    sendKeyEvent("", true) // 发送删除事件
                }
                return true
            }
            KeyEvent.KEYCODE_ENTER, KeyEvent.KEYCODE_NUMPAD_ENTER -> {
                flushInput()
                return true
            }
        }
        
        return false
    }
    
    /**
     * 发送输入完成事件
     */
    private fun flushInput() {
        if (inputBuffer.isEmpty()) return
        
        val input = inputBuffer.toString()
        inputBuffer.clear()
        
        sendCompleteEvent(input)
    }
    
    /**
     * 发送单个按键事件（实时显示）
     */
    private fun sendKeyEvent(char: String, isDelete: Boolean) {
        eventSink?.success(mapOf(
            "type" to "key_press",
            "char" to char,
            "isDelete" to isDelete,
            "timestamp" to System.currentTimeMillis()
        ))
    }
    
    /**
     * 发送输入完成事件
     */
    private fun sendCompleteEvent(input: String) {
        eventSink?.success(mapOf(
            "type" to "input_complete",
            "data" to input,
            "length" to input.length,
            "timestamp" to System.currentTimeMillis()
        ))
    }
    
    /**
     * 发送设备事件（插拔）
     */
    private fun sendDeviceEvent(eventType: String, device: UsbDevice) {
        eventSink?.success(mapOf(
            "type" to eventType,
            "deviceName" to device.deviceName,
            "vendorId" to device.vendorId,
            "productId" to device.productId,
            "productName" to (device.productName ?: "Unknown"),
            "deviceType" to getKeyboardType(device),
            "timestamp" to System.currentTimeMillis()
        ))
    }
    
    /**
     * 发送权限事件
     */
    private fun sendPermissionEvent(granted: Boolean, device: UsbDevice?) {
        eventSink?.success(mapOf(
            "type" to "permission_result",
            "granted" to granted,
            "deviceName" to (device?.deviceName ?: ""),
            "message" to if (granted) "权限已授予" else "权限被拒绝",
            "timestamp" to System.currentTimeMillis()
        ))
    }
}
