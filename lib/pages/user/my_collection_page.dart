import 'package:flutter/material.dart';
import 'package:tronskins_app/common/widgets/settings_style_app_bar.dart';
import 'package:get/get.dart';
import 'package:tronskins_app/api/market.dart';
import 'package:tronskins_app/api/model/market/market_models.dart';
import 'package:tronskins_app/api/model/user/collection_models.dart';
import 'package:tronskins_app/api/shop_product.dart';
import 'package:tronskins_app/common/hooks/currency/CurrencyController.dart';
import 'package:tronskins_app/common/hooks/game/global_game_controller.dart';
import 'package:tronskins_app/common/utils/app_snackbar.dart';
import 'package:tronskins_app/common/widgets/back_to_top_overlay.dart';
import 'package:tronskins_app/common/widgets/login_required_prompt.dart';
import 'package:tronskins_app/components/filter/filter_models.dart';
import 'package:tronskins_app/components/filter/market_filter_sheet.dart';
import 'package:tronskins_app/components/game_item/game_item_image.dart';
import 'package:tronskins_app/components/game_item/game_item_models.dart';
import 'package:tronskins_app/components/game_item/game_item_utils.dart';
import 'package:tronskins_app/components/game_item/wear_progress_bar.dart';
import 'package:tronskins_app/components/layout/list_end_tip.dart';
import 'package:tronskins_app/controllers/user/user_controller.dart';
import 'package:tronskins_app/routes/app_routes.dart';

String _collectionText({required String zh, required String en}) {
  final languageCode = Get.locale?.languageCode.toLowerCase();
  return languageCode == 'zh' ? zh : en;
}

String _collectionTitle(String? marketHashName, String? marketName) {
  final title = marketHashName?.trim() ?? '';
  if (title.isNotEmpty) {
    return title;
  }
  final fallback = marketName?.trim() ?? '';
  return fallback.isNotEmpty ? fallback : '--';
}

String _formatCollectionPrice(double? price) {
  if (price == null) {
    return '--';
  }
  try {
    return CurrencyController.to.format(price);
  } catch (_) {
    return '\$ ${price.toStringAsFixed(2)}';
  }
}

double? _parsePaintWear(String? value) {
  if (value == null || value.isEmpty) {
    return null;
  }
  return double.tryParse(value);
}

enum _CollectionVisualMode { category, single }

enum _CollectionSortChoice {
  defaultOrder,
  priceAsc,
  priceDesc;

  String get sortField {
    switch (this) {
      case _CollectionSortChoice.defaultOrder:
        return '';
      case _CollectionSortChoice.priceAsc:
      case _CollectionSortChoice.priceDesc:
        return 'price';
    }
  }

  bool get sortAsc {
    switch (this) {
      case _CollectionSortChoice.defaultOrder:
        return false;
      case _CollectionSortChoice.priceAsc:
        return true;
      case _CollectionSortChoice.priceDesc:
        return false;
    }
  }

  String get label {
    switch (this) {
      case _CollectionSortChoice.defaultOrder:
        return _collectionText(zh: '默认排序', en: 'Default');
      case _CollectionSortChoice.priceAsc:
        return _collectionText(zh: '价格从低到高', en: 'Price Low to High');
      case _CollectionSortChoice.priceDesc:
        return _collectionText(zh: '价格从高到低', en: 'Price High to Low');
    }
  }

  static _CollectionSortChoice fromFilter({
    required String field,
    required bool asc,
  }) {
    if (field == 'price') {
      return asc
          ? _CollectionSortChoice.priceAsc
          : _CollectionSortChoice.priceDesc;
    }
    return _CollectionSortChoice.defaultOrder;
  }
}

class _CollectionGameOption {
  const _CollectionGameOption({
    required this.appId,
    required this.label,
    required this.subtitle,
    required this.icon,
  });

  final int appId;
  final String label;
  final String subtitle;
  final IconData icon;
}

const List<_CollectionGameOption> _collectionGameOptions =
    <_CollectionGameOption>[
      _CollectionGameOption(
        appId: 730,
        label: 'CS2',
        subtitle: 'Counter-Strike 2',
        icon: Icons.sports_esports_outlined,
      ),
      _CollectionGameOption(
        appId: 570,
        label: 'DOTA2',
        subtitle: 'Defense of the Ancients',
        icon: Icons.auto_awesome_outlined,
      ),
      _CollectionGameOption(
        appId: 440,
        label: 'TF2',
        subtitle: 'Team Fortress 2',
        icon: Icons.extension_outlined,
      ),
    ];

class _CollectionAccessoryPreviewData {
  const _CollectionAccessoryPreviewData({
    required this.imageUrl,
    this.borderColor,
  });

  final String imageUrl;
  final Color? borderColor;
}

class MyCollectionPage extends StatefulWidget {
  const MyCollectionPage({super.key});

  @override
  State<MyCollectionPage> createState() => _MyCollectionPageState();
}

class _MyCollectionPageState extends State<MyCollectionPage>
    with SingleTickerProviderStateMixin {
  final UserController _userController = Get.find<UserController>();
  final GlobalGameController _globalGameController =
      GlobalGameController.ensureInstance();
  late final TabController _tabController;
  final _categoryTabKey = GlobalKey<_CollectionCategoryTabState>();
  final _favoriteTabKey = GlobalKey<_CollectionFavoriteTabState>();
  final _categoryControls = _CollectionTabControls();
  final _favoriteControls = _CollectionTabControls();
  late int _appId;
  int _currentTabIndex = 0;
  Worker? _gameWorker;

  @override
  void initState() {
    super.initState();
    _appId = _globalGameController.appId;
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabChange);
    _gameWorker = ever<int>(_globalGameController.currentAppId, (appId) {
      if (!mounted || appId == _appId) {
        return;
      }
      setState(() => _appId = appId);
    });
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    _gameWorker?.dispose();
    _categoryControls.dispose();
    _favoriteControls.dispose();
    super.dispose();
  }

  bool get _isCategoryTab => _currentTabIndex == 0;

  _CollectionTabControls get _activeControls =>
      _isCategoryTab ? _categoryControls : _favoriteControls;

  _CollectionTabHandle? get _activeTabHandle => _isCategoryTab
      ? _categoryTabKey.currentState
      : _favoriteTabKey.currentState;

  void _handleTabChange() {
    final nextIndex = _tabController.index;
    if (!mounted || _currentTabIndex == nextIndex) {
      return;
    }
    setState(() => _currentTabIndex = nextIndex);
  }

  void _handleTopBarChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _submitActiveSearch([String? value]) async {
    await _activeTabHandle?.submitSearch(value);
    _handleTopBarChanged();
  }

  Future<void> _openActiveFilterSheet() async {
    await _activeTabHandle?.openFilter(_appId);
    _handleTopBarChanged();
  }

  void _switchTab(int index) {
    if (_currentTabIndex == index) {
      return;
    }
    _tabController.animateTo(
      index,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _applyActiveSort({
    required String sortField,
    required bool sortAsc,
  }) async {
    await _activeTabHandle?.applyQuickSort(
      sortField: sortField,
      sortAsc: sortAsc,
    );
    _handleTopBarChanged();
  }

  Future<void> _resetActiveFilters() async {
    await _activeTabHandle?.resetFilters();
    _handleTopBarChanged();
  }

  Future<void> _openActiveSearchDialog() async {
    final initialKeyword = _activeTabHandle?.currentKeyword ?? '';
    final textController = TextEditingController(text: initialKeyword);
    final submitted = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        final colors = Theme.of(dialogContext).colorScheme;
        return AlertDialog(
          title: Text(_collectionText(zh: '搜索收藏', en: 'Search Collection')),
          content: TextField(
            controller: textController,
            autofocus: true,
            textInputAction: TextInputAction.search,
            onSubmitted: (value) =>
                Navigator.of(dialogContext).pop(value.trim()),
            decoration: InputDecoration(
              hintText: 'app.market.filter.search'.tr,
              filled: true,
              fillColor: colors.surfaceContainerHighest,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text('app.common.cancel'.tr),
            ),
            if (initialKeyword.trim().isNotEmpty)
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(''),
                child: Text('app.market.filter.clear'.tr),
              ),
            TextButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(textController.text.trim()),
              child: Text('app.market.filter.search'.tr),
            ),
          ],
        );
      },
    );
    textController.dispose();
    if (submitted == null) {
      return;
    }
    _activeControls.searchController.text = submitted;
    await _submitActiveSearch(submitted);
  }

  Future<void> _openCollectionActions() async {
    final handle = _activeTabHandle;
    if (handle == null) {
      return;
    }
    final currentSortField = handle.currentFilter.sortField;
    final currentSortAsc = handle.currentFilter.sortAsc;
    final currentKeyword = handle.currentKeyword.trim();
    final hasActiveFilter = handle.hasActiveFilter;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return _CollectionActionSheet(
          currentAppId: _appId,
          currentKeyword: currentKeyword,
          hasActiveFilter: hasActiveFilter,
          selectedSort: _CollectionSortChoice.fromFilter(
            field: currentSortField,
            asc: currentSortAsc,
          ),
          onSelectGame: (appId) async {
            Navigator.of(sheetContext).pop();
            if (appId == _appId) {
              return;
            }
            await _globalGameController.switchGame(appId);
          },
          onSearch: () async {
            Navigator.of(sheetContext).pop();
            await _openActiveSearchDialog();
          },
          onSortSelected: (choice) async {
            Navigator.of(sheetContext).pop();
            await _applyActiveSort(
              sortField: choice.sortField,
              sortAsc: choice.sortAsc,
            );
          },
          onAdvancedFilter: () async {
            Navigator.of(sheetContext).pop();
            await _openActiveFilterSheet();
          },
          onReset: hasActiveFilter
              ? () async {
                  Navigator.of(sheetContext).pop();
                  await _resetActiveFilters();
                }
              : null,
        );
      },
    );
  }

  Widget _buildLoginPrompt() {
    return const LoginRequiredPrompt();
  }

  Widget _buildTopSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Row(
        children: [
          _CollectionTabPill(
            label: 'app.user.collection.category'.tr,
            icon: Icons.widgets_outlined,
            active: _isCategoryTab,
            onTap: () => _switchTab(0),
          ),
          const SizedBox(width: 12),
          _CollectionTabPill(
            label: 'app.user.collection.single'.tr,
            icon: Icons.bookmarks_outlined,
            active: !_isCategoryTab,
            onTap: () => _switchTab(1),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final loggedIn = _userController.isLoggedIn.value;
      return BackToTopScope(
        enabled: false,
        child: Scaffold(
          backgroundColor: const Color(0xFFF7F9FB),
          appBar: SettingsStyleAppBar(
            title: Text('app.user.menu.collection'.tr),
            actions: loggedIn
                ? [
                    IconButton(
                      onPressed: _openCollectionActions,
                      icon: _CollectionOverflowIcon(
                        highlighted: _activeControls.hasActiveFilter,
                      ),
                    ),
                  ]
                : const [],
          ),
          body: loggedIn
              ? Column(
                  children: [
                    _buildTopSection(),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _CollectionCategoryTab(
                            key: _categoryTabKey,
                            appId: _appId,
                            controls: _categoryControls,
                            onControlsChanged: _handleTopBarChanged,
                          ),
                          _CollectionFavoriteTab(
                            key: _favoriteTabKey,
                            appId: _appId,
                            controls: _favoriteControls,
                            onControlsChanged: _handleTopBarChanged,
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              : _buildLoginPrompt(),
        ),
      );
    });
  }
}

class _CollectionTabControls {
  final TextEditingController searchController = TextEditingController();
  MarketFilterResult filter = const MarketFilterResult(
    sortField: '',
    sortAsc: false,
  );
  String keyword = '';

  bool get hasActiveFilter {
    return keyword.trim().isNotEmpty ||
        (filter.tags?.isNotEmpty ?? false) ||
        (filter.itemName?.isNotEmpty ?? false) ||
        filter.priceMin != null ||
        filter.priceMax != null ||
        filter.sortField.isNotEmpty;
  }

  void dispose() {
    searchController.dispose();
  }
}

abstract class _CollectionTabHandle {
  TextEditingController get searchController;
  bool get hasActiveFilter;
  MarketFilterResult get currentFilter;
  String get currentKeyword;
  Future<void> submitSearch([String? value]);
  Future<void> clearSearch();
  Future<void> applyQuickSort({
    required String sortField,
    required bool sortAsc,
  });
  Future<void> resetFilters();
  Future<void> openFilter(int appId);
}

abstract class _BaseCollectionTabState<T extends StatefulWidget>
    extends State<T>
    with AutomaticKeepAliveClientMixin
    implements _CollectionTabHandle {
  final ScrollController scrollController = ScrollController();
  final List<SortOption> sortOptions = const <SortOption>[
    SortOption(labelKey: 'app.market.filter.price', field: 'price'),
  ];
  bool loading = false;
  bool loadingMore = false;
  int page = 1;
  int total = 0;

  _CollectionTabControls get controls;

  VoidCallback? get onControlsChangedCallback;

  bool get hasMore => itemsLength < total;

  int get itemsLength;

  @override
  TextEditingController get searchController => controls.searchController;

  MarketFilterResult get filter => controls.filter;

  set filter(MarketFilterResult value) => controls.filter = value;

  String get keyword => controls.keyword;

  set keyword(String value) => controls.keyword = value;

  @override
  bool get hasActiveFilter => controls.hasActiveFilter;

  @override
  MarketFilterResult get currentFilter => filter;

  @override
  String get currentKeyword => keyword;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    scrollController.addListener(handleScroll);
  }

  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }

  void resetScrollPositionForGameChange() {
    if (scrollController.hasClients) {
      final minExtent = scrollController.position.minScrollExtent;
      if (scrollController.position.pixels != minExtent) {
        scrollController.jumpTo(minExtent);
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !scrollController.hasClients) {
        return;
      }
      final minExtent = scrollController.position.minScrollExtent;
      if (scrollController.position.pixels != minExtent) {
        scrollController.jumpTo(minExtent);
      }
    });
  }

  void handleScroll() {
    if (!scrollController.hasClients || loading || loadingMore) {
      return;
    }
    final position = scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 160 && hasMore) {
      loadData();
    }
  }

  Future<void> loadData({bool refresh = false});

  void notifyControlsChanged() {
    onControlsChangedCallback?.call();
  }

  @override
  Future<void> submitSearch([String? value]) async {
    final nextKeyword = (value ?? searchController.text).trim();
    keyword = nextKeyword;
    notifyControlsChanged();
    await loadData(refresh: true);
  }

  @override
  Future<void> clearSearch() => submitSearch('');

  @override
  Future<void> applyQuickSort({
    required String sortField,
    required bool sortAsc,
  }) async {
    filter = MarketFilterResult(
      sortField: sortField,
      sortAsc: sortAsc,
      priceMin: filter.priceMin,
      priceMax: filter.priceMax,
      tags: filter.tags,
      itemName: filter.itemName,
      statusList: filter.statusList,
      startDate: filter.startDate,
      endDate: filter.endDate,
    );
    notifyControlsChanged();
    await loadData(refresh: true);
  }

  @override
  Future<void> resetFilters() async {
    keyword = '';
    searchController.clear();
    filter = const MarketFilterResult(sortField: '', sortAsc: false);
    notifyControlsChanged();
    await loadData(refresh: true);
  }

  @override
  Future<void> openFilter(int appId) async {
    final result = await MarketFilterSheet.showFromRight(
      context: context,
      appId: appId,
      sortOptions: sortOptions,
      initial: filter,
      showPriceRange: true,
      showSort: false,
    );
    if (result == null) {
      return;
    }
    filter = result;
    if (result.clearKeyword) {
      searchController.clear();
      keyword = '';
    }
    notifyControlsChanged();
    await loadData(refresh: true);
  }
}

class _CollectionCategoryTab extends StatefulWidget {
  const _CollectionCategoryTab({
    super.key,
    required this.appId,
    required this.controls,
    this.onControlsChanged,
  });

  final int appId;
  final _CollectionTabControls controls;
  final VoidCallback? onControlsChanged;

  @override
  State<_CollectionCategoryTab> createState() => _CollectionCategoryTabState();
}

class _CollectionFavoriteTab extends StatefulWidget {
  const _CollectionFavoriteTab({
    super.key,
    required this.appId,
    required this.controls,
    this.onControlsChanged,
  });

  final int appId;
  final _CollectionTabControls controls;
  final VoidCallback? onControlsChanged;

  @override
  State<_CollectionFavoriteTab> createState() => _CollectionFavoriteTabState();
}

class _CollectionCategoryTabState
    extends _BaseCollectionTabState<_CollectionCategoryTab> {
  final ApiShopProductServer _api = ApiShopProductServer();
  final List<CollectionTemplateItem> _items = <CollectionTemplateItem>[];

  @override
  _CollectionTabControls get controls => widget.controls;

  @override
  VoidCallback? get onControlsChangedCallback => widget.onControlsChanged;

  @override
  int get itemsLength => _items.length;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      loadData(refresh: true);
    });
  }

  @override
  void didUpdateWidget(covariant _CollectionCategoryTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.appId != widget.appId) {
      filter = const MarketFilterResult(sortField: '', sortAsc: false);
      keyword = '';
      searchController.clear();
      resetScrollPositionForGameChange();
      notifyControlsChanged();
      loadData(refresh: true);
    }
  }

  @override
  Future<void> loadData({bool refresh = false}) async {
    if (loading || loadingMore) {
      return;
    }
    final nextPage = refresh ? 1 : page + 1;
    if (!refresh && !hasMore) {
      return;
    }
    setState(() {
      if (refresh) {
        loading = true;
      } else {
        loadingMore = true;
      }
    });
    try {
      final res = await _api.productCollectList(
        params:
            <String, dynamic>{
              'appId': widget.appId,
              'page': nextPage,
              'pageSize': 20,
              'field': filter.sortField,
              'asc': filter.sortField.isEmpty ? null : filter.sortAsc,
              'keywords': keyword.trim(),
              'tags': filter.tags,
              'itemName': filter.itemName,
              'minPrice': filter.priceMin,
              'maxPrice': filter.priceMax,
            }..removeWhere(
              (key, value) =>
                  value == null ||
                  value == '' ||
                  (value is Map && value.isEmpty),
            ),
      );
      if (!mounted) {
        return;
      }
      if (!res.success || res.datas == null) {
        AppSnackbar.error(
          res.message.isNotEmpty ? res.message : 'app.trade.filter.failed'.tr,
        );
        return;
      }
      final payload = res.datas!;
      setState(() {
        page = nextPage;
        total = payload.pager?.total ?? payload.items.length;
        if (refresh) {
          _items
            ..clear()
            ..addAll(payload.items);
        } else {
          _items.addAll(payload.items);
        }
      });
    } catch (_) {
      if (mounted) {
        AppSnackbar.error('app.trade.filter.failed'.tr);
      }
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
          loadingMore = false;
        });
      }
    }
  }

  Future<void> _openDetail(CollectionTemplateItem item) async {
    await Get.toNamed(
      Routers.MARKET_DETAIL,
      arguments: item.toMarketItemEntity(),
    );
    if (!mounted) {
      return;
    }
    await loadData(refresh: true);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final showSuggestions = !hasMore && !loadingMore && _items.isNotEmpty;
    return BackToTopScope(
      enabled: true,
      child: loading
          ? const _CollectionLoadingState(mode: _CollectionVisualMode.category)
          : RefreshIndicator(
              onRefresh: () => loadData(refresh: true),
              child: _items.isEmpty
                  ? const _CollectionEmptyState()
                  : ListView(
                      controller: scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
                      children: [
                        for (var i = 0; i < _items.length; i++) ...[
                          _CollectionCategoryCard(
                            item: _items[i],
                            onTap: () => _openDetail(_items[i]),
                          ),
                          if (i != _items.length - 1)
                            const SizedBox(height: 16),
                        ],
                        if (showSuggestions) ...[
                          const SizedBox(height: 28),
                          const _CollectionSuggestionSection(),
                        ],
                        const SizedBox(height: 10),
                        _CollectionFooter(
                          showLoading: loadingMore,
                          showNoMore: !hasMore,
                        ),
                      ],
                    ),
            ),
    );
  }
}

class _CollectionFavoriteTabState
    extends _BaseCollectionTabState<_CollectionFavoriteTab> {
  final ApiMarketServer _marketApi = ApiMarketServer();
  final ApiShopProductServer _api = ApiShopProductServer();
  final List<CollectionFavoriteItem> _items = <CollectionFavoriteItem>[];

  @override
  _CollectionTabControls get controls => widget.controls;

  @override
  VoidCallback? get onControlsChangedCallback => widget.onControlsChanged;

  @override
  int get itemsLength => _items.length;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      loadData(refresh: true);
    });
  }

  @override
  void didUpdateWidget(covariant _CollectionFavoriteTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.appId != widget.appId) {
      filter = const MarketFilterResult(sortField: '', sortAsc: false);
      keyword = '';
      searchController.clear();
      resetScrollPositionForGameChange();
      notifyControlsChanged();
      loadData(refresh: true);
    }
  }

  @override
  Future<void> loadData({bool refresh = false}) async {
    if (loading || loadingMore) {
      return;
    }
    final nextPage = refresh ? 1 : page + 1;
    if (!refresh && !hasMore) {
      return;
    }
    setState(() {
      if (refresh) {
        loading = true;
      } else {
        loadingMore = true;
      }
    });
    try {
      final res = await _api.productFavoriteList(
        params:
            <String, dynamic>{
              'appId': widget.appId,
              'page': nextPage,
              'pageSize': 20,
              'field': filter.sortField,
              'asc': filter.sortField.isEmpty ? null : filter.sortAsc,
              'keywords': keyword.trim(),
              'tags': filter.tags,
              'itemName': filter.itemName,
              'minPrice': filter.priceMin,
              'maxPrice': filter.priceMax,
            }..removeWhere(
              (key, value) =>
                  value == null ||
                  value == '' ||
                  (value is Map && value.isEmpty),
            ),
      );
      if (!mounted) {
        return;
      }
      if (!res.success || res.datas == null) {
        AppSnackbar.error(
          res.message.isNotEmpty ? res.message : 'app.trade.filter.failed'.tr,
        );
        return;
      }
      final payload = res.datas!;
      setState(() {
        page = nextPage;
        total = payload.pager?.total ?? payload.items.length;
        if (refresh) {
          _items
            ..clear()
            ..addAll(payload.items);
        } else {
          _items.addAll(payload.items);
        }
      });
    } catch (_) {
      if (mounted) {
        AppSnackbar.error('app.trade.filter.failed'.tr);
      }
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
          loadingMore = false;
        });
      }
    }
  }

  Future<void> _openDetail(CollectionFavoriteItem item) async {
    await Get.toNamed(
      Routers.MARKET_DETAIL,
      arguments: item.toMarketItemEntity(),
    );
    if (!mounted) {
      return;
    }
    await loadData(refresh: true);
  }

  Future<void> _cancelFavorite(CollectionFavoriteItem item) async {
    final itemId = item.itemId;
    if (itemId == null) {
      AppSnackbar.error('app.trade.filter.failed'.tr);
      return;
    }
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: Text('app.system.tips.title'.tr),
        content: Text('app.user.collection.uncollect_tips'.tr),
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
    if (confirmed != true) {
      return;
    }
    try {
      final res = await _marketApi.removeFavorite(itemId: itemId);
      if (!res.success) {
        AppSnackbar.error(
          res.message.isNotEmpty ? res.message : 'app.trade.filter.failed'.tr,
        );
        return;
      }
      AppSnackbar.success('app.user.collection.uncollect_success'.tr);
      await loadData(refresh: true);
    } catch (_) {
      AppSnackbar.error('app.trade.filter.failed'.tr);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final showSuggestions = !hasMore && !loadingMore && _items.isNotEmpty;
    return BackToTopScope(
      enabled: true,
      child: loading
          ? const _CollectionLoadingState(mode: _CollectionVisualMode.single)
          : RefreshIndicator(
              onRefresh: () => loadData(refresh: true),
              child: _items.isEmpty
                  ? const _CollectionEmptyState()
                  : ListView(
                      controller: scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
                      children: [
                        for (var i = 0; i < _items.length; i++) ...[
                          _CollectionFavoriteCard(
                            item: _items[i],
                            onTap: () => _openDetail(_items[i]),
                            onCancel: () => _cancelFavorite(_items[i]),
                          ),
                          if (i != _items.length - 1)
                            const SizedBox(height: 16),
                        ],
                        if (showSuggestions) ...[
                          const SizedBox(height: 28),
                          const _CollectionSuggestionSection(),
                        ],
                        const SizedBox(height: 10),
                        _CollectionFooter(
                          showLoading: loadingMore,
                          showNoMore: !hasMore,
                        ),
                      ],
                    ),
            ),
    );
  }
}

BoxDecoration _collectionCardDecoration({
  Color color = Colors.white,
  double radius = 28,
}) {
  return BoxDecoration(
    color: color,
    borderRadius: BorderRadius.circular(radius),
    boxShadow: const [
      BoxShadow(
        color: Color(0x120F172A),
        blurRadius: 28,
        offset: Offset(0, 12),
      ),
    ],
  );
}

MarketItemTags? _favoriteItemTags(CollectionFavoriteItem item) {
  if (item.tags != null) {
    return item.tags;
  }
  final rawTags = item.asset?['tags'];
  if (rawTags is Map<String, dynamic>) {
    return MarketItemTags.fromJson(rawTags);
  }
  if (rawTags is Map) {
    return MarketItemTags.fromJson(Map<String, dynamic>.from(rawTags));
  }
  return null;
}

List<_CollectionAccessoryPreviewData> _favoriteAccessoryItems(
  CollectionFavoriteItem item,
) {
  final stickers = <GameItemSticker>[
    ...parseStickerList(item.stickerRaw),
    ...parseStickerList(item.keychainRaw),
  ];
  final gems = parseGemList(item.gemRaw);
  return [
    for (final sticker in stickers)
      _CollectionAccessoryPreviewData(imageUrl: sticker.imageUrl),
    for (final gem in gems)
      _CollectionAccessoryPreviewData(
        imageUrl: gem.imageUrl,
        borderColor: gem.borderColor,
      ),
  ];
}

class _CollectionOverflowIcon extends StatelessWidget {
  const _CollectionOverflowIcon({required this.highlighted});

  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final color = highlighted
        ? const Color(0xFF2563EB)
        : const Color(0xFF475569);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: highlighted ? const Color(0xFFE8F0FF) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F0F172A),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Icon(Icons.more_vert_rounded, color: color, size: 20),
    );
  }
}

class _CollectionTabPill extends StatelessWidget {
  const _CollectionTabPill({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: active ? Colors.white : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(22),
              boxShadow: active
                  ? const [
                      BoxShadow(
                        color: Color(0x140F172A),
                        blurRadius: 22,
                        offset: Offset(0, 10),
                      ),
                    ]
                  : const [],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: active
                      ? const Color(0xFF1D4ED8)
                      : const Color(0xFF64748B),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: active
                          ? const Color(0xFF0F172A)
                          : const Color(0xFF64748B),
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
}

class _CollectionActionSheet extends StatelessWidget {
  const _CollectionActionSheet({
    required this.currentAppId,
    required this.currentKeyword,
    required this.hasActiveFilter,
    required this.selectedSort,
    required this.onSelectGame,
    required this.onSearch,
    required this.onSortSelected,
    required this.onAdvancedFilter,
    this.onReset,
  });

  final int currentAppId;
  final String currentKeyword;
  final bool hasActiveFilter;
  final _CollectionSortChoice selectedSort;
  final ValueChanged<int> onSelectGame;
  final VoidCallback onSearch;
  final ValueChanged<_CollectionSortChoice> onSortSelected;
  final VoidCallback onAdvancedFilter;
  final VoidCallback? onReset;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A0F172A),
              blurRadius: 40,
              offset: Offset(0, -8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD7E1EC),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                _collectionText(zh: '收藏筛选', en: 'Collection Tools'),
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _collectionText(
                  zh: '切换游戏、快速排序，或打开高级筛选',
                  en: 'Switch games, sort quickly, or open advanced filters',
                ),
                style: textTheme.bodyMedium?.copyWith(
                  height: 1.45,
                  color: const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 20),
              _CollectionActionPanel(
                icon: Icons.search_rounded,
                title: _collectionText(zh: '搜索收藏', en: 'Search Collection'),
                subtitle: currentKeyword.isNotEmpty
                    ? currentKeyword
                    : _collectionText(
                        zh: '按名称或关键词快速查找',
                        en: 'Search by name or keyword',
                      ),
                onTap: onSearch,
              ),
              const SizedBox(height: 14),
              Text(
                _collectionText(zh: '游戏', en: 'Game'),
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF334155),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final option in _collectionGameOptions)
                    _CollectionSelectableChip(
                      selected: option.appId == currentAppId,
                      leading: Icon(
                        option.icon,
                        size: 16,
                        color: option.appId == currentAppId
                            ? const Color(0xFF1D4ED8)
                            : const Color(0xFF64748B),
                      ),
                      label: option.label,
                      subtitle: option.subtitle,
                      onTap: () => onSelectGame(option.appId),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                _collectionText(zh: '价格排序', en: 'Price Sort'),
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF334155),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final choice in _CollectionSortChoice.values)
                    _CollectionSelectableChip(
                      selected: choice == selectedSort,
                      label: choice.label,
                      subtitle: choice == _CollectionSortChoice.defaultOrder
                          ? _collectionText(
                              zh: '恢复默认列表顺序',
                              en: 'Restore the default order',
                            )
                          : _collectionText(
                              zh: '参考网页端的价格筛选逻辑',
                              en: 'Match the web collection price sort',
                            ),
                      onTap: () => onSortSelected(choice),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              _CollectionActionPanel(
                icon: Icons.tune_rounded,
                title: _collectionText(zh: '高级筛选', en: 'Advanced Filter'),
                subtitle: hasActiveFilter
                    ? _collectionText(
                        zh: '当前已应用筛选条件，点击继续调整',
                        en: 'Filters are active, tap to refine them',
                      )
                    : _collectionText(
                        zh: '按属性、价格区间等条件筛选',
                        en: 'Filter by attributes, price range, and more',
                      ),
                onTap: onAdvancedFilter,
              ),
              if (onReset != null) ...[
                const SizedBox(height: 12),
                _CollectionActionPanel(
                  icon: Icons.restart_alt_rounded,
                  title: _collectionText(zh: '清空条件', en: 'Reset Filters'),
                  subtitle: _collectionText(
                    zh: '移除当前搜索词和筛选条件',
                    en: 'Clear the current search and filter settings',
                  ),
                  onTap: onReset!,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CollectionActionPanel extends StatelessWidget {
  const _CollectionActionPanel({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          decoration: _collectionCardDecoration(
            color: Colors.white.withValues(alpha: 0.9),
            radius: 22,
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F0FF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: const Color(0xFF1D4ED8), size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF64748B),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: Color(0xFF94A3B8),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CollectionSelectableChip extends StatelessWidget {
  const _CollectionSelectableChip({
    required this.selected,
    required this.label,
    required this.subtitle,
    required this.onTap,
    this.leading,
  });

  final bool selected;
  final String label;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          constraints: const BoxConstraints(minWidth: 124),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFEAF1FF) : Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (leading != null) ...[leading!, const SizedBox(width: 6)],
                  Flexible(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: selected
                            ? const Color(0xFF1D4ED8)
                            : const Color(0xFF0F172A),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: selected
                      ? const Color(0xFF45658D)
                      : const Color(0xFF64748B),
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CollectionCategoryCard extends StatelessWidget {
  const _CollectionCategoryCard({required this.item, required this.onTap});

  final CollectionTemplateItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = _collectionTitle(item.marketHashName, item.marketName);
    final tags = item.tags;
    final rarityColor =
        parseHexColor(tags?.rarity?.color) ?? const Color(0xFF3B82F6);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: _collectionCardDecoration(),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: SizedBox(
                      width: 96,
                      height: 96,
                      child: GameItemImage(
                        imageUrl: item.imageUrl,
                        appId: item.appId,
                        quality: TagInfo.fromMarketTag(tags?.quality),
                        rarity: TagInfo.fromMarketTag(tags?.rarity),
                        exterior: TagInfo.fromMarketTag(tags?.exterior),
                        showTopBadges: false,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 9,
                    right: 9,
                    child: _CollectionRarityDot(color: rarityColor),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _CollectionPriceMetric(
                            label: _collectionText(zh: '在售价', en: 'Sale'),
                            value: _formatCollectionPrice(item.sellMinPrice),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _CollectionPriceMetric(
                            label: _collectionText(zh: '求购价', en: 'Demand'),
                            value: _formatCollectionPrice(item.buyMaxPrice),
                          ),
                        ),
                      ],
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

class _CollectionFavoriteCard extends StatelessWidget {
  const _CollectionFavoriteCard({
    required this.item,
    required this.onTap,
    required this.onCancel,
  });

  final CollectionFavoriteItem item;
  final VoidCallback onTap;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final tags = _favoriteItemTags(item);
    final title = _collectionTitle(item.marketHashName, item.marketName);
    final rarityColor =
        parseHexColor(tags?.rarity?.color) ?? const Color(0xFF3B82F6);
    final wear = _parsePaintWear(item.paintWear);
    final accessories = _favoriteAccessoryItems(item);
    final exteriorColor = parseHexColor(tags?.exterior?.color);
    final statusLabel = (item.statusName ?? '').trim();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: _collectionCardDecoration(),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: SizedBox(
                      width: 96,
                      height: 96,
                      child: GameItemImage(
                        imageUrl: item.imageUrl,
                        appId: item.appId,
                        quality: TagInfo.fromMarketTag(tags?.quality),
                        rarity: TagInfo.fromMarketTag(tags?.rarity),
                        exterior: TagInfo.fromMarketTag(tags?.exterior),
                        compactTopLeftBadges: true,
                        avoidTopLeftBadgeOverlap: true,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 9,
                    right: 9,
                    child: _CollectionRarityDot(color: rarityColor),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
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
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF0F172A),
                                  height: 1.28,
                                ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              _formatCollectionPrice(item.price),
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF0F172A),
                                  ),
                            ),
                            const SizedBox(height: 6),
                            _CollectionTextAction(
                              label: 'app.user.collection.uncollect'.tr,
                              onTap: onCancel,
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (item.hasStatusTag && statusLabel.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      _CollectionStatusBadge(label: statusLabel),
                    ],
                    if (wear != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF2F6FA),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  _collectionText(zh: '磨损度', en: 'Wear'),
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF64748B),
                                      ),
                                ),
                                const Spacer(),
                                Text(
                                  wear.toStringAsFixed(4),
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF0F172A),
                                      ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            WearProgressBar(
                              paintWear: wear,
                              height: 10,
                              style: WearProgressBarStyle.figmaCompact,
                              accentColor: exteriorColor,
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (accessories.isNotEmpty) ...[
                      SizedBox(height: wear != null ? 8 : 10),
                      _CollectionAccessoryPreviewRow(items: accessories),
                    ],
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

class _CollectionPriceMetric extends StatelessWidget {
  const _CollectionPriceMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F6FA),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: const Color(0xFF64748B),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }
}

class _CollectionTextAction extends StatelessWidget {
  const _CollectionTextAction({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        padding: EdgeInsets.zero,
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        foregroundColor: const Color(0xFF64748B),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: const Color(0xFF64748B),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _CollectionAccessoryPreviewRow extends StatelessWidget {
  const _CollectionAccessoryPreviewRow({required this.items});

  final List<_CollectionAccessoryPreviewData> items;

  @override
  Widget build(BuildContext context) {
    final visibleItems = items.take(4).toList(growable: false);
    final overflow = items.length - visibleItems.length;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final item in visibleItems)
          _CollectionAccessoryPreviewTile(item: item),
        if (overflow > 0) _CollectionAccessoryOverflowTile(count: overflow),
      ],
    );
  }
}

class _CollectionAccessoryPreviewTile extends StatelessWidget {
  const _CollectionAccessoryPreviewTile({required this.item});

  final _CollectionAccessoryPreviewData item;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F6FA),
        borderRadius: BorderRadius.circular(10),
        border: item.borderColor == null
            ? null
            : Border.all(color: item.borderColor!, width: 1.2),
      ),
      child: Image.network(
        item.imageUrl,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return const Icon(
            Icons.auto_awesome_rounded,
            size: 14,
            color: Color(0xFF94A3B8),
          );
        },
      ),
    );
  }
}

class _CollectionAccessoryOverflowTile extends StatelessWidget {
  const _CollectionAccessoryOverflowTile({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '+$count',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: const Color(0xFF475569),
        ),
      ),
    );
  }
}

class _CollectionRarityDot extends StatelessWidget {
  const _CollectionRarityDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
    );
  }
}

class _CollectionSuggestionSection extends StatelessWidget {
  const _CollectionSuggestionSection();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                _collectionText(zh: '可能感兴趣', en: 'You May Also Like'),
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
              ),
            ),
            TextButton(
              onPressed: () => Get.toNamed(Routers.MARKET),
              child: Text(_collectionText(zh: '前往市场', en: 'Open Market')),
            ),
          ],
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final stacked = constraints.maxWidth < 360;
            final promoCard = _CollectionPromoCard(
              title: _collectionText(
                zh: '继续逛逛热门饰品',
                en: 'Explore Trending Skins',
              ),
              subtitle: _collectionText(
                zh: '从市场中继续发现你感兴趣的收藏目标',
                en: 'Keep browsing the market for your next favorite item',
              ),
              cta: _collectionText(zh: '进入市场', en: 'Go to Market'),
              icon: Icons.north_east_rounded,
              onTap: () => Get.toNamed(Routers.MARKET),
            );
            final insightCard = _CollectionInsightCard(
              title: _collectionText(
                zh: '收藏筛选提示',
                en: 'Collection Filter Tips',
              ),
              subtitle: _collectionText(
                zh: '支持价格排序、搜索名称和高级属性筛选',
                en: 'Use price sort, keyword search, and advanced filters',
              ),
            );
            if (stacked) {
              return Column(
                children: [promoCard, const SizedBox(height: 12), insightCard],
              );
            }
            return Row(
              children: [
                Expanded(child: promoCard),
                const SizedBox(width: 12),
                Expanded(child: insightCard),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _CollectionPromoCard extends StatelessWidget {
  const _CollectionPromoCard({
    required this.title,
    required this.subtitle,
    required this.cta,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String cta;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(26),
        child: Container(
          height: 154,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1E40AF), Color(0xFF3B82F6)],
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x241D4ED8),
                blurRadius: 28,
                offset: Offset(0, 14),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const Spacer(),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.86),
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                cta,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CollectionInsightCard extends StatelessWidget {
  const _CollectionInsightCard({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 154,
      padding: const EdgeInsets.all(18),
      decoration: _collectionCardDecoration(radius: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFEAF1FF),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              _collectionText(zh: '网页参考', en: 'Web Reference'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1D4ED8),
              ),
            ),
          ),
          const Spacer(),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
              height: 1.25,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: const Color(0xFF64748B),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _CollectionMiniStat(
                  label: _collectionText(zh: '搜索', en: 'Search'),
                  value: _collectionText(zh: '名称', en: 'Keyword'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _CollectionMiniStat(
                  label: _collectionText(zh: '排序', en: 'Sort'),
                  value: _collectionText(zh: '价格', en: 'Price'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CollectionMiniStat extends StatelessWidget {
  const _CollectionMiniStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F6FA),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }
}

class _CollectionEmptyState extends StatelessWidget {
  const _CollectionEmptyState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 20),
      children: [
        const SizedBox(height: 84),
        Container(
          padding: const EdgeInsets.fromLTRB(24, 30, 24, 24),
          decoration: _collectionCardDecoration(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF1E40AF), Color(0xFF60A5FA)],
                  ),
                ),
                child: const Icon(
                  Icons.bookmark_outline_rounded,
                  color: Colors.white,
                  size: 30,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                _collectionText(zh: '还没有收藏内容', en: 'No Collections Yet'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _collectionText(
                  zh: '去市场里逛逛，把感兴趣的饰品或品类收藏起来吧。',
                  en: 'Browse the market and save the items or categories you like.',
                ),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF64748B),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: () => Get.toNamed(Routers.MARKET),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1D4ED8),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: Text(_collectionText(zh: '前往市场', en: 'Open Market')),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CollectionLoadingState extends StatelessWidget {
  const _CollectionLoadingState({required this.mode});

  final _CollectionVisualMode mode;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
      children: [
        const _CollectionTabSkeleton(),
        const SizedBox(height: 18),
        for (var i = 0; i < 3; i++) ...[
          _CollectionCardSkeleton(mode: mode),
          if (i != 2) const SizedBox(height: 16),
        ],
        const SizedBox(height: 28),
        const _CollectionSuggestionSectionSkeleton(),
      ],
    );
  }
}

class _CollectionFooter extends StatelessWidget {
  const _CollectionFooter({
    required this.showLoading,
    required this.showNoMore,
  });

  final bool showLoading;
  final bool showNoMore;

  @override
  Widget build(BuildContext context) {
    if (showLoading) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(0, 10, 0, 14),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.2),
          ),
        ),
      );
    }
    if (showNoMore) {
      return const ListEndTip(padding: EdgeInsets.fromLTRB(8, 6, 8, 12));
    }
    return const SizedBox(height: 4);
  }
}

class _CollectionStatusBadge extends StatelessWidget {
  const _CollectionStatusBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF1FF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF1D4ED8),
        ),
      ),
    );
  }
}

class _CollectionTabSkeleton extends StatelessWidget {
  const _CollectionTabSkeleton();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        Expanded(child: _CollectionSkeletonBox(height: 18, radius: 12)),
        SizedBox(width: 12),
        _CollectionSkeletonBox(width: 84, height: 18, radius: 12),
      ],
    );
  }
}

class _CollectionCardSkeleton extends StatelessWidget {
  const _CollectionCardSkeleton({required this.mode});

  final _CollectionVisualMode mode;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _collectionCardDecoration(
        color: Colors.white.withValues(alpha: 0.92),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CollectionSkeletonBox(width: 96, height: 96, radius: 22),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _CollectionSkeletonBox(height: 16, radius: 10),
                const SizedBox(height: 8),
                const _CollectionSkeletonBox(
                  width: 140,
                  height: 14,
                  radius: 10,
                ),
                const SizedBox(height: 14),
                if (mode == _CollectionVisualMode.category)
                  Row(
                    children: const [
                      Expanded(
                        child: _CollectionSkeletonBox(height: 58, radius: 16),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: _CollectionSkeletonBox(height: 58, radius: 16),
                      ),
                    ],
                  )
                else ...[
                  const _CollectionSkeletonBox(height: 48, radius: 16),
                  const SizedBox(height: 10),
                  Row(
                    children: const [
                      _CollectionSkeletonBox(width: 28, height: 28, radius: 10),
                      SizedBox(width: 6),
                      _CollectionSkeletonBox(width: 28, height: 28, radius: 10),
                      SizedBox(width: 6),
                      _CollectionSkeletonBox(width: 28, height: 28, radius: 10),
                      SizedBox(width: 6),
                      _CollectionSkeletonBox(width: 28, height: 28, radius: 10),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CollectionSuggestionSectionSkeleton extends StatelessWidget {
  const _CollectionSuggestionSectionSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _CollectionSkeletonBox(width: 180, height: 18, radius: 12),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final stacked = constraints.maxWidth < 360;
            const card = _CollectionSkeletonBox(height: 154, radius: 26);
            if (stacked) {
              return Column(children: [card, const SizedBox(height: 12), card]);
            }
            return Row(
              children: [
                Expanded(child: card),
                const SizedBox(width: 12),
                Expanded(child: card),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _CollectionSkeletonBox extends StatelessWidget {
  const _CollectionSkeletonBox({
    this.width,
    required this.height,
    required this.radius,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFE8EEF5),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
