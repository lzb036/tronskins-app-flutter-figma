import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:tronskins_app/common/utils/app_snackbar.dart';
import 'package:tronskins_app/controllers/wallet/gift_card_controller.dart';
import 'package:tronskins_app/routes/app_routes.dart';

class GiftCardPage extends StatelessWidget {
  const GiftCardPage({super.key});

  static const Color _pageBackground = Color(0xFFF8FAFC);
  static const Color _surfaceContainer = Color(0xFFF1F5F9);
  static const Color _surfaceLowest = Colors.white;
  static const Color _brandBlue = Color(0xFF00288E);
  static const Color _primaryBlue = Color(0xFF1E40AF);
  static const Color _titleColor = Color(0xFF0F172A);
  static const Color _bodyColor = Color(0xFF444653);
  static const Color _mutedColor = Color(0xFF94A3B8);
  static const Color _successColor = Color(0xFF16A34A);
  static const Color _dangerColor = Color(0xFFDC2626);

  GiftCardController get _controller => Get.isRegistered<GiftCardController>()
      ? Get.find<GiftCardController>()
      : Get.put(GiftCardController());

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top + 88;
    final bottomPadding = MediaQuery.of(context).padding.bottom + 122;
    final controller = _controller;

    return Scaffold(
      backgroundColor: _pageBackground,
      body: Stack(
        children: [
          ListView(
            physics: const ClampingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(24, topPadding, 24, bottomPadding),
            children: [
              Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 672),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _GiftCardSummary(controller: controller),
                      const SizedBox(height: 32),
                      _GiftCardFilters(controller: controller),
                      const SizedBox(height: 24),
                      _GiftCardList(controller: controller),
                    ],
                  ),
                ),
              ),
            ],
          ),
          _GiftCardTopBar(
            title: 'app.user.wallet.gift'.tr,
            actionLabel: 'Add Card',
            onAction: () => Get.toNamed(Routers.WALLET_GIFT_CARD_CREATE),
          ),
          const _GiftCardBottomBar(),
        ],
      ),
    );
  }

  static String formatMoney(double value) => '\$${value.toStringAsFixed(2)}';

  static String statusLabel(GiftCardStatus status) {
    return switch (status) {
      GiftCardStatus.available => 'AVAILABLE',
      GiftCardStatus.used => 'USED',
      GiftCardStatus.expired => 'EXPIRED',
    };
  }
}

class _GiftCardTopBar extends StatelessWidget {
  const _GiftCardTopBar({
    required this.title,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            color: Colors.white.withValues(alpha: 0.82),
            padding: EdgeInsets.only(top: topInset),
            child: SizedBox(
              height: 64,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Material(
                      color: Colors.transparent,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => Navigator.of(context).maybePop(),
                        child: const SizedBox(
                          width: 32,
                          height: 32,
                          child: Icon(
                            Icons.arrow_back,
                            size: 22,
                            color: Color(0xFF1E3A8A),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: GiftCardPage._titleColor,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          height: 28 / 18,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: onAction,
                      style: TextButton.styleFrom(
                        foregroundColor: GiftCardPage._brandBlue,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: const Size(0, 40),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        actionLabel,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          height: 20 / 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GiftCardSummary extends StatelessWidget {
  const _GiftCardSummary({required this.controller});

  final GiftCardController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'TOTAL BALANCE',
            style: TextStyle(
              color: GiftCardPage._bodyColor,
              fontSize: 12,
              fontWeight: FontWeight.w500,
              height: 16 / 12,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 16,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                GiftCardPage.formatMoney(controller.totalBalance),
                style: const TextStyle(
                  color: GiftCardPage._titleColor,
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  height: 40 / 36,
                ),
              ),
              _SummaryPill(
                color: const Color(0xFF22C55E),
                label: '${controller.availableCount} Available',
              ),
              _SummaryPill(
                color: const Color(0xFFCBD5E1),
                label: '${controller.usedCount} Used',
              ),
            ],
          ),
        ],
      );
    });
  }
}

class _SummaryPill extends StatelessWidget {
  const _SummaryPill({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: GiftCardPage._bodyColor,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            height: 16 / 12,
          ),
        ),
      ],
    );
  }
}

class _GiftCardFilters extends StatelessWidget {
  const _GiftCardFilters({required this.controller});

  final GiftCardController controller;

  @override
  Widget build(BuildContext context) {
    final filters = <(GiftCardFilter, String)>[
      (GiftCardFilter.all, 'All'),
      (GiftCardFilter.available, 'Available'),
      (GiftCardFilter.used, 'Used'),
      (GiftCardFilter.expired, 'Expired'),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Obx(() {
        return Row(
          children: [
            for (final item in filters) ...[
              _FilterChipButton(
                label: item.$2,
                selected: controller.selectedFilter.value == item.$1,
                onTap: () => controller.setFilter(item.$1),
              ),
              const SizedBox(width: 8),
            ],
          ],
        );
      }),
    );
  }
}

class _FilterChipButton extends StatelessWidget {
  const _FilterChipButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? GiftCardPage._brandBlue
          : GiftCardPage._surfaceContainer,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : GiftCardPage._bodyColor,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              height: 16 / 12,
            ),
          ),
        ),
      ),
    );
  }
}

class _GiftCardList extends StatelessWidget {
  const _GiftCardList({required this.controller});

  final GiftCardController controller;

  Future<void> _copyCode(GiftCardItem item) async {
    await Clipboard.setData(ClipboardData(text: item.code));
    AppSnackbar.success('app.system.message.copy_success'.tr);
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final cards = controller.filteredCards;
      if (cards.isEmpty) {
        return const _GiftCardEmptyState();
      }

      return Column(
        children: [
          for (var index = 0; index < cards.length; index += 1) ...[
            if (index > 0) const SizedBox(height: 16),
            _GiftCardTile(
              item: cards[index],
              onCopy: () => _copyCode(cards[index]),
              onRemove: () => controller.removeCard(cards[index]),
            ),
          ],
        ],
      );
    });
  }
}

class _GiftCardEmptyState extends StatelessWidget {
  const _GiftCardEmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      decoration: BoxDecoration(
        color: GiftCardPage._surfaceLowest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(15, 23, 42, 0.04),
            blurRadius: 20,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: const Column(
        children: [
          Icon(
            Icons.card_giftcard_rounded,
            size: 36,
            color: GiftCardPage._mutedColor,
          ),
          SizedBox(height: 12),
          Text(
            'No gift cards here',
            style: TextStyle(
              color: GiftCardPage._bodyColor,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _GiftCardTile extends StatelessWidget {
  const _GiftCardTile({
    required this.item,
    required this.onCopy,
    required this.onRemove,
  });

  final GiftCardItem item;
  final VoidCallback onCopy;
  final VoidCallback onRemove;

  Color get _statusColor {
    return switch (item.status) {
      GiftCardStatus.available => GiftCardPage._successColor,
      GiftCardStatus.used => GiftCardPage._bodyColor,
      GiftCardStatus.expired => GiftCardPage._dangerColor,
    };
  }

  Color get _iconBackground {
    return switch (item.status) {
      GiftCardStatus.available => const Color.fromRGBO(0, 40, 142, 0.10),
      GiftCardStatus.used => GiftCardPage._surfaceContainer,
      GiftCardStatus.expired => const Color(0xFFFEE2E2),
    };
  }

  Color get _iconColor {
    return switch (item.status) {
      GiftCardStatus.available => GiftCardPage._brandBlue,
      GiftCardStatus.used => GiftCardPage._mutedColor,
      GiftCardStatus.expired => const Color(0xFFF87171),
    };
  }

  Color get _amountColor {
    return item.status == GiftCardStatus.expired
        ? const Color(0xFFCBD5E1)
        : GiftCardPage._titleColor;
  }

  @override
  Widget build(BuildContext context) {
    final muted = item.status != GiftCardStatus.available;
    return Container(
      padding: const EdgeInsets.all(21),
      decoration: BoxDecoration(
        color: GiftCardPage._surfaceLowest.withValues(alpha: muted ? 0.76 : 1),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(15, 23, 42, 0.05),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _iconBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.card_giftcard_rounded,
                  size: 22,
                  color: _iconColor,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.ownerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: muted
                            ? GiftCardPage._bodyColor
                            : GiftCardPage._titleColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        height: 24 / 16,
                      ),
                    ),
                    Text(
                      GiftCardPage.statusLabel(item.status),
                      style: TextStyle(
                        color: _statusColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        height: 15 / 10,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                GiftCardPage.formatMoney(item.amount),
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: _amountColor,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  height: 32 / 24,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Text(
                  item.maskedCode,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: muted
                        ? const Color(0xFFCBD5E1)
                        : GiftCardPage._mutedColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    height: 16 / 12,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              if (item.status == GiftCardStatus.available)
                _CopyButton(onTap: onCopy)
              else if (item.status == GiftCardStatus.expired)
                _RemoveRecordButton(onTap: onRemove)
              else
                Text(
                  item.statusNote?.toUpperCase() ?? 'REDEEMED',
                  style: const TextStyle(
                    color: GiftCardPage._mutedColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    height: 15 / 10,
                    letterSpacing: 1,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CopyButton extends StatelessWidget {
  const _CopyButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: GiftCardPage._pageBackground,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.copy_rounded,
                size: 14,
                color: GiftCardPage._brandBlue,
              ),
              const SizedBox(width: 8),
              Text(
                'app.common.copy'.tr.toUpperCase(),
                style: const TextStyle(
                  color: GiftCardPage._brandBlue,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  height: 16 / 12,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RemoveRecordButton extends StatelessWidget {
  const _RemoveRecordButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: GiftCardPage._dangerColor,
        padding: const EdgeInsets.symmetric(horizontal: 0),
        minimumSize: const Size(0, 32),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: const Text(
        'REMOVE RECORD',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          height: 15 / 10,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

class _GiftCardBottomBar extends StatelessWidget {
  const _GiftCardBottomBar();

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            color: Colors.white.withValues(alpha: 0.9),
            padding: EdgeInsets.fromLTRB(24, 12, 24, bottomInset + 18),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _BottomNavItem(
                  icon: Icons.account_balance_outlined,
                  label: 'GALLERY',
                ),
                _BottomNavItem(
                  icon: Icons.account_balance_wallet_rounded,
                  label: 'WALLET',
                  active: true,
                ),
                _BottomNavItem(
                  icon: Icons.confirmation_number_outlined,
                  label: 'EVENTS',
                ),
                _BottomNavItem(
                  icon: Icons.person_outline_rounded,
                  label: 'PROFILE',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  const _BottomNavItem({
    required this.icon,
    required this.label,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? GiftCardPage._brandBlue : const Color(0xFF94A3B8);
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            height: 15 / 10,
            letterSpacing: 1,
          ),
        ),
      ],
    );

    if (!active) {
      return Opacity(opacity: 0.6, child: content);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: GiftCardPage._primaryBlue.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
      ),
      child: content,
    );
  }
}
