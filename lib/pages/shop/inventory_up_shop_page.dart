import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tronskins_app/api/model/shop/shop_models.dart';
import 'package:tronskins_app/api/shop_product.dart';
import 'package:tronskins_app/api/steam.dart';
import 'package:tronskins_app/common/hooks/currency/CurrencyController.dart';
import 'package:tronskins_app/common/utils/app_snackbar.dart';
import 'package:tronskins_app/common/widgets/settings_style_app_bar.dart';
import 'package:tronskins_app/components/game_item/game_item_image.dart';
import 'package:tronskins_app/components/game_item/game_item_models.dart';
import 'package:tronskins_app/controllers/inventory/inventory_controller.dart';
import 'package:tronskins_app/pages/shop/inventory_up_shop_confirm_page.dart';
import 'package:tronskins_app/routes/app_routes.dart';

class _InventoryMergeGroup {
  _InventoryMergeGroup(this.key, InventoryItem first) : items = [first];

  final String key;
  final List<InventoryItem> items;
}

enum _PricingPreset { min, average, max }

class InventoryUpShopPage extends StatefulWidget {
  const InventoryUpShopPage({super.key});

  @override
  State<InventoryUpShopPage> createState() => _InventoryUpShopPageState();
}

class _InventoryUpShopPageState extends State<InventoryUpShopPage> {
  final ApiShopProductServer _shopApi = ApiShopProductServer();
  final ApiSteamServer _steamApi = ApiSteamServer();
  final InventoryController _inventoryController =
      Get.isRegistered<InventoryController>()
      ? Get.find<InventoryController>()
      : Get.put(InventoryController());

  final Map<int, TextEditingController> _controllers = {};
  final Map<int, double> _prices = {};

  late final List<InventoryItem> _items;
  late final Map<String, ShopSchemaInfo> _schemas;

  double _feeRate = 0;
  double _minFee = 0;
  bool _loadingParams = true;
  bool _isSubmitting = false;
  bool _mergeSameItems = false;

  static const double _minSellPrice = 0.02;

  @override
  void initState() {
    super.initState();
    final args = Get.arguments as Map<String, dynamic>? ?? {};
    _items =
        (args['items'] as List?)
            ?.whereType<InventoryItem>()
            .where((item) => item.id != null)
            .toList() ??
        <InventoryItem>[];
    final rawSchemas = args['schemas'];
    final schemaMap = <String, ShopSchemaInfo>{};
    if (rawSchemas is Map) {
      rawSchemas.forEach((key, value) {
        if (value is ShopSchemaInfo) {
          schemaMap[key.toString()] = value;
        }
      });
    }
    _schemas = schemaMap;

    for (final item in _items) {
      final id = item.id!;
      _controllers[id] = TextEditingController();
      _prices[id] = 0;
    }

    Future.microtask(_loadParams);
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  ShopSchemaInfo? _lookupSchema(InventoryItem item) {
    final hash = item.marketHashName;
    if (hash != null && _schemas.containsKey(hash)) {
      return _schemas[hash];
    }
    final key = item.schemaId?.toString();
    if (key != null && _schemas.containsKey(key)) {
      return _schemas[key];
    }
    return null;
  }

  Map<String, dynamic>? _resolveAsset(InventoryItem item) {
    final raw = item.raw;
    if (item.appId == 730 && raw['csgoAsset'] is Map<String, dynamic>) {
      return raw['csgoAsset'] as Map<String, dynamic>;
    }
    if (item.appId == 440 && raw['tf2Asset'] is Map<String, dynamic>) {
      return raw['tf2Asset'] as Map<String, dynamic>;
    }
    if (item.appId == 570 && raw['dota2Asset'] is Map<String, dynamic>) {
      return raw['dota2Asset'] as Map<String, dynamic>;
    }
    return raw;
  }

  String? _extractText(dynamic raw, List<String> keys) {
    if (raw is Map) {
      for (final key in keys) {
        final value = raw[key];
        if (value != null) {
          return value.toString();
        }
      }
    }
    return null;
  }

  double? _extractDouble(dynamic raw, List<String> keys) {
    if (raw is Map) {
      for (final key in keys) {
        final value = raw[key];
        if (value == null) {
          continue;
        }
        if (value is num) {
          return value.toDouble();
        }
        final parsed = double.tryParse(value.toString());
        if (parsed != null) {
          return parsed;
        }
      }
    }
    return null;
  }

  String? _extractWearText(InventoryItem item, Map<String, dynamic>? asset) {
    return _extractText(asset, ['paint_wear', 'paintWear']) ??
        _extractText(item.raw, ['paint_wear', 'paintWear']) ??
        item.paintWear?.toString();
  }

  double? _extractWearValue(InventoryItem item, Map<String, dynamic>? asset) {
    final text = _extractWearText(item, asset);
    if (text != null) {
      final parsed = double.tryParse(text);
      if (parsed != null) {
        return parsed;
      }
    }
    return item.paintWear ?? _extractDouble(asset, ['paint_wear', 'paintWear']);
  }

  double _parsePriceValue(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  double _truncateTo2(double value) {
    return (value * 100).floor() / 100;
  }

  double _normalizePrice(double value) {
    if (!value.isFinite || value <= 0) {
      return 0;
    }
    final rounded = double.parse(value.toStringAsFixed(2));
    if (rounded < _minSellPrice) {
      return _minSellPrice;
    }
    return rounded;
  }

  String _itemMergeKey(InventoryItem item) {
    final schemaId = item.schemaId;
    if (schemaId != null) {
      return 'schema:$schemaId';
    }
    final marketHashName = item.marketHashName;
    if (marketHashName != null && marketHashName.isNotEmpty) {
      return 'hash:$marketHashName';
    }
    final id = item.id;
    if (id != null) {
      return 'id:$id';
    }
    return 'raw:${item.raw.hashCode}';
  }

  List<_InventoryMergeGroup> _buildMergedGroups() {
    final groups = <String, _InventoryMergeGroup>{};
    for (final item in _items) {
      final key = _itemMergeKey(item);
      final exists = groups[key];
      if (exists != null) {
        exists.items.add(item);
      } else {
        groups[key] = _InventoryMergeGroup(key, item);
      }
    }
    return groups.values.toList(growable: false);
  }

  List<_InventoryMergeGroup> _visibleGroups() {
    if (!_mergeSameItems) {
      return _items
          .map((item) => _InventoryMergeGroup('id:${item.id}', item))
          .toList(growable: false);
    }
    return _buildMergedGroups();
  }

  List<int> _groupIds(_InventoryMergeGroup group) {
    return group.items
        .map((item) => item.id)
        .whereType<int>()
        .toList(growable: false);
  }

  int _groupTotalCount(_InventoryMergeGroup group) {
    var count = 0;
    for (final item in group.items) {
      count += _itemCount(item);
    }
    return count;
  }

  bool _groupHasWarning(_InventoryMergeGroup group) {
    for (final item in group.items) {
      final id = item.id;
      if (id == null) {
        continue;
      }
      final price = _prices[id] ?? 0;
      if (price > 0 && _isPriceWarning(item, price)) {
        return true;
      }
    }
    return false;
  }

  void _handlePriceChangedForIds(List<int> ids, String value, {int? sourceId}) {
    if (ids.isEmpty) {
      return;
    }
    if (value.isEmpty) {
      for (final id in ids) {
        _prices[id] = 0;
        if (sourceId == null || sourceId != id) {
          _controllers[id]?.text = '';
        }
      }
      setState(() {});
      return;
    }

    final parsed = double.tryParse(value);
    if (parsed == null) {
      for (final id in ids) {
        _prices[id] = 0;
      }
      setState(() {});
      return;
    }

    final decimal = value.split('.');
    if (decimal.length == 2 && decimal[1].length > 2) {
      final normalized = _truncateTo2(parsed);
      final text = normalized.toStringAsFixed(2);
      for (final id in ids) {
        final controller = _controllers[id];
        if (controller != null && controller.text != text) {
          controller.value = TextEditingValue(
            text: text,
            selection: TextSelection.fromPosition(
              TextPosition(offset: text.length),
            ),
          );
        }
        _prices[id] = normalized;
      }
      setState(() {});
      return;
    }

    for (final id in ids) {
      if (sourceId == null || sourceId != id) {
        final controller = _controllers[id];
        if (controller != null && controller.text != value) {
          controller.text = value;
        }
      }
      _prices[id] = parsed;
    }
    setState(() {});
  }

  void _normalizeInputOnBlurForIds(List<int> ids, {int? sourceId}) {
    if (ids.isEmpty) {
      return;
    }
    final activeId = sourceId ?? ids.first;
    final controller = _controllers[activeId];
    if (controller == null) {
      return;
    }
    var text = controller.text;
    if (text.endsWith('.')) {
      text = text.substring(0, text.length - 1);
      controller.value = TextEditingValue(
        text: text,
        selection: TextSelection.fromPosition(
          TextPosition(offset: text.length),
        ),
      );
    }
    final parsed = double.tryParse(text) ?? 0;
    for (final id in ids) {
      _prices[id] = parsed;
      if (id == activeId) {
        continue;
      }
      final peer = _controllers[id];
      if (peer != null && peer.text != text) {
        peer.text = text;
      }
    }
    setState(() {});
  }

  void _syncMergedGroupPricesFromLead() {
    final groups = _buildMergedGroups();
    for (final group in groups) {
      final ids = _groupIds(group);
      if (ids.length <= 1) {
        continue;
      }

      var mergedPrice = 0.0;
      var mergedText = '';
      for (final id in ids) {
        final currentText = _controllers[id]?.text.trim() ?? '';
        final currentPrice = _prices[id] ?? double.tryParse(currentText) ?? 0;
        if (currentPrice > mergedPrice) {
          mergedPrice = currentPrice;
          mergedText = currentText;
        }
      }

      if (mergedPrice <= 0) {
        mergedPrice = 0;
        mergedText = '';
      } else if (mergedText.isEmpty) {
        mergedText = mergedPrice.toStringAsFixed(2);
      }

      for (final id in ids) {
        _prices[id] = mergedPrice;
        final controller = _controllers[id];
        if (controller != null && controller.text != mergedText) {
          controller.text = mergedText;
        }
      }
    }
  }

  void _setMergeSameItems(bool enable) {
    if (_mergeSameItems == enable) {
      return;
    }
    if (enable) {
      _syncMergedGroupPricesFromLead();
    }
    setState(() {
      _mergeSameItems = enable;
    });
  }

  double _extractReference(InventoryItem item, ShopSchemaInfo? schema) {
    // Keep up-shop appraisal pricing aligned with tronskins-app getReferencePrice:
    // 1) sell_min > 0: use min(buff_min_price, sell_min), and enforce >= 0.02
    // 2) no sell_min: use buff_min_price directly
    // 3) fallback to 0
    if (schema == null) {
      return 0;
    }
    final raw = schema.raw;
    final sellMinPrice = _parsePriceValue(raw['sell_min'] ?? raw['sellMin']);
    final buffMinPrice = _parsePriceValue(
      raw['buff_min_price'] ?? raw['buffMinPrice'],
    );
    if (sellMinPrice > 0) {
      if (buffMinPrice > 0) {
        final price = buffMinPrice < sellMinPrice ? buffMinPrice : sellMinPrice;
        return price > _minSellPrice ? price : _minSellPrice;
      }
      return sellMinPrice > _minSellPrice ? sellMinPrice : _minSellPrice;
    }
    if (buffMinPrice > 0) {
      return buffMinPrice;
    }
    return 0;
  }

  Future<void> _loadParams() async {
    try {
      final res = await _shopApi.getSysParams();
      if (res.success && res.datas != null) {
        final data = res.datas!;
        _feeRate = (data['fee'] as num?)?.toDouble() ?? 0;
        _minFee = (data['minFeeAmount'] as num?)?.toDouble() ?? 0;
      }
    } finally {
      if (mounted) {
        setState(() => _loadingParams = false);
      }
    }
  }

  double _totalPrice() {
    double total = 0;
    for (final item in _items) {
      final id = item.id!;
      final price = _prices[id] ?? 0;
      final count = item.count ?? 1;
      total += price * count;
    }
    return total;
  }

  double _totalFee() {
    final total = _totalPrice();
    final fee = total * _feeRate;
    if (fee < _minFee) {
      return _minFee;
    }
    return fee;
  }

  double _totalIncome() {
    final total = _totalPrice();
    final fee = _totalFee();
    return total - fee;
  }

  int _pointsFromAmount(double amount) {
    if (!amount.isFinite || amount <= 0) {
      return 0;
    }
    return amount.floor();
  }

  int _totalRewardPoints() {
    return _pointsFromAmount(_totalPrice());
  }

  int _totalCount() {
    int count = 0;
    for (final item in _items) {
      count += item.count ?? 1;
    }
    return count;
  }

  int _itemCount(InventoryItem item) {
    return item.count ?? 1;
  }

  void _applyReferencePrice() {
    for (final item in _items) {
      final id = item.id!;
      final referencePrice = _extractReference(item, _lookupSchema(item));
      if (referencePrice <= 0) {
        continue;
      }

      double nextPrice = referencePrice;
      if (nextPrice > 1000) {
        nextPrice -= 0.5;
      } else if (nextPrice > 100) {
        nextPrice -= 0.1;
      } else if (nextPrice > _minSellPrice) {
        nextPrice -= 0.01;
      } else {
        nextPrice = _minSellPrice;
      }

      final normalizedPrice = _normalizePrice(nextPrice);
      if (normalizedPrice <= 0) {
        continue;
      }
      _prices[id] = normalizedPrice;
      _controllers[id]?.text = normalizedPrice.toStringAsFixed(2);
    }
    setState(() {});
  }

  bool _isPriceWarning(InventoryItem item, double price) {
    final schema = _lookupSchema(item);
    if (schema == null) {
      return false;
    }
    final rawSellMin = schema.raw['sell_min'];
    final sellMin = rawSellMin is num
        ? rawSellMin.toDouble()
        : double.tryParse(rawSellMin?.toString() ?? '') ?? 0;
    return sellMin > 10 && price < sellMin * 0.9;
  }

  List<String> _buildWarningLines(Map<int, double> payload) {
    final currency = Get.find<CurrencyController>();
    final warningLines = <String>[];

    for (final item in _items) {
      final id = item.id;
      if (id == null) {
        continue;
      }
      final price = payload[id];
      if (price == null) {
        continue;
      }
      if (_isPriceWarning(item, price)) {
        final schema = _lookupSchema(item);
        final title =
            item.marketName ??
            schema?.marketName ??
            item.marketHashName ??
            '#$id';
        warningLines.add('$title  ${currency.format(price)}');
      }
    }
    return warningLines;
  }

  Future<void> _submit() async {
    if (_isSubmitting) {
      return;
    }
    final payload = <int, double>{};
    for (final item in _items) {
      final id = item.id!;
      final price = _prices[id] ?? 0;
      if (price <= 0) {
        AppSnackbar.error('app.inventory.message.price_and_num_error'.tr);
        return;
      }
      payload[id] = price;
    }
    if (payload.isEmpty) {
      return;
    }

    final currency = Get.find<CurrencyController>();
    final warningLines = _buildWarningLines(payload);
    final expectedIncomeText = _loadingParams
        ? '--'
        : currency.format(_totalIncome());
    final confirmAmountText = _loadingParams
        ? ''
        : _formatConvertedCurrency(
            currency,
            _totalIncome(),
            trimTrailingZeros: true,
          );

    final confirmed = await Get.to<bool>(
      () => InventoryUpShopConfirmPage(
        totalCount: _totalCount(),
        totalPriceText: currency.format(_totalPrice()),
        handlingFeeText: _loadingParams ? '--' : currency.format(_totalFee()),
        expectedIncomeText: expectedIncomeText,
        confirmAmountText: confirmAmountText,
        rewardPointsText:
            '${_totalRewardPoints()} ${'app.user.integral.unit'.tr}',
        warningLines: warningLines,
      ),
    );
    if (confirmed != true) {
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final steamStatus = await _steamApi.steamOnlineState();
      if (steamStatus.datas != true) {
        await Get.dialog<void>(
          AlertDialog(
            title: Text('app.system.tips.title'.tr),
            content: Text('app.steam.session.expired'.tr),
            actions: [
              TextButton(
                onPressed: () => Get.back(),
                child: Text('app.common.cancel'.tr),
              ),
              TextButton(
                onPressed: () {
                  Get.back();
                  Get.toNamed(Routers.STEAM_SESSION);
                },
                child: Text('app.common.confirm'.tr),
              ),
            ],
          ),
        );
        return;
      }

      final submitRes = await _inventoryController.submitUpShopItems(payload);
      final submitCode = submitRes.code;
      final dynamicData = submitRes.datas;
      final dataText = dynamicData?.toString().trim();
      final submitText = (dataText?.isNotEmpty ?? false)
          ? dataText!
          : (submitRes.message.trim().isNotEmpty
                ? submitRes.message
                : 'app.trade.filter.failed'.tr);

      if (submitCode == 0 || submitCode == 200) {
        if (!mounted) {
          return;
        }
        Navigator.of(context).pop(true);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          AppSnackbar.success('app.inventory.message.upshop_success'.tr);
        });
        return;
      }

      AppSnackbar.error(submitText);
    } catch (_) {
      AppSnackbar.error('app.trade.filter.failed'.tr);
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  String _buildItemSubtitle(
    TagInfo? exterior,
    TagInfo? quality,
    TagInfo? rarity,
  ) {
    final parts = <String>[
      if (exterior?.hasLabel == true) exterior!.label!,
      if (quality?.hasLabel == true) quality!.label!,
      if (rarity?.hasLabel == true) rarity!.label!,
    ];
    return parts.join(' | ').toUpperCase();
  }

  List<double> _schemaPriceCandidates(ShopSchemaInfo? schema) {
    if (schema == null) {
      return const [];
    }

    final raw = schema.raw;
    final values = <double>[
      _parsePriceValue(raw['sell_min'] ?? raw['sellMin']),
      _parsePriceValue(raw['buff_min_price'] ?? raw['buffMinPrice']),
      _parsePriceValue(raw['reference_price'] ?? raw['referencePrice']),
      _parsePriceValue(raw['market_price'] ?? raw['marketPrice']),
    ];

    final unique = <double>[];
    for (final value in values) {
      if (value <= 0) {
        continue;
      }
      final normalized = _normalizePrice(value);
      if (normalized <= 0) {
        continue;
      }
      final exists = unique.any((item) => (item - normalized).abs() < 0.0001);
      if (!exists) {
        unique.add(normalized);
      }
    }

    unique.sort();
    return unique;
  }

  double _suggestedMinPrice(ShopSchemaInfo? schema) {
    final candidates = _schemaPriceCandidates(schema);
    return candidates.isEmpty ? 0 : candidates.first;
  }

  double _suggestedAveragePrice(ShopSchemaInfo? schema) {
    if (schema == null) {
      return 0;
    }

    final raw = schema.raw;
    final referencePrice = _normalizePrice(
      _parsePriceValue(raw['reference_price'] ?? raw['referencePrice']),
    );
    if (referencePrice > 0) {
      return referencePrice;
    }

    final marketPrice = _normalizePrice(
      _parsePriceValue(raw['market_price'] ?? raw['marketPrice']),
    );
    if (marketPrice > 0) {
      return marketPrice;
    }

    final candidates = _schemaPriceCandidates(schema);
    if (candidates.isEmpty) {
      return 0;
    }
    if (candidates.length == 1) {
      return candidates.first;
    }

    return _normalizePrice((candidates.first + candidates.last) / 2);
  }

  double _suggestedMaxPrice(ShopSchemaInfo? schema) {
    final candidates = _schemaPriceCandidates(schema);
    return candidates.isEmpty ? 0 : candidates.last;
  }

  void _applySuggestedPrice(List<int> ids, int leadId, double value) {
    final normalized = _normalizePrice(value);
    if (normalized <= 0) {
      return;
    }
    final text = _plainNumberText(normalized);
    for (final id in ids) {
      _prices[id] = normalized;
      final controller = _controllers[id];
      if (controller != null && controller.text != text) {
        controller.value = TextEditingValue(
          text: text,
          selection: TextSelection.fromPosition(
            TextPosition(offset: text.length),
          ),
        );
      }
    }
    _normalizeInputOnBlurForIds(ids, sourceId: leadId);
  }

  String _plainNumberText(double value, {bool trimTrailingZeros = true}) {
    if (!value.isFinite) {
      return '--';
    }
    var text = value.toStringAsFixed(2);
    if (trimTrailingZeros) {
      text = text.replaceFirst(RegExp(r'\.00$'), '');
      text = text.replaceFirst(RegExp(r'(\.\d)0$'), r'$1');
    }
    return text;
  }

  String _formatConvertedCurrency(
    CurrencyController currency,
    double usdAmount, {
    bool trimTrailingZeros = false,
  }) {
    if (!usdAmount.isFinite || usdAmount <= 0) {
      return '${currency.symbol}0';
    }

    final converted = usdAmount * currency.currentRate;
    const noDecimal = {'JPY', 'KRW', 'VND', 'IDR'};
    final fractionDigits = noDecimal.contains(currency.code) ? 0 : 2;
    final fixed = converted.toStringAsFixed(fractionDigits);
    final parts = fixed.split('.');
    final whole = parts.first;
    final buffer = StringBuffer();
    for (var index = 0; index < whole.length; index++) {
      final reverseIndex = whole.length - index;
      buffer.write(whole[index]);
      if (reverseIndex > 1 && reverseIndex % 3 == 1) {
        buffer.write(',');
      }
    }

    var number = buffer.toString();
    if (parts.length == 2) {
      number = '$number.${parts[1]}';
    }
    if (trimTrailingZeros) {
      number = number.replaceFirst(RegExp(r'\.00$'), '');
      number = number.replaceFirst(RegExp(r'(\.\d)0$'), r'$1');
    }
    return '${currency.symbol}$number';
  }

  String _titleText() {
    return 'app.inventory.upshop.text'.tr;
  }

  String _confirmText() {
    return '${'app.common.confirm'.tr} (${_items.length})';
  }

  String _pricingPresetLabel(_PricingPreset preset) {
    final language = Get.locale?.languageCode.toLowerCase();
    switch (preset) {
      case _PricingPreset.min:
        if (language == 'zh' || language == 'ja') {
          return '最低';
        }
        if (language == 'ko') {
          return '최저';
        }
        return 'Min';
      case _PricingPreset.average:
        if (language == 'zh' || language == 'ja') {
          return '参考';
        }
        if (language == 'ko') {
          return '참고';
        }
        if (language == 'fr') {
          return 'Moy';
        }
        return 'Avg';
      case _PricingPreset.max:
        if (language == 'zh' || language == 'ja') {
          return '最高';
        }
        if (language == 'ko') {
          return '최고';
        }
        return 'Max';
    }
  }

  Widget _buildTopActionButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    bool active = false,
  }) {
    const brandColor = Color(0xFF1E3A8A);
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Ink(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active ? brandColor : Colors.transparent,
              border: active
                  ? null
                  : Border.all(color: const Color.fromRGBO(226, 232, 240, 0.9)),
            ),
            child: Icon(
              icon,
              size: 18,
              color: active ? Colors.white : brandColor,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopNavigation(BuildContext context) {
    return SettingsStyleTopNavigation(
      title: _titleText(),
      actions: [
        _buildTopActionButton(
          icon: Icons.merge_type_rounded,
          tooltip: 'app.inventory.upshop.combining'.tr,
          onTap: () => _setMergeSameItems(!_mergeSameItems),
          active: _mergeSameItems,
        ),
        const SizedBox(width: 8),
        _buildTopActionButton(
          icon: Icons.auto_awesome_rounded,
          tooltip: 'app.inventory.pricing'.tr,
          onTap: _applyReferencePrice,
        ),
      ],
    );
  }

  Future<void> _showImagePreview({
    required String title,
    required Widget preview,
  }) async {
    final previewWidth = MediaQuery.of(context).size.width - 64;
    final maxPreviewHeight = MediaQuery.of(context).size.height * 0.62;
    final previewHeight = (previewWidth * 0.62)
        .clamp(180.0, maxPreviewHeight)
        .toDouble();
    await Get.dialog<void>(
      Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.16),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Get.back(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.68,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.35),
                    child: InteractiveViewer(
                      minScale: 1,
                      maxScale: 4,
                      child: SizedBox(
                        width: previewWidth,
                        height: previewHeight,
                        child: preview,
                      ),
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

  Widget _buildStickerPreviewRow(List<GameItemSticker> stickers) {
    if (stickers.isEmpty) {
      return const SizedBox.shrink();
    }

    final previewItems = stickers.take(4).toList(growable: false);
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final sticker in previewItems)
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: const Color(0xFFECEEF0),
              borderRadius: BorderRadius.circular(4),
            ),
            padding: const EdgeInsets.all(2),
            child: Image.network(
              sticker.imageUrl,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.image_not_supported_outlined,
                size: 14,
                color: Color(0xFF94A3B8),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildWearBar(double wearValue) {
    final clamped = wearValue.clamp(0.0, 1.0).toDouble();
    return SizedBox(
      height: 12,
      child: LayoutBuilder(
        builder: (context, constraints) {
          const knobWidth = 5.0;
          final maxLeft = (constraints.maxWidth - knobWidth).clamp(
            0.0,
            constraints.maxWidth,
          );
          final knobLeft = (maxLeft * clamped).clamp(0.0, maxLeft);
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                top: 4,
                left: 0,
                right: 0,
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF10B981),
                        Color(0xFFEAB308),
                        Color(0xFFEF4444),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: knobLeft,
                top: 0,
                child: Container(
                  width: knobWidth,
                  height: 12,
                  decoration: BoxDecoration(
                    color: const Color(0xFF191C1E),
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: const [
                      BoxShadow(
                        color: Color.fromRGBO(15, 23, 42, 0.14),
                        blurRadius: 4,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPresetChip({
    required String label,
    required double value,
    required VoidCallback? onTap,
  }) {
    final enabled = value > 0 && onTap != null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(4),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: enabled
                ? const Color(0xFFE6E8EA)
                : const Color(0xFFE6E8EA).withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            label,
            maxLines: 1,
            softWrap: false,
            style: TextStyle(
              color: enabled
                  ? const Color(0xFF191C1E)
                  : const Color(0xFF94A3B8),
              fontSize: 11,
              fontWeight: FontWeight.w500,
              height: 1.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildItemCard(
    BuildContext context,
    CurrencyController currency,
    _InventoryMergeGroup group,
  ) {
    final item = group.items.first;
    final ids = _groupIds(group);
    if (ids.isEmpty) {
      return const SizedBox.shrink();
    }
    final leadId = ids.first;
    final controller = _controllers[leadId]!;
    final schema = _lookupSchema(item);
    final tags = schema?.raw['tags'];
    final rarity = TagInfo.fromRaw(tags is Map ? tags['rarity'] : null);
    final quality = TagInfo.fromRaw(tags is Map ? tags['quality'] : null);
    final exterior = TagInfo.fromRaw(tags is Map ? tags['exterior'] : null);
    final asset = _resolveAsset(item);
    final stickers = parseStickerList(
      asset?['stickers'] ?? item.raw['stickers'],
      schemaMap: _schemas,
    );
    final gems = parseGemList(
      asset?['gemList'] ??
          asset?['gems'] ??
          item.raw['gemList'] ??
          item.raw['gems'],
    );
    final wearValue = _extractWearValue(item, asset);
    final wearText = _extractWearText(item, asset);
    final paintSeed =
        item.paintSeed ?? _extractText(asset, ['paint_seed', 'paintSeed']);
    final phase = item.phase ?? _extractText(asset, ['phase']);
    final percentage = _extractText(asset, ['percentage']);
    final imageUrl = item.imageUrl ?? schema?.imageUrl ?? '';
    final title =
        item.marketName ?? schema?.marketName ?? item.marketHashName ?? '-';
    final subtitle = _buildItemSubtitle(exterior, quality, rarity);
    final itemCount = _groupTotalCount(group);
    final showWarning = _groupHasWarning(group);
    final minPrice = _suggestedMinPrice(schema);
    final averagePrice = _suggestedAveragePrice(schema);
    final maxPrice = _suggestedMaxPrice(schema);
    final suggestionText = minPrice > 0 && maxPrice > 0
        ? minPrice == maxPrice
              ? _formatConvertedCurrency(
                  currency,
                  minPrice,
                  trimTrailingZeros: true,
                )
              : '${_formatConvertedCurrency(currency, minPrice, trimTrailingZeros: true)} - '
                    '${_formatConvertedCurrency(currency, maxPrice, trimTrailingZeros: true)}'
        : '--';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.zero,
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(15, 23, 42, 0.05),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: imageUrl.isEmpty
                      ? null
                      : () => _showImagePreview(
                          title: title,
                          preview: GameItemImage(
                            imageUrl: imageUrl,
                            appId: item.appId,
                            rarity: rarity,
                            quality: quality,
                            exterior: exterior,
                            paintSeed: paintSeed,
                            phase: phase,
                            percentage: percentage,
                            paintWearText: wearText,
                            count: itemCount,
                            alwaysShowCount: _mergeSameItems,
                            stickers: stickers,
                            gems: gems,
                          ),
                        ),
                  child: SizedBox(
                    width: 80,
                    height: 80,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: GameItemImage(
                        imageUrl: imageUrl,
                        appId: item.appId,
                        rarity: rarity,
                        quality: quality,
                        exterior: exterior,
                        count: itemCount,
                        alwaysShowCount: _mergeSameItems,
                        showTopBadges: false,
                        stickers: const [],
                        gems: const [],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 3, bottom: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFF191C1E),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (subtitle.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF757684),
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              height: 1.5,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                        if (stickers.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          _buildStickerPreviewRow(stickers),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (wearValue != null && wearText != null) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'app.market.csgo.abradability'.tr.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF757684),
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        height: 1.5,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    wearText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF444653),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              _buildWearBar(wearValue),
              const SizedBox(height: 12),
            ],
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFE6E8EA),
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Text(
                    currency.symbol,
                    style: const TextStyle(
                      color: Color(0xFF444653),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      style: const TextStyle(
                        color: Color(0xFF00288E),
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        height: 1.4,
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        hintText: 'app.inventory.selling_placeholder'.tr,
                        hintStyle: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          height: 1.3,
                        ),
                        contentPadding: EdgeInsets.zero,
                      ),
                      onChanged: (value) => _handlePriceChangedForIds(
                        ids,
                        value,
                        sourceId: leadId,
                      ),
                      onEditingComplete: () =>
                          _normalizeInputOnBlurForIds(ids, sourceId: leadId),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${'app.inventory.pricing_reference'.tr}:',
                        style: const TextStyle(
                          color: Color(0xFF757684),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        suggestionText,
                        softWrap: true,
                        style: const TextStyle(
                          color: Color(0xFF444653),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildPresetChip(
                      label: _pricingPresetLabel(_PricingPreset.min),
                      value: minPrice,
                      onTap: minPrice > 0
                          ? () => _applySuggestedPrice(ids, leadId, minPrice)
                          : null,
                    ),
                    const SizedBox(width: 4),
                    _buildPresetChip(
                      label: _pricingPresetLabel(_PricingPreset.average),
                      value: averagePrice,
                      onTap: averagePrice > 0
                          ? () =>
                                _applySuggestedPrice(ids, leadId, averagePrice)
                          : null,
                    ),
                    const SizedBox(width: 4),
                    _buildPresetChip(
                      label: _pricingPresetLabel(_PricingPreset.max),
                      value: maxPrice,
                      onTap: maxPrice > 0
                          ? () => _applySuggestedPrice(ids, leadId, maxPrice)
                          : null,
                    ),
                  ],
                ),
              ],
            ),
            if (showWarning) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1F2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      size: 16,
                      color: Color(0xFFDC2626),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'app.inventory.pricing_abnormal'.tr,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFFDC2626),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    final currency = Get.find<CurrencyController>();
    final incomeText = _loadingParams
        ? '--'
        : _formatConvertedCurrency(currency, _totalIncome());

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: SafeArea(
          top: false,
          child: Container(
            decoration: BoxDecoration(
              color: const Color.fromRGBO(255, 255, 255, 0.84),
              border: Border(
                top: BorderSide(
                  color: const Color(0xFFE2E8F0).withValues(alpha: 0.35),
                ),
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color.fromRGBO(15, 23, 42, 0.05),
                  blurRadius: 20,
                  offset: Offset(0, -4),
                ),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'app.inventory.upshop.expected_income'.tr,
                        softWrap: true,
                        style: const TextStyle(
                          color: Color(0xFF444653),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        incomeText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF059669),
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                IgnorePointer(
                  ignoring: _isSubmitting,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 180),
                    opacity: _isSubmitting ? 0.72 : 1,
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: _submit,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints.tightFor(
                            width: 172,
                            height: 48,
                          ),
                          child: Ink(
                            decoration: const BoxDecoration(
                              borderRadius: BorderRadius.all(
                                Radius.circular(12),
                              ),
                              gradient: LinearGradient(
                                colors: [Color(0xFF00288E), Color(0xFF0058BE)],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Color.fromRGBO(0, 40, 142, 0.2),
                                  blurRadius: 16,
                                  offset: Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 12,
                                ),
                                child: _isSubmitting
                                    ? Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                    Colors.white,
                                                  ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Flexible(
                                            child: Text(
                                              _confirmText(),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              softWrap: false,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 16,
                                                fontWeight: FontWeight.w700,
                                                height: 1.4,
                                              ),
                                            ),
                                          ),
                                        ],
                                      )
                                    : Text(
                                        _confirmText(),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        softWrap: false,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          height: 1.4,
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currency = Get.find<CurrencyController>();
    final visibleGroups = _visibleGroups();
    final topInset = MediaQuery.of(context).padding.top;
    final headerOffset = topInset + 76;
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FB),
      body: Stack(
        children: [
          Positioned.fill(
            child: ListView.separated(
              padding: EdgeInsets.fromLTRB(16, headerOffset, 16, 24),
              itemCount: visibleGroups.length,
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final group = visibleGroups[index];
                return KeyedSubtree(
                  key: ValueKey(group.key),
                  child: _buildItemCard(context, currency, group),
                );
              },
            ),
          ),
          _buildTopNavigation(context),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(context),
    );
  }
}
