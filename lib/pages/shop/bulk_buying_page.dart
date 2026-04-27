import 'dart:async';

import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:tronskins_app/common/widgets/settings_style_app_bar.dart';
import 'package:get/get.dart';
import 'package:tronskins_app/api/market.dart';
import 'package:tronskins_app/api/model/market/market_models.dart';
import 'package:tronskins_app/api/shop_product.dart';
import 'package:tronskins_app/common/hooks/currency/CurrencyController.dart';
import 'package:tronskins_app/common/storage/user_storage.dart';
import 'package:tronskins_app/common/utils/app_snackbar.dart';
import 'package:tronskins_app/common/widgets/figma_confirmation_dialog.dart';
import 'package:tronskins_app/components/filter/filter_sheet_style.dart';
import 'package:tronskins_app/components/game_item/game_item_utils.dart';

class BulkBuyingPage extends StatefulWidget {
  const BulkBuyingPage({super.key});

  @override
  State<BulkBuyingPage> createState() => _BulkBuyingPageState();
}

class _BulkBuyingPageState extends State<BulkBuyingPage> {
  static const String _wearUnlimitedValue = '__wear_unlimited__';
  static const String _wearCustomValue = '__wear_custom__';
  static const Color _pageBackground = Color(0xFFF7F9FB);
  static const Color _cardSurface = Colors.white;
  static const Color _fieldSurface = Color(0xFFECEEF0);
  static const Color _surfaceStroke = Color(0x0FC4C5D5);
  static const Color _titleColor = Color(0xFF191C1E);
  static const Color _bodyColor = Color(0xFF444653);
  static const Color _brandBlue = Color(0xFF1E40AF);
  static const Color _brandBlueEnd = Color(0xFF2170E4);
  static const Color _itemPreviewSlate = Color(0xFF1E293B);

  final ApiMarketServer _marketApi = ApiMarketServer();
  final ApiShopProductServer _shopApi = ApiShopProductServer();

  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _numController = TextEditingController();
  final FocusNode _priceFocusNode = FocusNode();

  late final int _appId;
  late final int _schemaId;

  MarketTemplateSchema? _schema;
  List<dynamic>? _paintKits;
  bool _showPaintKits = false;
  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _isLoadingMatches = false;
  Timer? _priceQueryDebounce;
  int _matchQueryVersion = 0;

  final List<MarketListItem> _matchedItems = <MarketListItem>[];
  double? _wearMin;
  double? _wearMax;
  String? _filterLabel;

  @override
  void initState() {
    super.initState();
    final args = Get.arguments as Map<String, dynamic>? ?? {};
    _appId = args['appId'] as int? ?? 730;
    _schemaId = args['schemaId'] as int? ?? 0;
    _priceController.addListener(_onInputChanged);
    _numController.addListener(_onInputChanged);
    _priceFocusNode.addListener(_handlePriceFocusChange);
    _loadData();
  }

  @override
  void dispose() {
    _priceQueryDebounce?.cancel();
    _priceController.removeListener(_onInputChanged);
    _numController.removeListener(_onInputChanged);
    _priceFocusNode.removeListener(_handlePriceFocusChange);
    _priceController.dispose();
    _numController.dispose();
    _priceFocusNode.dispose();
    super.dispose();
  }

  void _onInputChanged() {
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  void _handlePriceFocusChange() {
    if (_priceFocusNode.hasFocus) {
      return;
    }
    _priceQueryDebounce?.cancel();
    unawaited(_queryMatchedOnSale());
  }

  void _onPriceInputChanged(String value) {
    _sanitizePrice(value);
    _scheduleMatchedQuery();
  }

  void _scheduleMatchedQuery({
    Duration delay = const Duration(milliseconds: 360),
  }) {
    _priceQueryDebounce?.cancel();
    _priceQueryDebounce = Timer(delay, () {
      if (!mounted) {
        return;
      }
      unawaited(_queryMatchedOnSale());
    });
  }

  bool get _showFilter {
    if (_appId == 440) {
      return false;
    }
    if (_showPaintKits) {
      return true;
    }
    final typeKey = _schema?.tags?.type?.key ?? _schema?.tags?.type?.name;
    const excludedTypes = <String>{
      'CSGO_Type_WeaponCase',
      'Type_CustomPlayer',
      'CSGO_Tool_Sticker',
    };
    return !excludedTypes.contains(typeKey);
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
      _paintKits = res.datas?.paintKits;
      _showPaintKits = _isShowPaintKits(_schema, _paintKits);
      _filterLabel = _buildFilterLabel();
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  bool _isShowPaintKits(MarketTemplateSchema? schema, List<dynamic>? kits) {
    if (schema == null) {
      return false;
    }
    final hash = schema.marketHashName?.toLowerCase() ?? '';
    return hash.contains('doppler') || (kits != null && kits.isNotEmpty);
  }

  void _sanitizePrice(String value) {
    if (value.isEmpty) {
      return;
    }
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
      AppSnackbar.error('app.market.detail.bulk_buying.price_decimal_error'.tr);
    }
  }

  void _sanitizeNum(String value) {
    if (value.contains('.')) {
      _numController.text = value.split('.').first;
      _numController.selection = TextSelection.fromPosition(
        TextPosition(offset: _numController.text.length),
      );
      AppSnackbar.error('app.market.detail.message.num_error'.tr);
    }
    var numValue = int.tryParse(_numController.text) ?? 0;
    if (numValue > 200) {
      numValue = 200;
      _numController.text = '200';
      _numController.selection = TextSelection.fromPosition(
        TextPosition(offset: _numController.text.length),
      );
    }
    if (_matchedItems.isNotEmpty && numValue > _matchedItems.length) {
      _numController.text = _matchedItems.length.toString();
      _numController.selection = TextSelection.fromPosition(
        TextPosition(offset: _numController.text.length),
      );
    }
  }

  Future<void> _queryMatchedOnSale() async {
    final maxPrice = double.tryParse(_priceController.text);
    if (maxPrice == null || maxPrice <= 0) {
      _matchQueryVersion++;
      if (_matchedItems.isNotEmpty || _isLoadingMatches) {
        setState(() {
          _matchedItems.clear();
          _isLoadingMatches = false;
        });
      }
      return;
    }

    final user = UserStorage.getUserInfo();
    final useAuth = user != null;
    final userId = int.tryParse(user?.id ?? '');
    final queryVersion = ++_matchQueryVersion;

    setState(() => _isLoadingMatches = true);
    try {
      final res = await _marketApi.onSaleList(
        appId: _appId,
        schemaId: _schemaId,
        page: 1,
        pageSize: 100,
        maxPrice: maxPrice,
        userId: userId,
        useAuth: useAuth,
        fallbackToPublicOnFail: true,
      );
      if (!mounted || queryVersion != _matchQueryVersion) {
        return;
      }
      final items = res.datas?.items ?? <MarketListItem>[];
      items.sort((a, b) => (a.price ?? 0).compareTo(b.price ?? 0));
      _matchedItems
        ..clear()
        ..addAll(items);

      final currentNum = int.tryParse(_numController.text) ?? 0;
      if (currentNum > _matchedItems.length) {
        _numController.text = _matchedItems.length.toString();
        _numController.selection = TextSelection.fromPosition(
          TextPosition(offset: _numController.text.length),
        );
      }
    } finally {
      if (mounted && queryVersion == _matchQueryVersion) {
        setState(() => _isLoadingMatches = false);
      }
    }
  }

  double _totalAmount() {
    final quantity = int.tryParse(_numController.text) ?? 0;
    if (quantity <= 0 || _matchedItems.isEmpty) {
      return 0;
    }
    final selected = _matchedItems.take(quantity);
    var total = 0.0;
    for (final item in selected) {
      total += item.price ?? 0;
    }
    return total;
  }

  bool get _isEnglishLocale =>
      (Get.locale?.languageCode.toLowerCase() ?? '') == 'en';

  Future<void> _confirmSubmit() async {
    if (_isSubmitting) {
      return;
    }
    final user = UserStorage.getUserInfo();
    final price = double.tryParse(_priceController.text) ?? 0;
    final num = int.tryParse(_numController.text) ?? 0;
    if (user == null || price <= 0 || num <= 0) {
      await _submit();
      return;
    }

    final currency = Get.find<CurrencyController>();
    final itemTitle = _schema?.marketName ?? _schema?.marketHashName ?? '-';
    final estimatedTotal = _matchedItems.isNotEmpty
        ? _totalAmount()
        : price * num;
    final submitted = await showFigmaModal<bool>(
      context: context,
      barrierDismissible: false,
      child: FigmaAsyncConfirmationDialog(
        icon: Icons.inventory_2_rounded,
        iconColor: _brandBlue,
        iconBackgroundColor: const Color.fromRGBO(30, 64, 175, 0.10),
        title: _isEnglishLocale ? 'Confirm Bulk Buy' : '确认批量收购',
        message: _isEnglishLocale
            ? 'Review the batch parameters before submitting this bulk buy.'
            : '请在提交前确认本次批量收购参数。',
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              itemTitle,
              softWrap: true,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF0F172A),
                fontSize: 14,
                fontWeight: FontWeight.w700,
                height: 20 / 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _isEnglishLocale
                  ? 'Max ${currency.format(price)} · Qty $num'
                  : '最高单价 ${currency.format(price)} · 数量 $num',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 20 / 13,
              ),
            ),
          ],
        ),
        highlightText: _isEnglishLocale
            ? 'Estimated total: ${currency.format(estimatedTotal)}'
            : '预计总额 ${currency.format(estimatedTotal)}',
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

    final result = await showModalBottomSheet<_BulkWearRange>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            bool isQuickSelected(_BulkWearQuickOption option) {
              final min = double.tryParse(wearMinController.text.trim());
              final max = double.tryParse(wearMaxController.text.trim());
              if (min == null || max == null) {
                return false;
              }
              return (min - option.min).abs() < 0.000001 &&
                  (max - option.max).abs() < 0.000001;
            }

            Future<void> closeSheet(_BulkWearRange result) async {
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
                    onReset: () => closeSheet(const _BulkWearRange()),
                    onClose: () => Navigator.of(context).pop(),
                    confirmLabel: 'app.market.filter.finish'.tr,
                    onConfirm: () {
                      final normalized = _normalizeWearRange(
                        minInput: wearMinController.text,
                        maxInput: wearMaxController.text,
                        exteriorKey: exteriorKey,
                      );
                      closeSheet(normalized);
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
                                    (option) => _buildWearChip(
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

    _applyWearFilter(min: result.min, max: result.max);
  }

  String _buildFilterLabel() {
    if (_wearMin == null && _wearMax == null) {
      return _wearUnlimitedLabel;
    }
    final min = _wearMin ?? 0;
    final max = _wearMax ?? 0;
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

  String _wearOptionValue(_BulkWearQuickOption option) {
    return '${option.minText}-${option.maxText}';
  }

  bool _matchesWearOption(_BulkWearQuickOption option) {
    if (_wearMin == null || _wearMax == null) {
      return false;
    }
    return (_wearMin! - option.min).abs() < 0.000001 &&
        (_wearMax! - option.max).abs() < 0.000001;
  }

  String _currentWearDropdownValue(List<_BulkWearQuickOption> quickOptions) {
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
    List<_BulkWearQuickOption> quickOptions,
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

  List<_BulkWearQuickOption> _buildWearQuickOptions(String? exteriorKey) {
    switch (exteriorKey) {
      case 'WearCategory0':
        return const <_BulkWearQuickOption>[
          _BulkWearQuickOption(0.00, 0.01),
          _BulkWearQuickOption(0.01, 0.02),
          _BulkWearQuickOption(0.02, 0.03),
          _BulkWearQuickOption(0.03, 0.04),
          _BulkWearQuickOption(0.04, 0.07),
        ];
      case 'WearCategory1':
        return const <_BulkWearQuickOption>[
          _BulkWearQuickOption(0.07, 0.08),
          _BulkWearQuickOption(0.08, 0.09),
          _BulkWearQuickOption(0.09, 0.10),
          _BulkWearQuickOption(0.10, 0.11),
          _BulkWearQuickOption(0.11, 0.15),
        ];
      case 'WearCategory2':
        return const <_BulkWearQuickOption>[
          _BulkWearQuickOption(0.15, 0.18),
          _BulkWearQuickOption(0.18, 0.21),
          _BulkWearQuickOption(0.21, 0.24),
          _BulkWearQuickOption(0.24, 0.27),
          _BulkWearQuickOption(0.27, 0.38),
        ];
      case 'WearCategory3':
        return const <_BulkWearQuickOption>[
          _BulkWearQuickOption(0.38, 0.39),
          _BulkWearQuickOption(0.39, 0.40),
          _BulkWearQuickOption(0.40, 0.41),
          _BulkWearQuickOption(0.41, 0.42),
          _BulkWearQuickOption(0.42, 0.45),
        ];
      case 'WearCategory4':
        return const <_BulkWearQuickOption>[
          _BulkWearQuickOption(0.45, 0.50),
          _BulkWearQuickOption(0.50, 0.60),
          _BulkWearQuickOption(0.60, 0.70),
          _BulkWearQuickOption(0.70, 0.75),
          _BulkWearQuickOption(0.75, 0.80),
        ];
      default:
        return const <_BulkWearQuickOption>[
          _BulkWearQuickOption(0.00, 0.01),
          _BulkWearQuickOption(0.01, 0.02),
          _BulkWearQuickOption(0.02, 0.03),
          _BulkWearQuickOption(0.03, 0.04),
          _BulkWearQuickOption(0.04, 0.07),
        ];
    }
  }

  _BulkWearRange _normalizeWearRange({
    required String minInput,
    required String maxInput,
    required String? exteriorKey,
  }) {
    final options = _buildWearQuickOptions(exteriorKey);
    final minAllowed = options.first.min;
    final maxAllowed = options.last.max;

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

    return _BulkWearRange(
      min: min != null ? double.parse(min.toStringAsFixed(2)) : null,
      max: max != null ? double.parse(max.toStringAsFixed(2)) : null,
    );
  }

  Widget _buildWearChip({
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

  void _changeQuantity(int delta) {
    final current = int.tryParse(_numController.text.trim()) ?? 0;
    var maxAllowed = 200;
    if (_matchedItems.isNotEmpty) {
      maxAllowed = _matchedItems.length.clamp(0, 200);
    }
    final next = (current + delta).clamp(0, maxAllowed);
    _numController.text = next.toString();
    _numController.selection = TextSelection.fromPosition(
      TextPosition(offset: _numController.text.length),
    );
  }

  String _displayAmount(CurrencyController currency, double amount) {
    final formatted = currency.format(amount);
    final prefix = '${currency.symbol} ';
    if (formatted.startsWith(prefix)) {
      return formatted.substring(prefix.length);
    }
    return formatted.replaceFirst(currency.symbol, '').trim();
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
      AppSnackbar.error('app.system.message.nologin'.tr);
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();

    final price = double.tryParse(_priceController.text) ?? 0;
    final num = int.tryParse(_numController.text) ?? 0;
    final sellMin = _schema?.sellMin ?? 0;

    if (price <= 0) {
      resetSubmittingState();
      AppSnackbar.error('app.market.filter.message.price_error'.tr);
      return;
    }

    if (num <= 0) {
      resetSubmittingState();
      AppSnackbar.error('app.market.detail.message.num_error'.tr);
      return;
    }

    if (num > 200) {
      resetSubmittingState();
      AppSnackbar.error('app.market.detail.bulk_buying.num_error'.tr);
      return;
    }

    if (sellMin > 0 && price < sellMin) {
      resetSubmittingState();
      AppSnackbar.error('app.market.detail.bulk_buying.price_error'.tr);
      return;
    }

    await _queryMatchedOnSale();
    if (num > _matchedItems.length) {
      resetSubmittingState();
      AppSnackbar.error('app.market.detail.bulk_buying.num_over'.tr);
      return;
    }

    if (!alreadySubmitting) {
      setState(() => _isSubmitting = true);
    }
    try {
      final res = await _shopApi.orderItemBatchBuy(
        params: {
          'num': num,
          'price': price,
          'appId': _appId,
          'id': _schemaId,
          'paintWearMax': _wearMax,
          'paintWearMin': _wearMin,
        }..removeWhere((key, value) => value == null),
      );

      final datas = res.datas;
      if (datas is String) {
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
        if (datas.contains('Inventory privacy')) {
          Get.dialog(
            AlertDialog(
              title: Text('app.system.tips.title'.tr),
              content: Text('app.inventory.message.privacy'.tr),
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
        FocusManager.instance.primaryFocus?.unfocus();
        if (!mounted) {
          return;
        }
        Navigator.of(context).pop(true);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          AppSnackbar.success('app.trade.buy.message.success'.tr);
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

  Widget _buildItemTitle(String title) {
    return Text(
      title,
      softWrap: true,
      style: const TextStyle(
        color: _titleColor,
        fontSize: 16,
        height: 22 / 16,
        fontWeight: FontWeight.w700,
      ),
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
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(_brandBlue),
                        ),
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

  Widget _buildWearDropdown(List<_BulkWearQuickOption> quickOptions) {
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

    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: _fieldSurface,
        borderRadius: BorderRadius.circular(8),
      ),
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

  Widget _buildMatchStatusChip() {
    if (_isLoadingMatches) {
      return const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(_brandBlue),
        ),
      );
    }
    return Container(
      constraints: const BoxConstraints(maxWidth: 168),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _fieldSurface,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '${_matchedItems.length} ${'app.market.detail.bulk_buying.match'.tr}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: _bodyColor,
          fontSize: 11,
          height: 16 / 11,
          fontWeight: FontWeight.w600,
        ),
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
        title: Text('app.market.detail.bulk_buying.title'.tr),
      ),
      body: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 24, 16, contentBottomPadding),
        children: [
          _buildSurfaceCard(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                _buildSkeletonBox(width: 72, height: 68, radius: 8),
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
                      const SizedBox(height: 10),
                      _buildSkeletonBox(width: 88, height: 24, radius: 999),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _buildSkeletonBox(width: 120, height: 40, radius: 4),
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
    final title = schema?.marketName ?? schema?.marketHashName ?? '-';
    final sellMin = schema?.sellMin ?? 0;
    final buyMax = schema?.buyMax ?? 0;
    final wearQuickOptions = _showFilter
        ? _buildWearQuickOptions(schema?.tags?.exterior?.key)
        : const <_BulkWearQuickOption>[];
    final priceHint = sellMin > 0 ? _displayAmount(currency, sellMin) : '0.00';
    final totalDisplay = _displayAmount(currency, _totalAmount());
    const contentBottomPadding = 12.0;

    return Scaffold(
      backgroundColor: _pageBackground,
      appBar: SettingsStyleAppBar(
        title: Text('app.market.detail.bulk_buying.title'.tr),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, contentBottomPadding),
        children: [
          _buildSurfaceCard(
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildItemPreview(imageUrl: imageUrl),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildItemTitle(title),
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
          if (_showFilter) ...[
            const SizedBox(height: 16),
            _buildSurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'app.market.filter.csgo.wear_interval'.tr.toUpperCase(),
                    style: const TextStyle(
                      color: _bodyColor,
                      fontSize: 12,
                      height: 16 / 12,
                      letterSpacing: 0.6,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildWearDropdown(wearQuickOptions),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          _buildSurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'app.market.detail.bulk_buying.price_highest'.tr
                      .toUpperCase(),
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
                        focusNode: _priceFocusNode,
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
                        onChanged: _onPriceInputChanged,
                        onEditingComplete: _queryMatchedOnSale,
                        onSubmitted: (_) => _queryMatchedOnSale(),
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
                      const SizedBox(height: 10),
                      _buildMatchStatusChip(),
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
                                  key: const ValueKey('bulk-buying-loading'),
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
                                  key: const ValueKey('bulk-buying-idle'),
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'app.trade.buy.text'.tr,
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

class _BulkWearQuickOption {
  final double min;
  final double max;

  const _BulkWearQuickOption(this.min, this.max);

  String get minText => min.toStringAsFixed(2);

  String get maxText => max.toStringAsFixed(2);

  String get label => '${min.toStringAsFixed(2)}-${max.toStringAsFixed(2)}';
}

class _BulkWearRange {
  final double? min;
  final double? max;

  const _BulkWearRange({this.min, this.max});
}
