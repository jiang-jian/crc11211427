import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/widgets/debug_log_window.dart';
import '../controllers/external_keyboard_controller.dart';
import 'package:intl/intl.dart';

/// 外置键盘配置界面
class ExternalKeyboardView extends GetView<ExternalKeyboardController> {
  const ExternalKeyboardView({super.key});

  static const String debugTag = 'external_keyboard';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundGrey,
      body: Stack(
        children: [
          Padding(
            padding: EdgeInsets.all(AppTheme.spacingL),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                SizedBox(height: AppTheme.spacingL),
                Expanded(child: _buildMainContent()),
              ],
            ),
          ),
          // 调试日志窗口
          DebugLogWindow(
            tag: debugTag,
            width: 500.w,
            height: 600.h,
            collapsedHeight: 40.h,
          ),
        ],
      ),
    );
  }

  /// 顶部标题栏
  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppTheme.spacingL,
        vertical: AppTheme.spacingDefault,
      ),
      decoration: AppTheme.cardDecoration(),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(AppTheme.spacingM),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withAlpha((0.1 * 255).toInt()),
              borderRadius: BorderRadius.circular(AppTheme.borderRadiusM),
            ),
            child: Icon(Icons.keyboard, size: 32.sp, color: AppTheme.primaryColor),
          ),
          SizedBox(width: AppTheme.spacingM),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '外置键盘配置',
                style: AppTheme.textHeading.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                  fontSize: 20.sp,
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                'USB HID 键盘管理和测试',
                style: AppTheme.textCaption.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
          const Spacer(),
          Obx(
            () => Container(
              padding: EdgeInsets.symmetric(
                horizontal: AppTheme.spacingDefault,
                vertical: AppTheme.spacingS,
              ),
              decoration: BoxDecoration(
                color: controller.isConnected.value
                    ? AppTheme.successColor.withAlpha((0.1 * 255).toInt())
                    : AppTheme.backgroundDisabled,
                borderRadius: BorderRadius.circular(AppTheme.borderRadiusRound),
                border: Border.all(
                  color: controller.isConnected.value
                      ? AppTheme.successColor.withAlpha((0.3 * 255).toInt())
                      : AppTheme.borderColor,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 10.w,
                    height: 10.w,
                    decoration: BoxDecoration(
                      color: controller.isConnected.value
                          ? AppTheme.successColor
                          : AppTheme.textTertiary,
                      shape: BoxShape.circle,
                      boxShadow: controller.isConnected.value
                          ? [
                              BoxShadow(
                                color: AppTheme.successColor.withAlpha((0.5 * 255).toInt()),
                                blurRadius: 4,
                                spreadRadius: 1,
                              )
                            ]
                          : null,
                    ),
                  ),
                  SizedBox(width: AppTheme.spacingS),
                  Text(
                    controller.isConnected.value ? '已连接' : '未连接',
                    style: AppTheme.textBody.copyWith(
                      color: controller.isConnected.value
                          ? AppTheme.successColor
                          : AppTheme.textTertiary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14.sp,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 主内容区域（左右分栏 40:60）
  Widget _buildMainContent() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 左侧：设备信息区 (40%)
        Expanded(
          flex: 4,
          child: _buildLeftSection(),
        ),
        SizedBox(width: AppTheme.spacingL),
        // 右侧：输入测试区 (60%)
        Expanded(
          flex: 6,
          child: _buildRightSection(),
        ),
      ],
    );
  }

  /// 左侧区域：设备信息
  Widget _buildLeftSection() {
    return SingleChildScrollView(
      child: Column(
        children: [
          // 设备信息卡片
          _buildInfoCard(),
          SizedBox(height: AppTheme.spacingDefault),
          // 授权控制卡片
          _buildAuthCard(),
          SizedBox(height: AppTheme.spacingDefault),
          // 使用说明卡片
          _buildGuideCard(),
        ],
      ),
    );
  }

  /// 右侧区域：输入测试
  Widget _buildRightSection() {
    return SingleChildScrollView(
      child: Column(
        children: [
          // 输入测试卡片
          _buildInputTestCard(),
          SizedBox(height: AppTheme.spacingDefault),
          // 输入历史卡片
          _buildHistoryCard(),
        ],
      ),
    );
  }

  /// 设备信息卡片
  Widget _buildInfoCard() {
    return Container(
      padding: EdgeInsets.all(AppTheme.spacingDefault),
      decoration: AppTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, size: 20.sp, color: AppTheme.primaryColor),
              SizedBox(width: AppTheme.spacingS),
              Text(
                '设备信息',
                style: AppTheme.textSubheading.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 16.sp,
                ),
              ),
            ],
          ),
          SizedBox(height: AppTheme.spacingDefault),
          Obx(() => Column(
            children: [
              _buildInfoRow(
                '设备状态',
                controller.isConnected.value ? '已连接' : '未连接',
                valueColor: controller.isConnected.value
                    ? AppTheme.successColor
                    : AppTheme.errorColor,
                icon: controller.isConnected.value ? Icons.check_circle : Icons.cancel,
              ),
              _buildDivider(),
              _buildInfoRow('设备名称', controller.productName.value),
              _buildDivider(),
              _buildInfoRow('设备类型', controller.deviceType.value),
              _buildDivider(),
              _buildInfoRow('制造商', controller.manufacturerName.value),
              if (controller.isConnected.value) ..[
                _buildDivider(),
                _buildInfoRow(
                  'Vendor ID',
                  '0x${controller.vendorId.value.toRadixString(16).toUpperCase()}',
                ),
                _buildDivider(),
                _buildInfoRow(
                  'Product ID',
                  '0x${controller.productId.value.toRadixString(16).toUpperCase()}',
                ),
                _buildDivider(),
                _buildInfoRow(
                  '权限状态',
                  controller.hasPermission.value ? '已授权 ✓' : '未授权',
                  valueColor: controller.hasPermission.value
                      ? AppTheme.successColor
                      : AppTheme.warningColor,
                  icon: controller.hasPermission.value ? Icons.lock_open : Icons.lock,
                ),
              ],
            ],
          )),
        ],
      ),
    );
  }

  /// 授权控制卡片
  Widget _buildAuthCard() {
    return Container(
      padding: EdgeInsets.all(AppTheme.spacingDefault),
      decoration: AppTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.security, size: 20.sp, color: AppTheme.warningColor),
              SizedBox(width: AppTheme.spacingS),
              Text(
                '设备授权',
                style: AppTheme.textSubheading.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 16.sp,
                ),
              ),
            ],
          ),
          SizedBox(height: AppTheme.spacingDefault),
          Obx(() => Column(
            children: [
              // 重新检测按钮
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: controller.detectKeyboard,
                  icon: Icon(Icons.refresh, size: 20.sp),
                  label: Text('重新检测设备'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: AppTheme.spacingDefault),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.borderRadiusS),
                    ),
                    elevation: 2,
                  ),
                ),
              ),
              // 请求授权按钮（仅在已连接且未授权时显示）
              if (controller.isConnected.value && !controller.hasPermission.value) ..[
                SizedBox(height: AppTheme.spacingM),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: controller.requestPermission,
                    icon: Icon(Icons.vpn_key, size: 20.sp),
                    label: Text('请求 USB 授权'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.warningColor,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: AppTheme.spacingDefault),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.borderRadiusS),
                      ),
                      elevation: 2,
                    ),
                  ),
                ),
                SizedBox(height: AppTheme.spacingS),
                Container(
                  padding: EdgeInsets.all(AppTheme.spacingS),
                  decoration: BoxDecoration(
                    color: AppTheme.warningColor.withAlpha((0.1 * 255).toInt()),
                    borderRadius: BorderRadius.circular(AppTheme.borderRadiusXS),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info, size: 16.sp, color: AppTheme.warningColor),
                      SizedBox(width: AppTheme.spacingS),
                      Expanded(
                        child: Text(
                          '点击后会弹出系统授权对话框',
                          style: AppTheme.textCaption.copyWith(
                            color: AppTheme.warningColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          )),
        ],
      ),
    );
  }

  /// 使用说明卡片
  Widget _buildGuideCard() {
    return Container(
      padding: EdgeInsets.all(AppTheme.spacingDefault),
      decoration: AppTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.help_outline, size: 20.sp, color: AppTheme.infoColor),
              SizedBox(width: AppTheme.spacingS),
              Text(
                '使用说明',
                style: AppTheme.textSubheading.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 16.sp,
                ),
              ),
            ],
          ),
          SizedBox(height: AppTheme.spacingDefault),
          _buildGuideStep('1', '插入 USB 键盘到设备'),
          _buildGuideStep('2', '系统自动检测设备'),
          _buildGuideStep('3', '点击「请求授权」按钮'),
          _buildGuideStep('4', '在弹窗中授予 USB 权限'),
          _buildGuideStep('5', '点击右侧输入框聚焦'),
          _buildGuideStep('6', '使用键盘输入测试数据'),
        ],
      ),
    );
  }

  /// 使用说明步骤
  Widget _buildGuideStep(String number, String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: AppTheme.spacingS),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24.w,
            height: 24.w,
            decoration: BoxDecoration(
              color: AppTheme.infoColor.withAlpha((0.1 * 255).toInt()),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              number,
              style: AppTheme.textCaption.copyWith(
                color: AppTheme.infoColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(width: AppTheme.spacingS),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: 2.h),
              child: Text(
                text,
                style: AppTheme.textBody.copyWith(
                  height: 1.5,
                  fontSize: 13.sp,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 输入测试卡片
  Widget _buildInputTestCard() {
    return Container(
      padding: EdgeInsets.all(AppTheme.spacingL),
      decoration: AppTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.keyboard_alt, size: 20.sp, color: AppTheme.successColor),
              SizedBox(width: AppTheme.spacingS),
              Text(
                '键盘输入测试',
                style: AppTheme.textSubheading.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 16.sp,
                ),
              ),
            ],
          ),
          SizedBox(height: AppTheme.spacingDefault),
          Text(
            '点击下方输入框，然后使用外置键盘输入测试数据：',
            style: AppTheme.textBody.copyWith(
              color: AppTheme.textSecondary,
              fontSize: 13.sp,
            ),
          ),
          SizedBox(height: AppTheme.spacingDefault),
          
          // 输入框区域
          Obx(() => GestureDetector(
            onTap: () => controller.setFocus(true),
            child: Container(
              width: double.infinity,
              height: 120.h,
              padding: EdgeInsets.all(AppTheme.spacingDefault),
              decoration: BoxDecoration(
                color: AppTheme.backgroundLight,
                borderRadius: BorderRadius.circular(AppTheme.borderRadiusM),
                border: Border.all(
                  color: controller.isFocused.value
                      ? AppTheme.primaryColor
                      : AppTheme.borderColor,
                  width: controller.isFocused.value ? 2 : 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.edit,
                        size: 16.sp,
                        color: controller.isFocused.value
                            ? AppTheme.primaryColor
                            : AppTheme.textTertiary,
                      ),
                      SizedBox(width: AppTheme.spacingS),
                      Text(
                        '输入区域',
                        style: AppTheme.textCaption.copyWith(
                          color: controller.isFocused.value
                              ? AppTheme.primaryColor
                              : AppTheme.textTertiary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (controller.isFocused.value) ..[
                        SizedBox(width: AppTheme.spacingS),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: AppTheme.spacingS,
                            vertical: 2.h,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withAlpha((0.1 * 255).toInt()),
                            borderRadius: BorderRadius.circular(AppTheme.borderRadiusRound),
                          ),
                          child: Text(
                            '聚焦中',
                            style: AppTheme.textCaption.copyWith(
                              color: AppTheme.primaryColor,
                              fontSize: 11.sp,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  SizedBox(height: AppTheme.spacingM),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Text(
                        controller.currentInput.value.isEmpty
                            ? '等待键盘输入...'
                            : controller.currentInput.value,
                        style: AppTheme.textBody.copyWith(
                          color: controller.currentInput.value.isEmpty
                              ? AppTheme.textTertiary
                              : AppTheme.textPrimary,
                          fontFamily: 'monospace',
                          fontSize: 18.sp,
                          height: 1.6,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )),
          
          SizedBox(height: AppTheme.spacingDefault),
          
          // 操作按钮
          Row(
            children: [
              Expanded(
                flex: 2,
                child: OutlinedButton.icon(
                  onPressed: controller.clearInput,
                  icon: Icon(Icons.clear, size: 18.sp),
                  label: Text('清空输入'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.textSecondary,
                    side: BorderSide(color: AppTheme.borderColor),
                    padding: EdgeInsets.symmetric(vertical: AppTheme.spacingDefault),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.borderRadiusS),
                    ),
                  ),
                ),
              ),
              SizedBox(width: AppTheme.spacingM),
              Expanded(
                flex: 3,
                child: ElevatedButton.icon(
                  onPressed: controller.testOutput,
                  icon: Icon(Icons.send, size: 18.sp),
                  label: Text('测试输出'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.successColor,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: AppTheme.spacingDefault),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.borderRadiusS),
                    ),
                    elevation: 2,
                  ),
                ),
              ),
            ],
          ),
          
          SizedBox(height: AppTheme.spacingL),
          
          // 输出展示区域
          Obx(() => AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: EdgeInsets.all(AppTheme.spacingDefault),
            decoration: BoxDecoration(
              color: controller.isTestSuccess.value
                  ? AppTheme.successColor.withAlpha((0.1 * 255).toInt())
                  : AppTheme.backgroundDisabled,
              borderRadius: BorderRadius.circular(AppTheme.borderRadiusM),
              border: Border.all(
                color: controller.isTestSuccess.value
                    ? AppTheme.successColor
                    : AppTheme.borderColor,
                width: controller.isTestSuccess.value ? 2 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      controller.isTestSuccess.value
                          ? Icons.check_circle
                          : Icons.output,
                      size: 20.sp,
                      color: controller.isTestSuccess.value
                          ? AppTheme.successColor
                          : AppTheme.textTertiary,
                    ),
                    SizedBox(width: AppTheme.spacingS),
                    Text(
                      controller.isTestSuccess.value ? '✓ 测试成功' : '输出展示区域',
                      style: AppTheme.textBody.copyWith(
                        color: controller.isTestSuccess.value
                            ? AppTheme.successColor
                            : AppTheme.textTertiary,
                        fontWeight: controller.isTestSuccess.value
                            ? FontWeight.w600
                            : FontWeight.normal,
                        fontSize: 14.sp,
                      ),
                    ),
                    if (controller.testOutput.value.isNotEmpty) ..[
                      const Spacer(),
                      IconButton(
                        icon: Icon(Icons.clear, size: 18.sp),
                        onPressed: controller.clearOutput,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        color: AppTheme.textSecondary,
                      ),
                    ],
                  ],
                ),
                if (controller.testOutput.value.isNotEmpty) ..[
                  SizedBox(height: AppTheme.spacingM),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(AppTheme.spacingDefault),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppTheme.borderRadiusS),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SelectableText(
                          controller.testOutput.value,
                          style: AppTheme.textBody.copyWith(
                            fontFamily: 'monospace',
                            fontSize: 18.sp,
                            color: AppTheme.textPrimary,
                            height: 1.6,
                          ),
                        ),
                        SizedBox(height: AppTheme.spacingS),
                        Divider(height: 1, color: AppTheme.borderColor),
                        SizedBox(height: AppTheme.spacingS),
                        Row(
                          children: [
                            Icon(Icons.text_fields, size: 14.sp, color: AppTheme.textSecondary),
                            SizedBox(width: 4.w),
                            Text(
                              '长度: ${controller.testOutput.value.length} 字符',
                              style: AppTheme.textCaption.copyWith(
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ] else ..[
                  SizedBox(height: AppTheme.spacingS),
                  Center(
                    child: Text(
                      '点击「测试输出」查看结果',
                      style: AppTheme.textCaption.copyWith(
                        color: AppTheme.textTertiary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          )),
        ],
      ),
    );
  }

  /// 输入历史卡片
  Widget _buildHistoryCard() {
    return Container(
      padding: EdgeInsets.all(AppTheme.spacingDefault),
      decoration: AppTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.history, size: 20.sp, color: AppTheme.infoColor),
              SizedBox(width: AppTheme.spacingS),
              Text(
                '输入历史',
                style: AppTheme.textSubheading.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 16.sp,
                ),
              ),
              const Spacer(),
              Obx(() => controller.inputHistory.isNotEmpty
                  ? TextButton.icon(
                      onPressed: controller.clearHistory,
                      icon: Icon(Icons.delete_outline, size: 16.sp),
                      label: Text('清空'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.errorColor,
                        padding: EdgeInsets.symmetric(
                          horizontal: AppTheme.spacingS,
                          vertical: AppTheme.spacingXS,
                        ),
                      ),
                    )
                  : const SizedBox.shrink()),
            ],
          ),
          SizedBox(height: AppTheme.spacingDefault),
          Obx(() {
            if (controller.inputHistory.isEmpty) {
              return Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: AppTheme.spacingL),
                  child: Column(
                    children: [
                      Icon(
                        Icons.inbox,
                        size: 48.sp,
                        color: AppTheme.textTertiary,
                      ),
                      SizedBox(height: AppTheme.spacingS),
                      Text(
                        '暂无历史记录',
                        style: AppTheme.textBody.copyWith(
                          color: AppTheme.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }
            
            return Column(
              children: controller.inputHistory.take(10).map((record) {
                final timestamp = record['timestamp'] as DateTime;
                final data = record['data'] as String;
                final length = record['length'] as int;
                
                return Container(
                  margin: EdgeInsets.only(bottom: AppTheme.spacingS),
                  padding: EdgeInsets.all(AppTheme.spacingM),
                  decoration: BoxDecoration(
                    color: AppTheme.backgroundLight,
                    borderRadius: BorderRadius.circular(AppTheme.borderRadiusS),
                    border: Border.all(color: AppTheme.borderColor),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: EdgeInsets.all(AppTheme.spacingS),
                        decoration: BoxDecoration(
                          color: AppTheme.infoColor.withAlpha((0.1 * 255).toInt()),
                          borderRadius: BorderRadius.circular(AppTheme.borderRadiusXS),
                        ),
                        child: Icon(
                          Icons.keyboard,
                          size: 16.sp,
                          color: AppTheme.infoColor,
                        ),
                      ),
                      SizedBox(width: AppTheme.spacingM),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.schedule,
                                  size: 12.sp,
                                  color: AppTheme.textTertiary,
                                ),
                                SizedBox(width: 4.w),
                                Text(
                                  DateFormat('HH:mm:ss').format(timestamp),
                                  style: AppTheme.textCaption.copyWith(
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: AppTheme.spacingS,
                                    vertical: 2.h,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppTheme.infoColor.withAlpha((0.1 * 255).toInt()),
                                    borderRadius: BorderRadius.circular(AppTheme.borderRadiusRound),
                                  ),
                                  child: Text(
                                    '$length 字符',
                                    style: AppTheme.textCaption.copyWith(
                                      color: AppTheme.infoColor,
                                      fontSize: 11.sp,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 6.h),
                            Text(
                              data.length > 60 ? '${data.substring(0, 60)}...' : data,
                              style: AppTheme.textBody.copyWith(
                                fontFamily: 'monospace',
                                fontSize: 13.sp,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            );
          }),
        ],
      ),
    );
  }

  /// 信息行
  Widget _buildInfoRow(String label, String value, {Color? valueColor, IconData? icon}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: AppTheme.spacingS),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: AppTheme.textBody.copyWith(
                color: AppTheme.textSecondary,
                fontSize: 13.sp,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (icon != null) ..[
                  Icon(
                    icon,
                    size: 14.sp,
                    color: valueColor ?? AppTheme.textPrimary,
                  ),
                  SizedBox(width: 4.w),
                ],
                Flexible(
                  child: Text(
                    value,
                    style: AppTheme.textBody.copyWith(
                      color: valueColor ?? AppTheme.textPrimary,
                      fontWeight: FontWeight.w500,
                      fontSize: 13.sp,
                    ),
                    textAlign: TextAlign.right,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 分割线
  Widget _buildDivider() {
    return Divider(
      height: 1,
      color: AppTheme.borderColor.withAlpha((0.3 * 255).toInt()),
    );
  }
}
