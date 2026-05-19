import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tronskins_app/api/model/notify/notify_models.dart';
import 'package:tronskins_app/api/model/systemModel.dart';
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
  final MarketListController marketController =
      Get.isRegistered<MarketListController>()
      ? Get.find<MarketListController>()
      : Get.put(MarketListController());
  late final TabController _tabController;
  final ScrollController _latestScroll = ScrollController();
  final ScrollController _hotScroll = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  Worker? _gameWorker;
  Worker? _marketKeywordWorker;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _latestScroll.addListener(_handleLatestScroll);
    _hotScroll.addListener(_handleHotScroll);
    _searchController.text = marketController.keywords.value;
    _marketKeywordWorker = ever<String>(marketController.keywords, (value) {
      if (_searchController.text == value) {
        return;
      }
      _searchController.text = value;
      if (mounted) {
        setState(() {});
      }
    });
    _gameWorker = ever<int>(controller.appId, (_) {
      _resetHomeViewportForGameChange();
    });
  }

  @override
  void dispose() {
    _latestScroll.removeListener(_handleLatestScroll);
    _hotScroll.removeListener(_handleHotScroll);
    _tabController.dispose();
    _latestScroll.dispose();
    _hotScroll.dispose();
    _gameWorker?.dispose();
    _marketKeywordWorker?.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _jumpScrollToTop(ScrollController scrollController) {
    if (!scrollController.hasClients) {
      return;
    }
    final minExtent = scrollController.position.minScrollExtent;
    if (scrollController.position.pixels == minExtent) {
      return;
    }
    scrollController.jumpTo(minExtent);
  }

  void _resetHomeViewportForGameChange() {
    _jumpScrollToTop(_latestScroll);
    _jumpScrollToTop(_hotScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _jumpScrollToTop(_latestScroll);
      _jumpScrollToTop(_hotScroll);
    });
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
    final result = await MarketFilterSheet.showFromRight(
      context: context,
      appId: controller.appId.value,
      sortOptions: [
        SortOption(labelKey: 'app.market.filter.price', field: 'price'),
        SortOption(labelKey: 'app.market.filter.hot', field: 'hot'),
      ],
      showSort: !isTf2,
      showAttributeFilters: !isTf2,
      initial: MarketFilterResult(
        sortField: marketController.sortField.value,
        sortAsc: marketController.sortField.value.isEmpty
            ? false
            : marketController.sortAsc.value,
        priceMin: marketController.priceMin.value,
        priceMax: marketController.priceMax.value,
        tags: isTf2
            ? const <String, dynamic>{}
            : Map<String, dynamic>.from(marketController.tags),
        itemName: isTf2 ? null : marketController.itemName.value,
      ),
    );
    if (result == null || !mounted) {
      return;
    }
    final keyword = result.clearKeyword ? '' : _searchController.text.trim();
    if (result.clearKeyword) {
      setState(() => _searchController.clear());
    }
    _switchToMarketWithArgs({
      'keyword': keyword,
      'sortField': result.sortField,
      'sortAsc': result.sortField.isEmpty ? false : result.sortAsc,
      'minPrice': result.priceMin,
      'maxPrice': result.priceMax,
      'tags': result.tags,
      'itemName': result.itemName,
    });
  }

  void _submitSearch({String? keyword}) {
    final searchKeyword = keyword ?? _searchController.text.trim();
    _switchToMarketWithArgs({
      'keyword': searchKeyword,
      'sortField': marketController.sortField.value,
      'sortAsc': marketController.sortField.value.isEmpty
          ? false
          : marketController.sortAsc.value,
      'minPrice': marketController.priceMin.value,
      'maxPrice': marketController.priceMax.value,
      'tags': Map<String, dynamic>.from(marketController.tags),
      'itemName': marketController.itemName.value,
    });
  }

  void _switchToMarketWithArgs(Map<String, dynamic> args) {
    args['appId'] = controller.appId.value;
    _resetHomeViewportForGameChange();
    marketController.requestScrollToTop();
    marketController.applyInitialArgs(args);
    marketController.refresh(reset: true);
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
            Obx(() => _buildHeader()),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  Obx(() {
                    final currentAppId = controller.appId.value;
                    return _buildGrid(
                      'home-latest-$currentAppId',
                      controller.latestItems,
                      controller.isLoadingLatest.value,
                      controller.latestHasMore,
                      _latestScroll,
                      onRefresh: () => controller.fetchLatest(reset: true),
                    );
                  }),
                  Obx(() {
                    final currentAppId = controller.appId.value;
                    return _buildGrid(
                      'home-hot-$currentAppId',
                      controller.hotItems,
                      controller.isLoadingHot.value,
                      controller.hotHasMore,
                      _hotScroll,
                      onRefresh: () => controller.fetchHot(reset: true),
                    );
                  }),
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
        marketController.sortField.value.isNotEmpty ||
        marketController.priceMin.value != null ||
        marketController.priceMax.value != null ||
        marketController.tags.isNotEmpty ||
        (marketController.itemName.value?.isNotEmpty ?? false);

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
                Expanded(child: _buildSearchTrigger()),
                const SizedBox(width: 12),
                _buildGameSwitchTrigger(),
                const SizedBox(width: 8),
                HeaderFilterButton(
                  tooltip: 'app.market.filter.text'.tr,
                  active: hasActiveFilter,
                  onTap: _openFilterSheet,
                ),
              ],
            ),
          ),
          Obx(() {
            final notice = controller.systemNotice.value;
            final visible =
                controller.systemNoticeVisible.value && notice != null;
            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) {
                return SizeTransition(
                  sizeFactor: animation,
                  axisAlignment: -1,
                  child: FadeTransition(opacity: animation, child: child),
                );
              },
              child: visible
                  ? Padding(
                      key: ValueKey<String>(
                        notice.id ?? notice.title ?? 'home-notice',
                      ),
                      padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
                      child: _HomeNoticeBanner(
                        content: _plainNoticeContent(notice.content),
                        onTap: () => _openSystemNotice(notice),
                        onClose: controller.dismissSystemNotice,
                      ),
                    )
                  : const SizedBox.shrink(key: ValueKey('home-notice-empty')),
            );
          }),
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

  void _openSystemNotice(SystemNoticeEntity notice) {
    Get.toNamed(
      Routers.NOTICE_DETAIL,
      arguments: NoticeMessageItem(
        id: notice.id,
        title: notice.title,
        content: notice.content,
        createName: notice.createName,
        createTime: notice.createTime,
        isRead: notice.isRead,
      ),
    );
  }

  String _plainNoticeContent(String? content) {
    final source = content?.trim() ?? '';
    if (source.isEmpty) {
      return '';
    }
    return source
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll('&nbsp;', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
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

class _HomeNoticeBanner extends StatelessWidget {
  const _HomeNoticeBanner({
    required this.content,
    required this.onTap,
    required this.onClose,
  });

  final String content;
  final VoidCallback onTap;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final noticeText = _noticeText;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(3),
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFF36A3FF), Color(0xFF248AF0)],
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(3),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(3),
          child: SizedBox(
            height: 32,
            child: Row(
              children: [
                const SizedBox(width: 9),
                const Icon(
                  Icons.volume_up_outlined,
                  size: 17,
                  color: Colors.white,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _NoticeTickerText(
                    text: noticeText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      height: 1.25,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                _NoticeIconButton(
                  tooltip: 'app.common.close'.tr,
                  onTap: onClose,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String get _noticeText {
    return content;
  }
}

class _NoticeTickerText extends StatefulWidget {
  const _NoticeTickerText({required this.text, required this.style});

  final String text;
  final TextStyle style;

  @override
  State<_NoticeTickerText> createState() => _NoticeTickerTextState();
}

class _NoticeTickerTextState extends State<_NoticeTickerText>
    with SingleTickerProviderStateMixin {
  static const StrutStyle _strutStyle = StrutStyle(
    fontSize: 13,
    height: 1.25,
    forceStrutHeight: true,
  );

  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
  }

  @override
  void didUpdateWidget(covariant _NoticeTickerText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _controller
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportWidth = constraints.maxWidth;
        final textWidth = _measureTextWidth(context);
        if (!viewportWidth.isFinite || textWidth <= viewportWidth) {
          _stopTicker();
          return Text(
            widget.text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            strutStyle: _strutStyle,
            style: widget.style,
          );
        }

        final loopGap = viewportWidth;
        final loopDistance = textWidth + loopGap;
        _startTicker(loopDistance);
        return ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (bounds) {
            return const LinearGradient(
              colors: [
                Colors.transparent,
                Colors.white,
                Colors.white,
                Colors.transparent,
              ],
              stops: [0, 0.03, 0.95, 1],
            ).createShader(bounds);
          },
          child: SizedBox(
            height: 18,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return CustomPaint(
                  size: Size(viewportWidth, 18),
                  painter: _TickerTextPainter(
                    text: widget.text,
                    style: widget.style,
                    strutStyle: _strutStyle,
                    progress: _controller.value,
                    loopDistance: loopDistance,
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _startTicker(double distance) {
    final seconds = (distance / 18).clamp(5.0, 16.0);
    final duration = Duration(milliseconds: (seconds * 1000).round());
    if (_controller.duration != duration) {
      _controller.duration = duration;
    }
    if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  void _stopTicker() {
    if (_controller.isAnimating || _controller.value != 0) {
      _controller
        ..stop()
        ..value = 0;
    }
  }

  double _measureTextWidth(BuildContext context) {
    final painter = TextPainter(
      text: TextSpan(text: widget.text, style: widget.style),
      textDirection: Directionality.of(context),
      maxLines: 1,
      strutStyle: _strutStyle,
    )..layout();
    return painter.width;
  }
}

class _TickerTextPainter extends CustomPainter {
  const _TickerTextPainter({
    required this.text,
    required this.style,
    required this.strutStyle,
    required this.progress,
    required this.loopDistance,
  });

  final String text;
  final TextStyle style;
  final StrutStyle strutStyle;
  final double progress;
  final double loopDistance;

  @override
  void paint(Canvas canvas, Size size) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      strutStyle: strutStyle,
    )..layout();
    final offsetX = -loopDistance * progress;
    final offsetY = (size.height - painter.height) / 2;

    canvas.save();
    canvas.clipRect(Offset.zero & size);
    painter.paint(canvas, Offset(offsetX, offsetY));
    painter.paint(canvas, Offset(offsetX + loopDistance, offsetY));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _TickerTextPainter oldDelegate) {
    return oldDelegate.text != text ||
        oldDelegate.style != style ||
        oldDelegate.progress != progress ||
        oldDelegate.loopDistance != loopDistance;
  }
}

class _NoticeIconButton extends StatelessWidget {
  const _NoticeIconButton({required this.tooltip, required this.onTap});

  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkResponse(
          onTap: onTap,
          radius: 15,
          highlightShape: BoxShape.circle,
          child: SizedBox(
            width: 30,
            height: 32,
            child: Icon(
              Icons.close_rounded,
              size: 17,
              color: Colors.white.withValues(alpha: 0.82),
            ),
          ),
        ),
      ),
    );
  }
}
