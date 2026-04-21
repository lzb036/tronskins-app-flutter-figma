import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:tronskins_app/common/hooks/currency/CurrencyController.dart';
import 'package:tronskins_app/common/utils/app_snackbar.dart';
import 'package:tronskins_app/common/widgets/back_to_top_overlay.dart';
import 'package:tronskins_app/common/widgets/glass_notice_dialog.dart';
import 'package:tronskins_app/common/widgets/settings_style_app_bar.dart';
import 'package:tronskins_app/controllers/wallet/wallet_controller.dart';
import 'package:tronskins_app/routes/app_routes.dart';

class WalletRechargePage extends StatefulWidget {
  const WalletRechargePage({super.key});

  @override
  State<WalletRechargePage> createState() => _WalletRechargePageState();
}

class _WalletRechargePageState extends State<WalletRechargePage>
    with SingleTickerProviderStateMixin {
  static const Color _pageBackground = Color(0xFFF7F9FB);
  static const Color _brandBlue = Color(0xFF00288E);
  static const Color _brandBlueSoft = Color(0xFFEFF6FF);
  static const Color _brandBlueLight = Color(0xFF3B82F6);
  static const Color _panelBorder = Color(0xFFE0E3E5);
  static const Color _fieldFill = Color(0xFFE0E3E5);
  static const Color _softPanel = Color(0xFFF2F4F6);
  static const Color _strongText = Color(0xFF191C1E);
  static const Color _bodyText = Color(0xFF444653);
  static const Color _mutedText = Color(0xFF757684);
  static const Color _lineMuted = Color(0xFFC4C5D5);
  static const Color _skeletonBase = Color(0xFFE7ECF3);
  static const Color _skeletonHighlight = Color(0xFFF4F7FB);

  final WalletController controller = Get.isRegistered<WalletController>()
      ? Get.find<WalletController>()
      : Get.put(WalletController());

  late final TabController _tabController;
  final TextEditingController _secretKeyController = TextEditingController();
  Timer? _countdownTimer;
  int _remainingSeconds = 0;
  bool _isSubmittingChargeCard = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    controller.refreshUser();
    _loadWallet();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _secretKeyController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadWallet() async {
    await controller.loadOfficialWallet();
    _startCountdown(controller.officialWallet.value?.remainTime ?? 0);
  }

  void _startCountdown(int seconds) {
    _countdownTimer?.cancel();
    _remainingSeconds = seconds;
    if (_remainingSeconds <= 0) {
      setState(() {});
      return;
    }
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds <= 1) {
        timer.cancel();
        _remainingSeconds = 0;
        _loadWallet();
      } else {
        setState(() => _remainingSeconds -= 1);
      }
    });
  }

  String _formatRemaining(int seconds) {
    if (seconds <= 0) {
      return '00:00';
    }
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:'
        '${secs.toString().padLeft(2, '0')}';
  }

  Future<void> _copyAddress(String address) async {
    if (address.isEmpty) {
      _showTopSnack('app.trade.filter.failed'.tr, isError: true);
      return;
    }
    await Clipboard.setData(ClipboardData(text: address));
    if (!mounted) {
      return;
    }
    await showCopySuccessNoticeDialog(context);
  }

  Future<void> _submitChargeCard() async {
    if (_isSubmittingChargeCard) {
      _showTopSnack('app.system.tips.please_wait'.tr);
      return;
    }
    final value = _secretKeyController.text.trim();
    if (value.isEmpty || value.length != 32) {
      _showTopSnack(
        'app.user.recharge.secretKey_placeholder'.tr,
        isError: true,
      );
      return;
    }
    setState(() => _isSubmittingChargeCard = true);
    try {
      final result = await controller.consumeChargeCard(value);
      if (result.success) {
        _secretKeyController.clear();
        _showTopSnack('app.user.recharge.message.success'.tr, isSuccess: true);
        _returnToWalletAndClearRechargeRoute();
        return;
      }
      _showTopSnack(_resolveErrorMessage(result), isError: true);
    } finally {
      if (mounted) {
        setState(() => _isSubmittingChargeCard = false);
      }
    }
  }

  void _showTopSnack(
    String message, {
    bool isError = false,
    bool isSuccess = false,
  }) {
    if (isSuccess) {
      AppSnackbar.success(message);
      return;
    }
    if (isError) {
      AppSnackbar.error(message);
      return;
    }
    AppSnackbar.info(message);
  }

  String? _extractMessage(dynamic data) {
    if (data is String && data.trim().isNotEmpty) {
      return data;
    }
    if (data is Map) {
      for (final key in ['message', 'msg', 'error', 'detail', 'desc']) {
        final value = data[key];
        if (value is String && value.trim().isNotEmpty) {
          return value;
        }
      }
    }
    return null;
  }

  String _resolveErrorMessage(dynamic response) {
    final rawMessage = response?.message;
    if (rawMessage is String && rawMessage.trim().isNotEmpty) {
      return rawMessage;
    }
    final dataMessage = _extractMessage(response?.datas);
    if (dataMessage != null) {
      return dataMessage;
    }
    return 'app.trade.filter.failed'.tr;
  }

  void _returnToWalletAndClearRechargeRoute() {
    var walletFound = false;
    Get.until((route) {
      final isWallet = route.settings.name == Routers.WALLET;
      if (isWallet) {
        walletFound = true;
      }
      return isWallet;
    });
    if (!walletFound) {
      Get.offAllNamed(Routers.WALLET);
    }
  }

  String _remainingTimeLabel() {
    return _formatRemaining(_remainingSeconds);
  }

  String _copyAddressLabel() => 'app.common.copy'.tr;

  String _accountStatusLabel() => 'app.steam.account.status_success'.tr;

  String _securePaymentLabel() => 'Secure Payment';

  String _safetyLabel() => 'app.system.tips.title'.tr;

  String _encryptedTransferLabel() => 'Encrypted';

  String _encryptedTransferDesc() => 'SSL 256-bit encryption';

  String _fastArrivalLabel() => 'Fast arrival';

  String _fastArrivalDesc() => 'Arrives after confirmation';

  String _usdtSafetyNote() => 'app.user.recharge.tips_2'.tr;

  String _giftCardSafetyNote() => 'app.user.recharge.tips_2'.tr;

  void _selectRechargeMode(int index) {
    if (_tabController.index == index) {
      return;
    }
    setState(() => _tabController.animateTo(index));
  }

  @override
  Widget build(BuildContext context) {
    final currency = Get.find<CurrencyController>();
    return BackToTopScope(
      enabled: false,
      child: Scaffold(
        backgroundColor: _pageBackground,
        appBar: SettingsStyleAppBar(
          title: Text('app.user.recharge.title'.tr),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: _RechargeIconAction(
                icon: Icons.receipt_long_outlined,
                tooltip: 'app.user.wallet.recharge_record'.tr,
                onTap: () => Get.toNamed(Routers.WALLET_RECHARGE_RECORD),
              ),
            ),
          ],
        ),
        body: AnimatedBuilder(
          animation: _tabController,
          builder: (context, _) =>
              Obx(() => _buildRechargePage(context, currency)),
        ),
      ),
    );
  }

  Widget _buildRechargePage(BuildContext context, CurrencyController currency) {
    final balance = controller.userInfo.value?.fund?.balance ?? 0;
    final address = (controller.officialWallet.value?.walletAddress ?? '')
        .trim();
    final loadingWallet = controller.isLoadingOfficialWallet.value;
    final isUsdtMode = _tabController.index == 0;

    return _buildPageScroll(
      context: context,
      horizontalPadding: 16,
      maxWidth: 512,
      children: [
        _buildBalanceCard(
          amount: currency.formatUsd(balance),
          title: 'app.user.wallet.account'.tr,
        ),
        const SizedBox(height: 24),
        _buildUsdtModeSelector(),
        const SizedBox(height: 16),
        if (isUsdtMode) ...[
          if (loadingWallet)
            _buildLoadingPanel()
          else ...[
            _buildUsdtAddressCard(address),
            const SizedBox(height: 16),
            _buildNoticeArea([
              'app.user.recharge.tips'.tr,
              'app.user.recharge.tips_4'.tr,
              'app.user.recharge.tips_5'.tr,
              'app.user.recharge.tips_2'.tr,
              'app.user.recharge.tips_3'.tr,
            ]),
          ],
          const SizedBox(height: 28),
          _buildFooterDivider(
            _securePaymentLabel(),
            icon: Icons.shield_outlined,
          ),
          const SizedBox(height: 12),
          Text(
            _usdtSafetyNote(),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 11,
              height: 1.6,
            ),
          ),
        ] else ...[
          _buildChargeCardForm(),
          const SizedBox(height: 24),
          _buildChargeCardConfirmButton(),
          const SizedBox(height: 32),
          _buildFooterDivider(_safetyLabel()),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _SecurityFeatureCard(
                  icon: Icons.lock_outline_rounded,
                  title: _encryptedTransferLabel(),
                  description: _encryptedTransferDesc(),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _SecurityFeatureCard(
                  icon: Icons.bolt_outlined,
                  title: _fastArrivalLabel(),
                  description: _fastArrivalDesc(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _giftCardSafetyNote(),
            textAlign: TextAlign.center,
            style: const TextStyle(color: _bodyText, fontSize: 10, height: 1.6),
          ),
        ],
      ],
    );
  }

  Widget _buildPageScroll({
    required BuildContext context,
    required double horizontalPadding,
    required double maxWidth,
    required List<Widget> children,
  }) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        32,
        horizontalPadding,
        bottomInset + 32,
      ),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBalanceCard({
    required String amount,
    required String title,
    bool showStatus = false,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(24, 24, 24, showStatus ? 30 : 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: showStatus ? 0.04 : 0.03),
                blurRadius: showStatus ? 30 : 20,
                offset: Offset(0, showStatus ? 8 : 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _bodyText,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  height: 20 / 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                amount,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _brandBlue,
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  height: 40 / 36,
                  letterSpacing: -0.9,
                ),
              ),
              if (showStatus) ...[
                const SizedBox(height: 16),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xFFD8E2FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.verified_user_outlined,
                          color: Color(0xFF004395),
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _accountStatusLabel(),
                          style: const TextStyle(
                            color: Color(0xFF004395),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            height: 16 / 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (showStatus)
          const Positioned(
            top: 14,
            right: 14,
            child: Icon(
              Icons.account_balance_wallet_outlined,
              color: Color(0xFFD8E2FF),
              size: 54,
            ),
          ),
      ],
    );
  }

  Widget _buildUsdtModeSelector() {
    final activeIndex = _tabController.index;
    return Row(
      children: [
        Expanded(
          child: _RechargeModeTile(
            icon: Icons.currency_exchange_rounded,
            label: 'app.user.wallet.usdt'.tr,
            active: activeIndex == 0,
            onTap: () => _selectRechargeMode(0),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _RechargeModeTile(
            icon: Icons.card_giftcard_rounded,
            label: 'app.user.recharge.card'.tr,
            active: activeIndex == 1,
            onTap: () => _selectRechargeMode(1),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingPanel() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _buildSkeletonBlock(width: 172, height: 16),
              const Spacer(),
              _buildSkeletonBlock(
                width: 92,
                height: 24,
                radius: BorderRadius.circular(999),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
            decoration: BoxDecoration(
              color: _softPanel,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _lineMuted.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                Container(
                  width: 156,
                  height: 156,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: _buildQrSkeletonPattern(),
                ),
                const SizedBox(height: 16),
                _buildSkeletonBlock(width: 232, height: 12),
                const SizedBox(height: 8),
                _buildSkeletonBlock(width: 188, height: 12),
                const SizedBox(height: 12),
                _buildSkeletonBlock(
                  width: 96,
                  height: 18,
                  radius: BorderRadius.circular(8),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQrSkeletonPattern() {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: const Color(0xFFF8FAFC),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 6,
          runSpacing: 6,
          children: List.generate(
            16,
            (index) => _buildSkeletonBlock(
              width: index % 3 == 0 ? 22 : 18,
              height: index.isEven ? 18 : 22,
              radius: BorderRadius.circular(4),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSkeletonBlock({
    required double width,
    required double height,
    BorderRadius? radius,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: radius ?? BorderRadius.circular(4),
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [_skeletonBase, _skeletonHighlight],
        ),
      ),
    );
  }

  Widget _buildUsdtAddressCard(String address) {
    final hasAddress = address.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'app.user.recharge.payment_collection_address'.tr,
                  style: const TextStyle(
                    color: _strongText,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 20 / 14,
                  ),
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: _brandBlueSoft,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.schedule_rounded,
                        color: _brandBlue,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _remainingTimeLabel(),
                        style: const TextStyle(
                          color: _brandBlue,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          height: 16 / 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
            decoration: BoxDecoration(
              color: _softPanel,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _lineMuted.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                Container(
                  width: 156,
                  height: 156,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: hasAddress
                      ? QrImageView(
                          data: address,
                          backgroundColor: Colors.white,
                        )
                      : const Icon(
                          Icons.qr_code_2_rounded,
                          color: _lineMuted,
                          size: 92,
                        ),
                ),
                const SizedBox(height: 16),
                Text(
                  hasAddress ? address : '--',
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _bodyText,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    height: 16 / 12,
                    letterSpacing: 0.1,
                  ),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: hasAddress ? () => _copyAddress(address) : null,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.copy_rounded,
                          color: hasAddress
                              ? _brandBlue
                              : _brandBlue.withValues(alpha: 0.35),
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _copyAddressLabel(),
                          style: TextStyle(
                            color: hasAddress
                                ? _brandBlue
                                : _brandBlue.withValues(alpha: 0.35),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            height: 20 / 14,
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

  Widget _buildNoticeArea(List<String> tips) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      decoration: BoxDecoration(
        color: const Color(0xCCF1F5F9),
        borderRadius: BorderRadius.circular(8),
        border: const Border(
          left: BorderSide(color: Color(0xFF94A3B8), width: 4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.info_outline_rounded,
                color: Color(0xFF64748B),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'app.system.tips.title'.tr,
                style: const TextStyle(
                  color: _strongText,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  height: 20 / 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final tip in tips)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 3),
                    child: Text(
                      '-',
                      style: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tip,
                      style: const TextStyle(
                        color: _bodyText,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        height: 1.6,
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

  Widget _buildChargeCardForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'app.user.wallet.secret_key'.tr,
          style: const TextStyle(
            color: _strongText,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            height: 20 / 14,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _secretKeyController,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submitChargeCard(),
          style: const TextStyle(
            color: _strongText,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: _fieldFill,
            hintText: 'app.user.recharge.secretKey_placeholder'.tr,
            hintStyle: TextStyle(
              color: _mutedText.withValues(alpha: 0.6),
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            suffixIcon: const Icon(
              Icons.vpn_key_outlined,
              color: _mutedText,
              size: 24,
            ),
            border: OutlineInputBorder(
              borderSide: BorderSide.none,
              borderRadius: BorderRadius.circular(8),
            ),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide.none,
              borderRadius: BorderRadius.circular(8),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: _brandBlue, width: 1.2),
              borderRadius: BorderRadius.circular(8),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 17,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(
              Icons.info_outline_rounded,
              color: _bodyText.withValues(alpha: 0.7),
              size: 12,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                'app.user.recharge.secretKey_placeholder'.tr,
                style: TextStyle(
                  color: _bodyText.withValues(alpha: 0.7),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildChargeCardConfirmButton() {
    final enabled = !_isSubmittingChargeCard;
    return Material(
      color: Colors.transparent,
      child: Ink(
        height: 56,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: enabled
                ? const [_brandBlue, _brandBlueLight]
                : [
                    _brandBlue.withValues(alpha: 0.55),
                    _brandBlueLight.withValues(alpha: 0.55),
                  ],
          ),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: _brandBlueLight.withValues(alpha: enabled ? 0.2 : 0.08),
              blurRadius: 15,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: InkWell(
          onTap: enabled ? _submitChargeCard : null,
          borderRadius: BorderRadius.circular(8),
          child: Center(
            child: _isSubmittingChargeCard
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'app.common.confirm'.tr,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          height: 28 / 18,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooterDivider(String label, {IconData? icon}) {
    return Row(
      children: [
        const Expanded(child: Divider(color: Color(0x4DC4C5D5), height: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, color: _bodyText.withValues(alpha: 0.45), size: 14),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  color: _bodyText.withValues(alpha: 0.45),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  height: 15 / 10,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
        const Expanded(child: Divider(color: Color(0x4DC4C5D5), height: 1)),
      ],
    );
  }

  BoxDecoration _panelDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }
}

class _RechargeIconAction extends StatelessWidget {
  const _RechargeIconAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Center(child: Icon(icon, size: 20)),
        ),
      ),
    );
  }
}

class _RechargeModeTile extends StatelessWidget {
  const _RechargeModeTile({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active
        ? _WalletRechargePageState._brandBlue
        : _WalletRechargePageState._bodyText;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Ink(
          height: 100,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          decoration: BoxDecoration(
            color: active
                ? _WalletRechargePageState._brandBlueSoft
                : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: active
                  ? _WalletRechargePageState._brandBlue
                  : _WalletRechargePageState._panelBorder,
              width: active ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: active ? 24 : 25),
              const SizedBox(height: 8),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                  height: 20 / 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SecurityFeatureCard extends StatelessWidget {
  const _SecurityFeatureCard({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 98,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0x80ECEEF0),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: _WalletRechargePageState._brandBlue, size: 20),
          const SizedBox(height: 8),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _WalletRechargePageState._strongText,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              height: 16.5 / 11,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _WalletRechargePageState._bodyText,
              fontSize: 9,
              fontWeight: FontWeight.w500,
              height: 11.25 / 9,
            ),
          ),
        ],
      ),
    );
  }
}
