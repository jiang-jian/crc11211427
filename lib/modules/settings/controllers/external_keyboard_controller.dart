import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../core/utils/debug_log.dart';

/// 外置键盘控制器
/// 管理 USB 键盘的检测、连接、权限和输入捕获
class ExternalKeyboardController extends GetxController {
  static const String debugTag = 'external_keyboard';
  
  // MethodChannel 和 EventChannel
  static const MethodChannel _methodChannel = 
      MethodChannel('com.holox.ailand_pos/usb_keyboard');
  static const EventChannel _eventChannel = 
      EventChannel('com.holox.ailand_pos/usb_keyboard_events');
  
  // 设备信息
  final isConnected = false.obs;
  final deviceName = ''.obs;
  final vendorId = 0.obs;
  final productId = 0.obs;
  final productName = '未检测到设备'.obs;
  final manufacturerName = ''.obs;
  final deviceType = '未知类型'.obs;
  final hasPermission = false.obs;  // 新增：权限状态
  
  // 输入状态
  final currentInput = ''.obs;
  final testOutput = ''.obs;
  final isTestSuccess = false.obs;
  final isFocused = false.obs;
  
  // 历史记录
  final inputHistory = <Map<String, dynamic>>[].obs;
  
  @override
  void onInit() {
    super.onInit();
    DebugLog.log(debugTag, '控制器初始化');
    
    // 启动键盘事件监听
    _startListening();
    
    // 自动检测设备
    detectKeyboard();
  }
  
  @override
  void onClose() async {
    DebugLog.log(debugTag, '控制器关闭');
    super.onClose();
  }
  
  /// 启动键盘事件监听
  void _startListening() {
    _eventChannel.receiveBroadcastStream().listen(
      (dynamic event) {
        _handleKeyboardEvent(event);
      },
      onError: (dynamic error) {
        DebugLog.log(debugTag, '事件监听错误: $error', LogLevel.error);
      },
    );
    
    DebugLog.log(debugTag, '✓ 键盘事件监听已启动');
  }
  
  /// 处理键盘事件
  void _handleKeyboardEvent(dynamic event) {
    if (event is! Map) return;
    
    final type = event['type'] as String?;
    
    if (type == 'key_press') {
      // 实时按键事件
      final char = event['char'] as String? ?? '';
      final isDelete = event['isDelete'] as bool? ?? false;
      
      if (isDelete) {
        // 删除字符
        if (currentInput.value.isNotEmpty) {
          currentInput.value = 
              currentInput.value.substring(0, currentInput.value.length - 1);
        }
      } else if (char.isNotEmpty) {
        // 添加字符
        currentInput.value += char;
      }
      
      DebugLog.log(debugTag, '按键输入: $char (删除: $isDelete)');
      
    } else if (type == 'input_complete') {
      // 输入完成事件（按下回车）
      final data = event['data'] as String? ?? '';
      final timestamp = event['timestamp'] as int? ?? 0;
      
      if (data.isNotEmpty) {
        DebugLog.log(debugTag, '✓ 输入完成: $data');
        
        // 记录到历史
        inputHistory.insert(0, {
          'data': data,
          'timestamp': DateTime.fromMillisecondsSinceEpoch(timestamp),
          'length': data.length,
        });
        
        // 限制历史记录数量
        if (inputHistory.length > 50) {
          inputHistory.removeLast();
        }
      }
    } else if (type == 'device_attached') {
      // 设备插入事件
      final deviceName = event['deviceName'] as String? ?? '';
      final productName = event['productName'] as String? ?? '未知设备';
      final deviceType = event['deviceType'] as String? ?? '未知类型';
      
      DebugLog.log(debugTag, '✓ 设备已插入: $productName ($deviceType)');
      
      Get.snackbar(
        '设备已插入',
        '$productName - $deviceType',
        snackPosition: SnackPosition.TOP,
        duration: const Duration(seconds: 3),
      );
      
      // 自动检测设备信息
      detectKeyboard();
      
    } else if (type == 'device_detached') {
      // 设备拔出事件
      final productName = event['productName'] as String? ?? '未知设备';
      
      DebugLog.log(debugTag, '✗ 设备已拔出: $productName', LogLevel.warning);
      
      Get.snackbar(
        '设备已拔出',
        productName,
        snackPosition: SnackPosition.TOP,
        duration: const Duration(seconds: 3),
      );
      
      // 重置设备信息
      _resetDeviceInfo();
      
    } else if (type == 'permission_result') {
      // 权限授予结果
      final granted = event['granted'] as bool? ?? false;
      final message = event['message'] as String? ?? '';
      
      if (granted) {
        DebugLog.log(debugTag, '✓ 权限已授予');
        hasPermission.value = true;
        
        Get.snackbar(
          '授权成功',
          message,
          snackPosition: SnackPosition.TOP,
          backgroundColor: Get.theme.colorScheme.primaryContainer,
          duration: const Duration(seconds: 2),
        );
        
        // 重新检测设备信息
        detectKeyboard();
      } else {
        DebugLog.log(debugTag, '✗ 权限被拒绝', LogLevel.warning);
        hasPermission.value = false;
        
        Get.snackbar(
          '授权失败',
          message,
          snackPosition: SnackPosition.TOP,
          duration: const Duration(seconds: 2),
        );
      }
    }
  }
  
  /// 检测键盘设备
  Future<void> detectKeyboard() async {
    try {
      DebugLog.log(debugTag, '开始检测键盘设备...');
      
      final result = await _methodChannel.invokeMethod('getKeyboardInfo');
      
      if (result is Map) {
        final connected = result['connected'] as bool? ?? false;
        isConnected.value = connected;
        
        if (connected) {
          deviceName.value = result['deviceName'] as String? ?? '';
          vendorId.value = result['vendorId'] as int? ?? 0;
          productId.value = result['productId'] as int? ?? 0;
          productName.value = result['productName'] as String? ?? '未知设备';
          manufacturerName.value = result['manufacturerName'] as String? ?? '未知厂商';
          deviceType.value = result['deviceType'] as String? ?? '未知类型';
          hasPermission.value = result['hasPermission'] as bool? ?? false;
          
          DebugLog.log(debugTag, '✓ 检测到键盘: ${productName.value} ($deviceType)');
          DebugLog.log(debugTag, '  权限状态: ${hasPermission.value ? "已授权" : "未授权"}');
          
          Get.snackbar(
            '设备已连接',
            '${productName.value} - $deviceType',
            snackPosition: SnackPosition.TOP,
            duration: const Duration(seconds: 2),
          );
        } else {
          _resetDeviceInfo();
          final message = result['message'] as String? ?? '未检测到设备';
          DebugLog.log(debugTag, '✗ $message', LogLevel.warning);
          
          Get.snackbar(
            '未检测到设备',
            message,
            snackPosition: SnackPosition.TOP,
            duration: const Duration(seconds: 2),
          );
        }
      }
    } catch (e) {
      DebugLog.log(debugTag, '检测失败: $e', LogLevel.error);
      _resetDeviceInfo();
      
      Get.snackbar(
        '检测失败',
        '无法检测键盘设备: $e',
        snackPosition: SnackPosition.TOP,
        duration: const Duration(seconds: 2),
      );
    }
  }
  
  /// 请求 USB 权限
  Future<void> requestPermission() async {
    if (deviceName.value.isEmpty) {
      Get.snackbar(
        '提示',
        '未检测到设备，无法请求权限',
        snackPosition: SnackPosition.TOP,
        duration: const Duration(seconds: 2),
      );
      return;
    }
    
    try {
      DebugLog.log(debugTag, '请求 USB 权限: ${deviceName.value}');
      
      final result = await _methodChannel.invokeMethod('requestPermission', {
        'deviceName': deviceName.value,
      });
      
      if (result is Map) {
        final granted = result['granted'] as bool? ?? false;
        final message = result['message'] as String? ?? '';
        
        if (granted) {
          // 已有权限
          hasPermission.value = true;
          DebugLog.log(debugTag, '✓ $message');
          
          Get.snackbar(
            '提示',
            message,
            snackPosition: SnackPosition.TOP,
            duration: const Duration(seconds: 2),
          );
        } else {
          // 权限请求已发送，等待用户响应
          DebugLog.log(debugTag, '⏳ $message');
          
          Get.snackbar(
            '请求授权',
            '请在系统弹窗中授予 USB 权限',
            snackPosition: SnackPosition.TOP,
            duration: const Duration(seconds: 3),
          );
        }
      }
    } catch (e) {
      DebugLog.log(debugTag, '请求权限失败: $e', LogLevel.error);
      
      Get.snackbar(
        '请求失败',
        '无法请求 USB 权限: $e',
        snackPosition: SnackPosition.TOP,
        duration: const Duration(seconds: 2),
      );
    }
  }
  
  /// 获取所有键盘设备列表
  Future<List<Map<String, dynamic>>> getDeviceList() async {
    try {
      final result = await _methodChannel.invokeMethod('getDeviceList');
      
      if (result is List) {
        return result.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      DebugLog.log(debugTag, '获取设备列表失败: $e', LogLevel.error);
      return [];
    }
  }
  
  /// 测试输出
  Future<void> testOutput() async {
    if (currentInput.value.isEmpty) {
      Get.snackbar(
        '提示',
        '请先输入内容',
        snackPosition: SnackPosition.TOP,
        duration: const Duration(seconds: 2),
      );
      return;
    }
    
    // 设置输出内容
    testOutput.value = currentInput.value;
    
    // 显示成功动画
    isTestSuccess.value = true;
    DebugLog.log(debugTag, '✓ 测试输出: ${currentInput.value}');
    
    // 清空输入
    currentInput.value = '';
    
    // 2秒后隐藏成功状态
    Future.delayed(const Duration(seconds: 2), () {
      isTestSuccess.value = false;
    });
    
    Get.snackbar(
      '测试成功',
      '数据已成功输出到展示区域',
      snackPosition: SnackPosition.TOP,
      backgroundColor: Get.theme.colorScheme.primaryContainer,
      duration: const Duration(seconds: 2),
    );
  }
  
  /// 清空输入
  void clearInput() {
    currentInput.value = '';
    DebugLog.log(debugTag, '输入已清空');
  }
  
  /// 清空输出
  void clearOutput() {
    testOutput.value = '';
    isTestSuccess.value = false;
    DebugLog.log(debugTag, '输出已清空');
  }
  
  /// 清空历史记录
  void clearHistory() {
    inputHistory.clear();
    DebugLog.log(debugTag, '历史记录已清空');
  }
  
  /// 重置设备信息
  void _resetDeviceInfo() {
    isConnected.value = false;
    deviceName.value = '';
    vendorId.value = 0;
    productId.value = 0;
    productName.value = '未检测到设备';
    manufacturerName.value = '';
    deviceType.value = '未知类型';
    hasPermission.value = false;
  }
  
  /// 设置焦点状态
  void setFocus(bool focused) {
    isFocused.value = focused;
    if (focused) {
      DebugLog.log(debugTag, '输入框已聚焦');
    }
  }
}
