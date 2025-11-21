package com.holox.ailand_pos

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import android.os.Bundle
import android.view.WindowManager
import android.view.KeyEvent
import android.view.InputDevice
import android.hardware.usb.UsbManager
import android.hardware.usb.UsbDevice
import android.content.Context
import android.util.Log
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var barcodeScannerPlugin: BarcodeScannerPlugin? = null
    private var usbKeyboardPlugin: UsbKeyboardPlugin? = null
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // 设置窗口为全屏模式（隐藏状态栏和导航栏）
        window.setFlags(
            WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS
        )
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // 注册 Sunmi Customer API Plugin（内置打印机）
        flutterEngine.plugins.add(SunmiCustomerApiPlugin())
        
        // 注册 External Printer Plugin（外接USB打印机）
        flutterEngine.plugins.add(ExternalPrinterPlugin())
        
        // 注册 External Card Reader Plugin（外接USB读卡器）
        flutterEngine.plugins.add(ExternalCardReaderPlugin())
        
        // 注册 MW Card Reader Plugin（MW读卡器）
        flutterEngine.plugins.add(MwCardReaderPlugin())
        
        // 注册 Barcode Scanner Plugin（USB条码扫描器）
        barcodeScannerPlugin = BarcodeScannerPlugin()
        flutterEngine.plugins.add(barcodeScannerPlugin!!)
        
        // 注册 USB Keyboard Plugin（USB键盘）
        usbKeyboardPlugin = UsbKeyboardPlugin()
        flutterEngine.plugins.add(usbKeyboardPlugin!!)
    }
    
    /**
     * 拦截系统键盘事件，根据设备来源转发给对应插件
     * 
     * 新逻辑（设备隔离）：
     * - 扫描器设备 → 只转发给扫描器插件
     * - 键盘设备 → 只转发给键盘插件
     * - 未知设备 → 不转发（严格隔离模式）
     */
    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        // 获取输入设备信息
        val inputDevice = event.device
        if (inputDevice == null) {
            // 无法获取设备信息，交给系统处理
            Log.w("MainActivity", "Cannot get input device for key event, using default handler")
            return super.dispatchKeyEvent(event)
        }
        
        // 通过设备描述符查找对应的 USB 设备
        val usbDevice = findUsbDeviceByInputDevice(inputDevice)
        if (usbDevice == null) {
            // 不是 USB 设备（可能是虚拟键盘或内置键盘），交给系统处理
            return super.dispatchKeyEvent(event)
        }
        
        // 使用统一的设备分类器判断设备类型
        val classification = DeviceClassifier.classify(usbDevice)
        
        Log.d("MainActivity", "Key event from device: ${inputDevice.name}, " +
              "type: ${classification.type}, confidence: ${classification.confidence}, " +
              "reason: ${classification.reason}")
        
        // 根据设备类型路由到对应插件
        return when (classification.type) {
            DeviceClassifier.DeviceType.KEYBOARD -> {
                // 键盘设备 → 只转发给键盘插件
                usbKeyboardPlugin?.let { plugin ->
                    if (plugin.handleKeyEvent(event)) {
                        Log.d("MainActivity", "Key event handled by keyboard plugin")
                        return true
                    }
                }
                false
            }
            
            DeviceClassifier.DeviceType.SCANNER -> {
                // 扫描器设备 → 只转发给扫描器插件
                barcodeScannerPlugin?.let { plugin ->
                    if (plugin.handleKeyEventDirect(event)) {
                        Log.d("MainActivity", "Key event handled by scanner plugin")
                        return true
                    }
                }
                false
            }
            
            DeviceClassifier.DeviceType.UNKNOWN -> {
                // 未知设备 → 不转发（严格隔离模式）
                Log.w("MainActivity", "Unknown device type, event not forwarded to any plugin")
                super.dispatchKeyEvent(event)
            }
            
            else -> {
                // 其他设备类型（打印机、读卡器等）不处理键盘事件
                super.dispatchKeyEvent(event)
            }
        }
    }
    
    /**
     * 通过 InputDevice 查找对应的 USB 设备
     * 
     * InputDevice 提供设备描述符和名称，但不直接提供 USB VendorID/ProductID
     * 需要通过 UsbManager 匹配设备名称来查找对应的 UsbDevice
     */
    private fun findUsbDeviceByInputDevice(inputDevice: InputDevice): UsbDevice? {
        try {
            val usbManager = getSystemService(Context.USB_SERVICE) as? UsbManager
            if (usbManager == null) {
                Log.e("MainActivity", "Failed to get UsbManager")
                return null
            }
            
            val deviceList = usbManager.deviceList
            val inputDeviceName = inputDevice.name.lowercase()
            
            // 尝试通过设备名称匹配
            // InputDevice.name 格式通常为: "Vendor ProductName"
            // UsbDevice 可通过 productName 获取产品名称
            for ((_, usbDevice) in deviceList) {
                val usbProductName = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.LOLLIPOP) {
                    usbDevice.productName?.lowercase() ?: ""
                } else {
                    ""
                }
                
                // 匹配逻辑：InputDevice 名称包含 USB 产品名称
                if (usbProductName.isNotEmpty() && inputDeviceName.contains(usbProductName)) {
                    Log.d("MainActivity", "Found matching USB device: ${usbDevice.deviceName} " +
                          "(VID: 0x${usbDevice.vendorId.toString(16)}, PID: 0x${usbDevice.productId.toString(16)})")
                    return usbDevice
                }
                
                // 备用匹配：通过 VendorID 和部分名称
                val vendorIdHex = usbDevice.vendorId.toString(16).padStart(4, '0')
                if (inputDeviceName.contains(vendorIdHex)) {
                    Log.d("MainActivity", "Found matching USB device by VID: ${usbDevice.deviceName}")
                    return usbDevice
                }
            }
            
            Log.w("MainActivity", "No matching USB device found for InputDevice: ${inputDevice.name}")
            return null
            
        } catch (e: Exception) {
            Log.e("MainActivity", "Error finding USB device: ${e.message}", e)
            return null
        }
    }
}
