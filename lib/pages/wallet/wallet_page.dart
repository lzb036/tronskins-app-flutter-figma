import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tronskins_app/common/hooks/currency/CurrencyController.dart';
import 'package:tronskins_app/common/utils/app_snackbar.dart';
import 'package:tronskins_app/common/utils/feature_gate_dialog.dart';
import 'package:tronskins_app/common/widgets/login_required_prompt.dart';
import 'package:tronskins_app/common/widgets/settings_style_app_bar.dart';
import 'package:tronskins_app/controllers/user/user_controller.dart';
import 'package:tronskins_app/controllers/wallet/wallet_controller.dart';
import 'package:tronskins_app/routes/app_routes.dart';

class WalletPage extends StatefulWidget {
  const WalletPage({super.key});

  @override
  State<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage> {
  static const Color _pageBackground = Color(0xFFF1F5F9);
  static const Color _surfaceColor = Colors.white;
  static const Color _borderColor = Color.fromRGBO(226, 232, 240, 0.75);
  static const Color _titleColor = Color(0xFF0F172A);
  static const Color _bodyColor = Color(0xFF444653);
  static const Color _brandColor = Color(0xFF1E40AF);

  final WalletController controller = Get.isRegistered<WalletController>()
      ? Get.find<WalletController>()
      : Get.put(WalletController());
  final UserController userController = Get.find<UserController>();
  bool _isBalanceVisible = true;

  @override
  void initState() {
    super.initState();
    if (userController.isLoggedIn.value) {
      controller.refreshUser();
    }
  }

  Future<void> _navigateRecharge() async {
    if (!userController.isLoggedIn.value) {
      return;
    }
    final allow = await controller.checkRechargeEnable();
    if (allow == false) {
      AppSnackbar.info('app.user.recharge.disable'.tr);
      return;
    }
    Get.toNamed(Routers.WALLET_RECHARGE);
  }

  Future<void> _navigateWithdraw() async {
    final allow = await controller.checkWithdrawEnable();
    if (allow == false) {
      AppSnackbar.info('app.user.withdraw.disable'.tr);
      return;
    }
    Get.toNamed(Routers.WALLET_WITHDRAW);
  }

  void _toggleBalanceVisibility() {
    setState(() {
      _isBalanceVisible = !_isBalanceVisible;
    });
  }

  @override
  Widget build(BuildContext context) {
    final currency = Get.find<CurrencyController>();
    return Obx(() {
      final loggedIn = userController.isLoggedIn.value;
      final refreshing = controller.isLoadingUser.value;
      final fund =
          controller.userInfo.value?.fund ?? userController.user.value?.fund;
      final hasWalletData = fund != null;

      return Scaffold(
        backgroundColor: _pageBackground,
        body: Stack(
          children: [
            Positioned.fill(
              child: loggedIn
                  ? (refreshing && !hasWalletData
                        ? const Center(child: CircularProgressIndicator())
                        : _buildWalletBody(context, currency))
                  : _buildLoggedOutBody(context),
            ),
            _buildTopNavigation(context),
          ],
        ),
      );
    });
  }

  Widget _buildWalletBody(BuildContext context, CurrencyController currency) {
    final bottomPadding = MediaQuery.of(context).padding.bottom + 32;
    final quickActions = <_QuickActionItem>[
      _QuickActionItem(
        icon: Icons.add_circle_outline_rounded,
        title: 'app.user.recharge.title'.tr,
        onTap: _navigateRecharge,
      ),
      _QuickActionItem(
        icon: Icons.account_balance_wallet_outlined,
        title: 'app.user.withdraw.title'.tr,
        onTap: _navigateWithdraw,
      ),
      _QuickActionItem(
        icon: Icons.receipt_long_outlined,
        title: 'app.user.wallet.flow'.tr,
        onTap: () => Get.toNamed(Routers.WALLET_FLOW),
      ),
      _QuickActionItem(
        icon: Icons.timer_outlined,
        title: 'app.user.wallet.unsettled_details'.tr,
        onTap: () => Get.toNamed(Routers.WALLET_SETTLEMENT),
      ),
      _QuickActionItem(
        icon: Icons.lock_clock_outlined,
        title: 'app.user.wallet.lock_details'.tr,
        onTap: () => Get.toNamed(Routers.WALLET_LOCKED),
      ),
    ];

    return ListView(
      physics: const ClampingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(16, 96, 16, bottomPadding),
      children: [
        Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 672),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTotalAssetsCard(currency),
                const SizedBox(height: 24),
                _buildMetricGrid(currency),
                const SizedBox(height: 24),
                _buildQuickActionGrid(quickActions),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoggedOutBody(BuildContext context) {
    return const LoginRequiredPrompt();
  }

  Widget _buildTopNavigation(BuildContext context) {
    return SettingsStyleTopNavigation(
      title: 'app.user.wallet.title'.tr,
      onBack: () => Navigator.of(context).maybePop(),
    );
  }

  Widget _buildTotalAssetsCard(CurrencyController currency) {
    final fund =
        controller.userInfo.value?.fund ?? userController.user.value?.fund;
    final totalValue = currency.formatUsd(fund?.balance ?? 0);
    final currencyParts = _splitCurrencyText(_displayBalance(totalValue));

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _borderColor),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(15, 23, 42, 0.04),
            blurRadius: 20,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned(
            top: -64,
            right: -64,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 32, sigmaY: 32),
              child: Container(
                width: 128,
                height: 128,
                decoration: const BoxDecoration(
                  color: Color.fromRGBO(30, 64, 175, 0.05),
                  borderRadius: BorderRadius.all(Radius.circular(16)),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'app.user.wallet.assets_total'.tr,
                      style: const TextStyle(
                        color: _bodyColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        height: 20 / 14,
                        letterSpacing: 0.35,
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _toggleBalanceVisibility,
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: Icon(
                          _isBalanceVisible
                              ? Icons.remove_red_eye_outlined
                              : Icons.visibility_off_outlined,
                          size: 18,
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FittedBox(
                    alignment: Alignment.centerLeft,
                    fit: BoxFit.scaleDown,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (currencyParts.prefix.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(right: 8, bottom: 8),
                            child: Text(
                              currencyParts.prefix,
                              style: const TextStyle(
                                color: _brandColor,
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                height: 32 / 24,
                              ),
                            ),
                          ),
                        Text(
                          currencyParts.value,
                          style: const TextStyle(
                            color: _titleColor,
                            fontSize: 48,
                            fontWeight: FontWeight.w800,
                            height: 1,
                            letterSpacing: -1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricGrid(CurrencyController currency) {
    final fund =
        controller.userInfo.value?.fund ?? userController.user.value?.fund;
    final available = currency.formatUsd(fund?.available ?? 0);
    final locked = currency.formatUsd(fund?.locked ?? 0);
    final gift = currency.formatUsd(fund?.gift ?? 0);
    final settlement = currency.formatUsd(fund?.settlement ?? 0);

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _WalletMetricCard(
                height: 160,
                label: 'app.user.wallet.available'.tr,
                value: _displayBalance(available),
                onTap: () => Get.toNamed(Routers.WALLET_FLOW),
                bottomIcon: Icons.account_balance_wallet_outlined,
                bottomIconBackground: const Color(0xFFE8EEFF),
                bottomIconColor: _brandColor,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _WalletMetricCard(
                height: 160,
                label: 'app.user.wallet.lock_amount'.tr,
                value: _displayBalance(locked),
                onTap: () => Get.toNamed(Routers.WALLET_LOCKED),
                topIcon: Icons.info_outline,
                bottomIcon: Icons.lock_outline_rounded,
                bottomIconBackground: const Color(0xFFF1F5F9),
                bottomIconColor: const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _WalletMetricCard(
                height: 144,
                label: 'app.user.wallet.gift'.tr,
                value: _displayBalance(gift),
                onTap: () => showFeatureNotOpenDialog(),
                topIcon: Icons.chevron_right_rounded,
                bottomIcon: Icons.card_giftcard_rounded,
                bottomIconBackground: const Color(0xFFFFF1F2),
                bottomIconColor: const Color(0xFFF43F5E),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _WalletMetricCard(
                height: 144,
                label: 'app.user.wallet.unsettled'.tr,
                value: _displayBalance(settlement),
                onTap: () => Get.toNamed(Routers.WALLET_SETTLEMENT),
                topIcon: Icons.chevron_right_rounded,
                bottomIcon: Icons.history_toggle_off_rounded,
                bottomIconBackground: const Color(0xFFFFFBEB),
                bottomIconColor: const Color(0xFFF59E0B),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickActionGrid(List<_QuickActionItem> items) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 8.0;
        final itemWidth = (constraints.maxWidth - spacing * 2) / 3;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final item in items)
              SizedBox(
                width: itemWidth,
                child: _QuickActionCard(item: item),
              ),
          ],
        );
      },
    );
  }

  _CurrencyParts _splitCurrencyText(String value) {
    final digitIndex = value.indexOf(RegExp(r'[0-9]'));
    final maskIndex = value.indexOf('*');
    if (digitIndex < 0 && maskIndex > 0 && maskIndex < value.length) {
      return _CurrencyParts(
        prefix: value.substring(0, maskIndex).trim(),
        value: value.substring(maskIndex),
      );
    }
    if (digitIndex <= 0 || digitIndex >= value.length) {
      return _CurrencyParts(prefix: '', value: value);
    }
    return _CurrencyParts(
      prefix: value.substring(0, digitIndex).trim(),
      value: value.substring(digitIndex),
    );
  }

  String _displayBalance(String rawValue) {
    if (_isBalanceVisible) {
      return rawValue;
    }

    final parts = _splitCurrencyText(rawValue);
    if (parts.prefix.isEmpty) {
      return '* * * *';
    }

    return '${parts.prefix} * * * *';
  }
}

class _WalletMetricCard extends StatelessWidget {
  const _WalletMetricCard({
    required this.height,
    required this.label,
    required this.value,
    required this.bottomIcon,
    required this.bottomIconBackground,
    required this.bottomIconColor,
    this.onTap,
    this.topIcon,
  });

  final double height;
  final String label;
  final String value;
  final IconData bottomIcon;
  final Color bottomIconBackground;
  final Color bottomIconColor;
  final VoidCallback? onTap;
  final IconData? topIcon;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      height: height,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color.fromRGBO(226, 232, 240, 0.65)),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(15, 23, 42, 0.04),
            blurRadius: 20,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color.fromRGBO(68, 70, 83, 0.7),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 16 / 12,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              if (topIcon != null)
                Icon(topIcon, size: 18, color: const Color(0xFF94A3B8)),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FittedBox(
              alignment: Alignment.centerLeft,
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                maxLines: 1,
                style: const TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  height: 28 / 20,
                ),
              ),
            ),
          ),
          const Spacer(),
          Align(
            alignment: Alignment.bottomRight,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: bottomIconBackground,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(bottomIcon, size: 16, color: bottomIconColor),
            ),
          ),
        ],
      ),
    );

    if (onTap == null) {
      return content;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: content,
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({required this.item});

  final _QuickActionItem item;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: item.onTap,
        child: Ink(
          height: 116,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color.fromRGBO(226, 232, 240, 0.65),
            ),
            boxShadow: const [
              BoxShadow(
                color: Color.fromRGBO(15, 23, 42, 0.04),
                blurRadius: 20,
                offset: Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: Column(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color.fromRGBO(30, 64, 175, 0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  item.icon,
                  size: 20,
                  color: const Color(0xFF1D4ED8),
                ),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: Align(
                  alignment: Alignment.center,
                  child: Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF444653),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      height: 16 / 11,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActionItem {
  const _QuickActionItem({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
}

class _CurrencyParts {
  const _CurrencyParts({required this.prefix, required this.value});

  final String prefix;
  final String value;
}
