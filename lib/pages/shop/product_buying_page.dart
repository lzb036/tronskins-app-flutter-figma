import 'dart:async';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tronskins_app/api/market.dart';
import 'package:tronskins_app/api/model/market/market_models.dart';
import 'package:tronskins_app/api/shop.dart';
import 'package:tronskins_app/api/shop_product.dart';
import 'package:tronskins_app/common/hooks/currency/CurrencyController.dart';
import 'package:tronskins_app/common/storage/user_storage.dart';
import 'package:tronskins_app/common/utils/app_snackbar.dart';
import 'package:tronskins_app/common/utils/string_utils.dart';
import 'package:tronskins_app/common/widgets/figma_confirmation_dialog.dart';
import 'package:tronskins_app/common/widgets/settings_style_app_bar.dart';
import 'package:tronskins_app/components/filter/filter_sheet_style.dart';
import 'package:tronskins_app/components/game_item/game_item_utils.dart';
import 'package:tronskins_app/controllers/shop/buy_request_controller.dart';

class ProductBuyingPage extends StatefulWidget {
  const ProductBuyingPage({super.key});

  @override
  State<ProductBuyingPage> createState() => _ProductBuyingPageState();
}

class _ProductBuyingPageState extends State<ProductBuyingPage> {
  static const String _wearUnlimitedValue = '__wear_unlimited__';
  static const String _wearCustomValue = '__wear_custom__';
  static const String _phaseUnlimitedValue = '__phase_unlimited__';
  static const String _gradientUnlimitedValue = '__gradient_unlimited__';
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

  final ApiMarketServer _marketApi = ApiMarketServer();
  final ApiShopProductServer _shopApi = ApiShopProductServer();
  final ApiShopServer _shopServer = ApiShopServer();

  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _numController = TextEditingController();

  late final int _appId;
  late final int _schemaId;

  MarketTemplateSchema? _schema;
  List<dynamic> _paintKits = const <dynamic>[];
  double _purMinPrice = 0;
  double _minPrice = 0;
  int _purchaseNum = 0;
  int _remainNum = 0;
  bool _isLoading = true;
  bool _isSubmitting = false;

  double? _wearMin;
  double? _wearMax;
  String? _selectedPaintIndex;
  double? _gradientMin;
  double? _gradientMax;
  String? _filterLabel;

  @override
  void initState() {
    super.initState();
    final args = Get.arguments as Map<String, dynamic>? ?? {};
    _appId = args['appId'] as int? ?? 730;
    _schemaId = args['schemaId'] as int? ?? 0;
    _priceController.addListener(_onInputChanged);
    _numController.addListener(_onInputChanged);
    _loadData();
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

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final useAuth = UserStorage.getUserInfo() != null;
      final res = await _marketApi.marketTemplateDetail(
        appId: _appId,
        schemaId: _schemaId,
        useAuth: useAuth,
        fallbackToPublicOnFail: true,
      );
      _schema = res.datas?.schema;
      _paintKits = res.datas?.paintKits ?? const <dynamic>[];
      _selectedPaintIndex = null;
      _gradientMin = null;
      _gradientMax = null;

      final minRes = await _shopApi.getOrderBuyingMinPrice(
        appId: _appId,
        schemaId: _schemaId,
      );
      _purMinPrice = minRes.datas ?? 0;

      final remainRes = await _marketApi.buyRemainNum(schemaId: _schemaId);
      _purchaseNum = remainRes.datas?.purchaseNum ?? 0;
      _remainNum = remainRes.datas?.remainNum ?? 0;

      final paramsRes = await _shopApi.getSysParams();
      if (paramsRes.datas is Map<String, dynamic>) {
        final rawMin = paramsRes.datas?['minPrice'];
        if (rawMin is num) {
          _minPrice = rawMin.toDouble();
        } else {
          _minPrice = double.tryParse(rawMin?.toString() ?? '') ?? 0;
        }
      }
      _filterLabel = _buildFilterLabel();
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  bool get _showFilter {
    if (_appId != 730) {
      return false;
    }
    final typeKey = _schema?.tags?.type?.key ?? _schema?.tags?.type?.name;
    const excludedTypes = <String>{
      'CSGO_Type_WeaponCase',
      'Type_CustomPlayer',
      'CSGO_Tool_Sticker',
    };
    return !excludedTypes.contains(typeKey);
  }

  bool get _showPhaseFilter {
    if (_appId != 730) {
      return false;
    }
    return _marketHashNameContains('Doppler');
  }

  bool get _showGradientFilter {
    if (_appId != 730) {
      return false;
    }
    return _marketHashNameContains('Fade');
  }

  bool _marketHashNameContains(String text) {
    final marketHashName = _schema?.marketHashName ?? '';
    return marketHashName.toLowerCase().contains(text.toLowerCase());
  }

  double _totalAmount() {
    final price = double.tryParse(_priceController.text) ?? 0;
    final nums = int.tryParse(_numController.text) ?? 0;
    return price * nums;
  }

  int get _maxPublishQuantity => _remainNum > 0 ? _remainNum : 0;

  String get _quantityLimitTips {
    if (_purchaseNum >= 0 && _remainNum >= 0) {
      return formatWithParams('app.trade.purchase.message.remaining_tips'.tr, [
        _purchaseNum,
        _remainNum,
      ]);
    }
    return 'app.trade.purchase.num_placeholder'.tr;
  }

  Future<bool> _checkPurchaseOnline() async {
    final user = UserStorage.getUserInfo();
    final uuid = user?.uuid ?? user?.shop?.uuid;
    if (uuid == null || uuid.isEmpty) {
      return true;
    }
    try {
      final res = await _shopServer.getUserShopInfo(params: {'uuid': uuid});
      if (res.success && res.datas != null) {
        return res.datas?['signWanted'] == true;
      }
    } catch (_) {}
    return true;
  }

  void _sanitizePrice(String value) {
    final parsed = double.tryParse(value);
    if (parsed == null) {
      return;
    }
    final parts = value.split('.');
    if (parts.length == 2 && parts[1].length > 2) {
      _priceController.text = parsed.toStringAsFixed(2);
      _priceController.selection = TextSelection.fromPosition(
        TextPosition(offset: _priceController.text.length),
      );
    }
  }

  void _sanitizeNum(String value) {
    var text = value;
    if (value.contains('.')) {
      text = value.split('.').first;
      _setNumText(text);
      AppSnackbar.error('app.market.detail.message.num_error'.tr);
    }
    final numValue = int.tryParse(text) ?? 0;
    final maxQuantity = _maxPublishQuantity;
    if (text.isNotEmpty && numValue > maxQuantity) {
      _setNumText(maxQuantity.toString());
    }
  }

  void _setNumText(String text) {
    if (_numController.text == text) {
      return;
    }
    _numController.text = text;
    _numController.selection = TextSelection.fromPosition(
      TextPosition(offset: _numController.text.length),
    );
  }

  void _calibratePrice() {
    final value = _priceController.text.trim();
    if (value.isEmpty) {
      return;
    }
    final parsed = double.tryParse(value);
    if (parsed == null) {
      return;
    }
    var next = parsed;
    if (next < _minPrice) {
      next = _minPrice;
    }
    final text = next.toStringAsFixed(2);
    _priceController.text = text;
    _priceController.selection = TextSelection.fromPosition(
      TextPosition(offset: _priceController.text.length),
    );
  }

  Future<void> _openFilterSheet() async {
    final exteriorKey = _schema?.tags?.exterior?.key;
    final wearQuickOptions = _buildWearQuickOptions(exteriorKey);
    final minWearHint = wearQuickOptions.first.minText;
    final maxWearHint = wearQuickOptions.last.maxText;

    final wearMinController = TextEditingController(
      text: _wearMin != null ? _formatWearValue(_wearMin!) : '',
    );
    final wearMaxController = TextEditingController(
      text: _wearMax != null ? _formatWearValue(_wearMax!) : '',
    );

    final result = await showModalBottomSheet<_ProductFilterResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            bool isQuickSelected(_ProductWearQuickOption option) {
              final min = double.tryParse(wearMinController.text.trim());
              final max = double.tryParse(wearMaxController.text.trim());
              if (min == null || max == null) {
                return false;
              }
              return (min - option.min).abs() < 0.000001 &&
                  (max - option.max).abs() < 0.000001;
            }

            Future<void> closeSheet(_ProductFilterResult result) async {
              FocusManager.instance.primaryFocus?.unfocus();
              await Future<void>.delayed(const Duration(milliseconds: 10));
              if (!context.mounted) {
                return;
              }
              Navigator.of(context).pop(result);
            }

            return AnimatedPadding(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              padding: EdgeInsets.only(
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: FractionallySizedBox(
                heightFactor: 0.82,
                child: ClipRRect(
                  borderRadius: FilterSheetStyle.panelRadius,
                  child: FilterSheetFrame(
                    title: 'app.market.filter.text'.tr,
                    resetLabel: 'app.market.filter.reset'.tr,
                    onReset: () => closeSheet(const _ProductFilterResult()),
                    onClose: () => Navigator.of(context).pop(),
                    confirmLabel: 'app.market.filter.finish'.tr,
                    onConfirm: () {
                      final normalized = _normalizeWearRange(
                        minInput: wearMinController.text,
                        maxInput: wearMaxController.text,
                        exteriorKey: exteriorKey,
                      );
                      closeSheet(
                        _ProductFilterResult(
                          wearMin: normalized.min,
                          wearMax: normalized.max,
                        ),
                      );
                    },
                    body: SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 23, 16, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FilterSheetSection(
                            title: 'app.market.filter.csgo.wear_interval'.tr,
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: wearMinController,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    onChanged: (_) => setModalState(() {}),
                                    decoration:
                                        FilterSheetStyle.inputDecoration(
                                          hintText: minWearHint,
                                        ),
                                  ),
                                ),
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 8),
                                  child: SizedBox(
                                    width: 16,
                                    child: Divider(
                                      thickness: 1,
                                      height: 1,
                                      color: FilterSheetStyle.border,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: TextField(
                                    controller: wearMaxController,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    onChanged: (_) => setModalState(() {}),
                                    decoration:
                                        FilterSheetStyle.inputDecoration(
                                          hintText: maxWearHint,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          FilterSheetSection(
                            title: 'app.market.filter.selection_quick'.tr,
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: wearQuickOptions
                                  .map(
                                    (option) => _buildFilterChip(
                                      label: option.label,
                                      selected: isQuickSelected(option),
                                      onSelected: () {
                                        setModalState(() {
                                          wearMinController.text =
                                              option.minText;
                                          wearMaxController.text =
                                              option.maxText;
                                        });
                                      },
                                    ),
                                  )
                                  .toList(growable: false),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
    if (result == null || !mounted) {
      return;
    }
    _applyWearFilter(min: result.wearMin, max: result.wearMax);
  }

  String _buildFilterLabel() {
    if (_wearMin == null && _wearMax == null) {
      return _wearUnlimitedLabel;
    }
    final quickOptions = _buildWearQuickOptions(_schema?.tags?.exterior?.key);
    final min = _wearMin ?? quickOptions.first.min;
    final max = _wearMax ?? quickOptions.last.max;
    return '${_formatWearValue(min)}-${_formatWearValue(max)}';
  }

  String get _wearUnlimitedLabel {
    final languageCode = Get.locale?.languageCode.toLowerCase();
    if (languageCode == 'en') {
      return 'No Wear Limit';
    }
    return 'app.common.unlimited'.tr;
  }

  String get _wearCustomLabel {
    final languageCode = Get.locale?.languageCode.toLowerCase();
    if (languageCode == 'zh') {
      return '自定义';
    }
    return 'Customized';
  }

  String _wearOptionValue(_ProductWearQuickOption option) {
    return '${option.minText}-${option.maxText}';
  }

  bool _matchesWearOption(_ProductWearQuickOption option) {
    if (_wearMin == null || _wearMax == null) {
      return false;
    }
    return (_wearMin! - option.min).abs() < 0.000001 &&
        (_wearMax! - option.max).abs() < 0.000001;
  }

  String _currentWearDropdownValue(List<_ProductWearQuickOption> quickOptions) {
    if (_wearMin == null && _wearMax == null) {
      return _wearUnlimitedValue;
    }
    for (final option in quickOptions) {
      if (_matchesWearOption(option)) {
        return _wearOptionValue(option);
      }
    }
    return _wearCustomValue;
  }

  void _applyWearFilter({double? min, double? max}) {
    setState(() {
      _wearMin = min;
      _wearMax = max;
      _filterLabel = _buildFilterLabel();
    });
  }

  Future<void> _handleWearDropdownChanged(
    String? value,
    List<_ProductWearQuickOption> quickOptions,
  ) async {
    if (value == null) {
      return;
    }
    if (value == _wearUnlimitedValue) {
      _applyWearFilter();
      return;
    }
    if (value == _wearCustomValue) {
      await _openFilterSheet();
      return;
    }
    for (final option in quickOptions) {
      if (_wearOptionValue(option) == value) {
        _applyWearFilter(min: option.min, max: option.max);
        return;
      }
    }
  }

  List<_ProductWearQuickOption> _buildWearQuickOptions(String? exteriorKey) {
    switch (exteriorKey) {
      case 'WearCategory0':
        return const <_ProductWearQuickOption>[
          _ProductWearQuickOption(0.00, 0.01),
          _ProductWearQuickOption(0.01, 0.02),
          _ProductWearQuickOption(0.02, 0.03),
          _ProductWearQuickOption(0.03, 0.04),
          _ProductWearQuickOption(0.04, 0.07),
        ];
      case 'WearCategory1':
        return const <_ProductWearQuickOption>[
          _ProductWearQuickOption(0.07, 0.08),
          _ProductWearQuickOption(0.08, 0.09),
          _ProductWearQuickOption(0.09, 0.10),
          _ProductWearQuickOption(0.10, 0.11),
          _ProductWearQuickOption(0.11, 0.15),
        ];
      case 'WearCategory2':
        return const <_ProductWearQuickOption>[
          _ProductWearQuickOption(0.15, 0.18),
          _ProductWearQuickOption(0.18, 0.21),
          _ProductWearQuickOption(0.21, 0.24),
          _ProductWearQuickOption(0.24, 0.27),
          _ProductWearQuickOption(0.27, 0.38),
        ];
      case 'WearCategory3':
        return const <_ProductWearQuickOption>[
          _ProductWearQuickOption(0.38, 0.39),
          _ProductWearQuickOption(0.39, 0.40),
          _ProductWearQuickOption(0.40, 0.41),
          _ProductWearQuickOption(0.41, 0.42),
          _ProductWearQuickOption(0.42, 0.45),
        ];
      case 'WearCategory4':
        return const <_ProductWearQuickOption>[
          _ProductWearQuickOption(0.45, 0.50),
          _ProductWearQuickOption(0.50, 0.60),
          _ProductWearQuickOption(0.60, 0.70),
          _ProductWearQuickOption(0.70, 0.75),
          _ProductWearQuickOption(0.75, 0.80),
        ];
      default:
        return const <_ProductWearQuickOption>[
          _ProductWearQuickOption(0.00, 0.01),
          _ProductWearQuickOption(0.01, 0.02),
          _ProductWearQuickOption(0.02, 0.03),
          _ProductWearQuickOption(0.03, 0.04),
          _ProductWearQuickOption(0.04, 0.07),
        ];
    }
  }

  _ProductWearRange _normalizeWearRange({
    required String minInput,
    required String maxInput,
    required String? exteriorKey,
  }) {
    final quickOptions = _buildWearQuickOptions(exteriorKey);
    final minAllowed = quickOptions.first.min;
    final maxAllowed = quickOptions.last.max;

    var min = _toDouble(minInput.trim());
    var max = _toDouble(maxInput.trim());

    if (min != null) {
      if (min < minAllowed) {
        min = minAllowed;
      } else if (min > maxAllowed) {
        min = maxAllowed;
      }
    }

    if (max != null) {
      if (max < minAllowed) {
        max = minAllowed;
      } else if (max > maxAllowed) {
        max = maxAllowed;
      }
    }

    if (min != null && max != null && min > max) {
      max = min;
    }

    return _ProductWearRange(
      min: min != null ? double.parse(min.toStringAsFixed(2)) : null,
      max: max != null ? double.parse(max.toStringAsFixed(2)) : null,
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool selected,
    required VoidCallback onSelected,
  }) {
    return FilterSheetOptionChip(
      label: label,
      selected: selected,
      onTap: onSelected,
      selectedStyle: FilterChipSelectedStyle.soft,
    );
  }

  String _formatWearValue(double value) => value.toStringAsFixed(2);

  double? _toDouble(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is double) {
      return value;
    }
    if (value is num) {
      return value.toDouble();
    }
    final text = value.toString().trim();
    if (text.isEmpty) {
      return null;
    }
    return double.tryParse(text);
  }

  bool get _isEnglishLocale =>
      (Get.locale?.languageCode.toLowerCase() ?? '') == 'en';

  Future<void> _confirmSubmit() async {
    if (_isSubmitting) {
      return;
    }
    final user = UserStorage.getUserInfo();
    final price = double.tryParse(_priceController.text) ?? 0;
    final nums = int.tryParse(_numController.text) ?? 0;
    final maxQuantity = _maxPublishQuantity;
    if (user == null ||
        price <= 0 ||
        nums <= 0 ||
        maxQuantity <= 0 ||
        nums > maxQuantity) {
      await _submit();
      return;
    }

    final currency = Get.find<CurrencyController>();
    final itemTitle = _schema?.marketName ?? _schema?.marketHashName ?? '-';
    final sellMin = _schema?.sellMin ?? _minPrice;
    final showPriceNotice = price >= 10 && sellMin > 0 && price > sellMin;
    final submitted = await showFigmaModal<bool>(
      context: context,
      barrierDismissible: false,
      child: FigmaAsyncConfirmationDialog(
        icon: Icons.shopping_bag_rounded,
        iconColor: _brandBlue,
        iconBackgroundColor: const Color.fromRGBO(30, 64, 175, 0.10),
        title: _isEnglishLocale ? 'Confirm Buy Order' : '确认发布求购',
        message: _isEnglishLocale
            ? 'Review the order details before creating this buy request.'
            : '请在提交前确认本次求购信息。',
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              itemTitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF0F172A),
                fontSize: 15,
                fontWeight: FontWeight.w700,
                height: 22 / 15,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _isEnglishLocale
                  ? '${currency.format(price)} each · Qty $nums'
                  : '单价 ${currency.format(price)} · 数量 $nums',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 20 / 13,
              ),
            ),
            if (showPriceNotice) ...[
              const SizedBox(height: 8),
              Text(
                _isEnglishLocale
                    ? 'Your offer is above the current lowest listing price.'
                    : '当前出价高于在售价，将按你设置的价格挂出求购。',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  height: 20 / 13,
                ),
              ),
            ],
          ],
        ),
        highlightText:
            '${'app.trade.purchase.estimated_amount'.tr} ${currency.format(price * nums)}',
        primaryLabel: _isEnglishLocale ? 'Confirm Submission' : '确认提交',
        secondaryLabel: 'app.common.cancel'.tr,
        onSecondary: () => popModalRoute(context, false),
        onConfirm: (_) => _submit(alreadySubmitting: true),
      ),
    );
    if (submitted == true && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _submit({bool alreadySubmitting = false}) async {
    if (_isSubmitting && !alreadySubmitting) {
      return;
    }
    var shouldClosePage = false;
    void resetSubmittingState() {
      if (mounted && !shouldClosePage && _isSubmitting) {
        setState(() => _isSubmitting = false);
      }
    }

    final user = UserStorage.getUserInfo();
    if (user == null) {
      resetSubmittingState();
      AppSnackbar.info('app.system.message.nologin'.tr);
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    if (!await _checkPurchaseOnline()) {
      resetSubmittingState();
      AppSnackbar.info('app.trade.purchase.offline_tips'.tr);
      return;
    }

    final price = double.tryParse(_priceController.text) ?? 0;
    final nums = int.tryParse(_numController.text) ?? 0;
    final maxQuantity = _maxPublishQuantity;
    if (maxQuantity <= 0) {
      resetSubmittingState();
      AppSnackbar.error(_quantityLimitTips);
      return;
    }
    if (price <= 0) {
      resetSubmittingState();
      AppSnackbar.error('app.market.filter.message.price_error'.tr);
      return;
    }
    if (nums <= 0) {
      resetSubmittingState();
      AppSnackbar.error('app.market.detail.message.num_error'.tr);
      return;
    }
    if (nums > maxQuantity) {
      _setNumText(maxQuantity.toString());
      resetSubmittingState();
      AppSnackbar.error(_quantityLimitTips);
      return;
    }
    if (price < _purMinPrice) {
      resetSubmittingState();
      AppSnackbar.error('app.trade.purchase.message.balance_insufficient'.tr);
      return;
    }

    final total = price * nums;
    final available = (user.fund?.available ?? 0) + (user.fund?.gift ?? 0);
    if (available < total) {
      resetSubmittingState();
      Get.dialog(
        AlertDialog(
          title: Text('app.system.tips.title'.tr),
          content: Text('app.trade.purchase.message.supply_price_error'.tr),
          actions: [
            TextButton(
              onPressed: () => Get.back(),
              child: Text('app.common.confirm'.tr),
            ),
          ],
        ),
      );
      return;
    }

    if (!alreadySubmitting) {
      setState(() => _isSubmitting = true);
    }
    try {
      final res = await _shopApi.orderItemBuying(
        params: {
          'nums': nums,
          'price': price,
          'appId': _appId,
          'schemaId': _schemaId,
          'paintWearMax': _wearMax,
          'paintWearMin': _wearMin,
          'paintGradientMin': _gradientMin,
          'paintGradientMax': _gradientMax,
          'paintIndex': _selectedPaintIndex,
        }..removeWhere((key, value) => value == null),
      );

      final datas = res.datas;
      if (datas is String) {
        if (datas.contains('lower than')) {
          Get.dialog(
            AlertDialog(
              title: Text('app.system.tips.title'.tr),
              content: Text(datas),
              actions: [
                TextButton(
                  onPressed: () => Get.back(),
                  child: Text('app.common.confirm'.tr),
                ),
              ],
            ),
          );
          return;
        }
        if (datas.contains('Steam issue')) {
          Get.dialog(
            AlertDialog(
              title: Text('app.system.tips.title'.tr),
              content: Text('app.steam.message.trading_restrictions'.tr),
              actions: [
                TextButton(
                  onPressed: () => Get.back(),
                  child: Text('app.common.confirm'.tr),
                ),
              ],
            ),
          );
          return;
        }
      }

      if (res.success) {
        shouldClosePage = true;
        final buyRequestController = Get.isRegistered<BuyRequestController>()
            ? Get.find<BuyRequestController>()
            : null;
        FocusManager.instance.primaryFocus?.unfocus();
        if (!mounted) {
          return;
        }
        Navigator.of(context).pop(true);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          AppSnackbar.success('app.trade.purchase.message.success'.tr);
          buyRequestController?.refreshMyBuying();
        });
        return;
      } else {
        AppSnackbar.error(
          res.message.isNotEmpty ? res.message : 'app.trade.filter.failed'.tr,
        );
      }
    } finally {
      if (mounted && !shouldClosePage) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _changeQuantity(int delta) {
    final current = int.tryParse(_numController.text.trim()) ?? 0;
    final next = (current + delta).clamp(0, _maxPublishQuantity).toInt();
    _setNumText(next.toString());
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

  Widget _buildItemPreview({required String imageUrl}) {
    return Container(
      width: 92,
      height: 68,
      decoration: BoxDecoration(
        color: _itemPreviewSlate,
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(decoration: itemImageBackgroundDecoration()),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.18),
              ),
            ),
          ),
          Positioned.fill(
            child: Center(
              child: imageUrl.isEmpty
                  ? Icon(
                      Icons.image_not_supported_outlined,
                      color: Colors.white.withValues(alpha: 0.4),
                      size: 22,
                    )
                  : CachedNetworkImage(
                      imageUrl: imageUrl,
                      width: 78,
                      height: 78,
                      fit: BoxFit.contain,
                      placeholder: (context, _) => const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      errorWidget: (context, _, __) => const Icon(
                        Icons.image_not_supported_outlined,
                        color: Colors.white54,
                        size: 22,
                      ),
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

  Widget _buildFilterCard({required String title, required Widget child}) {
    return _buildSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              color: _bodyColor,
              fontSize: 12,
              height: 16 / 12,
              letterSpacing: 0.6,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  List<_ProductPhaseOption> _buildPhaseOptions() {
    final options = <_ProductPhaseOption>[
      _ProductPhaseOption(
        label: 'app.market.csgo.phase_unlimited'.tr,
        value: _phaseUnlimitedValue,
      ),
    ];
    final seen = <String>{_phaseUnlimitedValue};
    for (final paintKit in _paintKits) {
      if (paintKit is! Map) {
        continue;
      }
      final id = paintKit['id']?.toString();
      if (id == null || id.isEmpty || !seen.add(id)) {
        continue;
      }
      final phase = paintKit['phase']?.toString();
      options.add(
        _ProductPhaseOption(
          label: phase == null || phase.isEmpty ? id : phase,
          value: id,
        ),
      );
    }
    return options;
  }

  Widget _buildPhaseDropdown() {
    final options = _buildPhaseOptions();
    final selectedValue = _selectedPaintIndex == null
        ? _phaseUnlimitedValue
        : options.any((option) => option.value == _selectedPaintIndex)
        ? _selectedPaintIndex!
        : _phaseUnlimitedValue;

    return _buildDropdownContainer(
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedValue,
          isExpanded: true,
          menuMaxHeight: 280,
          borderRadius: BorderRadius.circular(12),
          dropdownColor: Colors.white,
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: _bodyColor,
          ),
          style: const TextStyle(
            color: _titleColor,
            fontSize: 14,
            height: 20 / 14,
            fontWeight: FontWeight.w600,
          ),
          items: options
              .map(
                (option) => DropdownMenuItem<String>(
                  value: option.value,
                  child: Text(option.label),
                ),
              )
              .toList(growable: false),
          onChanged: (value) {
            setState(() {
              _selectedPaintIndex = value == _phaseUnlimitedValue
                  ? null
                  : value;
            });
          },
        ),
      ),
    );
  }

  List<_ProductGradientOption> _buildGradientOptions() {
    return <_ProductGradientOption>[
      _ProductGradientOption(
        value: _gradientUnlimitedValue,
        label: 'app.market.csgo.gradient_unlimited'.tr,
      ),
      const _ProductGradientOption(
        value: '95-100',
        label: '≥95%',
        min: 95,
        max: 100,
      ),
      const _ProductGradientOption(
        value: '96-100',
        label: '≥96%',
        min: 96,
        max: 100,
      ),
      const _ProductGradientOption(
        value: '97-100',
        label: '≥97%',
        min: 97,
        max: 100,
      ),
      const _ProductGradientOption(
        value: '98-100',
        label: '≥98%',
        min: 98,
        max: 100,
      ),
      const _ProductGradientOption(
        value: '99-100',
        label: '≥99%',
        min: 99,
        max: 100,
      ),
    ];
  }

  String _currentGradientDropdownValue(List<_ProductGradientOption> options) {
    if (_gradientMin == null && _gradientMax == null) {
      return _gradientUnlimitedValue;
    }
    for (final option in options) {
      if (option.min == _gradientMin && option.max == _gradientMax) {
        return option.value;
      }
    }
    return _gradientUnlimitedValue;
  }

  Widget _buildGradientDropdown() {
    final options = _buildGradientOptions();
    return _buildDropdownContainer(
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _currentGradientDropdownValue(options),
          isExpanded: true,
          menuMaxHeight: 280,
          borderRadius: BorderRadius.circular(12),
          dropdownColor: Colors.white,
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: _bodyColor,
          ),
          style: const TextStyle(
            color: _titleColor,
            fontSize: 14,
            height: 20 / 14,
            fontWeight: FontWeight.w600,
          ),
          items: options
              .map(
                (option) => DropdownMenuItem<String>(
                  value: option.value,
                  child: Text(option.label),
                ),
              )
              .toList(growable: false),
          onChanged: (value) {
            final option = options.firstWhere(
              (option) => option.value == value,
              orElse: () => options.first,
            );
            setState(() {
              _gradientMin = option.min;
              _gradientMax = option.max;
            });
          },
        ),
      ),
    );
  }

  Widget _buildDropdownContainer({required Widget child}) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: _fieldSurface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: child,
    );
  }

  Widget _buildWearDropdown(List<_ProductWearQuickOption> quickOptions) {
    final currentValue = _currentWearDropdownValue(quickOptions);
    final menuLabels = <String>[
      _wearUnlimitedLabel,
      ...quickOptions.map(_wearOptionValue),
      _wearCustomLabel,
    ];
    final selectedCustomLabel =
        (_filterLabel == null || _filterLabel == _wearUnlimitedLabel)
        ? _wearCustomLabel
        : _filterLabel!;

    return _buildDropdownContainer(
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: currentValue,
          isExpanded: true,
          menuMaxHeight: 280,
          borderRadius: BorderRadius.circular(12),
          dropdownColor: Colors.white,
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: _bodyColor,
          ),
          style: const TextStyle(
            color: _titleColor,
            fontSize: 14,
            height: 20 / 14,
            fontWeight: FontWeight.w600,
          ),
          selectedItemBuilder: (context) {
            return menuLabels.map((label) {
              final displayLabel = label == _wearCustomLabel
                  ? selectedCustomLabel
                  : label;
              return Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  displayLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _titleColor,
                    fontSize: 14,
                    height: 20 / 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            }).toList();
          },
          items: [
            DropdownMenuItem<String>(
              value: _wearUnlimitedValue,
              child: Text(_wearUnlimitedLabel),
            ),
            ...quickOptions.map(
              (option) => DropdownMenuItem<String>(
                value: _wearOptionValue(option),
                child: Text(_wearOptionValue(option)),
              ),
            ),
            DropdownMenuItem<String>(
              value: _wearCustomValue,
              child: Text(_wearCustomLabel),
            ),
          ],
          onChanged: (value) => _handleWearDropdownChanged(value, quickOptions),
        ),
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

  Widget _buildQuantityControlButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: SizedBox(
          width: 32,
          height: 32,
          child: Icon(icon, size: 18, color: _bodyColor),
        ),
      ),
    );
  }

  Widget _buildSkeletonBox({
    required double width,
    required double height,
    double radius = 999,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }

  Widget _buildLoadingScaffold() {
    const contentBottomPadding = 12.0;
    return Scaffold(
      backgroundColor: _pageBackground,
      appBar: SettingsStyleAppBar(
        title: Text('app.market.detail.release_purchase'.tr),
      ),
      body: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(16, 24, 16, contentBottomPadding),
        children: [
          _buildSurfaceCard(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                _buildSkeletonBox(width: 72, height: 72, radius: 8),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSkeletonBox(width: 176, height: 24, radius: 6),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 16,
                        runSpacing: 8,
                        children: [
                          _buildSkeletonBox(width: 116, height: 16, radius: 6),
                          _buildSkeletonBox(width: 124, height: 16, radius: 6),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildSurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSkeletonBox(width: 112, height: 16, radius: 6),
                const SizedBox(height: 12),
                _buildSkeletonBox(
                  width: double.infinity,
                  height: 44,
                  radius: 8,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _buildSurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSkeletonBox(width: 124, height: 16, radius: 6),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildSkeletonBox(width: 14, height: 28, radius: 6),
                    const SizedBox(width: 8),
                    _buildSkeletonBox(width: 96, height: 32, radius: 8),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildSurfaceCard(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSkeletonBox(width: 144, height: 16, radius: 6),
                      const SizedBox(height: 8),
                      _buildSkeletonBox(width: 164, height: 12, radius: 6),
                      const SizedBox(height: 4),
                      _buildSkeletonBox(width: 138, height: 12, radius: 6),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _buildSkeletonBox(width: 120, height: 40, radius: 4),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(21),
            decoration: BoxDecoration(
              color: _softSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _surfaceStroke),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSkeletonBox(width: 136, height: 16, radius: 6),
                const SizedBox(height: 16),
                _buildSkeletonBox(
                  width: double.infinity,
                  height: 42,
                  radius: 8,
                ),
                const SizedBox(height: 16),
                _buildSkeletonBox(
                  width: double.infinity,
                  height: 42,
                  radius: 8,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _buildSurfaceCard(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
            borderRadius: const BorderRadius.all(Radius.circular(16)),
            child: Column(
              children: [
                _buildSkeletonBox(width: 104, height: 16, radius: 6),
                const SizedBox(height: 10),
                _buildSkeletonBox(width: 132, height: 40, radius: 8),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
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
              child: _buildSkeletonBox(
                width: double.infinity,
                height: 48,
                radius: 8,
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
    if (_isLoading) {
      return _buildLoadingScaffold();
    }
    final schema = _schema;
    final imageUrl = schema?.imageUrl ?? '';
    final itemTitle = schema?.marketName ?? schema?.marketHashName ?? '-';
    final sellMin = schema?.sellMin ?? 0;
    final buyMax = schema?.buyMax ?? 0;
    final wearQuickOptions = _showFilter
        ? _buildWearQuickOptions(schema?.tags?.exterior?.key)
        : const <_ProductWearQuickOption>[];
    final quantityTips = _quantityLimitTips;
    final priceHint = _purMinPrice > 0
        ? _displayAmount(currency, _purMinPrice)
        : '0.00';
    final totalDisplay = _displayAmount(currency, _totalAmount());
    const contentBottomPadding = 12.0;
    return Scaffold(
      backgroundColor: _pageBackground,
      appBar: SettingsStyleAppBar(
        title: Text('app.market.detail.release_purchase'.tr),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 24, 16, contentBottomPadding),
        children: [
          _buildSurfaceCard(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                _buildItemPreview(imageUrl: imageUrl),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        itemTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _titleColor,
                          fontSize: 18,
                          height: 28 / 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 16,
                        runSpacing: 8,
                        children: [
                          _buildStatItem(
                            label: 'app.market.detail.sale_lowest'.tr,
                            value: currency.format(sellMin),
                          ),
                          _buildStatItem(
                            label: 'app.market.detail.purchase_highest'.tr,
                            value: currency.format(buyMax),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_showPhaseFilter) ...[
            const SizedBox(height: 16),
            _buildFilterCard(
              title: 'app.market.csgo.phase'.tr,
              child: _buildPhaseDropdown(),
            ),
          ],
          if (_showGradientFilter) ...[
            const SizedBox(height: 16),
            _buildFilterCard(
              title: 'app.market.csgo.gradient_range'.tr,
              child: _buildGradientDropdown(),
            ),
          ],
          if (_showFilter) ...[
            const SizedBox(height: 16),
            _buildFilterCard(
              title: 'app.market.filter.csgo.wear_interval'.tr,
              child: _buildWearDropdown(wearQuickOptions),
            ),
          ],
          const SizedBox(height: 20),
          _buildSurfaceCard(
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
                        onEditingComplete: _calibratePrice,
                        onSubmitted: (_) => _calibratePrice(),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildSurfaceCard(
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
                        quantityTips,
                        maxLines: 3,
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
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: _fieldSurface,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildQuantityControlButton(
                        icon: Icons.remove_rounded,
                        onTap: () => _changeQuantity(-1),
                      ),
                      SizedBox(
                        width: 48,
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
                      _buildQuantityControlButton(
                        icon: Icons.add_rounded,
                        onTap: () => _changeQuantity(1),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
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
                    const Icon(
                      Icons.shield_outlined,
                      size: 18,
                      color: _bodyColor,
                    ),
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
                          text: 'app.trade.purchase.buyer_notice_2'.tr,
                          style: const TextStyle(
                            color: _dangerColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        TextSpan(
                          text: ' ${'app.trade.purchase.buyer_notice_3'.tr}',
                        ),
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
          ),
          const SizedBox(height: 12),
          _buildTotalAmountCard(currency: currency, totalDisplay: totalDisplay),
        ],
      ),

      bottomNavigationBar: SafeArea(
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
                      : const LinearGradient(
                          colors: [_brandBlue, _brandBlueEnd],
                        ),
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
                    onTap: _isSubmitting ? null : _confirmSubmit,
                    child: SizedBox(
                      height: 48,
                      child: Center(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          switchInCurve: Curves.easeOut,
                          switchOutCurve: Curves.easeIn,
                          child: _isSubmitting
                              ? Row(
                                  key: const ValueKey('product-buying-loading'),
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
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
                                  key: const ValueKey('product-buying-idle'),
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'app.market.detail.release_purchase'.tr,
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
      ),
    );
  }
}

class _ProductWearQuickOption {
  final double min;
  final double max;

  const _ProductWearQuickOption(this.min, this.max);

  String get minText => min.toStringAsFixed(2);

  String get maxText => max.toStringAsFixed(2);

  String get label => '${min.toStringAsFixed(2)}-${max.toStringAsFixed(2)}';
}

class _ProductPhaseOption {
  final String label;
  final String value;

  const _ProductPhaseOption({required this.label, required this.value});
}

class _ProductGradientOption {
  final String value;
  final String label;
  final double? min;
  final double? max;

  const _ProductGradientOption({
    required this.value,
    required this.label,
    this.min,
    this.max,
  });
}

class _ProductWearRange {
  final double? min;
  final double? max;

  const _ProductWearRange({this.min, this.max});
}

class _ProductFilterResult {
  final double? wearMin;
  final double? wearMax;

  const _ProductFilterResult({this.wearMin, this.wearMax});
}
