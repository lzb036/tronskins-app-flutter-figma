// lib/controllers/user_controller.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tronskins_app/api/loginServer.dart';
import 'package:tronskins_app/api/model/entity/user/user_info_entity.dart';
import 'package:tronskins_app/common/events/app_events.dart';
import 'package:tronskins_app/common/http/interceptors/auth_interceptor.dart';
import 'package:tronskins_app/common/http/http_helper.dart';
import 'package:tronskins_app/common/logging/app_logger.dart';
import 'package:tronskins_app/common/storage/app_cache.dart';
import 'package:tronskins_app/common/storage/server_storage.dart';
import 'package:tronskins_app/common/storage/twofa_storage.dart';
import 'package:tronskins_app/common/storage/user_storage.dart';
import 'package:tronskins_app/common/widgets/figma_confirmation_dialog.dart';
import 'package:tronskins_app/routes/app_routes.dart';

class UserController extends GetxController {
  static const String _imageBaseUrl = 'https://www.tronskins.com/fms/image';
  // ==================== 鍝嶅簲寮忕姸鎬?====================
  final RxBool isLoading = false.obs;
  final RxBool isLoggedIn = false.obs;
  Worker? _logoutWorker;
  Worker? _serverWorker;

  // 鍏抽敭锛氱敤 late + Rx锛岄伩鍏?null 瀹夊叏璀﹀憡
  final Rx<UserInfoEntity?> user = Rx<UserInfoEntity?>(null);

  // ==================== 璁＄畻灞炴€э紙瓒呭畨鍏ㄥ啓娉曪級================
  ImageProvider get avatarProvider {
    final avatar = user.value?.avatar ?? user.value?.config?.avatar;
    final resolved = _resolveAvatarUrl(avatar);
    if (isLoggedIn.value && resolved.isNotEmpty) {
      return CachedNetworkImageProvider(resolved);
    }
    return const AssetImage('assets/images/user/none.png');
  }

  String get nickname {
    if (!isLoggedIn.value) return '';
    final name = user.value?.nickname;
    if (name != null && name.isNotEmpty) return name;
    return '';
  }

  String get email {
    if (!isLoggedIn.value) return '';
    final safeEmail = user.value?.safeTokenName;
    if (safeEmail != null && safeEmail.isNotEmpty) return safeEmail;
    final name = user.value?.showEmail;
    if (name != null && name.isNotEmpty) return name;
    return '';
  }

  String get balance {
    final b = user.value?.fund?.balance;
    return b != null ? b.toStringAsFixed(2) : '0.00';
  }

  String get gift {
    final g = user.value?.fund?.gift;
    return g != null ? g.toStringAsFixed(0) : '0';
  }

  double get balanceValue => user.value?.fund?.balance ?? 0;

  double get giftValue => user.value?.fund?.gift ?? 0;

  double get lockedValue => user.value?.fund?.locked ?? 0;

  double get settlementValue => user.value?.fund?.settlement ?? 0;

  String get integral {
    return user.value?.fund?.integral ?? '0';
  }

  // ==================== 鍒濆鍖?====================
  @override
  void onInit() {
    super.onInit();
    final cachedUser = UserStorage.getUserInfo();
    final hasToken = AuthInterceptor.hasToken;
    if (cachedUser != null && hasToken) {
      user.value = cachedUser;
      isLoggedIn.value = true;
    } else if (!hasToken) {
      clearSession();
    }
    // 寤惰繜涓€鐐圭偣鎵ц锛岄伩鍏嶅喎鍚姩鍗￠】锛堝彲閫変紭鍖栵級
    ever(isLoggedIn, (_) => update()); // 鐧诲綍鐘舵€佸彉浜嗗氨鍒锋柊椤甸潰
    _logoutWorker = ever(AppEvents.userLogoutEvent, (_) => clearSession());
    _serverWorker = ever<int>(ServerStorage.changeToken, (_) {
      refreshForServerSwitch();
    });
    if (AuthInterceptor.hasToken) {
      fetchUserData();
    }
  }

  @override
  void onClose() {
    _logoutWorker?.dispose();
    _serverWorker?.dispose();
    super.onClose();
  }

  // ==================== 鑾峰彇鐢ㄦ埛淇℃伅 ====================
  Future<void> fetchUserData({bool showLoading = true}) async {
    if (isLoading.value) return;

    final requestServer = ServerStorage.getServer();
    if (showLoading) isLoading.value = true;

    try {
      final result = await ApiLoginServer().getUserApi();
      if (requestServer != ServerStorage.getServer()) {
        return;
      }
      if (result.success && result.datas != null) {
        final mergedUserInfo = UserStorage.mergeUserInfo(
          result.datas!,
          fallbackUserInfo: user.value,
        );
        user.value = mergedUserInfo;
        isLoggedIn.value = true;
        UserStorage.setUserInfo(mergedUserInfo);
      } else if (result.code == 401) {
        clearSession();
      }
    } on HttpException catch (error) {
      if (requestServer != ServerStorage.getServer()) {
        return;
      }
      if (error.dioError?.response?.statusCode == 401) {
        clearSession();
      }
    } catch (e, stackTrace) {
      if (requestServer != ServerStorage.getServer()) {
        return;
      }
      AppLogger.errorLog(
        'USER',
        'Failed to refresh user profile.',
        scope: 'FETCH',
        error: e,
        stackTrace: stackTrace,
      );
      // 网络异常或数据解析异常时，保留本地用户信息
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> refreshForServerSwitch() async {
    if (!AuthInterceptor.hasToken) {
      clearSession();
      return;
    }
    user.value = null;
    isLoggedIn.value = true;
    UserStorage.setUserInfo(null);
    var waitCycles = 0;
    while (isLoading.value && waitCycles < 20) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      waitCycles++;
    }
    if (isClosed || !AuthInterceptor.hasToken) {
      return;
    }
    await fetchUserData(showLoading: false);
  }

  Future<void> handleLoginSuccess() async {
    if (!AuthInterceptor.hasToken) {
      clearSession();
      return;
    }
    isLoggedIn.value = true;
    await fetchUserData(showLoading: false);
  }

  // ==================== 閫€鍑虹櫥褰?====================
  Future<void> logout(BuildContext context) async {
    await showFigmaModal<void>(
      context: context,
      barrierDismissible: false,
      child: FigmaAsyncConfirmationDialog(
        icon: Icons.logout_rounded,
        iconColor: const Color(0xFFE11D48),
        iconBackgroundColor: const Color.fromRGBO(225, 29, 72, 0.10),
        accentColor: const Color(0xFFE11D48),
        title: 'app.user.login.logout'.tr,
        message: 'app.user.login.logout_confirm'.tr,
        primaryLabel: 'app.user.login.logout'.tr,
        secondaryLabel: 'app.common.cancel'.tr,
        onSecondary: () => popModalRoute(context),
        onConfirm: (_) => _doLogout(),
      ),
    );
  }

  /// 瀹為檯鎵ц閫€鍑虹櫥褰曠殑鏂规硶
  Future<void> _doLogout() async {
    final currentUser = user.value ?? UserStorage.getUserInfo();
    try {
      // 1. 璋冪敤閫€鍑虹櫥褰?API
      await ApiLoginServer().logoutApi();

      // 2. 鍙戦€佸叏灞€閫€鍑轰簨浠讹紝閫氱煡鍏朵粬椤甸潰
      AppEvents.triggerUserLogout();
    } catch (_) {}

    // 3. 娓呴櫎缂撳瓨鍜屼會璇?
    final currentUserId = currentUser?.id ?? '';
    final currentAppUse = currentUser?.appUse ?? '';
    if (currentUserId.isNotEmpty && currentAppUse.isNotEmpty) {
      await TwoFactorStorage.removePendingTokenEntry(
        server: ServerStorage.getServer(),
        appUse: currentAppUse,
        userId: currentUserId,
      );
    }
    await AppCache.clearOnLogout();
    clearSession();

    // 4. 寤惰繜璺宠浆鍒扮敤鎴蜂腑蹇冮〉闈紙涓?tronskins-app 淇濇寔涓€鑷达級
    await Future.delayed(const Duration(milliseconds: 500));
    Get.offAllNamed(Routers.USER);
  }

  // ==================== 绉佹湁鏂规硶 ====================
  void clearSession() {
    user.value = null;
    isLoggedIn.value = false;
    UserStorage.setUserInfo(null);
  }

  // ==================== 涓嬫媺鍒锋柊 ====================
  Future<void> onRefresh() => fetchUserData(showLoading: false);

  String _resolveAvatarUrl(String? avatar) {
    if (avatar == null || avatar.isEmpty) {
      return '';
    }
    final trimmed = avatar.trim();
    if (trimmed.isEmpty) {
      return '';
    }
    if (trimmed.startsWith('//')) {
      return 'https:$trimmed';
    }
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    final normalizedPath = trimmed.startsWith('/') ? trimmed : '/$trimmed';
    return '$_imageBaseUrl$normalizedPath';
  }
}
