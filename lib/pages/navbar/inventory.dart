import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tronskins_app/common/utils/app_snackbar.dart';
import 'package:tronskins_app/common/widgets/login_required_prompt.dart';
import 'package:tronskins_app/api/model/shop/shop_models.dart';
import 'package:tronskins_app/api/steam.dart';
import 'package:tronskins_app/common/hooks/currency/CurrencyController.dart';
import 'package:tronskins_app/common/widgets/figma_confirmation_dialog.dart';
import 'package:tronskins_app/components/game/game_switch_menu.dart';
import 'package:tronskins_app/common/widgets/back_to_top_overlay.dart';
import 'package:tronskins_app/components/game_item/inventory_showcase_card.dart';
import 'package:tronskins_app/components/filter/filter_models.dart';
import 'package:tronskins_app/components/filter/market_filter_sheet.dart';
import 'package:tronskins_app/components/layout/app_search_bar.dart';
import 'package:tronskins_app/components/layout/navbar/floating_selection_action_bar.dart';
import 'package:tronskins_app/components/layout/header_filter_button.dart';
import 'package:tronskins_app/components/layout/list_end_tip.dart';
import 'package:tronskins_app/components/market/market_showcase_card.dart';
import 'package:tronskins_app/controllers/inventory/inventory_controller.dart';
import 'package:tronskins_app/controllers/navbar/nav_controller.dart';
import 'package:tronskins_app/controllers/user/user_controller.dart';
import 'package:tronskins_app/routes/app_routes.dart';

enum _InventoryStateFilter { all, sellable, cooling }

class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key});

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage>
    with SingleTickerProviderStateMixin {
  static const int _gridColumns = 2;
  static const double _gridMainSpacing = 8;
  static const double _gridCrossSpacing = 8;
  static const double _gridAspectRatio = 0.92;
  static const EdgeInsets _gridPadding = EdgeInsets.fromLTRB(16, 4, 16, 16);
  static const int _loadMorePlaceholderCount = 2;
  final InventoryController controller = Get.isRegistered<InventoryController>()
      ? Get.find<InventoryController>()
      : Get.put(InventoryController());
  final UserController userController = Get.find<UserController>();
  final ApiSteamServer _steamApi = ApiSteamServer();
  late final PageController _inventoryStatePageController;
  late final TabController _inventoryTabController;
  final ScrollController _allInventoryScroll = ScrollController();
  final ScrollController _sellableInventoryScroll = ScrollController();
  final ScrollController _coolingInventoryScroll = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  Worker? _loginWorker;
  Worker? _tabWorker;
  bool _steamSessionDialogShowing = false;

  String _steamIdFromProfile() {
    final steamId = userController.user.value?.config?.steamId;
    if (steamId == null) {
      return '';
    }
    return steamId.trim();
  }

  Future<bool> _hasBoundSteam() async {
    if (_steamIdFromProfile().isNotEmpty) {
      return true;
    }
    await userController.fetchUserData(showLoading: false);
    return _steamIdFromProfile().isNotEmpty;
  }

  String get _steamUnboundDialogMessage {
    final language = (Get.locale?.languageCode ?? '').toLowerCase();
    final country = (Get.locale?.countryCode ?? '').toUpperCase();
    if (language == 'zh' && country == 'TW') {
      return '當前尚未綁定 Steam，請先前往 TronSkins 官方網站完成綁定。';
    }
    if (language == 'zh') {
      return '当前尚未绑定 Steam，请先前往 TronSkins 官网完成绑定。';
    }
    return 'Steam is not bound yet. Please go to the TronSkins official '
        'website and bind it first.';
  }

  Future<void> _refreshInventoryAndPreloadIfNeeded() async {
    await controller.refreshIfStale();
    await controller.preloadStateBucketsIfNeeded();
  }

  @override
  void initState() {
    super.initState();
    _inventoryStatePageController = PageController(
      initialPage: _inventoryFilterToPage(_currentInventoryStateFilter()),
    );
    _inventoryStatePageController.addListener(
      _syncInventoryTabIndicatorWithPage,
    );
    _inventoryTabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: _inventoryFilterToPage(_currentInventoryStateFilter()),
    );
    _searchController.text = controller.keywords.value;
    if (userController.isLoggedIn.value) {
      Future.microtask(_refreshInventoryAndPreloadIfNeeded);
      Future.microtask(_checkSteamSessionIfNeeded);
    }
    _loginWorker = ever<bool>(userController.isLoggedIn, (loggedIn) {
      if (loggedIn) {
        Future.microtask(_refreshInventoryAndPreloadIfNeeded);
        Future.microtask(_checkSteamSessionIfNeeded);
      } else {
        controller.items.clear();
        controller.schemas.clear();
        controller.total.value = 0;
        controller.totalPrice.value = 0;
        controller.clearSelection();
      }
    });

    if (Get.isRegistered<NavController>()) {
      final navController = Get.find<NavController>();
      _tabWorker = ever<int>(navController.currentIndex, (index) {
        if (index == 2 && userController.isLoggedIn.value) {
          Future.microtask(_refreshInventoryAndPreloadIfNeeded);
          Future.microtask(_checkSteamSessionIfNeeded);
        }
      });
    }
  }

  Future<bool> _checkSteamSessionIfNeeded() async {
    if (!mounted ||
        !userController.isLoggedIn.value ||
        _steamSessionDialogShowing) {
      return true;
    }

    try {
      final hasBoundSteam = await _hasBoundSteam();
      if (!mounted || !userController.isLoggedIn.value) {
        return true;
      }
      if (!hasBoundSteam) {
        _steamSessionDialogShowing = true;
        await showFigmaModal<void>(
          context: context,
          barrierDismissible: true,
          child: _InventorySteamUnboundDialog(
            message: _steamUnboundDialogMessage,
            onConfirm: () => popModalRoute(context),
          ),
        );
        return false;
      }

      final sessionState = await _steamApi.steamOnlineState();
      if (!mounted || !userController.isLoggedIn.value) {
        return true;
      }
      if (sessionState.datas == true) {
        return true;
      }

      _steamSessionDialogShowing = true;
      await showFigmaModal<void>(
        context: context,
        barrierDismissible: true,
        child: _InventorySteamSessionExpiredDialog(
          onCancel: () => popModalRoute(context),
          onVerify: () {
            popModalRoute(context);
            Get.toNamed(
              Routers.STEAM_SETTING,
              arguments: {'fromInventorySessionExpired': true},
            );
          },
        ),
      );
      return false;
    } catch (_) {
      // ignore network errors for passive session check
      return true;
    } finally {
      _steamSessionDialogShowing = false;
    }
  }

  @override
  void dispose() {
    _inventoryTabController.dispose();
    _inventoryStatePageController
      ..removeListener(_syncInventoryTabIndicatorWithPage)
      ..dispose();
    _allInventoryScroll.dispose();
    _sellableInventoryScroll.dispose();
    _coolingInventoryScroll.dispose();
    _searchController.dispose();
    _loginWorker?.dispose();
    _tabWorker?.dispose();
    super.dispose();
  }

  Future<void> _onRefresh() async {
    final canContinue = await _checkSteamSessionIfNeeded();
    if (!canContinue) {
      return;
    }
    await controller.refreshByPullDown();
  }

  bool _isItemSelectable(InventoryItem item) {
    final isTradable = item.tradable ?? true;
    final isCooling = item.coolingDown ?? false;
    final isOnSale = item.status == 1;
    final isInSupply = item.status == 2;
    return isTradable && !isCooling && !isOnSale && !isInSupply;
  }

  Future<void> _openSelectedItemsUpshop() async {
    if (controller.selectedIds.isEmpty) {
      return;
    }
    final selectedItems = controller.items
        .where((item) => controller.selectedIds.contains(item.id ?? -1))
        .toList();
    if (selectedItems.isEmpty) {
      return;
    }
    await Get.toNamed(
      Routers.INVENTORY_UPSHOP,
      arguments: {
        'items': selectedItems,
        'schemas': controller.schemas,
        'appId': controller.appId,
      },
    );
  }

  void _toggleSelectAllSellable(Set<int> sellableIds) {
    if (sellableIds.isEmpty) {
      return;
    }
    final selectedIds = controller.selectedIds;
    final isAllSelected = sellableIds.every(selectedIds.contains);
    if (isAllSelected) {
      selectedIds.removeAll(sellableIds);
    } else {
      selectedIds.addAll(sellableIds);
    }
    selectedIds.refresh();
  }

  Future<void> _openFilterSheet() async {
    final result = await MarketFilterSheet.showFromLeft(
      context: context,
      appId: controller.currentAppId.value,
      sortOptions: const [
        SortOption(labelKey: 'app.market.filter.price', field: 'price'),
        SortOption(labelKey: 'app.market.filter.time', field: 'time'),
        SortOption(labelKey: 'app.market.csgo.wear', field: 'paintWear'),
      ],
      showPriceRange: false,
      attributeGroupOrder: const [
        'type',
        'exterior',
        'quality',
        'rarity',
        'itemSet',
      ],
      includeFallbackAttributeGroups: false,
      useCompactSortLabels: true,
      initial: MarketFilterResult(
        sortField: controller.sortField.value,
        sortAsc: controller.sortField.value.isEmpty
            ? false
            : controller.sortAsc.value,
        priceMin: controller.priceMin.value,
        priceMax: controller.priceMax.value,
        tags: Map<String, dynamic>.from(controller.tags),
        itemName: controller.itemName.value,
      ),
    );
    if (result != null) {
      if (result.clearKeyword) {
        _searchController.clear();
      }
      await controller.applyFilter(
        field: result.sortField,
        asc: result.sortAsc,
        minPrice: result.priceMin,
        maxPrice: result.priceMax,
        tags: result.tags,
        itemName: result.itemName,
        keyword: result.clearKeyword ? '' : null,
      );
    }
  }

  ShopSchemaInfo? _lookupSchema(
    Map<String, ShopSchemaInfo> schemas,
    InventoryItem item,
  ) {
    final hash = item.marketHashName;
    if (hash != null && schemas.containsKey(hash)) {
      return schemas[hash];
    }
    final schemaId = item.schemaId?.toString();
    if (schemaId != null && schemas.containsKey(schemaId)) {
      return schemas[schemaId];
    }
    return null;
  }

  int _inventoryFilterToPage(_InventoryStateFilter filter) {
    switch (filter) {
      case _InventoryStateFilter.all:
        return 0;
      case _InventoryStateFilter.sellable:
        return 1;
      case _InventoryStateFilter.cooling:
        return 2;
    }
  }

  _InventoryStateFilter _inventoryFilterFromPage(int page) {
    switch (page) {
      case 1:
        return _InventoryStateFilter.sellable;
      case 2:
        return _InventoryStateFilter.cooling;
      default:
        return _InventoryStateFilter.all;
    }
  }

  String _inventoryStateKey(_InventoryStateFilter filter) {
    switch (filter) {
      case _InventoryStateFilter.all:
        return 'all';
      case _InventoryStateFilter.sellable:
        return 'sellable';
      case _InventoryStateFilter.cooling:
        return 'cooling';
    }
  }

  Future<void> _applyInventoryStateFilter(
    _InventoryStateFilter selected,
  ) async {
    switch (selected) {
      case _InventoryStateFilter.all:
        if (controller.sellableOnly.value) {
          await controller.toggleSellable();
          return;
        }
        if (controller.coolingOnly.value) {
          await controller.toggleCooling();
        }
        return;
      case _InventoryStateFilter.sellable:
        if (!controller.sellableOnly.value) {
          await controller.toggleSellable();
        }
        return;
      case _InventoryStateFilter.cooling:
        if (!controller.coolingOnly.value) {
          await controller.toggleCooling();
        }
        return;
    }
  }

  Future<void> _animateToInventoryStatePage(
    _InventoryStateFilter filter,
  ) async {
    if (!_inventoryStatePageController.hasClients) {
      await _applyInventoryStateFilter(filter);
      return;
    }
    final targetPage = _inventoryFilterToPage(filter);
    final currentPage =
        (_inventoryStatePageController.page ??
                _inventoryStatePageController.initialPage.toDouble())
            .round();
    if (currentPage == targetPage) {
      return;
    }
    await _inventoryStatePageController.animateToPage(
      targetPage,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _onInventoryStatePageChanged(int page) async {
    if (controller.isLoading.value) {
      _syncInventoryTabController(_currentInventoryStateFilter());
      await _animateToInventoryStatePage(_currentInventoryStateFilter());
      return;
    }
    final selected = _inventoryFilterFromPage(page);
    _syncInventoryTabController(selected);
    if (selected == _currentInventoryStateFilter()) {
      return;
    }
    await _applyInventoryStateFilter(selected);
  }

  bool _onInventoryScrollNotification(ScrollNotification notification) {
    final metrics = notification.metrics;
    if (metrics.maxScrollExtent <= 0) {
      return false;
    }
    if (metrics.pixels >= metrics.maxScrollExtent - 240) {
      controller.loadMore();
    }
    return false;
  }

  Future<void> _applySearch(String value) async {
    final normalized = value.trim();
    if (normalized == controller.keywords.value) {
      return;
    }
    await controller.search(normalized);
  }

  void _syncInventoryTabIndicatorWithPage() {
    if (!_inventoryStatePageController.hasClients ||
        _inventoryTabController.indexIsChanging) {
      return;
    }

    final page = _inventoryStatePageController.page;
    if (page == null) {
      return;
    }

    final clampedPage = page.clamp(
      0.0,
      (_inventoryTabController.length - 1).toDouble(),
    );
    final baseIndex = clampedPage.floor();
    final nextOffset = (clampedPage - baseIndex).clamp(-1.0, 1.0);

    if (_inventoryTabController.index != baseIndex) {
      _inventoryTabController.index = baseIndex;
    }
    _inventoryTabController.offset = nextOffset;
  }

  void _syncInventoryTabController(_InventoryStateFilter filter) {
    final targetIndex = _inventoryFilterToPage(filter);
    if (_inventoryTabController.index == targetIndex &&
        !_inventoryTabController.indexIsChanging) {
      return;
    }
    _inventoryTabController.animateTo(
      targetIndex,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
    );
  }

  String _gameLabelForAppId(int appId) {
    return switch (appId) {
      730 => 'CS2',
      570 => 'DOTA2',
      440 => 'TF2',
      _ => 'GAME',
    };
  }

  bool get _isEnglishLocale =>
      Get.locale?.languageCode.toLowerCase().startsWith('en') ?? false;

  String get _emptyTitle => _isEnglishLocale ? 'No inventory items' : '暂无库存饰品';

  String get _emptySubtitle => _isEnglishLocale
      ? 'Adjust your search or filters, then check back again.'
      : '调整搜索或筛选条件后，再回来看看。';

  Widget _buildInventoryListView({
    required String storageKey,
    required ScrollController scrollController,
    required _InventoryStateFilter filter,
  }) {
    return Obx(() {
      final _ = controller.stateCacheVersion.value;
      final stateKey = _inventoryStateKey(filter);
      final isActiveState = controller.activeStateKey == stateKey;
      final visibleItems = controller.itemsForState(stateKey);
      final visibleSchemas = controller.schemasForState(stateKey);
      final visibleStickers = controller.stickersForState(stateKey);
      final showLoadingState =
          visibleItems.isEmpty &&
          (isActiveState
              ? controller.isLoading.value
              : !controller.isStateCached(stateKey) ||
                    controller.isPreloadingStateBuckets);

      if (showLoadingState) {
        return _buildLoadingGrid('$storageKey-loading');
      }
      if (visibleItems.isEmpty) {
        return _buildInventoryEmptyState();
      }
      return _buildRefreshScrollView(
        storageKey: storageKey,
        scrollController: scrollController,
        slivers: [
          SliverPadding(
            padding: _gridPadding,
            sliver: SliverGrid.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: _gridColumns,
                mainAxisSpacing: _gridMainSpacing,
                crossAxisSpacing: _gridCrossSpacing,
                childAspectRatio: _gridAspectRatio,
              ),
              itemCount:
                  visibleItems.length +
                  (isActiveState &&
                          controller.isLoading.value &&
                          controller.hasMoreForState(stateKey)
                      ? _loadMorePlaceholderCount
                      : 0),
              itemBuilder: (context, index) {
                if (index >= visibleItems.length) {
                  return const MarketShowcaseLoadingCard();
                }

                final item = visibleItems[index];
                final schema = _lookupSchema(visibleSchemas, item);
                final isTradable = item.tradable ?? true;
                final isCooling = item.coolingDown ?? false;
                final isOnSale = item.status == 1;
                final isInSupply = item.status == 2;
                final disabled = !_isItemSelectable(item);
                final disabledLabel = !isTradable
                    ? 'app.trade.non_tradable'.tr
                    : isCooling
                    ? 'app.market.product.cooling'.tr
                    : isOnSale
                    ? 'app.inventory.on_sale'.tr
                    : isInSupply
                    ? 'app.inventory.in_supply'.tr
                    : null;

                return Obx(() {
                  final selected = controller.selectedIds.contains(
                    item.id ?? -1,
                  );
                  final showSelectionControl =
                      controller.selectedIds.isNotEmpty && !disabled;
                  return InventoryShowcaseCard(
                    item: item,
                    schema: schema,
                    schemaMap: visibleSchemas,
                    stickerMap: visibleStickers,
                    selected: selected,
                    showSelectionControl: showSelectionControl,
                    disabledLabel: disabled ? disabledLabel : null,
                    onTap: () {
                      if (item.id == null) {
                        return;
                      }
                      if (disabled) {
                        AppSnackbar.info(
                          !isTradable
                              ? 'app.inventory.message.non_tradable'.tr
                              : isCooling
                              ? 'app.market.product.cooling'.tr
                              : isOnSale
                              ? 'app.inventory.on_sale'.tr
                              : 'app.inventory.in_supply'.tr,
                        );
                        return;
                      }
                      controller.toggleSelection(item.id!);
                    },
                  );
                });
              },
            ),
          ),
          if (visibleItems.isNotEmpty &&
              (!isActiveState || !controller.isLoading.value) &&
              !controller.hasMoreForState(stateKey))
            const SliverToBoxAdapter(child: ListEndTip()),
        ],
      );
    });
  }

  Widget _buildInventoryEmptyState() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
      child: SizedBox.expand(
        child: MarketEmptyState(
          icon: Icons.inventory_2_outlined,
          title: _emptyTitle,
          subtitle: _emptySubtitle,
          blendWithBackground: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currency = Get.find<CurrencyController>();
    return BackToTopScope(
      enabled: false,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F9FB),
        body: Obx(() {
          if (!userController.isLoggedIn.value) {
            return _buildLoginPrompt();
          }
          return SafeArea(
            bottom: false,
            child: Column(
              children: [
                _buildHeader(currency),
                Expanded(
                  child: Obx(() {
                    if (controller.currentAppId.value == 440) {
                      return _buildInventoryListView(
                        storageKey: 'inventory_scroll_single',
                        scrollController: _allInventoryScroll,
                        filter: _InventoryStateFilter.all,
                      );
                    }
                    return PageView(
                      controller: _inventoryStatePageController,
                      onPageChanged: (page) {
                        _onInventoryStatePageChanged(page);
                      },
                      children: [
                        _buildInventoryListView(
                          storageKey: 'inventory_scroll_all',
                          scrollController: _allInventoryScroll,
                          filter: _InventoryStateFilter.all,
                        ),
                        _buildInventoryListView(
                          storageKey: 'inventory_scroll_sellable',
                          scrollController: _sellableInventoryScroll,
                          filter: _InventoryStateFilter.sellable,
                        ),
                        _buildInventoryListView(
                          storageKey: 'inventory_scroll_cooling',
                          scrollController: _coolingInventoryScroll,
                          filter: _InventoryStateFilter.cooling,
                        ),
                      ],
                    );
                  }),
                ),
              ],
            ),
          );
        }),
        bottomNavigationBar: Obx(() {
          if (!userController.isLoggedIn.value ||
              controller.selectedIds.isEmpty) {
            return const SizedBox.shrink();
          }
          return _buildInventorySelectionBar();
        }),
      ),
    );
  }

  Widget _buildRefreshScrollView({
    required String storageKey,
    required ScrollController scrollController,
    required List<Widget> slivers,
  }) {
    return RefreshIndicator(
      color: const Color(0xFF00288E),
      backgroundColor: Colors.white,
      strokeWidth: 2.2,
      displacement: 22,
      edgeOffset: 2,
      elevation: 0,
      notificationPredicate: (notification) => notification.depth == 0,
      onRefresh: _onRefresh,
      child: NotificationListener<ScrollNotification>(
        onNotification: _onInventoryScrollNotification,
        child: CustomScrollView(
          key: PageStorageKey<String>(storageKey),
          controller: scrollController,
          physics: const AlwaysScrollableScrollPhysics(
            parent: ClampingScrollPhysics(),
          ),
          slivers: slivers,
        ),
      ),
    );
  }

  Widget _buildLoadingGrid(String storageKey) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemCount = _calculateLoadingCount(constraints);
        return GridView.builder(
          key: PageStorageKey<String>(storageKey),
          padding: _gridPadding,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: _gridColumns,
            mainAxisSpacing: _gridMainSpacing,
            crossAxisSpacing: _gridCrossSpacing,
            childAspectRatio: _gridAspectRatio,
          ),
          itemCount: itemCount,
          itemBuilder: (context, index) => const MarketShowcaseLoadingCard(),
        );
      },
    );
  }

  int _calculateLoadingCount(BoxConstraints constraints) {
    if (!constraints.hasBoundedWidth || !constraints.hasBoundedHeight) {
      return 6;
    }
    final contentWidth =
        constraints.maxWidth - _gridPadding.left - _gridPadding.right;
    if (contentWidth <= 0) {
      return 6;
    }
    final itemWidth =
        (contentWidth - _gridCrossSpacing * (_gridColumns - 1)) / _gridColumns;
    if (itemWidth <= 0) {
      return 6;
    }
    final itemHeight = itemWidth / _gridAspectRatio;
    final effectiveHeight =
        constraints.maxHeight - _gridPadding.top - _gridPadding.bottom;
    final rowExtent = itemHeight + _gridMainSpacing;
    final visibleRows = ((effectiveHeight + _gridMainSpacing) / rowExtent)
        .ceil()
        .clamp(2, 8);
    return visibleRows * _gridColumns;
  }

  Widget _buildHeader(CurrencyController currency) {
    final showTabs = controller.currentAppId.value != 440;
    final hasActiveFilter =
        controller.sortField.value.isNotEmpty ||
        controller.priceMin.value != null ||
        controller.priceMax.value != null ||
        controller.tags.isNotEmpty ||
        (controller.itemName.value?.isNotEmpty ?? false);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FB).withValues(alpha: 0.94),
        border: Border(
          bottom: BorderSide(color: Colors.black.withValues(alpha: 0.04)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      HeaderFilterButton(
                        tooltip: 'app.market.filter.text'.tr,
                        active: hasActiveFilter,
                        onTap: _openFilterSheet,
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          'app.inventory.title'.tr,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF191C1E),
                            fontSize: 20,
                            height: 28 / 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                _buildGameSwitchTrigger(),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: _buildSearchBar(),
          ),
          if (showTabs)
            Align(
              alignment: Alignment.centerLeft,
              child: _buildInventoryTabBar(),
            ),
          Padding(
            padding: EdgeInsets.fromLTRB(16, showTabs ? 6 : 2, 16, 10),
            child: _buildInventorySummaryBar(currency),
          ),
        ],
      ),
    );
  }

  Widget _buildInventorySelectionBar() {
    final sellableTotal = controller.items.where(_isItemSelectable).length;
    final selectedCount = controller.selectedIds.length;
    final isAllSelected = sellableTotal > 0 && selectedCount >= sellableTotal;
    final selectableIds = controller.items
        .where(_isItemSelectable)
        .map((item) => item.id)
        .whereType<int>()
        .toSet();

    return FloatingSelectionActionBar(
      isAllSelected: isAllSelected,
      selectAllLabel: 'app.market.filter.all'.tr,
      toggleTooltip: isAllSelected
          ? 'app.common.deselect_all'.tr
          : 'app.common.select_all'.tr,
      selectedCountText: '$selectedCount/$sellableTotal',
      onToggleSelectAll: () => _toggleSelectAllSellable(selectableIds),
      actions: [
        SelectionActionBarButtonData(
          label: 'app.inventory.upshop.text'.tr,
          onTap: _openSelectedItemsUpshop,
          variant: SelectionActionBarButtonVariant.primary,
        ),
      ],
    );
  }

  _InventoryStateFilter _currentInventoryStateFilter() {
    if (controller.sellableOnly.value) {
      return _InventoryStateFilter.sellable;
    }
    if (controller.coolingOnly.value) {
      return _InventoryStateFilter.cooling;
    }
    return _InventoryStateFilter.all;
  }

  String _inventoryStateLabelKey(_InventoryStateFilter filter) {
    switch (filter) {
      case _InventoryStateFilter.sellable:
        return 'app.market.product.sellable';
      case _InventoryStateFilter.cooling:
        return 'app.market.product.cooling';
      case _InventoryStateFilter.all:
        return 'app.market.filter.all';
    }
  }

  Widget _buildGameSwitchTrigger() {
    final appId = controller.currentAppId.value;
    return Builder(
      builder: (switchContext) {
        return Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () async {
              final selected = await showGameSwitchMenu(
                iconContext: switchContext,
                currentAppId: appId,
              );
              if (selected == null) {
                return;
              }
              await controller.changeGame(selected);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _gameLabelForAppId(appId),
                    style: const TextStyle(
                      color: Color(0xFF191C1E),
                      fontSize: 14,
                      height: 20 / 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: Color(0xFF191C1E),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInventoryTabBar() {
    return Obx(() {
      final loading = controller.isLoading.value;
      final currentFilter = _currentInventoryStateFilter();
      final targetIndex = _inventoryFilterToPage(currentFilter);
      if (_inventoryTabController.index != targetIndex &&
          !_inventoryTabController.indexIsChanging) {
        _inventoryTabController.index = targetIndex;
      }

      final tabBar = TabBar(
        controller: _inventoryTabController,
        isScrollable: true,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        tabAlignment: TabAlignment.start,
        indicatorSize: TabBarIndicatorSize.label,
        indicatorColor: const Color(0xFF00288E),
        indicatorWeight: 2,
        dividerColor: Colors.transparent,
        labelPadding: const EdgeInsets.only(right: 28, bottom: 2),
        splashFactory: NoSplash.splashFactory,
        labelColor: const Color(0xFF00288E),
        unselectedLabelColor: const Color(0xFF444653),
        labelStyle: const TextStyle(
          fontSize: 16,
          height: 24 / 16,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 16,
          height: 24 / 16,
          fontWeight: FontWeight.w500,
        ),
        onTap: (index) {
          if (loading) {
            _syncInventoryTabController(currentFilter);
            return;
          }
          _animateToInventoryStatePage(_inventoryFilterFromPage(index));
        },
        tabs: [
          Tab(
            height: 30,
            text: _inventoryStateLabelKey(_InventoryStateFilter.all).tr,
          ),
          Tab(
            height: 30,
            text: _inventoryStateLabelKey(_InventoryStateFilter.sellable).tr,
          ),
          Tab(
            height: 30,
            text: _inventoryStateLabelKey(_InventoryStateFilter.cooling).tr,
          ),
        ],
      );

      return IgnorePointer(
        ignoring: loading,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragUpdate: (details) {
                if (!_inventoryStatePageController.hasClients) {
                  return;
                }
                final width = constraints.maxWidth;
                if (width <= 0) {
                  return;
                }
                final page = _inventoryStatePageController.page;
                if (page == null) {
                  return;
                }
                final nextPage = (page - (details.delta.dx / width)).clamp(
                  0.0,
                  (_inventoryTabController.length - 1).toDouble(),
                );
                _inventoryStatePageController.jumpTo(
                  nextPage *
                      _inventoryStatePageController.position.viewportDimension,
                );
              },
              onHorizontalDragEnd: (_) {
                if (!_inventoryStatePageController.hasClients) {
                  return;
                }
                final page = _inventoryStatePageController.page;
                if (page == null) {
                  return;
                }
                _animateToInventoryStatePage(
                  _inventoryFilterFromPage(page.round()),
                );
              },
              onHorizontalDragCancel: () {
                _animateToInventoryStatePage(_currentInventoryStateFilter());
              },
              child: tabBar,
            );
          },
        ),
      );
    });
  }

  Widget _buildInventorySummaryBar(CurrencyController currency) {
    final colors = Theme.of(context).colorScheme;
    final borderColor = colors.outline.withValues(alpha: 0.12);

    return Obx(() {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: borderColor),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A0F172A),
              offset: Offset(0, 3),
              blurRadius: 10,
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: _buildInventorySummaryMetric(
                label: 'app.inventory.count'.tr,
                value: '${controller.total.value}',
              ),
            ),
            Container(
              width: 1,
              height: 14,
              color: borderColor,
              margin: const EdgeInsets.symmetric(horizontal: 10),
            ),
            Expanded(
              child: _buildInventorySummaryMetric(
                label: 'app.inventory.total_value'.tr,
                value: currency.format(controller.totalPrice.value),
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildInventorySummaryMetric({
    required String label,
    required String value,
  }) {
    return RichText(
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      text: TextSpan(
        children: [
          TextSpan(
            text: '$label  ',
            style: const TextStyle(
              color: Color(0xFF757684),
              fontSize: 11,
              height: 16 / 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          TextSpan(
            text: value,
            style: const TextStyle(
              color: Color(0xFF191C1E),
              fontSize: 14,
              height: 18 / 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return AppSearchInputBar(
      controller: _searchController,
      hintText: 'app.market.filter.search'.tr,
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => FocusScope.of(context).unfocus(),
      onChanged: (_) {
        if (mounted) {
          setState(() {});
        }
      },
      onClearTap: () {
        _searchController.clear();
        if (mounted) {
          setState(() {});
        }
        _applySearch('');
      },
      onSearchTap: () {
        FocusScope.of(context).unfocus();
        _applySearch(_searchController.text);
      },
    );
  }

  Widget _buildLoginPrompt() {
    return const LoginRequiredPrompt();
  }
}

class _InventorySteamSessionExpiredDialog extends StatelessWidget {
  const _InventorySteamSessionExpiredDialog({
    required this.onCancel,
    required this.onVerify,
  });

  final VoidCallback onCancel;
  final VoidCallback onVerify;

  @override
  Widget build(BuildContext context) {
    final verifyLabel = Get.locale?.languageCode == 'en'
        ? 'Verification'
        : 'app.steam.verification'.tr;
    return FigmaConfirmationDialog(
      icon: Icons.warning_amber_rounded,
      title: 'app.steam.verification'.tr,
      message: 'app.steam.session.expired'.tr,
      primaryLabel: verifyLabel,
      onPrimary: onVerify,
      secondaryLabel: 'app.common.cancel'.tr,
      onSecondary: onCancel,
    );
  }
}

class _InventorySteamUnboundDialog extends StatelessWidget {
  const _InventorySteamUnboundDialog({
    required this.message,
    required this.onConfirm,
  });

  final String message;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return FigmaConfirmationDialog(
      icon: Icons.public_rounded,
      iconColor: const Color(0xFF1E40AF),
      iconBackgroundColor: const Color.fromRGBO(30, 64, 175, 0.10),
      title: 'app.system.tips.warm'.tr,
      message: message,
      primaryLabel: 'app.common.confirm'.tr,
      onPrimary: onConfirm,
    );
  }
}
