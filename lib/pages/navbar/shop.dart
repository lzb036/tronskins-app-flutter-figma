import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:tronskins_app/api/model/shop/shop_models.dart';
import 'package:tronskins_app/api/steam.dart';
import 'package:tronskins_app/common/hooks/currency/CurrencyController.dart';
import 'package:tronskins_app/common/hooks/game/global_game_controller.dart';
import 'package:tronskins_app/common/utils/app_snackbar.dart';
import 'package:tronskins_app/common/widgets/back_to_top_overlay.dart';
import 'package:tronskins_app/common/widgets/figma_confirmation_dialog.dart';
import 'package:tronskins_app/common/widgets/glass_notice_dialog.dart';
import 'package:tronskins_app/common/widgets/login_required_prompt.dart';
import 'package:tronskins_app/components/game/game_switch_menu.dart';
import 'package:tronskins_app/components/filter/filter_models.dart';
import 'package:tronskins_app/components/filter/market_filter_sheet.dart';
import 'package:tronskins_app/components/game_item/game_item_image.dart';
import 'package:tronskins_app/components/game_item/game_item_models.dart';
import 'package:tronskins_app/components/game_item/shop_sale_item_card.dart';
import 'package:tronskins_app/components/layout/app_search_bar.dart';
import 'package:tronskins_app/components/layout/header_filter_button.dart';
import 'package:tronskins_app/components/layout/navbar/floating_selection_action_bar.dart';
import 'package:tronskins_app/components/layout/list_end_tip.dart';
import 'package:tronskins_app/components/market/market_showcase_card.dart';
import 'package:tronskins_app/controllers/navbar/nav_controller.dart';
import 'package:tronskins_app/controllers/shop/shop_controller.dart';
import 'package:tronskins_app/controllers/shop/shop_order_controller.dart';
import 'package:tronskins_app/controllers/shop/shop_sales_controller.dart';
import 'package:tronskins_app/controllers/shop/shop_shipping_notice_controller.dart';
import 'package:tronskins_app/controllers/user/user_controller.dart';
import 'package:tronskins_app/routes/app_routes.dart';

enum _ShopTabFilter { onSale, pending, saleRecord }

class ShopPage extends StatefulWidget {
  const ShopPage({super.key});

  @override
  State<ShopPage> createState() => _ShopPageState();
}

class _ShopPageState extends State<ShopPage>
    with SingleTickerProviderStateMixin {
  static const Color _pendingNoticeDot = Color(0xFFFF9500);
  static const int _gridColumns = 2;
  static const double _gridMainSpacing = 8;
  static const double _gridCrossSpacing = 8;
  static const double _gridAspectRatio = 0.92;
  static const EdgeInsets _gridPadding = EdgeInsets.fromLTRB(16, 4, 16, 16);
  static const int _onSaleLoadingPlaceholderCount = 6;
  static const int _pendingLoadingPlaceholderCount = 4;
  static const int _recordLoadingPlaceholderCount = 4;
  static const int _footerLoadingPlaceholderCount = 1;
  final ShopController shopController = Get.isRegistered<ShopController>()
      ? Get.find<ShopController>()
      : Get.put(ShopController());
  final ShopSalesController salesController =
      Get.isRegistered<ShopSalesController>()
      ? Get.find<ShopSalesController>()
      : Get.put(ShopSalesController());
  final ShopOrderController orderController =
      Get.isRegistered<ShopOrderController>()
      ? Get.find<ShopOrderController>()
      : Get.put(ShopOrderController());
  final ShopShippingNoticeController shippingNoticeController =
      Get.isRegistered<ShopShippingNoticeController>()
      ? Get.find<ShopShippingNoticeController>()
      : Get.put(ShopShippingNoticeController(), permanent: true);
  final NavController navController = Get.isRegistered<NavController>()
      ? Get.find<NavController>()
      : Get.put(NavController(), permanent: true);
  final UserController userController = Get.find<UserController>();
  final GlobalGameController _globalGameController =
      GlobalGameController.ensureInstance();

  late final TabController _tabController;
  int _activeTab = 0;
  final ScrollController _onSaleScroll = ScrollController();
  final ScrollController _pendingScroll = ScrollController();
  final ScrollController _recordScroll = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _pendingSearchController =
      TextEditingController();
  final TextEditingController _recordSearchController = TextEditingController();
  final Set<int> _selectedIds = <int>{};
  final Set<int> _refreshingPendingBuyerOrderIds = <int>{};
  Worker? _loginWorker;
  Worker? _shopTargetTabWorker;
  Worker? _shopStatusWorker;
  Worker? _shopTabVisibilityWorker;
  Worker? _gameWorker;
  bool _didResolveInitialOfflineDialog = false;
  bool _isShowingInitialOfflineDialog = false;
  static const List<StatusOption> _statusOptions = [
    StatusOption(
      labelKey: 'app.market.filter.all',
      values: [-2, -1, 1, 2, 3, 4, 5, 6, 9],
    ),
    StatusOption(labelKey: 'app.inventory.on_sale', values: [2, 3, 4]),
    StatusOption(labelKey: 'app.trade.filter.failed', values: [-1]),
    StatusOption(labelKey: 'app.trade.filter.revoked', values: [-2]),
    StatusOption(labelKey: 'app.trade.filter.settling', values: [5]),
    StatusOption(labelKey: 'app.trade.filter.success', values: [6]),
  ];
  static const List<String> _sellAttributeGroupOrder = [
    'type',
    'exterior',
    'quality',
    'rarity',
    'itemSet',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _activeTab = _tabController.index;
    _tabController.addListener(_handleTabChange);
    _onSaleScroll.addListener(_handleOnSaleScroll);
    _pendingScroll.addListener(_handlePendingScroll);
    _recordScroll.addListener(_handleRecordScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      MarketFilterSheet.preload(appId: _globalGameController.appId);
      _scheduleInitialOfflineDialogCheck();
    });
    _shopTargetTabWorker = ever<int?>(navController.pendingShopTabIndex, (
      targetTab,
    ) {
      if (targetTab == null) {
        return;
      }
      _switchToShopTab(targetTab);
      navController.clearPendingShopTab();
    });
    final initialTargetTab = navController.pendingShopTabIndex.value;
    if (initialTargetTab != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        _switchToShopTab(initialTargetTab);
        navController.clearPendingShopTab();
      });
    }
    _shopStatusWorker = everAll(
      [shopController.shop, shopController.isLoading],
      (_) {
        _scheduleInitialOfflineDialogCheck();
      },
    );
    _shopTabVisibilityWorker = ever<int>(navController.currentIndex, (index) {
      if (index == NavController.tabSell) {
        _scheduleInitialOfflineDialogCheck();
      }
    });
    _gameWorker = ever<int>(_globalGameController.currentAppId, (appId) {
      if (!mounted) {
        return;
      }
      unawaited(MarketFilterSheet.preload(appId: appId));
      if (userController.isLoggedIn.value) {
        salesController.refreshOnSale();
        orderController.refreshPending();
        salesController.refreshSellRecords();
        shippingNoticeController.refreshPendingTotals();
      }
      setState(() {});
    });

    if (userController.isLoggedIn.value) {
      salesController.refreshOnSale();
      orderController.refreshPending();
      salesController.refreshSellRecords();
      shippingNoticeController.refreshPendingTotals();
    }

    _loginWorker = ever<bool>(userController.isLoggedIn, (loggedIn) {
      _didResolveInitialOfflineDialog = false;
      _isShowingInitialOfflineDialog = false;
      if (loggedIn) {
        salesController.refreshOnSale();
        orderController.refreshPending();
        salesController.refreshSellRecords();
        shippingNoticeController.refreshPendingTotals();
        _scheduleInitialOfflineDialogCheck();
      }
    });
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    _onSaleScroll
      ..removeListener(_handleOnSaleScroll)
      ..dispose();
    _pendingScroll
      ..removeListener(_handlePendingScroll)
      ..dispose();
    _recordScroll
      ..removeListener(_handleRecordScroll)
      ..dispose();
    _searchController.dispose();
    _pendingSearchController.dispose();
    _recordSearchController.dispose();
    _loginWorker?.dispose();
    _shopTargetTabWorker?.dispose();
    _shopStatusWorker?.dispose();
    _shopTabVisibilityWorker?.dispose();
    _gameWorker?.dispose();
    super.dispose();
  }

  void _scheduleInitialOfflineDialogCheck() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _maybeShowInitialOfflineDialog();
    });
  }

  bool _isShopPageVisible() {
    final route = ModalRoute.of(context);
    final isCurrentRoute = route?.isCurrent ?? true;
    return navController.currentIndex.value == NavController.tabSell &&
        isCurrentRoute;
  }

  void _maybeShowInitialOfflineDialog() {
    if (!mounted ||
        _didResolveInitialOfflineDialog ||
        _isShowingInitialOfflineDialog ||
        !userController.isLoggedIn.value ||
        !_isShopPageVisible() ||
        shopController.isLoading.value) {
      return;
    }
    final shop = shopController.shop.value;
    if (shop == null) {
      return;
    }
    if (shop.isOnline == true) {
      _didResolveInitialOfflineDialog = true;
      return;
    }
    _isShowingInitialOfflineDialog = true;
    unawaited(
      _showInitialOfflineDialog().whenComplete(() {
        _isShowingInitialOfflineDialog = false;
        _didResolveInitialOfflineDialog = true;
      }),
    );
  }

  Future<void> _showInitialOfflineDialog() {
    return showFigmaModal<void>(
      context: context,
      barrierDismissible: true,
      child: _ShopOfflineDialog(
        onCancel: () => popModalRoute(context),
        onOpenSettings: () {
          popModalRoute(context);
          Get.toNamed(Routers.SHOP_SETTING);
        },
      ),
    );
  }

  void _switchToShopTab(int targetTab) {
    final safeIndex = targetTab.clamp(0, _tabController.length - 1).toInt();
    if (_tabController.index == safeIndex) {
      return;
    }
    _tabController.animateTo(safeIndex);
  }

  void _handleTabChange() {
    if (_tabController.index == _activeTab) {
      return;
    }
    setState(() {
      _activeTab = _tabController.index;
      if (_activeTab != 0 && _selectedIds.isNotEmpty) {
        _selectedIds.clear();
      }
    });
  }

  void _handleOnSaleScroll() {
    if (_onSaleScroll.position.pixels >
        _onSaleScroll.position.maxScrollExtent - 200) {
      salesController.loadOnSale();
    }
  }

  void _handlePendingScroll() {
    if (_pendingScroll.position.pixels >
        _pendingScroll.position.maxScrollExtent - 200) {
      orderController.loadPendingShipments();
    }
  }

  void _handleRecordScroll() {
    if (_recordScroll.position.pixels >
        _recordScroll.position.maxScrollExtent - 200) {
      salesController.loadSellRecords();
    }
  }

  void _toggleSelection(ShopItemAsset item) {
    final id = item.id;
    if (id == null) {
      return;
    }
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _toggleSelectAllOnSale(Set<int> selectableIds) {
    if (selectableIds.isEmpty) {
      return;
    }
    setState(() {
      final isAllSelected = selectableIds.every(_selectedIds.contains);
      if (isAllSelected) {
        _selectedIds.removeAll(selectableIds);
      } else {
        _selectedIds.addAll(selectableIds);
      }
    });
  }

  Future<void> _confirmDelist() async {
    if (_selectedIds.isEmpty) {
      return;
    }
    var submitting = false;
    await showFigmaModal<void>(
      context: context,
      barrierDismissible: false,
      child: StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          Future<void> submitDelist() async {
            if (submitting) {
              return;
            }
            setDialogState(() => submitting = true);
            try {
              final res = await salesController.delistItems(
                _selectedIds.toList(),
              );
              if (res.success) {
                if (mounted) {
                  setState(_selectedIds.clear);
                }
                if (dialogContext.mounted) {
                  popModalRoute(dialogContext);
                }
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  AppSnackbar.success('app.system.message.success'.tr);
                });
              } else {
                AppSnackbar.error(
                  res.message.isNotEmpty
                      ? res.message
                      : 'app.trade.filter.failed'.tr,
                );
                if (dialogContext.mounted) {
                  setDialogState(() => submitting = false);
                }
              }
            } catch (_) {
              AppSnackbar.error('app.trade.filter.failed'.tr);
              if (dialogContext.mounted) {
                setDialogState(() => submitting = false);
              }
            }
          }

          return FigmaConfirmationDialog(
            title: _isEnglishLocale ? 'Delist Listing' : '确认下架',
            message: 'app.inventory.message.confirm_delist'.tr,
            primaryLabel: _isEnglishLocale ? 'Confirm Delist' : '确认下架',
            primaryLoading: submitting,
            secondaryLabel: 'app.common.cancel'.tr,
            onPrimary: submitting
                ? null
                : () {
                    submitDelist();
                  },
            onSecondary: submitting ? null : () => popModalRoute(dialogContext),
          );
        },
      ),
    );
  }

  ShopSchemaInfo? _lookupSchema(
    Map<String, ShopSchemaInfo> schemas,
    String? marketHashName,
    int? schemaId,
  ) {
    if (marketHashName != null && schemas.containsKey(marketHashName)) {
      return schemas[marketHashName];
    }
    final key = schemaId?.toString();
    if (key != null && schemas.containsKey(key)) {
      return schemas[key];
    }
    return null;
  }

  TagInfo? _schemaTag(ShopSchemaInfo? schema, String key) {
    final tags = schema?.raw['tags'];
    if (tags is Map) {
      return TagInfo.fromRaw(tags[key]);
    }
    return null;
  }

  int _resolveDetailAppId(ShopOrderDetail detail, ShopSchemaInfo? schema) {
    final raw = detail.raw;
    final schemaRaw = schema?.raw;
    final rawApp = raw['app_id'] ?? raw['appId'];
    final schemaApp = schemaRaw?['app_id'] ?? schemaRaw?['appId'];
    return _asInt(rawApp) ?? _asInt(schemaApp) ?? _globalGameController.appId;
  }

  String? _detailText(ShopOrderDetail detail, List<String> keys) {
    final raw = detail.raw;
    for (final key in keys) {
      final value = raw[key];
      if (value != null) {
        return value.toString();
      }
    }
    return null;
  }

  double? _detailDouble(ShopOrderDetail detail, List<String> keys) {
    final raw = detail.raw;
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
    return null;
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

  String _formatTime(int? timestamp) {
    if (timestamp == null) {
      return '';
    }
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    return DateFormat('yyyy-MM-dd HH:mm').format(date);
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

  int _pendingShippingType(ShopOrderItem order) {
    for (final detail in order.details) {
      if (detail.type == 2) {
        return 2;
      }
    }
    return 1;
  }

  double _pendingShippingHours(ShopOrderItem order) {
    final status = order.status;
    final type = _pendingShippingType(order);
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

  int _pendingDeadlineMs(ShopOrderItem order) {
    final changeTime = order.changeTime;
    if (changeTime == null || changeTime <= 0) {
      return 0;
    }
    final shippingMs = (_pendingShippingHours(order) * 3600 * 1000).round();
    return changeTime * 1000 + shippingMs;
  }

  int _pendingRemainMs(ShopOrderItem order) {
    final deadline = _pendingDeadlineMs(order);
    if (deadline <= 0) {
      return 0;
    }
    final remain = deadline - DateTime.now().millisecondsSinceEpoch;
    return remain > 0 ? remain : 0;
  }

  bool _showPendingCountdown(ShopOrderItem order) {
    return _pendingRemainMs(order) > 0;
  }

  int _pendingOrderKey(ShopOrderItem order) {
    return order.id ?? order.hashCode;
  }

  ShopOrderItem _copyOrderWithUser(ShopOrderItem source, ShopUserInfo? user) {
    return ShopOrderItem(
      raw: source.raw,
      id: source.id,
      status: source.status,
      statusName: source.statusName,
      createTime: source.createTime,
      changeTime: source.changeTime,
      price: source.price,
      totalPrice: source.totalPrice,
      nums: source.nums,
      protectionTime: source.protectionTime,
      type: source.type,
      tradeOfferId: source.tradeOfferId,
      cancelDesc: source.cancelDesc,
      buyerId: source.buyerId,
      details: source.details,
      user: user,
    );
  }

  Future<void> _refreshPendingBuyer(ShopOrderItem order) async {
    final buyerId = (order.buyerId ?? order.user?.id ?? '').trim();
    if (buyerId.isEmpty) {
      return;
    }
    final orderKey = _pendingOrderKey(order);
    if (_refreshingPendingBuyerOrderIds.contains(orderKey)) {
      return;
    }
    setState(() {
      _refreshingPendingBuyerOrderIds.add(orderKey);
    });
    try {
      final res = await ApiSteamServer().getSteamUserInfo(id: buyerId);
      final data = res.datas;
      if (res.code == 0 && data != null) {
        final mergedUser = ShopUserInfo(
          id: data['id']?.toString() ?? order.user?.id ?? buyerId,
          uuid: data['uuid']?.toString() ?? order.user?.uuid,
          avatar: data['avatar']?.toString() ?? order.user?.avatar,
          nickname: data['nickname']?.toString() ?? order.user?.nickname,
          level: _asInt(data['level']) ?? order.user?.level,
          yearsLevel: _asInt(data['yearsLevel']) ?? order.user?.yearsLevel,
        );
        orderController.users[buyerId] = mergedUser;
        final updated = orderController.pendingShipments
            .map((item) {
              final sameOrder = order.id != null && item.id == order.id;
              final sameBuyer = item.buyerId == buyerId;
              if (!sameOrder && !sameBuyer) {
                return item;
              }
              return _copyOrderWithUser(item, mergedUser);
            })
            .toList(growable: false);
        orderController.pendingShipments.assignAll(updated);
        if (mounted) {
          unawaited(
            showGlassNoticeDialog(
              context,
              message: 'app.steam.message.refresh_info_success'.tr,
              icon: Icons.check_circle_outline_rounded,
              barrierLabel: 'refresh_pending_buyer_success',
            ),
          );
        }
      } else {
        final dataText = _extractApiErrorText(data);
        final message = (dataText?.isNotEmpty ?? false)
            ? dataText!
            : (res.message.trim().isNotEmpty
                  ? res.message
                  : 'app.trade.filter.failed'.tr);
        if (mounted) {
          unawaited(
            showGlassNoticeDialog(
              context,
              message: message,
              icon: Icons.error_outline_rounded,
              barrierLabel: 'refresh_pending_buyer_failed',
            ),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        unawaited(
          showGlassNoticeDialog(
            context,
            message: 'app.trade.filter.failed'.tr,
            icon: Icons.error_outline_rounded,
            barrierLabel: 'refresh_pending_buyer_failed',
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _refreshingPendingBuyerOrderIds.remove(orderKey);
        });
      }
    }
  }

  String? _extractApiErrorText(Map<String, dynamic>? data) {
    if (data == null) {
      return null;
    }
    final candidates = [
      data['_message'],
      data['message'],
      data['msg'],
      data['datas'],
      data['error'],
    ];
    for (final candidate in candidates) {
      final text = candidate?.toString().trim();
      if (text != null && text.isNotEmpty) {
        return text;
      }
    }
    return null;
  }

  Widget _buildPendingBuyerInfo(ShopOrderItem order) {
    final user = order.user;
    final nickname = (user?.nickname ?? '').trim();
    final level = user?.level;
    final yearsLevel = user?.yearsLevel;
    final refreshing = _refreshingPendingBuyerOrderIds.contains(
      _pendingOrderKey(order),
    );
    final buyerLabel = _isEnglishLocale ? 'Buyer' : 'app.market.buyer'.tr;
    final displayName = nickname.isEmpty ? '-' : nickname;

    return _buildPendingMetaLine(
      icon: Icons.person_outline_rounded,
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$buyerLabel: $displayName',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF444653),
                fontSize: 11,
                height: 16.5 / 11,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          if (level != null) ...[
            const SizedBox(width: 4),
            Container(
              height: 20,
              constraints: const BoxConstraints(minWidth: 20),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0x1F444653)),
                borderRadius: BorderRadius.circular(999),
                color: Colors.white,
              ),
              child: Text(
                '$level',
                style: const TextStyle(
                  color: Color(0xFF444653),
                  fontSize: 10,
                  height: 14 / 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          if (yearsLevel != null) ...[
            const SizedBox(width: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.network(
                'https://community.cloudflare.steamstatic.com/public/images/badges/02_years/steamyears${yearsLevel}_80.png',
                width: 20,
                height: 20,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ],
          if (user != null) ...[
            const SizedBox(width: 4),
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: refreshing ? null : () => _refreshPendingBuyer(order),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: Center(
                    child: refreshing
                        ? const SizedBox(
                            width: 10,
                            height: 10,
                            child: CircularProgressIndicator(strokeWidth: 1.8),
                          )
                        : const Icon(
                            Icons.refresh_rounded,
                            size: 14,
                            color: Color(0xFF00288E),
                          ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPendingActionButton({
    required String label,
    required bool primary,
    VoidCallback? onTap,
    Color? foregroundColor,
    Color? backgroundColor,
  }) {
    final resolvedForeground =
        foregroundColor ?? (primary ? Colors.white : const Color(0xFF444653));

    return Material(
      color: Colors.transparent,
      child: Ink(
        height: 40,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: primary ? null : backgroundColor ?? const Color(0xFFE6E8EA),
          gradient: primary
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF00288E), Color(0xFF0058BE)],
                )
              : null,
          boxShadow: primary
              ? const [
                  BoxShadow(
                    color: Color(0x1A00288E),
                    offset: Offset(0, 10),
                    blurRadius: 15,
                    spreadRadius: -3,
                  ),
                  BoxShadow(
                    color: Color(0x1A00288E),
                    offset: Offset(0, 4),
                    blurRadius: 6,
                    spreadRadius: -4,
                  ),
                ]
              : null,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: resolvedForeground,
                  fontSize: 14,
                  height: 20 / 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPendingStatusAction(ShopOrderItem order) {
    final status = order.status;
    if (status == 2) {
      return _buildPendingActionButton(
        label: 'app.market.product.deliver'.tr,
        primary: true,
        onTap: () => _openDeliverGoodsPage(order),
      );
    }

    final statusText = status == 3
        ? 'app.steam.message.confirm_quote'.tr
        : (order.statusName ?? '').trim().isEmpty
        ? '-'
        : (order.statusName ?? '').trim();
    final statusColor = status == 3
        ? Theme.of(context).colorScheme.tertiary
        : (status == -1
              ? Theme.of(context).colorScheme.onSurfaceVariant
              : Theme.of(context).colorScheme.error);

    return _buildPendingActionButton(
      label: statusText,
      primary: false,
      foregroundColor: statusColor,
      backgroundColor: statusColor.withValues(alpha: 0.10),
    );
  }

  Widget _buildSellRecordDetailImage({
    required ShopOrderDetail detail,
    required Map<String, ShopSchemaInfo> schemas,
    double width = 72,
    double height = 43,
    bool showTopBadges = true,
    bool showStickers = true,
  }) {
    final schema = _lookupSchema(
      schemas,
      detail.marketHashName,
      detail.schemaId,
    );
    final appId = _resolveDetailAppId(detail, schema);
    final imageUrl = detail.imageUrl ?? schema?.imageUrl ?? '';
    final rarity = _schemaTag(schema, 'rarity');
    final quality = _schemaTag(schema, 'quality');
    final phase = _detailText(detail, ['phase']);
    final percentage = _detailText(detail, ['percentage']);
    final rawAsset = detail.raw['asset'];
    final rawCsgoAsset = detail.raw['csgoAsset'];
    final stickers = showStickers
        ? parseStickerList(
            detail.raw['stickers'] ??
                (rawAsset is Map ? rawAsset['stickers'] : null) ??
                (rawCsgoAsset is Map ? rawCsgoAsset['stickers'] : null),
            schemaMap: schemas,
            stickerMap: salesController.stickers,
          )
        : const <GameItemSticker>[];
    final count = detail.count ?? 1;
    return SizedBox(
      width: width,
      height: height,
      child: GameItemImage(
        imageUrl: imageUrl,
        appId: appId,
        rarity: rarity,
        quality: quality,
        phase: phase,
        percentage: percentage,
        count: count > 1 ? count : null,
        stickers: stickers,
        showTopBadges: showTopBadges,
      ),
    );
  }

  String _buildRecordStatusText(ShopOrderItem record) {
    final status = record.status;
    if (status == 6) {
      return 'Sold successfully';
    }
    if (status == 5) {
      return 'In settlement';
    }
    return 'Sale failed';
  }

  bool _showRecordCountdown(ShopOrderItem record) {
    final protectionTime = record.protectionTime;
    return protectionTime != null && protectionTime > 0 && record.status == 5;
  }

  Future<void> _openOnSaleFilterSheet() async {
    final result = await MarketFilterSheet.showFromLeft(
      context: context,
      appId: _globalGameController.appId,
      sortOptions: const [
        SortOption(labelKey: 'app.market.filter.price', field: 'price'),
        SortOption(labelKey: 'app.market.filter.time', field: 'time'),
        SortOption(labelKey: 'app.market.csgo.wear', field: 'paintWear'),
      ],
      showPriceRange: false,
      attributeGroupOrder: _sellAttributeGroupOrder,
      includeFallbackAttributeGroups: false,
      includeDefaultSortOption: false,
      useCompactSortLabels: true,
      initial: MarketFilterResult(
        sortField: salesController.onSaleSortField.value,
        sortAsc: salesController.onSaleSortField.value.isEmpty
            ? false
            : salesController.onSaleSortAsc.value,
        priceMin: salesController.onSalePriceMin.value,
        priceMax: salesController.onSalePriceMax.value,
        tags: Map<String, dynamic>.from(salesController.onSaleTags),
        itemName: salesController.onSaleItemName.value,
      ),
    );
    if (result != null) {
      if (result.clearKeyword) {
        _searchController.clear();
      }
      await salesController.applyOnSaleFilter(
        sortField: result.sortField,
        sortAsc: result.sortField.isEmpty ? false : result.sortAsc,
        minPrice: result.priceMin,
        maxPrice: result.priceMax,
        tags: result.tags,
        itemName: result.itemName,
        keyword: result.clearKeyword ? '' : null,
      );
    }
  }

  Future<void> _openPendingFilterSheet() async {
    final result = await MarketFilterSheet.showFromLeft(
      context: context,
      appId: _globalGameController.appId,
      sortOptions: const [
        SortOption(labelKey: 'app.market.filter.time', field: 'time'),
      ],
      showPriceRange: false,
      showAttributeFilters: false,
      includeDefaultSortOption: false,
      useCompactSortLabels: true,
      initial: MarketFilterResult(
        sortField: orderController.pendingSortField.value,
        sortAsc: orderController.pendingSortField.value.isEmpty
            ? false
            : orderController.pendingSortAsc.value,
        tags: Map<String, dynamic>.from(orderController.pendingTags),
        itemName: orderController.pendingItemName.value,
      ),
    );
    if (result != null) {
      if (result.clearKeyword) {
        _pendingSearchController.clear();
      }
      await orderController.applyPendingFilter(
        sortField: result.sortField,
        sortAsc: result.sortField.isEmpty ? false : result.sortAsc,
        tags: result.tags,
        itemName: result.itemName,
        keyword: result.clearKeyword ? '' : null,
      );
    }
  }

  Future<void> _openSellRecordFilterSheet() async {
    final result = await MarketFilterSheet.showFromLeft(
      context: context,
      appId: _globalGameController.appId,
      sortOptions: const [
        SortOption(labelKey: 'app.market.filter.time', field: 'time'),
      ],
      showSort: false,
      showPriceRange: false,
      showStatus: true,
      showDateRange: true,
      statusOptions: _statusOptions,
      attributeGroupOrder: _sellAttributeGroupOrder,
      includeFallbackAttributeGroups: false,
      initial: MarketFilterResult(
        sortField: salesController.recordSortField.value,
        sortAsc: salesController.recordSortField.value.isEmpty
            ? false
            : salesController.recordSortAsc.value,
        tags: Map<String, dynamic>.from(salesController.recordTags),
        itemName: salesController.recordItemName.value,
        statusList: salesController.recordStatusList.toList(),
        startDate: salesController.recordStartDate.value,
        endDate: salesController.recordEndDate.value,
      ),
    );
    if (result != null) {
      if (result.clearKeyword) {
        _recordSearchController.clear();
      }
      await salesController.applyRecordFilter(
        statusList: result.statusList,
        startDate: result.startDate,
        endDate: result.endDate,
        sortAsc: result.sortField.isEmpty ? false : result.sortAsc,
        sortField: result.sortField,
        tags: result.tags,
        itemName: result.itemName,
        keyword: result.clearKeyword ? '' : null,
      );
    }
  }

  Future<void> _openActiveTabFilterSheet() {
    switch (_currentShopTabFilter()) {
      case _ShopTabFilter.onSale:
        return _openOnSaleFilterSheet();
      case _ShopTabFilter.pending:
        return _openPendingFilterSheet();
      case _ShopTabFilter.saleRecord:
        return _openSellRecordFilterSheet();
    }
  }

  bool _isActiveTabFilterApplied() {
    switch (_currentShopTabFilter()) {
      case _ShopTabFilter.onSale:
        return salesController.onSaleSortField.value.isNotEmpty ||
            salesController.onSalePriceMin.value != null ||
            salesController.onSalePriceMax.value != null ||
            salesController.onSaleTags.isNotEmpty ||
            (salesController.onSaleItemName.value?.isNotEmpty ?? false);
      case _ShopTabFilter.pending:
        return orderController.pendingSortField.value.isNotEmpty ||
            orderController.pendingTags.isNotEmpty ||
            (orderController.pendingItemName.value?.isNotEmpty ?? false);
      case _ShopTabFilter.saleRecord:
        return salesController.recordSortField.value.isNotEmpty ||
            salesController.recordTags.isNotEmpty ||
            (salesController.recordItemName.value?.isNotEmpty ?? false) ||
            salesController.recordStatusList.isNotEmpty ||
            salesController.recordStartDate.value != null ||
            salesController.recordEndDate.value != null;
    }
  }

  _ShopTabFilter _currentShopTabFilter() {
    switch (_activeTab) {
      case 1:
        return _ShopTabFilter.pending;
      case 2:
        return _ShopTabFilter.saleRecord;
      case 0:
      default:
        return _ShopTabFilter.onSale;
    }
  }

  String _gameLabelForAppId(int appId) {
    return switch (appId) {
      730 => 'CS2',
      570 => 'DOTA2',
      440 => 'TF2',
      _ => 'GAME',
    };
  }

  String _shopTabLabel(_ShopTabFilter filter) {
    if (_isEnglishLocale) {
      return switch (filter) {
        _ShopTabFilter.onSale => 'On Sale',
        _ShopTabFilter.pending => 'Awaiting Delivery',
        _ShopTabFilter.saleRecord => 'Sold',
      };
    }
    return switch (filter) {
      _ShopTabFilter.onSale => 'app.trade.onSale.text'.tr,
      _ShopTabFilter.pending => 'app.market.product.wait_for_sending'.tr,
      _ShopTabFilter.saleRecord => 'app.user.menu.sale'.tr,
    };
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
    double top = 2,
    double right = 2,
    double size = 8,
    bool glow = false,
  }) {
    if (!visible) {
      return child;
    }
    return Stack(
      children: [
        child,
        Positioned(
          right: right,
          top: top,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
              border: Border.all(
                color: Theme.of(context).colorScheme.surface,
                width: 1,
              ),
              boxShadow: glow
                  ? [
                      BoxShadow(
                        color: dotColor.withValues(alpha: 0.34),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildShopSummaryBar(CurrencyController currency) {
    final colors = Theme.of(context).colorScheme;
    final borderColor = colors.outline.withValues(alpha: 0.12);

    return Obx(() {
      final count = salesController.totalOnSale.value;
      final totalValue = salesController.totalOnSalePrice.value;
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
              child: _buildShopSummaryMetric(
                label: 'app.inventory.count'.tr,
                value: '$count',
              ),
            ),
            Container(
              width: 1,
              height: 14,
              color: borderColor,
              margin: const EdgeInsets.symmetric(horizontal: 10),
            ),
            Expanded(
              child: _buildShopSummaryMetric(
                label: 'app.inventory.total_value'.tr,
                value: currency.format(totalValue),
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildShopSummaryMetric({
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

  @override
  Widget build(BuildContext context) {
    final currency = Get.find<CurrencyController>();
    return BackToTopScope(
      enabled: false,
      child: Scaffold(
        body: Obx(() {
          if (!userController.isLoggedIn.value) {
            return _buildLoginPrompt();
          }
          return SafeArea(
            child: Column(
              children: [
                _buildHeader(currency),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildOnSaleTab(),
                      _buildPendingShipmentTab(currency),
                      _buildSellRecordTab(currency),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
        bottomNavigationBar: _activeTab == 0 && _selectedIds.isNotEmpty
            ? _buildOnSaleActions()
            : null,
      ),
    );
  }

  Widget _buildLoginPrompt() {
    return const LoginRequiredPrompt();
  }

  Widget _buildHeader(CurrencyController currency) {
    final colors = Theme.of(context).colorScheme;
    final isShopOnline = shopController.shop.value?.isOnline ?? false;

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
                        active: _isActiveTabFilterApplied(),
                        onTap: _openActiveTabFilterSheet,
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          'app.user.menu.shop'.tr,
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
                _buildTopActionWithDot(
                  visible: true,
                  dotColor: isShopOnline
                      ? const Color(0xFF22C55E)
                      : colors.outlineVariant,
                  child: _buildTopIconAction(
                    icon: Icons.settings_outlined,
                    tooltip: 'app.user.shop.setting'.tr,
                    onTap: () => Get.toNamed(Routers.SHOP_SETTING),
                  ),
                ),
                const SizedBox(width: 8),
                _buildGameSwitchTrigger(),
              ],
            ),
          ),
          _buildSharedTabSearchBar(),
          Align(alignment: Alignment.centerLeft, child: _buildShopTabBar()),
          if (_activeTab == 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
              child: _buildShopSummaryBar(currency),
            )
          else
            const SizedBox(height: 6),
        ],
      ),
    );
  }

  Widget _buildTabSearchBar({
    required TextEditingController controller,
    required ValueChanged<String> onSubmitted,
    required VoidCallback onSearch,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: AppSearchInputBar(
        controller: controller,
        hintText: 'app.market.filter.search'.tr,
        onSubmitted: onSubmitted,
        onChanged: (_) {
          if (mounted) {
            setState(() {});
          }
        },
        onClearTap: () {
          controller.clear();
          if (mounted) {
            setState(() {});
          }
        },
        onSearchTap: onSearch,
      ),
    );
  }

  Widget _buildGameSwitchTrigger() {
    return Obx(() {
      final appId = _globalGameController.currentAppId.value;
      final showPendingDot = shippingNoticeController.hasOtherPending(appId);
      return Builder(
        builder: (switchContext) {
          return _buildTopActionWithDot(
            visible: showPendingDot,
            dotColor: _pendingNoticeDot,
            right: 4,
            top: 5,
            size: 9,
            glow: true,
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () async {
                  final selected = await showGameSwitchMenu(
                    iconContext: switchContext,
                    currentAppId: appId,
                    pendingTotalsByAppId: shippingNoticeController
                        .snapshotTotals(),
                  );
                  if (selected == null) {
                    return;
                  }
                  await _globalGameController.switchGame(selected);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
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
            ),
          );
        },
      );
    });
  }

  Widget _buildShopTabBar() {
    return Obx(() {
      final currentAppId = _globalGameController.currentAppId.value;
      final showPendingDot =
          shippingNoticeController.pendingCount(currentAppId) > 0;
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
          Tab(height: 30, text: _shopTabLabel(_ShopTabFilter.onSale)),
          Tab(
            height: 30,
            child: _buildPendingTabLabel(showDot: showPendingDot),
          ),
          Tab(height: 30, text: _shopTabLabel(_ShopTabFilter.saleRecord)),
        ],
      );
    });
  }

  Widget _buildPendingTabLabel({required bool showDot}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(_shopTabLabel(_ShopTabFilter.pending)),
        if (showDot) ...[
          const SizedBox(width: 6),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: _pendingNoticeDot,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _pendingNoticeDot.withValues(alpha: 0.28),
                  blurRadius: 6,
                  spreadRadius: 0.5,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildEmptyStateView({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
      child: SizedBox.expand(
        child: MarketEmptyState(
          title: title,
          subtitle: subtitle,
          icon: icon,
          blendWithBackground: true,
        ),
      ),
    );
  }

  Widget _buildLoadingLine({
    double? width,
    required double height,
    double radius = 999,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFF2F4F6),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }

  Widget _buildSectionCard({
    required Widget child,
    VoidCallback? onTap,
    EdgeInsetsGeometry padding = const EdgeInsets.all(14),
  }) {
    final borderColor = Theme.of(
      context,
    ).colorScheme.outline.withValues(alpha: 0.12);
    final content = Padding(padding: padding, child: child);
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A0F172A),
              offset: Offset(0, 3),
              blurRadius: 10,
            ),
          ],
        ),
        child: onTap == null
            ? content
            : InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: onTap,
                child: content,
              ),
      ),
    );
  }

  Widget _buildPendingCardShell({
    required Widget child,
    VoidCallback? onTap,
    EdgeInsetsGeometry padding = const EdgeInsets.all(16),
  }) {
    final content = Padding(padding: padding, child: child);
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0x99FFFFFF)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x05000000),
              offset: Offset(0, 2),
              blurRadius: 12,
            ),
          ],
        ),
        child: onTap == null
            ? content
            : InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: onTap,
                child: content,
              ),
      ),
    );
  }

  Widget _buildInsetPanel({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.fromLTRB(10, 8, 10, 8),
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.06)),
      ),
      child: child,
    );
  }

  Widget _buildInfoChip({
    required String text,
    required Color foregroundColor,
    required Color backgroundColor,
    IconData? icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: foregroundColor),
            const SizedBox(width: 4),
          ],
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 140),
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: foregroundColor,
                fontSize: 11,
                height: 14 / 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOnSaleLoadingView() {
    return GridView.builder(
      key: const PageStorageKey<String>('shop-on-sale-loading'),
      physics: const NeverScrollableScrollPhysics(),
      padding: _gridPadding,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: _gridColumns,
        mainAxisSpacing: _gridMainSpacing,
        crossAxisSpacing: _gridCrossSpacing,
        childAspectRatio: _gridAspectRatio,
      ),
      itemCount: _onSaleLoadingPlaceholderCount,
      itemBuilder: (_, __) => const MarketShowcaseLoadingCard(),
    );
  }

  Widget _buildPendingLoadingView() {
    return ListView.separated(
      key: const PageStorageKey<String>('shop-pending-loading'),
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      itemCount: _pendingLoadingPlaceholderCount,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, __) => _buildPendingLoadingCard(),
    );
  }

  Widget _buildPendingLoadingCard() {
    return _buildPendingCardShell(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFFEDF1F4),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLoadingLine(width: 72, height: 11, radius: 6),
                    const SizedBox(height: 8),
                    _buildLoadingLine(height: 16, radius: 8),
                    const SizedBox(height: 10),
                    _buildLoadingLine(width: 110, height: 16, radius: 8),
                    const SizedBox(height: 12),
                    _buildLoadingLine(width: 136, height: 11, radius: 6),
                    const SizedBox(height: 6),
                    _buildLoadingLine(width: 124, height: 11, radius: 6),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildLoadingLine(width: 96, height: 24, radius: 999),
          const SizedBox(height: 12),
          Column(
            children: [
              _buildInsetPanel(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEDF1F4),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: _buildLoadingLine(height: 12, radius: 8)),
                    const SizedBox(width: 12),
                    _buildLoadingLine(width: 34, height: 18, radius: 999),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _buildLoadingLine(height: 40, radius: 8)),
              const SizedBox(width: 12),
              _buildLoadingLine(width: 104, height: 40, radius: 8),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSellRecordLoadingView() {
    return ListView.separated(
      key: const PageStorageKey<String>('shop-sell-record-loading'),
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      itemCount: _recordLoadingPlaceholderCount,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, __) => _buildSellRecordLoadingCard(),
    );
  }

  Widget _buildSellRecordLoadingCard() {
    return _buildSectionCard(
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _buildLoadingLine(width: 120, height: 12)),
              const SizedBox(width: 12),
              _buildLoadingLine(width: 72, height: 24),
            ],
          ),
          const SizedBox(height: 12),
          _buildInsetPanel(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 76,
                  height: 46,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEDF1F4),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLoadingLine(height: 12),
                      const SizedBox(height: 8),
                      _buildLoadingLine(width: 110, height: 11),
                      const SizedBox(height: 10),
                      _buildLoadingLine(width: 92, height: 16),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSharedTabSearchBar() {
    switch (_activeTab) {
      case 0:
        return _buildTabSearchBar(
          controller: _searchController,
          onSubmitted: salesController.searchOnSale,
          onSearch: () => salesController.searchOnSale(_searchController.text),
        );
      case 1:
        return _buildTabSearchBar(
          controller: _pendingSearchController,
          onSubmitted: orderController.searchPending,
          onSearch: () =>
              orderController.searchPending(_pendingSearchController.text),
        );
      case 2:
        return _buildTabSearchBar(
          controller: _recordSearchController,
          onSubmitted: salesController.searchSellRecords,
          onSearch: () =>
              salesController.searchSellRecords(_recordSearchController.text),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  bool get _isEnglishLocale =>
      Get.locale?.languageCode.toLowerCase().startsWith('en') ?? false;

  String get _shopEmptySubtitle => _isEnglishLocale
      ? 'Adjust your search or filters, then check back again.'
      : '调整搜索或筛选条件后，再回来看看。';

  String _shopEmptyTitle(_ShopTabFilter filter) {
    if (_isEnglishLocale) {
      return switch (filter) {
        _ShopTabFilter.onSale => 'No items on sale',
        _ShopTabFilter.pending => 'No pending shipments',
        _ShopTabFilter.saleRecord => 'No sale records',
      };
    }
    return switch (filter) {
      _ShopTabFilter.onSale => '暂无在售饰品',
      _ShopTabFilter.pending => '暂无待发货订单',
      _ShopTabFilter.saleRecord => '暂无出售记录',
    };
  }

  Widget _buildOnSaleTab() {
    return Obx(() {
      if (salesController.onSaleItems.isEmpty &&
          salesController.isLoadingOnSale.value) {
        return _buildOnSaleLoadingView();
      }
      if (salesController.onSaleItems.isEmpty) {
        return _buildEmptyStateView(
          icon: Icons.storefront_outlined,
          title: _shopEmptyTitle(_ShopTabFilter.onSale),
          subtitle: _shopEmptySubtitle,
        );
      }
      final showLoadingFooter =
          salesController.isLoadingOnSale.value &&
          salesController.onSaleItems.isNotEmpty;
      final showNoMoreFooter =
          salesController.onSaleItems.isNotEmpty &&
          !salesController.isLoadingOnSale.value &&
          !salesController.onSaleHasMore;
      return RefreshIndicator(
        color: const Color(0xFF00288E),
        backgroundColor: Colors.white,
        strokeWidth: 2.2,
        displacement: 22,
        edgeOffset: 2,
        elevation: 0,
        onRefresh: salesController.refreshOnSale,
        child: CustomScrollView(
          controller: _onSaleScroll,
          physics: const AlwaysScrollableScrollPhysics(
            parent: ClampingScrollPhysics(),
          ),
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
                    salesController.onSaleItems.length +
                    (showLoadingFooter ? _footerLoadingPlaceholderCount : 0),
                itemBuilder: (context, index) {
                  if (index >= salesController.onSaleItems.length) {
                    return const MarketShowcaseLoadingCard();
                  }
                  final item = salesController.onSaleItems[index];
                  final schema = _lookupSchema(
                    salesController.schemas,
                    item.marketHashName,
                    item.schemaId,
                  );
                  final selected = _selectedIds.contains(item.id ?? -1);
                  return ShopSaleItemCard(
                    item: item,
                    schema: schema,
                    schemaMap: salesController.schemas,
                    stickerMap: salesController.stickers,
                    selected: selected,
                    showSelectionControl: _selectedIds.isNotEmpty,
                    onTap: () => _toggleSelection(item),
                  );
                },
              ),
            ),
            if (showNoMoreFooter) const SliverToBoxAdapter(child: ListEndTip()),
          ],
        ),
      );
    });
  }

  Widget _buildPendingShipmentTab(CurrencyController currency) {
    return Obx(() {
      if (orderController.pendingShipments.isEmpty &&
          orderController.isLoadingPending.value) {
        return _buildPendingLoadingView();
      }
      if (orderController.pendingShipments.isEmpty) {
        return _buildEmptyStateView(
          icon: Icons.local_shipping_outlined,
          title: _shopEmptyTitle(_ShopTabFilter.pending),
          subtitle: _shopEmptySubtitle,
        );
      }
      final pendingShipments = orderController.pendingShipments;
      final showLoadingFooter =
          orderController.isLoadingPending.value && pendingShipments.isNotEmpty;
      final showNoMoreFooter =
          pendingShipments.isNotEmpty &&
          !orderController.isLoadingPending.value &&
          !orderController.pendingHasMore;
      final loadingPlaceholderCount = showLoadingFooter
          ? _footerLoadingPlaceholderCount
          : 0;
      final footerCount = showNoMoreFooter ? 1 : 0;
      return RefreshIndicator(
        color: const Color(0xFF00288E),
        backgroundColor: Colors.white,
        strokeWidth: 2.2,
        displacement: 22,
        edgeOffset: 2,
        elevation: 0,
        onRefresh: orderController.refreshPending,
        child: ListView.separated(
          controller: _pendingScroll,
          physics: const AlwaysScrollableScrollPhysics(
            parent: ClampingScrollPhysics(),
          ),
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          itemCount:
              pendingShipments.length + loadingPlaceholderCount + footerCount,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            if (index >= pendingShipments.length) {
              final skeletonIndex = index - pendingShipments.length;
              if (skeletonIndex < loadingPlaceholderCount) {
                return _buildPendingLoadingCard();
              }
              return const ListEndTip();
            }
            final order = pendingShipments[index];
            return _buildPendingShipmentCard(order: order, currency: currency);
          },
        ),
      );
    });
  }

  Widget _buildPendingShipmentCard({
    required ShopOrderItem order,
    required CurrencyController currency,
  }) {
    final details = order.details;
    final primary = details.isNotEmpty ? details.first : null;
    final primarySchema = primary == null
        ? null
        : _lookupSchema(
            orderController.schemas,
            primary.marketHashName,
            primary.schemaId,
          );
    final title =
        primary?.marketName ??
        primarySchema?.marketName ??
        primary?.marketHashName ??
        '-';
    final totalPrice = _sumOrderPrice(order);
    final primaryCount = primary?.count ?? 1;
    final totalItemCount = details.fold<int>(
      0,
      (sum, detail) => sum + (detail.count ?? 1),
    );
    final extraDetails = details.length > 1 ? details.sublist(1) : const [];
    final showCountdown = _showPendingCountdown(order);
    final deadlineMs = _pendingDeadlineMs(order);

    return _buildPendingCardShell(
      onTap: () => _openPendingShipmentDetail(order),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPendingPreview(detail: primary, schema: primarySchema),
              const SizedBox(width: 16),
              Expanded(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 80),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              softWrap: false,
                              style: const TextStyle(
                                color: Color(0xFF191C1E),
                                fontSize: 16,
                                height: 24 / 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (primaryCount > 1) ...[
                            const SizedBox(width: 8),
                            _buildInfoChip(
                              text: 'x$primaryCount',
                              foregroundColor: const Color(0xFF00288E),
                              backgroundColor: const Color(0xFFE9F0FF),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        currency.format(totalPrice),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFFBA1A1A),
                          fontSize: 16,
                          height: 24 / 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildPendingBuyerInfo(order),
                      const SizedBox(height: 4),
                      _buildPendingMetaLine(
                        icon: Icons.access_time_rounded,
                        child: Text(
                          _formatTime(order.createTime),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF444653),
                            fontSize: 11,
                            height: 16.5 / 11,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (details.isEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'app.common.no_data'.tr,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 12,
                height: 18 / 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ] else if (extraDetails.isNotEmpty || primaryCount > 1) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildInfoChip(
                  text: 'x$totalItemCount',
                  foregroundColor: const Color(0xFF00288E),
                  backgroundColor: const Color(0xFFE9F0FF),
                ),
              ],
            ),
          ],
          if (extraDetails.isNotEmpty) ...[
            const SizedBox(height: 12),
            Column(
              children: extraDetails.asMap().entries.map((entry) {
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: entry.key == extraDetails.length - 1 ? 0 : 8,
                  ),
                  child: _buildPendingExtraDetailRow(entry.value),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _buildPendingStatusAction(order)),
              if (showCountdown) ...[
                const SizedBox(width: 12),
                _buildPendingCountdownBadge(deadlineMs),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPendingPreview({
    required ShopOrderDetail? detail,
    required ShopSchemaInfo? schema,
  }) {
    if (detail == null) {
      return Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: const Color(0xFFECEEF0),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(
          Icons.image_not_supported_outlined,
          size: 20,
          color: Color(0xFF94A3B8),
        ),
      );
    }

    final appId = _resolveDetailAppId(detail, schema);
    final imageUrl = detail.imageUrl ?? schema?.imageUrl ?? '';
    final rarity = _schemaTag(schema, 'rarity');
    final quality = _schemaTag(schema, 'quality');

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 80,
        height: 80,
        child: Stack(
          children: [
            Positioned.fill(
              child: ColoredBox(
                color: const Color(0xFFECEEF0),
                child: GameItemImage(
                  imageUrl: imageUrl,
                  appId: appId,
                  rarity: rarity,
                  quality: quality,
                  showTopBadges: false,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingExtraDetailRow(ShopOrderDetail detail) {
    final schema = _lookupSchema(
      orderController.schemas,
      detail.marketHashName,
      detail.schemaId,
    );
    final appId = _resolveDetailAppId(detail, schema);
    final imageUrl = detail.imageUrl ?? schema?.imageUrl ?? '';
    final title =
        detail.marketName ?? schema?.marketName ?? detail.marketHashName ?? '-';
    final count = detail.count ?? 1;
    final rarity = _schemaTag(schema, 'rarity');
    final quality = _schemaTag(schema, 'quality');

    return _buildInsetPanel(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 44,
              height: 44,
              child: GameItemImage(
                imageUrl: imageUrl,
                appId: appId,
                rarity: rarity,
                quality: quality,
                showTopBadges: false,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF191C1E),
                fontSize: 12,
                height: 18 / 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (count > 1) ...[
            const SizedBox(width: 8),
            _buildInfoChip(
              text: 'x$count',
              foregroundColor: const Color(0xFF00288E),
              backgroundColor: const Color(0xFFE9F0FF),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPendingMetaLine({
    required IconData icon,
    required Widget child,
    Color iconColor = const Color(0xFF444653),
  }) {
    return Row(
      children: [
        Icon(icon, size: 14, color: iconColor),
        const SizedBox(width: 4),
        Expanded(child: child),
      ],
    );
  }

  Widget _buildPendingCountdownBadge(int deadlineMs) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F5F7),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.schedule_rounded,
            size: 14,
            color: Color(0xFF6B7280),
          ),
          const SizedBox(width: 6),
          _PendingShipmentCountdown(
            endTimeMs: deadlineMs,
            style: const TextStyle(
              color: Color(0xFF444653),
              fontSize: 12,
              height: 18 / 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSellRecordTab(CurrencyController currency) {
    return Column(
      children: [
        Expanded(
          child: Obx(() {
            if (salesController.sellRecords.isEmpty &&
                salesController.isLoadingRecords.value) {
              return _buildSellRecordLoadingView();
            }
            if (salesController.sellRecords.isEmpty) {
              return _buildEmptyStateView(
                icon: Icons.receipt_long_outlined,
                title: _shopEmptyTitle(_ShopTabFilter.saleRecord),
                subtitle: _shopEmptySubtitle,
              );
            }
            final sellRecords = salesController.sellRecords;
            final showLoadingFooter =
                salesController.isLoadingRecords.value &&
                sellRecords.isNotEmpty;
            final showNoMoreFooter =
                sellRecords.isNotEmpty &&
                !salesController.isLoadingRecords.value &&
                !salesController.recordHasMore;
            final loadingPlaceholderCount = showLoadingFooter
                ? _footerLoadingPlaceholderCount
                : 0;
            final footerCount = showNoMoreFooter ? 1 : 0;
            return RefreshIndicator(
              color: const Color(0xFF00288E),
              backgroundColor: Colors.white,
              strokeWidth: 2.2,
              displacement: 22,
              edgeOffset: 2,
              elevation: 0,
              onRefresh: salesController.refreshSellRecords,
              child: ListView.separated(
                controller: _recordScroll,
                physics: const AlwaysScrollableScrollPhysics(
                  parent: ClampingScrollPhysics(),
                ),
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                itemCount:
                    sellRecords.length + loadingPlaceholderCount + footerCount,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  if (index >= sellRecords.length) {
                    final skeletonIndex = index - sellRecords.length;
                    if (skeletonIndex < loadingPlaceholderCount) {
                      return _buildSellRecordLoadingCard();
                    }
                    return const ListEndTip();
                  }
                  final record = sellRecords[index];
                  return _buildSellRecordHistoryCard(
                    record: record,
                    currency: currency,
                  );
                },
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildSellRecordHistoryCard({
    required ShopOrderItem record,
    required CurrencyController currency,
  }) {
    final primary = record.details.isNotEmpty ? record.details.first : null;
    final schema = primary == null
        ? null
        : _lookupSchema(
            salesController.schemas,
            primary.marketHashName,
            primary.schemaId,
          );
    final title = primary?.marketName ?? schema?.marketName ?? '-';
    final totalPrice = _sumOrderPrice(record);
    final wearValue =
        primary?.paintWear ??
        (primary == null
            ? null
            : _detailDouble(primary, const ['paint_wear', 'paintWear']));
    final wearText = primary == null
        ? null
        : _detailText(primary, const ['paint_wear', 'paintWear']) ??
              wearValue?.toString();
    final totalItemCount = record.details.fold<int>(
      0,
      (sum, detail) => sum + (detail.count ?? 1),
    );
    final hiddenDetailCount = record.details.length > 1
        ? record.details.length - 1
        : 0;
    final showCountdown = _showRecordCountdown(record);
    final statusText = _buildRecordStatusText(record);
    final statusVisual = _buildSellRecordStatusVisual(record);
    final titleColor = statusVisual.muted
        ? const Color(0xFF475569)
        : const Color(0xFF0F172A);
    final secondaryColor = statusVisual.muted
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);
    final priceColor = statusVisual.muted
        ? const Color(0xFF94A3B8)
        : const Color(0xFF0F172A);
    final priceTextDecoration = statusVisual.muted
        ? TextDecoration.lineThrough
        : TextDecoration.none;

    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFF0F0F0)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A000000),
              offset: Offset(0, 10),
              blurRadius: 15,
              spreadRadius: -3,
            ),
            BoxShadow(
              color: Color(0x1A000000),
              offset: Offset(0, 4),
              blurRadius: 6,
              spreadRadius: -4,
            ),
          ],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _openSellRecordDetail(record),
          child: Opacity(
            opacity: statusVisual.muted ? 0.84 : 1,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(17, 17, 17, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSellRecordPreviewBox(
                    primary: primary,
                    hiddenDetailCount: hiddenDetailCount,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final statusMaxWidth = constraints.maxWidth >= 222
                            ? 132.0
                            : 124.0;

                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: titleColor,
                                      fontSize: 14,
                                      height: 17.5 / 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  fit: FlexFit.loose,
                                  child: Align(
                                    alignment: Alignment.topRight,
                                    child: ConstrainedBox(
                                      constraints: BoxConstraints(
                                        maxWidth: statusMaxWidth,
                                      ),
                                      child: _buildSellRecordStatusChip(
                                        text: statusText,
                                        visual: statusVisual,
                                        secondary:
                                            showCountdown &&
                                                record.protectionTime != null
                                            ? _RecordProtectionCountdownText(
                                                endTimeSeconds:
                                                    record.protectionTime!,
                                                style: const TextStyle(
                                                  color: Color(0xFF777777),
                                                  fontSize: 10,
                                                  height: 15 / 10,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              )
                                            : null,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            if (wearValue != null &&
                                wearValue > 0 &&
                                wearText != null &&
                                wearText.isNotEmpty)
                              _buildSellRecordWearRow(
                                wearValue: wearValue,
                                wearText: wearText,
                                textColor: secondaryColor,
                              )
                            else if (totalItemCount > 1)
                              Text(
                                'x$totalItemCount',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: secondaryColor,
                                  fontSize: 10,
                                  height: 15 / 10,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            const SizedBox(height: 12),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Expanded(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      SizedBox(
                                        width: double.infinity,
                                        height: 20,
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          alignment: Alignment.centerLeft,
                                          child: Text(
                                            _formatTime(record.createTime),
                                            softWrap: false,
                                            style: TextStyle(
                                              color: secondaryColor,
                                              fontSize: 14,
                                              height: 20 / 14,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Flexible(
                                  fit: FlexFit.loose,
                                  child: Obx(
                                    () => Align(
                                      alignment: Alignment.centerRight,
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            currency.format(totalPrice),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: priceColor,
                                              fontSize: 18,
                                              height: 28 / 18,
                                              fontWeight: FontWeight.w800,
                                              decoration: priceTextDecoration,
                                              decorationColor: priceColor,
                                            ),
                                          ),
                                          if (!showCountdown &&
                                              totalItemCount > 1) ...[
                                            const SizedBox(height: 1),
                                            Text(
                                              'x$totalItemCount',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: secondaryColor,
                                                fontSize: 10,
                                                height: 15 / 10,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      },
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

  Widget _buildSellRecordPreviewBox({
    required ShopOrderDetail? primary,
    required int hiddenDetailCount,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0x1AC4C5D5)),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: primary == null
              ? const Center(
                  child: Icon(
                    Icons.image_not_supported_outlined,
                    size: 18,
                    color: Colors.white54,
                  ),
                )
              : Center(
                  child: _buildSellRecordDetailImage(
                    detail: primary,
                    schemas: salesController.schemas,
                    width: 80,
                    height: 80,
                    showTopBadges: false,
                    showStickers: false,
                  ),
                ),
        ),
        if (hiddenDetailCount > 0)
          Positioned(
            right: 6,
            bottom: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.58),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '+$hiddenDetailCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  height: 12 / 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSellRecordWearRow({
    required double wearValue,
    required String wearText,
    required Color textColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 64,
          child: _buildSellRecordWearTrack(wearValue: wearValue),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            wearText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: textColor,
              fontSize: 10,
              height: 15 / 10,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSellRecordStatusChip({
    required String text,
    required ({Color foreground, Color background, IconData icon, bool muted})
    visual,
    Widget? secondary,
  }) {
    final showIcon = visual.icon != Icons.hourglass_top_rounded;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showIcon) ...[
              Icon(visual.icon, size: 12, color: visual.foreground),
              const SizedBox(width: 3),
            ],
            Flexible(
              child: Text(
                text,
                maxLines: 1,
                softWrap: false,
                style: TextStyle(
                  color: visual.foreground,
                  fontSize: 11,
                  height: 16 / 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        if (secondary != null) ...[
          const SizedBox(height: 2),
          DefaultTextStyle.merge(textAlign: TextAlign.right, child: secondary),
        ],
      ],
    );
  }

  Color _sellRecordStatusColor(ShopOrderItem record) {
    if (record.status == 6 || record.status == 5) {
      return const Color(0xFF67C23A);
    }
    return const Color(0xFFF56C6C);
  }

  IconData _sellRecordStatusIcon(ShopOrderItem record) {
    if (record.status == 6) {
      return Icons.check_circle_rounded;
    }
    if (record.status != 5) {
      return Icons.cancel_rounded;
    }
    return Icons.hourglass_top_rounded;
  }

  bool _sellRecordStatusMuted(ShopOrderItem record) {
    return record.status != 5 && record.status != 6;
  }

  ({Color foreground, Color background, IconData icon, bool muted})
  _buildSellRecordStatusVisual(ShopOrderItem record) {
    return (
      foreground: _sellRecordStatusColor(record),
      background: Colors.transparent,
      icon: _sellRecordStatusIcon(record),
      muted: _sellRecordStatusMuted(record),
    );
  }

  Widget _buildSellRecordWearTrack({required double wearValue}) {
    final normalizedWear = wearValue.clamp(0.0, 1.0).toDouble();
    final fillFactor = normalizedWear <= 0
        ? 0.0
        : normalizedWear.clamp(0.06, 1.0).toDouble();
    final fillColor = _sellRecordConditionColor(
      _sellRecordConditionLabelForWear(normalizedWear),
    );

    return SizedBox(
      height: 4,
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFFB8C1CC).withValues(alpha: 0.38),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: fillFactor,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: fillColor,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const SizedBox(height: 4),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _sellRecordConditionLabelForWear(double wearValue) {
    if (wearValue < 0.07) {
      return 'Factory New';
    }
    if (wearValue < 0.15) {
      return 'Minimal Wear';
    }
    if (wearValue < 0.38) {
      return 'Field-Tested';
    }
    if (wearValue < 0.45) {
      return 'Well-Worn';
    }
    return 'Battle-Scarred';
  }

  Color _sellRecordConditionColor(String label) {
    final normalized = label.toLowerCase();
    if (normalized.contains('factory new')) {
      return const Color(0xFF17A673);
    }
    if (normalized.contains('minimal wear')) {
      return const Color(0xFF8B5CF6);
    }
    if (normalized.contains('field-tested')) {
      return const Color(0xFF8BC34A);
    }
    if (normalized.contains('well-worn')) {
      return const Color(0xFFF59E0B);
    }
    if (normalized.contains('battle-scarred')) {
      return const Color(0xFFE11D48);
    }
    return const Color(0xFF00288E);
  }

  Widget _buildOnSaleActions() {
    final selectableIds = salesController.onSaleItems
        .where((item) => item.id != null)
        .map((item) => item.id!)
        .toSet();
    final selectableTotal = selectableIds.length;
    Future<void> openBatchPriceChange() async {
      final selectedItems = salesController.onSaleItems
          .where((item) => _selectedIds.contains(item.id ?? -1))
          .toList();
      if (selectedItems.isEmpty) {
        return;
      }
      final changed = await Get.toNamed(
        Routers.SHOP_PRICE_CHANGE,
        arguments: {
          'items': selectedItems,
          'schemas': salesController.schemas,
          'appId': _globalGameController.appId,
        },
      );
      if (changed == true) {
        await salesController.refreshOnSale();
        if (!mounted) {
          return;
        }
        setState(_selectedIds.clear);
      }
    }

    final selectedCount = _selectedIds.length;
    final isAllSelected =
        selectableTotal > 0 && selectedCount >= selectableTotal;

    return FloatingSelectionActionBar(
      isAllSelected: isAllSelected,
      selectAllLabel: 'app.market.filter.all'.tr,
      toggleTooltip: isAllSelected
          ? 'app.common.deselect_all'.tr
          : 'app.common.select_all'.tr,
      selectedCountText: '$selectedCount/$selectableTotal',
      onToggleSelectAll: () => _toggleSelectAllOnSale(selectableIds),
      actions: [
        SelectionActionBarButtonData(
          label: _compactPriceChangeLabel(),
          onTap: openBatchPriceChange,
          variant: SelectionActionBarButtonVariant.primary,
        ),
        SelectionActionBarButtonData(
          label: 'app.inventory.delist'.tr,
          onTap: _confirmDelist,
          variant: SelectionActionBarButtonVariant.destructive,
        ),
      ],
    );
  }

  String _compactPriceChangeLabel() {
    final locale = Get.locale ?? Get.deviceLocale ?? const Locale('en', 'US');
    final localeKey = '${locale.languageCode}_${locale.countryCode ?? ''}';

    switch (localeKey) {
      case 'en_US':
        return 'Change';
      case 'fr_FR':
        return 'Changer';
      case 'ge_DE':
        return 'Ändern';
      case 'in_ID':
        return 'Ubah';
      case 'it_IT':
        return 'Cambia';
      case 'ja_JP':
        return '変更';
      case 'ko_KR':
        return '변경';
      case 'la_LAT':
        return 'Cambiar';
      case 'po_PL':
        return 'Zmień';
      case 'po_PT':
        return 'Alterar';
      case 'ru_RU':
        return 'Изменить';
      case 'sp_ES':
        return 'Cambiar';
      case 'th_TH':
        return 'เปลี่ยน';
      case 'tu_TR':
        return 'Değiştir';
      case 'vi_VN':
        return 'Thay đổi';
      case 'zh_CN':
        return '改价';
      case 'zh_TW':
        return '改價';
      default:
        return 'app.inventory.price_change'.tr;
    }
  }

  Future<void> _openDeliverGoodsPage(ShopOrderItem order) async {
    await _openPendingShipmentDetail(order);
  }

  Future<void> _openPendingShipmentDetail(ShopOrderItem order) async {
    final delivered = await Get.toNamed(
      Routers.SHOP_PENDING_ORDER_DETAIL,
      arguments: {
        'order': order,
        'orders': _pendingOrdersForBuyer(order),
        'schemas': Map<String, ShopSchemaInfo>.from(orderController.schemas),
        'users': Map<String, ShopUserInfo>.from(orderController.users),
        'stickers': Map<String, dynamic>.from(salesController.stickers),
      },
    );
    if (delivered == true) {
      orderController.refreshPending();
      shippingNoticeController.refreshPendingTotals();
    }
  }

  List<ShopOrderItem> _pendingOrdersForBuyer(ShopOrderItem order) {
    final buyerId = (order.buyerId ?? order.user?.id ?? '').trim();
    if (buyerId.isEmpty) {
      return <ShopOrderItem>[order];
    }

    final related = orderController.pendingShipments
        .where(
          (item) => (item.buyerId ?? item.user?.id ?? '').trim() == buyerId,
        )
        .toList(growable: false);
    if (related.isEmpty) {
      return <ShopOrderItem>[order];
    }

    final ordered = <ShopOrderItem>[order];
    for (final item in related) {
      final sameOrder = order.id != null && item.id == order.id;
      if (!sameOrder) {
        ordered.add(item);
      }
    }
    return ordered;
  }

  Future<void> _openSellRecordDetail(ShopOrderItem record) async {
    await Get.toNamed(
      Routers.SHOP_ORDER_DETAIL,
      arguments: {
        'order': record,
        'schemas': Map<String, ShopSchemaInfo>.from(salesController.schemas),
        'users': Map<String, ShopUserInfo>.from(salesController.users),
        'stickers': Map<String, dynamic>.from(salesController.stickers),
      },
    );
  }
}

class _ShopOfflineDialog extends StatelessWidget {
  const _ShopOfflineDialog({
    required this.onCancel,
    required this.onOpenSettings,
  });

  final VoidCallback onCancel;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return FigmaConfirmationDialog(
      icon: Icons.settings_rounded,
      iconColor: const Color(0xFF1E40AF),
      iconBackgroundColor: const Color.fromRGBO(30, 64, 175, 0.10),
      title: 'app.user.shop.status'.tr,
      message: 'app.user.shop.message.offline'.tr,
      primaryLabel: 'app.user.shop.setting'.tr,
      onPrimary: onOpenSettings,
      secondaryLabel: 'app.common.cancel'.tr,
      onSecondary: onCancel,
    );
  }
}

class _PendingShipmentCountdown extends StatefulWidget {
  const _PendingShipmentCountdown({required this.endTimeMs, this.style});

  final int endTimeMs;
  final TextStyle? style;

  @override
  State<_PendingShipmentCountdown> createState() =>
      _PendingShipmentCountdownState();
}

class _PendingShipmentCountdownState extends State<_PendingShipmentCountdown> {
  Timer? _timer;
  String _text = '';

  @override
  void initState() {
    super.initState();
    _tick();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void didUpdateWidget(covariant _PendingShipmentCountdown oldWidget) {
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
    final formattedMinutes = minutes.toString().padLeft(2, '0');
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
        return '$remainingHours${'app.common.hours'.tr}$formattedMinutes${'app.common.minutes'.tr}';
      }
      final hourKey = remainingHours > 1
          ? 'app.common.hours'
          : 'app.common.hour';
      final minuteKey = minutes > 1
          ? 'app.common.minutes'
          : 'app.common.minute';
      return '$remainingHours${hourKey.tr}$formattedMinutes${minuteKey.tr}';
    }

    if (minutes > 0) {
      if (isCjkLocale) {
        return '$formattedMinutes${'app.common.minutes'.tr}';
      }
      final minuteKey = minutes > 1
          ? 'app.common.minutes'
          : 'app.common.minute';
      return '$formattedMinutes ${minuteKey.tr}';
    }

    return '';
  }

  @override
  Widget build(BuildContext context) {
    if (_remainText.isEmpty) {
      return const SizedBox.shrink();
    }
    return Text(_remainText, style: widget.style);
  }
}
