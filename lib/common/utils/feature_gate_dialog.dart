import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tronskins_app/common/utils/app_snackbar.dart';
import 'package:tronskins_app/common/widgets/figma_confirmation_dialog.dart';

Future<void> showFeatureNotOpenDialog() async {
  final context = Get.overlayContext ?? Get.context;
  if (context == null) {
    AppSnackbar.info('app.system.message.not_open'.tr);
    return;
  }

  await showFigmaModal<void>(
    context: context,
    child: FigmaConfirmationDialog(
      title: 'app.system.tips.title'.tr,
      message: 'app.system.message.not_open'.tr,
      primaryLabel: 'app.common.confirm'.tr,
      onPrimary: () => popModalRoute(context),
      icon: Icons.lock_outline_rounded,
      accentColor: const Color(0xFF1E40AF),
      iconColor: const Color(0xFF1E40AF),
      iconBackgroundColor: const Color.fromRGBO(30, 64, 175, 0.10),
    ),
  );
}
