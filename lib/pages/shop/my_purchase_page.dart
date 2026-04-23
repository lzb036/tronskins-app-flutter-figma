import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tronskins_app/common/utils/app_snackbar.dart';
import 'package:intl/intl.dart';
import 'package:tronskins_app/api/model/shop/shop_models.dart';
import 'package:tronskins_app/api/steam.dart';
import 'package:tronskins_app/common/hooks/currency/CurrencyController.dart';
import 'package:tronskins_app/common/hooks/game/global_game_controller.dart';
import 'package:tronskins_app/common/widgets/back_to_top_overlay.dart';
import 'package:tronskins_app/common/widgets/login_required_prompt.dart';
import 'package:tronskins_app/common/theme/settings_top_bar_style.dart';
import 'package:tronskins_app/common/widgets/settings_style_app_bar.dart';
import 'package:tronskins_app/components/filter/filter_models.dart';
import 'package:tronskins_app/components/filter/market_filter_sheet.dart';
import 'package:tronskins_app/components/filter/order_filter_sheet.dart';
import 'package:tronskins_app/components/game/game_switch_menu.dart';
import 'package:tronskins_app/components/game_item/game_item_image.dart';
import 'package:tronskins_app/components/game_item/game_item_models.dart';
import 'package:tronskins_app/components/game_item/game_item_utils.dart';
import 'package:tronskins_app/components/game_item/wear_progress_bar.dart';
import 'package:tronskins_app/components/layout/app_search_bar.dart';
import 'package:tronskins_app/components/layout/header_filter_button.dart';
import 'package:tronskins_app/components/layout/list_end_tip.dart';
import 'package:tronskins_app/controllers/shop/shop_order_controller.dart';
import 'package:tronskins_app/controllers/user/user_controller.dart';
import 'package:tronskins_app/routes/app_routes.dart';

class MyPurchasePage extends StatefulWidget {
  const MyPurchasePage({super.key});

  @override
  State<MyPurchasePage> createState() => _MyPurchasePageState();
}

class _MyPurchasePageState extends State<MyPurchasePage>
    with SingleTickerProviderStateMixin {
  static const double _loadMoreThreshold = 200;
  static const Color _buyRecordCardTitleColor = Color(0xFF0F172A);
  static const Color _buyRecordRefreshColor = Color(0xFF1E40AF);
  static const Color _buyRecordRefreshSurfaceColor = Colors.white;
  static const Color _buyRecordSoftSurfaceColor = Color(0xFFF8FAFC);
  static const Color _buyRecordBodyColor = Color(0xFF64748B);
  static const Color _buyRecordSkeletonColor = Color(0xFFE2E8F0);
  final ShopOrderController controller = Get.isRegistered<ShopOrderController>()
      ? Get.find<ShopOrderController>()
      : Get.put(ShopOrderController());
  final UserController userController = Get.find<UserController>();
  final ApiSteamServer _steamApi = ApiSteamServer();
  final GlobalGameController _globalGameController =
      GlobalGameController.ensureInstance();

  late final TabController _tabController;
  late int _currentAppId;
  int _currentTabIndex = 0;
  final ScrollController _receiptScroll = ScrollController();
  final ScrollController _recordScroll = ScrollController();
  final TextEditingController _receiptSearchController =
      TextEditingController();
  final TextEditingController _recordSearchController = TextEditingController();
  Worker? _gameWorker;
  Worker? _loginWorker;

  bool get _isChineseLocale =>
      (Get.locale?.languageCode ?? '').toLowerCase().startsWith('zh');

  String _text({required String zh, required String en}) =>
      _isChineseLocale ? zh : en;

  static const String _defaultOrderSortField = 'time';
  static const bool _defaultOrderSortAsc = false;
  static const List<SortOption> _timeSortOptions = [
    SortOption(
      labelKey: 'app.market.filter.time',
      field: _defaultOrderSortField,
    ),
  ];

  void _handleSearchTextChange() {
    if (mounted) {
      setState(() {});
    }
  }

  static const List<StatusOption> _statusOptions = [
    StatusOption(labelKey: 'app.market.filter.all', values: []),
    StatusOption(labelKey: 'app.trade.filter.in', values: [2, 3]),
    StatusOption(labelKey: 'app.trade.filter.failed', values: [-1]),
    StatusOption(labelKey: 'app.trade.filter.settling', values: [5]),
    StatusOption(labelKey: 'app.trade.filter.success', values: [6]),
  ];

  @override
  void initState() {
    super.initState();
    final args = Get.arguments;
    int initialTab = 0;
    if (args is Map && args['initialTab'] is int) {
      initialTab = args['initialTab'] as int;
    }
    if (args is Map && args['mode']?.toString() == 'records') {
      initialTab = 1;
    }
    if (initialTab < 0 || initialTab > 1) {
      initialTab = 0;
    }
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: initialTab,
    );
    _currentTabIndex = initialTab;
    _currentAppId = _globalGameController.appId;
    unawaited(MarketFilterSheet.preload(appId: _currentAppId));
    _gameWorker = ever<int>(_globalGameController.currentAppId, (appId) {
      if (!mounted || appId == _currentAppId) {
        return;
      }
      setState(() => _currentAppId = appId);
      _resetPurchaseViewportForGameChange();
      unawaited(MarketFilterSheet.preload(appId: appId));
      controller.refreshWaitingReceipts();
      controller.refreshBuyRecords();
    });
    _tabController.addListener(_handleTabChange);
    _receiptScroll.addListener(_handleReceiptScroll);
    _recordScroll.addListener(_handleRecordScroll);
    _receiptSearchController.addListener(_handleSearchTextChange);
    _recordSearchController.addListener(_handleSearchTextChange);
    if (userController.isLoggedIn.value) {
      controller.refreshWaitingReceipts();
      controller.refreshBuyRecords();
    }
    _loginWorker = ever<bool>(userController.isLoggedIn, (loggedIn) {
      if (loggedIn) {
        controller.refreshWaitingReceipts();
        controller.refreshBuyRecords();
      } else {
        controller.waitingReceipts.clear();
        controller.buyRecords.clear();
        controller.schemas.clear();
        controller.users.clear();
      }
    });
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    _receiptScroll
      ..removeListener(_handleReceiptScroll)
      ..dispose();
    _recordScroll
      ..removeListener(_handleRecordScroll)
      ..dispose();
    _receiptSearchController.removeListener(_handleSearchTextChange);
    _recordSearchController.removeListener(_handleSearchTextChange);
    _gameWorker?.dispose();
    _loginWorker?.dispose();
    _receiptSearchController.dispose();
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

  void _jumpScrollToTop(ScrollController controller) {
    if (!controller.hasClients) {
      return;
    }
    final minExtent = controller.position.minScrollExtent;
    if (controller.position.pixels == minExtent) {
      return;
    }
    controller.jumpTo(minExtent);
  }

  void _resetPurchaseViewportForGameChange() {
    _jumpScrollToTop(_receiptScroll);
    _jumpScrollToTop(_recordScroll);
    if (_tabController.offset != 0) {
      _tabController.offset = 0;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _jumpScrollToTop(_receiptScroll);
      _jumpScrollToTop(_recordScroll);
      if (_tabController.offset != 0) {
        _tabController.offset = 0;
      }
    });
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

  void _handleReceiptScroll() {
    if (!_shouldLoadMore(_receiptScroll) ||
        controller.isLoadingWaiting.value ||
        !controller.waitingHasMore) {
      return;
    }
    controller.loadWaitingReceipts();
  }

  void _handleRecordScroll() {
    if (!_shouldLoadMore(_recordScroll) ||
        controller.isLoadingRecords.value ||
        !controller.recordHasMore) {
      return;
    }
    controller.loadBuyRecords();
  }

  ShopSchemaInfo? _lookupSchema(
    Map<String, ShopSchemaInfo> schemas,
    ShopOrderDetail? detail,
  ) {
    if (detail == null) {
      return null;
    }
    final hash = detail.marketHashName;
    if (hash != null && schemas.containsKey(hash)) {
      return schemas[hash];
    }
    final key = detail.schemaId?.toString();
    if (key != null && schemas.containsKey(key)) {
      return schemas[key];
    }
    return null;
  }

  double _sumOrderPrice(ShopOrderItem order) {
    if (order.price != null) {
      return order.price!;
    }
    double total = 0;
    for (final detail in order.details) {
      final unit = detail.price ?? 0;
      final count = detail.count ?? 1;
      total += unit * count;
    }
    return total;
  }

  double _buyRecordUnitPrice(ShopOrderItem order) {
    final detail = _primaryRecordDetail(order);
    final detailPrice = detail?.price;
    if (detailPrice != null && detailPrice > 0) {
      return detailPrice;
    }
    final quantity = _buyRecordQuantity(order);
    if (quantity <= 0) {
      return _sumOrderPrice(order);
    }
    return _sumOrderPrice(order) / quantity;
  }

  String _buyRecordUnitPriceFormula(
    ShopOrderItem order,
    CurrencyController currency,
  ) {
    final quantity = _buyRecordQuantity(order);
    final unitPrice = _buyRecordUnitPrice(order);
    final totalPrice = _sumOrderPrice(order);
    return '${currency.format(unitPrice)} x $quantity = '
        '${currency.format(totalPrice)}';
  }

  Future<void> _openReceiptFilterSheet() async {
    final result = await OrderFilterSheet.showFromRight(
      context: context,
      initial: OrderFilterResult(
        sortField: controller.waitingSortField.value.isEmpty
            ? _defaultOrderSortField
            : controller.waitingSortField.value,
        sortAsc: controller.waitingSortField.value.isEmpty
            ? _defaultOrderSortAsc
            : controller.waitingSortAsc.value,
      ),
      statusOptions: _statusOptions,
      sortOptions: _timeSortOptions,
      defaultSortField: _defaultOrderSortField,
      defaultSortAsc: _defaultOrderSortAsc,
      showSort: true,
      showStatus: false,
      showDateRange: false,
      enableAttributeFilter: false,
      sectionOrder: const [OrderFilterSectionCategory.sort],
    );
    if (result != null) {
      final sort = _storedOrderSort(result);
      await controller.applyWaitingFilter(
        startDate: result.startDate,
        endDate: result.endDate,
        sortAsc: sort.asc,
        sortField: sort.field,
        tags: const <String, dynamic>{},
        itemName: '',
      );
      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<void> _openBuyRecordFilterSheet() async {
    final result = await OrderFilterSheet.showFromRight(
      context: context,
      initial: OrderFilterResult(
        statusList: controller.buyRecordStatusList.toList(),
        startDate: controller.buyRecordStartDate.value,
        endDate: controller.buyRecordEndDate.value,
        sortField: controller.buyRecordSortField.value.isEmpty
            ? _defaultOrderSortField
            : controller.buyRecordSortField.value,
        sortAsc: controller.buyRecordSortField.value.isEmpty
            ? _defaultOrderSortAsc
            : controller.buyRecordSortAsc.value,
      ),
      statusOptions: _statusOptions,
      sortOptions: _timeSortOptions,
      defaultSortField: _defaultOrderSortField,
      defaultSortAsc: _defaultOrderSortAsc,
      showSort: true,
      showStatus: true,
      showDateRange: true,
      enableAttributeFilter: false,
      sectionOrder: const [
        OrderFilterSectionCategory.sort,
        OrderFilterSectionCategory.date,
        OrderFilterSectionCategory.status,
      ],
    );
    if (result != null) {
      final sort = _storedOrderSort(result);
      await controller.applyBuyRecordFilter(
        statusList: result.statusList,
        startDate: result.startDate,
        endDate: result.endDate,
        sortAsc: sort.asc,
        sortField: sort.field,
        tags: const <String, dynamic>{},
        itemName: '',
      );
      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<void> _switchGame(int appId) async {
    if (appId == _globalGameController.appId) {
      return;
    }
    await _globalGameController.switchGame(appId);
  }

  ({String field, bool asc}) _storedOrderSort(OrderFilterResult result) {
    final field = (result.sortField ?? '').trim();
    final asc = result.sortAsc ?? _defaultOrderSortAsc;
    if (field == _defaultOrderSortField && asc == _defaultOrderSortAsc) {
      return (field: '', asc: _defaultOrderSortAsc);
    }
    return (field: field, asc: field.isEmpty ? _defaultOrderSortAsc : asc);
  }

  Future<void> _receiveOrder(ShopOrderItem order) async {
    final id = order.id?.toString();
    if (id == null) {
      return;
    }
    final steamStatus = await _steamApi.steamOnlineState();
    if (steamStatus.datas != true) {
      final tradeOfferId = order.tradeOfferId ?? '';
      if (tradeOfferId.isNotEmpty) {
        Get.toNamed(
          Routers.RECEIVE_GOODS,
          arguments: {'tradeOfferId': tradeOfferId},
        );
      } else {
        AppSnackbar.error('app.trade.filter.failed'.tr);
      }
      return;
    }
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: Text('app.system.tips.title'.tr),
        content: Text('app.trade.receipt.message.confirm_auto'.tr),
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
      await controller.acceptTradeOffer(id);
      AppSnackbar.success('app.system.message.success'.tr);
    } catch (_) {
      AppSnackbar.error('app.trade.filter.failed'.tr);
    }
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

  TagInfo? _schemaTag(ShopSchemaInfo? schema, String key) {
    final tags = schema?.raw['tags'];
    if (tags is Map) {
      return TagInfo.fromRaw(tags[key]);
    }
    return null;
  }

  int _resolveDetailAppId(ShopOrderDetail? detail, ShopSchemaInfo? schema) {
    final raw = detail?.raw;
    final schemaRaw = schema?.raw;
    final rawApp = raw?['app_id'] ?? raw?['appId'];
    final schemaApp = schemaRaw?['app_id'] ?? schemaRaw?['appId'];
    return _asInt(rawApp) ?? _asInt(schemaApp) ?? _currentAppId;
  }

  Future<void> _openOrderDetail(ShopOrderItem order) async {
    await Get.toNamed(
      Routers.SHOP_ORDER_DETAIL,
      arguments: {
        'order': order,
        'schemas': Map<String, ShopSchemaInfo>.from(controller.schemas),
        'users': Map<String, ShopUserInfo>.from(controller.users),
      },
    );
  }

  String _buildStatusText(ShopOrderItem order) {
    if ([2, 3, 4].contains(order.status)) {
      return 'app.trade.filter.in'.tr;
    }
    if (order.status == 5) {
      return 'app.trade.filter.settling'.tr;
    }
    if (order.status == 6) {
      return 'app.trade.filter.success'.tr;
    }
    return 'app.trade.filter.failed'.tr;
  }

  ({Color bg, Color fg, Color border, IconData icon}) _statusPalette(
    int? status,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    if (status == 6) {
      return (
        bg: const Color(0xFFF0FDF4),
        fg: const Color(0xFF16A34A),
        border: const Color(0xFFD1FAE5),
        icon: Icons.check_circle_rounded,
      );
    }

    if (status == 5) {
      return (
        bg: const Color(0xFFEFF6FF),
        fg: const Color(0xFF2563EB),
        border: const Color(0xFFDBEAFE),
        icon: Icons.hourglass_top_rounded,
      );
    }

    if ([2, 3, 4].contains(status)) {
      return (
        bg: const Color(0xFFFFF7ED),
        fg: const Color(0xFFEA580C),
        border: const Color(0xFFFED7AA),
        icon: Icons.local_shipping_rounded,
      );
    }

    if ([-1, -2].contains(status)) {
      return (
        bg: const Color(0xFFFEF2F2),
        fg: const Color(0xFFDC2626),
        border: const Color(0xFFFECACA),
        icon: Icons.cancel_rounded,
      );
    }

    return (
      bg: colorScheme.surfaceContainerHighest.withValues(alpha: 0.72),
      fg: colorScheme.onSurfaceVariant,
      border: colorScheme.outline.withValues(alpha: 0.10),
      icon: Icons.info_rounded,
    );
  }

  Widget _buildStatusBadge(ShopOrderItem order) {
    final palette = _statusPalette(order.status);
    final text = _buildStatusText(order);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 190),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: palette.bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: palette.border),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(palette.icon, size: 12, color: palette.fg),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: palette.fg,
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  BoxDecoration _buildBuyRecordCardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.zero,
      boxShadow: const [
        BoxShadow(
          color: Color.fromRGBO(15, 23, 42, 0.05),
          blurRadius: 16,
          offset: Offset(0, 4),
        ),
      ],
    );
  }

  String _formatRecordTime(int? timestamp) {
    if (timestamp == null || timestamp <= 0) {
      return '-';
    }
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    return DateFormat('yyyy-MM-dd HH:mm').format(date);
  }

  ShopOrderDetail? _primaryRecordDetail(ShopOrderItem order) {
    if (order.details.isEmpty) {
      return null;
    }
    return order.details.first;
  }

  int _buyRecordQuantity(ShopOrderItem order) {
    if (order.nums != null && order.nums! > 0) {
      return order.nums!;
    }
    var total = 0;
    for (final detail in order.details) {
      total += detail.count ?? 1;
    }
    return total > 0 ? total : 1;
  }

  int? _buyRecordPreviewBadgeCount(ShopOrderItem order) {
    final quantity = _buyRecordQuantity(order);
    return quantity > 1 ? quantity : null;
  }

  bool _shouldShowBuyRecordWear(ShopOrderItem order, double? wear) {
    return wear != null && _buyRecordQuantity(order) <= 1;
  }

  String _formatBuyRecordWearValue(ShopOrderDetail? detail, double? wear) {
    final rawValue =
        detail?.raw['paint_wear_text'] ??
        detail?.raw['paintWearText'] ??
        detail?.raw['paint_wear'] ??
        detail?.raw['paintWear'];
    final text = rawValue?.toString().trim();
    if (text != null && text.isNotEmpty) {
      return text;
    }
    return wear?.toString() ?? '';
  }

  String _buyRecordTitle(ShopOrderItem order, ShopSchemaInfo? schema) {
    final detail = _primaryRecordDetail(order);
    return detail?.marketName ??
        schema?.marketName ??
        detail?.marketHashName ??
        schema?.marketHashName ??
        '-';
  }

  Widget _buildBuyRecordPreviewImage(
    ShopOrderItem order,
    ShopOrderDetail? detail,
    ShopSchemaInfo? schema,
  ) {
    final badgeCount = _buyRecordPreviewBadgeCount(order);
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
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(4),
            ),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: GameItemImage(
                imageUrl: detail?.imageUrl ?? schema?.imageUrl,
                appId: _resolveDetailAppId(detail, schema),
                rarity: _schemaTag(schema, 'rarity'),
                quality: _schemaTag(schema, 'quality'),
                exterior: _schemaTag(schema, 'exterior'),
                phase: detail?.raw['phase']?.toString(),
                percentage: detail?.raw['percentage']?.toString(),
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

  Widget _buildBuyRecordWearInfo(
    ShopOrderDetail detail,
    double wear, {
    Color? accentColor,
  }) {
    final wearText = _formatBuyRecordWearValue(detail, wear);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: double.infinity,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '${'app.market.csgo.abradability'.tr}: $wearText',
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 12,
                fontWeight: FontWeight.w500,
                height: 18 / 12,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        WearProgressBar(
          paintWear: wear,
          height: 12,
          style: WearProgressBarStyle.figmaCompact,
          accentColor: accentColor,
        ),
      ],
    );
  }

  Widget _buildBuyRecordCountdownChip(Widget child) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.schedule, size: 12, color: Colors.orange.shade700),
          const SizedBox(width: 4),
          child,
        ],
      ),
    );
  }

  Widget _buildBuyRecordSummaryRow({
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

  Widget _buildBuyRecordSummaryPanel(
    ShopOrderItem order,
    CurrencyController currency,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      decoration: BoxDecoration(
        color: _buyRecordSoftSurfaceColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Obx(
        () => _buildBuyRecordSummaryRow(
          label: _text(zh: '单价', en: 'Unit Price'),
          value: Text(
            _buyRecordUnitPriceFormula(order, currency),
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: _buyRecordBodyColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 18 / 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBuyRecordCard({
    required ShopOrderItem order,
    required CurrencyController currency,
  }) {
    final detail = _primaryRecordDetail(order);
    final schema = _lookupSchema(controller.schemas, detail);
    final wear = detail?.paintWear;
    final showWearInfo = _shouldShowBuyRecordWear(order, wear);
    final waitingDeadlineMs = _waitingDeadlineMs(order);
    final showWaitingCountdown = _showWaitingCountdown(order);
    final showProtectionCountdown =
        !showWaitingCountdown &&
        order.protectionTime != null &&
        order.protectionTime! > 0 &&
        order.status == 5;

    return DecoratedBox(
      decoration: _buildBuyRecordCardDecoration(),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.zero,
          onTap: () => _openOrderDetail(order),
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
                              color: const Color(0xFF94A3B8),
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              height: 15 / 10,
                              letterSpacing: _isChineseLocale ? 0 : 1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatRecordTime(order.createTime),
                            style: const TextStyle(
                              color: _buyRecordCardTitleColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              height: 18 / 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    _buildStatusBadge(order),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildBuyRecordPreviewImage(order, detail, schema),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _buyRecordTitle(order, schema),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _buyRecordCardTitleColor,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              height: 24 / 16,
                            ),
                          ),
                          if (showWearInfo) ...[
                            const SizedBox(height: 6),
                            _buildBuyRecordWearInfo(
                              detail!,
                              wear!,
                              accentColor: parseHexColor(
                                _schemaTag(schema, 'exterior')?.color,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                if (showWaitingCountdown || showProtectionCountdown) ...[
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (showWaitingCountdown)
                          _buildBuyRecordCountdownChip(
                            _InlineCountdownText(
                              endTimeMs: waitingDeadlineMs,
                              style: const TextStyle(
                                color: Color(0xFF9A3412),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                height: 16 / 11,
                              ),
                            ),
                          )
                        else if (showProtectionCountdown)
                          _buildBuyRecordCountdownChip(
                            _RecordProtectionCountdownText(
                              endTimeSeconds: order.protectionTime!,
                              style: const TextStyle(
                                color: Color(0xFF9A3412),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                height: 16 / 11,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                _buildBuyRecordSummaryPanel(order, currency),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWaitingReceiptCard({
    required ShopOrderItem order,
    required CurrencyController currency,
  }) {
    final detail = _primaryRecordDetail(order);
    final schema = _lookupSchema(controller.schemas, detail);
    final wear = detail?.paintWear;
    final showWearInfo = _shouldShowBuyRecordWear(order, wear);
    final showCountdown = _showWaitingCountdown(order);
    final deadlineMs = _waitingDeadlineMs(order);
    final displayTime = order.changeTime ?? order.createTime;

    return DecoratedBox(
      decoration: _buildBuyRecordCardDecoration(),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.zero,
          onTap: () => _openOrderDetail(order),
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
                            _text(zh: '订单时间', en: 'ORDER DATE'),
                            style: TextStyle(
                              color: const Color(0xFF94A3B8),
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              height: 15 / 10,
                              letterSpacing: _isChineseLocale ? 0 : 1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatRecordTime(displayTime),
                            style: const TextStyle(
                              color: _buyRecordCardTitleColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              height: 18 / 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    _buildStatusBadge(order),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildBuyRecordPreviewImage(order, detail, schema),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _buyRecordTitle(order, schema),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _buyRecordCardTitleColor,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              height: 24 / 16,
                            ),
                          ),
                          if (showWearInfo) ...[
                            const SizedBox(height: 6),
                            _buildBuyRecordWearInfo(
                              detail!,
                              wear!,
                              accentColor: parseHexColor(
                                _schemaTag(schema, 'exterior')?.color,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildBuyRecordSummaryPanel(order, currency),
                if (showCountdown) ...[
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: _buildBuyRecordCountdownChip(
                      _InlineCountdownText(
                        endTimeMs: deadlineMs,
                        style: const TextStyle(
                          color: Color(0xFF9A3412),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          height: 16 / 11,
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                _buildWaitingReceiptActionButton(
                  label: 'app.market.product.receive'.tr,
                  onTap: () => _receiveOrder(order),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWaitingReceiptActionButton({
    required String label,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0F766E), Color(0xFF14B8A6)],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [
                BoxShadow(
                  color: Color.fromRGBO(20, 184, 166, 0.22),
                  blurRadius: 16,
                  spreadRadius: -4,
                  offset: Offset(0, 8),
                ),
                BoxShadow(
                  color: Color.fromRGBO(15, 118, 110, 0.18),
                  blurRadius: 8,
                  spreadRadius: -4,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  height: 20 / 14,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWaitingReceiptSkeletonList({
    int count = 3,
    bool shrinkWrap = false,
  }) {
    return ListView.separated(
      controller: shrinkWrap ? null : _receiptScroll,
      shrinkWrap: shrinkWrap,
      physics: const NeverScrollableScrollPhysics(),
      padding: shrinkWrap
          ? EdgeInsets.zero
          : const EdgeInsets.fromLTRB(12, 8, 12, 16),
      itemCount: count,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, __) => _buildWaitingReceiptSkeletonCard(),
    );
  }

  Widget _buildWaitingReceiptSkeletonCard() {
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
                    _buildSkeletonBox(width: 84, height: 10, radius: 4),
                    const SizedBox(height: 6),
                    _buildSkeletonBox(width: 128, height: 14, radius: 6),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _buildSkeletonBox(width: 82, height: 26, radius: 999),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSkeletonBox(width: 64, height: 64, radius: 4),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSkeletonBox(
                      width: double.infinity,
                      height: 18,
                      radius: 8,
                    ),
                    const SizedBox(height: 8),
                    _buildSkeletonBox(width: 104, height: 12, radius: 6),
                    const SizedBox(height: 6),
                    _buildSkeletonBox(
                      width: double.infinity,
                      height: 4,
                      radius: 999,
                    ),
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
            child: Row(
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
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: _buildSkeletonBox(width: 88, height: 22, radius: 999),
          ),
          const SizedBox(height: 12),
          _buildSkeletonBox(width: double.infinity, height: 44, radius: 12),
        ],
      ),
    );
  }

  Widget _buildBuyRecordSkeletonList({int count = 3, bool shrinkWrap = false}) {
    return ListView.separated(
      controller: shrinkWrap ? null : _recordScroll,
      shrinkWrap: shrinkWrap,
      physics: const NeverScrollableScrollPhysics(),
      padding: shrinkWrap
          ? EdgeInsets.zero
          : const EdgeInsets.fromLTRB(12, 8, 12, 16),
      itemCount: count,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
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
                    _buildSkeletonBox(width: 84, height: 10, radius: 4),
                    const SizedBox(height: 6),
                    _buildSkeletonBox(width: 128, height: 14, radius: 6),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _buildSkeletonBox(width: 82, height: 26, radius: 999),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSkeletonBox(width: 64, height: 64, radius: 4),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSkeletonBox(
                      width: double.infinity,
                      height: 18,
                      radius: 8,
                    ),
                    const SizedBox(height: 8),
                    _buildSkeletonBox(width: 92, height: 12, radius: 6),
                    const SizedBox(height: 6),
                    _buildSkeletonBox(
                      width: double.infinity,
                      height: 4,
                      radius: 999,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: _buildSkeletonBox(width: 88, height: 22, radius: 999),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
            decoration: BoxDecoration(
              color: _buyRecordSoftSurfaceColor,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
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

  double _waitingShippingHours(ShopOrderItem order) {
    final status = order.status;
    final type = order.type;
    if (status == 3) {
      return 0.5;
    }
    if (type == 2 && status == 2) {
      return 0.5;
    }
    if (type == 1 && status == 2) {
      return 18;
    }
    if (status == 4) {
      return 18;
    }
    return 18;
  }

  int _waitingDeadlineMs(ShopOrderItem order) {
    final changeTime = order.changeTime;
    if (changeTime == null || changeTime <= 0) {
      return 0;
    }
    final shippingMs = (_waitingShippingHours(order) * 3600 * 1000).round();
    return changeTime * 1000 + shippingMs;
  }

  bool _showWaitingCountdown(ShopOrderItem order) {
    if (![2, 3, 4].contains(order.status)) {
      return false;
    }
    final deadline = _waitingDeadlineMs(order);
    if (deadline <= 0) {
      return false;
    }
    return deadline > DateTime.now().millisecondsSinceEpoch;
  }

  bool _hasWaitingFilter() {
    if (controller.waitingSortField.value.isNotEmpty) {
      return true;
    }
    return false;
  }

  bool get _isWaitingTab => _currentTabIndex == 0;

  TextEditingController get _activeSearchController =>
      _isWaitingTab ? _receiptSearchController : _recordSearchController;

  ValueChanged<String> get _activeSearchSubmit =>
      _isWaitingTab ? controller.searchWaiting : controller.searchBuyRecords;

  Future<void> _submitActiveSearch() {
    if (_isWaitingTab) {
      return controller.searchWaiting(_receiptSearchController.text);
    }
    return controller.searchBuyRecords(_recordSearchController.text);
  }

  Future<void> _openActiveFilterSheet() {
    if (_isWaitingTab) {
      return _openReceiptFilterSheet();
    }
    return _openBuyRecordFilterSheet();
  }

  bool _hasActiveFilter() {
    if (_isWaitingTab) {
      return _hasWaitingFilter();
    }
    return _hasBuyRecordFilter();
  }

  bool _hasBuyRecordFilter() {
    if (controller.buyRecordStatusList.isNotEmpty) {
      return true;
    }
    if (controller.buyRecordStartDate.value != null ||
        controller.buyRecordEndDate.value != null) {
      return true;
    }
    if (controller.buyRecordSortField.value.isNotEmpty) {
      return true;
    }
    return false;
  }

  String _gameLabelForAppId(int appId) {
    return switch (appId) {
      730 => 'CS2',
      570 => 'DOTA2',
      440 => 'TF2',
      _ => 'GAME',
    };
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
              active: _hasActiveFilter(),
              onTap: _openActiveFilterSheet,
              size: 40,
              iconSize: 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPurchaseTabBar() {
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
        Tab(height: 30, text: 'app.market.product.wait_for_receipt'.tr),
        Tab(height: 30, text: 'app.user.menu.buy'.tr),
      ],
    );
  }

  Widget _buildPullToRefreshEmpty({
    required Future<void> Function() onRefresh,
  }) {
    return RefreshIndicator(
      color: _buyRecordRefreshColor,
      backgroundColor: _buyRecordRefreshSurfaceColor,
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

  Widget _buildHeader({required bool showInteractiveSections}) {
    return Container(
      decoration: const BoxDecoration(
        color: settingsTopBarBackground,
        border: Border(bottom: BorderSide(color: settingsTopBarBorderColor)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SettingsStyleNavigationRow(
            title: 'app.user.menu.buy'.tr,
            onBack: () => Navigator.of(context).maybePop(),
            actions: [if (showInteractiveSections) _buildGameSwitchTrigger()],
          ),
          if (showInteractiveSections) ...[
            _buildTabSearchBar(),
            Align(
              alignment: Alignment.centerLeft,
              child: _buildPurchaseTabBar(),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currency = Get.find<CurrencyController>();
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
                          children: [
                            _buildWaitingReceipts(currency),
                            _buildBuyRecords(currency),
                          ],
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

  Widget _buildWaitingReceipts(CurrencyController currency) {
    return Obx(() {
      if (controller.waitingReceipts.isEmpty &&
          controller.isLoadingWaiting.value) {
        return _buildWaitingReceiptSkeletonList();
      }
      if (controller.waitingReceipts.isEmpty) {
        return _buildPullToRefreshEmpty(
          onRefresh: controller.refreshWaitingReceipts,
        );
      }
      final showLoadingFooter =
          controller.isLoadingWaiting.value &&
          controller.waitingReceipts.isNotEmpty;
      final showNoMoreFooter =
          controller.waitingReceipts.isNotEmpty &&
          !controller.isLoadingWaiting.value &&
          !controller.waitingHasMore;
      final showFooter = showLoadingFooter || showNoMoreFooter;
      return BackToTopScope(
        enabled: true,
        child: RefreshIndicator(
          color: _buyRecordRefreshColor,
          backgroundColor: _buyRecordRefreshSurfaceColor,
          strokeWidth: 2.6,
          edgeOffset: 8,
          displacement: 24,
          onRefresh: controller.refreshWaitingReceipts,
          child: ListView.separated(
            controller: _receiptScroll,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
            itemCount: controller.waitingReceipts.length + (showFooter ? 1 : 0),
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              if (index >= controller.waitingReceipts.length) {
                return _buildWaitingReceiptLoadMoreFooter(
                  loading: showLoadingFooter,
                  hasMore: controller.waitingHasMore,
                );
              }
              final order = controller.waitingReceipts[index];
              return _buildWaitingReceiptCard(order: order, currency: currency);
            },
          ),
        ),
      );
    });
  }

  Widget _buildWaitingReceiptLoadMoreFooter({
    required bool loading,
    required bool hasMore,
  }) {
    if (loading && hasMore) {
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: _buildWaitingReceiptSkeletonList(count: 2, shrinkWrap: true),
      );
    }
    if (!hasMore) {
      return const ListEndTip(padding: EdgeInsets.fromLTRB(8, 6, 8, 12));
    }
    return const SizedBox(height: 4);
  }

  Widget _buildBuyRecords(CurrencyController currency) {
    return Obx(() {
      if (controller.buyRecords.isEmpty && controller.isLoadingRecords.value) {
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
          color: _buyRecordRefreshColor,
          backgroundColor: _buyRecordRefreshSurfaceColor,
          strokeWidth: 2.6,
          edgeOffset: 8,
          displacement: 24,
          onRefresh: controller.refreshBuyRecords,
          child: ListView.separated(
            controller: _recordScroll,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
            itemCount: controller.buyRecords.length + (showFooter ? 1 : 0),
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              if (index >= controller.buyRecords.length) {
                return _buildBuyRecordLoadMoreFooter(
                  loading: showLoadingFooter,
                  hasMore: controller.recordHasMore,
                );
              }
              final order = controller.buyRecords[index];
              return _buildBuyRecordCard(order: order, currency: currency);
            },
          ),
        ),
      );
    });
  }

  Widget _buildBuyRecordLoadMoreFooter({
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

class _InlineCountdownText extends StatefulWidget {
  const _InlineCountdownText({required this.endTimeMs, this.style});

  final int endTimeMs;
  final TextStyle? style;

  @override
  State<_InlineCountdownText> createState() => _InlineCountdownTextState();
}

class _InlineCountdownTextState extends State<_InlineCountdownText> {
  Timer? _timer;
  String _text = '';

  @override
  void initState() {
    super.initState();
    _tick();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void didUpdateWidget(covariant _InlineCountdownText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.endTimeMs != widget.endTimeMs) {
      _tick();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _tick() {
    final next = _format(widget.endTimeMs);
    if (!mounted) {
      return;
    }
    if (_text != next) {
      setState(() => _text = next);
    }
    if (next.isEmpty) {
      _timer?.cancel();
    }
  }

  String _format(int endTimeMs) {
    final remainMs = endTimeMs - DateTime.now().millisecondsSinceEpoch;
    if (remainMs <= 0) {
      return '';
    }
    final totalSeconds = remainMs ~/ 1000;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    final h = hours.toString().padLeft(2, '0');
    final m = minutes.toString().padLeft(2, '0');
    final s = seconds.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    if (_text.isEmpty) {
      return const SizedBox.shrink();
    }
    return Text(_text, style: widget.style);
  }
}

class _RecordProtectionCountdownText extends StatefulWidget {
  const _RecordProtectionCountdownText({
    required this.endTimeSeconds,
    this.style,
  });

  final int endTimeSeconds;
  final TextStyle? style;

  @override
  State<_RecordProtectionCountdownText> createState() =>
      _RecordProtectionCountdownTextState();
}

class _RecordProtectionCountdownTextState
    extends State<_RecordProtectionCountdownText> {
  Timer? _timer;
  String _remainText = '';

  @override
  void initState() {
    super.initState();
    _tick();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void didUpdateWidget(covariant _RecordProtectionCountdownText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.endTimeSeconds != widget.endTimeSeconds) {
      _tick();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _tick() {
    final next = _formatRemainText(widget.endTimeSeconds);
    if (!mounted) {
      return;
    }
    if (_remainText != next) {
      setState(() => _remainText = next);
    }
    if (next.isEmpty) {
      _timer?.cancel();
    }
  }

  String _formatRemainText(int endTimeSeconds) {
    final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final totalTimeLeft = endTimeSeconds - nowSeconds;
    if (totalTimeLeft <= 0) {
      return '';
    }

    var days = totalTimeLeft ~/ (24 * 60 * 60);
    final hoursTotal = totalTimeLeft ~/ (60 * 60);
    final minutes = (totalTimeLeft % (60 * 60)) ~/ 60;
    var remainingHours = hoursTotal - days * 24 + (minutes > 0 ? 1 : 0);

    if (remainingHours % 24 == 0) {
      days += 1;
      remainingHours -= 24;
    }

    final localeTag = Get.locale?.toLanguageTag().toLowerCase() ?? '';
    final isCjkLocale =
        localeTag.startsWith('zh') ||
        localeTag.startsWith('ja') ||
        localeTag.startsWith('zh-hk');

    if (days > 0) {
      if (isCjkLocale) {
        return '$days${'app.common.day'.tr}$remainingHours${'app.common.hours'.tr}';
      }
      final dayKey = days > 1 ? 'app.common.days' : 'app.common.day';
      final hourKey = remainingHours > 1
          ? 'app.common.hours'
          : 'app.common.hour';
      return '$days${dayKey.tr}$remainingHours${hourKey.tr}';
    }

    if (remainingHours > 0) {
      if (isCjkLocale) {
        return '$remainingHours${'app.common.hours'.tr}';
      }
      final hourKey = remainingHours > 1
          ? 'app.common.hours'
          : 'app.common.hour';
      return '$remainingHours${hourKey.tr}';
    }

    final formattedMinutes = minutes.toString().padLeft(2, '0');
    final minuteKey = isCjkLocale
        ? 'app.common.minutes'.tr
        : (minutes > 1 ? 'app.common.minutes'.tr : 'app.common.minute'.tr);
    return '$formattedMinutes$minuteKey';
  }

  @override
  Widget build(BuildContext context) {
    if (_remainText.isEmpty) {
      return const SizedBox.shrink();
    }
    return Text(_remainText, style: widget.style);
  }
}
