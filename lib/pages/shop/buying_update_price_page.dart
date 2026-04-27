import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tronskins_app/api/model/shop/shop_models.dart';
import 'package:tronskins_app/api/shop_product.dart';
import 'package:tronskins_app/common/hooks/currency/CurrencyController.dart';
import 'package:tronskins_app/common/utils/app_snackbar.dart';
import 'package:tronskins_app/common/widgets/settings_style_app_bar.dart';
import 'package:tronskins_app/components/game_item/game_item_image.dart';

class BuyingUpdatePricePage extends StatefulWidget {
  const BuyingUpdatePricePage({super.key});

  @override
  State<BuyingUpdatePricePage> createState() => _BuyingUpdatePricePageState();
}

class _BuyingUpdatePricePageState extends State<BuyingUpdatePricePage> {
  final ApiShopProductServer _api = ApiShopProductServer();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _numController = TextEditingController();

  late final BuyRequestItem _item;
  Map<String, dynamic> _schemaRaw = {};
  double _minPrice = 0;
  bool _isSubmitting = false;

  static const double _minTradePrice = 0.02;
  static const Color _pageBackground = Color(0xFFF7F9FB);
  static const Color _cardSurface = Colors.white;
  static const Color _softSurface = Color(0xFFF2F4F6);
  static const Color _fieldSurface = Color(0xFFECEEF0);
  static const Color _surfaceStroke = Color(0x0FC4C5D5);
  static const Color _titleColor = Color(0xFF191C1E);
  static const Color _bodyColor = Color(0xFF444653);
  static const Color _brandBlue = Color(0xFF1E40AF);
  static const Color _brandBlueEnd = Color(0xFF2170E4);
  static const Color _dangerColor = Color(0xFFBA1A1A);
  static const Color _itemPreviewSlate = Color(0xFF1E293B);

  @override
  void initState() {
    super.initState();
    final args = Get.arguments as Map<String, dynamic>? ?? {};
    final rawItem = args['item'];
    if (rawItem is BuyRequestItem) {
      _item = rawItem;
    } else if (rawItem is Map) {
      _item = BuyRequestItem.fromJson(Map<String, dynamic>.from(rawItem));
    } else {
      _item = BuyRequestItem(raw: const {});
    }

    final rawSchema = args['schema'];
    if (rawSchema is ShopSchemaInfo) {
      _schemaRaw = rawSchema.raw;
    } else if (rawSchema is Map) {
      _schemaRaw = Map<String, dynamic>.from(rawSchema);
    }

    _priceController.text = _normalizeDisplayPrice(_item.price ?? 0);
    _numController.text = (_item.nums ?? 0).toString();
    _priceController.addListener(_onInputChanged);
    _numController.addListener(_onInputChanged);
    _loadParams();
  }

  @override
  void dispose() {
    _priceController.removeListener(_onInputChanged);
    _numController.removeListener(_onInputChanged);
    _priceController.dispose();
    _numController.dispose();
    super.dispose();
  }

  void _onInputChanged() {
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  Future<void> _loadParams() async {
    final res = await _api.getSysParams();
    final raw = res.datas;
    if (raw is Map<String, dynamic>) {
      final minValue = raw['minPrice'];
      if (minValue is num) {
        _minPrice = max(minValue.toDouble(), _minTradePrice);
      } else {
        _minPrice = max(
          double.tryParse(minValue?.toString() ?? '') ?? 0,
          _minTradePrice,
        );
      }
    }
    if (mounted) {
      setState(() {});
    }
  }

  double _sellMin() {
    final sellMin = _parseDouble(_schemaRaw['sell_min']);
    final buffMin = _parseDouble(_schemaRaw['buff_min_price']);
    final candidates = [
      sellMin,
      buffMin,
    ].whereType<double>().where((value) => value > 0).toList();
    if (candidates.isEmpty) {
      return 0;
    }
    final minMarket = candidates.reduce(min);
    return minMarket > _minTradePrice ? minMarket : _minTradePrice;
  }

  double _buyMax() {
    return _parseDouble(_schemaRaw['buy_max']) ?? 0;
  }

  double _truncateTo2(double value) {
    return (value * 100).floor() / 100;
  }

  int _resolveAppId() {
    final value = _item.appId ?? _schemaRaw['app_id'] ?? _schemaRaw['appId'];
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '') ?? 730;
  }

  String _normalizeDisplayPrice(double value) {
    if (value <= 0) {
      return '';
    }
    final normalized = _truncateTo2(value);
    return normalized.toStringAsFixed(2);
  }

  double _getPricingRules(double buyMaxPrice) {
    if (buyMaxPrice <= 0) {
      return 0;
    }
    double newPrice = 0;
    if (buyMaxPrice <= 10 && buyMaxPrice > 0) {
      newPrice = buyMaxPrice + 0.01;
    }
    if (buyMaxPrice > 10 && buyMaxPrice <= 100) {
      newPrice = buyMaxPrice + 0.1;
    }
    if (buyMaxPrice > 100) {
      newPrice = buyMaxPrice + 0.5;
    }
    final rounded = double.parse(newPrice.toStringAsFixed(2));
    return rounded < _minTradePrice ? _minTradePrice : rounded;
  }

  double _totalAmount() {
    final price = double.tryParse(_priceController.text) ?? 0;
    final num = int.tryParse(_numController.text) ?? 0;
    return price * num;
  }

  bool _hasMoreThanTwoDecimals(String value) {
    final dotIndex = value.indexOf('.');
    if (dotIndex < 0) {
      return false;
    }
    return value.length - dotIndex - 1 > 2;
  }

  void _setControllerText(TextEditingController controller, String text) {
    controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.fromPosition(TextPosition(offset: text.length)),
    );
  }

  void _applyMaxPrice() {
    final value = _getPricingRules(_buyMax());
    if (value <= 0) {
      return;
    }
    _setControllerText(_priceController, value.toStringAsFixed(2));
  }

  void _sanitizePrice(String value) {
    if (value.isEmpty) {
      setState(() {});
      return;
    }
    final parsed = double.tryParse(value);
    if (parsed == null) {
      setState(() {});
      return;
    }
    final parts = value.split('.');
    if (parts.length == 2 && parts[1].length > 2) {
      final truncated = _truncateTo2(parsed);
      _setControllerText(_priceController, truncated.toStringAsFixed(2));
    }
    setState(() {});
  }

  void _normalizePriceOnBlur() {
    final text = _priceController.text;
    if (text.isEmpty) {
      return;
    }
    if (text.endsWith('.')) {
      final normalizedText = text.substring(0, text.length - 1);
      _setControllerText(_priceController, normalizedText);
    }
    final price = double.tryParse(_priceController.text);
    if (price == null) {
      return;
    }
    if (price < _minTradePrice) {
      _setControllerText(_priceController, _minTradePrice.toStringAsFixed(2));
    }
    setState(() {});
  }

  void _sanitizeNum(String value) {
    if (value.contains('.')) {
      final integer = value.split('.').first;
      _setControllerText(_numController, integer);
    }
    final numValue = int.tryParse(_numController.text) ?? 0;
    if (numValue > 200) {
      _setControllerText(_numController, '200');
    }
    setState(() {});
  }

  String? _rawText(List<String> keys) {
    for (final key in keys) {
      final value = _item.raw[key];
      if (value != null) {
        return value.toString();
      }
    }
    return null;
  }

  Future<void> _submit() async {
    if (_isSubmitting) {
      return;
    }
    var shouldClosePage = false;
    FocusManager.instance.primaryFocus?.unfocus();
    final priceText = _priceController.text.trim();
    final numText = _numController.text.trim();
    final normalizedPriceText = priceText.endsWith('.') && priceText.length > 1
        ? priceText.substring(0, priceText.length - 1)
        : priceText;
    if (normalizedPriceText.isEmpty || _hasMoreThanTwoDecimals(priceText)) {
      AppSnackbar.error('app.market.filter.message.price_error'.tr);
      return;
    }
    final price = double.tryParse(normalizedPriceText);
    final nums = int.tryParse(numText);
    if (price == null || price <= 0 || nums == null || nums <= 0) {
      AppSnackbar.error('app.market.filter.message.price_error'.tr);
      return;
    }
    final effectiveMinPrice = _minPrice > 0 ? _minPrice : _minTradePrice;
    if (price < effectiveMinPrice) {
      AppSnackbar.error('app.trade.purchase.message.min_price_error'.tr);
      return;
    }
    final sellMin = _sellMin();
    final shouldConfirm = price >= 10 && sellMin > 0 && price > sellMin;
    if (shouldConfirm) {
      final confirm = await Get.dialog<bool>(
        AlertDialog(
          title: Text('app.system.tips.title'.tr),
          content: Text('app.trade.purchase.message.confirm_to_buy'.tr),
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
      if (confirm != true) {
        return;
      }
    }
    setState(() => _isSubmitting = true);
    try {
      final res = await _api.myBuyUpdatePrice(
        items: [
          {'id': _item.id, 'price': price, 'nums': nums},
        ],
      );
      if (!res.success) {
        final dataText = res.datas?.toString().trim();
        final errorText = (dataText?.isNotEmpty ?? false)
            ? dataText!
            : (res.message.trim().isNotEmpty
                  ? res.message
                  : 'app.trade.filter.failed'.tr);
        AppSnackbar.error(errorText);
        return;
      }
      shouldClosePage = true;
      FocusManager.instance.primaryFocus?.unfocus();
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        AppSnackbar.success('app.inventory.message.price_change_success'.tr);
      });
      return;
    } finally {
      if (mounted && !shouldClosePage) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  String _displayAmount(CurrencyController currency, double amount) {
    final formatted = currency.format(amount);
    final prefix = '${currency.symbol} ';
    if (formatted.startsWith(prefix)) {
      return formatted.substring(prefix.length);
    }
    return formatted.replaceFirst(currency.symbol, '').trim();
  }

  String get _guidelineTitle {
    final purchaseLabel = 'app.trade.purchase.text'.tr;
    final tipsLabel = 'app.system.tips.title'.tr;
    final languageCode = Get.locale?.languageCode.toLowerCase();
    if (languageCode == 'zh') {
      return '$purchaseLabel$tipsLabel';
    }
    return '$purchaseLabel $tipsLabel';
  }

  String get _totalAmountTitle {
    final locale = Get.locale;
    final languageCode = locale?.languageCode.toLowerCase();
    final countryCode = locale?.countryCode?.toUpperCase();
    if (languageCode == 'zh') {
      return countryCode == 'TW' ? '訂單總額' : '订单总额';
    }
    return 'Total Amount';
  }

  Widget _buildSurfaceCard({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(16),
    BorderRadiusGeometry borderRadius = const BorderRadius.all(
      Radius.circular(8),
    ),
  }) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: _cardSurface,
        borderRadius: borderRadius,
        border: Border.all(color: _surfaceStroke),
        boxShadow: const [
          BoxShadow(
            color: Color(0x05000000),
            blurRadius: 20,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildStatItem({required String label, required String value}) {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: '$label ',
            style: const TextStyle(
              color: _bodyColor,
              fontSize: 12,
              height: 16 / 12,
            ),
          ),
          TextSpan(
            text: value,
            style: const TextStyle(
              color: _titleColor,
              fontSize: 12,
              height: 16 / 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemPreview({required String imageUrl, required int appId}) {
    return Container(
      width: 92,
      height: 68,
      decoration: BoxDecoration(
        color: _itemPreviewSlate,
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: GameItemImage(
        imageUrl: imageUrl,
        appId: appId,
        count: _item.count,
        alwaysShowCount: true,
        showTopBadges: false,
      ),
    );
  }

  Widget _buildPriceCard({
    required CurrencyController currency,
    required String priceHint,
  }) {
    return _buildSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'app.trade.purchase.price'.tr.toUpperCase(),
            style: const TextStyle(
              color: _bodyColor,
              fontSize: 12,
              height: 16 / 12,
              letterSpacing: 0.6,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                currency.symbol,
                style: const TextStyle(
                  color: _brandBlue,
                  fontSize: 20,
                  height: 28 / 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _priceController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: const TextStyle(
                    color: _titleColor,
                    fontSize: 24,
                    height: 32 / 24,
                    fontWeight: FontWeight.w700,
                  ),
                  cursorColor: _brandBlue,
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: priceHint,
                    hintStyle: TextStyle(
                      color: _titleColor.withValues(alpha: 0.35),
                      fontSize: 24,
                      height: 32 / 24,
                      fontWeight: FontWeight.w700,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: _sanitizePrice,
                  onEditingComplete: _normalizePriceOnBlur,
                  onSubmitted: (_) => _normalizePriceOnBlur(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuantityCard() {
    return _buildSurfaceCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'app.trade.purchase.num'.tr.toUpperCase(),
                  style: const TextStyle(
                    color: _bodyColor,
                    fontSize: 12,
                    height: 16 / 12,
                    letterSpacing: 0.6,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'app.trade.purchase.placeholder_num'.tr,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _bodyColor,
                    fontSize: 10,
                    height: 15 / 10,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 112,
            height: 44,
            decoration: BoxDecoration(
              color: _fieldSurface,
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: TextField(
              controller: _numController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _titleColor,
                fontSize: 16,
                height: 24 / 16,
                fontWeight: FontWeight.w700,
              ),
              cursorColor: _brandBlue,
              decoration: InputDecoration(
                isDense: true,
                hintText: '0',
                hintStyle: TextStyle(
                  color: _titleColor.withValues(alpha: 0.35),
                  fontSize: 16,
                  height: 24 / 16,
                  fontWeight: FontWeight.w700,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: _sanitizeNum,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuidelineItem({required Widget icon, required Widget content}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(padding: const EdgeInsets.only(top: 1), child: icon),
        const SizedBox(width: 12),
        Expanded(child: content),
      ],
    );
  }

  Widget _buildGuidelineCard(String noticeSpacing) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _softSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _surfaceStroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.shield_outlined, size: 18, color: _bodyColor),
              const SizedBox(width: 8),
              Text(
                _guidelineTitle,
                style: const TextStyle(
                  color: _bodyColor,
                  fontSize: 12,
                  height: 16 / 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildGuidelineItem(
            icon: const Icon(
              Icons.warning_amber_rounded,
              size: 18,
              color: _dangerColor,
            ),
            content: RichText(
              text: TextSpan(
                style: const TextStyle(
                  color: _bodyColor,
                  fontSize: 12,
                  height: 19.5 / 12,
                ),
                children: [
                  TextSpan(
                    text: '${'app.trade.purchase.buyer_notice_1'.tr} ',
                    style: const TextStyle(
                      color: _titleColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextSpan(
                    text:
                        '$noticeSpacing'
                        '${'app.trade.purchase.buyer_notice_2'.tr}'
                        '$noticeSpacing',
                    style: const TextStyle(
                      color: _dangerColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextSpan(text: 'app.trade.purchase.buyer_notice_3'.tr),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildGuidelineItem(
            icon: const Icon(
              Icons.info_outline_rounded,
              size: 18,
              color: _brandBlue,
            ),
            content: Text(
              'app.trade.purchase.buyer_notice_4'.tr,
              style: const TextStyle(
                color: _bodyColor,
                fontSize: 12,
                height: 19.5 / 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalAmountCard({
    required CurrencyController currency,
    required String totalDisplay,
  }) {
    return _buildSurfaceCard(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      borderRadius: const BorderRadius.all(Radius.circular(16)),
      child: Column(
        children: [
          Text(
            _totalAmountTitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _bodyColor,
              fontSize: 14,
              height: 20 / 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              children: [
                TextSpan(
                  text: currency.symbol,
                  style: const TextStyle(
                    color: _brandBlue,
                    fontSize: 22,
                    height: 32 / 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.44,
                  ),
                ),
                TextSpan(
                  text: totalDisplay,
                  style: const TextStyle(
                    color: _brandBlue,
                    fontSize: 34,
                    height: 40 / 34,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.85,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return SafeArea(
      top: false,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.78),
              border: const Border(top: BorderSide(color: Color(0x12C4C5D5))),
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                gradient: _isSubmitting
                    ? const LinearGradient(
                        colors: [Color(0xFF94A3B8), Color(0xFFCBD5E1)],
                      )
                    : const LinearGradient(colors: [_brandBlue, _brandBlueEnd]),
                boxShadow: _isSubmitting
                    ? null
                    : const [
                        BoxShadow(
                          color: Color(0x331E40AF),
                          blurRadius: 15,
                          offset: Offset(0, 10),
                          spreadRadius: -4,
                        ),
                      ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: _isSubmitting ? null : _submit,
                  child: SizedBox(
                    height: 48,
                    child: Center(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        switchInCurve: Curves.easeOut,
                        switchOutCurve: Curves.easeIn,
                        child: _isSubmitting
                            ? Row(
                                key: const ValueKey(
                                  'buying-update-price-loading',
                                ),
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    'app.system.tips.please_wait'.tr,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      height: 22 / 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              )
                            : Row(
                                key: const ValueKey('buying-update-price-idle'),
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'app.common.confirm'.tr,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      height: 24 / 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(
                                    Icons.north_east_rounded,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currency = Get.find<CurrencyController>();
    final imageUrl = _schemaRaw['image_url']?.toString() ?? '';
    final title =
        _schemaRaw['market_name']?.toString() ??
        _schemaRaw['market_hash_name']?.toString() ??
        '-';
    final appId = _resolveAppId();
    final languageCode = Localizations.localeOf(
      context,
    ).languageCode.toLowerCase();
    final noticeSpacing = switch (languageCode) {
      'zh' || 'ja' || 'ko' => '',
      _ => ' ',
    };
    final wearMin =
        _rawText(const ['paint_wear_min', 'paintWearMin']) ??
        _item.paintWearMin?.toString();
    final wearMax =
        _rawText(const ['paint_wear_max', 'paintWearMax']) ??
        _item.paintWearMax?.toString();
    final priceHint = _minPrice > 0
        ? _displayAmount(currency, _minPrice)
        : '0.00';
    final totalDisplay = _displayAmount(currency, _totalAmount());
    return Scaffold(
      backgroundColor: _pageBackground,
      appBar: SettingsStyleAppBar(
        title: Text(
          'app.trade.purchase.price_change'.tr,
          maxLines: 1,
          softWrap: false,
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: TextButton(
              onPressed: _applyMaxPrice,
              style: TextButton.styleFrom(
                foregroundColor: _brandBlue,
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'app.inventory.pricing'.tr,
                style: const TextStyle(
                  color: _brandBlue,
                  fontSize: 14,
                  height: 20 / 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
        children: [
          _buildSurfaceCard(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                _buildItemPreview(imageUrl: imageUrl, appId: appId),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _titleColor,
                          fontSize: 18,
                          height: 28 / 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (wearMin != null && wearMax != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          '${'app.market.filter.csgo.wear_interval'.tr}: '
                          '$wearMin - $wearMax',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _bodyColor,
                            fontSize: 12,
                            height: 16 / 12,
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 16,
                        runSpacing: 8,
                        children: [
                          _buildStatItem(
                            label: 'app.market.detail.sale_lowest'.tr,
                            value: currency.format(_sellMin()),
                          ),
                          _buildStatItem(
                            label: 'app.market.detail.purchase_highest'.tr,
                            value: currency.format(_buyMax()),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _buildPriceCard(currency: currency, priceHint: priceHint),
          const SizedBox(height: 16),
          _buildQuantityCard(),
          const SizedBox(height: 16),
          _buildGuidelineCard(noticeSpacing),
          const SizedBox(height: 12),
          _buildTotalAmountCard(currency: currency, totalDisplay: totalDisplay),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }
}

double? _parseDouble(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is double) {
    return value;
  }
  if (value is int) {
    return value.toDouble();
  }
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value.toString());
}
