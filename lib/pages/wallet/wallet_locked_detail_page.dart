import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:tronskins_app/api/shop_product.dart';
import 'package:tronskins_app/api/steam.dart';
import 'package:tronskins_app/common/hooks/currency/CurrencyController.dart';
import 'package:tronskins_app/common/storage/game_storage.dart';
import 'package:tronskins_app/common/utils/app_snackbar.dart';
import 'package:tronskins_app/common/widgets/back_to_top_overlay.dart';
import 'package:tronskins_app/common/widgets/settings_style_app_bar.dart';
import 'package:tronskins_app/controllers/wallet/wallet_controller.dart';
import 'package:tronskins_app/api/model/wallet/wallet_models.dart';
import 'package:tronskins_app/components/game_item/game_item_image.dart';
import 'package:tronskins_app/components/game_item/game_item_models.dart';
import 'package:tronskins_app/components/game_item/sticker_row.dart';
import 'package:tronskins_app/components/game_item/wear_progress_bar.dart';
import 'package:tronskins_app/components/notify/notify_trade_deliver_sheet.dart';
import 'package:tronskins_app/routes/app_routes.dart';

class WalletLockedDetailPage extends StatefulWidget {
  const WalletLockedDetailPage({super.key});

  @override
  State<WalletLockedDetailPage> createState() => _WalletLockedDetailPageState();
}

class _WalletLockedDetailPageState extends State<WalletLockedDetailPage> {
  static const _pageBg = Color(0xFFF7F9FB);
  static const _cardBg = Colors.white;
  static const _titleColor = Color(0xFF191C1E);
  static const _mutedColor = Color(0xFF757684);
  static const _bodyColor = Color(0xFF444653);
  static const _skeletonColor = Color(0xFFE8EDF3);

  final WalletController controller = Get.isRegistered<WalletController>()
      ? Get.find<WalletController>()
      : Get.put(WalletController());
  final ApiShopProductServer _shopApi = ApiShopProductServer();
  final ApiSteamServer _steamApi = ApiSteamServer();

  Map<String, dynamic> args = const {};
  bool _loading = true;
  WalletLockedDetail? _detail;

  @override
  void initState() {
    super.initState();
    args = (Get.arguments as Map<String, dynamic>?) ?? {};
    controller.refreshUser();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    final id = args['id']?.toString();
    if (id == null) {
      setState(() => _loading = false);
      return;
    }
    final detail = await controller.loadLockedDetail(
      id: id,
      lockType: args['lockType'] as int?,
    );
    setState(() {
      _detail = detail;
      _loading = false;
    });
  }

  Future<void> _copy(String text) async {
    if (text.isEmpty) {
      return;
    }
    await Clipboard.setData(ClipboardData(text: text));
    AppSnackbar.success('app.system.message.copy_success'.tr);
  }

  void _showTopSnack(
    String message, {
    bool isError = false,
    bool isSuccess = false,
  }) {
    if (isSuccess) {
      AppSnackbar.success(message);
      return;
    }
    if (isError) {
      AppSnackbar.error(message);
      return;
    }
    AppSnackbar.info(message);
  }

  String _currentUserId() {
    return controller.userInfo.value?.id?.trim() ?? '';
  }

  bool _isBuyer(WalletLockedOrder? order) {
    if (order == null) {
      return false;
    }
    final userId = _currentUserId();
    final buyerId = order.buyerId?.trim() ?? '';
    if (userId.isEmpty || buyerId.isEmpty) {
      return false;
    }
    return userId == buyerId;
  }

  bool _isSeller(WalletLockedOrder? order) {
    if (order == null) {
      return false;
    }
    final userId = _currentUserId();
    final sellerId = order.sellerId?.trim() ?? '';
    if (userId.isEmpty || sellerId.isEmpty) {
      return false;
    }
    return userId == sellerId;
  }

  bool get _isChineseLocale {
    final languageCode = Get.locale?.languageCode.toLowerCase();
    return languageCode != null && languageCode.startsWith('zh');
  }

  String _text({required String zh, required String en}) {
    return _isChineseLocale ? zh : en;
  }

  String _formatTimestamp(int? timestamp) {
    if (timestamp == null || timestamp <= 0) {
      return '-';
    }
    return DateFormat(
      'yyyy-MM-dd HH:mm',
    ).format(DateTime.fromMillisecondsSinceEpoch(timestamp * 1000).toLocal());
  }

  String _formatAmount(CurrencyController currency, double value) {
    return currency.formatUsd(value);
  }

  int? _resolvedStatus(WalletLockedOrder? order) {
    return order?.status ??
        _asInt(_pickRawValue(_detail?.raw, const ['status']));
  }

  int? _resolvedLockTime(WalletLockedOrder? order) {
    return _asInt(args['lockTime']) ??
        _asInt(
          _pickRawValue(_detail?.raw, const [
            'lockTime',
            'lock_time',
            'lockAmount',
            'lock_amount',
          ]),
        ) ??
        _resolvedCreatedTime(order);
  }

  int? _resolvedCreatedTime(WalletLockedOrder? order) {
    return order?.createTime ??
        _asInt(
          _pickRawValue(order?.raw, const [
            'create_time',
            'createTime',
            'created_at',
            'createdAt',
          ]),
        ) ??
        _asInt(
          _pickRawValue(_detail?.raw, const [
            'create_time',
            'createTime',
            'created_at',
            'createdAt',
            'time',
          ]),
        );
  }

  String _statusHeadline(WalletLockedOrder? order) {
    final status = _resolvedStatus(order);
    final cancelDesc =
        _pickRawText(order?.raw, const ['cancelDesc', 'cancel_desc']) ??
        _pickRawText(_detail?.raw, const ['cancelDesc', 'cancel_desc']);
    final statusName =
        _pickRawText(order?.raw, const ['statusName', 'status_name']) ??
        _pickRawText(_detail?.raw, const ['statusName', 'status_name']);
    if (status == -1 || status == -2) {
      if (cancelDesc != null && cancelDesc.isNotEmpty) {
        return cancelDesc;
      }
      if (statusName != null && statusName.isNotEmpty) {
        return statusName;
      }
      return _text(zh: '订单已关闭', en: 'Order Closed');
    }
    if (status == 6) {
      return _text(zh: '交易已完成', en: 'Transaction Completed');
    }
    if (status == 5) {
      return _text(zh: '结算中', en: 'Settlement In Progress');
    }
    if (status == 4 && _isBuyer(order)) {
      return _text(zh: '待确认收货', en: 'Ready to Receive');
    }
    if (status == 2 && _isSeller(order)) {
      return _text(zh: '准备发货', en: 'Ready to Deliver');
    }
    if ([2, 3, 4].contains(status)) {
      return _text(zh: '订单处理中', en: 'Order In Progress');
    }
    if (statusName != null && statusName.isNotEmpty) {
      return statusName;
    }
    final typeName = _resolvedTypeName(order);
    if (typeName.isNotEmpty && typeName != '-') {
      return typeName;
    }
    return _text(zh: '锁定详情', en: 'Lock Details');
  }

  String _resolvedTypeName(WalletLockedOrder? order) {
    final rawTypeName =
        args['typeName']?.toString().trim() ??
        _pickRawText(_detail?.raw, const ['typeName', 'type_name']) ??
        _pickRawText(order?.raw, const ['typeName', 'type_name']);
    if (rawTypeName != null && rawTypeName.isNotEmpty) {
      return rawTypeName;
    }
    final lockType = _resolvedLockType(order);
    if (lockType == 1) {
      return _text(zh: '购买', en: 'Buying');
    }
    if (lockType == 3) {
      return _text(zh: '提现', en: 'Withdraw');
    }
    return '-';
  }

  int? _resolvedLockType(WalletLockedOrder? order) {
    return _asInt(args['lockType']) ??
        _asInt(_pickRawValue(_detail?.raw, const ['lockType', 'lock_type'])) ??
        _asInt(_pickRawValue(order?.raw, const ['lockType', 'lock_type']));
  }

  String _resolvedOrderId(WalletLockedOrder? order) {
    return order?.id?.toString() ??
        args['srcId']?.toString() ??
        _pickRawText(_detail?.raw, const ['srcId', 'src_id', 'orderId']) ??
        '-';
  }

  double _resolvedLockedAmountValue() {
    return _asDouble(args['lockedAmount']) ??
        _asDouble(args['lockAmount']) ??
        _asDouble(
          _pickRawValue(_detail?.raw, const [
            'amount',
            'lock_amount',
            'lockedAmount',
          ]),
        ) ??
        0;
  }

  double _resolvedGiftAmountValue() {
    return _asDouble(args['giftAmount']) ??
        _asDouble(
          _pickRawValue(_detail?.raw, const [
            'gift_amount',
            'giftAmount',
            'lockedGift',
          ]),
        ) ??
        0;
  }

  double? _resolvedOrderPrice(WalletLockedOrder? order) {
    return order?.price ??
        _asDouble(
          _pickRawValue(_detail?.raw, const [
            'price',
            'total_price',
            'totalPrice',
          ]),
        );
  }

  List<Color> _statusGradient(WalletLockedOrder? order) {
    final status = _resolvedStatus(order);
    if (status == -1 || status == -2) {
      return const [Color(0xFFEF4444), Color(0xFFDC2626)];
    }
    if (status == 6) {
      return const [Color(0xFF10B981), Color(0xFF059669)];
    }
    if (status == 5) {
      return const [Color(0xFF0EA5E9), Color(0xFF2563EB)];
    }
    if (status == 4 && _isBuyer(order)) {
      return const [Color(0xFF0F766E), Color(0xFF14B8A6)];
    }
    if (status == 2 && _isSeller(order)) {
      return const [Color(0xFFF59E0B), Color(0xFFD97706)];
    }
    if ([2, 3, 4].contains(status)) {
      return const [Color(0xFF1D4ED8), Color(0xFF3B82F6)];
    }
    final lockType = _resolvedLockType(order);
    final typeName = _resolvedTypeName(order).toLowerCase();
    if (lockType == 3 || typeName.contains('withdraw') || typeName == '提现') {
      return const [Color(0xFFF59E0B), Color(0xFFEA580C)];
    }
    if (lockType == 1 ||
        typeName.contains('buy') ||
        typeName.contains('purchase') ||
        typeName == '购买') {
      return const [Color(0xFF2563EB), Color(0xFF1D4ED8)];
    }
    return const [Color(0xFF475569), Color(0xFF334155)];
  }

  IconData _statusIcon(WalletLockedOrder? order) {
    final status = _resolvedStatus(order);
    if (status == -1 || status == -2) {
      return Icons.cancel_outlined;
    }
    if (status == 6) {
      return Icons.check_rounded;
    }
    if (status == 5) {
      return Icons.account_balance_wallet_outlined;
    }
    if (status == 4 && _isBuyer(order)) {
      return Icons.inventory_2_outlined;
    }
    if (status == 2 && _isSeller(order)) {
      return Icons.local_shipping_outlined;
    }
    if ([2, 3, 4].contains(status)) {
      return Icons.schedule_rounded;
    }
    final lockType = _resolvedLockType(order);
    final typeName = _resolvedTypeName(order).toLowerCase();
    if (lockType == 3 || typeName.contains('withdraw') || typeName == '提现') {
      return Icons.account_balance_wallet_outlined;
    }
    if (lockType == 1 ||
        typeName.contains('buy') ||
        typeName.contains('purchase') ||
        typeName == '购买') {
      return Icons.shopping_bag_outlined;
    }
    return Icons.info_outline_rounded;
  }

  String _gameName(int appId) {
    switch (appId) {
      case 730:
        return 'CS2';
      case 570:
        return 'Dota 2';
      case 440:
        return 'TF2';
      default:
        return 'Steam';
    }
  }

  String? _schemaPaintWearText(
    WalletSchemaInfo? schema,
    WalletLockedOrder? order,
  ) {
    final value =
        _pickRawValue(schema?.raw, const ['paint_wear', 'paintWear']) ??
        _pickRawValue(order?.raw, const ['paint_wear', 'paintWear']) ??
        _pickRawValue(_pickRawMap(order?.raw['asset']), const [
          'paint_wear',
          'paintWear',
        ]) ??
        _pickRawValue(_pickRawMap(order?.raw['csgoAsset']), const [
          'paint_wear',
          'paintWear',
        ]);
    if (value != null) {
      return value.toString();
    }
    return schema?.paintWear?.toString();
  }

  double? _schemaPaintWearValue(
    WalletSchemaInfo? schema,
    WalletLockedOrder? order,
  ) {
    return _asDouble(
          _pickRawValue(schema?.raw, const ['paint_wear', 'paintWear']),
        ) ??
        _asDouble(
          _pickRawValue(order?.raw, const ['paint_wear', 'paintWear']),
        ) ??
        _asDouble(
          _pickRawValue(_pickRawMap(order?.raw['asset']), const [
            'paint_wear',
            'paintWear',
          ]),
        ) ??
        _asDouble(
          _pickRawValue(_pickRawMap(order?.raw['csgoAsset']), const [
            'paint_wear',
            'paintWear',
          ]),
        ) ??
        schema?.paintWear;
  }

  TagInfo? _schemaTag(WalletSchemaInfo? schema, String key) {
    final tags = schema?.raw['tags'];
    if (tags is Map) {
      return TagInfo.fromRaw(tags[key]);
    }
    return null;
  }

  int _resolveAppId(WalletSchemaInfo? schema, WalletLockedOrder? order) {
    final rawAsset = _pickRawMap(order?.raw['asset']);
    final rawCsgoAsset = _pickRawMap(order?.raw['csgoAsset']);
    return schema?.appId ??
        order?.appId ??
        _asInt(_pickRawValue(schema?.raw, const ['app_id', 'appId'])) ??
        _asInt(_pickRawValue(order?.raw, const ['app_id', 'appId'])) ??
        _asInt(_pickRawValue(rawAsset, const ['app_id', 'appId'])) ??
        _asInt(_pickRawValue(rawCsgoAsset, const ['app_id', 'appId'])) ??
        GameStorage.getGameType();
  }

  String _resolveImageUrl(WalletSchemaInfo? schema, WalletLockedOrder? order) {
    final rawAsset = _pickRawMap(order?.raw['asset']);
    final rawCsgoAsset = _pickRawMap(order?.raw['csgoAsset']);
    return schema?.imageUrl ??
        _pickRawText(schema?.raw, const [
          'image_url',
          'imageUrl',
          'icon_url',
          'iconUrl',
          'image',
        ]) ??
        _pickRawText(order?.raw, const [
          'image_url',
          'imageUrl',
          'icon_url',
          'iconUrl',
          'image',
        ]) ??
        _pickRawText(rawAsset, const [
          'image_url',
          'imageUrl',
          'icon_url',
          'iconUrl',
          'image',
        ]) ??
        _pickRawText(rawCsgoAsset, const [
          'image_url',
          'imageUrl',
          'icon_url',
          'iconUrl',
          'image',
        ]) ??
        '';
  }

  List<GameItemSticker> _schemaStickers(
    WalletSchemaInfo? schema,
    WalletLockedOrder? order,
  ) {
    final rawAsset = _pickRawMap(order?.raw['asset']);
    final rawCsgoAsset = _pickRawMap(order?.raw['csgoAsset']);
    final stickerRaw =
        _pickRawValue(schema?.raw, const ['stickers']) ??
        _pickRawValue(order?.raw, const ['stickers']) ??
        _pickRawValue(rawAsset, const ['stickers']) ??
        _pickRawValue(rawCsgoAsset, const ['stickers']);
    return parseStickerList(stickerRaw, stickerMap: _detail?.stickers);
  }

  Map? _pickRawMap(dynamic value) {
    if (value is Map) {
      return value;
    }
    return null;
  }

  dynamic _pickRawValue(dynamic source, List<String> keys) {
    if (source is! Map) {
      return null;
    }
    for (final key in keys) {
      final value = source[key];
      if (value != null) {
        return value;
      }
    }
    return null;
  }

  String? _pickRawText(dynamic source, List<String> keys) {
    final value = _pickRawValue(source, keys);
    if (value == null) {
      return null;
    }
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
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

  Future<void> _openDeliverDrawer(WalletLockedOrder order) async {
    final buyerId = order.buyerId?.trim() ?? '';
    if (buyerId.isEmpty) {
      _showTopSnack('app.trade.filter.failed'.tr, isError: true);
      return;
    }
    await showNotifyTradeDeliverSheet(
      context,
      buyerId: buyerId,
      status: order.status,
      onDelivered: () {
        _loadDetail();
      },
    );
  }

  Future<void> _receiveGoods(WalletLockedOrder order) async {
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

    final orderId = order.id?.toString() ?? '';
    if (orderId.isEmpty) {
      _showTopSnack('app.trade.filter.failed'.tr, isError: true);
      return;
    }

    try {
      final steamStatus = await _steamApi.steamOnlineState();
      if (steamStatus.datas != true) {
        final tradeOfferId = order.tradeOfferId ?? '';
        if (tradeOfferId.isNotEmpty) {
          Get.toNamed(
            Routers.RECEIVE_GOODS,
            arguments: {'tradeOfferId': tradeOfferId},
          );
        } else {
          _showTopSnack('app.trade.filter.failed'.tr, isError: true);
        }
        return;
      }

      final response = await _shopApi.tradeofferReceipt(id: orderId);
      if (response.success) {
        _showTopSnack(
          response.message.isNotEmpty
              ? response.message
              : 'app.system.message.success'.tr,
          isSuccess: true,
        );
        await _loadDetail();
        if (mounted) {
          Future.delayed(const Duration(milliseconds: 900), () {
            if (mounted) {
              Get.back();
            }
          });
        }
      } else {
        _showTopSnack(
          response.message.isNotEmpty
              ? response.message
              : 'app.trade.filter.failed'.tr,
          isError: true,
        );
      }
    } catch (_) {
      _showTopSnack('app.trade.filter.failed'.tr, isError: true);
    }
  }

  Future<void> _cancelOrder(WalletLockedOrder order) async {
    final orderId = order.id?.toString() ?? '';
    if (orderId.isEmpty) {
      _showTopSnack('app.trade.filter.failed'.tr, isError: true);
      return;
    }

    final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final changeTime = order.changeTime ?? order.createTime ?? 0;
    final isCancelTimeLess =
        changeTime > 0 && (nowSeconds - changeTime).abs() <= 1800;

    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: Text('app.trade.order.cancel'.tr),
        content: Text(
          isCancelTimeLess
              ? 'app.trade.order.message.cancel_time_less'.tr
              : 'app.trade.order.message.confirm_cancel'.tr,
        ),
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
      final response = await _shopApi.cancelOrder(id: orderId);
      if (response.success) {
        _showTopSnack('app.system.message.success'.tr, isSuccess: true);
        await _loadDetail();
        if (mounted) {
          Get.back();
        }
        return;
      }
      _showTopSnack(
        response.message.isNotEmpty
            ? response.message
            : 'app.trade.filter.failed'.tr,
        isError: true,
      );
    } catch (_) {
      _showTopSnack('app.trade.filter.failed'.tr, isError: true);
    }
  }

  _LockedDetailPrimaryAction? _resolvePrimaryAction(WalletLockedOrder? order) {
    if (order == null) {
      return null;
    }

    final status = order.status ?? -999;
    if (_isSeller(order) && status == 2) {
      return _LockedDetailPrimaryAction(
        label: 'app.market.product.deliver'.tr,
        icon: Icons.local_shipping_outlined,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
        ),
        onTap: () => _openDeliverDrawer(order),
      );
    }
    if (_isBuyer(order) && status == 4) {
      return _LockedDetailPrimaryAction(
        label: 'app.market.product.receive'.tr,
        icon: Icons.inventory_2_outlined,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F766E), Color(0xFF14B8A6)],
        ),
        onTap: () => _receiveGoods(order),
      );
    }
    if (_isBuyer(order) && status == 2) {
      return _LockedDetailPrimaryAction(
        label: 'app.trade.order.cancel'.tr,
        icon: Icons.cancel_outlined,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE11D48), Color(0xFFFB7185)],
        ),
        onTap: () => _cancelOrder(order),
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final currency = Get.find<CurrencyController>();
    final topInset = MediaQuery.of(context).padding.top;
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final primaryAction = _resolvePrimaryAction(_detail?.order);
    final bottomPadding = bottomInset + 120;

    return BackToTopScope(
      enabled: false,
      child: Scaffold(
        backgroundColor: _pageBg,
        body: Stack(
          children: [
            Positioned.fill(
              child: _loading
                  ? _buildLoadingSkeleton(
                      topInset: topInset,
                      bottomPadding: bottomPadding,
                    )
                  : _detail == null
                  ? _buildCenteredState(
                      topInset: topInset,
                      child: Text(
                        'app.common.no_data'.tr,
                        style: const TextStyle(
                          color: _mutedColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    )
                  : SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(
                        16,
                        topInset + 80,
                        16,
                        bottomPadding,
                      ),
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 672),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildStatusCard(currency),
                              const SizedBox(height: 16),
                              _buildProductCard(currency),
                            ],
                          ),
                        ),
                      ),
                    ),
            ),
            _buildTopNavigation(context),
            _buildBottomActionBar(bottomInset, primaryAction),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingSkeleton({
    required double topInset,
    required double bottomPadding,
  }) {
    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(16, topInset + 80, 16, bottomPadding),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 672),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStatusSkeletonCard(),
              const SizedBox(height: 16),
              _buildProductSkeletonCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCenteredState({
    required double topInset,
    required Widget child,
  }) {
    return Padding(
      padding: EdgeInsets.only(top: topInset + 96),
      child: Center(child: child),
    );
  }

  Widget _buildTopNavigation(BuildContext context) {
    return SettingsStyleTopNavigation(
      title: 'app.trade.order.details'.tr,
      horizontalPadding: 16,
      onBack: () => Navigator.of(context).maybePop(),
    );
  }

  Widget _buildStatusCard(CurrencyController currency) {
    final order = _detail?.order;
    final orderId = _resolvedOrderId(order);
    final lockTime = _formatTimestamp(_resolvedLockTime(order));
    final typeName = _resolvedTypeName(order);
    final lockedAmount = _formatAmount(currency, _resolvedLockedAmountValue());
    final lockedGift = _formatAmount(currency, _resolvedGiftAmountValue());
    final headline = _statusHeadline(order);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _statusGradient(order),
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.10),
            blurRadius: 15,
            offset: Offset(0, 10),
          ),
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.10),
            blurRadius: 6,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 41,
                height: 41,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20.5),
                ),
                child: Icon(_statusIcon(order), color: Colors.white, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: SizedBox(
                  height: 32,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        headline,
                        softWrap: false,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          height: 32 / 24,
                          letterSpacing: -0.6,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildGlassStatusRow(
            label: '${_text(zh: '订单号', en: 'Order No')}:',
            value: orderId,
            onCopy: orderId == '-' ? null : () => _copy(orderId),
          ),
          const SizedBox(height: 8),
          _buildGlassStatusRow(
            label: '${_text(zh: '锁定时间', en: 'Lock Time')}:',
            value: lockTime,
          ),
          const SizedBox(height: 8),
          _buildGlassStatusRow(
            label: '${_text(zh: '类型', en: 'Type')}:',
            value: typeName,
          ),
          const SizedBox(height: 8),
          _buildGlassStatusRow(
            label: '${_text(zh: '锁定金额', en: 'Locked Amount')}:',
            value: lockedAmount,
          ),
          const SizedBox(height: 8),
          _buildGlassStatusRow(
            label: '${_text(zh: '锁定礼品卡', en: 'Locked Gift')}:',
            value: lockedGift,
          ),
          const SizedBox(height: 18),
          _buildGlassButton(
            label: _text(zh: '联系客服', en: 'Contact Customer Service'),
            onTap: () => Get.toNamed(Routers.FEEDBACK_LIST),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(CurrencyController currency) {
    final schema = _detail?.schema;
    final order = _detail?.order;
    final name = schema?.marketName ?? schema?.marketHashName ?? '-';
    final subtitle = schema?.marketHashName;
    final orderPrice = _resolvedOrderPrice(order);
    final sellMin = schema?.sellMin;
    final buyMax = schema?.buyMax;
    final paintWearText = _schemaPaintWearText(schema, order);
    final paintWear = _schemaPaintWearValue(schema, order);
    final stickers = _schemaStickers(schema, order);
    final appId = _resolveAppId(schema, order);
    final imageUrl = _resolveImageUrl(schema, order);
    final rarity = _schemaTag(schema, 'rarity');
    final quality = _schemaTag(schema, 'quality');
    final exterior = _schemaTag(schema, 'exterior');
    final phase = _pickRawText(schema?.raw, const ['phase']);
    final percentage = _pickRawText(schema?.raw, const ['percentage']);
    final primaryQualityLabel = quality?.label ?? rarity?.label;

    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(_text(zh: '商品信息', en: 'Product Info')),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 96,
                  height: 96,
                  child: GameItemImage(
                    imageUrl: imageUrl,
                    appId: appId,
                    rarity: rarity,
                    quality: quality,
                    exterior: exterior,
                    phase: phase,
                    percentage: percentage,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _titleColor,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        height: 28 / 20,
                      ),
                    ),
                    if (subtitle != null &&
                        subtitle.isNotEmpty &&
                        subtitle != name) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _mutedColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          height: 18 / 12,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildInfoChip(
                          label: _gameName(appId),
                          background: const Color(0xFFF1F5F9),
                          foreground: const Color(0xFF475569),
                        ),
                        if (primaryQualityLabel != null &&
                            primaryQualityLabel.isNotEmpty)
                          _buildInfoChip(
                            label: primaryQualityLabel,
                            background: const Color(0xFFFEF2F2),
                            foreground: const Color(0xFFDC2626),
                          ),
                        if (exterior?.label != null &&
                            exterior!.label!.isNotEmpty)
                          _buildInfoChip(
                            label: exterior.label!,
                            background: const Color(0xFFEEF6FF),
                            foreground: const Color(0xFF2563EB),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (orderPrice != null || sellMin != null || buyMax != null) ...[
            const SizedBox(height: 18),
            if (orderPrice != null)
              _buildDetailValueRow(
                label: _text(zh: '订单金额', en: 'Total Price'),
                value: _formatAmount(currency, orderPrice),
              ),
            if (orderPrice != null && (sellMin != null || buyMax != null))
              const SizedBox(height: 8),
            if (sellMin != null)
              _buildDetailValueRow(
                label: 'app.market.detail.sale_lowest'.tr,
                value: _formatAmount(currency, sellMin),
              ),
            if (sellMin != null && buyMax != null) const SizedBox(height: 8),
            if (buyMax != null)
              _buildDetailValueRow(
                label: 'app.market.detail.purchase_highest'.tr,
                value: _formatAmount(currency, buyMax),
              ),
          ],
          if (paintWearText != null && paintWearText.isNotEmpty) ...[
            const SizedBox(height: 22),
            _buildWearValueRow(
              label: _text(zh: '磨损度', en: 'Wear'),
              value: paintWearText,
            ),
          ],
          if (paintWear != null && paintWear > 0) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: WearProgressBar(
                paintWear: paintWear,
                height: 18,
                style: WearProgressBarStyle.figmaCompact,
              ),
            ),
          ],
          if (stickers.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              _text(zh: '印花信息', en: 'Sticker Info'),
              style: const TextStyle(
                color: _mutedColor,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                height: 18 / 12,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 10),
            StickerRow(stickers: stickers, size: 28),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomActionBar(
    double bottomInset,
    _LockedDetailPrimaryAction? action,
  ) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: EdgeInsets.fromLTRB(16, 12, 16, bottomInset + 16),
            decoration: const BoxDecoration(
              color: Color.fromRGBO(255, 255, 255, 0.80),
              boxShadow: [
                BoxShadow(
                  color: Color.fromRGBO(0, 0, 0, 0.05),
                  blurRadius: 20,
                  offset: Offset(0, -4),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildBottomButton(
                    icon: Icons.help_outline_rounded,
                    label: _text(zh: '帮助中心', en: 'Help Center'),
                    background: const Color(0xFFF1F5F9),
                    foreground: const Color(0xFF475569),
                    onTap: () => Get.toNamed(Routers.HELP_CENTER),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildBottomButton(
                    icon: action?.icon ?? Icons.support_agent_rounded,
                    label: action?.label ?? _text(zh: '联系客服', en: 'Contact'),
                    foreground: Colors.white,
                    gradient:
                        action?.gradient ??
                        const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF1D4ED8), Color(0xFF3B82F6)],
                        ),
                    onTap:
                        action?.onTap ??
                        () => Get.toNamed(Routers.FEEDBACK_LIST),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomButton({
    required IconData icon,
    required String label,
    required Color foreground,
    required VoidCallback onTap,
    Color? background,
    Gradient? gradient,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: background,
          gradient: gradient,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: foreground),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: foreground,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 16 / 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusSkeletonCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFEFF4FA), Color(0xFFE2E8F0)],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildSkeletonBox(width: 48, height: 48, radius: 24),
              const SizedBox(width: 16),
              Expanded(child: _buildSkeletonBox(height: 26, radius: 8)),
            ],
          ),
          const SizedBox(height: 26),
          _buildSkeletonInfoRow(),
          const SizedBox(height: 12),
          _buildSkeletonInfoRow(shortValue: true),
          const SizedBox(height: 12),
          _buildSkeletonInfoRow(shortValue: true),
          const SizedBox(height: 12),
          _buildSkeletonInfoRow(),
          const SizedBox(height: 12),
          _buildSkeletonInfoRow(),
          const SizedBox(height: 18),
          _buildSkeletonBox(height: 36, radius: 8),
        ],
      ),
    );
  }

  Widget _buildProductSkeletonCard() {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSkeletonBox(width: 108, height: 18, radius: 8),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSkeletonBox(width: 116, height: 116, radius: 10),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSkeletonBox(height: 22, radius: 8),
                    const SizedBox(height: 10),
                    _buildSkeletonBox(width: 150, height: 18, radius: 8),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _buildSkeletonBox(width: 48, height: 30, radius: 999),
                        const SizedBox(width: 10),
                        _buildSkeletonBox(width: 56, height: 30, radius: 999),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSkeletonInfoRow(),
          const SizedBox(height: 12),
          _buildSkeletonInfoRow(),
          const SizedBox(height: 18),
          _buildSkeletonInfoRow(shortValue: true),
          const SizedBox(height: 8),
          _buildSkeletonBox(height: 6, radius: 999),
        ],
      ),
    );
  }

  Widget _buildSkeletonInfoRow({bool shortValue = false}) {
    return Row(
      children: [
        _buildSkeletonBox(width: 96, height: 14, radius: 7),
        const SizedBox(width: 24),
        Expanded(child: Container()),
        _buildSkeletonBox(width: shortValue ? 88 : 128, height: 16, radius: 8),
      ],
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }

  Widget _buildSkeletonBox({
    double? width,
    required double height,
    double radius = 999,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: _skeletonColor,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: _mutedColor,
        fontSize: 14,
        fontWeight: FontWeight.w700,
        height: 20 / 14,
      ),
    );
  }

  Widget _buildInfoChip({
    required String label,
    required Color background,
    required Color foreground,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          height: 1.25,
        ),
      ),
    );
  }

  Widget _buildGlassButton({
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            height: 20 / 14,
          ),
        ),
      ),
    );
  }

  Widget _buildDetailValueRow({required String label, required String value}) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: _bodyColor,
              fontSize: 14,
              fontWeight: FontWeight.w400,
              height: 20 / 14,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          value,
          textAlign: TextAlign.right,
          style: const TextStyle(
            color: _titleColor,
            fontSize: 15,
            fontWeight: FontWeight.w700,
            height: 20 / 15,
          ),
        ),
      ],
    );
  }

  Widget _buildWearValueRow({required String label, required String value}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: _mutedColor,
            fontSize: 12,
            fontWeight: FontWeight.w500,
            height: 18 / 12,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: _bodyColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 18 / 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGlassStatusRow({
    required String label,
    required String value,
    VoidCallback? onCopy,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 116,
          child: Text(
            label,
            style: const TextStyle(
              color: Color.fromRGBO(255, 255, 255, 0.90),
              fontSize: 14,
              fontWeight: FontWeight.w400,
              height: 20 / 14,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 20,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        value,
                        softWrap: false,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          color: Color.fromRGBO(255, 255, 255, 0.90),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          height: 20 / 14,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (onCopy != null) ...[
                const SizedBox(width: 6),
                InkWell(
                  onTap: onCopy,
                  child: const Icon(
                    Icons.content_copy_rounded,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _LockedDetailPrimaryAction {
  const _LockedDetailPrimaryAction({
    required this.label,
    required this.icon,
    required this.gradient,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Gradient gradient;
  final VoidCallback onTap;
}
