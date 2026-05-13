import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:tronskins_app/common/widgets/settings_style_app_bar.dart';
import 'package:get/get.dart';
import 'package:tronskins_app/api/inventory.dart';
import 'package:tronskins_app/api/model/shop/shop_models.dart';
import 'package:tronskins_app/api/shop_product.dart';
import 'package:tronskins_app/api/steam.dart';
import 'package:tronskins_app/common/hooks/currency/CurrencyController.dart';
import 'package:tronskins_app/common/storage/user_storage.dart';
import 'package:tronskins_app/common/utils/app_snackbar.dart';
import 'package:tronskins_app/common/widgets/figma_confirmation_dialog.dart';
import 'package:tronskins_app/common/widgets/steam_style_confirm_dialog.dart';
import 'package:tronskins_app/components/game_item/game_item_image.dart';
import 'package:tronskins_app/components/game_item/game_item_models.dart';
import 'package:tronskins_app/components/game_item/game_item_utils.dart';
import 'package:tronskins_app/components/layout/list_end_tip.dart';
import 'package:tronskins_app/pages/shop/buying_supply_matcher.dart';
import 'package:tronskins_app/routes/app_routes.dart';

class BuyingSupplyPage extends StatefulWidget {
  const BuyingSupplyPage({super.key});

  @override
  State<BuyingSupplyPage> createState() => _BuyingSupplyPageState();
}

class _BuyingSupplyPageState extends State<BuyingSupplyPage> {
  static const int _inventoryPageSize = 50;

  final ApiInventoryServer _inventoryApi = ApiInventoryServer();
  final ApiShopProductServer _shopApi = ApiShopProductServer();
  final ApiSteamServer _steamApi = ApiSteamServer();

  late final BuyRequestItem _request;
  ShopSchemaInfo? _schema;

  final List<InventoryItem> _items = [];
  final Map<String, ShopSchemaInfo> _schemas = {};
  final Set<int> _selectedIds = <int>{};
  final ScrollController _scrollController = ScrollController();

  int _page = 1;
  bool _hasMore = true;
  bool _isLoading = false;
  bool _isRefreshing = false;
  bool _hasLoadedOnce = false;
  bool _isSubmitting = false;
  double _feeRate = 0;
  bool _loadingFee = true;

  @override
  void initState() {
    super.initState();
    final args = Get.arguments as Map<String, dynamic>? ?? {};
    _request = _parseRequest(args['item']);
    _schema = _parseSchema(args['schema']);
    _scrollController.addListener(_handleScroll);
    _loadFeeRate();
    _refresh();
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  BuyRequestItem _parseRequest(dynamic raw) {
    if (raw is BuyRequestItem) {
      return raw;
    }
    if (raw is Map) {
      return BuyRequestItem.fromJson(Map<String, dynamic>.from(raw));
    }
    return const BuyRequestItem(raw: {});
  }

  ShopSchemaInfo? _parseSchema(dynamic raw) {
    if (raw is ShopSchemaInfo) {
      return raw;
    }
    if (raw is Map) {
      return ShopSchemaInfo.fromJson(Map<String, dynamic>.from(raw));
    }
    return null;
  }

  int get _maxNeed {
    final need = _request.need ?? _request.nums ?? 0;
    return need < 0 ? 0 : need;
  }

  void _handleScroll() {
    if (_scrollController.position.pixels >
        _scrollController.position.maxScrollExtent - 200) {
      _loadInventory();
    }
  }

  Future<InventoryResponse?> _fetchInventoryPage(int page) async {
    final appId = _request.appId ?? 730;
    final schemaId = _request.schemaId;
    if (schemaId == null) {
      return null;
    }
    final res = await _inventoryApi.inventoryList(
      appId: appId,
      page: page,
      pageSize: _inventoryPageSize,
      schemaId: schemaId,
      canSupply: true,
    );
    return res.datas;
  }

  bool _hasNextInventoryPage(InventoryResponse data, int currentPage) {
    if (data.items.isEmpty) {
      return false;
    }
    final total = data.total ?? data.pager?.total;
    final pageSize = data.pager?.pageSize ?? _inventoryPageSize;
    if (total != null && total > 0) {
      return currentPage * pageSize < total;
    }
    return data.items.length >= pageSize;
  }

  Future<_SupplyInventoryBatch> _fetchMatchingInventoryBatch(
    int startPage,
  ) async {
    var page = startPage;
    var hasMore = false;
    final matchedItems = <InventoryItem>[];
    final schemas = <String, ShopSchemaInfo>{};

    while (true) {
      final data = await _fetchInventoryPage(page);
      if (data == null) {
        return _SupplyInventoryBatch(
          items: matchedItems,
          schemas: schemas,
          nextPage: page,
          hasMore: false,
        );
      }

      schemas.addAll(data.schemas);
      matchedItems.addAll(filterSupplyInventoryItems(_request, data.items));
      hasMore = _hasNextInventoryPage(data, page);
      final nextPage = page + 1;
      if (matchedItems.isNotEmpty || !hasMore) {
        return _SupplyInventoryBatch(
          items: matchedItems,
          schemas: schemas,
          nextPage: nextPage,
          hasMore: hasMore,
        );
      }
      page = nextPage;
    }
  }

  Future<void> _refresh() async {
    if (_isRefreshing || _isLoading) {
      return;
    }
    final showInitialSkeleton = _items.isEmpty;
    setState(() {
      _isRefreshing = true;
      if (showInitialSkeleton) {
        _isLoading = true;
      }
    });
    try {
      final batch = await _fetchMatchingInventoryBatch(1);
      if (!mounted) {
        return;
      }
      setState(() {
        _items
          ..clear()
          ..addAll(batch.items);
        _schemas.addAll(batch.schemas);
        _selectedIds.clear();
        _hasMore = batch.hasMore;
        _page = batch.nextPage;
        _hasLoadedOnce = true;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
          _isLoading = false;
          _hasLoadedOnce = true;
        });
      }
    }
  }

  Future<void> _loadInventory() async {
    if (_isLoading || _isRefreshing || !_hasMore) {
      return;
    }
    if (_request.schemaId == null) {
      setState(() {
        _hasMore = false;
        _hasLoadedOnce = true;
      });
      return;
    }
    setState(() => _isLoading = true);
    try {
      final batch = await _fetchMatchingInventoryBatch(_page);
      if (!mounted) {
        return;
      }
      setState(() {
        _items.addAll(batch.items);
        _hasMore = batch.hasMore;
        _page = batch.nextPage;
        _schemas.addAll(batch.schemas);
        _hasLoadedOnce = true;
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadFeeRate() async {
    try {
      final res = await _shopApi.getSysParams();
      if (res.datas is Map<String, dynamic>) {
        final fee = res.datas?['fee'];
        if (fee is num) {
          _feeRate = fee.toDouble();
        } else {
          _feeRate = double.tryParse(fee?.toString() ?? '') ?? 0;
        }
      }
    } finally {
      if (mounted) {
        setState(() => _loadingFee = false);
      }
    }
  }

  bool _isSelectable(InventoryItem item) {
    final isCooling =
        (item.coolingDown ?? false) || (item.cooldown?.isNotEmpty == true);
    final isTradable = item.tradable ?? true;
    final inSupply = item.status == 2;
    return isTradable &&
        !isCooling &&
        !inSupply &&
        matchesBuyRequestSupplyConstraints(_request, item);
  }

  void _toggleSelection(InventoryItem item) {
    final id = item.id;
    if (id == null) {
      return;
    }
    final isCooling =
        (item.coolingDown ?? false) || (item.cooldown?.isNotEmpty == true);
    final isTradable = item.tradable ?? true;
    if (isCooling) {
      AppSnackbar.info('app.market.product.cooling'.tr);
      return;
    }
    if (!isTradable) {
      AppSnackbar.info('app.inventory.message.non_tradable'.tr);
      return;
    }
    if (item.status == 2) {
      AppSnackbar.info('app.inventory.in_supply'.tr);
      return;
    }
    if (!matchesBuyRequestSupplyConstraints(_request, item)) {
      AppSnackbar.info('app.trade.filter.failed'.tr);
      return;
    }
    if (!_selectedIds.contains(id) && _maxNeed > 0) {
      if (_selectedIds.length >= _maxNeed) {
        AppSnackbar.info('app.trade.supply.message.more_than_needed'.tr);
        return;
      }
    }
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _toggleSelectAll() {
    final available = _items.where(_isSelectable).toList();
    final limit = _maxNeed > 0 ? _maxNeed : available.length;
    if (limit <= 0) {
      return;
    }
    setState(() {
      if (_selectedIds.length >= limit) {
        _selectedIds.clear();
      } else {
        _selectedIds
          ..clear()
          ..addAll(
            available
                .where((item) => item.id != null)
                .map((item) => item.id!)
                .take(limit),
          );
      }
    });
  }

  double _totalAmount() {
    final price = _request.price ?? 0;
    return price * _selectedIds.length;
  }

  double _feeAmount() {
    final fee = _totalAmount() * _feeRate;
    return (fee * 100).floor() / 100;
  }

  double _incomeAmount() {
    final income = _totalAmount() - _feeAmount();
    return (income * 100).round() / 100;
  }

  int _rewardPoints() {
    final total = _totalAmount();
    if (!total.isFinite || total <= 0) {
      return 0;
    }
    return total.floor();
  }

  Future<void> _showConfirmDialog() async {
    if (_selectedIds.isEmpty) {
      AppSnackbar.error('app.trade.supply.message.not_selected'.tr);
      return;
    }
    if (_maxNeed > 0 && _selectedIds.length > _maxNeed) {
      AppSnackbar.info('app.trade.supply.message.more_than_needed'.tr);
      return;
    }
    final selectedItems = _items.where(
      (item) => item.id != null && _selectedIds.contains(item.id),
    );
    if (selectedItems.length != _selectedIds.length ||
        !selectedItems.every((item) => _isSelectable(item))) {
      _selectedIds.removeWhere(
        (id) => !_items.any((item) => item.id == id && _isSelectable(item)),
      );
      AppSnackbar.info('app.trade.filter.failed'.tr);
      setState(() {});
      return;
    }
    final currency = Get.find<CurrencyController>();
    final total = _totalAmount();
    final fee = _feeAmount();
    final income = _incomeAmount();
    final points = _rewardPoints();
    final confirmed = await showSteamStyleAmountConfirmDialog(
      context,
      title: 'app.trade.supply.text'.tr,
      amount: currency.format(income),
      amountLabel: 'app.trade.supply.actual_income'.tr,
      summaryItems: [
        SteamStyleConfirmSummaryItem(
          label: 'app.inventory.count'.tr,
          value: '${_selectedIds.length} ${'app.market.unit_qty'.tr}',
        ),
        SteamStyleConfirmSummaryItem(
          label: 'app.inventory.upshop.expected_income'.tr,
          value: currency.format(total),
        ),
        SteamStyleConfirmSummaryItem(
          label: 'app.inventory.upshop.handling_charge'.tr,
          value: currency.format(fee),
        ),
        SteamStyleConfirmSummaryItem(
          label: 'app.user.integral.award'.tr,
          value: '$points ${'app.user.integral.unit'.tr}',
          valueColor: _SupplyPalette.blue,
          emphasized: true,
        ),
      ],
      cancelText: 'app.common.cancel'.tr,
      confirmText: 'app.trade.supply.text'.tr,
      accentColor: _SupplyPalette.blue,
      requireAgreement: false,
    );
    if (confirmed == true) {
      await _submitSupply();
    }
  }

  Future<void> _submitSupply() async {
    if (_isSubmitting) {
      return;
    }
    final requestId = _request.id;
    final appId = _request.appId;
    final price = _request.price;
    if (requestId == null || appId == null || price == null) {
      AppSnackbar.error('app.trade.filter.failed'.tr);
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

      final res = await _shopApi.orderItemSupply(
        params: {
          'appid': appId,
          'id': requestId,
          'price': price,
          'ids': _selectedIds.toList(),
        },
      );
      final datas = res.datas;
      if (datas is String) {
        if (datas.contains('Steam issue')) {
          await Get.dialog<void>(
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
          final user = UserStorage.getUserInfo();
          final nickname = user?.config?.nickname ?? user?.nickname ?? '';
          await Get.dialog<void>(
            AlertDialog(
              title: Text('app.system.tips.title'.tr),
              content: Text('${'app.inventory.message.privacy'.tr}$nickname'),
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

      final dataText = datas?.toString().trim();
      if (res.success) {
        FocusManager.instance.primaryFocus?.unfocus();
        if (!mounted) {
          return;
        }
        final buyerId = _resolveSupplyDeliveryBuyerId(datas);
        Navigator.of(context).pop(true);
        _showSupplySuccessPrompt(buyerId);
        return;
      }

      final errorText = (dataText?.isNotEmpty ?? false)
          ? dataText!
          : (res.message.trim().isNotEmpty
                ? res.message
                : 'app.trade.filter.failed'.tr);
      AppSnackbar.error(errorText);
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _showSupplySuccessPrompt(String buyerId) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final dialogContext = Get.overlayContext ?? Get.context;
      if (dialogContext == null) {
        return;
      }
      final goDeliver = await showFigmaModal<bool>(
        context: dialogContext,
        child: FigmaConfirmationDialog(
          icon: Icons.local_shipping_outlined,
          iconColor: _SupplyPalette.blue,
          iconBackgroundColor: const Color.fromRGBO(37, 99, 235, 0.10),
          accentColor: _SupplyPalette.blue,
          title: 'app.system.tips.title'.tr,
          message: 'app.trade.supply.message.confirm'.tr,
          primaryLabel: 'app.common.yes'.tr,
          secondaryLabel: 'app.common.no'.tr,
          primaryFirst: false,
          onPrimary: () => popModalRoute(dialogContext, true),
          onSecondary: () => popModalRoute(dialogContext, false),
        ),
      );
      if (goDeliver != true) {
        return;
      }
      await Get.toNamed(
        Routers.SHOP_DELIVER_GOODS,
        arguments: {'buyerId': buyerId},
      );
    });
  }

  String _resolveSupplyDeliveryBuyerId(dynamic data) {
    final fromData = _extractSupplyBuyerId(data);
    if (fromData.isNotEmpty) {
      return fromData;
    }
    final fromRequest = _extractSupplyBuyerId(_request.raw);
    if (fromRequest.isNotEmpty) {
      return fromRequest;
    }
    return _request.userId?.toString() ?? '';
  }

  String _extractSupplyBuyerId(dynamic raw) {
    if (raw is List) {
      for (final item in raw) {
        final value = _extractSupplyBuyerId(item);
        if (value.isNotEmpty) {
          return value;
        }
      }
      return '';
    }
    if (raw is! Map) {
      return '';
    }
    const directKeys = [
      'buyer',
      'buyer_id',
      'buyerId',
      'userId',
      'user_id',
      'steamId',
      'steam_id',
    ];
    for (final key in directKeys) {
      final value = raw[key];
      if (value != null && value is! Map && value is! List) {
        final text = value.toString().trim();
        if (text.isNotEmpty) {
          return text;
        }
      }
    }
    const nestedKeys = ['order', 'send', 'record', 'user', 'buyerInfo'];
    for (final key in nestedKeys) {
      final value = _extractSupplyBuyerId(raw[key]);
      if (value.isNotEmpty) {
        return value;
      }
    }
    return '';
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

  @override
  Widget build(BuildContext context) {
    final currency = Get.find<CurrencyController>();
    final fallbackSchema =
        _schema ?? _schemas[_request.schemaId?.toString() ?? ''];
    final headerTitle =
        fallbackSchema?.marketName ??
        fallbackSchema?.marketHashName ??
        _request.raw['market_name']?.toString() ??
        '-';
    final imageUrl =
        fallbackSchema?.imageUrl ?? _request.raw['image_url']?.toString() ?? '';
    final maxNeed = _maxNeed;
    final isAllSelected = maxNeed > 0
        ? _selectedIds.length >= maxNeed
        : _items.isNotEmpty && _selectedIds.length >= _items.length;
    final showInitialSkeleton =
        _items.isEmpty && (_isLoading || !_hasLoadedOnce);
    final showSkeletonGrid = _isRefreshing || showInitialSkeleton;
    final showLoadMoreSkeleton =
        _isLoading && _items.isNotEmpty && !_isRefreshing;
    return Scaffold(
      backgroundColor: _SupplyPalette.galleryWall,
      appBar: SettingsStyleAppBar(title: Text('app.trade.supply.inventory'.tr)),
      body: ColoredBox(
        color: _SupplyPalette.galleryWall,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 672),
            child: Column(
              children: [
                _SupplySelectedItemCard(
                  title: headerTitle,
                  imageUrl: imageUrl,
                  appId: _request.appId ?? 730,
                  count: maxNeed,
                ),
                _SupplyInventoryHeader(
                  title: 'app.trade.supply.message.select_inventory'.tr,
                  selectedCount: _selectedIds.length,
                  targetCount: maxNeed > 0 ? maxNeed : _items.length,
                ),
                Expanded(
                  child: RefreshIndicator(
                    color: _SupplyPalette.blue,
                    backgroundColor: _SupplyPalette.assetCase,
                    strokeWidth: 2.4,
                    displacement: 28,
                    edgeOffset: 6,
                    onRefresh: _refresh,
                    child: CustomScrollView(
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        if (showSkeletonGrid)
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            sliver: SliverGrid.builder(
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    mainAxisSpacing: 16,
                                    crossAxisSpacing: 16,
                                    childAspectRatio: 0.58,
                                  ),
                              itemCount: 4,
                              itemBuilder: (context, index) =>
                                  const _SupplyInventorySkeletonCard(),
                            ),
                          )
                        else if (_items.isEmpty)
                          SliverFillRemaining(
                            child: Center(child: Text('app.common.no_data'.tr)),
                          )
                        else
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            sliver: SliverGrid.builder(
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    mainAxisSpacing: 16,
                                    crossAxisSpacing: 16,
                                    childAspectRatio: 0.58,
                                  ),
                              itemCount:
                                  _items.length +
                                  (showLoadMoreSkeleton ? 2 : 0),
                              itemBuilder: (context, index) {
                                if (index >= _items.length) {
                                  return const _SupplyInventorySkeletonCard();
                                }
                                final item = _items[index];
                                final schema = _lookupSchema(item);
                                final selected = _selectedIds.contains(
                                  item.id ?? -1,
                                );
                                final isCooling =
                                    (item.coolingDown ?? false) ||
                                    (item.cooldown?.isNotEmpty == true);
                                final isTradable = item.tradable ?? true;
                                final inSupply = item.status == 2;
                                final disabled =
                                    !isTradable || isCooling || inSupply;
                                final disabledLabel = !isTradable
                                    ? 'app.trade.non_tradable'.tr
                                    : isCooling
                                    ? 'app.market.product.cooling'.tr
                                    : inSupply
                                    ? 'app.inventory.in_supply'.tr
                                    : null;
                                return _SupplyInventoryItemCard(
                                  item: item,
                                  schema: schema,
                                  currency: currency,
                                  selected: selected,
                                  disabledLabel: disabled
                                      ? disabledLabel
                                      : null,
                                  onTap: () => _toggleSelection(item),
                                );
                              },
                            ),
                          ),
                        SliverToBoxAdapter(child: _buildLoadMoreFooter()),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: _SupplyBottomActionBar(
        isAllSelected: isAllSelected,
        totalAmount: _totalAmount(),
        currency: currency,
        isSubmitting: _isSubmitting,
        isActionDisabled: _isSubmitting || _loadingFee,
        onToggleSelectAll: _toggleSelectAll,
        onSupply: _showConfirmDialog,
        label: 'app.trade.supply.text'.tr,
      ),
    );
  }

  Widget _buildLoadMoreFooter() {
    if (_isLoading) {
      return const SizedBox(height: 16);
    }
    if (!_hasMore && _items.isNotEmpty) {
      return const ListEndTip(padding: EdgeInsets.fromLTRB(8, 6, 8, 12));
    }
    return const SizedBox(height: 4);
  }
}

class _SupplyInventoryBatch {
  const _SupplyInventoryBatch({
    required this.items,
    required this.schemas,
    required this.nextPage,
    required this.hasMore,
  });

  final List<InventoryItem> items;
  final Map<String, ShopSchemaInfo> schemas;
  final int nextPage;
  final bool hasMore;
}

class _SupplyPalette {
  static const galleryWall = Color(0xFFF8FAFC);
  static const softSurface = Color(0xFFF1F5F9);
  static const assetCase = Color(0xFFFFFFFF);
  static const selectedPanel = Color(0xFFFFFFFF);
  static const footerGlass = Color(0xE6FFFFFF);
  static const ink = Color(0xFF0F172A);
  static const body = Color(0xFF1E293B);
  static const muted = Color(0xFF64748B);
  static const blue = Color(0xFF2563EB);
  static const blueSoft = Color(0xFFEFF6FF);
  static const blueBorder = Color(0xFFDBEAFE);
  static const ghostBorder = Color(0xFFE2E8F0);
}

class _SupplySelectedItemCard extends StatelessWidget {
  const _SupplySelectedItemCard({
    required this.title,
    required this.imageUrl,
    required this.appId,
    required this.count,
  });

  final String title;
  final String imageUrl;
  final int appId;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _SupplyPalette.selectedPanel,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _SupplyPalette.ghostBorder),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0D000000),
              blurRadius: 2,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 64,
                height: 64,
                padding: const EdgeInsets.all(1),
                decoration: BoxDecoration(
                  color: _SupplyPalette.galleryWall,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _SupplyPalette.softSurface),
                ),
                child: Center(
                  child: SizedBox(
                    width: 52,
                    height: 52,
                    child: GameItemImage(
                      imageUrl: imageUrl,
                      appId: appId,
                      showTopBadges: false,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: _SupplyPalette.ink,
                        fontSize: 15,
                        height: 19 / 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'x${count > 0 ? count : 1}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: _SupplyPalette.blue,
                        fontSize: 11,
                        height: 15 / 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SupplyInventoryHeader extends StatelessWidget {
  const _SupplyInventoryHeader({
    required this.title,
    required this.selectedCount,
    required this.targetCount,
  });

  final String title;
  final int selectedCount;
  final int targetCount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Container(
        height: 42,
        decoration: const BoxDecoration(
          color: _SupplyPalette.assetCase,
          border: Border(
            top: BorderSide(color: _SupplyPalette.ghostBorder),
            bottom: BorderSide(color: _SupplyPalette.ghostBorder),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: _SupplyPalette.muted,
                  fontSize: 13,
                  height: 18 / 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 86,
              height: 22,
              decoration: BoxDecoration(
                color: _SupplyPalette.blueSoft,
                border: Border.all(color: _SupplyPalette.blueBorder),
              ),
              alignment: Alignment.center,
              child: Text(
                'app.trade.supply.selected_count'.trParams({
                  'count': selectedCount.toString(),
                  'total': targetCount.toString(),
                }),
                maxLines: 1,
                softWrap: false,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: _SupplyPalette.blue,
                  fontSize: 10,
                  height: 15 / 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SupplyInventoryItemCard extends StatelessWidget {
  const _SupplyInventoryItemCard({
    required this.item,
    required this.schema,
    required this.currency,
    required this.selected,
    required this.disabledLabel,
    required this.onTap,
  });

  final InventoryItem item;
  final ShopSchemaInfo? schema;
  final CurrencyController currency;
  final bool selected;
  final String? disabledLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final visual = _SupplyItemVisualData.from(item, schema);
    final price = _resolveSupplyCardPrice(item, schema);
    final borderColor = selected
        ? _SupplyPalette.blue.withValues(alpha: 0.55)
        : _SupplyPalette.ghostBorder;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 1,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        color: _SupplyPalette.assetCase,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor, width: selected ? 1.2 : 1),
            ),
            child: Padding(
              padding: const EdgeInsets.all(11),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Flexible(
                    fit: FlexFit.loose,
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: _SupplyPalette.galleryWall,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _SupplyPalette.softSurface),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: Opacity(
                                  opacity: disabledLabel == null ? 1 : 0.58,
                                  child: GameItemImage(
                                    imageUrl: visual.imageUrl,
                                    appId: item.appId,
                                    showTopBadges: false,
                                  ),
                                ),
                              ),
                              if (selected) const _SupplySelectedOverlay(),
                              if (disabledLabel != null)
                                Positioned(
                                  left: 8,
                                  right: 8,
                                  bottom: 8,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.86,
                                      ),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 3,
                                      ),
                                      child: Text(
                                        disabledLabel!,
                                        maxLines: 1,
                                        textAlign: TextAlign.center,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall
                                            ?.copyWith(
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.error,
                                              fontSize: 10,
                                              height: 1.2,
                                              fontWeight: FontWeight.w700,
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
                  ),
                  const SizedBox(height: 12),
                  Text(
                    visual.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: _SupplyPalette.body,
                      fontSize: 11,
                      height: 13.75 / 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${'app.trade.supply.float'.tr}: ${visual.paintWearText ?? '-'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: _SupplyPalette.muted,
                      fontSize: 10,
                      height: 15 / 10,
                      fontWeight: FontWeight.w400,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(height: 8),
                  _SupplyBlueProgressBar(paintWear: visual.paintWearValue),
                  const SizedBox(height: 8),
                  Obx(
                    () => Text(
                      currency.format(price),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: _SupplyPalette.ink,
                        fontSize: 14,
                        height: 20 / 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SupplyBlueProgressBar extends StatelessWidget {
  const _SupplyBlueProgressBar({required this.paintWear});

  final double? paintWear;

  @override
  Widget build(BuildContext context) {
    final fill = paintWear == null
        ? 1.0
        : (1 - paintWear! * 2).clamp(0.04, 1.0).toDouble();
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        height: 6,
        child: ColoredBox(
          color: _SupplyPalette.softSurface,
          child: Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: fill,
              heightFactor: 1,
              child: const ColoredBox(color: _SupplyPalette.blue),
            ),
          ),
        ),
      ),
    );
  }
}

class _SupplyInventorySkeletonCard extends StatelessWidget {
  const _SupplyInventorySkeletonCard();

  @override
  Widget build(BuildContext context) {
    return _SupplySkeletonShimmer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _SupplyPalette.assetCase,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _SupplyPalette.ghostBorder),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0D000000),
              blurRadius: 1,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(11),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: const [
              Flexible(
                fit: FlexFit.loose,
                child: AspectRatio(
                  aspectRatio: 1,
                  child: _SupplySkeletonBox(radius: 8),
                ),
              ),
              SizedBox(height: 12),
              _SupplySkeletonBox(height: 12, radius: 6),
              SizedBox(height: 6),
              FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: 0.72,
                child: _SupplySkeletonBox(height: 12, radius: 6),
              ),
              SizedBox(height: 10),
              FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: 0.78,
                child: _SupplySkeletonBox(height: 10, radius: 5),
              ),
              SizedBox(height: 8),
              _SupplySkeletonBox(height: 6, radius: 999),
              SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: _SupplySkeletonBox(width: 54, height: 16, radius: 8),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SupplySkeletonBox extends StatelessWidget {
  const _SupplySkeletonBox({this.width, this.height, required this.radius});

  final double? width;
  final double? height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFE8EEF5),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: SizedBox(width: width, height: height),
    );
  }
}

class _SupplySkeletonShimmer extends StatefulWidget {
  const _SupplySkeletonShimmer({required this.child});

  final Widget child;

  @override
  State<_SupplySkeletonShimmer> createState() => _SupplySkeletonShimmerState();
}

class _SupplySkeletonShimmerState extends State<_SupplySkeletonShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return LayoutBuilder(
            builder: (context, constraints) {
              final shimmerWidth = constraints.maxWidth * 0.62;
              final travel = constraints.maxWidth + shimmerWidth * 2;
              final left = -shimmerWidth + travel * _controller.value;
              return Stack(
                children: [
                  child!,
                  Positioned(
                    top: 0,
                    bottom: 0,
                    left: left,
                    width: shimmerWidth,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              Colors.white.withValues(alpha: 0),
                              Colors.white.withValues(alpha: 0.58),
                              Colors.white.withValues(alpha: 0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
        child: widget.child,
      ),
    );
  }
}

class _SupplySelectedOverlay extends StatelessWidget {
  const _SupplySelectedOverlay();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: ColoredBox(color: _SupplyPalette.blue.withValues(alpha: 0.12)),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(
              color: _SupplyPalette.blue,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_rounded,
              color: Colors.white,
              size: 17,
            ),
          ),
        ),
      ],
    );
  }
}

class _SupplyBottomActionBar extends StatelessWidget {
  const _SupplyBottomActionBar({
    required this.isAllSelected,
    required this.totalAmount,
    required this.currency,
    required this.isSubmitting,
    required this.isActionDisabled,
    required this.onToggleSelectAll,
    required this.onSupply,
    required this.label,
  });

  final bool isAllSelected;
  final double totalAmount;
  final CurrencyController currency;
  final bool isSubmitting;
  final bool isActionDisabled;
  final VoidCallback onToggleSelectAll;
  final VoidCallback onSupply;
  final String label;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final topPadding = 12.0;
    final bottomPadding = bottomInset > 0 ? bottomInset + 10 : 18.0;
    final barHeight = topPadding + 42.0 + bottomPadding;

    return SizedBox(
      height: barHeight,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: DecoratedBox(
            decoration: const BoxDecoration(
              color: _SupplyPalette.footerGlass,
              border: Border(
                top: BorderSide(color: _SupplyPalette.ghostBorder),
              ),
              boxShadow: [
                BoxShadow(
                  color: Color(0x12000000),
                  blurRadius: 22,
                  offset: Offset(0, -8),
                ),
              ],
            ),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 672),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    24,
                    topPadding,
                    24,
                    bottomPadding,
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 118,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'app.trade.supply.total_amount'.tr,
                              maxLines: 1,
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: _SupplyPalette.muted,
                                    fontSize: 9,
                                    height: 13 / 9,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1,
                                  ),
                            ),
                            Obx(
                              () => Text(
                                currency.format(totalAmount),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(
                                      color: _SupplyPalette.ink,
                                      fontSize: 22,
                                      height: 29 / 22,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: -0.6,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _SupplyAllSupplyButton(
                                  selected: isAllSelected,
                                  onTap: onToggleSelectAll,
                                ),
                                const SizedBox(width: 8),
                                _SupplySubmitButton(
                                  label: label,
                                  loading: isSubmitting,
                                  disabled: isActionDisabled,
                                  onTap: onSupply,
                                ),
                              ],
                            ),
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
      ),
    );
  }
}

class _SupplyAllSupplyButton extends StatelessWidget {
  const _SupplyAllSupplyButton({required this.selected, required this.onTap});

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: SizedBox(
          height: 40,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: 13.5,
                  height: 13.5,
                  decoration: BoxDecoration(
                    color: selected ? _SupplyPalette.blue : Colors.transparent,
                    borderRadius: BorderRadius.circular(1.5),
                    border: Border.all(
                      color: selected
                          ? _SupplyPalette.blue
                          : const Color(0xFF94A3B8),
                      width: 1.5,
                    ),
                  ),
                  child: selected
                      ? const Icon(
                          Icons.check_rounded,
                          size: 10,
                          color: Colors.white,
                        )
                      : null,
                ),
                const SizedBox(width: 6),
                Text(
                  'app.trade.supply.all_supply'.tr,
                  maxLines: 1,
                  softWrap: false,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: const Color(0xFF475569),
                    fontSize: 11,
                    height: 16.5 / 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.55,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SupplySubmitButton extends StatelessWidget {
  const _SupplySubmitButton({
    required this.label,
    required this.loading,
    required this.disabled,
    required this.onTap,
  });

  final String label;
  final bool loading;
  final bool disabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 160),
      opacity: disabled ? 0.58 : 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _SupplyPalette.blue,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(
              color: Color(0x332563EB),
              blurRadius: 15,
              offset: Offset(0, 10),
              spreadRadius: -3,
            ),
            BoxShadow(
              color: Color(0x332563EB),
              blurRadius: 6,
              offset: Offset(0, 4),
              spreadRadius: -4,
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: disabled ? null : onTap,
            child: SizedBox(
              width: 90,
              height: 40,
              child: Center(
                child: loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            label.toUpperCase(),
                            maxLines: 1,
                            softWrap: false,
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(
                                  color: Colors.white,
                                  fontSize: 12,
                                  height: 16 / 12,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.6,
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

class _SupplyItemVisualData {
  const _SupplyItemVisualData({
    required this.title,
    required this.imageUrl,
    required this.quality,
    required this.rarity,
    required this.exterior,
    required this.paintWearValue,
    required this.paintWearText,
    required this.paintSeed,
    required this.phase,
    required this.percentage,
    required this.stickers,
    required this.gems,
    required this.wearAccentColor,
    required this.showOnSaleBadge,
    required this.stickerBottomOffset,
    required this.onSaleBottomOffset,
  });

  final String title;
  final String imageUrl;
  final TagInfo? quality;
  final TagInfo? rarity;
  final TagInfo? exterior;
  final double? paintWearValue;
  final String? paintWearText;
  final String? paintSeed;
  final String? phase;
  final String? percentage;
  final List<GameItemSticker> stickers;
  final List<GameItemGem> gems;
  final Color? wearAccentColor;
  final bool showOnSaleBadge;
  final double stickerBottomOffset;
  final double onSaleBottomOffset;

  factory _SupplyItemVisualData.from(
    InventoryItem item,
    ShopSchemaInfo? schema,
  ) {
    final asset = _resolveSupplyAsset(item);
    final tags = schema?.raw['tags'];
    final quality = TagInfo.fromRaw(tags is Map ? tags['quality'] : null);
    final rarity = TagInfo.fromRaw(tags is Map ? tags['rarity'] : null);
    final exterior = TagInfo.fromRaw(tags is Map ? tags['exterior'] : null);
    final paintWearValue =
        item.paintWear ??
        _extractSupplyDouble(asset, ['paint_wear', 'paintWear']);
    final paintWearText =
        _extractSupplyText(asset, ['paint_wear', 'paintWear']) ??
        _extractSupplyText(item.raw, ['paint_wear', 'paintWear']) ??
        _formatSupplyWear(paintWearValue);
    final hasWear = paintWearText != null && paintWearText.isNotEmpty;

    return _SupplyItemVisualData(
      title:
          item.marketName ?? schema?.marketName ?? item.marketHashName ?? '-',
      imageUrl: item.imageUrl ?? schema?.imageUrl ?? '',
      quality: quality,
      rarity: rarity,
      exterior: exterior,
      paintWearValue: paintWearValue,
      paintWearText: paintWearText,
      paintSeed:
          item.paintSeed ??
          _extractSupplyText(asset, ['paint_seed', 'paintSeed']),
      phase: item.phase ?? _extractSupplyText(asset, ['phase']),
      percentage: _extractSupplyText(asset, ['percentage']),
      stickers: buildAccessoryPreviewStickers(
        stickers: parseFirstAccessoryStickerList([
          asset?['stickers'],
          asset?['stickerList'],
          asset?['sticker_list'],
          asset?['sticker'],
          item.raw['stickers'],
          item.raw['stickerList'],
          item.raw['sticker_list'],
          item.raw['sticker'],
        ]),
        keychains: parseFirstAccessoryStickerList([
          asset?['keychains'],
          asset?['keychain'],
          item.raw['keychains'],
          item.raw['keychain'],
        ]),
      ),
      gems: parseGemList(
        asset?['gemList'] ??
            asset?['gems'] ??
            item.raw['gemList'] ??
            item.raw['gems'],
      ),
      wearAccentColor: parseHexColor(exterior?.color),
      showOnSaleBadge: item.status == 1 || item.status == 2,
      stickerBottomOffset: hasWear ? 16 : 0,
      onSaleBottomOffset: hasWear ? 14 : 0,
    );
  }
}

Map<String, dynamic>? _resolveSupplyAsset(InventoryItem item) {
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

String? _extractSupplyText(dynamic raw, List<String> keys) {
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

double? _extractSupplyDouble(dynamic raw, List<String> keys) {
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

double _parseSupplyPrice(dynamic value) {
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

double _normalizeSupplyPrice(double value) {
  if (!value.isFinite || value <= 0) {
    return 0;
  }
  return double.parse(value.toStringAsFixed(2));
}

double _resolveSupplyCardPrice(InventoryItem item, ShopSchemaInfo? schema) {
  final itemPrice = _parseSupplyPrice(item.price);
  if (itemPrice > 0) {
    return _normalizeSupplyPrice(itemPrice);
  }
  final raw = schema?.raw;
  if (raw != null) {
    final schemaPrice = _parseSupplyPrice(
      raw['buff_min_price'] ?? raw['buffMinPrice'],
    );
    if (schemaPrice > 0) {
      return _normalizeSupplyPrice(schemaPrice);
    }
  }
  return 0;
}

String? _formatSupplyWear(double? wear) {
  if (wear == null) {
    return null;
  }
  return wear.toString();
}
