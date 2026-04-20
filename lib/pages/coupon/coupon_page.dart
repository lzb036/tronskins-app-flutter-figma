import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:tronskins_app/api/model/wallet/wallet_models.dart';
import 'package:tronskins_app/common/hooks/currency/CurrencyController.dart';
import 'package:tronskins_app/common/widgets/back_to_top_overlay.dart';
import 'package:tronskins_app/common/widgets/login_required_prompt.dart';
import 'package:tronskins_app/common/widgets/settings_style_app_bar.dart';
import 'package:tronskins_app/controllers/user/user_controller.dart';
import 'package:tronskins_app/controllers/wallet/coupon_controller.dart';

class CouponPage extends StatefulWidget {
  const CouponPage({super.key});

  @override
  State<CouponPage> createState() => _CouponPageState();
}

class _CouponPageState extends State<CouponPage> {
  static const _pageBg = Color(0xFFF7F9FB);
  static const _ink = Color(0xFF0F172A);
  static const _body = Color(0xFF444653);
  static const _muted = Color(0xFF64748B);
  static const _blue = Color(0xFF00288E);
  static const _lightPanel = Color(0xFFF2F4F6);
  static const _danger = Color(0xFFBA1A1A);

  final CouponController controller = Get.isRegistered<CouponController>()
      ? Get.find<CouponController>()
      : Get.put(CouponController());
  final UserController userController = Get.find<UserController>();
  final CurrencyController currency = Get.find<CurrencyController>();

  Worker? _loginWorker;

  @override
  void initState() {
    super.initState();
    if (userController.isLoggedIn.value) {
      _refreshData();
    }
    _loginWorker = ever<bool>(userController.isLoggedIn, (loggedIn) {
      if (loggedIn) {
        _refreshData();
      } else {
        controller.coupons.clear();
      }
    });
  }

  @override
  void dispose() {
    _loginWorker?.dispose();
    super.dispose();
  }

  Future<void> _refreshData() async {
    await Future.wait([
      controller.loadCoupons(),
      userController.fetchUserData(showLoading: false),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (!userController.isLoggedIn.value) {
        return const Scaffold(
          backgroundColor: _pageBg,
          body: LoginRequiredPrompt(),
        );
      }

      final giftValue = userController.giftValue;
      final coupons = controller.coupons.toList(growable: false);
      final stats = _GiftStats.from(coupons: coupons, giftValue: giftValue);
      final cards = _buildGiftCards(coupons: coupons, giftValue: giftValue);

      return BackToTopScope(
        enabled: false,
        child: Scaffold(
          backgroundColor: _pageBg,
          body: Stack(
            children: [
              Positioned.fill(
                child: RefreshIndicator(
                  color: _blue,
                  backgroundColor: Colors.white,
                  onRefresh: _refreshData,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(24, 96, 24, 32),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 672),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildOverviewBanner(giftValue, stats),
                            const SizedBox(height: 32),
                            _buildStatusTabs(stats),
                            const SizedBox(height: 32),
                            if (controller.isLoading.value && coupons.isEmpty)
                              const _GiftCardSkeletonList()
                            else
                              _buildCardList(cards),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              _buildTopNavigation(context),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildTopNavigation(BuildContext context) {
    return SettingsStyleTopNavigation(
      title: 'My Gift Cards',
      onBack: () => Navigator.of(context).maybePop(),
      actions: [
        InkWell(
          customBorder: const CircleBorder(),
          onTap: () {},
          child: const SizedBox(
            width: 20,
            height: 20,
            child: Icon(Icons.add, color: _ink, size: 20),
          ),
        ),
      ],
    );
  }

  Widget _buildOverviewBanner(double giftValue, _GiftStats stats) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3B82F6), Color(0xFF1E40AF)],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.10),
            blurRadius: 25,
            offset: Offset(0, 20),
            spreadRadius: -5,
          ),
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.10),
            blurRadius: 10,
            offset: Offset(0, 8),
            spreadRadius: -6,
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: -72,
            bottom: -72,
            child: Container(
              width: 192,
              height: 192,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'TOTAL PORTFOLIO VALUE',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.80),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 16 / 12,
                      letterSpacing: 1.2,
                    ),
                  ),
                  Icon(
                    Icons.select_all_rounded,
                    color: Colors.white.withValues(alpha: 0.82),
                    size: 20,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _formatGiftAmount(giftValue),
                        maxLines: 1,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                          height: 40 / 36,
                          letterSpacing: -1,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Text(
                      currency.code,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.70),
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        height: 20 / 14,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.only(top: 17),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: Colors.white.withValues(alpha: 0.10),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    _buildStatItem('AVAILABLE', stats.available),
                    _buildStatItem('USED', stats.used),
                    _buildStatItem('EXPIRED', stats.expired),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, int value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.70),
              fontSize: 10,
              fontWeight: FontWeight.w500,
              height: 15 / 10,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value.toString().padLeft(2, '0'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              height: 28 / 18,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusTabs(_GiftStats stats) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildFilterPill('All (${stats.total})', active: true),
          const SizedBox(width: 8),
          _buildFilterPill('Available (${stats.available})'),
          const SizedBox(width: 8),
          _buildFilterPill('Used'),
        ],
      ),
    );
  }

  Widget _buildFilterPill(String label, {bool active = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: active ? const Color(0xFF191C1E) : const Color(0xFFE6E8EA),
        borderRadius: BorderRadius.circular(999),
        boxShadow: active
            ? const [
                BoxShadow(
                  color: Color.fromRGBO(0, 0, 0, 0.10),
                  blurRadius: 6,
                  offset: Offset(0, 4),
                  spreadRadius: -1,
                ),
              ]
            : null,
      ),
      child: Text(
        label,
        style: TextStyle(
          color: active ? Colors.white : _body,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          height: 20 / 14,
        ),
      ),
    );
  }

  Widget _buildCardList(List<_GiftCardDisplayData> cards) {
    return Column(
      children: [
        for (int index = 0; index < cards.length; index++) ...[
          _buildGiftCard(cards[index]),
          if (index != cards.length - 1) const SizedBox(height: 24),
        ],
      ],
    );
  }

  Widget _buildGiftCard(_GiftCardDisplayData card) {
    return Opacity(
      opacity: card.opacity,
      child: Stack(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [
                BoxShadow(
                  color: Color.fromRGBO(0, 0, 0, 0.05),
                  blurRadius: 2,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    _buildGiftLogo(card),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            card.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: card.textMuted ? _muted : _ink,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              height: 20 / 16,
                            ),
                          ),
                          Text(
                            card.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: card.statusColor ?? _muted,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              height: 15 / 10,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          card.amount,
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            color: card.amountColor,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            height: 25 / 20,
                            decoration: card.strikeAmount
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                        if (card.dateLabel != null) ...[
                          const SizedBox(height: 1),
                          Text(
                            card.dateLabel!,
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              color: card.dateColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              height: 15 / 10,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _lightPanel,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          card.code,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: card.codeColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            height: 20 / 14,
                            letterSpacing: 1.4,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      _buildCardAction(card),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            bottom: 0,
            child: Container(
              width: 4,
              decoration: BoxDecoration(
                color: card.accent,
                borderRadius: const BorderRadius.horizontal(
                  right: Radius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGiftLogo(_GiftCardDisplayData card) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: card.logoBg,
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: Icon(card.icon, size: 23, color: card.logoColor),
    );
  }

  Widget _buildCardAction(_GiftCardDisplayData card) {
    switch (card.actionType) {
      case _GiftActionType.copy:
        return const Icon(Icons.copy_rounded, color: _body, size: 18);
      case _GiftActionType.link:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Text(
              'Usage Record',
              style: TextStyle(
                color: _blue,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                height: 16.5 / 11,
              ),
            ),
            SizedBox(width: 4),
            Icon(Icons.open_in_new_rounded, color: _blue, size: 12),
          ],
        );
      case _GiftActionType.delete:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
          decoration: BoxDecoration(
            border: Border.all(color: _danger.withValues(alpha: 0.30)),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Text(
            'Delete Record',
            style: TextStyle(
              color: _danger,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              height: 16.5 / 11,
            ),
          ),
        );
    }
  }

  List<_GiftCardDisplayData> _buildGiftCards({
    required List<WalletCouponRecord> coupons,
    required double giftValue,
  }) {
    final firstCoupon = coupons.isNotEmpty ? coupons.first : null;
    final secondCoupon = coupons.length > 1 ? coupons[1] : null;
    final thirdCoupon = coupons.length > 2 ? coupons[2] : null;
    final realGiftAmount = _formatGiftAmount(giftValue);
    final zeroAmount = _formatGiftAmount(0);

    return [
      _GiftCardDisplayData.available(
        title: firstCoupon?.typeName ?? 'Steam Wallet',
        amount: realGiftAmount,
        code: _codeFromCoupon(firstCoupon, fallback: 'ACTIVE-GIFT-BALANCE'),
        dateLabel: _validDateLabel(firstCoupon) ?? 'Valid thru --/----',
      ),
      _GiftCardDisplayData.used(
        title: secondCoupon?.typeName ?? 'Perfect World',
        amount: zeroAmount,
        code: _maskedCode(secondCoupon?.id, fallback: '****-****-****-7890'),
      ),
      _GiftCardDisplayData.expired(
        title: thirdCoupon?.typeName ?? 'Epic Games Store',
        amount: zeroAmount,
        code: _maskedCode(thirdCoupon?.id, fallback: '****-****-****-****'),
        dateLabel: _expiredDateLabel(thirdCoupon) ?? 'Expired --/----',
      ),
    ];
  }

  String _formatGiftAmount(double value) {
    return currency.format(value).replaceAll(' ', '');
  }

  String _codeFromCoupon(
    WalletCouponRecord? coupon, {
    required String fallback,
  }) {
    final raw = coupon?.id;
    if (raw == null || raw.isEmpty) {
      return fallback;
    }
    return _groupCode(raw);
  }

  String _maskedCode(String? raw, {required String fallback}) {
    if (raw == null || raw.length < 4) {
      return fallback;
    }
    final suffix = raw.substring(raw.length - 4);
    return '****-****-****-$suffix';
  }

  String _groupCode(String raw) {
    final clean = raw.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
    if (clean.isEmpty) {
      return raw;
    }
    final groups = <String>[];
    for (var index = 0; index < clean.length; index += 4) {
      final end = (index + 4).clamp(0, clean.length);
      groups.add(clean.substring(index, end));
    }
    return groups.join('-');
  }

  String? _validDateLabel(WalletCouponRecord? coupon) {
    final expireTime = coupon?.expireTime;
    if (expireTime == null || expireTime <= 0) {
      return null;
    }
    final date = DateTime.fromMillisecondsSinceEpoch(expireTime * 1000);
    return 'Valid thru ${DateFormat('MM/yyyy').format(date)}';
  }

  String? _expiredDateLabel(WalletCouponRecord? coupon) {
    final expireTime = coupon?.expireTime;
    if (expireTime == null || expireTime <= 0) {
      return null;
    }
    final date = DateTime.fromMillisecondsSinceEpoch(expireTime * 1000);
    return 'Expired ${DateFormat('MM/yyyy').format(date)}';
  }
}

class _GiftStats {
  const _GiftStats({
    required this.total,
    required this.available,
    required this.used,
    required this.expired,
  });

  final int total;
  final int available;
  final int used;
  final int expired;

  factory _GiftStats.from({
    required List<WalletCouponRecord> coupons,
    required double giftValue,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final expired = coupons
        .where((item) => item.expireTime != null && item.expireTime! <= now)
        .length;
    final activeCoupons = coupons.length - expired;
    final available = giftValue > 0
        ? activeCoupons.clamp(1, 99)
        : activeCoupons;
    final total = coupons.isNotEmpty ? coupons.length : (giftValue > 0 ? 1 : 0);
    final used = (total - available - expired).clamp(0, 99);
    return _GiftStats(
      total: total,
      available: available,
      used: used,
      expired: expired,
    );
  }
}

enum _GiftActionType { copy, link, delete }

class _GiftCardDisplayData {
  const _GiftCardDisplayData({
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.code,
    required this.accent,
    required this.amountColor,
    required this.logoBg,
    required this.logoColor,
    required this.icon,
    required this.codeColor,
    required this.actionType,
    required this.opacity,
    this.dateLabel,
    this.dateColor = _CouponPageState._muted,
    this.statusColor,
    this.strikeAmount = false,
    this.textMuted = false,
  });

  factory _GiftCardDisplayData.available({
    required String title,
    required String amount,
    required String code,
    required String dateLabel,
  }) {
    return _GiftCardDisplayData(
      title: title,
      subtitle: 'DIGITAL CODE',
      amount: amount,
      code: code,
      dateLabel: dateLabel,
      accent: const Color(0xFF1E40AF),
      amountColor: _CouponPageState._blue,
      logoBg: _CouponPageState._ink,
      logoColor: Colors.white,
      icon: Icons.account_balance_wallet_rounded,
      codeColor: const Color(0xFF1E293B),
      actionType: _GiftActionType.copy,
      opacity: 1,
    );
  }

  factory _GiftCardDisplayData.used({
    required String title,
    required String amount,
    required String code,
  }) {
    return _GiftCardDisplayData(
      title: title,
      subtitle: 'STATUS: REDEEMED',
      amount: amount,
      code: code,
      accent: _CouponPageState._danger,
      amountColor: const Color(0xFF94A3B8),
      logoBg: const Color.fromRGBO(186, 26, 26, 0.10),
      logoColor: _CouponPageState._danger,
      icon: Icons.verified_rounded,
      codeColor: const Color(0xFF94A3B8),
      actionType: _GiftActionType.link,
      opacity: 0.70,
      statusColor: _CouponPageState._danger,
      strikeAmount: true,
    );
  }

  factory _GiftCardDisplayData.expired({
    required String title,
    required String amount,
    required String code,
    required String dateLabel,
  }) {
    return _GiftCardDisplayData(
      title: title,
      subtitle: 'STATUS: EXPIRED',
      amount: amount,
      code: code,
      dateLabel: dateLabel,
      accent: const Color(0xFF94A3B8),
      amountColor: const Color(0xFF94A3B8),
      logoBg: const Color(0xFFF1F5F9),
      logoColor: const Color(0xFF64748B),
      icon: Icons.local_offer_rounded,
      codeColor: const Color(0xFF94A3B8),
      actionType: _GiftActionType.delete,
      opacity: 0.60,
      dateColor: _CouponPageState._danger,
      textMuted: true,
    );
  }

  final String title;
  final String subtitle;
  final String amount;
  final String code;
  final String? dateLabel;
  final Color accent;
  final Color amountColor;
  final Color logoBg;
  final Color logoColor;
  final IconData icon;
  final Color codeColor;
  final Color dateColor;
  final Color? statusColor;
  final _GiftActionType actionType;
  final double opacity;
  final bool strikeAmount;
  final bool textMuted;
}

class _GiftCardSkeletonList extends StatelessWidget {
  const _GiftCardSkeletonList();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        _GiftCardSkeleton(),
        SizedBox(height: 24),
        _GiftCardSkeleton(),
        SizedBox(height: 24),
        _GiftCardSkeleton(),
      ],
    );
  }
}

class _GiftCardSkeleton extends StatelessWidget {
  const _GiftCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: const [
              _GiftSkeletonBox(width: 40, height: 40, radius: 8),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _GiftSkeletonBox(width: 112, height: 16, radius: 8),
                    SizedBox(height: 8),
                    _GiftSkeletonBox(width: 72, height: 10, radius: 5),
                  ],
                ),
              ),
              _GiftSkeletonBox(width: 64, height: 22, radius: 8),
            ],
          ),
          const SizedBox(height: 16),
          const _GiftSkeletonBox(height: 46, radius: 8),
        ],
      ),
    );
  }
}

class _GiftSkeletonBox extends StatelessWidget {
  const _GiftSkeletonBox({
    this.width,
    required this.height,
    required this.radius,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFE8EDF3),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
