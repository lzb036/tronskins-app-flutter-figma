import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tronskins_app/common/hooks/currency/CurrencyController.dart';
import 'package:tronskins_app/common/utils/feature_gate_dialog.dart';
import 'package:tronskins_app/common/widgets/back_to_top_overlay.dart';
import 'package:tronskins_app/common/widgets/figma_confirmation_dialog.dart';
import 'package:tronskins_app/controllers/user/notify_controller.dart';
import 'package:tronskins_app/controllers/user/user_controller.dart';
import 'package:tronskins_app/pages/user/scan_login_page.dart';
import 'package:tronskins_app/routes/app_routes.dart';

import 'user_menu_config.dart';

class UserPage extends StatelessWidget {
  const UserPage({super.key});

  @override
  Widget build(BuildContext context) {
    final userCtrl = Get.find<UserController>();
    final currency = Get.find<CurrencyController>();

    return BackToTopScope(
      enabled: false,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F9FB),
        body: Stack(
          children: [
            Positioned.fill(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 96, 16, 24),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 672),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Obx(
                          () => _ProfileSection(
                            avatarProvider: userCtrl.avatarProvider,
                            nickname: userCtrl.nickname,
                            userId:
                                userCtrl.user.value?.config?.partnerId ?? '',
                            steamId: userCtrl.user.value?.config?.steamId ?? '',
                            isLoggedIn: userCtrl.isLoggedIn.value,
                          ),
                        ),
                        Obx(() {
                          if (!userCtrl.isLoggedIn.value) {
                            return const SizedBox(height: 32);
                          }
                          return Column(
                            children: [
                              const SizedBox(height: 32),
                              _AssetSection(
                                balance: currency.formatUsd(
                                  userCtrl.balanceValue,
                                ),
                                gift: currency.formatUsd(userCtrl.giftValue),
                                points: userCtrl.integral,
                              ),
                              const SizedBox(height: 32),
                            ],
                          );
                        }),
                        _ServicesSection(itemConfigs: userMenuItems),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const _TopNavigationShell(),
          ],
        ),
      ),
    );
  }
}

class _TopNavigationShell extends StatelessWidget {
  const _TopNavigationShell();

  Future<bool> _promptLoginIfNeeded(BuildContext context) async {
    final userCtrl = Get.find<UserController>();
    if (userCtrl.isLoggedIn.value) {
      return true;
    }

    final confirmed = await showFigmaModal<bool>(
      context: context,
      child: FigmaConfirmationDialog(
        icon: Icons.login_rounded,
        iconColor: const Color(0xFF1E40AF),
        iconBackgroundColor: const Color.fromRGBO(30, 64, 175, 0.10),
        title: 'app.user.login.nologin'.tr,
        message: 'app.system.message.nologin'.tr,
        primaryLabel: 'app.user.login.nologin'.tr,
        secondaryLabel: 'app.common.cancel'.tr,
        onPrimary: () => popModalRoute(context, true),
        onSecondary: () => popModalRoute(context, false),
      ),
    );
    if (confirmed == true) {
      await Get.toNamed(Routers.LOGIN);
    }
    return false;
  }

  Future<void> _scanCode(BuildContext context) async {
    if (!await _promptLoginIfNeeded(context)) {
      return;
    }
    if (!context.mounted) {
      return;
    }

    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const ScanLoginPage()));
  }

  @override
  Widget build(BuildContext context) {
    final userCtrl = Get.find<UserController>();
    final notifyCtrl = Get.isRegistered<NotifyController>()
        ? Get.find<NotifyController>()
        : Get.put(NotifyController());
    final topInset = MediaQuery.of(context).padding.top;
    return Obx(() {
      final loggedIn = userCtrl.isLoggedIn.value;
      if (loggedIn) {
        notifyCtrl.ensureBadgeLoaded();
      }
      final badgeText = loggedIn ? notifyCtrl.unreadBadgeLabel : null;

      return Positioned(
        top: 0,
        left: 0,
        right: 0,
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
            child: Container(
              color: const Color.fromRGBO(249, 249, 249, 0.8),
              padding: EdgeInsets.fromLTRB(16, topInset + 16, 16, 16),
              child: Align(
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _TopIconButton(
                      icon: Icons.center_focus_weak,
                      onTap: () => _scanCode(context),
                    ),
                    const SizedBox(width: 16),
                    _TopIconButton(
                      icon: Icons.notifications_none_rounded,
                      onTap: () => Get.toNamed(Routers.MESSAGE),
                      badgeText: badgeText,
                    ),
                    const SizedBox(width: 16),
                    _TopIconButton(
                      icon: Icons.settings_outlined,
                      onTap: () => Get.toNamed(Routers.USER_SETTING),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    });
  }
}

class _TopIconButton extends StatelessWidget {
  const _TopIconButton({
    required this.icon,
    required this.onTap,
    this.badgeText,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? badgeText;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: SizedBox(
          width: 36,
          height: 36,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Center(
                child: Icon(icon, color: const Color(0xFF4B4E5D), size: 20),
              ),
              if (badgeText != null)
                Positioned(
                  top: 4,
                  right: 1,
                  child: _TopIconBadge(text: badgeText!),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopIconBadge extends StatelessWidget {
  const _TopIconBadge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white, width: 1.4),
          boxShadow: const [
            BoxShadow(
              color: Color.fromRGBO(239, 68, 68, 0.28),
              blurRadius: 10,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 8.5,
            fontWeight: FontWeight.w700,
            height: 1.0,
          ),
        ),
      ),
    );
  }
}

class _ProfileSection extends StatelessWidget {
  const _ProfileSection({
    required this.avatarProvider,
    required this.nickname,
    required this.userId,
    required this.steamId,
    required this.isLoggedIn,
  });

  final ImageProvider avatarProvider;
  final String nickname;
  final String userId;
  final String steamId;
  final bool isLoggedIn;

  @override
  Widget build(BuildContext context) {
    final displayName = isLoggedIn
        ? (nickname.isNotEmpty ? nickname : '--')
        : 'app.user.login.nologin'.tr;
    final displayId = isLoggedIn ? (userId.isNotEmpty ? userId : '--') : '--';
    final displaySteamId = isLoggedIn
        ? (steamId.isNotEmpty ? steamId : '--')
        : '--';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white, width: 4),
            boxShadow: const [
              BoxShadow(
                color: Color.fromRGBO(0, 0, 0, 0.05),
                blurRadius: 2,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: Image(
            image: avatarProvider,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) {
              return Container(color: const Color(0xFF10293E));
            },
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: isLoggedIn ? null : () => Get.toNamed(Routers.LOGIN),
                behavior: HitTestBehavior.opaque,
                child: Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF191C1E),
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    height: 32 / 24,
                    letterSpacing: -0.6,
                  ),
                ),
              ),
              if (isLoggedIn) ...[
                const SizedBox(height: 4),
                Text(
                  'ID: $displayId',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF444653),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    height: 20 / 14,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'steamID: $displaySteamId',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF00288E),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 16 / 12,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _AssetSection extends StatelessWidget {
  const _AssetSection({
    required this.balance,
    required this.gift,
    required this.points,
  });

  static const double _cardHeight = 96;
  static const double _cardHorizontalPadding = 10;
  static const double _cardVerticalPadding = 18;

  final String balance;
  final String gift;
  final String points;

  double _resolveSharedValueFontSize(
    BuildContext context, {
    required List<String> values,
    required double maxWidth,
    required double maxFontSize,
    required double minFontSize,
  }) {
    final direction = Directionality.of(context);
    final textScaler = MediaQuery.textScalerOf(context);
    const baseStyle = TextStyle(
      color: Color(0xFF191C1E),
      fontWeight: FontWeight.w700,
      height: 1.0,
    );

    for (
      double fontSize = maxFontSize;
      fontSize >= minFontSize;
      fontSize -= 0.25
    ) {
      var fitsAll = true;
      for (final value in values) {
        final painter = TextPainter(
          text: TextSpan(
            text: value,
            style: baseStyle.copyWith(fontSize: fontSize),
          ),
          textDirection: direction,
          textScaler: textScaler,
          maxLines: 1,
        )..layout();
        if (painter.width > maxWidth) {
          fitsAll = false;
          break;
        }
      }
      if (fitsAll) {
        return fontSize;
      }
    }
    return minFontSize;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 10.0;
        // Use the narrowest practical card width to avoid per-column pixel
        // rounding differences causing right-edge clipping.
        final cardWidth = ((constraints.maxWidth - spacing * 2) / 3)
            .floorToDouble();
        const textSafetyPadding = 3.0;
        final valueMaxWidth =
            (cardWidth - _cardHorizontalPadding * 2 - textSafetyPadding)
                .clamp(0.0, cardWidth)
                .toDouble();
        final sharedValueFontSize = _resolveSharedValueFontSize(
          context,
          values: [balance, gift, points],
          maxWidth: valueMaxWidth,
          maxFontSize: 24,
          minFontSize: 8,
        );

        return Row(
          children: [
            Expanded(
              child: _AssetCard(
                label: 'app.user.wallet.balance'.tr,
                value: balance,
                valueFontSize: sharedValueFontSize,
                emphasized: true,
                onTap: () => Get.toNamed(Routers.WALLET),
              ),
            ),
            const SizedBox(width: spacing),
            Expanded(
              child: _AssetCard(
                label: 'app.user.wallet.gift'.tr,
                value: gift,
                valueFontSize: sharedValueFontSize,
                onTap: () => Get.toNamed(Routers.WALLET),
              ),
            ),
            const SizedBox(width: spacing),
            Expanded(
              child: _AssetCard(
                label: 'app.user.integral.unit'.tr,
                value: points,
                valueFontSize: sharedValueFontSize,
                onTap: () => showFeatureNotOpenDialog(),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _AssetCard extends StatelessWidget {
  const _AssetCard({
    required this.label,
    required this.value,
    required this.onTap,
    this.emphasized = false,
    this.valueFontSize = 20,
  });

  final String label;
  final String value;
  final VoidCallback onTap;
  final bool emphasized;
  final double valueFontSize;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Ink(
          height: _AssetSection._cardHeight,
          padding: const EdgeInsets.symmetric(
            horizontal: _AssetSection._cardHorizontalPadding,
            vertical: _AssetSection._cardVerticalPadding,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: double.infinity,
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.left,
                  style: const TextStyle(
                    color: Color(0xFF444653),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    height: 16 / 12,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: Text(
                  value,
                  maxLines: 1,
                  softWrap: false,
                  textAlign: TextAlign.left,
                  style: TextStyle(
                    color: emphasized
                        ? const Color(0xFF00288E)
                        : const Color(0xFF191C1E),
                    fontSize: valueFontSize,
                    fontWeight: FontWeight.w700,
                    // Keep the visual line height fixed even when the font
                    // size is reduced or increased to fit the card width.
                    height: 28 / valueFontSize,
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

class _ServicesSection extends StatelessWidget {
  const _ServicesSection({required this.itemConfigs});

  final List<UserMenuItem> itemConfigs;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'app.user.server.title'.tr.toUpperCase(),
          style: const TextStyle(
            color: Color(0xFF444653),
            fontSize: 12,
            fontWeight: FontWeight.w800,
            height: 16 / 12,
            letterSpacing: 2.4,
          ),
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: itemConfigs.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 0.8,
          ),
          itemBuilder: (context, index) {
            return _ServiceCard(item: itemConfigs[index]);
          },
        ),
      ],
    );
  }
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({required this.item});

  final UserMenuItem item;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: item.onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(item.icon, size: 20, color: const Color(0xFF4B4E5D)),
              const SizedBox(height: 12),
              Text(
                item.title.tr,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF191C1E),
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
