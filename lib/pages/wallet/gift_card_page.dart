import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:tronskins_app/api/model/wallet/wallet_models.dart';
import 'package:tronskins_app/common/hooks/currency/CurrencyController.dart';
import 'package:tronskins_app/common/utils/app_snackbar.dart';
import 'package:tronskins_app/controllers/wallet/gift_card_controller.dart';
import 'package:tronskins_app/routes/app_routes.dart';

class GiftCardPage extends StatefulWidget {
  const GiftCardPage({super.key});

  @override
  State<GiftCardPage> createState() => _GiftCardPageState();
}

class _GiftCardPageState extends State<GiftCardPage> {
  static const Color _pageBackground = Color(0xFFF8FAFC);
  static const Color _surfaceContainer = Color(0xFFF1F5F9);
  static const Color _surfaceLowest = Colors.white;
  static const Color _brandBlue = Color(0xFF00288E);
  static const Color _titleColor = Color(0xFF0F172A);
  static const Color _bodyColor = Color(0xFF444653);
  static const Color _mutedColor = Color(0xFF94A3B8);
  static const Color _successColor = Color(0xFF16A34A);

  final GiftCardController controller = Get.isRegistered<GiftCardController>()
      ? Get.find<GiftCardController>()
      : Get.put(GiftCardController());
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    controller.loadCards(reset: true);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) {
      return;
    }
    if (_scrollController.position.pixels >
        _scrollController.position.maxScrollExtent - 240) {
      controller.loadCards();
    }
  }

  Future<void> _openCreatePage() async {
    await Get.toNamed(Routers.WALLET_GIFT_CARD_CREATE);
    if (mounted) {
      await controller.loadCards(reset: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top + 88;
    final bottomPadding = MediaQuery.of(context).padding.bottom + 32;

    return Scaffold(
      backgroundColor: _pageBackground,
      body: Stack(
        children: [
          RefreshIndicator(
            color: _brandBlue,
            backgroundColor: Colors.white,
            onRefresh: () => controller.loadCards(reset: true),
            child: ListView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(
                parent: ClampingScrollPhysics(),
              ),
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
          ),
          _GiftCardTopBar(
            title: 'app.user.wallet.gift'.tr,
            actionLabel: 'app.user.gift_card.generate'.tr,
            onAction: _openCreatePage,
          ),
        ],
      ),
    );
  }

  static String formatMoney(double value) {
    final currency = Get.find<CurrencyController>();
    return currency.formatUsd(value).replaceFirst('\$ ', r'$');
  }

  static String statusLabel(WalletGiftCardItem item) {
    return item.isUsed
        ? 'app.user.gift_card.status_used'.tr.toUpperCase()
        : 'app.user.gift_card.status_available'.tr.toUpperCase();
  }

  static String formatDate(int? timestamp) {
    if (timestamp == null) {
      return '';
    }
    return DateFormat(
      'yyyy-MM-dd HH:mm',
    ).format(DateTime.fromMillisecondsSinceEpoch(timestamp).toLocal());
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
                          color: _GiftCardPageState._titleColor,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          height: 28 / 18,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: onAction,
                      style: TextButton.styleFrom(
                        foregroundColor: _GiftCardPageState._brandBlue,
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
          Text(
            'app.user.gift_card.total_balance'.tr.toUpperCase(),
            style: const TextStyle(
              color: _GiftCardPageState._bodyColor,
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
                _GiftCardPageState.formatMoney(controller.totalBalance),
                style: const TextStyle(
                  color: _GiftCardPageState._titleColor,
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  height: 40 / 36,
                ),
              ),
              _SummaryPill(
                color: const Color(0xFF22C55E),
                label: 'app.user.gift_card.available_count'.trArgs([
                  '${controller.availableCount}',
                ]),
              ),
              _SummaryPill(
                color: const Color(0xFFCBD5E1),
                label: 'app.user.gift_card.used_count'.trArgs([
                  '${controller.usedCount}',
                ]),
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
            color: _GiftCardPageState._bodyColor,
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
      (GiftCardFilter.all, 'app.common.all'.tr),
      (GiftCardFilter.available, 'app.user.gift_card.available'.tr),
      (GiftCardFilter.used, 'app.user.gift_card.used'.tr),
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
          ? _GiftCardPageState._brandBlue
          : _GiftCardPageState._surfaceContainer,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : _GiftCardPageState._bodyColor,
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

  Future<void> _copyPassword(WalletGiftCardItem item) async {
    final password = await controller.loadPassword(item);
    if (password == null || password.isEmpty) {
      AppSnackbar.error('app.user.gift_card.password_load_failed'.tr);
      return;
    }
    await Clipboard.setData(ClipboardData(text: password));
    AppSnackbar.success('app.system.message.copy_success'.tr);
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final cards = controller.cards.toList(growable: false);
      final loading = controller.isLoadingCards.value;
      if (loading && cards.isEmpty) {
        return const _GiftCardSkeletonList();
      }
      if (cards.isEmpty) {
        return const _GiftCardEmptyState();
      }

      return Column(
        children: [
          for (var index = 0; index < cards.length; index += 1) ...[
            if (index > 0) const SizedBox(height: 16),
            _GiftCardTile(
              item: cards[index],
              onCopyPassword: () => _copyPassword(cards[index]),
            ),
          ],
          if (controller.isLoadingMoreCards.value) ...[
            const SizedBox(height: 18),
            const Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
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
        color: _GiftCardPageState._surfaceLowest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(15, 23, 42, 0.04),
            blurRadius: 20,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          const Icon(
            Icons.card_giftcard_rounded,
            size: 36,
            color: _GiftCardPageState._mutedColor,
          ),
          const SizedBox(height: 12),
          Text(
            'app.user.gift_card.empty'.tr,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _GiftCardPageState._bodyColor,
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
  const _GiftCardTile({required this.item, required this.onCopyPassword});

  final WalletGiftCardItem item;
  final VoidCallback onCopyPassword;

  Color get _statusColor {
    return item.isAvailable
        ? _GiftCardPageState._successColor
        : _GiftCardPageState._bodyColor;
  }

  Color get _iconBackground {
    return item.isAvailable
        ? const Color.fromRGBO(0, 40, 142, 0.10)
        : _GiftCardPageState._surfaceContainer;
  }

  Color get _iconColor {
    return item.isAvailable
        ? _GiftCardPageState._brandBlue
        : _GiftCardPageState._mutedColor;
  }

  @override
  Widget build(BuildContext context) {
    final muted = item.isUsed;
    final chargeUser = item.chargeUser?.trim();
    final userLabel = chargeUser == null || chargeUser.isEmpty
        ? 'app.common.none'.tr
        : chargeUser;
    final usedDate = _GiftCardPageState.formatDate(item.chargeTime);
    return Container(
      padding: const EdgeInsets.all(21),
      decoration: BoxDecoration(
        color: _GiftCardPageState._surfaceLowest.withValues(
          alpha: muted ? 0.76 : 1,
        ),
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
                      userLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: muted
                            ? _GiftCardPageState._bodyColor
                            : _GiftCardPageState._titleColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        height: 24 / 16,
                      ),
                    ),
                    Text(
                      _GiftCardPageState.statusLabel(item),
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
                _GiftCardPageState.formatMoney(item.value),
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: muted
                      ? const Color(0xFFCBD5E1)
                      : _GiftCardPageState._titleColor,
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
                  item.maskedCardNumber,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: muted
                        ? const Color(0xFFCBD5E1)
                        : _GiftCardPageState._mutedColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    height: 16 / 12,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              if (item.isAvailable)
                _CopyButton(onTap: onCopyPassword)
              else
                Text(
                  usedDate.isEmpty
                      ? 'app.user.gift_card.status_used'.tr.toUpperCase()
                      : 'app.user.gift_card.redeemed_at'.trArgs([usedDate]),
                  style: const TextStyle(
                    color: _GiftCardPageState._mutedColor,
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
      color: _GiftCardPageState._pageBackground,
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
                color: _GiftCardPageState._brandBlue,
              ),
              const SizedBox(width: 8),
              Text(
                'app.common.copy'.tr.toUpperCase(),
                style: const TextStyle(
                  color: _GiftCardPageState._brandBlue,
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

class _GiftCardSkeletonList extends StatelessWidget {
  const _GiftCardSkeletonList();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        3,
        (index) => Padding(
          padding: EdgeInsets.only(top: index == 0 ? 0 : 16),
          child: Container(
            height: 150,
            decoration: BoxDecoration(
              color: _GiftCardPageState._surfaceLowest,
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.all(21),
            child: Column(
              children: [
                Row(
                  children: [
                    _SkeletonBox(width: 48, height: 48, radius: 12),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SkeletonBox(width: 120, height: 16, radius: 4),
                          SizedBox(height: 8),
                          _SkeletonBox(width: 68, height: 10, radius: 4),
                        ],
                      ),
                    ),
                    _SkeletonBox(width: 96, height: 24, radius: 4),
                  ],
                ),
                const Spacer(),
                const Row(
                  children: [
                    Expanded(child: _SkeletonBox(height: 12, radius: 4)),
                    SizedBox(width: 24),
                    _SkeletonBox(width: 88, height: 34, radius: 8),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  const _SkeletonBox({this.width, required this.height, required this.radius});

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
