import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tronskins_app/common/events/app_events.dart';
import 'package:tronskins_app/common/widgets/figma_confirmation_dialog.dart';
import 'package:tronskins_app/routes/app_routes.dart';

class AuthSessionExpiredListener extends StatefulWidget {
  const AuthSessionExpiredListener({super.key, required this.child});

  final Widget child;

  @override
  State<AuthSessionExpiredListener> createState() =>
      _AuthSessionExpiredListenerState();
}

class _AuthSessionExpiredListenerState
    extends State<AuthSessionExpiredListener> {
  Worker? _authExpiredWorker;
  bool _isShowing = false;

  @override
  void initState() {
    super.initState();
    _authExpiredWorker = ever<int>(
      AppEvents.authExpiredEvent,
      (_) => _showAuthExpiredDialog(),
    );
  }

  @override
  void dispose() {
    _authExpiredWorker?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;

  Future<void> _showAuthExpiredDialog() async {
    if (!mounted || _isShowing || Get.currentRoute == Routers.LOGIN) {
      return;
    }

    _isShowing = true;
    try {
      await showFigmaModal<void>(
        context: context,
        barrierDismissible: false,
        child: FigmaConfirmationDialog(
          title: _title,
          message: _message,
          primaryLabel: 'app.common.confirm'.tr,
          onPrimary: _goToLogin,
        ),
      );
    } finally {
      _isShowing = false;
    }
  }

  void _goToLogin() {
    Get.offAllNamed(Routers.LOGIN);
  }

  String get _title {
    if (Get.locale?.languageCode == 'zh') {
      return '登录状态已失效';
    }
    return 'Session expired';
  }

  String get _message {
    if (Get.locale?.languageCode == 'zh') {
      return '您的登录状态已失效，请重新登录后继续操作。';
    }
    return 'Your login session has expired. Please sign in again to continue.';
  }
}
