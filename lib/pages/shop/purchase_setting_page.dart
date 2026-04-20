import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tronskins_app/common/utils/app_snackbar.dart';
import 'package:tronskins_app/common/widgets/settings_style_app_bar.dart';
import 'package:tronskins_app/controllers/shop/buy_request_controller.dart';

class PurchaseSettingPage extends StatefulWidget {
  const PurchaseSettingPage({super.key});

  @override
  State<PurchaseSettingPage> createState() => _PurchaseSettingPageState();
}

class _PurchaseSettingPageState extends State<PurchaseSettingPage> {
  static const _pageBg = Color(0xFFF7F9FB);
  static const _cardBg = Colors.white;
  static const _cardBorder = Color(0xFFF1F5F9);
  static const _titleColor = Color(0xFF191C1E);
  static const _mutedColor = Color(0xFF444653);
  static const _brandColor = Color(0xFF00288E);
  static const _brandColorLight = Color(0xFF0058BE);

  final BuyRequestController controller =
      Get.isRegistered<BuyRequestController>()
      ? Get.find<BuyRequestController>()
      : Get.put(BuyRequestController());
  bool _isSwitchingPurchaseOnline = false;

  @override
  void initState() {
    super.initState();
    controller.refreshPurchaseStatus();
  }

  Future<bool> _confirmSwitch(String messageKey) async {
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: Text('app.system.tips.title'.tr),
        content: Text(messageKey.tr),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: Text('app.common.cancel'.tr),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            child: Text('app.common.confirm'.tr),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  String _purchaseOnlineConfirmKey(bool value) => value
      ? 'app.trade.purchase.message.confirm_online_on'
      : 'app.trade.purchase.message.confirm_online_off';

  String _purchaseOnlineSuccessKey(bool value) => value
      ? 'app.trade.purchase.message.online_on_success'
      : 'app.trade.purchase.message.online_off_success';

  String _purchaseOnlineFailedKey(bool value) => value
      ? 'app.trade.purchase.message.online_on_failed'
      : 'app.trade.purchase.message.online_off_failed';

  Future<void> _handlePurchaseOnlineChanged(bool value) async {
    if (_isSwitchingPurchaseOnline) {
      return;
    }
    final confirmed = await _confirmSwitch(_purchaseOnlineConfirmKey(value));
    if (!confirmed || !mounted) {
      return;
    }
    setState(() => _isSwitchingPurchaseOnline = true);
    try {
      final res = await controller.togglePurchaseStatus();
      if (res.success) {
        AppSnackbar.success(_purchaseOnlineSuccessKey(value).tr);
      } else {
        AppSnackbar.error(_purchaseOnlineFailedKey(value).tr);
        await controller.refreshPurchaseStatus();
      }
    } catch (_) {
      AppSnackbar.error(_purchaseOnlineFailedKey(value).tr);
      await controller.refreshPurchaseStatus();
    } finally {
      if (mounted) {
        setState(() => _isSwitchingPurchaseOnline = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageBg,
      body: Stack(
        children: [
          Positioned.fill(
            child: Obx(() {
              final isOnline = controller.purchaseOnline.value;
              return SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 96, 16, 32),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 672),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildOverviewCard(isOnline: isOnline),
                        const SizedBox(height: 16),
                        _buildNoticeCard(),
                        const SizedBox(height: 16),
                        _buildGroupedCard([
                          _buildToggleTile(
                            icon: Icons.wifi_tethering_rounded,
                            title: 'app.trade.purchase.status_online'.tr,
                            value: isOnline,
                            isBusy: _isSwitchingPurchaseOnline,
                            onChanged: _isSwitchingPurchaseOnline
                                ? null
                                : _handlePurchaseOnlineChanged,
                          ),
                        ]),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
          _buildTopNavigation(),
        ],
      ),
    );
  }

  Widget _buildTopNavigation() {
    return SettingsStyleTopNavigation(title: 'app.trade.purchase.setting'.tr);
  }

  Widget _buildOverviewCard({required bool isOnline}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, Color(0xFFF8FBFF)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cardBorder),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.04),
            blurRadius: 20,
            offset: Offset(0, 4),
          ),
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.03),
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned(
            right: -36,
            top: -48,
            child: _buildBlurBlob(
              size: 148,
              color: const Color.fromRGBO(0, 88, 190, 0.10),
            ),
          ),
          Positioned(
            left: -42,
            bottom: -56,
            child: _buildBlurBlob(
              size: 156,
              color: const Color.fromRGBO(0, 40, 142, 0.08),
            ),
          ),
          Positioned(
            left: 22,
            top: 0,
            child: Container(
              width: 84,
              height: 5,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_brandColor, _brandColorLight],
                ),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(999),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAF2FF),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.shopping_cart_checkout_rounded,
                        size: 22,
                        color: _brandColor,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        'app.trade.purchase.setting'.tr,
                        style: const TextStyle(
                          color: _mutedColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          height: 16 / 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  'app.trade.purchase.status_online'.tr,
                  style: const TextStyle(
                    color: _titleColor,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    height: 32 / 24,
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: 14),
                _buildStateChip(
                  icon: Icons.wifi_tethering_rounded,
                  label: 'app.trade.purchase.status_online'.tr,
                  active: isOnline,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoticeCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cardBorder),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.03),
            blurRadius: 12,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.info_outline_rounded,
                size: 20,
                color: _brandColor,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'app.system.tips.title'.tr,
                    style: const TextStyle(
                      color: _titleColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      height: 24 / 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'app.trade.purchase.tips'.tr,
                    style: const TextStyle(
                      color: _mutedColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      height: 20 / 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupedCard(List<Widget> tiles) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cardBorder),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.03),
            blurRadius: 12,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          for (var i = 0; i < tiles.length; i++) ...[
            tiles[i],
            if (i != tiles.length - 1)
              const Divider(
                height: 1,
                thickness: 1,
                indent: 16,
                endIndent: 16,
                color: _cardBorder,
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildToggleTile({
    required IconData icon,
    required String title,
    required bool value,
    required bool isBusy,
    required ValueChanged<bool>? onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          _buildLeadingIcon(icon),
          const SizedBox(width: 16),
          Expanded(
            child: SizedBox(
              width: double.infinity,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  title,
                  softWrap: false,
                  style: const TextStyle(
                    color: _titleColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    height: 24 / 16,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: isBusy
                ? const SizedBox(
                    key: ValueKey('busy'),
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.2),
                  )
                : Transform.scale(
                    key: const ValueKey('switch'),
                    scale: 0.92,
                    child: Switch(
                      value: value,
                      onChanged: onChanged,
                      activeThumbColor: Colors.white,
                      activeTrackColor: _brandColor,
                      inactiveThumbColor: Colors.white,
                      inactiveTrackColor: const Color(0xFFE2E8F0),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeadingIcon(IconData icon) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, size: 20, color: _brandColor),
    );
  }

  Widget _buildStateChip({
    required IconData icon,
    required String label,
    required bool active,
  }) {
    final background = active
        ? const Color(0xFFEAF2FF)
        : const Color(0xFFF1F5F9);
    final foreground = active ? _brandColor : _mutedColor;
    final borderColor = active
        ? const Color.fromRGBO(0, 40, 142, 0.10)
        : _cardBorder;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: foreground),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: foreground,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 16 / 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlurBlob({required double size, required Color color}) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}
