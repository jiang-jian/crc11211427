package com.holox.ailand_pos

import android.hardware.usb.UsbDevice
import android.os.Build
import android.util.Log

/**
 * 统一的 USB 设备分类器
 * 提供一致的设备识别逻辑，避免各 Plugin 识别冲突
 * 
 * 设计原则：
 * 1. 每个设备只能被识别为一种类型
 * 2. 优先级：扫描器 > 键盘 > 打印机 > 读卡器 > 未知
 * 3. 多维特征匹配：厂商 ID + 产品名称 + USB 协议
 */
object DeviceClassifier {
    private const val TAG = "DeviceClassifier"
    
    // USB HID 设备类代码
    private const val USB_CLASS_HID = 3
    private const val USB_SUBCLASS_BOOT = 1
    private const val USB_PROTOCOL_KEYBOARD = 1
    private const val USB_PROTOCOL_MOUSE = 2
    
    /**
     * 设备类型枚举
     */
    enum class DeviceType {
        SCANNER,        // 条码扫描器
        KEYBOARD,       // 键盘（含数字键盘）
        PRINTER,        // 打印机
        CARD_READER,    // 读卡器
        UNKNOWN         // 未知设备
    }
    
    /**
     * 设备分类结果
     */
    data class ClassificationResult(
        val type: DeviceType,
        val confidence: Float,  // 识别置信度 0.0-1.0
        val reason: String      // 识别原因（用于调试）
    )
    
    /**
     * 专业扫描器厂商 ID 列表
     * 这些厂商的设备优先识别为扫描器
     */
    private val PROFESSIONAL_SCANNER_VENDORS = setOf(
        0x05e0,  // Symbol Technologies (Zebra收购)
        0x0c2e,  // Honeywell (霍尼韦尔)
        0x0536,  // Hand Held Products (Honeywell旗下)
        0x1f3a,  // Allwinner Technology (全志科技，部分扫描器使用)
        0x1a86,  // QinHeng Electronics (沁恒电子，CH340芯片 - 得力等使用)
        0x0483,  // STMicroelectronics (意法半导体)
        0x1a40,  // Terminus Technology (泰硕电子，USB Hub常用)
        0x2687,  // Fitbit (某些扫描器使用相同芯片)
        0x05ac   // Apple (部分扫描器兼容)
    )
    
    /**
     * 知名键盘品牌厂商 ID 列表
     */
    private val KNOWN_KEYBOARD_VENDORS = setOf(
        0x046d,  // Logitech (罗技)
        0x045e,  // Microsoft (微软)
        0x04d9,  // Holtek (合泰 - 常见廉价键盘)
        0x1ea7,  // RAPOO (雷柏)
        0x258a,  // SINO WEALTH (中颖电子 - 国产键盘常用)
        0x3151   // ZIYOU LANG (自由狼 - 数字键盘)
    )
    
    /**
     * 主分类方法 - 对 USB 设备进行分类
     */
    fun classify(device: UsbDevice): ClassificationResult {
        val productName = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            device.productName?.lowercase() ?: ""
        } else {
            ""
        }
        
        val vendorId = device.vendorId
        
        // 详细日志：显示设备信息
        Log.d(TAG, "========================================")
        Log.d(TAG, "Classifying USB Device:")
        Log.d(TAG, "  Device Name: ${device.deviceName}")
        Log.d(TAG, "  Vendor ID: 0x${vendorId.toString(16).padStart(4, '0')}")
        Log.d(TAG, "  Product ID: 0x${device.productId.toString(16).padStart(4, '0')}")
        Log.d(TAG, "  Product Name: ${device.productName ?: "(null)"}")
        Log.d(TAG, "  Product Name (lowercase): '$productName'")
        Log.d(TAG, "  Manufacturer: ${device.manufacturerName ?: "(null)"}")
        Log.d(TAG, "  Interface Count: ${device.interfaceCount}")
        for (i in 0 until device.interfaceCount) {
            val iface = device.getInterface(i)
            Log.d(TAG, "  Interface $i: class=${iface.interfaceClass}, subclass=${iface.interfaceSubclass}, protocol=${iface.interfaceProtocol}")
        }
        Log.d(TAG, "========================================")
        
        // 第一优先级：专业扫描器识别（最高优先级）
        if (vendorId in PROFESSIONAL_SCANNER_VENDORS) {
            Log.d(TAG, "Device ${device.deviceName} classified as SCANNER (professional vendor: 0x${vendorId.toString(16)})")
            return ClassificationResult(
                type = DeviceType.SCANNER,
                confidence = 0.95f,
                reason = "Professional scanner vendor ID: 0x${vendorId.toString(16)}"
            )
        }
        
        // 第二优先级：通过产品名称识别扫描器
        val scannerKeywords = listOf(
            "scanner", "barcode", "qr", "reader",  // 英文关键词
            "deli", "得力",                           // 得力品牌
            "newland", "新大陆",                      // 新大陆品牌
            "mindeo", "民德"                         // 民德品牌
        )
        
        if (scannerKeywords.any { productName.contains(it) }) {
            Log.d(TAG, "Device ${device.deviceName} classified as SCANNER (product name: $productName)")
            return ClassificationResult(
                type = DeviceType.SCANNER,
                confidence = 0.9f,
                reason = "Product name contains scanner keyword: $productName"
            )
        }
        
        // 第三优先级：知名键盘品牌
        if (vendorId in KNOWN_KEYBOARD_VENDORS) {
            Log.d(TAG, "Device ${device.deviceName} classified as KEYBOARD (known vendor: 0x${vendorId.toString(16)})")
            return ClassificationResult(
                type = DeviceType.KEYBOARD,
                confidence = 0.9f,
                reason = "Known keyboard vendor ID: 0x${vendorId.toString(16)}"
            )
        }
        
        // 第四优先级：通过产品名称识别键盘
        val keyboardKeywords = listOf(
            "keyboard", "键盘",           // 标准键盘
            "numpad", "numeric",         // 数字键盘英文
            "数字键盘", "小键盘",         // 数字键盘中文
            "keypad", "num pad",         // 其他变体
            "usb keyboard"               // USB键盘通用标识
        )
        
        if (keyboardKeywords.any { productName.contains(it) }) {
            Log.d(TAG, "Device ${device.deviceName} classified as KEYBOARD (product name: $productName)")
            return ClassificationResult(
                type = DeviceType.KEYBOARD,
                confidence = 0.85f,
                reason = "Product name contains keyboard keyword: $productName"
            )
        }
        
        // 第五优先级：通过 USB 协议识别键盘
        // 必须是 HID Boot Keyboard 协议，且没有扫描器特征
        if (hasBootKeyboardProtocol(device)) {
            Log.d(TAG, "Device ${device.deviceName} classified as KEYBOARD (Boot Keyboard protocol)")
            return ClassificationResult(
                type = DeviceType.KEYBOARD,
                confidence = 0.7f,
                reason = "HID Boot Keyboard protocol detected"
            )
        }
        
        // 第六优先级：通用 HID 设备（排除已识别的扫描器）
        // 数字键盘可能不遵循 Boot Keyboard 协议，但仍是 HID 设备
        if (hasHidInterface(device)) {
            Log.d(TAG, "Device ${device.deviceName} classified as KEYBOARD (generic HID device, likely keyboard)")
            return ClassificationResult(
                type = DeviceType.KEYBOARD,
                confidence = 0.6f,
                reason = "Generic HID device, not identified as scanner"
            )
        }
        
        // 未知设备
        Log.d(TAG, "Device ${device.deviceName} classified as UNKNOWN (vendorId: 0x${vendorId.toString(16)}, product: $productName)")
        return ClassificationResult(
            type = DeviceType.UNKNOWN,
            confidence = 0.0f,
            reason = "No matching criteria"
        )
    }
    
    /**
     * 检查设备是否有 Boot Keyboard 协议
     */
    private fun hasBootKeyboardProtocol(device: UsbDevice): Boolean {
        for (i in 0 until device.interfaceCount) {
            val usbInterface = device.getInterface(i)
            
            // 只检查键盘协议，不包含鼠标
            if (usbInterface.interfaceClass == USB_CLASS_HID &&
                usbInterface.interfaceSubclass == USB_SUBCLASS_BOOT &&
                usbInterface.interfaceProtocol == USB_PROTOCOL_KEYBOARD) {
                return true
            }
        }
        return false
    }
    
    /**
     * 检查设备是否有 HID 接口（通用检测）
     * 用于识别不遵循 Boot Keyboard 协议的数字键盘等设备
     */
    private fun hasHidInterface(device: UsbDevice): Boolean {
        for (i in 0 until device.interfaceCount) {
            val usbInterface = device.getInterface(i)
            
            // 检查是否为 HID 设备类
            if (usbInterface.interfaceClass == USB_CLASS_HID) {
                return true
            }
        }
        return false
    }
    
    /**
     * 便捷方法：判断是否为扫描器
     */
    fun isScanner(device: UsbDevice): Boolean {
        return classify(device).type == DeviceType.SCANNER
    }
    
    /**
     * 便捷方法：判断是否为键盘
     */
    fun isKeyboard(device: UsbDevice): Boolean {
        return classify(device).type == DeviceType.KEYBOARD
    }
    
    /**
     * 便捷方法：判断是否为打印机
     */
    fun isPrinter(device: UsbDevice): Boolean {
        return classify(device).type == DeviceType.PRINTER
    }
    
    /**
     * 便捷方法：判断是否为读卡器
     */
    fun isCardReader(device: UsbDevice): Boolean {
        return classify(device).type == DeviceType.CARD_READER
    }
    
    /**
     * 获取设备类型的可读名称
     */
    fun getTypeName(type: DeviceType): String {
        return when (type) {
            DeviceType.SCANNER -> "扫描器"
            DeviceType.KEYBOARD -> "键盘"
            DeviceType.PRINTER -> "打印机"
            DeviceType.CARD_READER -> "读卡器"
            DeviceType.UNKNOWN -> "未知设备"
        }
    }
}
