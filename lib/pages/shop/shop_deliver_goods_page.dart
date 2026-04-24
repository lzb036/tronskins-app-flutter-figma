import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:tronskins_app/api/model/shop/shop_models.dart';
import 'package:tronskins_app/api/shop_product.dart';
import 'package:tronskins_app/api/steam.dart';
import 'package:tronskins_app/api/tradeoffer.dart';
import 'package:tronskins_app/common/hooks/currency/CurrencyController.dart';
import 'package:tronskins_app/common/storage/game_storage.dart';
import 'package:tronskins_app/common/utils/app_snackbar.dart';
import 'package:tronskins_app/common/widgets/settings_style_app_bar.dart';
import 'package:tronskins_app/components/game_item/game_item_image.dart';
import 'package:tronskins_app/components/game_item/game_item_models.dart';
import 'package:tronskins_app/components/game_item/wear_progress_bar.dart';
import 'package:tronskins_app/controllers/user/user_controller.dart';
import 'package:tronskins_app/routes/app_routes.dart';

class ShopDeliverGoodsPage extends StatefulWidget {
  const ShopDeliverGoodsPage({super.key});

  @override
  State<ShopDeliverGoodsPage> createState() => _ShopDeliverGoodsPageState();
}

class _ShopDeliverGoodsPageState extends State<ShopDeliverGoodsPage> {
  static const _pageBg = Color(0xFFF7F9FB);
  static const _cardBg = Colors.white;
  static const _titleColor = Color(0xFF191C1E);
  static const _mutedColor = Color(0xFF757684);
  static const _lineColor = Color(0xFFECEEF0);
  static const _brandColor = Color(0xFF00288E);

  final _args = _ShopDeliverGoodsArgs.fromDynamic(Get.arguments);
  final ApiShopProductServer _api = ApiShopProductServer();
  final ApiSteamServer _steamApi = ApiSteamServer();
  final ApiTradeOfferServer _tradeApi = ApiTradeOfferServer();

  final Map<String, ShopSchemaInfo> _schemas = <String, ShopSchemaInfo>{};
  final Map<String, ShopUserInfo> _users = <String, ShopUserInfo>{};
  final Map<String, dynamic> _stickers = <String, dynamic>{};
  List<ShopOrderItem> _orders = <ShopOrderItem>[];

  bool _loading = true;
  bool _submitting = false;
  bool _refreshingBuyer = false;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  bool get _isEnglishLocale =>
      (Get.locale?.languageCode ?? '').toLowerCase() == 'en';

  int? get _resolvedStatus =>
      _args.status ?? (_orders.isNotEmpty ? _orders.first.status : null);

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final currency = Get.isRegistered<CurrencyController>()
        ? Get.find<CurrencyController>()
        : null;

    return Scaffold(
      backgroundColor: _pageBg,
      body: Stack(
        children: [
          Positioned.fill(
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                16,
                topInset + 80,
                16,
                bottomInset + 132,
              ),
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 672),
                  child: _loading
                      ? _buildLoadingSkeleton()
                      : _orders.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.only(top: 96),
                          child: Center(
                            child: Text(
                              'app.common.no_data'.tr,
                              style: const TextStyle(
                                color: _mutedColor,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildBuyerCard(currency),
                            const SizedBox(height: 18),
                            _buildSteamBuyerCard(),
                            const SizedBox(height: 20),
                            _buildOrdersCard(currency),
                          ],
                        ),
                ),
              ),
            ),
          ),
          SettingsStyleTopNavigation(
            title: _isEnglishLocale ? 'Delivery Goods' : '发货详情',
          ),
          if (!_loading && _orders.isNotEmpty)
            _buildBottomActionBar(bottomInset, _resolvedStatus),
        ],
      ),
    );
  }

  Future<void> _loadOrders() async {
    if (_args.buyerId.isEmpty) {
      if (mounted) {
        setState(() => _loading = false);
      }
      return;
    }

    if (mounted) {
      setState(() => _loading = true);
    }
    try {
      final params = <String, dynamic>{
        'appId': GameStorage.getGameType(),
        'buyer': _args.buyerId,
        'page': 1,
        'pageSize': 50,
        'statusList': _args.status != null ? [_args.status] : [2, 3],
        'isload': true,
      };
      final res = await _api.pendingShipmentList(params: params);
      if (res.success && res.datas != null) {
        final data = res.datas!;
        _orders = data.items;
        _schemas
          ..clear()
          ..addAll(data.schemas);
        _users
          ..clear()
          ..addAll(data.users);
        _stickers
          ..clear()
          ..addAll(data.stickers);
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _refreshBuyer() async {
    if (_refreshingBuyer || _args.buyerId.isEmpty) {
      return;
    }
    setState(() => _refreshingBuyer = true);
    try {
      final res = await _steamApi.getSteamUserInfo(id: _args.buyerId);
      if (res.success && res.datas != null) {
        final data = res.datas!;
        final current = _users[_args.buyerId];
        _users[_args.buyerId] = ShopUserInfo(
          id: current?.id ?? _args.buyerId,
          uuid: current?.uuid,
          avatar: data['avatar']?.toString() ?? current?.avatar,
          nickname: data['nickname']?.toString() ?? current?.nickname,
          level: _asInt(data['level']) ?? current?.level,
          yearsLevel: _asInt(data['yearsLevel']) ?? current?.yearsLevel,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _refreshingBuyer = false);
      }
    }
  }

  Future<void> _submit() async {
    if (_submitting) {
      return;
    }
    if (_orders.isEmpty || _orders.first.id == null) {
      AppSnackbar.error('app.trade.filter.failed'.tr);
      return;
    }

    setState(() => _submitting = true);
    try {
      final steamStatus = await _steamApi.steamOnlineState();
      if (steamStatus.datas != true) {
        await Get.dialog<void>(
          AlertDialog(
            title: Text('app.system.tips.title'.tr),
            content: Text('app.steam.session.expired'.tr),
            actions: [
              TextButton(
                onPressed: () => Get.back(),
                child: Text('app.common.cancel'.tr),
              ),
              TextButton(
                onPressed: () {
                  Get.back();
                  Get.toNamed(Routers.STEAM_SESSION);
                },
                child: Text('app.common.confirm'.tr),
              ),
            ],
          ),
        );
        return;
      }

      final res = await _tradeApi.createTradeOffer(
        params: {'id': _orders.first.id},
      );
      if (res.success) {
        AppSnackbar.success(
          'app.trade.deliver.message.steam_trade_url_success'.tr,
        );
        if (!mounted) {
          return;
        }
        Navigator.of(context).pop(true);
        return;
      }

      final datas = res.datas?.toString() ?? '';
      if (datas.contains('Steam issue')) {
        await Get.dialog<void>(
          AlertDialog(
            title: Text('app.system.tips.title'.tr),
            content: Text('app.steam.message.trading_restrictions'.tr),
            actions: [
              TextButton(
                onPressed: () => Get.back(),
                child: Text('app.common.confirm'.tr),
              ),
            ],
          ),
        );
        return;
      }

      if (datas.contains('Inventory privacy')) {
        final nickname = Get.isRegistered<UserController>()
            ? Get.find<UserController>().nickname
            : '';
        await Get.dialog<void>(
          AlertDialog(
            title: Text('app.system.tips.title'.tr),
            content: Text('app.inventory.message.privacy'.tr + nickname),
            actions: [
              TextButton(
                onPressed: () => Get.back(),
                child: Text('app.common.confirm'.tr),
              ),
            ],
          ),
        );
        return;
      }

      AppSnackbar.error(
        res.message.isNotEmpty ? res.message : 'app.trade.filter.failed'.tr,
      );
    } catch (_) {
      AppSnackbar.error('app.trade.filter.failed'.tr);
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Widget _buildLoadingSkeleton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSkeletonNoticeCard(),
        const SizedBox(height: 18),
        _buildSkeletonSteamCard(),
        const SizedBox(height: 20),
        Row(
          children: [
            const _DeliverSkeletonBox(width: 146, height: 20, radius: 4),
            const Spacer(),
            const _DeliverSkeletonBox(width: 82, height: 12, radius: 4),
          ],
        ),
        const SizedBox(height: 12),
        const _DeliverSkeletonOrderCard(),
        const SizedBox(height: 16),
        const _DeliverSkeletonOrderCard(showStack: true),
        const SizedBox(height: 16),
        const _DeliverSkeletonOrderCard(),
      ],
    );
  }

  Widget _buildSkeletonNoticeCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E6),
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: const Color(0xFFFDE8B8)),
      ),
      child: const Row(
        children: [
          _DeliverSkeletonBox(width: 17, height: 17, radius: 8.5),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DeliverSkeletonBox(height: 10, radius: 5),
                SizedBox(height: 7),
                _DeliverSkeletonBox(width: 240, height: 10, radius: 5),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonSteamCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x05000000),
            blurRadius: 12,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: const Row(
        children: [
          _DeliverSkeletonBox(width: 52, height: 52, radius: 26),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _DeliverSkeletonBox(width: 82, height: 13, radius: 5),
                    SizedBox(width: 6),
                    _DeliverSkeletonBox(width: 14, height: 14, radius: 7),
                  ],
                ),
                SizedBox(height: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _DeliverSkeletonBox(width: 20, height: 16, radius: 8),
                    SizedBox(width: 6),
                    _DeliverSkeletonBox(width: 92, height: 10, radius: 4),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBuyerCard(CurrencyController? _) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E6),
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: const Color(0xFFFDE8B8)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(
              Icons.warning_amber_rounded,
              size: 17,
              color: Color(0xFFE28A00),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _isEnglishLocale
                  ? 'When confirming in Steam Guard, carefully verify the buyer Steam account and item information.'
                  : '在 Steam 令牌确认时，请仔细核对买家的 Steam 账号与商品信息。',
              style: const TextStyle(
                color: Color(0xFF7C4A03),
                fontSize: 12,
                fontWeight: FontWeight.w500,
                height: 18 / 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSteamBuyerCard() {
    final buyer = _buyerInfo();
    final displayName = buyer?.nickname?.trim().isNotEmpty == true
        ? buyer!.nickname!
        : (_isEnglishLocale ? 'Steam Buyer' : 'Steam 买家');
    final level = buyer?.level;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x05000000),
            blurRadius: 12,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildSteamBuyerAvatar(buyer),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      fit: FlexFit.loose,
                      child: Text(
                        displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _titleColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          height: 18 / 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: 5),
                    _buildSteamRefreshButton(),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildSteamLevelBadge(level),
                    const SizedBox(width: 6),
                    const Text(
                      'STEAM LEVEL',
                      style: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        height: 12 / 9,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSteamBuyerAvatar(ShopUserInfo? buyer) {
    final avatar = (buyer?.avatar ?? '').trim();
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(26),
      ),
      clipBehavior: Clip.antiAlias,
      child: avatar.isEmpty
          ? const Icon(Icons.person_outline_rounded, color: _mutedColor)
          : CachedNetworkImage(
              imageUrl: avatar,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) =>
                  const Icon(Icons.person_outline_rounded, color: _mutedColor),
            ),
    );
  }

  Widget _buildSteamLevelBadge(int? level) {
    return Container(
      height: 16,
      constraints: const BoxConstraints(minWidth: 20),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFF2F6FED),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        level?.toString() ?? '--',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          height: 12 / 9,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildSteamRefreshButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: _refreshingBuyer ? null : _refreshBuyer,
        child: Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          alignment: Alignment.center,
          child: _refreshingBuyer
              ? const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.8,
                    color: _brandColor,
                  ),
                )
              : const Icon(Icons.refresh_rounded, size: 14, color: _brandColor),
        ),
      ),
    );
  }

  Widget _buildOrdersCard(CurrencyController? currency) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildShipmentHeader(),
        const SizedBox(height: 12),
        for (var index = 0; index < _orders.length; index++) ...[
          if (index > 0) const SizedBox(height: 16),
          _buildOrderBlock(_orders[index], currency),
        ],
      ],
    );
  }

  Widget _buildShipmentHeader() {
    return Row(
      children: [
        Expanded(
          child: Text(
            '${_isEnglishLocale ? 'Shipment Count' : '发货数量'} (${_totalItems()})',
            style: const TextStyle(
              color: _titleColor,
              fontSize: 15,
              fontWeight: FontWeight.w800,
              height: 22 / 15,
            ),
          ),
        ),
        Text(
          _isEnglishLocale ? 'LIST SUMMARY' : '清单摘要',
          style: const TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 9,
            fontWeight: FontWeight.w900,
            height: 12 / 9,
            letterSpacing: 1.0,
          ),
        ),
      ],
    );
  }

  Widget _buildOrderBlock(ShopOrderItem order, CurrencyController? currency) {
    final useBatchPreview = _shouldUseOrderBatchPreview(order);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _orderIdLabel(order.id),
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    height: 12 / 9,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                _formatTime(order.createTime),
                style: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  height: 14 / 10,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (useBatchPreview)
            _buildOrderBatchItem(order, currency)
          else
            for (var index = 0; index < order.details.length; index++) ...[
              if (index > 0) const Divider(height: 18, color: _lineColor),
              _buildDetailItem(order.details[index], currency),
            ],
        ],
      ),
    );
  }

  Widget _buildOrderBatchItem(
    ShopOrderItem order,
    CurrencyController? currency,
  ) {
    final primary = order.details.first;
    final title = _detailTitle(primary);
    final wearInfo = _wearInfo(primary);
    final stickers = _detailStickers(primary);
    final price = _orderTotalPrice(order);
    final previewWidth = _orderBatchPreviewWidth(order);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPreviewColumn(
          preview: _buildOrderBatchPreview(order),
          width: previewWidth,
          wearInfo: wearInfo,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _titleColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  height: 20 / 14,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                _formatCurrency(price, currency),
                style: const TextStyle(
                  color: Color(0xFFE31B2F),
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  height: 18 / 13,
                ),
              ),
              if (stickers.isNotEmpty) ...[
                const SizedBox(height: 7),
                _buildStickerPreview(stickers),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailItem(
    ShopOrderDetail detail,
    CurrencyController? currency,
  ) {
    final title = _detailTitle(detail);
    final wearInfo = _wearInfo(detail);
    final price =
        detail.totalPrice ?? ((detail.price ?? 0) * (detail.count ?? 1));
    final stickers = _detailStickers(detail);
    final previewWidth = _detailPreviewWidth(detail);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPreviewColumn(
          preview: _buildDetailPreview(detail),
          width: previewWidth,
          wearInfo: wearInfo,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _titleColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  height: 20 / 14,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                _formatCurrency(price, currency),
                style: const TextStyle(
                  color: Color(0xFFE31B2F),
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  height: 18 / 13,
                ),
              ),
              if (stickers.isNotEmpty) ...[
                const SizedBox(height: 7),
                _buildStickerPreview(stickers),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewColumn({
    required Widget preview,
    required double width,
    required _DetailWearInfo? wearInfo,
  }) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          preview,
          if (wearInfo != null) ...[
            const SizedBox(height: 6),
            _buildCompactWearInfo(wearInfo),
          ],
        ],
      ),
    );
  }

  Widget _buildCompactWearInfo(_DetailWearInfo wearInfo) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              _isEnglishLocale ? 'Wear' : '磨损度',
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 8,
                fontWeight: FontWeight.w700,
                height: 10 / 8,
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                wearInfo.text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  color: _titleColor,
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                  height: 10 / 8,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        WearProgressBar(
          paintWear: wearInfo.value,
          height: 10,
          style: WearProgressBarStyle.figmaCompact,
        ),
      ],
    );
  }

  Widget _buildOrderBatchPreview(ShopOrderItem order) {
    final previewDetails = _orderPreviewDetails(order);
    final count = _orderItemQuantity(order);
    if (previewDetails.isEmpty) {
      return const SizedBox(
        width: 64,
        height: 64,
        child: DecoratedBox(
          decoration: BoxDecoration(color: Color(0xFFECEEF0)),
          child: Icon(
            Icons.image_not_supported_outlined,
            size: 22,
            color: _mutedColor,
          ),
        ),
      );
    }

    const tileSize = 64.0;
    const horizontalPeek = 7.0;
    const verticalPeek = 4.0;
    const badgeSize = 22.0;
    const badgeOverlap = 6.0;
    final stackCount = previewDetails.length > 3 ? 3 : previewDetails.length;
    return SizedBox(
      width: tileSize + ((stackCount - 1) * horizontalPeek),
      height: tileSize + ((stackCount - 1) * verticalPeek),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var layer = stackCount - 1; layer >= 0; layer--)
            Positioned(
              left: layer * horizontalPeek,
              top: layer * verticalPeek,
              child: _buildDetailImageTile(
                previewDetails[layer],
                isFront: layer == 0,
                opacity: layer == 0 ? 1 : (layer == 1 ? 0.74 : 0.52),
              ),
            ),
          Positioned(
            left: tileSize - badgeSize + badgeOverlap,
            top: -badgeOverlap,
            child: _buildCountBadge(count),
          ),
        ],
      ),
    );
  }

  double _orderBatchPreviewWidth(ShopOrderItem order) {
    final previewDetails = _orderPreviewDetails(order);
    if (previewDetails.isEmpty) {
      return 64;
    }
    const tileSize = 64.0;
    const horizontalPeek = 7.0;
    final stackCount = previewDetails.length > 3 ? 3 : previewDetails.length;
    return tileSize + ((stackCount - 1) * horizontalPeek);
  }

  Widget _buildDetailPreview(ShopOrderDetail detail) {
    final count = detail.count ?? 1;
    if (count > 1) {
      return _buildStackedDetailPreview(detail, count);
    }
    return _buildDetailImageTile(detail, isFront: true, opacity: 1);
  }

  double _detailPreviewWidth(ShopOrderDetail detail) {
    final count = detail.count ?? 1;
    if (count <= 1) {
      return 64;
    }
    const tileSize = 64.0;
    const horizontalPeek = 7.0;
    final stackCount = count > 3 ? 3 : count;
    return tileSize + ((stackCount - 1) * horizontalPeek);
  }

  Widget _buildStackedDetailPreview(ShopOrderDetail detail, int count) {
    const tileSize = 64.0;
    const horizontalPeek = 7.0;
    const verticalPeek = 4.0;
    const badgeSize = 22.0;
    const badgeOverlap = 6.0;
    final stackCount = count > 3 ? 3 : count;
    return SizedBox(
      width: tileSize + ((stackCount - 1) * horizontalPeek),
      height: tileSize + ((stackCount - 1) * verticalPeek),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var layer = stackCount - 1; layer >= 0; layer--)
            Positioned(
              left: layer * horizontalPeek,
              top: layer * verticalPeek,
              child: _buildDetailImageTile(
                detail,
                isFront: layer == 0,
                opacity: layer == 0 ? 1 : (layer == 1 ? 0.74 : 0.52),
              ),
            ),
          Positioned(
            left: tileSize - badgeSize + badgeOverlap,
            top: -badgeOverlap,
            child: _buildCountBadge(count),
          ),
        ],
      ),
    );
  }

  Widget _buildCountBadge(int count) {
    return Container(
      constraints: const BoxConstraints(minWidth: 22),
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: _brandColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white, width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A0F172A),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        _countLabel(count),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          height: 1,
        ),
      ),
    );
  }

  Widget _buildDetailImageTile(
    ShopOrderDetail detail, {
    required bool isFront,
    required double opacity,
  }) {
    final schema = _lookupSchema(detail);
    final imageUrl = detail.imageUrl ?? schema?.imageUrl ?? '';
    final appId = _resolveDetailAppId(detail, schema);
    final rarity = _schemaTag(schema, 'rarity');
    final quality = _schemaTag(schema, 'quality');
    final exterior = _schemaTag(schema, 'exterior');
    final phase = _detailText(detail, const ['phase']);
    final percentage = _detailText(detail, const ['percentage']);

    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: isFront ? const Color(0xFFECEEF0) : const Color(0xFFE5E7EB),
        borderRadius: BorderRadius.circular(4),
        boxShadow: isFront
            ? const [
                BoxShadow(
                  color: Color(0x12000000),
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ]
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: Opacity(
        opacity: opacity,
        child: GameItemImage(
          imageUrl: imageUrl,
          appId: appId,
          rarity: rarity,
          quality: quality,
          exterior: exterior,
          phase: phase,
          percentage: percentage,
          showTopBadges: false,
        ),
      ),
    );
  }

  Widget _buildStickerPreview(List<GameItemSticker> stickers) {
    final visible = stickers.length > 4 ? stickers.take(4) : stickers;
    return Wrap(
      spacing: 5,
      runSpacing: 4,
      children: [
        for (final sticker in visible)
          Container(
            width: 18,
            height: 18,
            color: const Color(0xFFF1F5F9),
            child: Image.network(
              sticker.imageUrl,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
      ],
    );
  }

  Widget _buildBottomActionBar(double bottomInset, int? status) {
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
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 672),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildSteamConfirmButton(
                      onTap: status == 2 && !_submitting ? _submit : null,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isEnglishLocale
                          ? 'STEAM MOBILE CONFIRMATION REQUIRED\nAPI KEY VERIFIED SECURE'
                          : '需要前往 STEAM 手机端确认\nAPI KEY 已安全验证',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 7,
                        fontWeight: FontWeight.w900,
                        height: 11 / 7,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSteamConfirmButton({required VoidCallback? onTap}) {
    return Opacity(
      opacity: onTap == null ? 0.6 : 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Container(
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFF111827),
            borderRadius: BorderRadius.circular(6),
            boxShadow: const [
              BoxShadow(
                color: Color(0x26000000),
                blurRadius: 12,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _submitting
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(
                      Icons.bolt_rounded,
                      size: 16,
                      color: Colors.white,
                    ),
              const SizedBox(width: 8),
              Text(
                _isEnglishLocale
                    ? 'Go to Steam APP to confirm'
                    : '前往 Steam APP 确认',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  height: 18 / 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  ShopUserInfo? _buyerInfo() {
    final direct = _users[_args.buyerId];
    if (direct != null) {
      return direct;
    }
    for (final order in _orders) {
      if (order.buyerId == _args.buyerId && order.user != null) {
        return order.user;
      }
    }
    return null;
  }

  ShopSchemaInfo? _lookupSchema(ShopOrderDetail detail) {
    final hash = detail.marketHashName;
    if (hash != null && _schemas.containsKey(hash)) {
      return _schemas[hash];
    }
    final schemaId = detail.schemaId?.toString();
    if (schemaId != null && _schemas.containsKey(schemaId)) {
      return _schemas[schemaId];
    }
    return null;
  }

  String _orderIdLabel(int? id) {
    if (id == null) {
      return _isEnglishLocale ? 'ORDER ID: --' : '订单 ID: --';
    }
    return _isEnglishLocale ? 'ORDER ID: $id' : '订单 ID: $id';
  }

  String _countLabel(int count) {
    if (count > 99) {
      return '99+';
    }
    return '$count';
  }

  bool _shouldUseOrderBatchPreview(ShopOrderItem order) {
    final quantity = _orderItemQuantity(order);
    if (quantity <= 1 || order.details.isEmpty) {
      return false;
    }
    if (order.details.length == 1) {
      return true;
    }
    final firstIdentity = _detailIdentity(order.details.first);
    return order.details.skip(1).every((detail) {
      return _detailIdentity(detail) == firstIdentity;
    });
  }

  String _detailIdentity(ShopOrderDetail detail) {
    final schemaId = detail.schemaId;
    if (schemaId != null && schemaId > 0) {
      return 'schema:$schemaId';
    }
    final hashName = (detail.marketHashName ?? '').trim();
    if (hashName.isNotEmpty) {
      return 'hash:$hashName';
    }
    final marketName = (detail.marketName ?? '').trim();
    if (marketName.isNotEmpty) {
      return 'name:$marketName';
    }
    final imageUrl = (detail.imageUrl ?? '').trim();
    return 'image:$imageUrl';
  }

  int _orderItemQuantity(ShopOrderItem order) {
    if (order.nums != null && order.nums! > 0) {
      return order.nums!;
    }
    var total = 0;
    for (final detail in order.details) {
      total += detail.count ?? 1;
    }
    return total > 0 ? total : 1;
  }

  List<ShopOrderDetail> _orderPreviewDetails(ShopOrderItem order) {
    final previews = <ShopOrderDetail>[];
    for (final detail in order.details) {
      final detailCount = detail.count ?? 1;
      final repeat = detailCount > 0 ? detailCount : 1;
      for (var index = 0; index < repeat; index++) {
        previews.add(detail);
        if (previews.length >= 3) {
          return previews;
        }
      }
    }
    return previews;
  }

  double _orderTotalPrice(ShopOrderItem order) {
    final orderTotal = order.totalPrice ?? order.price;
    if (orderTotal != null) {
      return orderTotal;
    }
    var total = 0.0;
    for (final detail in order.details) {
      total += detail.totalPrice ?? ((detail.price ?? 0) * (detail.count ?? 1));
    }
    return total;
  }

  String _detailTitle(ShopOrderDetail detail) {
    final schema = _lookupSchema(detail);
    return detail.marketName ??
        detail.marketHashName ??
        schema?.marketName ??
        schema?.marketHashName ??
        '-';
  }

  int? _resolveDetailAppId(ShopOrderDetail detail, ShopSchemaInfo? schema) {
    final detailAppId = _asInt(detail.raw['app_id'] ?? detail.raw['appId']);
    if (detailAppId != null) {
      return detailAppId;
    }
    final schemaAppId = _asInt(schema?.raw['app_id'] ?? schema?.raw['appId']);
    return schemaAppId ?? GameStorage.getGameType();
  }

  TagInfo? _schemaTag(ShopSchemaInfo? schema, String key) {
    final tags = schema?.raw['tags'];
    if (tags is Map) {
      return TagInfo.fromRaw(tags[key]);
    }
    return null;
  }

  String? _detailText(ShopOrderDetail detail, List<String> keys) {
    for (final key in keys) {
      final value = detail.raw[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString();
      }
    }
    return null;
  }

  List<GameItemSticker> _detailStickers(ShopOrderDetail detail) {
    for (final candidate in _detailStickerCandidates(detail)) {
      final stickers = parseStickerList(
        _normalizeStickerEntries(candidate),
        schemaMap: _schemas,
        stickerMap: _stickers,
      );
      if (stickers.isNotEmpty) {
        return stickers;
      }
    }
    return const [];
  }

  List<dynamic> _detailStickerCandidates(ShopOrderDetail detail) {
    final schema = _lookupSchema(detail);
    final appId = _resolveDetailAppId(detail, schema);
    final raw = detail.raw;
    final schemaRaw = schema?.raw;
    final rawAsset = _pickAssetRaw(raw, appId);
    final rawCsgoAsset = _asMap(raw['csgoAsset']);
    final schemaAsset = schemaRaw == null
        ? null
        : _pickAssetRaw(schemaRaw, appId);
    final schemaCsgoAsset = _asMap(schemaRaw?['csgoAsset']);

    return [
      raw['stickers'],
      raw['stickerList'],
      raw['sticker_list'],
      raw['sticker'],
      rawAsset?['stickers'],
      rawAsset?['stickerList'],
      rawAsset?['sticker_list'],
      rawAsset?['sticker'],
      rawCsgoAsset?['stickers'],
      rawCsgoAsset?['stickerList'],
      rawCsgoAsset?['sticker_list'],
      rawCsgoAsset?['sticker'],
      schemaRaw?['stickers'],
      schemaRaw?['stickerList'],
      schemaRaw?['sticker_list'],
      schemaRaw?['sticker'],
      schemaAsset?['stickers'],
      schemaAsset?['stickerList'],
      schemaAsset?['sticker_list'],
      schemaAsset?['sticker'],
      schemaCsgoAsset?['stickers'],
      schemaCsgoAsset?['stickerList'],
      schemaCsgoAsset?['sticker_list'],
      schemaCsgoAsset?['sticker'],
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
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .toList(growable: false);
      }
      return <dynamic>[value];
    }
    return const [];
  }

  Map<String, dynamic>? _pickAssetRaw(Map<String, dynamic> raw, int? appId) {
    if (appId == 730 && raw['csgoAsset'] is Map) {
      return _asMap(raw['csgoAsset']);
    }
    if (appId == 440 && raw['tf2Asset'] is Map) {
      return _asMap(raw['tf2Asset']);
    }
    if (appId == 570 && raw['dota2Asset'] is Map) {
      return _asMap(raw['dota2Asset']);
    }
    return _asMap(raw['asset']);
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

  _DetailWearInfo? _wearInfo(ShopOrderDetail detail) {
    final schema = _lookupSchema(detail);
    if (_resolveDetailAppId(detail, schema) != 730) {
      return null;
    }
    final value = _paintWearValue(detail);
    if (value == null) {
      return null;
    }
    final text = _paintWearText(detail) ?? value.toString();
    return _DetailWearInfo(value: value, text: text);
  }

  double? _paintWearValue(ShopOrderDetail detail) {
    final value = detail.raw['paint_wear'] ?? detail.raw['paintWear'];
    if (value is num) {
      return value.toDouble();
    }
    if (value != null) {
      return double.tryParse(value.toString());
    }
    return detail.paintWear;
  }

  String? _paintWearText(ShopOrderDetail detail) {
    final value = detail.raw['paint_wear'] ?? detail.raw['paintWear'];
    return value?.toString() ?? detail.paintWear?.toString();
  }

  String _formatCurrency(double value, CurrencyController? currency) {
    if (currency != null) {
      return currency.format(value);
    }
    return NumberFormat.currency(symbol: '\$').format(value);
  }

  String _formatTime(int? timestamp) {
    if (timestamp == null) {
      return '--';
    }
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    return DateFormat('MM-dd HH:mm').format(date);
  }

  int _totalItems() {
    var total = 0;
    for (final order in _orders) {
      total += order.details.fold<int>(0, (sum, detail) {
        return sum + (detail.count ?? 1);
      });
    }
    return total;
  }
}

class _DetailWearInfo {
  const _DetailWearInfo({required this.value, required this.text});

  final double value;
  final String text;
}

class _ShopDeliverGoodsArgs {
  const _ShopDeliverGoodsArgs({required this.buyerId, this.status});

  final String buyerId;
  final int? status;

  factory _ShopDeliverGoodsArgs.fromDynamic(dynamic raw) {
    if (raw is Map) {
      return _ShopDeliverGoodsArgs(
        buyerId: raw['buyerId']?.toString().trim() ?? '',
        status: _asInt(raw['status']),
      );
    }
    return const _ShopDeliverGoodsArgs(buyerId: '');
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

class _DeliverSkeletonOrderCard extends StatelessWidget {
  const _DeliverSkeletonOrderCard({this.showStack = false});

  final bool showStack;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              _DeliverSkeletonBox(width: 150, height: 9, radius: 4),
              Spacer(),
              _DeliverSkeletonBox(width: 56, height: 10, radius: 4),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              showStack
                  ? const _DeliverSkeletonStackedImage()
                  : const _DeliverSkeletonBox(width: 64, height: 64, radius: 4),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _DeliverSkeletonBox(height: 14, radius: 5),
                    SizedBox(height: 8),
                    _DeliverSkeletonBox(width: 170, height: 14, radius: 5),
                    SizedBox(height: 10),
                    _DeliverSkeletonBox(width: 58, height: 13, radius: 5),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DeliverSkeletonStackedImage extends StatelessWidget {
  const _DeliverSkeletonStackedImage();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 78,
      height: 72,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 14,
            top: 8,
            child: _DeliverSkeletonBox(width: 64, height: 64, radius: 4),
          ),
          Positioned(
            left: 7,
            top: 4,
            child: _DeliverSkeletonBox(width: 64, height: 64, radius: 4),
          ),
          Positioned(
            left: 0,
            top: 0,
            child: _DeliverSkeletonBox(width: 64, height: 64, radius: 4),
          ),
          Positioned(
            left: 48,
            top: -6,
            child: _DeliverSkeletonBox(width: 22, height: 22, radius: 11),
          ),
        ],
      ),
    );
  }
}

class _DeliverSkeletonBox extends StatelessWidget {
  const _DeliverSkeletonBox({
    this.width,
    required this.height,
    required this.radius,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width ?? double.infinity,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFE8EEF4),
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}
