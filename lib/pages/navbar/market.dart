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
import 'package:tronskins_app/controllers/market/market_list_controller.dart';
import 'package:tronskins_app/pages/market/market_search_page.dart';
import 'package:tronskins_app/routes/app_routes.dart';

class MarketPage extends StatefulWidget {
  const MarketPage({super.key});

  @override
  State<MarketPage> createState() => _MarketPageState();
}

class _MarketPageState extends State<MarketPage> {
  static const int _gridColumns = 2;
  static const double _gridMainSpacing = 8;
  static const double _gridCrossSpacing = 8;
  static const double _gridAspectRatio = 0.98;
  static const EdgeInsets _gridPadding = EdgeInsets.fromLTRB(16, 4, 16, 16);
  static const int _loadMorePlaceholderCount = 2;

  final MarketListController controller =
      Get.isRegistered<MarketListController>()
      ? Get.find<MarketListController>()
      : Get.put(MarketListController());

  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  late final Worker _keywordWorker;

  @override
  void initState() {
    super.initState();
    controller.applyInitialArgs(Get.arguments as Map<String, dynamic>?);
    _searchController.text = controller.keywords.value;
    _keywordWorker = ever<String>(controller.keywords, (value) {
      if (_searchController.text != value) {
        _searchController.text = value;
        if (mounted) {
          setState(() {});
        }
      }
    });
    if (controller.items.isEmpty && !controller.isLoading.value) {
      controller.refresh();
    }
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >
          _scrollController.position.maxScrollExtent - 200) {
        controller.loadMore();
      }
    });
  }

  @override
  void dispose() {
    _keywordWorker.dispose();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openFilterSheet() async {
    final isTf2 = controller.appId.value == 440;
    final result = await MarketFilterSheet.showFromLeft(
      context: context,
      appId: controller.appId.value,
      sortOptions: const [
        SortOption(labelKey: 'app.market.filter.price', field: 'price'),
        SortOption(labelKey: 'app.market.filter.hot', field: 'hot'),
      ],
      showSort: !isTf2,
      showAttributeFilters: !isTf2,
      initial: MarketFilterResult(
        sortField: controller.sortField.value,
        sortAsc: controller.sortField.value.isEmpty
            ? false
            : controller.sortAsc.value,
        priceMin: controller.priceMin.value,
        priceMax: controller.priceMax.value,
        tags: isTf2
            ? const <String, dynamic>{}
            : Map<String, dynamic>.from(controller.tags),
        itemName: isTf2 ? null : controller.itemName.value,
      ),
    );
    if (result != null) {
      if (result.clearKeyword) {
        _searchController.clear();
      }
      await controller.applyFilter(
        field: result.sortField,
        asc: result.sortField.isEmpty ? false : result.sortAsc,
        minPrice: result.priceMin,
        maxPrice: result.priceMax,
        tags: result.tags,
        itemName: result.itemName,
        keyword: result.clearKeyword ? '' : null,
      );
    }
  }

  Future<void> _openSearchPage() async {
    final result = await Get.to<String>(
      () => MarketSearchPage(
        appId: controller.appId.value,
        initialKeyword: controller.keywords.value,
      ),
      transition: Transition.rightToLeft,
      duration: const Duration(milliseconds: 220),
    );
    if (result != null) {
      _searchController.text = result;
      await controller.search(result);
      if (mounted) {
        setState(() {});
      }
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
            Obx(() => _buildHeader()),
            Expanded(child: _buildGrid()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
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
                      const Flexible(
                        child: Text(
                          'Market',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
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
            child: _buildSearchTrigger(),
          ),
        ],
      ),
    );
  }

  Widget _buildGameSwitchTrigger() {
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

  Widget _buildSearchTrigger() {
    final hasKeyword = _searchController.text.trim().isNotEmpty;
    final keyword = _searchController.text.trim();

    return AppSearchTriggerBar(
      hintText: 'app.market.filter.search'.tr,
      text: hasKeyword ? keyword : null,
      onTap: _openSearchPage,
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

  String get _emptyTitle => _isEnglishLocale ? 'No items found' : '暂无饰品数据';

  String get _emptySubtitle => _isEnglishLocale
      ? 'Try pulling down to refresh or adjust your search and filters.'
      : '可以尝试下拉刷新，或调整搜索与筛选条件。';

  Widget _buildRefreshScrollView({
    required String storageKey,
    required Future<void> Function() onRefresh,
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
      onRefresh: onRefresh,
      child: CustomScrollView(
        key: PageStorageKey<String>(storageKey),
        controller: _scrollController,
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

  Widget _buildGrid() {
    return Obx(() {
      if (controller.items.isEmpty && controller.isLoading.value) {
        return _buildLoadingGrid('market-loading');
      }
      return _buildRefreshScrollView(
        storageKey: 'market-grid',
        onRefresh: () => controller.refresh(reset: true),
        slivers: [
          if (controller.items.isEmpty)
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
                    controller.items.length +
                    (controller.isLoading.value && controller.hasMore
                        ? _loadMorePlaceholderCount
                        : 0),
                itemBuilder: (context, index) {
                  if (index >= controller.items.length) {
                    return const MarketShowcaseLoadingCard();
                  }
                  final item = controller.items[index];
                  return HomeMarketItemCard(
                    item: item,
                    onTap: () =>
                        Get.toNamed(Routers.MARKET_DETAIL, arguments: item),
                  );
                },
              ),
            ),
          if (controller.items.isNotEmpty &&
              !controller.isLoading.value &&
              !controller.hasMore)
            const SliverToBoxAdapter(child: ListEndTip()),
        ],
      );
    });
  }
}
