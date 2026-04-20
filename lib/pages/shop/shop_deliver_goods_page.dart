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
  static const _bodyColor = Color(0xFF444653);
  static const _lineColor = Color(0xFFECEEF0);
  static const _brandColor = Color(0xFF00288E);

  final _args = _ShopDeliverGoodsArgs.fromDynamic(Get.arguments);
  final ApiShopProductServer _api = ApiShopProductServer();
  final ApiSteamServer _steamApi = ApiSteamServer();
  final ApiTradeOfferServer _tradeApi = ApiTradeOfferServer();

  final Map<String, ShopSchemaInfo> _schemas = <String, ShopSchemaInfo>{};
  final Map<String, ShopUserInfo> _users = <String, ShopUserInfo>{};
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
                      ? const Padding(
                          padding: EdgeInsets.only(top: 96),
                          child: Center(child: CircularProgressIndicator()),
                        )
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
                            const SizedBox(height: 16),
                            _buildSteamBuyerCard(),
                            const SizedBox(height: 16),
                            _buildOrdersCard(currency),
                            const SizedBox(height: 16),
                            _buildTipsCard(),
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

  Widget _buildBuyerCard(CurrencyController? currency) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
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
                child: const Icon(
                  Icons.local_shipping_outlined,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  _isEnglishLocale ? 'Ready to Deliver' : '准备发货',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    height: 32 / 24,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'app.trade.order.seller_tips_3'.tr,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              height: 20 / 13,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
            ),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildGlassMetricChip(
                  label: _isEnglishLocale ? 'Items' : '发货数量',
                  value: _totalItems().toString(),
                ),
                _buildGlassMetricChip(
                  label: _isEnglishLocale ? 'Total' : '订单金额',
                  value: _formatCurrency(_totalAmount(), currency),
                ),
              ],
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
    final yearsLevel = buyer?.yearsLevel;

    return _buildCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSteamBuyerAvatar(buyer),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isEnglishLocale ? 'Buyer Steam Info' : '买家 Steam 信息',
                  style: const TextStyle(
                    color: _mutedColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 18 / 12,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _titleColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    height: 24 / 18,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          if (level != null) _buildSteamLevelBadge(level),
                          if (yearsLevel != null)
                            _buildSteamYearsBadge(yearsLevel),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildSteamRefreshButton(),
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
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
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

  Widget _buildSteamLevelBadge(int level) {
    return Container(
      height: 24,
      constraints: const BoxConstraints(minWidth: 24),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0x1F444653)),
        borderRadius: BorderRadius.circular(999),
        color: Colors.white,
      ),
      child: Text(
        '$level',
        style: const TextStyle(
          color: Color(0xFF444653),
          fontSize: 11,
          height: 16 / 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildSteamYearsBadge(int yearsLevel) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Image.network(
        'https://community.cloudflare.steamstatic.com/public/images/badges/02_years/steamyears${yearsLevel}_80.png',
        width: 24,
        height: 24,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
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
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
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
              : const Icon(Icons.refresh_rounded, size: 16, color: _brandColor),
        ),
      ),
    );
  }

  Widget _buildGlassMetricChip({required String label, required String value}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            height: 16 / 12,
          ),
          children: [
            TextSpan(text: '$label  '),
            TextSpan(
              text: value,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrdersCard(CurrencyController? currency) {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(
            '${_isEnglishLocale ? 'Delivery Items' : '待发货商品'} (${_totalItems()})',
          ),
          const SizedBox(height: 16),
          for (var index = 0; index < _orders.length; index++) ...[
            if (index > 0) const SizedBox(height: 16),
            _buildOrderBlock(_orders[index], currency),
          ],
        ],
      ),
    );
  }

  Widget _buildOrderBlock(ShopOrderItem order, CurrencyController? currency) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${_isEnglishLocale ? 'Order No' : '订单号'}: ${order.id ?? '--'}',
                  style: const TextStyle(
                    color: _titleColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                _formatTime(order.createTime),
                style: const TextStyle(
                  color: _mutedColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (var index = 0; index < order.details.length; index++) ...[
            if (index > 0) const Divider(height: 20, color: _lineColor),
            _buildDetailItem(order.details[index], currency),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailItem(
    ShopOrderDetail detail,
    CurrencyController? currency,
  ) {
    final schema = _lookupSchema(detail);
    final title =
        detail.marketName ??
        detail.marketHashName ??
        schema?.marketName ??
        schema?.marketHashName ??
        '-';
    final imageUrl = detail.imageUrl ?? schema?.imageUrl ?? '';
    final wearValue = _paintWearValue(detail);
    final wearText = _paintWearText(detail);
    final count = detail.count ?? 1;
    final price =
        detail.totalPrice ?? ((detail.price ?? 0) * (detail.count ?? 1));

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildProductImage(imageUrl),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _titleColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  height: 22 / 15,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildInfoChip(
                    label: '${_isEnglishLocale ? 'Qty' : '数量'} x$count',
                    background: const Color(0xFFEFF6FF),
                    foreground: const Color(0xFF1D4ED8),
                  ),
                  if (wearText != null && wearText.isNotEmpty)
                    _buildInfoChip(
                      label: wearText,
                      background: const Color(0xFFF8FAFC),
                      foreground: const Color(0xFF475569),
                    ),
                ],
              ),
              if (wearValue != null) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: WearProgressBar(paintWear: wearValue, height: 16),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text(
          _formatCurrency(price, currency),
          style: const TextStyle(
            color: _brandColor,
            fontSize: 15,
            fontWeight: FontWeight.w800,
            height: 22 / 15,
          ),
        ),
      ],
    );
  }

  Widget _buildProductImage(String imageUrl) {
    return Container(
      width: 76,
      height: 56,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: imageUrl.isEmpty
          ? const Icon(Icons.image_not_supported_outlined, color: _mutedColor)
          : CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.contain,
              placeholder: (_, __) => const Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
              errorWidget: (_, __, ___) =>
                  const Icon(Icons.image_not_supported_outlined),
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
          fontSize: 12,
          fontWeight: FontWeight.w700,
          height: 16 / 12,
        ),
      ),
    );
  }

  Widget _buildTipsCard() {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(_isEnglishLocale ? 'Shipping Notes' : '发货提醒'),
          const SizedBox(height: 14),
          _buildTipLine(
            _isEnglishLocale
                ? 'Verify the buyer information in Steam before sending the trade offer.'
                : '前往 Steam 发货前，请先核对买家 Steam 信息，避免误发。',
          ),
          const SizedBox(height: 12),
          _buildTipLine(
            _isEnglishLocale
                ? 'After the trade offer is sent, return here to confirm the latest order status.'
                : '发出报价后可返回此处刷新，确认订单状态是否已更新。',
          ),
        ],
      ),
    );
  }

  Widget _buildTipLine(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 6,
          height: 6,
          margin: const EdgeInsets.only(top: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF59E0B),
            borderRadius: BorderRadius.circular(99),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: _bodyColor,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              height: 22 / 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.05),
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: _titleColor,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        height: 24 / 18,
      ),
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
            child: Row(
              children: [
                Expanded(
                  child: _buildBottomButton(
                    icon: Icons.support_agent_rounded,
                    label: _isEnglishLocale ? 'Contact' : '联系客服',
                    background: const Color(0xFFF1F5F9),
                    foreground: const Color(0xFF475569),
                    onTap: () => Get.toNamed(Routers.FEEDBACK_LIST),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildBottomButton(
                    icon: Icons.local_shipping_outlined,
                    label: _isEnglishLocale ? 'Deliver Now' : '立即发货',
                    background: null,
                    foreground: Colors.white,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                    ),
                    onTap: status == 2 && !_submitting ? _submit : null,
                    trailing: _submitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : null,
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
    required Color? background,
    required Color foreground,
    Gradient? gradient,
    required VoidCallback? onTap,
    Widget? trailing,
  }) {
    return Opacity(
      opacity: onTap == null ? 0.6 : 1,
      child: InkWell(
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
              trailing ?? Icon(icon, size: 20, color: foreground),
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

  String? _paintWearText(ShopOrderDetail detail) {
    final value = detail.raw['paint_wear'] ?? detail.raw['paintWear'];
    if (value == null) {
      return null;
    }
    return value.toString();
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

  double _totalAmount() {
    var total = 0.0;
    for (final order in _orders) {
      final orderTotal = order.totalPrice ?? order.price;
      if (orderTotal != null) {
        total += orderTotal;
        continue;
      }
      for (final detail in order.details) {
        total +=
            detail.totalPrice ?? ((detail.price ?? 0) * (detail.count ?? 1));
      }
    }
    return total;
  }
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
