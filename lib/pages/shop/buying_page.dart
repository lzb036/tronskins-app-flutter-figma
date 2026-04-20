import 'dart:math';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tronskins_app/common/utils/app_snackbar.dart';
import 'package:tronskins_app/api/shop_product.dart';
import 'package:tronskins_app/common/theme/settings_top_bar_style.dart';
import 'package:intl/intl.dart';
import 'package:tronskins_app/api/model/shop/shop_models.dart';
import 'package:tronskins_app/common/hooks/currency/CurrencyController.dart';
import 'package:tronskins_app/common/hooks/game/global_game_controller.dart';
import 'package:tronskins_app/common/widgets/app_request_loading_overlay.dart';
import 'package:tronskins_app/common/widgets/back_to_top_overlay.dart';
import 'package:tronskins_app/common/widgets/figma_confirmation_dialog.dart';
import 'package:tronskins_app/common/widgets/login_required_prompt.dart';
import 'package:tronskins_app/common/widgets/settings_style_app_bar.dart';
import 'package:tronskins_app/components/filter/filter_models.dart';
import 'package:tronskins_app/components/filter/market_filter_sheet.dart';
import 'package:tronskins_app/components/filter/order_filter_sheet.dart';
import 'package:tronskins_app/components/game/game_switch_menu.dart';
import 'package:tronskins_app/components/game_item/game_item_image.dart';
import 'package:tronskins_app/components/game_item/game_item_models.dart';
import 'package:tronskins_app/components/layout/app_search_bar.dart';
import 'package:tronskins_app/components/layout/header_filter_button.dart';
import 'package:tronskins_app/components/layout/list_end_tip.dart';
import 'package:tronskins_app/controllers/shop/buy_request_controller.dart';
import 'package:tronskins_app/controllers/user/user_controller.dart';
import 'package:tronskins_app/routes/app_routes.dart';

class BuyingPage extends StatefulWidget {
  const BuyingPage({super.key});

  @override
  State<BuyingPage> createState() => _BuyingPageState();
}

class _BuyingPageState extends State<BuyingPage>
    with SingleTickerProviderStateMixin {
  static const double _loadMoreThreshold = 200;
  static const double _myBuyingActionHeight = 42;
  static const Color _buyRecordSurfaceColor = Colors.white;
  static const Color _buyRecordSoftSurfaceColor = Color(0xFFF8FAFC);
  static const Color _buyRecordTitleColor = Color(0xFF191C1E);
  static const Color _buyRecordBodyColor = Color(0xFF64748B);
  static const Color _buyRecordMutedColor = Color(0xFF94A3B8);
  static const Color _buyRecordBrandColor = Color(0xFF1E40AF);
  static const Color _buyRecordSkeletonColor = Color(0xFFE2E8F0);
  static const String _defaultPurchaseSortField = 'time';
  static const bool _defaultPurchaseSortAsc = false;
  static const List<SortOption> _purchaseSortOptions = [
    SortOption(labelKey: 'app.market.filter.time', field: 'time'),
    SortOption(labelKey: 'app.market.filter.price', field: 'price'),
  ];
  static const List<SortOption> _purchaseRecordSortOptions = [
    SortOption(labelKey: 'app.market.filter.time', field: 'time'),
  ];
  static const List<String> _purchaseAttributeGroupOrder = [
    'type',
    'exterior',
    'quality',
    'rarity',
    'itemSet',
  ];
  final BuyRequestController controller =
      Get.isRegistered<BuyRequestController>()
      ? Get.find<BuyRequestController>()
      : Get.put(BuyRequestController());
  final UserController userController = Get.find<UserController>();
  final GlobalGameController _globalGameController =
      GlobalGameController.ensureInstance();

  late final TabController _tabController;
  late int _currentAppId;
  int _currentTabIndex = 0;
  final ScrollController _myBuyingScroll = ScrollController();
  final ScrollController _recordScroll = ScrollController();
  final TextEditingController _mySearchController = TextEditingController();
  final TextEditingController _recordSearchController = TextEditingController();
  Worker? _gameWorker;
  Worker? _loginWorker;

  bool get _isChineseLocale =>
      (Get.locale?.languageCode ?? '').toLowerCase().startsWith('zh');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabChange);
    _currentAppId = _globalGameController.appId;
    MarketFilterSheet.preload(appId: _currentAppId);
    _gameWorker = ever<int>(_globalGameController.currentAppId, (appId) {
      if (!mounted || appId == _currentAppId) {
        return;
      }
      setState(() => _currentAppId = appId);
      MarketFilterSheet.preload(appId: appId);
      controller.refreshMyBuying();
      controller.refreshBuyRecords();
    });
    _myBuyingScroll.addListener(_handleMyBuyingScroll);
    _recordScroll.addListener(_handleRecordScroll);
    _mySearchController.addListener(_handleSearchTextChange);
    _recordSearchController.addListener(_handleSearchTextChange);
    if (userController.isLoggedIn.value) {
      controller.refreshMyBuying();
      controller.refreshBuyRecords();
    }
    _loginWorker = ever<bool>(userController.isLoggedIn, (loggedIn) {
      if (loggedIn) {
        controller.refreshPurchaseStatus();
        controller.refreshMyBuying();
        controller.refreshBuyRecords();
      } else {
        controller.myBuying.clear();
        controller.buyRecords.clear();
        controller.schemas.clear();
        controller.totalMyBuying.value = 0;
        controller.totalRecords.value = 0;
      }
    });
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    _myBuyingScroll
      ..removeListener(_handleMyBuyingScroll)
      ..dispose();
    _recordScroll
      ..removeListener(_handleRecordScroll)
      ..dispose();
    _mySearchController.removeListener(_handleSearchTextChange);
    _recordSearchController.removeListener(_handleSearchTextChange);
    _gameWorker?.dispose();
    _loginWorker?.dispose();
    _mySearchController.dispose();
    _recordSearchController.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    final nextIndex = _tabController.index;
    if (!mounted || _currentTabIndex == nextIndex) {
      return;
    }
    setState(() => _currentTabIndex = nextIndex);
  }

  void _handleSearchTextChange() {
    if (mounted) {
      setState(() {});
    }
  }

  bool _shouldLoadMore(ScrollController scrollController) {
    if (!scrollController.hasClients) {
      return false;
    }
    final position = scrollController.position;
    if (position.outOfRange) {
      return false;
    }
    return position.extentAfter <= _loadMoreThreshold;
  }

  void _handleMyBuyingScroll() {
    if (!_shouldLoadMore(_myBuyingScroll) ||
        controller.isLoadingMyBuying.value ||
        !controller.myBuyingHasMore) {
      return;
    }
    controller.loadMyBuying();
  }

  void _handleRecordScroll() {
    if (!_shouldLoadMore(_recordScroll) ||
        controller.isLoadingRecords.value ||
        !controller.recordHasMore) {
      return;
    }
    controller.loadBuyRecords();
  }

  ShopSchemaInfo? _lookupSchema(BuyRequestItem item) {
    final key = item.schemaId?.toString();
    if (key != null && controller.schemas.containsKey(key)) {
      return controller.schemas[key];
    }
    return null;
  }

  String _formatTime(int? timestamp) {
    if (timestamp == null) {
      return '-';
    }
    var ts = timestamp;
    if (ts < 10000000000) {
      ts *= 1000;
    }
    final date = DateTime.fromMillisecondsSinceEpoch(ts);
    return DateFormat('yyyy-MM-dd HH:mm').format(date);
  }

  Future<void> _switchGame(int appId) async {
    if (appId == _globalGameController.appId) {
      return;
    }
    await _globalGameController.switchGame(appId);
  }

  void _showOfflineTips() {
    AppSnackbar.info('app.trade.purchase.offline_tips'.tr);
  }

  Future<void> _openBuyingPriceChange(
    BuyRequestItem item,
    ShopSchemaInfo? schema,
  ) async {
    if (!controller.purchaseOnline.value) {
      _showOfflineTips();
      return;
    }
    final result = await showFigmaModal<bool>(
      context: context,
      child: _PurchasePriceChangeDialog(
        item: item,
        schema: schema,
        currentAppId: _currentAppId,
      ),
    );
    if (result == true) {
      await controller.refreshMyBuying();
    }
  }

  Future<void> _confirmTerminateBuying(BuyRequestItem item) async {
    if (!controller.purchaseOnline.value) {
      _showOfflineTips();
      return;
    }
    final id = item.id?.toString();
    if (id == null) {
      return;
    }
    final title = _recordTitle(item, _lookupSchema(item));
    final confirm = await showFigmaModal<bool>(
      context: context,
      child: FigmaConfirmationDialog(
        title: _text(zh: '终止求购', en: 'Terminate Buy Request'),
        primaryLabel: _text(zh: '确认终止', en: 'Confirm Termination'),
        secondaryLabel: 'app.common.cancel'.tr,
        onPrimary: () => Navigator.of(context).pop(true),
        onSecondary: () => Navigator.of(context).pop(false),
        content: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: _text(
                  zh: '你确定要终止对 ',
                  en: 'Are you sure you want to terminate the buy request for ',
                ),
              ),
              TextSpan(
                text: '[$title]',
                style: const TextStyle(
                  color: Color(0xFF0F172A),
                  fontWeight: FontWeight.w600,
                ),
              ),
              TextSpan(
                text: _text(
                  zh: ' 吗？终止后资金将解除冻结。',
                  en: '? The funds will be unfrozen upon termination.',
                ),
              ),
            ],
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
    if (confirm == true) {
      AppRequestLoading.show();
      try {
        await controller.cancelBuy(id);
        AppSnackbar.success('app.system.message.success'.tr);
      } finally {
        AppRequestLoading.hide();
      }
    }
  }

  bool get _isMyBuyingTab => _currentTabIndex == 0;

  TextEditingController get _activeSearchController =>
      _isMyBuyingTab ? _mySearchController : _recordSearchController;

  ValueChanged<String> get _activeSearchSubmit =>
      _isMyBuyingTab ? controller.searchMyBuying : controller.searchRecords;

  Future<void> _submitActiveSearch() {
    if (_isMyBuyingTab) {
      return controller.searchMyBuying(_mySearchController.text);
    }
    return controller.searchRecords(_recordSearchController.text);
  }

  Map<String, dynamic> _normalizeFilterTags(Map<String, dynamic> source) {
    final tags = Map<String, dynamic>.from(source)
      ..removeWhere((key, value) => value == null || value.toString().isEmpty);
    return tags;
  }

  String _initialPurchaseSortField(String sortField) =>
      sortField.isEmpty ? _defaultPurchaseSortField : sortField;

  bool _initialPurchaseSortAsc({
    required String sortField,
    required bool sortAsc,
  }) {
    return sortField.isEmpty ? _defaultPurchaseSortAsc : sortAsc;
  }

  String _appliedPurchaseSortField(OrderFilterResult result) {
    final field = (result.sortField ?? '').trim();
    final asc = result.sortAsc ?? _defaultPurchaseSortAsc;
    if (field == _defaultPurchaseSortField && asc == _defaultPurchaseSortAsc) {
      return '';
    }
    return field;
  }

  bool _appliedPurchaseSortAsc(OrderFilterResult result) {
    final field = (result.sortField ?? '').trim();
    if (field.isEmpty) {
      return _defaultPurchaseSortAsc;
    }
    return result.sortAsc ?? _defaultPurchaseSortAsc;
  }

  bool _hasMyBuyingFilter() {
    if (controller.buyingSortField.isNotEmpty) {
      return true;
    }
    return controller.buyingTags.isNotEmpty;
  }

  bool _hasRecordFilter() {
    if (controller.recordSortField.isNotEmpty) {
      return true;
    }
    return controller.recordTags.isNotEmpty;
  }

  Future<void> _openMyBuyingFilterSheet() async {
    final currentTags = _normalizeFilterTags(controller.buyingTags);
    final result = await OrderFilterSheet.showFromRight(
      context: context,
      initial: OrderFilterResult(
        sortAsc: _initialPurchaseSortAsc(
          sortField: controller.buyingSortField,
          sortAsc: controller.buyingSortAsc.value,
        ),
        sortField: _initialPurchaseSortField(controller.buyingSortField),
        tags: currentTags,
      ),
      statusOptions: const [],
      sortOptions: _purchaseSortOptions,
      defaultSortField: _defaultPurchaseSortField,
      defaultSortAsc: _defaultPurchaseSortAsc,
      showSort: true,
      showStatus: false,
      showDateRange: false,
      enableAttributeFilter: true,
      attributeShowPriceRange: false,
      attributeGroupOrder: _purchaseAttributeGroupOrder,
      includeFallbackAttributeGroups: false,
      attributeUseFlatSections: true,
      appId: _currentAppId,
      sectionOrder: const [
        OrderFilterSectionCategory.sort,
        OrderFilterSectionCategory.attribute,
      ],
    );
    if (result != null) {
      await controller.applyMyBuyingFilter(
        sortAsc: result.reset
            ? _defaultPurchaseSortAsc
            : _appliedPurchaseSortAsc(result),
        sortField: result.reset ? '' : _appliedPurchaseSortField(result),
        tags: result.reset ? const <String, dynamic>{} : result.tags,
        itemName: '',
      );
      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<void> _openRecordFilterSheet() async {
    final currentTags = _normalizeFilterTags(controller.recordTags);
    final result = await OrderFilterSheet.showFromRight(
      context: context,
      initial: OrderFilterResult(
        sortAsc: _initialPurchaseSortAsc(
          sortField: controller.recordSortField,
          sortAsc: controller.recordSortAsc.value,
        ),
        sortField: _initialPurchaseSortField(controller.recordSortField),
        tags: currentTags,
      ),
      statusOptions: const [],
      sortOptions: _purchaseRecordSortOptions,
      defaultSortField: _defaultPurchaseSortField,
      defaultSortAsc: _defaultPurchaseSortAsc,
      showSort: true,
      showStatus: false,
      showDateRange: false,
      enableAttributeFilter: true,
      attributeGroupOrder: _purchaseAttributeGroupOrder,
      includeFallbackAttributeGroups: false,
      attributeUseFlatSections: true,
      appId: _currentAppId,
      sectionOrder: const [
        OrderFilterSectionCategory.sort,
        OrderFilterSectionCategory.attribute,
      ],
    );
    if (result != null) {
      await controller.applyRecordFilter(
        sortAsc: result.reset
            ? _defaultPurchaseSortAsc
            : _appliedPurchaseSortAsc(result),
        sortField: result.reset ? '' : _appliedPurchaseSortField(result),
        tags: result.reset ? const <String, dynamic>{} : result.tags,
        itemName: '',
      );
      if (mounted) {
        setState(() {});
      }
    }
  }

  String? _rawText(Map<String, dynamic> raw, List<String> keys) {
    for (final key in keys) {
      final value = raw[key];
      if (value != null) {
        return value.toString();
      }
    }
    return null;
  }

  int? _rawInt(Map<String, dynamic> raw, List<String> keys) {
    final text = _rawText(raw, keys);
    if (text == null) {
      return null;
    }
    return int.tryParse(text);
  }

  double? _rawDouble(Map<String, dynamic> raw, List<String> keys) {
    final text = _rawText(raw, keys);
    if (text == null) {
      return null;
    }
    return double.tryParse(text);
  }

  String _text({required String zh, required String en}) {
    return _isChineseLocale ? zh : en;
  }

  TagInfo? _schemaTag(ShopSchemaInfo? schema, String key) {
    final tags = schema?.raw['tags'];
    if (tags is Map) {
      return TagInfo.fromRaw(tags[key]);
    }
    return null;
  }

  String _gameLabelForAppId(int appId) {
    return switch (appId) {
      730 => 'CS2',
      570 => 'DOTA2',
      440 => 'TF2',
      _ => 'GAME',
    };
  }

  bool _isActiveTabFilterApplied() {
    if (_isMyBuyingTab) {
      return _hasMyBuyingFilter();
    }
    return _hasRecordFilter();
  }

  Future<void> _openActiveTabFilterSheet() {
    if (_isMyBuyingTab) {
      return _openMyBuyingFilterSheet();
    }
    return _openRecordFilterSheet();
  }

  Widget _buildTopIconAction({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: SizedBox(
            width: 34,
            height: 34,
            child: Icon(icon, size: 18, color: colors.onSurfaceVariant),
          ),
        ),
      ),
    );
  }

  Widget _buildTopActionWithDot({
    required Widget child,
    required Color dotColor,
    required bool visible,
  }) {
    if (!visible) {
      return child;
    }
    return Stack(
      children: [
        child,
        Positioned(
          right: 2,
          top: 2,
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
              border: Border.all(
                color: Theme.of(context).colorScheme.surface,
                width: 1,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPullToRefreshEmpty({
    required Future<void> Function() onRefresh,
  }) {
    return RefreshIndicator(
      color: _buyRecordBrandColor,
      backgroundColor: _buyRecordSurfaceColor,
      strokeWidth: 2.6,
      edgeOffset: 8,
      displacement: 24,
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        children: [
          const SizedBox(height: 180),
          Center(child: Text('app.common.no_data'.tr)),
        ],
      ),
    );
  }

  Widget _buildGameSwitchTrigger() {
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
                currentAppId: _currentAppId,
              );
              if (selected == null) {
                return;
              }
              await _switchGame(selected);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _gameLabelForAppId(_currentAppId),
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

  Widget _buildTabSearchBar() {
    final controller = _activeSearchController;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Row(
        children: [
          Expanded(
            child: AppSearchInputBar(
              controller: controller,
              hintText: 'app.market.filter.search'.tr,
              onSubmitted: _activeSearchSubmit,
              onChanged: (_) {
                if (mounted) {
                  setState(() {});
                }
              },
              onClearTap: () {
                controller.clear();
                _activeSearchSubmit('');
                if (mounted) {
                  setState(() {});
                }
              },
              onSearchTap: _submitActiveSearch,
            ),
          ),
          const SizedBox(width: 8),
          DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: HeaderFilterButton(
              tooltip: 'app.market.filter.text'.tr,
              active: _isActiveTabFilterApplied(),
              onTap: _openActiveTabFilterSheet,
              size: 40,
              iconSize: 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBuyTabBar() {
    final theme = Theme.of(context);

    return TabBar(
      controller: _tabController,
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
      labelStyle: theme.textTheme.titleSmall?.copyWith(
        fontSize: 16,
        height: 24 / 16,
        fontWeight: FontWeight.w700,
      ),
      unselectedLabelStyle: theme.textTheme.titleSmall?.copyWith(
        fontSize: 16,
        height: 24 / 16,
        fontWeight: FontWeight.w500,
      ),
      tabs: [
        Tab(height: 30, text: 'app.user.menu.purchase'.tr),
        Tab(height: 30, text: 'app.trade.purchase.record'.tr),
      ],
    );
  }

  Widget _buildHeader({required bool showInteractiveSections}) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      decoration: const BoxDecoration(
        color: settingsTopBarBackground,
        border: Border(bottom: BorderSide(color: settingsTopBarBorderColor)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SettingsStyleNavigationRow(
            title: 'app.user.menu.purchase'.tr,
            onBack: () => Navigator.of(context).maybePop(),
            actions: [
              if (showInteractiveSections) ...[
                Obx(() {
                  final isOnline = controller.purchaseOnline.value;
                  return _buildTopActionWithDot(
                    visible: true,
                    dotColor: isOnline
                        ? const Color(0xFF22C55E)
                        : colors.outlineVariant,
                    child: _buildTopIconAction(
                      icon: Icons.settings_outlined,
                      tooltip: 'app.trade.purchase.setting'.tr,
                      onTap: () => Get.toNamed(Routers.PURCHASE_SETTING),
                    ),
                  );
                }),
                const SizedBox(width: 8),
                _buildGameSwitchTrigger(),
              ],
            ],
          ),
          if (showInteractiveSections) ...[
            _buildTabSearchBar(),
            Align(alignment: Alignment.centerLeft, child: _buildBuyTabBar()),
          ],
        ],
      ),
    );
  }

  Widget _buildProgressBadge(BuyRequestItem item) {
    final received = item.received ?? 0;
    final total =
        item.need ?? item.nums ?? item.count ?? _recordDisplayQuantity(item);
    return Text(
      '$received/$total',
      style: const TextStyle(
        color: Color(0xFF0F172A),
        fontSize: 12,
        fontWeight: FontWeight.w700,
        height: 16 / 12,
      ),
    );
  }

  BoxDecoration _buildMyBuyingCardDecoration() {
    return BoxDecoration(
      color: _buyRecordSurfaceColor,
      borderRadius: BorderRadius.circular(8),
      boxShadow: const [
        BoxShadow(
          color: Color.fromRGBO(0, 0, 0, 0.05),
          blurRadius: 2,
          offset: Offset(0, 1),
        ),
      ],
    );
  }

  BoxDecoration _buildBuyRecordCardDecoration({
    Color color = _buyRecordSurfaceColor,
  }) {
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(8),
      boxShadow: const [
        BoxShadow(
          color: Color.fromRGBO(0, 0, 0, 0.03),
          blurRadius: 20,
          offset: Offset(0, 4),
        ),
      ],
    );
  }

  String _recordTitle(BuyRequestItem item, ShopSchemaInfo? schema) {
    return schema?.marketName ??
        schema?.marketHashName ??
        item.raw['market_name']?.toString() ??
        '-';
  }

  int _recordDisplayQuantity(BuyRequestItem item) {
    final quantity =
        item.nums ??
        _rawInt(item.raw, const ['nums']) ??
        item.count ??
        _rawInt(item.raw, const ['count']);
    if (quantity != null && quantity > 0) {
      return quantity;
    }
    return 1;
  }

  int? _recordBadgeCount(BuyRequestItem item) {
    final count = _recordDisplayQuantity(item);
    if (count > 1) {
      return count;
    }
    return null;
  }

  double _recordUnitPrice(BuyRequestItem item) {
    return item.price ??
        _rawDouble(item.raw, const ['price', 'unit_price', 'unitPrice']) ??
        0;
  }

  int _recordSettledQuantity(BuyRequestItem item) {
    final received =
        item.received ??
        _rawInt(item.raw, const [
          'received',
          'settled_nums',
          'settledNums',
          'done_count',
          'doneCount',
          'success_count',
          'successCount',
        ]);
    if (received != null && received > 0) {
      return received;
    }
    if (_isRecordCompleted(item)) {
      return _recordDisplayQuantity(item);
    }
    return 0;
  }

  double _recordSettledAmount(BuyRequestItem item) {
    final rawTotal = _rawDouble(item.raw, const [
      'settled_price',
      'settledPrice',
      'done_price',
      'donePrice',
      'success_price',
      'successPrice',
      'total_price',
      'totalPrice',
    ]);
    if (rawTotal != null && rawTotal > 0) {
      return rawTotal;
    }
    return _recordUnitPrice(item) * _recordSettledQuantity(item);
  }

  double _recordRequestedAmount(BuyRequestItem item) {
    return _recordUnitPrice(item) * _recordDisplayQuantity(item);
  }

  bool _textContainsAny(String source, List<String> keywords) {
    for (final keyword in keywords) {
      if (source.contains(keyword)) {
        return true;
      }
    }
    return false;
  }

  bool _isRecordCompleted(BuyRequestItem item) {
    final normalized = (item.statusName ?? '').trim().toLowerCase();
    return item.status == 1 ||
        _textContainsAny(normalized, const [
          'complete',
          'completed',
          'success',
          'done',
          '已完成',
          '完成',
          '交易成功',
        ]);
  }

  bool _isRecordExpired(BuyRequestItem item) {
    final normalized = (item.statusName ?? '').trim().toLowerCase();
    return _textContainsAny(normalized, const [
      'expire',
      'expired',
      'timeout',
      '已过期',
      '过期',
    ]);
  }

  bool _isRecordCancelled(BuyRequestItem item) {
    final normalized = (item.statusName ?? '').trim().toLowerCase();
    return _textContainsAny(normalized, const [
      'cancel',
      'cancelled',
      'canceled',
      'closed',
      'terminate',
      '已取消',
      '取消',
      '已关闭',
      '终止',
    ]);
  }

  String _recordStatusLabel(BuyRequestItem item) {
    final text = item.statusName?.trim();
    if (text != null && text.isNotEmpty) {
      return text;
    }
    if (_isRecordCompleted(item)) {
      return _text(zh: '已完成', en: 'Completed');
    }
    if (_isRecordExpired(item)) {
      return _text(zh: '已过期', en: 'Expired');
    }
    if (_isRecordCancelled(item)) {
      return _text(zh: '已取消', en: 'Cancelled');
    }
    return _text(zh: '处理中', en: 'Processing');
  }

  _BuyRecordStatusStyle _recordStatusStyle(BuyRequestItem item) {
    if (_isRecordCompleted(item)) {
      return const _BuyRecordStatusStyle(
        backgroundColor: Color(0xFFF0FDF4),
        foregroundColor: Color(0xFF16A34A),
        icon: Icons.check_circle_rounded,
      );
    }
    if (_isRecordExpired(item)) {
      return const _BuyRecordStatusStyle(
        backgroundColor: Color(0xFFFFF7ED),
        foregroundColor: Color(0xFFEA580C),
        icon: Icons.schedule_rounded,
      );
    }
    return const _BuyRecordStatusStyle(
      backgroundColor: Color(0xFFF1F5F9),
      foregroundColor: Color(0xFF64748B),
      icon: Icons.cancel_rounded,
    );
  }

  Widget _buildRecordStatusChip(BuyRequestItem item) {
    final style = _recordStatusStyle(item);
    return Container(
      constraints: const BoxConstraints(minHeight: 24),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: style.backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(style.icon, size: 12, color: style.foregroundColor),
          const SizedBox(width: 4),
          Text(
            _recordStatusLabel(item),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: style.foregroundColor,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              height: 15 / 11,
              letterSpacing: _isChineseLocale ? 0 : 0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordPreviewImage(BuyRequestItem item, ShopSchemaInfo? schema) {
    final badgeCount = _recordBadgeCount(item);
    return SizedBox(
      width: 64,
      height: 64,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: _buyRecordSoftSurfaceColor,
              borderRadius: BorderRadius.circular(4),
            ),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: GameItemImage(
                imageUrl: schema?.imageUrl,
                appId: item.appId ?? _currentAppId,
                rarity: _schemaTag(schema, 'rarity'),
                quality: _schemaTag(schema, 'quality'),
                exterior: _schemaTag(schema, 'exterior'),
                showTopBadges: false,
              ),
            ),
          ),
          if (badgeCount != null)
            Positioned(
              right: -4,
              top: -4,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                alignment: Alignment.center,
                child: Text(
                  '$badgeCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    height: 1,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRecordSummaryRow({
    required String label,
    required Widget value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: _buyRecordBodyColor,
              fontSize: 12,
              fontWeight: FontWeight.w500,
              height: 18 / 12,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Align(alignment: Alignment.centerRight, child: value),
        ),
      ],
    );
  }

  String _recordFormulaText(
    BuyRequestItem item,
    CurrencyController currency, {
    required bool settled,
  }) {
    final quantity = settled
        ? _recordSettledQuantity(item)
        : _recordDisplayQuantity(item);
    final amount = settled
        ? _recordSettledAmount(item)
        : _recordRequestedAmount(item);
    return '${currency.format(_recordUnitPrice(item))} x $quantity = ${currency.format(amount)}';
  }

  String _recordSupplyDemandText(BuyRequestItem item) {
    final supplied =
        item.received ??
        _rawInt(item.raw, const [
          'received',
          'settled_nums',
          'settledNums',
          'done_count',
          'doneCount',
          'success_count',
          'successCount',
        ]) ??
        0;
    final demanded =
        item.need ??
        _rawInt(item.raw, const ['need']) ??
        item.nums ??
        _rawInt(item.raw, const ['nums']) ??
        item.count ??
        _rawInt(item.raw, const ['count']) ??
        1;
    return '$supplied/$demanded';
  }

  Widget _buildRecordSummaryPanel(BuyRequestItem item) {
    final isCompleted = _isRecordCompleted(item);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      decoration: BoxDecoration(
        color: _buyRecordSoftSurfaceColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Obx(() {
        final currency = Get.find<CurrencyController>();
        final primaryLabel = isCompleted
            ? _text(zh: '单价', en: 'Unit Price')
            : _text(zh: '汇总', en: 'Summary');
        final primaryText = _recordFormulaText(
          item,
          currency,
          settled: isCompleted,
        );
        final primaryStyle = isCompleted
            ? const TextStyle(
                color: _buyRecordBodyColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 18 / 12,
              )
            : const TextStyle(
                color: _buyRecordTitleColor,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                height: 20 / 14,
              );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildRecordSummaryRow(
              label: primaryLabel,
              value: Text(
                primaryText,
                textAlign: TextAlign.right,
                style: primaryStyle,
              ),
            ),
            const SizedBox(height: 12),
            _buildRecordSummaryRow(
              label: _text(zh: '供给数/求购数', en: 'Supplied/Demanded'),
              value: Text(
                _recordSupplyDemandText(item),
                textAlign: TextAlign.right,
                style: const TextStyle(
                  color: _buyRecordBodyColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  height: 18 / 12,
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildMyBuyingPreviewTile(
    BuyRequestItem item,
    ShopSchemaInfo? schema,
  ) {
    const previewSize = 96.0;

    return Container(
      width: previewSize,
      height: previewSize,
      decoration: BoxDecoration(
        color: _buyRecordSoftSurfaceColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: GameItemImage(
          imageUrl: schema?.imageUrl,
          appId: item.appId ?? _currentAppId,
          rarity: _schemaTag(schema, 'rarity'),
          quality: _schemaTag(schema, 'quality'),
          exterior: _schemaTag(schema, 'exterior'),
          phase: item.phase,
          showTopBadges: false,
        ),
      ),
    );
  }

  Widget _buildMyBuyingPriceRow({
    required String label,
    required String value,
    required TextStyle valueStyle,
    bool preserveValue = false,
  }) {
    final labelWidth = _isChineseLocale ? 48.0 : 76.0;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: labelWidth,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _buyRecordBodyColor,
              fontSize: 12,
              fontWeight: FontWeight.w400,
              height: 16 / 12,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: preserveValue
              ? SizedBox(
                  width: double.infinity,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      value,
                      softWrap: false,
                      textAlign: TextAlign.right,
                      style: valueStyle,
                    ),
                  ),
                )
              : Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: valueStyle,
                ),
        ),
      ],
    );
  }

  String _myBuyingStatusLabel(BuyRequestItem item) {
    final status = item.statusName?.trim();
    if (status != null && status.isNotEmpty) {
      return status;
    }
    return _text(zh: '在售中', en: 'On Selling');
  }

  Widget _buildBuyRequestSummary(BuyRequestItem item, ShopSchemaInfo? schema) {
    final currency = Get.find<CurrencyController>();
    final title =
        schema?.marketName ??
        schema?.marketHashName ??
        item.raw['market_name']?.toString() ??
        '-';
    final wearMin =
        _rawText(item.raw, const ['paint_wear_min', 'paintWearMin']) ??
        item.paintWearMin?.toString();
    final wearMax =
        _rawText(item.raw, const ['paint_wear_max', 'paintWearMax']) ??
        item.paintWearMax?.toString();
    final titleSuffix = wearMin != null && wearMax != null
        ? ' (${_text(zh: '$wearMin-$wearMax', en: '$wearMin-$wearMax')})'
        : '';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildMyBuyingPreviewTile(item, schema),
        const SizedBox(width: 16),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Obx(() {
              final unitPrice = currency.format(_recordUnitPrice(item));

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$title$titleSuffix',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF0F172A),
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      height: 22.5 / 15,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildMyBuyingPriceRow(
                    label: _text(zh: '单价', en: 'Unit Price'),
                    value: unitPrice,
                    preserveValue: true,
                    valueStyle: const TextStyle(
                      color: _buyRecordBrandColor,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      height: 28 / 18,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _buildMyBuyingPriceRow(
                    label: _text(zh: '状态', en: 'Status'),
                    value: _myBuyingStatusLabel(item),
                    valueStyle: const TextStyle(
                      color: Color(0xFF16A34A),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 16 / 12,
                    ),
                  ),
                ],
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildCompactActionLabel(String text) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
    );
  }

  ButtonStyle _buildPrimaryActionButtonStyle() {
    final textStyle = Theme.of(context).textTheme.labelLarge?.copyWith(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      height: 20 / 14,
    );
    return FilledButton.styleFrom(
      backgroundColor: const Color(0xFF3B82F6),
      foregroundColor: Colors.white,
      elevation: 0,
      minimumSize: const Size(0, _myBuyingActionHeight),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      textStyle: textStyle,
    );
  }

  ButtonStyle _buildDangerActionButtonStyle() {
    final textStyle = Theme.of(context).textTheme.labelLarge?.copyWith(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      height: 20 / 14,
    );
    return OutlinedButton.styleFrom(
      minimumSize: const Size(0, _myBuyingActionHeight),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      side: const BorderSide(color: Color(0xFFFECACA)),
      foregroundColor: const Color(0xFFDC2626),
      backgroundColor: Colors.white,
      textStyle: textStyle,
    );
  }

  Widget _buildMyBuyingActions(BuyRequestItem item, ShopSchemaInfo? schema) {
    Widget buildPriceChangeButton() {
      return FilledButton(
        onPressed: () => _openBuyingPriceChange(item, schema),
        style: _buildPrimaryActionButtonStyle(),
        child: _buildCompactActionLabel('app.inventory.price_change'.tr),
      );
    }

    Widget buildTerminateButton() {
      return OutlinedButton(
        onPressed: () => _confirmTerminateBuying(item),
        style: _buildDangerActionButtonStyle(),
        child: _buildCompactActionLabel(_text(zh: '终止求购', en: 'Termination')),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 280) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              buildPriceChangeButton(),
              const SizedBox(height: 12),
              buildTerminateButton(),
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: buildPriceChangeButton()),
            const SizedBox(width: 12),
            Expanded(child: buildTerminateButton()),
          ],
        );
      },
    );
  }

  Widget _buildMyBuyingItem(BuyRequestItem item) {
    final schema = _lookupSchema(item);
    return DecoratedBox(
      decoration: _buildMyBuyingCardDecoration(),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _formatTime(item.upTime ?? item.createTime),
                    style: const TextStyle(
                      color: _buyRecordBodyColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      height: 16 / 12,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                _buildProgressBadge(item),
              ],
            ),
            const SizedBox(height: 16),
            _buildBuyRequestSummary(item, schema),
            const SizedBox(height: 16),
            _buildMyBuyingActions(item, schema),
          ],
        ),
      ),
    );
  }

  Widget _buildMyBuyingSkeletonList({int count = 3, bool shrinkWrap = false}) {
    return ListView.separated(
      controller: shrinkWrap ? null : _myBuyingScroll,
      shrinkWrap: shrinkWrap,
      physics: const NeverScrollableScrollPhysics(),
      padding: shrinkWrap
          ? EdgeInsets.zero
          : const EdgeInsets.fromLTRB(12, 8, 12, 16),
      itemCount: count,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, __) => _buildMyBuyingSkeletonCard(),
    );
  }

  Widget _buildMyBuyingSkeletonCard() {
    return Container(
      decoration: _buildMyBuyingCardDecoration(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildSkeletonBox(width: 108, height: 12, radius: 6),
              ),
              const SizedBox(width: 12),
              _buildSkeletonBox(width: 28, height: 12, radius: 6),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSkeletonBox(width: 96, height: 96, radius: 8),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildSkeletonBox(width: 44, height: 19, radius: 2),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildSkeletonBox(
                            width: double.infinity,
                            height: 15,
                            radius: 8,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildSkeletonBox(
                            width: double.infinity,
                            height: 12,
                            radius: 6,
                          ),
                        ),
                        const SizedBox(width: 12),
                        _buildSkeletonBox(width: 40, height: 18, radius: 8),
                      ],
                    ),
                    const SizedBox(height: 4),
                    _buildSkeletonBox(
                      width: double.infinity,
                      height: 12,
                      radius: 6,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: _buildSkeletonBox(
                            width: double.infinity,
                            height: 12,
                            radius: 6,
                          ),
                        ),
                        const SizedBox(width: 12),
                        _buildSkeletonBox(width: 52, height: 14, radius: 8),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildSkeletonBox(
                  width: double.infinity,
                  height: _myBuyingActionHeight,
                  radius: 8,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSkeletonBox(
                  width: double.infinity,
                  height: _myBuyingActionHeight,
                  radius: 8,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecordItem(BuyRequestItem item) {
    final schema = _lookupSchema(item);
    return Container(
      decoration: _buildBuyRecordCardDecoration(),
      child: Padding(
        padding: const EdgeInsets.all(21),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _text(zh: '下单时间', en: 'ORDER DATE'),
                        style: TextStyle(
                          color: _buyRecordMutedColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          height: 15 / 10,
                          letterSpacing: _isChineseLocale ? 0 : 1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatTime(item.createTime ?? item.upTime),
                        style: const TextStyle(
                          color: _buyRecordTitleColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          height: 18 / 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _buildRecordStatusChip(item),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildRecordPreviewImage(item, schema),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _recordTitle(item, schema),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _buyRecordTitleColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          height: 24 / 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildRecordSummaryPanel(item),
          ],
        ),
      ),
    );
  }

  Widget _buildBuyRecordSkeletonList({int count = 3, bool shrinkWrap = false}) {
    return ListView.separated(
      controller: shrinkWrap ? null : _recordScroll,
      shrinkWrap: shrinkWrap,
      physics: shrinkWrap
          ? const NeverScrollableScrollPhysics()
          : const AlwaysScrollableScrollPhysics(),
      padding: shrinkWrap
          ? EdgeInsets.zero
          : const EdgeInsets.fromLTRB(12, 8, 12, 16),
      itemCount: count,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, __) => _buildBuyRecordSkeletonCard(),
    );
  }

  Widget _buildBuyRecordSkeletonCard() {
    return Container(
      decoration: _buildBuyRecordCardDecoration(),
      padding: const EdgeInsets.all(21),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSkeletonBox(width: 76, height: 10, radius: 6),
                    const SizedBox(height: 6),
                    _buildSkeletonBox(width: 124, height: 12, radius: 6),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _buildSkeletonBox(width: 88, height: 24, radius: 12),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildSkeletonBox(width: 64, height: 64, radius: 4),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSkeletonBox(width: 168, height: 16, radius: 8),
                    const SizedBox(height: 8),
                    _buildSkeletonBox(width: 96, height: 12, radius: 6),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
            decoration: BoxDecoration(
              color: _buyRecordSoftSurfaceColor,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildSkeletonBox(
                        width: double.infinity,
                        height: 12,
                        radius: 6,
                      ),
                    ),
                    const SizedBox(width: 12),
                    _buildSkeletonBox(width: 136, height: 12, radius: 6),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildSkeletonBox(
                        width: double.infinity,
                        height: 12,
                        radius: 6,
                      ),
                    ),
                    const SizedBox(width: 12),
                    _buildSkeletonBox(width: 112, height: 12, radius: 6),
                  ],
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
        color: _buyRecordSkeletonColor,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isLoggedIn = userController.isLoggedIn.value;
      return Scaffold(
        backgroundColor: const Color(0xFFF7F9FB),
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _buildHeader(showInteractiveSections: isLoggedIn),
              Expanded(
                child: isLoggedIn
                    ? BackToTopScope(
                        enabled: false,
                        child: TabBarView(
                          controller: _tabController,
                          children: [_buildMyBuyingTab(), _buildRecordTab()],
                        ),
                      )
                    : const LoginRequiredPrompt(),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildMyBuyingTab() {
    return Obx(() {
      if (controller.isLoadingMyBuying.value && controller.myBuying.isEmpty) {
        return _buildMyBuyingSkeletonList();
      }
      if (controller.myBuying.isEmpty) {
        return _buildPullToRefreshEmpty(onRefresh: controller.refreshMyBuying);
      }
      final showLoadingFooter =
          controller.isLoadingMyBuying.value && controller.myBuying.isNotEmpty;
      final showNoMoreFooter =
          controller.myBuying.isNotEmpty &&
          !controller.isLoadingMyBuying.value &&
          !controller.myBuyingHasMore;
      final showFooter = showLoadingFooter || showNoMoreFooter;

      return BackToTopScope(
        enabled: true,
        child: RefreshIndicator(
          color: _buyRecordBrandColor,
          backgroundColor: _buyRecordSurfaceColor,
          strokeWidth: 2.6,
          edgeOffset: 8,
          displacement: 24,
          onRefresh: controller.refreshMyBuying,
          child: ListView.separated(
            controller: _myBuyingScroll,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
            itemCount: controller.myBuying.length + (showFooter ? 1 : 0),
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              if (index >= controller.myBuying.length) {
                return _buildMyBuyingLoadMoreFooter(
                  loading: showLoadingFooter,
                  hasMore: controller.myBuyingHasMore,
                );
              }
              final item = controller.myBuying[index];
              return _buildMyBuyingItem(item);
            },
          ),
        ),
      );
    });
  }

  Widget _buildMyBuyingLoadMoreFooter({
    required bool loading,
    required bool hasMore,
  }) {
    if (loading && hasMore) {
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: _buildMyBuyingSkeletonList(count: 2, shrinkWrap: true),
      );
    }
    if (!hasMore) {
      return const ListEndTip(padding: EdgeInsets.fromLTRB(8, 6, 8, 12));
    }
    return const SizedBox(height: 4);
  }

  Widget _buildRecordTab() {
    return Obx(() {
      if (controller.isLoadingRecords.value && controller.buyRecords.isEmpty) {
        return _buildBuyRecordSkeletonList();
      }
      if (controller.buyRecords.isEmpty) {
        return _buildPullToRefreshEmpty(
          onRefresh: controller.refreshBuyRecords,
        );
      }
      final showLoadingFooter =
          controller.isLoadingRecords.value && controller.buyRecords.isNotEmpty;
      final showNoMoreFooter =
          controller.buyRecords.isNotEmpty &&
          !controller.isLoadingRecords.value &&
          !controller.recordHasMore;
      final showFooter = showLoadingFooter || showNoMoreFooter;

      return BackToTopScope(
        enabled: true,
        child: RefreshIndicator(
          color: _buyRecordBrandColor,
          backgroundColor: _buyRecordSurfaceColor,
          strokeWidth: 2.6,
          edgeOffset: 8,
          displacement: 24,
          onRefresh: controller.refreshBuyRecords,
          child: ListView.separated(
            controller: _recordScroll,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
            itemCount: controller.buyRecords.length + (showFooter ? 1 : 0),
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              if (index >= controller.buyRecords.length) {
                return _buildRecordLoadMoreFooter(
                  loading: showLoadingFooter,
                  hasMore: controller.recordHasMore,
                );
              }
              final item = controller.buyRecords[index];
              return _buildRecordItem(item);
            },
          ),
        ),
      );
    });
  }

  Widget _buildRecordLoadMoreFooter({
    required bool loading,
    required bool hasMore,
  }) {
    if (loading && hasMore) {
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: _buildBuyRecordSkeletonList(count: 2, shrinkWrap: true),
      );
    }
    if (!hasMore) {
      return const ListEndTip(padding: EdgeInsets.fromLTRB(8, 6, 8, 12));
    }
    return const SizedBox(height: 4);
  }
}

class _PurchasePriceChangeDialog extends StatefulWidget {
  const _PurchasePriceChangeDialog({
    required this.item,
    required this.schema,
    required this.currentAppId,
  });

  final BuyRequestItem item;
  final ShopSchemaInfo? schema;
  final int currentAppId;

  @override
  State<_PurchasePriceChangeDialog> createState() =>
      _PurchasePriceChangeDialogState();
}

class _PurchasePriceChangeDialogState
    extends State<_PurchasePriceChangeDialog> {
  static const double _minTradePrice = 0.02;

  final ApiShopProductServer _api = ApiShopProductServer();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _numController = TextEditingController();

  double _minPrice = 0;
  double _referencePrice = 0;
  bool _isSubmitting = false;
  bool _isLoadingReferencePrice = false;

  Map<String, dynamic> get _schemaRaw => widget.schema?.raw ?? const {};

  @override
  void initState() {
    super.initState();
    _priceController.text = _normalizeDisplayPrice(widget.item.price ?? 0);
    _numController.text = (widget.item.nums ?? widget.item.count ?? 1)
        .toString();
    _loadParams();
  }

  @override
  void dispose() {
    _priceController.dispose();
    _numController.dispose();
    super.dispose();
  }

  String get _title =>
      widget.schema?.marketName ??
      widget.schema?.marketHashName ??
      widget.item.raw['market_name']?.toString() ??
      '-';

  String? _itemRawText(List<String> keys) {
    for (final key in keys) {
      final value = widget.item.raw[key];
      if (value != null) {
        return value.toString();
      }
    }
    return null;
  }

  TagInfo? _dialogSchemaTag(String key) {
    final tags = widget.schema?.raw['tags'];
    if (tags is Map) {
      return TagInfo.fromRaw(tags[key]);
    }
    return null;
  }

  double _truncateTo2(double value) {
    return (value * 100).floor() / 100;
  }

  String _normalizeDisplayPrice(double value) {
    if (value <= 0) {
      return '';
    }
    final normalized = _truncateTo2(value);
    return normalized.toStringAsFixed(2);
  }

  Future<void> _loadParams() async {
    final res = await _api.getSysParams();
    final raw = res.datas;
    if (raw is Map<String, dynamic>) {
      final minValue = raw['minPrice'];
      if (minValue is num) {
        _minPrice = max(minValue.toDouble(), _minTradePrice);
      } else {
        _minPrice = max(
          double.tryParse(minValue?.toString() ?? '') ?? 0,
          _minTradePrice,
        );
      }
    }
    await _loadReferencePrice(silentError: true);
  }

  double _sellMin() {
    final sellMin = _buyingParseDouble(_schemaRaw['sell_min']);
    final buffMin = _buyingParseDouble(_schemaRaw['buff_min_price']);
    final candidates = [
      sellMin,
      buffMin,
    ].whereType<double>().where((value) => value > 0).toList();
    if (candidates.isEmpty) {
      return 0;
    }
    final minMarket = candidates.reduce(min);
    return minMarket > _minTradePrice ? minMarket : _minTradePrice;
  }

  double _buyMax() {
    return _buyingParseDouble(_schemaRaw['buy_max']) ?? 0;
  }

  Future<void> _loadReferencePrice({bool silentError = false}) async {
    final schemaId =
        widget.item.schemaId ??
        int.tryParse(widget.schema?.raw['id']?.toString() ?? '');
    if (schemaId == null) {
      return;
    }
    if (mounted) {
      setState(() => _isLoadingReferencePrice = true);
    } else {
      _isLoadingReferencePrice = true;
    }
    try {
      final res = await _api.getOrderBuyingMinPrice(
        appId: widget.item.appId ?? widget.currentAppId,
        schemaId: schemaId,
      );
      _referencePrice = res.datas ?? 0;
    } catch (_) {
      if (!silentError) {
        AppSnackbar.error('app.trade.filter.failed'.tr);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingReferencePrice = false);
      } else {
        _isLoadingReferencePrice = false;
      }
    }
  }

  double _totalAmount() {
    final price = double.tryParse(_priceController.text) ?? 0;
    final num = int.tryParse(_numController.text) ?? 0;
    return price * num;
  }

  Future<void> _applyMaxPrice() async {
    if (_isLoadingReferencePrice) {
      return;
    }
    if (_referencePrice <= 0) {
      await _loadReferencePrice();
    }
    final value = _referencePrice;
    if (value <= 0) {
      AppSnackbar.error('app.trade.filter.failed'.tr);
      return;
    }
    _priceController.text = _normalizeDisplayPrice(value);
    _priceController.selection = TextSelection.fromPosition(
      TextPosition(offset: _priceController.text.length),
    );
    if (mounted) {
      setState(() {});
    }
  }

  bool _hasMoreThanTwoDecimals(String value) {
    final dotIndex = value.indexOf('.');
    if (dotIndex < 0) {
      return false;
    }
    return value.length - dotIndex - 1 > 2;
  }

  void _sanitizePrice(String value) {
    setState(() {});
  }

  void _normalizePriceOnBlur() {
    setState(() {});
  }

  void _sanitizeNum(String value) {
    setState(() {});
  }

  Future<void> _submit() async {
    if (_isSubmitting) {
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    final priceText = _priceController.text.trim();
    final numText = _numController.text.trim();
    final normalizedPriceText = priceText.endsWith('.') && priceText.length > 1
        ? priceText.substring(0, priceText.length - 1)
        : priceText;
    if (normalizedPriceText.isEmpty) {
      AppSnackbar.error('app.market.filter.message.price_error'.tr);
      return;
    }
    if (_hasMoreThanTwoDecimals(normalizedPriceText)) {
      AppSnackbar.error('app.market.filter.message.price_error'.tr);
      return;
    }
    final price = double.tryParse(normalizedPriceText);
    if (price == null || price <= 0) {
      AppSnackbar.error('app.market.filter.message.price_error'.tr);
      return;
    }
    final nums = int.tryParse(numText);
    if (nums == null || nums <= 0) {
      AppSnackbar.error('app.trade.purchase.message.num_error'.tr);
      return;
    }
    if (nums > 200) {
      AppSnackbar.error('app.market.detail.bulk_buying.num_error'.tr);
      return;
    }
    final effectiveMinPrice = _minPrice > 0 ? _minPrice : _minTradePrice;
    if (price < effectiveMinPrice) {
      AppSnackbar.error('app.trade.purchase.message.min_price_error'.tr);
      return;
    }
    final sellMin = _sellMin();
    final shouldConfirm = price >= 10 && sellMin > 0 && price > sellMin;
    if (shouldConfirm) {
      final confirm = await showFigmaModal<bool>(
        context: context,
        child: FigmaConfirmationDialog(
          title: 'app.system.tips.title'.tr,
          message: 'app.trade.purchase.message.confirm_to_buy'.tr,
          primaryLabel: 'app.common.confirm'.tr,
          secondaryLabel: 'app.common.cancel'.tr,
          onPrimary: () => Navigator.of(context).pop(true),
          onSecondary: () => Navigator.of(context).pop(false),
        ),
      );
      if (confirm != true) {
        return;
      }
    }
    setState(() => _isSubmitting = true);
    AppRequestLoading.show();
    var shouldClose = false;
    try {
      final res = await _api.myBuyUpdatePrice(
        items: [
          {'id': widget.item.id, 'price': price, 'nums': nums},
        ],
      );
      if (!res.success) {
        final dataText = res.datas?.toString().trim();
        final errorText = (dataText?.isNotEmpty ?? false)
            ? dataText!
            : (res.message.trim().isNotEmpty
                  ? res.message
                  : 'app.trade.filter.failed'.tr);
        AppSnackbar.error(errorText);
        return;
      }
      shouldClose = true;
      if (mounted) {
        Navigator.of(context).pop(true);
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        AppSnackbar.success('app.inventory.message.price_change_success'.tr);
      });
    } finally {
      AppRequestLoading.hide();
      if (mounted && !shouldClose) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Widget _buildPreviewCard() {
    final currency = Get.find<CurrencyController>();
    final wearMin =
        _itemRawText(const ['paint_wear_min', 'paintWearMin']) ??
        widget.item.paintWearMin?.toString();
    final wearMax =
        _itemRawText(const ['paint_wear_max', 'paintWearMax']) ??
        widget.item.paintWearMax?.toString();
    final wearText = wearMin != null && wearMax != null
        ? '${'app.market.filter.csgo.wear_interval'.tr}: $wearMin - $wearMax'
        : null;
    final lowestLabel = _textForLocale(zh: '最低在售价', en: 'Lowest On Sale');
    final highestLabel = _textForLocale(zh: '当前最高价', en: 'Current Highest');
    final lowestSaleText = currency.format(_sellMin());
    final highestText = currency.format(_buyMax());

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: _BuyingPageState._buyRecordSoftSurfaceColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFF1F5F9)),
            ),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: GameItemImage(
                imageUrl: widget.schema?.imageUrl,
                appId: widget.item.appId ?? widget.currentAppId,
                rarity: _dialogSchemaTag('rarity'),
                quality: _dialogSchemaTag('quality'),
                exterior: _dialogSchemaTag('exterior'),
                phase: widget.item.phase,
                showTopBadges: false,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF191C1E),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    height: 20 / 14,
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '$lowestLabel: ',
                            style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 11,
                              fontWeight: FontWeight.w400,
                              height: 16 / 11,
                            ),
                          ),
                          TextSpan(
                            text: lowestSaleText,
                            style: const TextStyle(
                              color: Color(0xFF191C1E),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              height: 16 / 11,
                            ),
                          ),
                        ],
                      ),
                      softWrap: false,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  width: double.infinity,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '$highestLabel: ',
                            style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 11,
                              fontWeight: FontWeight.w400,
                              height: 16 / 11,
                            ),
                          ),
                          TextSpan(
                            text: highestText,
                            style: const TextStyle(
                              color: Color(0xFF191C1E),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              height: 16 / 11,
                            ),
                          ),
                        ],
                      ),
                      softWrap: false,
                    ),
                  ),
                ),
                if (wearText != null) ...[
                  const SizedBox(height: 4),
                  SizedBox(
                    width: double.infinity,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        wearText,
                        softWrap: false,
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                          height: 16 / 11,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputShell({
    required String prefix,
    required TextEditingController controller,
    required TextInputType keyboardType,
    required ValueChanged<String> onChanged,
    VoidCallback? onEditingComplete,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color.fromRGBO(224, 227, 229, 0.50),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 15),
      child: Row(
        children: [
          Text(
            prefix,
            style: const TextStyle(
              color: Color(0xFF191C1E),
              fontSize: 16,
              fontWeight: FontWeight.w700,
              height: 24 / 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: keyboardType,
              onChanged: onChanged,
              onEditingComplete: onEditingComplete,
              enabled: !_isSubmitting,
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              style: const TextStyle(
                color: Color(0xFF757684),
                fontSize: 18,
                fontWeight: FontWeight.w700,
                height: 24 / 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _textForLocale({required String zh, required String en}) {
    final code = Get.locale?.languageCode.toLowerCase() ?? '';
    return code.startsWith('zh') ? zh : en;
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final currency = Get.find<CurrencyController>();
    final payableText = currency.format(_totalAmount());

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: 320,
        maxHeight: media.size.height * 0.88,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(
              color: Color.fromRGBO(0, 0, 0, 0.10),
              blurRadius: 50,
              offset: Offset(0, 20),
            ),
          ],
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPreviewCard(),
              const SizedBox(height: 20),
              Row(
                children: [
                  Text(
                    _textForLocale(zh: '新求购价', en: 'NEW BUY PRICE'),
                    style: const TextStyle(
                      color: Color(0xFF444653),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 16 / 12,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: (_isSubmitting || _isLoadingReferencePrice)
                        ? null
                        : _applyMaxPrice,
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF1E40AF),
                      backgroundColor: const Color.fromRGBO(30, 64, 175, 0.08),
                      minimumSize: const Size(0, 30),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                        side: const BorderSide(
                          color: Color.fromRGBO(30, 64, 175, 0.16),
                        ),
                      ),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Text(
                      'Reference Pricing',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        height: 16 / 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildInputShell(
                prefix: '¥',
                controller: _priceController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: _sanitizePrice,
                onEditingComplete: _normalizePriceOnBlur,
              ),
              const SizedBox(height: 18),
              Text(
                _textForLocale(zh: '数量', en: 'QUANTITY'),
                style: const TextStyle(
                  color: Color(0xFF444653),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  height: 16 / 12,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 12),
              _buildInputShell(
                prefix: '#',
                controller: _numController,
                keyboardType: TextInputType.number,
                onChanged: _sanitizeNum,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    'app.trade.purchase.payable'.tr,
                    style: const TextStyle(
                      color: Color(0xFF444653),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      height: 18 / 12,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    payableText,
                    style: const TextStyle(
                      color: Color(0xFF1E40AF),
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      height: 24 / 16,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _PurchaseModalActionButton(
                label: 'app.common.confirm'.tr,
                onTap: _isSubmitting ? null : _submit,
                filled: true,
              ),
              const SizedBox(height: 12),
              _PurchaseModalActionButton(
                label: 'app.common.cancel'.tr,
                onTap: _isSubmitting
                    ? null
                    : () => Navigator.of(context).pop(false),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  _textForLocale(
                    zh: '修改价格会重新排序你的求购单',
                    en: 'Modifying the price will re-sort your buy request',
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color.fromRGBO(68, 70, 83, 0.70),
                    fontSize: 10,
                    fontWeight: FontWeight.w400,
                    height: 16.25 / 10,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PurchaseModalActionButton extends StatelessWidget {
  const _PurchaseModalActionButton({
    required this.label,
    required this.onTap,
    this.filled = false,
  });

  final String label;
  final VoidCallback? onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final background = filled ? const Color(0xFF1E40AF) : Colors.white;
    final foreground = filled ? Colors.white : const Color(0xFF334155);
    final border = filled
        ? Border.all(color: Colors.transparent)
        : Border.all(color: const Color(0xFFE2E8F0), width: 2);
    final shadow = filled
        ? const [
            BoxShadow(
              color: Color.fromRGBO(30, 64, 175, 0.20),
              blurRadius: 15,
              spreadRadius: -3,
              offset: Offset(0, 10),
            ),
            BoxShadow(
              color: Color.fromRGBO(30, 64, 175, 0.20),
              blurRadius: 6,
              spreadRadius: -4,
              offset: Offset(0, 4),
            ),
          ]
        : const <BoxShadow>[];

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(8),
              border: border,
              boxShadow: shadow,
            ),
            child: Center(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: foreground,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  height: 24 / 16,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

double? _buyingParseDouble(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is double) {
    return value;
  }
  if (value is int) {
    return value.toDouble();
  }
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value.toString());
}

class _BuyRecordStatusStyle {
  const _BuyRecordStatusStyle({
    required this.backgroundColor,
    required this.foregroundColor,
    required this.icon,
  });

  final Color backgroundColor;
  final Color foregroundColor;
  final IconData icon;
}
