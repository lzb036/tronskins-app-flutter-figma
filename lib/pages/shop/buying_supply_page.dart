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
import 'package:tronskins_app/components/game_item/game_item_image.dart';
import 'package:tronskins_app/components/game_item/game_item_models.dart';
import 'package:tronskins_app/components/game_item/game_item_utils.dart';
import 'package:tronskins_app/components/game_item/wear_progress_bar.dart';
import 'package:tronskins_app/components/layout/list_end_tip.dart';
import 'package:tronskins_app/routes/app_routes.dart';

class BuyingSupplyPage extends StatefulWidget {
  const BuyingSupplyPage({super.key});

  @override
  State<BuyingSupplyPage> createState() => _BuyingSupplyPageState();
}

class _BuyingSupplyPageState extends State<BuyingSupplyPage> {
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

  Future<void> _refresh() async {
    _page = 1;
    _hasMore = true;
    _items.clear();
    _selectedIds.clear();
    await _loadInventory();
  }

  Future<void> _loadInventory() async {
    if (_isLoading || !_hasMore) {
      return;
    }
    final appId = _request.appId ?? 730;
    final schemaId = _request.schemaId;
    if (schemaId == null) {
      _hasMore = false;
      return;
    }
    setState(() => _isLoading = true);
    try {
      final res = await _inventoryApi.inventoryList(
        appId: appId,
        page: _page,
        pageSize: 50,
        schemaId: schemaId,
        canSupply: true,
      );
      final data = res.datas;
      if (data == null || data.items.isEmpty) {
        _hasMore = false;
      } else {
        _items.addAll(data.items);
        _page += 1;
      }
      _schemas.addAll(data?.schemas ?? const {});
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
    return isTradable && !isCooling && !inSupply;
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

  Future<void> _showConfirmDialog() async {
    if (_selectedIds.isEmpty) {
      AppSnackbar.error('app.trade.supply.message.not_selected'.tr);
      return;
    }
    if (_maxNeed > 0 && _selectedIds.length > _maxNeed) {
      AppSnackbar.info('app.trade.supply.message.more_than_needed'.tr);
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return _SupplyConfirmDialog(
          count: _selectedIds.length,
          total: _totalAmount(),
          fee: _feeAmount(),
          income: _incomeAmount(),
        );
      },
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
        Navigator.of(context).pop(true);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          AppSnackbar.success('app.trade.supply.message.success'.tr);
        });
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
    final price = _request.price ?? 0;
    final maxNeed = _maxNeed;
    final isAllSelected = maxNeed > 0
        ? _selectedIds.length >= maxNeed
        : _items.isNotEmpty && _selectedIds.length >= _items.length;
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
                  selectedCount: _selectedIds.length,
                  price: price,
                  currency: currency,
                ),
                _SupplyInventoryHeader(
                  title: 'app.trade.supply.message.select_inventory'.tr,
                  selectedCount: _selectedIds.length,
                  totalCount: _items.length,
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _refresh,
                    child: CustomScrollView(
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        if (_items.isEmpty && _isLoading)
                          const SliverFillRemaining(
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else if (_items.isEmpty)
                          SliverFillRemaining(
                            child: Center(child: Text('app.common.no_data'.tr)),
                          )
                        else
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
                            sliver: SliverGrid.builder(
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    mainAxisSpacing: 14,
                                    crossAxisSpacing: 14,
                                    childAspectRatio: 0.74,
                                  ),
                              itemCount: _items.length,
                              itemBuilder: (context, index) {
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
                                  price: item.price ?? price,
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
        selectedCount: _selectedIds.length,
        totalCount: _items.length,
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
      return const Padding(
        padding: EdgeInsets.fromLTRB(0, 4, 0, 12),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.2),
          ),
        ),
      );
    }
    if (!_hasMore && _items.isNotEmpty) {
      return const ListEndTip(padding: EdgeInsets.fromLTRB(8, 6, 8, 12));
    }
    return const SizedBox(height: 4);
  }
}

class _SupplyPalette {
  static const galleryWall = Color(0xFFF8FAFC);
  static const assetCase = Color(0xFFFFFFFF);
  static const selectedPanel = Color(0xFFEFF7F8);
  static const footerGlass = Color(0xF3F5FCFF);
  static const ink = Color(0xFF0F172A);
  static const body = Color(0xFF1E293B);
  static const teal = Color(0xFF007B8B);
  static const tealDark = Color(0xFF006B7C);
  static const pill = Color(0xFFCFEAF2);
  static const ghostBorder = Color(0x26C4C5D5);
}

class _SupplySelectedItemCard extends StatelessWidget {
  const _SupplySelectedItemCard({
    required this.title,
    required this.imageUrl,
    required this.appId,
    required this.count,
    required this.selectedCount,
    required this.price,
    required this.currency,
  });

  final String title;
  final String imageUrl;
  final int appId;
  final int count;
  final int selectedCount;
  final double price;
  final CurrencyController currency;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _SupplyPalette.selectedPanel,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _SupplyPalette.ghostBorder),
          boxShadow: const [
            BoxShadow(
              color: Color(0x12000000),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: SizedBox(
                  width: 122,
                  height: 72,
                  child: GameItemImage(
                    imageUrl: imageUrl,
                    appId: appId,
                    count: count > 0 ? count : null,
                    alwaysShowCount: count > 0,
                    showTopBadges: false,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.black,
                        fontSize: 17,
                        height: 1.35,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Obx(
                      () => Text(
                        currency.format(price),
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: _SupplyPalette.teal,
                          fontSize: 17,
                          height: 1.2,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: 10),
                _SupplyCountPill(text: '$selectedCount/$count'),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SupplyCountPill extends StatelessWidget {
  const _SupplyCountPill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 56),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: _SupplyPalette.pill,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: _SupplyPalette.ink,
          fontSize: 15,
          height: 1.1,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SupplyInventoryHeader extends StatelessWidget {
  const _SupplyInventoryHeader({
    required this.title,
    required this.selectedCount,
    required this.totalCount,
  });

  final String title;
  final int selectedCount;
  final int totalCount;

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: Colors.black,
      fontSize: 16,
      height: 1.25,
      fontWeight: FontWeight.w400,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 16, 22, 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textStyle,
            ),
          ),
          Text('$selectedCount/$totalCount', style: textStyle),
        ],
      ),
    );
  }
}

class _SupplyInventoryItemCard extends StatelessWidget {
  const _SupplyInventoryItemCard({
    required this.item,
    required this.schema,
    required this.price,
    required this.currency,
    required this.selected,
    required this.disabledLabel,
    required this.onTap,
  });

  final InventoryItem item;
  final ShopSchemaInfo? schema;
  final double price;
  final CurrencyController currency;
  final bool selected;
  final String? disabledLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final visual = _SupplyItemVisualData.from(item, schema);
    final borderColor = selected
        ? _SupplyPalette.teal.withValues(alpha: 0.45)
        : _SupplyPalette.ghostBorder;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: _SupplyPalette.assetCase,
        borderRadius: BorderRadius.circular(8),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: borderColor, width: selected ? 1.2 : 1),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final maxImageHeight = constraints.maxHeight * 0.64;
                final minImageHeight = maxImageHeight < 96
                    ? maxImageHeight
                    : 96.0;
                final imageHeight = (constraints.maxWidth * 0.78)
                    .clamp(minImageHeight, maxImageHeight)
                    .toDouble();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: imageHeight,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: Opacity(
                              opacity: disabledLabel == null ? 1 : 0.68,
                              child: GameItemImage(
                                imageUrl: visual.imageUrl,
                                appId: item.appId,
                                rarity: visual.rarity,
                                quality: visual.quality,
                                exterior: visual.exterior,
                                cooldown: item.cooldown,
                                paintSeed: visual.paintSeed,
                                phase: visual.phase,
                                percentage: visual.percentage,
                                paintWearText: visual.paintWearText,
                                count: item.count,
                                selected: false,
                                showOnSaleBadge: visual.showOnSaleBadge,
                                disabledLabel: disabledLabel,
                                stickers: visual.stickers,
                                gems: visual.gems,
                                stickerBottomOffset: visual.stickerBottomOffset,
                                onSaleBottomOffset: visual.onSaleBottomOffset,
                                avoidTopLeftBadgeOverlap: true,
                                compactTopLeftBadges: true,
                                topBadgeScale: 0.95,
                              ),
                            ),
                          ),
                          if (selected) const _SupplySelectedOverlay(),
                        ],
                      ),
                    ),
                    if (visual.paintWearValue != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 0, 4, 0),
                        child: WearProgressBar(
                          paintWear: visual.paintWearValue!,
                          height: 18,
                          accentColor: visual.wearAccentColor,
                        ),
                      )
                    else
                      const SizedBox(height: 10),
                    Expanded(
                      child: ColoredBox(
                        color: _SupplyPalette.galleryWall,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                visual.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodyLarge
                                    ?.copyWith(
                                      color: _SupplyPalette.body,
                                      fontSize: 16,
                                      height: 1.25,
                                      fontWeight: FontWeight.w500,
                                    ),
                              ),
                              const Spacer(),
                              Row(
                                children: [
                                  Expanded(
                                    child: Obx(
                                      () => Text(
                                        currency.format(price),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              color: _SupplyPalette.teal,
                                              fontSize: 18,
                                              height: 1.15,
                                              fontWeight: FontWeight.w800,
                                            ),
                                      ),
                                    ),
                                  ),
                                  if (item.tradable == false)
                                    Text(
                                      'app.trade.non_tradable'.tr,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.error,
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
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
          child: ColoredBox(color: _SupplyPalette.teal.withValues(alpha: 0.12)),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(
              color: _SupplyPalette.teal,
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
    required this.selectedCount,
    required this.totalCount,
    required this.isSubmitting,
    required this.isActionDisabled,
    required this.onToggleSelectAll,
    required this.onSupply,
    required this.label,
  });

  final bool isAllSelected;
  final int selectedCount;
  final int totalCount;
  final bool isSubmitting;
  final bool isActionDisabled;
  final VoidCallback onToggleSelectAll;
  final VoidCallback onSupply;
  final String label;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            color: _SupplyPalette.footerGlass,
            border: Border(top: BorderSide(color: _SupplyPalette.ghostBorder)),
            boxShadow: [
              BoxShadow(
                color: Color(0x12000000),
                blurRadius: 22,
                offset: Offset(0, -8),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 672),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(28, 20, 14, 20),
                  child: Row(
                    children: [
                      _SupplyCheckbox(
                        selected: isAllSelected,
                        onTap: onToggleSelectAll,
                      ),
                      const SizedBox(width: 18),
                      Text(
                        '$selectedCount/$totalCount',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.black,
                          fontSize: 15,
                          height: 1.2,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const Spacer(),
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
          ),
        ),
      ),
    );
  }
}

class _SupplyCheckbox extends StatelessWidget {
  const _SupplyCheckbox({required this.selected, required this.onTap});

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 30,
          height: 30,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 23,
              height: 23,
              decoration: BoxDecoration(
                color: selected ? _SupplyPalette.teal : Colors.transparent,
                borderRadius: BorderRadius.circular(3),
                border: Border.all(
                  color: selected
                      ? _SupplyPalette.teal
                      : const Color(0xFF455A64),
                  width: 2,
                ),
              ),
              child: selected
                  ? const Icon(
                      Icons.check_rounded,
                      size: 17,
                      color: Colors.white,
                    )
                  : null,
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
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_SupplyPalette.tealDark, _SupplyPalette.teal],
          ),
          borderRadius: BorderRadius.circular(26),
          boxShadow: const [
            BoxShadow(
              color: Color(0x26007B8B),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(26),
          child: InkWell(
            borderRadius: BorderRadius.circular(26),
            onTap: disabled ? null : onTap,
            child: SizedBox(
              width: 98,
              height: 50,
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
                            label,
                            maxLines: 1,
                            softWrap: false,
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(
                                  color: Colors.white,
                                  fontSize: 16,
                                  height: 1.1,
                                  fontWeight: FontWeight.w700,
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
      stickers: parseStickerList(asset?['stickers'] ?? item.raw['stickers']),
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

String? _formatSupplyWear(double? wear) {
  if (wear == null) {
    return null;
  }
  return wear.toString();
}

class _SupplyConfirmDialog extends StatelessWidget {
  const _SupplyConfirmDialog({
    required this.count,
    required this.total,
    required this.fee,
    required this.income,
  });

  final int count;
  final double total;
  final double fee;
  final double income;

  @override
  Widget build(BuildContext context) {
    final currency = Get.find<CurrencyController>();
    final points = (total * 100).floor() / 100;
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'app.trade.supply.text'.tr,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            _buildRow(
              context,
              label: 'app.inventory.count'.tr,
              value: '$count ${'app.market.unit_qty'.tr}',
            ),
            Obx(
              () => _buildRow(
                context,
                label: 'app.inventory.upshop.expected_income'.tr,
                value: currency.format(total),
              ),
            ),
            Obx(
              () => _buildRow(
                context,
                label: 'app.inventory.upshop.handling_charge'.tr,
                value: currency.format(fee),
              ),
            ),
            Obx(
              () => _buildRow(
                context,
                label: 'app.trade.supply.actual_income'.tr,
                value: currency.format(income),
                highlight: true,
              ),
            ),
            _buildRow(
              context,
              label: 'app.user.integral.award'.tr,
              value:
                  '${points.toStringAsFixed(2)} ${'app.user.integral.unit'.tr}',
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text('app.common.cancel'.tr),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: Text('app.trade.supply.text'.tr),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(
    BuildContext context, {
    required String label,
    required String value,
    bool highlight = false,
  }) {
    final style = Theme.of(context).textTheme.bodyMedium!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(
            value,
            style: style.copyWith(
              color: highlight
                  ? Theme.of(context).colorScheme.primary
                  : style.color,
              fontWeight: highlight ? FontWeight.w600 : style.fontWeight,
            ),
          ),
        ],
      ),
    );
  }
}
