import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

/// 应用事件管理类
/// 使用 GetX 的响应式变量实现事件总线
class AppEvents {
  // 单例模式
  AppEvents._();

  static final AppEvents _instance = AppEvents._();
  static AppEvents get instance => _instance;

  /// 用户退出登录事件标志
  final RxBool _userLogoutEvent = false.obs;
  final RxInt _authExpiredEvent = 0.obs;

  /// 触发用户退出登录事件
  static void triggerUserLogout() {
    instance._userLogoutEvent.value = !instance._userLogoutEvent.value;
  }

  /// 触发登录态失效事件
  static void triggerAuthExpired() {
    instance._authExpiredEvent.value++;
  }

  /// 监听用户退出登录事件
  static void onUserLogout(VoidCallback callback) {
    ever(instance._userLogoutEvent, (_) => callback());
  }

  /// 获取退出登录事件流（用于 Worker）
  static RxBool get userLogoutEvent => instance._userLogoutEvent;

  /// 获取登录态失效事件流（用于 Worker）
  static RxInt get authExpiredEvent => instance._authExpiredEvent;
}
