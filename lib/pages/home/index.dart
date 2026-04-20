import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tronskins_app/components/game/game_switch_menu.dart';
import 'package:tronskins_app/components/filter/filter_models.dart';
import 'package:tronskins_app/components/filter/market_filter_sheet.dart';
import 'package:tronskins_app/components/layout/app_search_bar.dart';
import 'package:tronskins_app/components/layout/header_filter_button.dart';
import 'package:tronskins_app/components/layout/list_end_tip.dart';
import 'package:tronskins_app/components/market/home_market_item_card.dart';
import 'package:tronskins_app/components/market/market_showcase_card.dart';
import 'package:tronskins_app/controllers/home/home_controller.dart';
import 'package:tronskins_app/controllers/market/market_list_controller.dart';
import 'package:tronskins_app/controllers/navbar/nav_controller.dart';
import 'package:tronskins_app/pages/market/market_search_page.dart';
import 'package:tronskins_app/routes/app_routes.dart';
import 'package:tronskins_app/api/model/market/market_models.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  static const int _gridColumns = 2;
  static const double _gridMainSpacing = 8;
  static const double _gridCrossSpacing = 8;
  static const double _gridAspectRatio = 0.98;
  static const EdgeInsets _gridPadding = EdgeInsets.fromLTRB(16, 4, 16, 16);
  static const int _loadMorePlaceholderCount = 2;

  final HomeController controller = Get.isRegistered<HomeController>()
      ? Get.find<HomeController>()
      : Get.put(HomeController());
  late final TabController _tabController;
  final ScrollController _latestScroll = ScrollController();
  final ScrollController _hotScroll = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  String _sortField = '';
  bool _sortAsc = false;
  double? _priceMin;
  double? _priceMax;
  Map<String, dynamic>? _tags;
  String? _itemName;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _latestScroll.addListener(_handleLatestScroll);
    _hotScroll.addListener(_handleHotScroll);
  }

  @override
  void dispose() {
    _latestScroll.removeListener(_handleLatestScroll);
    _hotScroll.removeListener(_handleHotScroll);
    _tabController.dispose();
    _latestScroll.dispose();
    _hotScroll.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _handleLatestScroll() {
    if (_latestScroll.hasClients &&
        _latestScroll.position.pixels >
            _latestScroll.position.maxScrollExtent - 200) {
      controller.fetchLatest();
    }
  }

  void _handleHotScroll() {
    if (_hotScroll.hasClients &&
        _hotScroll.position.pixels >
            _hotScroll.position.maxScrollExtent - 200) {
      controller.fetchHot();
    }
  }

  void _handleTabDragUpdate({
    required double deltaDx,
    required double dragWidth,
  }) {
    if (_tabController.indexIsChanging || dragWidth <= 0) {
      return;
    }
    final maxIndex = (_tabController.length - 1).toDouble();
    final currentValue =
        _tabController.animation?.value ?? _tabController.index.toDouble();
    final nextValue = (currentValue - (deltaDx / dragWidth))
        .clamp(0.0, maxIndex)
        .toDouble();
    final nextOffset = (nextValue - _tabController.index).clamp(-1.0, 1.0);
    if (nextOffset >= 0.98 &&
        _tabController.index < _tabController.length - 1) {
      _tabController.index = _tabController.index + 1;
      _tabController.offset = 0;
      return;
    }
    if (nextOffset <= -0.98 && _tabController.index > 0) {
      _tabController.index = _tabController.index - 1;
      _tabController.offset = 0;
      return;
    }
    _tabController.offset = nextOffset;
  }

  void _settleToClosestTab() {
    if (_tabController.indexIsChanging) {
      return;
    }
    final value =
        _tabController.animation?.value ?? _tabController.index.toDouble();
    final targetIndex = value.round().clamp(0, _tabController.length - 1);
    if (targetIndex == _tabController.index) {
      _tabController.offset = 0;
      return;
    }
    _tabController.animateTo(
      targetIndex,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _openFilterSheet() async {
    final isTf2 = controller.appId.value == 440;
    final result = await MarketFilterSheet.showFromLeft(
      context: context,
      appId: controller.appId.value,
      sortOptions: [
        SortOption(labelKey: 'app.market.filter.price', field: 'price'),
        SortOption(labelKey: 'app.market.filter.hot', field: 'hot'),
      ],
      showSort: !isTf2,
      showAttributeFilters: !isTf2,
      initial: MarketFilterResult(
        sortField: _sortField,
        sortAsc: _sortField.isEmpty ? false : _sortAsc,
        priceMin: _priceMin,
        priceMax: _priceMax,
        tags: isTf2 ? const <String, dynamic>{} : _tags,
        itemName: isTf2 ? null : _itemName,
      ),
    );
    if (result != null) {
      if (result.clearKeyword) {
        setState(() => _searchController.clear());
      }
      setState(() {
        _sortField = result.sortField;
        _sortAsc = result.sortField.isEmpty ? false : result.sortAsc;
        _priceMin = result.priceMin;
        _priceMax = result.priceMax;
        _tags = result.tags == null || result.tags!.isEmpty
            ? null
            : result.tags;
        _itemName = (result.itemName == null || result.itemName!.isEmpty)
            ? null
            : result.itemName;
      });
      _switchToMarketWithArgs({
        'keyword': _searchController.text.trim(),
        'sortField': result.sortField,
        'sortAsc': result.sortField.isEmpty ? false : result.sortAsc,
        'minPrice': result.priceMin,
        'maxPrice': result.priceMax,
        'tags': result.tags,
        'itemName': result.itemName,
      });
    }
  }

  void _submitSearch({String? keyword}) {
    final searchKeyword = keyword ?? _searchController.text.trim();
    _switchToMarketWithArgs({
      'keyword': searchKeyword,
      'sortField': _sortField,
      'sortAsc': _sortField.isEmpty ? false : _sortAsc,
      'minPrice': _priceMin,
      'maxPrice': _priceMax,
      'tags': _tags,
      'itemName': _itemName,
    });
  }

  void _switchToMarketWithArgs(Map<String, dynamic> args) {
    args['appId'] = controller.appId.value;
    final marketCtrl = Get.isRegistered<MarketListController>()
        ? Get.find<MarketListController>()
        : Get.put(MarketListController());
    marketCtrl.applyInitialArgs(args);
    marketCtrl.refresh(reset: true);
    final navCtrl = Get.isRegistered<NavController>()
        ? Get.find<NavController>()
        : Get.put(NavController(), permanent: true);
    navCtrl.switchTo(1);
  }

  Future<void> _openSearchPage() async {
    final result = await Get.to<String>(
      () => MarketSearchPage(appId: controller.appId.value, initialKeyword: ''),
      transition: Transition.rightToLeft,
      duration: const Duration(milliseconds: 220),
    );
    if (result != null) {
      setState(() => _searchController.clear());
      _submitSearch(keyword: result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FB),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  Obx(
                    () => _buildGrid(
                      'home-latest',
                      controller.latestItems,
                      controller.isLoadingLatest.value,
                      controller.latestHasMore,
                      _latestScroll,
                      onRefresh: () => controller.fetchLatest(reset: true),
                    ),
                  ),
                  Obx(
                    () => _buildGrid(
                      'home-hot',
                      controller.hotItems,
                      controller.isLoadingHot.value,
                      controller.hotHasMore,
                      _hotScroll,
                      onRefresh: () => controller.fetchHot(reset: true),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final hasActiveFilter =
        _sortField.isNotEmpty ||
        _priceMin != null ||
        _priceMax != null ||
        (_tags?.isNotEmpty ?? false) ||
        (_itemName?.isNotEmpty ?? false);

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
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
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
                      const SizedBox(width: 10),
                      Expanded(child: _buildSearchTrigger()),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _buildGameSwitchTrigger(),
              ],
            ),
          ),
          Align(alignment: Alignment.centerLeft, child: _buildHomeTabBar()),
        ],
      ),
    );
  }

  Widget _buildHomeTabBar() {
    final tabBar = TabBar(
      controller: _tabController,
      isScrollable: true,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      tabAlignment: TabAlignment.start,
      indicatorSize: TabBarIndicatorSize.label,
      indicatorColor: const Color(0xFF00288E),
      indicatorWeight: 2,
      dividerColor: Colors.transparent,
      labelPadding: const EdgeInsets.only(right: 22, bottom: 1),
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
      tabs: [
        Tab(height: 30, text: 'app.market.latest'.tr),
        Tab(height: 30, text: 'app.market.popular'.tr),
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragUpdate: (details) => _handleTabDragUpdate(
            deltaDx: details.delta.dx,
            dragWidth: constraints.maxWidth,
          ),
          onHorizontalDragEnd: (_) => _settleToClosestTab(),
          onHorizontalDragCancel: _settleToClosestTab,
          child: tabBar,
        );
      },
    );
  }

  Widget _buildSearchTrigger() {
    return AppSearchTriggerBar(
      hintText: 'app.market.filter.search'.tr,
      onTap: _openSearchPage,
    );
  }

  Widget _buildGameSwitchTrigger() {
    return Obx(() {
      final appId = controller.appId.value;
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
                if (!mounted) {
                  return;
                }
                setState(() {
                  _sortField = '';
                  _sortAsc = false;
                  _priceMin = null;
                  _priceMax = null;
                  _tags = null;
                  _itemName = null;
                });
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
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
    });
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

  String get _emptyTitle => _isEnglishLocale ? 'No items found' : '暂无饰品数据';

  String get _emptySubtitle => _isEnglishLocale
      ? 'Try pulling down to refresh or adjust your search and filters.'
      : '可以尝试下拉刷新，或调整搜索与筛选条件。';

  Widget _buildRefreshScrollView({
    required String storageKey,
    required Future<void> Function() onRefresh,
    required List<Widget> slivers,
    ScrollController? controller,
  }) {
    return RefreshIndicator(
      color: const Color(0xFF00288E),
      backgroundColor: Colors.white,
      strokeWidth: 2.2,
      displacement: 22,
      edgeOffset: 2,
      elevation: 0,
      notificationPredicate: (notification) => notification.depth == 0,
      onRefresh: onRefresh,
      child: CustomScrollView(
        key: PageStorageKey<String>(storageKey),
        controller: controller,
        physics: const AlwaysScrollableScrollPhysics(
          parent: ClampingScrollPhysics(),
        ),
        slivers: slivers,
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

  Widget _buildGrid(
    String storageKey,
    List<MarketItemEntity> items,
    bool isLoading,
    bool hasMore,
    ScrollController scrollController, {
    required Future<void> Function() onRefresh,
  }) {
    if (items.isEmpty && isLoading) {
      return _buildLoadingGrid('$storageKey-loading');
    }
    return _buildRefreshScrollView(
      storageKey: storageKey,
      controller: scrollController,
      onRefresh: onRefresh,
      slivers: [
        if (items.isEmpty)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
            sliver: SliverFillRemaining(
              hasScrollBody: false,
              child: MarketEmptyState(
                title: _emptyTitle,
                subtitle: _emptySubtitle,
              ),
            ),
          )
        else
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
                  items.length +
                  (isLoading && hasMore ? _loadMorePlaceholderCount : 0),
              itemBuilder: (context, index) {
                if (index >= items.length) {
                  return const MarketShowcaseLoadingCard();
                }
                final item = items[index];
                return HomeMarketItemCard(
                  item: item,
                  onTap: () =>
                      Get.toNamed(Routers.MARKET_DETAIL, arguments: item),
                );
              },
            ),
          ),
        if (items.isNotEmpty && !isLoading && !hasMore)
          const SliverToBoxAdapter(child: ListEndTip()),
      ],
    );
  }
}
