import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:tronskins_app/common/widgets/settings_style_app_bar.dart';
import 'package:get/get.dart';
import 'package:tronskins_app/api/model/market/market_models.dart';
import 'package:tronskins_app/api/model/shop/shop_models.dart';
import 'package:tronskins_app/api/shop.dart';
import 'package:tronskins_app/common/hooks/game/global_game_controller.dart';
import 'package:tronskins_app/components/game/game_switch_menu.dart';
import 'package:tronskins_app/components/game_item/game_item_models.dart';
import 'package:tronskins_app/components/market/market_showcase_card.dart';
import 'package:tronskins_app/routes/app_routes.dart';

enum _SellerMetricPeriod { week, month }

enum _SellerShopTab { onSale, saleHistory }

enum _SellerOnSaleSort { priceAsc, priceDesc, wearAsc, wearDesc }

class SellerShopPage extends StatefulWidget {
  const SellerShopPage({super.key});

  @override
  State<SellerShopPage> createState() => _SellerShopPageState();
}

class _SellerShopPageState extends State<SellerShopPage>
    with SingleTickerProviderStateMixin {
  static const Color _pageBackground = Color(0xFFF7F9FB);
  static const Color _surfaceCard = Colors.white;
  static const Color _surfaceSoft = Color(0xFFF2F4F6);
  static const Color _textPrimary = Color(0xFF191C1E);
  static const Color _textSecondary = Color(0xFF757684);
  static const Color _brandBlue = Color(0xFF00288E);
  static const Color _successGreen = Color(0xFF22C55E);
  static const int _onSaleGridColumns = 2;
  static const double _onSaleGridMainSpacing = 8;
  static const double _onSaleGridCrossSpacing = 8;
  static const double _onSaleGridAspectRatio = 0.98;
  static const double _onSaleFilterBarMaxHeight = 30;
  static const EdgeInsets _onSaleGridPadding = EdgeInsets.fromLTRB(
    16,
    4,
    16,
    16,
  );
  static const int _onSaleLoadMorePlaceholderCount = 2;
  static const int _saleHistoryLoadMorePlaceholderCount = 2;

  final ApiShopServer _shopServer = ApiShopServer();
  final GlobalGameController _globalGameController =
      GlobalGameController.ensureInstance();
  final ScrollController _onSaleScrollController = ScrollController();
  final ScrollController _historyScrollController = ScrollController();
  final GlobalKey _onSaleSortButtonKey = GlobalKey();
  TabController? _tabController;
  Worker? _gameWorker;

  late int _appId;
  late final String _shopUuid;
  Map<String, dynamic>? _shopInfo;
  final List<ShopItemAsset> _items = <ShopItemAsset>[];
  final List<ShopSaleHistoryItem> _historyItems = <ShopSaleHistoryItem>[];
  Map<String, ShopSchemaInfo> _schemas = <String, ShopSchemaInfo>{};
  Map<String, dynamic> _stickers = <String, dynamic>{};
  bool _loadingInfo = true;
  bool _loadingItems = true;
  bool _refreshingItems = false;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  bool _loadingHistory = false;
  bool _refreshingHistory = false;
  bool _loadingHistoryMore = false;
  bool _historyHasMore = true;
  int _historyPage = 1;
  _SellerMetricPeriod _metricPeriod = _SellerMetricPeriod.week;
  _SellerShopTab _activeTab = _SellerShopTab.onSale;
  _SellerOnSaleSort _onSaleSort = _SellerOnSaleSort.priceAsc;

  @override
  void initState() {
    super.initState();
    _ensureTabController();
    final args = Get.arguments as Map<String, dynamic>? ?? const {};
    _appId = _asInt(args['appId']) ?? _globalGameController.appId;
    _shopUuid = args['uuid']?.toString() ?? '';
    _shopInfo = args['shopInfo'] is Map
        ? Map<String, dynamic>.from(args['shopInfo'] as Map)
        : null;
    _onSaleScrollController.addListener(_handleOnSaleScroll);
    _historyScrollController.addListener(_handleHistoryScroll);
    _gameWorker = ever<int>(_globalGameController.currentAppId, (
      nextAppId,
    ) async {
      if (!mounted || nextAppId == _appId) {
        return;
      }
      await _applyGameChange(nextAppId);
    });
    if (_appId != _globalGameController.appId) {
      unawaited(_globalGameController.switchGame(_appId));
    }
    _bootstrap();
  }

  @override
  void dispose() {
    _gameWorker?.dispose();
    _tabController?.animation?.removeListener(_handleTabAnimationTick);
    _tabController
      ?..removeListener(_handleTabControllerChange)
      ..dispose();
    _onSaleScrollController
      ..removeListener(_handleOnSaleScroll)
      ..dispose();
    _historyScrollController
      ..removeListener(_handleHistoryScroll)
      ..dispose();
    super.dispose();
  }

  TabController _ensureTabController() {
    final existing = _tabController;
    if (existing != null) {
      return existing;
    }
    final controller = TabController(
      length: 2,
      vsync: this,
      initialIndex: _activeTab == _SellerShopTab.onSale ? 0 : 1,
    );
    controller.addListener(_handleTabControllerChange);
    controller.animation?.addListener(_handleTabAnimationTick);
    _tabController = controller;
    return controller;
  }

  Future<void> _bootstrap() async {
    await Future.wait<void>([
      _loadShopInfo(),
      _loadItems(reset: true),
      _loadHistory(reset: true),
    ]);
  }

  Future<void> _loadShopInfo() async {
    if (_shopUuid.isEmpty) {
      setState(() => _loadingInfo = false);
      return;
    }
    try {
      final res = await _shopServer.getUserShopInfo(
        params: {'uuid': _shopUuid},
      );
      if (!mounted) {
        return;
      }
      if (res.success && res.datas != null) {
        setState(() => _shopInfo = Map<String, dynamic>.from(res.datas!));
      }
    } catch (_) {
      // Keep the initial snapshot if the request fails.
    } finally {
      if (mounted) {
        setState(() => _loadingInfo = false);
      }
    }
  }

  Future<void> _loadItems({
    bool reset = false,
    bool clearVisibleItems = false,
    bool preserveVisibleItems = false,
  }) async {
    if (_shopUuid.isEmpty) {
      setState(() {
        _loadingItems = false;
        _refreshingItems = false;
        _loadingMore = false;
        _hasMore = false;
      });
      return;
    }
    if (reset) {
      setState(() {
        _page = 1;
        _hasMore = true;
        _loadingItems = true;
        _refreshingItems = preserveVisibleItems && _items.isNotEmpty;
        _loadingMore = false;
        if (clearVisibleItems || !preserveVisibleItems) {
          _items.clear();
        }
      });
    } else {
      if (_loadingItems || _loadingMore || !_hasMore) {
        return;
      }
      setState(() => _loadingMore = true);
    }

    final requestAppId = _appId;
    final requestPage = reset ? 1 : _page;

    try {
      final res = await _shopServer.publicShopSellList(
        appId: requestAppId,
        uuid: _shopUuid,
        page: requestPage,
        pageSize: 20,
        field: _onSaleSortField,
        asc: _onSaleSortAsc,
      );
      if (!mounted || requestAppId != _appId) {
        return;
      }
      if (res.success && res.datas != null) {
        final datas = res.datas!;
        final pageSize = datas.pager?.pageSize ?? 20;
        final total = datas.total ?? datas.pager?.total ?? datas.items.length;
        final totalPages = pageSize <= 0 ? 1 : (total / pageSize).ceil();
        setState(() {
          final mergedSchemas = reset
              ? <String, ShopSchemaInfo>{}
              : Map<String, ShopSchemaInfo>.from(_schemas);
          mergedSchemas.addAll(datas.schemas);
          final mergedStickers = reset
              ? <String, dynamic>{}
              : Map<String, dynamic>.from(_stickers);
          mergedStickers.addAll(datas.stickers);
          if (reset) {
            _items
              ..clear()
              ..addAll(datas.items);
          } else {
            _items.addAll(datas.items);
          }
          _schemas = mergedSchemas;
          _stickers = mergedStickers;
          _hasMore = requestPage < totalPages;
          _page = requestPage + 1;
        });
      } else if (reset) {
        setState(() {
          if (!preserveVisibleItems) {
            _items.clear();
          }
          _hasMore = false;
        });
      }
    } catch (_) {
      if (reset && mounted) {
        setState(() {
          if (!preserveVisibleItems) {
            _items.clear();
          }
          _hasMore = false;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _loadingItems = false;
          _refreshingItems = false;
          _loadingMore = false;
        });
      }
    }
  }

  Future<void> _loadHistory({
    bool reset = false,
    bool clearVisibleItems = false,
    bool preserveVisibleItems = false,
  }) async {
    if (_shopUuid.isEmpty) {
      if (mounted) {
        setState(() {
          _loadingHistory = false;
          _refreshingHistory = false;
          _loadingHistoryMore = false;
          _historyHasMore = false;
        });
      }
      return;
    }

    if (reset) {
      setState(() {
        _historyPage = 1;
        _historyHasMore = true;
        _loadingHistory = true;
        _refreshingHistory = preserveVisibleItems && _historyItems.isNotEmpty;
        _loadingHistoryMore = false;
        if (clearVisibleItems || !preserveVisibleItems) {
          _historyItems.clear();
        }
      });
    } else {
      if (_loadingHistory || _loadingHistoryMore || !_historyHasMore) {
        return;
      }
      setState(() => _loadingHistoryMore = true);
    }

    const pageSize = 20;
    final requestAppId = _appId;
    final requestPage = reset ? 1 : _historyPage;

    try {
      final res = await _shopServer.shopTransactionList(
        appId: requestAppId,
        uuid: _shopUuid,
        page: requestPage,
        pageSize: pageSize,
      );
      if (!mounted || requestAppId != _appId) {
        return;
      }
      if (res.success && res.datas != null) {
        final items = res.datas!;
        setState(() {
          if (reset) {
            _historyItems
              ..clear()
              ..addAll(items);
          } else {
            _historyItems.addAll(items);
          }
          _historyHasMore = items.length >= pageSize;
          _historyPage = requestPage + 1;
        });
      } else if (reset) {
        setState(() {
          if (!preserveVisibleItems) {
            _historyItems.clear();
          }
          _historyHasMore = false;
        });
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        if (reset) {
          if (!preserveVisibleItems) {
            _historyItems.clear();
          }
          _historyHasMore = false;
        }
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingHistory = false;
          _refreshingHistory = false;
          _loadingHistoryMore = false;
        });
      }
    }
  }

  void _handleOnSaleScroll() {
    if (!_onSaleScrollController.hasClients) {
      return;
    }
    if (_onSaleScrollController.position.extentAfter < 280) {
      _loadItems();
    }
  }

  void _handleHistoryScroll() {
    if (!_historyScrollController.hasClients) {
      return;
    }
    if (_historyScrollController.position.extentAfter < 280) {
      _loadHistory();
    }
  }

  void _handleTabControllerChange() {
    final controller = _tabController;
    if (controller == null) {
      return;
    }
    final nextTab = controller.index == 0
        ? _SellerShopTab.onSale
        : _SellerShopTab.saleHistory;
    if (_activeTab == nextTab) {
      return;
    }
    _selectTab(nextTab, syncController: false);
  }

  void _handleTabAnimationTick() {
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  void _handleTabDragUpdate({
    required double deltaDx,
    required double dragWidth,
  }) {
    final controller = _ensureTabController();
    if (controller.indexIsChanging || dragWidth <= 0) {
      return;
    }
    final maxIndex = (controller.length - 1).toDouble();
    final currentValue =
        controller.animation?.value ?? controller.index.toDouble();
    final nextValue = (currentValue - (deltaDx / dragWidth))
        .clamp(0.0, maxIndex)
        .toDouble();
    final nextOffset = (nextValue - controller.index).clamp(-1.0, 1.0);
    if (nextOffset >= 0.98 && controller.index < controller.length - 1) {
      controller.index = controller.index + 1;
      controller.offset = 0;
      return;
    }
    if (nextOffset <= -0.98 && controller.index > 0) {
      controller.index = controller.index - 1;
      controller.offset = 0;
      return;
    }
    controller.offset = nextOffset;
  }

  void _settleToClosestTab() {
    final controller = _ensureTabController();
    if (controller.indexIsChanging) {
      return;
    }
    final value = controller.animation?.value ?? controller.index.toDouble();
    final targetIndex = value.round().clamp(0, controller.length - 1);
    if (targetIndex == controller.index) {
      controller.offset = 0;
      return;
    }
    controller.animateTo(
      targetIndex,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _refreshOnSale() async {
    await Future.wait<void>([
      _loadShopInfo(),
      _loadItems(reset: true, preserveVisibleItems: true),
    ]);
  }

  Future<void> _refreshHistory() async {
    await Future.wait<void>([
      _loadShopInfo(),
      _loadHistory(reset: true, preserveVisibleItems: true),
    ]);
  }

  Future<void> _applyGameChange(int nextAppId) async {
    if (nextAppId == _appId) {
      return;
    }
    if (mounted) {
      setState(() => _appId = nextAppId);
    } else {
      _appId = nextAppId;
    }
    if (_onSaleScrollController.hasClients) {
      _onSaleScrollController.jumpTo(0);
    }
    if (_historyScrollController.hasClients) {
      _historyScrollController.jumpTo(0);
    }
    await Future.wait<void>([
      _loadItems(reset: true, clearVisibleItems: true),
      _loadHistory(reset: true, clearVisibleItems: true),
    ]);
  }

  Future<void> _changeOnSaleSort(_SellerOnSaleSort sort) async {
    if (_onSaleSort == sort) {
      return;
    }
    setState(() => _onSaleSort = sort);
    if (_onSaleScrollController.hasClients) {
      _onSaleScrollController.jumpTo(0);
    }
    await _loadItems(reset: true, clearVisibleItems: true);
  }

  bool get _isEnglishLocale =>
      (Get.locale?.languageCode ?? '').toLowerCase().startsWith('en');

  double get _tabAnimationValue {
    final controller = _tabController;
    final raw =
        controller?.animation?.value ??
        (controller?.index.toDouble() ??
            (_activeTab == _SellerShopTab.onSale ? 0.0 : 1.0));
    return raw.clamp(0.0, 1.0).toDouble();
  }

  double get _onSaleFilterBarProgress {
    return (1.0 - _tabAnimationValue.abs()).clamp(0.0, 1.0).toDouble();
  }

  double get _onSaleFilterBarHeight =>
      _onSaleFilterBarMaxHeight * _onSaleFilterBarProgress;

  bool get _showOnSaleFilterBar => _onSaleFilterBarHeight > 0.001;

  String get _pageTitle => 'app.market.seller_shop.title'.tr;

  String get _gameSwitcherLabel {
    return switch (_appId) {
      440 => 'TF2',
      570 => 'DOTA2',
      730 => 'CS2',
      _ => 'GAME',
    };
  }

  String get _onSaleLabel => _isEnglishLocale ? 'On Sale' : '在售商品';

  String get _saleHistoryLabel => _isEnglishLocale ? 'Sale History' : '成交记录';

  String get _currentOnSaleSortLabel => _sortOptionLabel(_onSaleSort);

  String get _onSaleSortField {
    return switch (_onSaleSort) {
      _SellerOnSaleSort.priceAsc || _SellerOnSaleSort.priceDesc => 'price',
      _SellerOnSaleSort.wearAsc || _SellerOnSaleSort.wearDesc => 'wear',
    };
  }

  bool get _onSaleSortAsc {
    return switch (_onSaleSort) {
      _SellerOnSaleSort.priceAsc || _SellerOnSaleSort.wearAsc => true,
      _SellerOnSaleSort.priceDesc || _SellerOnSaleSort.wearDesc => false,
    };
  }

  String _sortOptionLabel(_SellerOnSaleSort sort) {
    return switch (sort) {
      _SellerOnSaleSort.priceAsc => _isEnglishLocale ? 'Price ↑' : '价格 ↑',
      _SellerOnSaleSort.priceDesc => _isEnglishLocale ? 'Price ↓' : '价格 ↓',
      _SellerOnSaleSort.wearAsc => _isEnglishLocale ? 'Wear ↑' : '磨损 ↑',
      _SellerOnSaleSort.wearDesc => _isEnglishLocale ? 'Wear ↓' : '磨损 ↓',
    };
  }

  String get _onlineLabel => _isEnglishLocale ? 'ONLINE' : '在线';

  String get _offlineLabel => _isEnglishLocale ? 'OFFLINE' : '离线';

  String get _weekLabel => _isEnglishLocale ? 'Week' : '近7天';

  String get _monthLabel => _isEnglishLocale ? 'Month' : '近30天';

  String get _avgShipLabel => _isEnglishLocale ? 'AVG. SHIP' : '平均发货';

  String get _rateLabel => _isEnglishLocale ? 'RATE' : '发货率';

  String get _emptyTitle => _isEnglishLocale ? 'No items on sale' : '暂无在售商品';

  String get _emptySubtitle => _isEnglishLocale
      ? 'This seller has no public listings right now.'
      : '当前卖家没有公开在售饰品。';

  String get _emptyHistoryTitle =>
      _isEnglishLocale ? 'No sale history yet' : '暂无成交记录';

  String get _emptyHistorySubtitle => _isEnglishLocale
      ? 'This seller has no recent public sale history.'
      : '当前卖家暂无最近成交记录。';

  String get _shopName =>
      _shopInfo?['name']?.toString().trim() ??
      _shopInfo?['shopName']?.toString().trim() ??
      _shopInfo?['nickname']?.toString().trim() ??
      _shopUuid;

  String? get _avatarUrl => _resolveAvatarUrl(_shopInfo?['avatar']?.toString());

  String? _resolveAvatarUrl(String? raw) {
    if (raw == null || raw.isEmpty) {
      return null;
    }
    if (raw.startsWith('http')) {
      return raw;
    }
    return 'https://www.tronskins.com/fms/image$raw';
  }

  int? _asInt(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value.toString());
  }

  double? _asDouble(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is double) {
      return value;
    }
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value.toString());
  }

  String _deliverySuccessRate({required int total, required int notSend}) {
    if (total <= 0) {
      return '0%';
    }
    final rate = ((total - notSend) / total * 100).clamp(0, 100);
    return '${rate.toStringAsFixed(1)}%';
  }

  String _formatAverageShip(double? value) {
    if (value == null || value <= 0) {
      return _isEnglishLocale ? '0 mins' : '0 分钟';
    }
    if (value < 2) {
      return _isEnglishLocale ? '< 2 mins' : '< 2 分钟';
    }
    final text = value.toStringAsFixed(value >= 10 ? 0 : 1);
    return _isEnglishLocale ? '$text mins' : '$text 分钟';
  }

  double? _metricAverageShip() {
    return _metricPeriod == _SellerMetricPeriod.week
        ? _asDouble(_shopInfo?['last7daysAvg'])
        : _asDouble(_shopInfo?['last30daysAvg']);
  }

  String _metricRate() {
    final total = _metricPeriod == _SellerMetricPeriod.week
        ? _asInt(_shopInfo?['last7daysNums']) ?? 0
        : _asInt(_shopInfo?['last30daysNums']) ?? 0;
    final notSend = _metricPeriod == _SellerMetricPeriod.week
        ? _asInt(_shopInfo?['last7daysNotSend']) ?? 0
        : _asInt(_shopInfo?['last30daysNotSend']) ?? 0;
    return _deliverySuccessRate(total: total, notSend: notSend);
  }

  void _openItemDetail(ShopItemAsset item) {
    final schema = _schemas[item.schemaId?.toString() ?? ''];
    final asset = item.asset;
    final marketItem = MarketListItem.fromJson({
      ...item.raw,
      'id': item.raw['sell_id'] ?? item.id,
      'app_id': item.appId,
      'schema_id': item.schemaId,
      'price': item.price,
      'market_name': item.marketName,
      'market_hash_name': item.marketHashName,
      'image_url': item.imageUrl,
      'user_id': item.userId,
      if (asset != null) _appAssetKey(item.appId): asset,
    });
    final user = MarketUserInfo.fromJson({
      'avatar': _shopInfo?['avatar'],
      'nickname': _shopName,
      'uuid': _shopUuid,
    });
    Get.toNamed(
      Routers.MARKET_ITEM_DETAIL,
      arguments: {
        'item': marketItem,
        'schema': schema == null ? null : MarketSchemaInfo.fromJson(schema.raw),
        'user': user,
        'schemas': {
          for (final entry in _schemas.entries)
            entry.key: MarketSchemaInfo.fromJson(entry.value.raw),
        },
        'stickers': _stickers,
      },
    );
  }

  String _appAssetKey(int? appId) {
    switch (appId) {
      case 440:
        return 'tf2Asset';
      case 570:
        return 'dota2Asset';
      case 730:
      default:
        return 'csgoAsset';
    }
  }

  void _selectTab(_SellerShopTab tab, {bool syncController = true}) {
    if (_activeTab == tab) {
      return;
    }
    setState(() => _activeTab = tab);
    if (syncController) {
      final nextIndex = tab == _SellerShopTab.onSale ? 0 : 1;
      final controller = _ensureTabController();
      if (controller.index != nextIndex) {
        controller.animateTo(nextIndex);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _ensureTabController();
    return Scaffold(
      backgroundColor: _pageBackground,
      appBar: SettingsStyleAppBar(
        title: Text(_pageTitle),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Center(
              child: Builder(
                builder: (iconContext) => _buildGameSwitcherButton(iconContext),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragStart: (_) {},
              onHorizontalDragUpdate: (_) {},
              onHorizontalDragEnd: (_) {},
              onHorizontalDragCancel: () {},
              child: _buildSellerCard(),
            ),
          ),
          const SizedBox(height: 10),
          _buildControlSection(),
          Expanded(
            child: Container(
              color: _pageBackground,
              child: TabBarView(
                controller: controller,
                children: [_buildOnSaleTab(), _buildSaleHistoryTab()],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlSection() {
    return Container(
      width: double.infinity,
      color: _pageBackground,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildTabBar(),
          if (_onSaleFilterBarHeight > 0 || _showOnSaleFilterBar)
            SizedBox(
              height: _onSaleFilterBarHeight,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: _buildOnSaleFilterBar(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGameSwitcherButton(BuildContext iconContext) {
    const buttonBlue = Color(0xFF1E40AF);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openGameSwitcher(iconContext),
        borderRadius: BorderRadius.circular(8),
        overlayColor: WidgetStateProperty.resolveWith<Color?>((states) {
          if (states.contains(WidgetState.pressed)) {
            return buttonBlue.withValues(alpha: 0.12);
          }
          if (states.contains(WidgetState.hovered)) {
            return buttonBlue.withValues(alpha: 0.06);
          }
          return null;
        }),
        child: Container(
          constraints: const BoxConstraints(minWidth: 66),
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _gameSwitcherLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: buttonBlue,
                  fontSize: 14,
                  height: 20 / 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.35,
                ),
              ),
              const SizedBox(width: 2),
              const Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 16,
                color: buttonBlue,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openGameSwitcher(BuildContext iconContext) async {
    final selected = await showGameSwitchMenu(
      iconContext: iconContext,
      currentAppId: _appId,
    );
    if (selected == null || selected == _appId) {
      return;
    }
    await _globalGameController.switchGame(selected);
  }

  Widget _buildTabBar() {
    final controller = _ensureTabController();
    final tabBar = SizedBox(
      height: 30,
      child: TabBar(
        controller: controller,
        dividerColor: Colors.transparent,
        padding: EdgeInsets.zero,
        indicatorPadding: EdgeInsets.zero,
        labelPadding: EdgeInsets.zero,
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: _brandBlue,
        unselectedLabelColor: _textSecondary,
        labelStyle: const TextStyle(
          fontSize: 10,
          height: 12 / 10,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 10,
          height: 12 / 10,
          fontWeight: FontWeight.w600,
        ),
        overlayColor: WidgetStateProperty.resolveWith<Color?>((states) {
          if (states.contains(WidgetState.pressed)) {
            return _brandBlue.withValues(alpha: 0.08);
          }
          if (states.contains(WidgetState.hovered)) {
            return _brandBlue.withValues(alpha: 0.04);
          }
          return null;
        }),
        indicator: const UnderlineTabIndicator(
          borderSide: BorderSide(color: _brandBlue, width: 2.5),
          insets: EdgeInsets.symmetric(horizontal: 16),
        ),
        tabs: [
          Tab(text: _onSaleLabel),
          Tab(text: _saleHistoryLabel),
        ],
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final dragWidth = constraints.maxWidth;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragUpdate: (details) => _handleTabDragUpdate(
            deltaDx: details.delta.dx,
            dragWidth: dragWidth,
          ),
          onHorizontalDragEnd: (_) => _settleToClosestTab(),
          onHorizontalDragCancel: _settleToClosestTab,
          child: tabBar,
        );
      },
    );
  }

  Widget _buildOnSaleFilterBar() {
    return IgnorePointer(
      ignoring: _onSaleFilterBarProgress < 0.98,
      child: ClipRect(
        child: Align(
          alignment: Alignment.centerRight,
          widthFactor: _onSaleFilterBarProgress,
          child: Opacity(
            opacity: _onSaleFilterBarProgress,
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: SizedBox(
                height: 26,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [_buildOnSaleSortDropdown()],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOnSaleTab() {
    final showRefreshingSkeleton =
        _loadingItems && _refreshingItems && _items.isNotEmpty;
    final showLoadMorePlaceholders = _loadingMore && _items.isNotEmpty;

    if (_loadingItems && _items.isEmpty) {
      return _buildOnSaleLoadingView(storageKey: 'seller-shop-on-sale-loading');
    }

    if (showRefreshingSkeleton) {
      return _buildOnSaleLoadingView(
        storageKey: 'seller-shop-on-sale-refreshing',
      );
    }

    if (_items.isEmpty) {
      return _buildRefreshScrollView(
        storageKey: 'seller-shop-on-sale-empty',
        onRefresh: _refreshOnSale,
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
            sliver: SliverFillRemaining(
              hasScrollBody: false,
              child: _buildEmptyState(
                title: _emptyTitle,
                subtitle: _emptySubtitle,
              ),
            ),
          ),
        ],
      );
    }

    return _buildRefreshScrollView(
      storageKey: 'seller-shop-on-sale',
      controller: _onSaleScrollController,
      onRefresh: _refreshOnSale,
      slivers: [
        SliverPadding(
          padding: _onSaleGridPadding,
          sliver: SliverGrid(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                if (index >= _items.length) {
                  return _buildLoadingCard();
                }
                return _buildShopItemCard(_items[index]);
              },
              childCount:
                  _items.length +
                  (showLoadMorePlaceholders
                      ? _onSaleLoadMorePlaceholderCount
                      : 0),
            ),
            gridDelegate: _onSaleGridDelegate,
          ),
        ),
      ],
    );
  }

  Widget _buildOnSaleSortDropdown() {
    return _buildToolbarTextAction(
      actionKey: _onSaleSortButtonKey,
      label: _currentOnSaleSortLabel,
      color: _loadingItems ? _textSecondary : _brandBlue,
      icon: Icons.keyboard_arrow_down_rounded,
      iconSize: 13,
      onTap: _loadingItems ? null : _openOnSaleSortMenu,
    );
  }

  Widget _buildToolbarTextAction({
    required String label,
    required Color color,
    IconData? icon,
    double iconSize = 14,
    VoidCallback? onTap,
    Key? actionKey,
  }) {
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: color,
            fontSize: 11,
            height: 14 / 11,
            fontWeight: FontWeight.w500,
          ),
        ),
        if (icon != null) ...[
          const SizedBox(width: 1),
          Icon(icon, size: iconSize, color: color),
        ],
      ],
    );
    if (onTap == null) {
      return content;
    }
    return Material(
      key: actionKey,
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(7),
        overlayColor: WidgetStateProperty.resolveWith<Color?>((states) {
          if (states.contains(WidgetState.pressed)) {
            return color.withValues(alpha: 0.12);
          }
          if (states.contains(WidgetState.hovered)) {
            return color.withValues(alpha: 0.06);
          }
          return null;
        }),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: content,
        ),
      ),
    );
  }

  Future<void> _openOnSaleSortMenu() async {
    final currentContext = _onSaleSortButtonKey.currentContext;
    if (currentContext == null) {
      return;
    }
    final target = currentContext.findRenderObject() as RenderBox?;
    final overlay =
        Overlay.of(currentContext).context.findRenderObject() as RenderBox?;
    if (target == null || overlay == null) {
      return;
    }
    final topLeft = target.localToGlobal(Offset.zero, ancestor: overlay);
    final bottomRight = target.localToGlobal(
      target.size.bottomRight(Offset.zero),
      ancestor: overlay,
    );
    final position = RelativeRect.fromRect(
      Rect.fromLTWH(topLeft.dx, bottomRight.dy + 6, target.size.width, 0),
      Offset.zero & overlay.size,
    );
    final selected = await showMenu<_SellerOnSaleSort>(
      context: context,
      position: position,
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 10,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      items: _SellerOnSaleSort.values
          .map((sort) {
            final isSelected = sort == _onSaleSort;
            return PopupMenuItem<_SellerOnSaleSort>(
              value: sort,
              height: 0,
              padding: EdgeInsets.zero,
              child: Container(
                constraints: const BoxConstraints(minWidth: 124),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? _brandBlue.withValues(alpha: 0.06)
                      : Colors.transparent,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _sortOptionLabel(sort),
                        style: TextStyle(
                          color: isSelected ? _brandBlue : _textPrimary,
                          fontSize: 13,
                          height: 18 / 13,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                    if (isSelected)
                      const Icon(
                        Icons.check_rounded,
                        size: 16,
                        color: _brandBlue,
                      ),
                  ],
                ),
              ),
            );
          })
          .toList(growable: false),
    );
    if (selected == null) {
      return;
    }
    await _changeOnSaleSort(selected);
  }

  SliverGridDelegateWithFixedCrossAxisCount get _onSaleGridDelegate =>
      const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: _onSaleGridColumns,
        mainAxisSpacing: _onSaleGridMainSpacing,
        crossAxisSpacing: _onSaleGridCrossSpacing,
        childAspectRatio: _onSaleGridAspectRatio,
      );

  int _calculateOnSaleLoadingCount(BoxConstraints constraints) {
    if (!constraints.hasBoundedWidth || !constraints.hasBoundedHeight) {
      return 6;
    }
    final contentWidth =
        constraints.maxWidth -
        _onSaleGridPadding.left -
        _onSaleGridPadding.right;
    if (contentWidth <= 0) {
      return 6;
    }
    final cardWidth =
        (contentWidth - _onSaleGridCrossSpacing * (_onSaleGridColumns - 1)) /
        _onSaleGridColumns;
    if (cardWidth <= 0) {
      return 6;
    }
    final cardHeight = cardWidth / _onSaleGridAspectRatio;
    final contentHeight =
        constraints.maxHeight -
        _onSaleGridPadding.top -
        _onSaleGridPadding.bottom;
    final effectiveHeight = contentHeight <= 0 ? cardHeight : contentHeight;
    final rowExtent = cardHeight + _onSaleGridMainSpacing;
    final visibleRows = ((effectiveHeight + _onSaleGridMainSpacing) / rowExtent)
        .ceil();
    return visibleRows.clamp(2, 8) * _onSaleGridColumns;
  }

  Widget _buildOnSaleLoadingView({
    required String storageKey,
    Future<void> Function()? onRefresh,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemCount = _calculateOnSaleLoadingCount(constraints);
        if (onRefresh == null) {
          return GridView.builder(
            key: PageStorageKey<String>(storageKey),
            padding: _onSaleGridPadding,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: _onSaleGridDelegate,
            itemCount: itemCount,
            itemBuilder: (context, index) => _buildLoadingCard(),
          );
        }
        return _buildRefreshScrollView(
          storageKey: storageKey,
          onRefresh: onRefresh,
          slivers: [
            SliverPadding(
              padding: _onSaleGridPadding,
              sliver: SliverGrid(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _buildLoadingCard(),
                  childCount: itemCount,
                ),
                gridDelegate: _onSaleGridDelegate,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHistoryLoadingView({
    required String storageKey,
    Future<void> Function()? onRefresh,
  }) {
    const itemCount = 4;
    if (onRefresh == null) {
      return ListView.builder(
        key: PageStorageKey<String>(storageKey),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
        physics: const NeverScrollableScrollPhysics(),
        itemCount: itemCount,
        itemBuilder: (context, index) => Padding(
          padding: EdgeInsets.only(top: index == 0 ? 0 : 10),
          child: _buildHistoryLoadingCard(),
        ),
      );
    }
    return _buildRefreshScrollView(
      storageKey: storageKey,
      onRefresh: onRefresh,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => Padding(
                padding: EdgeInsets.only(top: index == 0 ? 0 : 10),
                child: _buildHistoryLoadingCard(),
              ),
              childCount: itemCount,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSaleHistoryTab() {
    final showRefreshingSkeleton =
        _loadingHistory && _refreshingHistory && _historyItems.isNotEmpty;
    final showLoadMorePlaceholders =
        _loadingHistoryMore && _historyItems.isNotEmpty;

    if (_loadingHistory && _historyItems.isEmpty) {
      return _buildHistoryLoadingView(
        storageKey: 'seller-shop-sale-history-loading',
      );
    }

    if (showRefreshingSkeleton) {
      return _buildHistoryLoadingView(
        storageKey: 'seller-shop-sale-history-refreshing',
      );
    }

    if (_historyItems.isEmpty) {
      return _buildRefreshScrollView(
        storageKey: 'seller-shop-sale-history-empty',
        onRefresh: _refreshHistory,
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
            sliver: SliverFillRemaining(
              hasScrollBody: false,
              child: _buildEmptyState(
                title: _emptyHistoryTitle,
                subtitle: _emptyHistorySubtitle,
              ),
            ),
          ),
        ],
      );
    }

    return _buildRefreshScrollView(
      storageKey: 'seller-shop-sale-history',
      controller: _historyScrollController,
      onRefresh: _refreshHistory,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                if (index >= _historyItems.length) {
                  return Padding(
                    padding: EdgeInsets.only(
                      top: index == _historyItems.length ? 0 : 10,
                    ),
                    child: _buildHistoryLoadingCard(),
                  );
                }
                return Padding(
                  padding: EdgeInsets.only(top: index == 0 ? 0 : 10),
                  child: _buildHistoryCard(_historyItems[index]),
                );
              },
              childCount:
                  _historyItems.length +
                  (showLoadMorePlaceholders
                      ? _saleHistoryLoadMorePlaceholderCount
                      : 0),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRefreshScrollView({
    required String storageKey,
    required Future<void> Function() onRefresh,
    required List<Widget> slivers,
    ScrollController? controller,
  }) {
    return RefreshIndicator(
      color: _brandBlue,
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

  Widget _buildProgressSpinner({double size = 22, double strokeWidth = 2}) {
    return MarketProgressSpinner(size: size, strokeWidth: strokeWidth);
  }

  Widget _buildSellerCard() {
    if (_loadingInfo && (_shopInfo == null || _shopInfo!.isEmpty)) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _surfaceCard,
          borderRadius: BorderRadius.circular(8),
          boxShadow: const [
            BoxShadow(
              color: Color(0x80E2E8F0),
              blurRadius: 25,
              spreadRadius: -5,
              offset: Offset(0, 20),
            ),
            BoxShadow(
              color: Color(0x80E2E8F0),
              blurRadius: 10,
              spreadRadius: -6,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: SizedBox(
          height: 72,
          child: Center(child: _buildProgressSpinner()),
        ),
      );
    }

    final isOnline =
        _shopInfo?['isOnline'] == true || _shopInfo?['is_online'] == true;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _surfaceCard,
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(
            color: Color(0x80E2E8F0),
            blurRadius: 25,
            spreadRadius: -5,
            offset: Offset(0, 20),
          ),
          BoxShadow(
            color: Color(0x80E2E8F0),
            blurRadius: 10,
            spreadRadius: -6,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 2),
            child: _buildOnlineIndicator(isOnline),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildSellerAvatar(),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _shopName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _textPrimary,
                        fontSize: 15,
                        height: 20 / 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.35,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _buildPeriodSwitch(),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerRight,
                              child: _buildInlineMetrics(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodSwitch() {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: _surfaceSoft,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildPeriodChip(
            label: _weekLabel,
            selected: _metricPeriod == _SellerMetricPeriod.week,
            onTap: () =>
                setState(() => _metricPeriod = _SellerMetricPeriod.week),
          ),
          _buildPeriodChip(
            label: _monthLabel,
            selected: _metricPeriod == _SellerMetricPeriod.month,
            onTap: () =>
                setState(() => _metricPeriod = _SellerMetricPeriod.month),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: selected
                ? const [
                    BoxShadow(
                      color: Color(0x0D0F172A),
                      blurRadius: 2,
                      offset: Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? _brandBlue : _textSecondary,
              fontSize: 9,
              height: 13 / 9,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInlineMetrics() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildMetricValue(
          label: _avgShipLabel,
          value: _formatAverageShip(_metricAverageShip()),
        ),
        Container(
          width: 1,
          height: 18,
          margin: const EdgeInsets.symmetric(horizontal: 8),
          color: const Color(0xFFECEEF0),
        ),
        _buildMetricValue(label: _rateLabel, value: _metricRate()),
      ],
    );
  }

  Widget _buildMetricValue({required String label, required String value}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          softWrap: false,
          style: const TextStyle(
            color: _textSecondary,
            fontSize: 8,
            height: 11 / 8,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          softWrap: false,
          style: const TextStyle(
            color: _brandBlue,
            fontSize: 13,
            height: 15 / 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildOnlineIndicator(bool isOnline) {
    final color = isOnline ? _successGreen : const Color(0xFF94A3B8);
    final glowColor = isOnline
        ? const Color(0xBF4ADE80)
        : const Color(0x6694A3B8);
    return SizedBox(
      height: 12,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 8,
            height: 8,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: glowColor,
                    shape: BoxShape.circle,
                  ),
                ),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Text(
            isOnline ? _onlineLabel : _offlineLabel,
            style: TextStyle(
              color: isOnline ? const Color(0xFF16A34A) : _textSecondary,
              fontSize: 9,
              height: 12 / 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.25,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSellerAvatar() {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: _surfaceSoft,
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [
          BoxShadow(color: Color(0xFFECEEF0), blurRadius: 0, spreadRadius: 2),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: _avatarUrl == null
          ? const Icon(
              Icons.storefront_outlined,
              color: _textSecondary,
              size: 24,
            )
          : CachedNetworkImage(
              imageUrl: _avatarUrl!,
              fit: BoxFit.cover,
              errorWidget: (context, _, __) => const Icon(
                Icons.storefront_outlined,
                color: _textSecondary,
                size: 24,
              ),
            ),
    );
  }

  Widget _buildShopItemCard(ShopItemAsset item) {
    final schema = _schemas[item.schemaId?.toString() ?? ''];
    final tags = schema?.raw['tags'];
    final quality = TagInfo.fromRaw(tags is Map ? tags['quality'] : null);
    final rarity = TagInfo.fromRaw(tags is Map ? tags['rarity'] : null);
    final exterior = TagInfo.fromRaw(tags is Map ? tags['exterior'] : null);
    final asset = item.asset ?? item.raw;
    final imageUrl = _normalizeMarketImageUrl(
      item.imageUrl ?? schema?.imageUrl ?? '',
    );
    final title =
        item.marketName ?? schema?.marketName ?? item.marketHashName ?? '-';
    final wearText = _extractText(asset, const ['paint_wear', 'paintWear']);
    final wearValue = _extractDouble(asset, const ['paint_wear', 'paintWear']);
    final wearDisplay = _formatWearText(wearText, wearValue);
    final patternLabel = _extractText(asset, const ['paint_seed', 'paintSeed']);
    final stickers = _parseStickersForItem(item, asset).take(4).toList();
    final gems = _parseGemsForItem(item, asset).take(4).toList();
    return MarketShowcaseCard(
      appId: item.appId ?? _appId,
      imageUrl: imageUrl,
      title: title,
      price: item.price ?? 0,
      rarity: rarity,
      quality: quality,
      exterior: exterior,
      patternLabel: patternLabel,
      stickers: stickers,
      gems: gems,
      wearDisplay: wearDisplay,
      wearValue: wearValue,
      onTap: () => _openItemDetail(item),
    );
  }

  Widget _buildHistoryCard(ShopSaleHistoryItem item) {
    final imageUrl = _normalizeMarketImageUrl(item.imageUrl ?? '');
    final title = item.marketName?.trim().isNotEmpty == true
        ? item.marketName!.trim()
        : '-';
    final time = item.time?.trim().isNotEmpty == true
        ? item.time!.trim()
        : (_isEnglishLocale ? 'Unknown time' : '未知时间');

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _surfaceCard,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0F172A),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: const Color(0xFFF2F4F6),
              borderRadius: BorderRadius.circular(12),
            ),
            clipBehavior: Clip.antiAlias,
            child: imageUrl.isEmpty
                ? const Icon(
                    Icons.image_not_supported_outlined,
                    color: _textSecondary,
                    size: 24,
                  )
                : CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.contain,
                    errorWidget: (context, _, __) => const Icon(
                      Icons.image_not_supported_outlined,
                      color: _textSecondary,
                      size: 24,
                    ),
                  ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: _textPrimary,
                      fontSize: 13,
                      height: 18 / 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: _surfaceSoft,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      time,
                      style: const TextStyle(
                        color: _textSecondary,
                        fontSize: 10,
                        height: 12 / 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _normalizeMarketImageUrl(String raw) {
    if (raw.isEmpty) {
      return raw;
    }
    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      return raw;
    }
    if (raw.startsWith('/')) {
      return 'https://www.tronskins.com$raw';
    }
    return 'https://community.steamstatic.com/economy/image/$raw';
  }

  String? _formatWearText(String? rawText, double? rawValue) {
    final text = rawText?.trim();
    if (text != null && text.isNotEmpty) {
      return text;
    }
    if (rawValue == null) {
      return null;
    }
    return rawValue.toStringAsFixed(8);
  }

  List<GameItemSticker> _parseStickersForItem(
    ShopItemAsset item,
    Map<String, dynamic>? asset,
  ) {
    for (final candidate in _stickerCandidatesForItem(item, asset)) {
      final parsed = parseStickerList(
        _normalizeStickerEntries(candidate),
        schemaMap: _schemas,
        stickerMap: _stickers,
      );
      if (parsed.isNotEmpty) {
        return parsed;
      }
    }
    return const [];
  }

  List<GameItemGem> _parseGemsForItem(
    ShopItemAsset item,
    Map<String, dynamic>? asset,
  ) {
    for (final candidate in _gemCandidatesForItem(item, asset)) {
      final parsed = parseGemList(_normalizeGemEntries(candidate));
      if (parsed.isNotEmpty) {
        return parsed;
      }
    }
    return const [];
  }

  List<dynamic> _stickerCandidatesForItem(
    ShopItemAsset item,
    Map<String, dynamic>? asset,
  ) {
    final rawAsset = _asMap(item.raw['asset']) ?? _asMap(item.raw['itemAsset']);
    final rawCsgoAsset =
        _asMap(item.raw['csgoAsset']) ?? _asMap(item.raw['csgo_asset']);
    final rawTf2Asset =
        _asMap(item.raw['tf2Asset']) ?? _asMap(item.raw['tf2_asset']);
    final rawDotaAsset =
        _asMap(item.raw['dota2Asset']) ?? _asMap(item.raw['dota2_asset']);

    return <dynamic>[
      asset?['stickers'],
      asset?['stickerList'],
      asset?['sticker_list'],
      asset?['sticker'],
      rawAsset?['stickers'],
      rawAsset?['stickerList'],
      rawAsset?['sticker_list'],
      rawAsset?['sticker'],
      rawCsgoAsset?['stickers'],
      rawCsgoAsset?['stickerList'],
      rawCsgoAsset?['sticker_list'],
      rawCsgoAsset?['sticker'],
      rawTf2Asset?['stickers'],
      rawTf2Asset?['stickerList'],
      rawTf2Asset?['sticker_list'],
      rawTf2Asset?['sticker'],
      rawDotaAsset?['stickers'],
      rawDotaAsset?['stickerList'],
      rawDotaAsset?['sticker_list'],
      rawDotaAsset?['sticker'],
      item.raw['stickers'],
      item.raw['stickerList'],
      item.raw['sticker_list'],
      item.raw['sticker'],
    ];
  }

  List<dynamic> _gemCandidatesForItem(
    ShopItemAsset item,
    Map<String, dynamic>? asset,
  ) {
    final rawAsset = _asMap(item.raw['asset']) ?? _asMap(item.raw['itemAsset']);
    final rawCsgoAsset =
        _asMap(item.raw['csgoAsset']) ?? _asMap(item.raw['csgo_asset']);
    final rawTf2Asset =
        _asMap(item.raw['tf2Asset']) ?? _asMap(item.raw['tf2_asset']);
    final rawDotaAsset =
        _asMap(item.raw['dota2Asset']) ?? _asMap(item.raw['dota2_asset']);

    return <dynamic>[
      asset?['gemList'],
      asset?['gems'],
      asset?['gem_list'],
      asset?['gem'],
      rawAsset?['gemList'],
      rawAsset?['gems'],
      rawAsset?['gem_list'],
      rawAsset?['gem'],
      rawCsgoAsset?['gemList'],
      rawCsgoAsset?['gems'],
      rawCsgoAsset?['gem_list'],
      rawCsgoAsset?['gem'],
      rawTf2Asset?['gemList'],
      rawTf2Asset?['gems'],
      rawTf2Asset?['gem_list'],
      rawTf2Asset?['gem'],
      rawDotaAsset?['gemList'],
      rawDotaAsset?['gems'],
      rawDotaAsset?['gem_list'],
      rawDotaAsset?['gem'],
      item.raw['gemList'],
      item.raw['gems'],
      item.raw['gem_list'],
      item.raw['gem'],
    ];
  }

  List<dynamic> _normalizeStickerEntries(dynamic raw) {
    if (raw is List) {
      return raw;
    }
    if (raw is Iterable) {
      return raw.toList(growable: false);
    }
    if (raw is Map) {
      if (raw.containsKey('image_url') ||
          raw.containsKey('imageUrl') ||
          raw.containsKey('image') ||
          raw.containsKey('id') ||
          raw.containsKey('sticker_id') ||
          raw.containsKey('schema_id')) {
        return <dynamic>[raw];
      }
      return raw.values.toList(growable: false);
    }
    if (raw is String) {
      final value = raw.trim();
      if (value.isEmpty || value == 'null') {
        return const [];
      }
      if (value.contains(',')) {
        return value
            .split(',')
            .map((entry) => entry.trim())
            .where((entry) => entry.isNotEmpty)
            .toList(growable: false);
      }
      return <dynamic>[value];
    }
    return const [];
  }

  List<dynamic> _normalizeGemEntries(dynamic raw) {
    if (raw is List) {
      return raw;
    }
    if (raw is Iterable) {
      return raw.toList(growable: false);
    }
    if (raw is Map) {
      if (raw.containsKey('image_url') ||
          raw.containsKey('imageUrl') ||
          raw.containsKey('image')) {
        return <dynamic>[raw];
      }
      return raw.values.toList(growable: false);
    }
    if (raw is String) {
      final value = raw.trim();
      if (value.isEmpty || value == 'null') {
        return const [];
      }
      return <dynamic>[value];
    }
    return const [];
  }

  Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return null;
  }

  Widget _buildLoadingCard() {
    return const MarketShowcaseLoadingCard();
  }

  Widget _buildHistoryLoadingCard() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _surfaceCard,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: const Color(0xFFF2F4F6),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 14,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2F4F6),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  width: 96,
                  height: 12,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2F4F6),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({required String title, required String subtitle}) {
    return MarketEmptyState(title: title, subtitle: subtitle);
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
}
