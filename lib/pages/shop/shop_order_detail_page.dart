import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:tronskins_app/api/model/market/market_models.dart';
import 'package:tronskins_app/api/model/shop/shop_models.dart';
import 'package:tronskins_app/api/steam.dart';
import 'package:tronskins_app/api/tradeoffer.dart';
import 'package:tronskins_app/common/hooks/currency/CurrencyController.dart';
import 'package:tronskins_app/common/storage/game_storage.dart';
import 'package:tronskins_app/common/theme/order_detail_status_style.dart';
import 'package:tronskins_app/common/utils/app_snackbar.dart';
import 'package:tronskins_app/common/widgets/back_to_top_overlay.dart';
import 'package:tronskins_app/common/widgets/figma_confirmation_dialog.dart';
import 'package:tronskins_app/common/widgets/glass_notice_dialog.dart';
import 'package:tronskins_app/common/widgets/settings_style_app_bar.dart';
import 'package:tronskins_app/components/game_item/game_item_image.dart';
import 'package:tronskins_app/components/game_item/game_item_models.dart';
import 'package:tronskins_app/components/game_item/game_item_utils.dart';
import 'package:tronskins_app/components/game_item/game_item_wear_overlay.dart';
import 'package:tronskins_app/controllers/shop/shop_order_controller.dart';
import 'package:tronskins_app/controllers/shop/shop_shipping_notice_controller.dart';
import 'package:tronskins_app/controllers/user/user_controller.dart';
import 'package:tronskins_app/routes/app_routes.dart';

class ShopOrderDetailPage extends StatelessWidget {
  const ShopOrderDetailPage({super.key, this.isPendingFlow = false});

  static const _pageBg = Color(0xFFF7F9FB);
  static const _cardBg = Colors.white;
  static const _titleColor = Color(0xFF191C1E);
  static const _mutedColor = Color(0xFF757684);
  static const _bodyColor = Color(0xFF444653);
  static const _lineColor = Color(0xFFECEEF0);
  static const _brandColor = Color(0xFF00288E);
  static const _deliveryGoodsGlassColor = Color(0x33FFFFFF);

  final bool isPendingFlow;

  @override
  Widget build(BuildContext context) {
    final args = _ShopOrderDetailArgs.fromDynamic(Get.arguments);
    final order = args.order;
    if (order == null) {
      return _buildEmptyState(context);
    }

    final topInset = MediaQuery.of(context).padding.top;
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final currency = Get.isRegistered<CurrencyController>()
        ? Get.find<CurrencyController>()
        : null;
    final displayOrders = isPendingFlow
        ? (args.orders.isNotEmpty ? args.orders : <ShopOrderItem>[order])
        : <ShopOrderItem>[order];
    final totalPrice = _sumOrdersPrice(displayOrders);
    final totalItemCount = _countOrderItems(displayOrders);
    final feeAmount = isPendingFlow ? null : _extractFeeAmount(order);
    final incomeAmount = isPendingFlow
        ? null
        : _extractIncomeAmount(
            order: order,
            totalPrice: totalPrice,
            feeAmount: feeAmount,
          );
    final currentUserId = _currentUserId();
    final pendingBuyer = isPendingFlow
        ? _resolveBuyerParty(args.users, order)
        : null;
    final primaryParty = _resolvePrimaryParty(
      users: args.users,
      order: order,
      currentUserId: currentUserId,
    );
    final secondaryParty = _resolveSecondaryParty(
      users: args.users,
      order: order,
      primary: primaryParty,
      currentUserId: currentUserId,
    );
    return BackToTopScope(
      enabled: false,
      child: Scaffold(
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildStatusCard(
                          context: context,
                          order: order,
                          statusText: args.statusText,
                          currency: currency,
                          totalPrice: totalPrice,
                          totalItemCount: totalItemCount,
                          onCopy: order.id == null
                              ? null
                              : () =>
                                    _copyOrderId(context, order.id!.toString()),
                          useDeliveryGoodsPalette: args.fromDeliveryGoodsDrawer,
                        ),
                        const SizedBox(height: 16),
                        _buildOrderStatusCard(
                          order: order,
                          statusText: args.statusText,
                        ),
                        if (pendingBuyer != null) ...[
                          const SizedBox(height: 16),
                          _buildPendingBuyerCard(
                            order: order,
                            users: args.users,
                          ),
                        ],
                        const SizedBox(height: 16),
                        _buildProductCard(
                          context: context,
                          order: order,
                          orders: displayOrders,
                          schemas: args.schemas,
                          stickers: args.stickers,
                        ),
                        if (!isPendingFlow) ...[
                          const SizedBox(height: 16),
                          _buildPriceCard(
                            context: context,
                            currency: currency,
                            totalPrice: totalPrice,
                            totalItemCount: totalItemCount,
                            feeAmount: feeAmount,
                            incomeAmount: incomeAmount,
                          ),
                          if (primaryParty != null) ...[
                            const SizedBox(height: 16),
                            _buildPartyCard(
                              context: context,
                              order: order,
                              primary: primaryParty,
                              secondary: secondaryParty,
                              currentUserId: currentUserId,
                            ),
                          ],
                        ],
                        const SizedBox(height: 16),
                        _buildTipsCard(context),
                        if (isPendingFlow) ...[
                          const SizedBox(height: 16),
                          _buildPendingHelpSection(context),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
            _buildTopNavigation(context),
            _buildBottomActionBar(
              context,
              bottomInset,
              order,
              disableOrderActions: args.disableOrderActions,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: _pageBg,
      body: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.only(top: topInset + 96),
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
            ),
          ),
          _buildTopNavigation(context),
        ],
      ),
    );
  }

  Widget _buildStatusCard({
    required BuildContext context,
    required ShopOrderItem order,
    required String? statusText,
    required CurrencyController? currency,
    required double totalPrice,
    required int totalItemCount,
    required VoidCallback? onCopy,
    required bool useDeliveryGoodsPalette,
  }) {
    final statusLabel = _statusHeadline(order, statusText: statusText);
    final headline = _statusDescription(order, fallback: statusLabel);
    final statusRows = _buildStatusRows(order);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: kOrderDetailStatusCardGradientColors,
        ),
        borderRadius: BorderRadius.all(Radius.circular(12)),
        boxShadow: kOrderDetailStatusCardShadow,
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
                  color: useDeliveryGoodsPalette
                      ? _deliveryGoodsGlassColor
                      : Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20.5),
                ),
                child: Icon(
                  _statusIcon(order.status),
                  color: Colors.white,
                  size: 22,
                ),
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
                        style: TextStyle(
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
          if (isPendingFlow) ...[
            const SizedBox(height: 12),
            Text(
              'app.trade.order.seller_tips_3'.tr,
              style: const TextStyle(
                color: Color.fromRGBO(255, 255, 255, 0.92),
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
                    label: _text(zh: '发货数量', en: 'Items'),
                    value: totalItemCount.toString(),
                  ),
                  _buildGlassMetricChip(
                    label: _text(zh: '订单金额', en: 'Total'),
                    value: _formatPrice(currency, totalPrice),
                  ),
                ],
              ),
            ),
          ] else ...[
            const SizedBox(height: 24),
            ...statusRows.map(
              (row) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _buildStatusRow(
                  row,
                  onCopy: row.copyable ? onCopy : null,
                ),
              ),
            ),
            const SizedBox(height: 8),
            _buildGlassButton(
              label: _text(zh: '联系客服', en: 'Contact Customer Service'),
              onTap: () => Get.toNamed(Routers.FEEDBACK_LIST),
              backgroundColor: useDeliveryGoodsPalette
                  ? _deliveryGoodsGlassColor
                  : null,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOrderStatusCard({
    required ShopOrderItem order,
    required String? statusText,
  }) {
    final statusLabel = _statusHeadline(order, statusText: statusText);
    final statusColor = _statusHeadlineColor(order);
    return _buildCard(
      child: Row(
        children: [
          Expanded(
            child: _buildSectionTitle(_text(zh: '订单状态', en: 'Order Status')),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_statusIcon(order.status), color: statusColor, size: 16),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      statusLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        height: 20 / 14,
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

  Widget _buildProductCard({
    required BuildContext context,
    required ShopOrderItem order,
    required List<ShopOrderItem> orders,
    required Map<String, ShopSchemaInfo> schemas,
    required Map<String, dynamic> stickers,
  }) {
    final displayOrders = isPendingFlow ? orders : <ShopOrderItem>[order];
    final sectionTitle = isPendingFlow
        ? '${_text(zh: '待发货商品', en: 'Delivery Items')} (${_countOrderItems(displayOrders)})'
        : _text(zh: '商品信息', en: 'Product Info');
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(sectionTitle),
          const SizedBox(height: 16),
          if (displayOrders.isEmpty)
            _buildEmptyBlock()
          else
            ...List.generate(displayOrders.length, (index) {
              final currentOrder = displayOrders[index];
              return Padding(
                padding: EdgeInsets.only(
                  bottom: index == displayOrders.length - 1 ? 0 : 16,
                ),
                child: _buildOrderDetailsBlock(
                  context: context,
                  order: currentOrder,
                  schemas: schemas,
                  stickers: stickers,
                  grouped: isPendingFlow,
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildOrderDetailsBlock({
    required BuildContext context,
    required ShopOrderItem order,
    required Map<String, ShopSchemaInfo> schemas,
    required Map<String, dynamic> stickers,
    required bool grouped,
  }) {
    final details = order.details;
    final content = details.isEmpty
        ? <Widget>[_buildEmptyBlock()]
        : List<Widget>.generate(details.length, (index) {
            final detail = details[index];
            return Column(
              children: [
                _buildDetailItem(
                  context: context,
                  detail: detail,
                  schemas: schemas,
                  stickers: stickers,
                ),
                if (index != details.length - 1) ...[
                  const SizedBox(height: 16),
                  const Divider(height: 1, color: _lineColor),
                  const SizedBox(height: 16),
                ],
              ],
            );
          });
    if (!grouped) {
      return Column(children: content);
    }

    return Container(
      width: double.infinity,
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
                  '${_text(zh: '订单号', en: 'Order No')}: ${order.id ?? '-'}',
                  style: const TextStyle(
                    color: _titleColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    height: 18 / 13,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                _formatTime(order.createTime),
                style: const TextStyle(
                  color: _mutedColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  height: 18 / 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...content,
        ],
      ),
    );
  }

  Widget _buildPriceCard({
    required BuildContext context,
    required CurrencyController? currency,
    required double totalPrice,
    required int totalItemCount,
    required double? feeAmount,
    required double? incomeAmount,
  }) {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(
            isPendingFlow
                ? _text(zh: '发货汇总', en: 'Delivery Summary')
                : _text(zh: '价格明细', en: 'Price Breakdown'),
          ),
          const SizedBox(height: 16),
          if (isPendingFlow) ...[
            _buildPriceRow(
              _text(zh: '发货数量', en: 'Items'),
              totalItemCount.toString(),
            ),
            const SizedBox(height: 12),
          ],
          _buildPriceRow(
            isPendingFlow
                ? _text(zh: '订单总额', en: 'Total Amount')
                : _text(zh: '成交金额', en: 'Sale Price'),
            _formatPrice(currency, totalPrice),
          ),
          if (feeAmount != null) ...[
            const SizedBox(height: 12),
            _buildPriceRow(
              _text(zh: '服务费', en: 'Service Fee'),
              '-${_formatPrice(currency, feeAmount.abs())}',
              valueColor: const Color(0xFFBA1A1A),
            ),
          ],
          if (incomeAmount != null) ...[
            const SizedBox(height: 12),
            const Divider(height: 1, color: _lineColor),
            const SizedBox(height: 12),
            _buildPriceRow(
              _text(zh: '实际到账', en: 'Actual Income'),
              _formatPrice(currency, incomeAmount),
              labelStyle: const TextStyle(
                color: _titleColor,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                height: 1.5,
              ),
              valueStyle: const TextStyle(
                color: Color(0xFF10B981),
                fontSize: 20,
                fontWeight: FontWeight.w700,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPendingBuyerCard({
    required ShopOrderItem order,
    required Map<String, ShopUserInfo> users,
  }) {
    var refreshing = false;
    return StatefulBuilder(
      builder: (context, setState) {
        final buyer = _resolveBuyerParty(users, order);
        if (buyer == null) {
          return const SizedBox.shrink();
        }
        final chips = <Widget>[
          if (buyer.level != null)
            _buildSteamInfoChip(
              label: 'Lv.${buyer.level}',
              background: const Color(0xFFEFF6FF),
              foreground: const Color(0xFF2563EB),
            ),
          if (buyer.yearsLevel != null)
            _buildSteamInfoChip(
              label: _text(
                zh: 'Steam ${buyer.yearsLevel} 年',
                en: 'Steam ${buyer.yearsLevel}y',
              ),
              background: const Color(0xFFF8FAFC),
              foreground: const Color(0xFF475569),
            ),
        ];

        return _buildCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPendingBuyerAvatar(buyer),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle(
                      _text(zh: '买家 Steam 信息', en: 'Buyer Steam Info'),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      buyer.nickname?.trim().isNotEmpty == true
                          ? buyer.nickname!
                          : _text(zh: 'Steam 买家', en: 'Steam Buyer'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _titleColor,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        height: 24 / 18,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: chips.isEmpty
                              ? Text(
                                  _text(
                                    zh: '暂未获取到更多 Steam 信息',
                                    en: 'More Steam info unavailable',
                                  ),
                                  style: const TextStyle(
                                    color: _mutedColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    height: 18 / 12,
                                  ),
                                )
                              : Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: chips,
                                ),
                        ),
                        const SizedBox(width: 12),
                        _buildSteamRefreshButton(
                          refreshing: refreshing,
                          onTap: () async {
                            if (refreshing) {
                              return;
                            }
                            setState(() => refreshing = true);
                            try {
                              await _refreshBuyerInfo(
                                users: users,
                                order: order,
                              );
                            } finally {
                              if (context.mounted) {
                                setState(() => refreshing = false);
                              }
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPendingBuyerAvatar(_PartyInfo buyer) {
    final avatarUrl = _resolveAvatarUrl(buyer.avatar);
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: avatarUrl.isEmpty
          ? const Icon(Icons.person_outline_rounded, color: _mutedColor)
          : Image.network(
              avatarUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(
                  Icons.person_outline_rounded,
                  color: _mutedColor,
                );
              },
            ),
    );
  }

  Widget _buildSteamInfoChip({
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
          height: 16 / 11,
        ),
      ),
    );
  }

  Widget _buildSteamRefreshButton({
    required bool refreshing,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: refreshing ? null : onTap,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(999),
          ),
          alignment: Alignment.center,
          child: refreshing
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.8,
                    color: _brandColor,
                  ),
                )
              : const Icon(Icons.refresh_rounded, size: 18, color: _brandColor),
        ),
      ),
    );
  }

  Widget _buildPartyCard({
    required BuildContext context,
    required ShopOrderItem order,
    required _PartyInfo primary,
    required _PartyInfo? secondary,
    required String currentUserId,
  }) {
    _PartyInfo? visibleSecondary;
    if (secondary != null &&
        !_isSameParty(primary, secondary) &&
        !_isCurrentUserParty(secondary, currentUserId)) {
      visibleSecondary = secondary;
    }
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(primary.sectionTitle),
          const SizedBox(height: 16),
          _buildPartyRow(primary, order: order),
          if (visibleSecondary != null) ...[
            const SizedBox(height: 12),
            const Divider(height: 1, color: _lineColor),
            const SizedBox(height: 12),
            _buildMiniPartyRow(visibleSecondary),
          ],
        ],
      ),
    );
  }

  Widget _buildTipsCard(BuildContext context) {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(_text(zh: '温馨提示', en: 'Warm Tips')),
          const SizedBox(height: 14),
          ..._tipItems().map(
            (tip) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                tip,
                style: const TextStyle(
                  color: _bodyColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  height: 20 / 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingHelpSection(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Column(
        children: [
          Text(
            _text(zh: '需要帮助？', en: 'Need Help?'),
            style: const TextStyle(
              color: _mutedColor,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              height: 20 / 14,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildSupportAction(
                icon: Icons.help_outline_rounded,
                label: _text(zh: '帮助中心', en: 'Help Center'),
                onTap: () => Get.toNamed(Routers.HELP_CENTER),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTopNavigation(BuildContext context) {
    return SettingsStyleTopNavigation(
      title: _text(zh: '订单详情', en: 'Order Details'),
    );
  }

  Widget _buildBottomActionBar(
    BuildContext context,
    double bottomInset,
    ShopOrderItem order, {
    bool disableOrderActions = false,
  }) {
    final canReceiveOrder =
        !disableOrderActions && !isPendingFlow && _canReceiveOrder(order);
    final canCancelOrder =
        !disableOrderActions &&
        !isPendingFlow &&
        !canReceiveOrder &&
        _canCancelOrder(order);
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
                    icon: isPendingFlow
                        ? Icons.support_agent_rounded
                        : Icons.help_outline_rounded,
                    label: isPendingFlow
                        ? _text(zh: '联系客服', en: 'Contact')
                        : _text(zh: '帮助中心', en: 'Help Center'),
                    background: const Color(0xFFF1F5F9),
                    foreground: const Color(0xFF475569),
                    onTap: () => Get.toNamed(
                      isPendingFlow
                          ? Routers.FEEDBACK_LIST
                          : Routers.HELP_CENTER,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildBottomButton(
                    icon: isPendingFlow
                        ? Icons.local_shipping_outlined
                        : canReceiveOrder
                        ? Icons.inventory_2_outlined
                        : canCancelOrder
                        ? Icons.cancel_outlined
                        : Icons.support_agent_rounded,
                    label: isPendingFlow
                        ? _text(zh: '立即发货', en: 'Deliver Now')
                        : canReceiveOrder
                        ? 'app.market.product.receive'.tr
                        : canCancelOrder
                        ? 'app.trade.order.cancel'.tr
                        : _text(zh: '联系客服', en: 'Contact'),
                    background: null,
                    foreground: Colors.white,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isPendingFlow
                          ? const [Color(0xFFF59E0B), Color(0xFFD97706)]
                          : canReceiveOrder
                          ? const [Color(0xFF0F766E), Color(0xFF14B8A6)]
                          : canCancelOrder
                          ? const [Color(0xFFE11D48), Color(0xFFFB7185)]
                          : const [Color(0xFF1D4ED8), Color(0xFF3B82F6)],
                    ),
                    onTap: () => isPendingFlow
                        ? _openPendingDeliverPage(context, order)
                        : canReceiveOrder
                        ? _handleReceiveOrder(context, order)
                        : canCancelOrder
                        ? _handleCancelOrder(context, order)
                        : Get.toNamed(Routers.FEEDBACK_LIST),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailItem({
    required BuildContext context,
    required ShopOrderDetail detail,
    required Map<String, ShopSchemaInfo> schemas,
    required Map<String, dynamic> stickers,
  }) {
    final schema = _lookupSchema(
      schemas: schemas,
      marketHashName: detail.marketHashName,
      schemaId: detail.schemaId,
    );
    final appId = _resolveDetailAppId(detail, schema);
    final title =
        detail.marketName ??
        detail.marketHashName ??
        schema?.marketName ??
        schema?.marketHashName ??
        '-';
    final count = detail.count ?? 1;
    final paintWear = normalizeGameItemWearValue(
      detail.paintWear ?? _detailDouble(detail, const ['paint_wear']),
    );
    final wearText = formatGameItemWearText(
      _buildWearText(detail, null),
      paintWear,
    );
    final stickerDetails = _resolveDetailStickerDetails(
      detail: detail,
      schema: schema,
      appId: appId,
      stickerMap: stickers,
    );
    final exterior = _schemaTag(schema, 'exterior');
    final rarity = _schemaTag(schema, 'rarity');
    final quality = _schemaTag(schema, 'quality');
    final currency = Get.isRegistered<CurrencyController>()
        ? Get.find<CurrencyController>()
        : null;
    final price = _detailDisplayPrice(detail);
    final priceText = price == null ? null : _formatPrice(currency, price);
    final exteriorAccentColor = parseHexColor(exterior?.color);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _openMarketDetail(detail, schema),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildItemImage(
                    imageUrl: detail.imageUrl ?? schema?.imageUrl,
                    appId: appId,
                    rarity: rarity,
                    quality: quality,
                    exterior: exterior,
                    phase: detail.raw['phase']?.toString(),
                    percentage: detail.raw['percentage']?.toString(),
                    count: count > 1 ? count : null,
                    wearText: wearText,
                    paintWear: paintWear,
                    wearAccentColor: exteriorAccentColor,
                    wearConditionLabel: exterior?.label?.trim(),
                  ),
                  const SizedBox(width: 16),
                  _buildItemInfoContent(
                    title: title,
                    priceText: priceText,
                    count: count,
                    stickerDetails: stickerDetails,
                  ),
                ],
              ),
            ),
            if (stickerDetails.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildStickerDetailCards(
                stickers: stickerDetails,
                currency: currency,
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _openMarketDetail(ShopOrderDetail detail, ShopSchemaInfo? schema) {
    final item = _buildMarketDetailItem(detail, schema);
    if (item.schemaId == null && item.id == null) {
      AppSnackbar.error('app.trade.filter.failed'.tr);
      return;
    }
    Get.toNamed(Routers.MARKET_DETAIL, arguments: item);
  }

  MarketItemEntity _buildMarketDetailItem(
    ShopOrderDetail detail,
    ShopSchemaInfo? schema,
  ) {
    final schemaId =
        detail.schemaId ??
        _asInt(
          detail.raw['schema_id'] ??
              detail.raw['schemaId'] ??
              schema?.raw['schema_id'] ??
              schema?.raw['schemaId'] ??
              schema?.raw['id'],
        );
    final marketHashName =
        detail.marketHashName ??
        schema?.marketHashName ??
        _findTextValue(detail.raw, const [
          'market_hash_name',
          'marketHashName',
        ]);
    final marketName =
        detail.marketName ??
        schema?.marketName ??
        _findTextValue(detail.raw, const ['market_name', 'marketName', 'name']);
    final imageUrl =
        detail.imageUrl ??
        schema?.imageUrl ??
        _findTextValue(detail.raw, const ['image_url', 'imageUrl', 'image']);
    return MarketItemEntity(
      id: schemaId,
      schemaId: schemaId,
      appId: _resolveDetailAppId(detail, schema),
      marketName: marketName ?? marketHashName,
      marketHashName: marketHashName,
      imageUrl: imageUrl,
      marketPrice:
          _detailDisplayPrice(detail) ??
          _findNumericValue(schema?.raw, const [
            'reference_price',
            'referencePrice',
            'market_price',
            'marketPrice',
            'price',
          ]),
      paintSeed: _findTextValue(detail.raw, const ['paint_seed', 'paintSeed']),
      paintIndex: _findTextValue(detail.raw, const [
        'paint_index',
        'paintIndex',
      ]),
      paintWear:
          detail.paintWear?.toString() ??
          _findTextValue(detail.raw, const ['paint_wear', 'paintWear']),
      percentage: _findTextValue(detail.raw, const ['percentage']),
      phase: _findTextValue(detail.raw, const ['phase']),
      tags: _marketTagsFromSchema(schema),
    );
  }

  MarketItemTags? _marketTagsFromSchema(ShopSchemaInfo? schema) {
    final tags = schema?.raw['tags'];
    if (tags is Map<String, dynamic>) {
      return MarketItemTags.fromJson(tags);
    }
    if (tags is Map) {
      return MarketItemTags.fromJson(
        tags.map((key, value) => MapEntry(key.toString(), value)),
      );
    }
    return null;
  }

  Widget _buildItemInfoContent({
    required String title,
    required String? priceText,
    required int count,
    required List<_OrderStickerDetailData> stickerDetails,
  }) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _titleColor,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              height: 1.25,
            ),
          ),
          if (priceText != null) ...[
            const SizedBox(height: 6),
            Text(
              priceText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFFBA1A1A),
                fontSize: 16,
                fontWeight: FontWeight.w800,
                height: 20 / 16,
              ),
            ),
          ],
          if (stickerDetails.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildStickerIconRow(stickers: stickerDetails),
          ],
          if (count > 1) ...[
            const SizedBox(height: 10),
            _buildInfoChip(
              label: '${_text(zh: '数量', en: 'Qty')}: $count',
              background: const Color(0xFFEEF6FF),
              foreground: const Color(0xFF2563EB),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildItemImage({
    required String? imageUrl,
    required int appId,
    required TagInfo? rarity,
    required TagInfo? quality,
    required TagInfo? exterior,
    required String? phase,
    required String? percentage,
    required int? count,
    required String? wearText,
    required double? paintWear,
    required Color? wearAccentColor,
    required String? wearConditionLabel,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 96,
        height: 96,
        child: Stack(
          fit: StackFit.expand,
          children: [
            GameItemImage(
              imageUrl: imageUrl,
              appId: appId,
              rarity: rarity,
              quality: quality,
              exterior: exterior,
              phase: phase,
              percentage: percentage,
              count: count,
              squareTopBadges: true,
            ),
            if (paintWear != null && wearText != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: GameItemWearOverlay(
                  label: _text(zh: '磨损度', en: 'Wear'),
                  text: wearText,
                  value: paintWear,
                  accentColor: wearAccentColor,
                  conditionLabel: wearConditionLabel,
                  showLabel: false,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStickerIconRow({
    required List<_OrderStickerDetailData> stickers,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var index = 0; index < stickers.length; index++)
          _buildStickerIcon(sticker: stickers[index], index: index),
      ],
    );
  }

  Widget _buildStickerIcon({
    required _OrderStickerDetailData sticker,
    required int index,
  }) {
    final name = sticker.name?.trim().isNotEmpty == true
        ? sticker.name!
        : _stickerFallbackName(index);

    return Tooltip(
      message: name,
      child: Container(
        width: 32,
        height: 32,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Image.network(
          sticker.imageUrl,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return const Icon(
              Icons.image_not_supported_outlined,
              size: 18,
              color: _mutedColor,
            );
          },
        ),
      ),
    );
  }

  Widget _buildStickerDetailCards({
    required List<_OrderStickerDetailData> stickers,
    required CurrencyController? currency,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _text(zh: '印花', en: 'Stickers'),
          style: const TextStyle(
            color: _mutedColor,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            height: 16 / 12,
          ),
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final useTwoColumns = constraints.maxWidth >= 520;
            final spacing = useTwoColumns ? 8.0 : 0.0;
            final cardWidth = useTwoColumns
                ? (constraints.maxWidth - spacing) / 2
                : constraints.maxWidth;
            return Wrap(
              spacing: spacing,
              runSpacing: 8,
              children: [
                for (var index = 0; index < stickers.length; index++)
                  SizedBox(
                    width: cardWidth,
                    child: _buildStickerDetailCard(
                      sticker: stickers[index],
                      index: index,
                      currency: currency,
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildStickerDetailCard({
    required _OrderStickerDetailData sticker,
    required int index,
    required CurrencyController? currency,
  }) {
    final name = sticker.name?.trim().isNotEmpty == true
        ? sticker.name!
        : _stickerFallbackName(index);
    final price = sticker.price;
    final priceText = price == null ? '-' : _formatPrice(currency, price);
    final metaItems = <String>[
      if (sticker.slotLabel?.trim().isNotEmpty == true)
        sticker.slotLabel!.trim(),
      if (sticker.wearText?.trim().isNotEmpty == true)
        '${_text(zh: '磨损', en: 'Wear')} ${sticker.wearText!.trim()}',
    ];

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Image.network(
              sticker.imageUrl,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(
                  Icons.image_not_supported_outlined,
                  size: 20,
                  color: _mutedColor,
                );
              },
            ),
          ),
          const SizedBox(width: 10),
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
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    height: 16 / 12,
                  ),
                ),
                if (metaItems.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    metaItems.join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _mutedColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      height: 14 / 10,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 92),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                priceText,
                maxLines: 1,
                style: TextStyle(
                  color: price == null
                      ? const Color(0xFF94A3B8)
                      : const Color(0xFFBA1A1A),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  height: 16 / 12,
                ),
              ),
            ),
          ),
        ],
      ),
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

  Widget _buildEmptyBlock() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 18),
      alignment: Alignment.center,
      child: Text(
        'app.common.no_data'.tr,
        style: const TextStyle(
          color: _mutedColor,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
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

  Widget _buildPriceRow(
    String label,
    String value, {
    Color? valueColor,
    TextStyle? labelStyle,
    TextStyle? valueStyle,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style:
                labelStyle ??
                const TextStyle(
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
          style:
              valueStyle ??
              TextStyle(
                color: valueColor ?? _titleColor,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                height: 20 / 14,
              ),
        ),
      ],
    );
  }

  Widget _buildStatusRow(_StatusRowData row, {VoidCallback? onCopy}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
          child: Text(
            row.label,
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
                        row.value,
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

  Widget _buildGlassButton({
    required String label,
    required VoidCallback onTap,
    Color? backgroundColor,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: backgroundColor ?? Colors.white.withValues(alpha: 0.10),
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

  Widget _buildPartyRow(_PartyInfo party, {required ShopOrderItem order}) {
    final avatarUrl = _resolveAvatarUrl(party.avatar);
    final canOpenShop = (party.shopUuid ?? '').isNotEmpty;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: const BoxDecoration(
            color: Color(0xFFE2E8F0),
            shape: BoxShape.circle,
          ),
          clipBehavior: Clip.hardEdge,
          child: avatarUrl.isEmpty
              ? const Icon(Icons.person_rounded, color: _bodyColor)
              : Image.network(
                  avatarUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(Icons.person_rounded, color: _bodyColor);
                  },
                ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                party.nickname ?? '-',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _titleColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  height: 24 / 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _partyMetaText(party),
                style: const TextStyle(
                  color: _mutedColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  height: 16 / 11,
                ),
              ),
            ],
          ),
        ),
        if (party.level != null || canOpenShop) ...[
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (party.level != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Lv.${party.level}',
                    style: const TextStyle(
                      color: Color(0xFF2563EB),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                    ),
                  ),
                ),
              if (canOpenShop) ...[
                if (party.level != null) const SizedBox(height: 10),
                InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: () => _openPartyShop(party, order),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.storefront_outlined,
                          size: 16,
                          color: _brandColor,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _text(zh: '进入店铺', en: 'View Shop'),
                          style: const TextStyle(
                            color: _brandColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            height: 16 / 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildMiniPartyRow(_PartyInfo party) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            party.roleLabel,
            style: const TextStyle(
              color: _bodyColor,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            party.nickname ?? '-',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _titleColor,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSupportAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: SizedBox(
        width: 86,
        child: Column(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(
                    color: Color.fromRGBO(0, 0, 0, 0.05),
                    blurRadius: 2,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              child: Icon(icon, size: 20, color: _brandColor),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _bodyColor,
                fontSize: 12,
                fontWeight: FontWeight.w500,
                height: 16 / 12,
              ),
            ),
          ],
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
    required VoidCallback onTap,
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

  Future<void> _openPendingDeliverPage(
    BuildContext context,
    ShopOrderItem order,
  ) async {
    if (order.id == null) {
      AppSnackbar.error('app.trade.filter.failed'.tr);
      return;
    }

    final steamApi = ApiSteamServer();
    final tradeApi = ApiTradeOfferServer();

    try {
      final steamStatus = await steamApi.steamOnlineState();
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

      final res = await tradeApi.createTradeOffer(params: {'id': order.id});
      if (res.success) {
        AppSnackbar.success(
          'app.trade.deliver.message.steam_trade_url_success'.tr,
        );
        if (Get.isRegistered<ShopOrderController>()) {
          Get.find<ShopOrderController>().refreshPending();
        }
        if (Get.isRegistered<ShopShippingNoticeController>()) {
          Get.find<ShopShippingNoticeController>().refreshPendingTotals();
        }
        if (!context.mounted) {
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
    }
  }

  Future<void> _handleCancelOrder(
    BuildContext context,
    ShopOrderItem order,
  ) async {
    final orderId = order.id?.toString();
    if (orderId == null || orderId.isEmpty) {
      AppSnackbar.error('app.trade.filter.failed'.tr);
      return;
    }

    final messageKey = _isCancelTimeLessThanThirtyMinutes(order)
        ? 'app.trade.order.message.cancel_time_less'
        : 'app.trade.order.message.confirm_cancel';

    await showFigmaModal<void>(
      context: context,
      barrierDismissible: false,
      child: FigmaAsyncConfirmationDialog(
        icon: Icons.cancel_outlined,
        iconColor: const Color(0xFFE11D48),
        iconBackgroundColor: const Color.fromRGBO(225, 29, 72, 0.10),
        accentColor: const Color(0xFFE11D48),
        title: 'app.trade.order.cancel'.tr,
        message: messageKey.tr,
        primaryLabel: _text(zh: '确认取消', en: 'Confirm Cancel'),
        secondaryLabel: 'app.common.cancel'.tr,
        onSecondary: () => popModalRoute(context),
        onConfirm: (dialogContext) async {
          try {
            final controller = Get.isRegistered<ShopOrderController>()
                ? Get.find<ShopOrderController>()
                : Get.put(ShopOrderController());
            final message = await controller.cancelBuyOrder(orderId);
            final successMessage = message.trim().isNotEmpty
                ? message.trim()
                : 'app.system.message.success'.tr;
            if (dialogContext.mounted) {
              popModalRoute(dialogContext);
            }
            if (!context.mounted) {
              return;
            }
            Navigator.of(context).pop(true);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              AppSnackbar.success(successMessage);
            });
          } catch (error) {
            AppSnackbar.error(_resolveActionErrorMessage(error));
          }
        },
      ),
    );
  }

  Future<void> _handleReceiveOrder(
    BuildContext context,
    ShopOrderItem order,
  ) async {
    final orderId = order.id?.toString();
    if (orderId == null || orderId.isEmpty) {
      AppSnackbar.error('app.trade.filter.failed'.tr);
      return;
    }

    await showFigmaModal<void>(
      context: context,
      barrierDismissible: false,
      child: FigmaAsyncConfirmationDialog(
        icon: Icons.inventory_2_outlined,
        iconColor: const Color(0xFF0F766E),
        iconBackgroundColor: const Color.fromRGBO(15, 118, 110, 0.10),
        accentColor: const Color(0xFF0F766E),
        title: 'app.market.product.receive'.tr,
        message: 'app.trade.receipt.message.confirm_auto'.tr,
        primaryLabel: 'app.market.product.receive'.tr,
        secondaryLabel: 'app.common.cancel'.tr,
        onSecondary: () => popModalRoute(context),
        onConfirm: (dialogContext) async {
          try {
            final steamStatus = await ApiSteamServer().steamOnlineState();
            if (steamStatus.datas != true) {
              final tradeOfferId = order.tradeOfferId?.trim() ?? '';
              if (tradeOfferId.isNotEmpty) {
                if (dialogContext.mounted) {
                  popModalRoute(dialogContext);
                }
                Get.toNamed(
                  Routers.RECEIVE_GOODS,
                  arguments: {'tradeOfferId': tradeOfferId},
                );
              } else {
                AppSnackbar.error('app.trade.filter.failed'.tr);
              }
              return;
            }

            final controller = Get.isRegistered<ShopOrderController>()
                ? Get.find<ShopOrderController>()
                : Get.put(ShopOrderController());
            await controller.acceptTradeOffer(orderId);
            await controller.refreshBuyRecords();
            if (dialogContext.mounted) {
              popModalRoute(dialogContext);
            }
            if (!context.mounted) {
              return;
            }
            Navigator.of(context).pop(true);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              AppSnackbar.success('app.system.message.success'.tr);
            });
          } catch (error) {
            AppSnackbar.error(_resolveActionErrorMessage(error));
          }
        },
      ),
    );
  }

  String _resolveActionErrorMessage(Object error) {
    final message = error.toString().replaceFirst(
      RegExp(r'^Exception:\s*'),
      '',
    );
    final trimmed = message.trim();
    return trimmed.isNotEmpty ? trimmed : 'app.trade.filter.failed'.tr;
  }

  List<_StatusRowData> _buildStatusRows(ShopOrderItem order) {
    final rows = <_StatusRowData>[
      _StatusRowData(
        label: '${_text(zh: '订单号', en: 'Order No')}:',
        value: order.id?.toString() ?? '-',
        copyable: order.id != null,
      ),
      _StatusRowData(
        label: '${_text(zh: '创建时间', en: 'Created')}:',
        value: _formatTime(order.createTime),
      ),
    ];
    final completed = _formatTime(order.changeTime);
    final showCompletedTime =
        completed != '-' && !_shouldHideCompletedTime(order.status);
    if (showCompletedTime) {
      rows.add(
        _StatusRowData(
          label: '${_text(zh: '完成时间', en: 'Completed')}:',
          value: completed,
        ),
      );
    } else {
      rows.add(
        _StatusRowData(
          label: '${_text(zh: '订单类型', en: 'Order Type')}:',
          value: _resolveTypeName(order),
        ),
      );
    }
    return rows;
  }

  String _statusHeadline(ShopOrderItem order, {String? statusText}) {
    final listStatusText = statusText?.trim();
    if (listStatusText != null && listStatusText.isNotEmpty) {
      return listStatusText;
    }
    return _buildStatusText(order);
  }

  String _statusDescription(ShopOrderItem order, {required String fallback}) {
    final cancelDesc = order.cancelDesc?.trim();
    if (cancelDesc != null && cancelDesc.isNotEmpty) {
      return cancelDesc;
    }
    final statusName = order.statusName?.trim();
    if (statusName != null && statusName.isNotEmpty) {
      return statusName;
    }
    return fallback;
  }

  bool _canCancelOrder(ShopOrderItem order) {
    if (order.status != 2) {
      return false;
    }
    return order.id != null && _showWaitingCountdown(order);
  }

  bool _isCancelTimeLessThanThirtyMinutes(ShopOrderItem order) {
    final orderTime = order.changeTime ?? order.createTime ?? 0;
    if (orderTime <= 0) {
      return false;
    }
    final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return (nowSeconds - orderTime).abs() <= 1800;
  }

  bool _isUnfinishedTradeStatus(int? status) {
    return status == 2 || status == 3 || status == 4;
  }

  bool _shouldHideCompletedTime(int? status) {
    return _isUnfinishedTradeStatus(status) || status == -1 || status == -2;
  }

  bool _canReceiveOrder(ShopOrderItem order) {
    if (order.status != 4) {
      return false;
    }
    return order.id != null && _showWaitingCountdown(order);
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
    if (!_isUnfinishedTradeStatus(order.status)) {
      return false;
    }
    final deadline = _waitingDeadlineMs(order);
    if (deadline <= 0) {
      return false;
    }
    return deadline > DateTime.now().millisecondsSinceEpoch;
  }

  Color _statusHeadlineColor(ShopOrderItem order) {
    final status = order.status;
    if (status == 6) {
      return const Color(0xFF16A34A);
    }
    if (status == 5) {
      return const Color(0xFF2563EB);
    }
    if (status == 4) {
      return const Color(0xFF059669);
    }
    if (status == 3) {
      return const Color(0xFF2563EB);
    }
    if (status == 2) {
      return const Color(0xFFEA580C);
    }
    if (status == -1 || status == -2) {
      return const Color(0xFFDC2626);
    }
    return kOrderDetailStatusTextNeutral;
  }

  IconData _statusIcon(int? status) {
    if (status == 6) {
      return Icons.check_rounded;
    }
    if (status == 5) {
      return Icons.account_balance_wallet_outlined;
    }
    if (status == 4) {
      return Icons.move_to_inbox_rounded;
    }
    if (status == 3) {
      return Icons.sync_rounded;
    }
    if (status == 2) {
      return Icons.schedule_rounded;
    }
    return Icons.info_outline_rounded;
  }

  double _sumOrderPrice(ShopOrderItem order) {
    if (order.totalPrice != null) {
      return order.totalPrice!;
    }
    if (order.price != null) {
      return order.price!;
    }
    double total = 0;
    for (final detail in order.details) {
      final count = detail.count ?? 1;
      final unit = detail.price ?? 0;
      total += unit * count;
    }
    return total;
  }

  double _sumOrdersPrice(List<ShopOrderItem> orders) {
    double total = 0;
    for (final item in orders) {
      total += _sumOrderPrice(item);
    }
    return total;
  }

  int _countOrderItems(List<ShopOrderItem> orders) {
    int total = 0;
    for (final item in orders) {
      for (final detail in item.details) {
        total += detail.count ?? 1;
      }
    }
    return total;
  }

  int _resolveOrderAppId(ShopOrderItem order) {
    final detail = order.details.isNotEmpty ? order.details.first : null;
    final rawApp = detail?.raw['app_id'] ?? detail?.raw['appId'];
    final orderApp = order.raw['app_id'] ?? order.raw['appId'];
    return _asInt(rawApp) ?? _asInt(orderApp) ?? GameStorage.getGameType();
  }

  void _openPartyShop(_PartyInfo party, ShopOrderItem order) {
    final uuid = party.shopUuid?.trim();
    if (uuid == null || uuid.isEmpty) {
      return;
    }
    Get.toNamed(
      Routers.MARKET_SELLER_SHOP,
      arguments: {
        'uuid': uuid,
        'appId': _resolveOrderAppId(order),
        'shopInfo': {
          'uuid': uuid,
          if ((party.nickname ?? '').isNotEmpty) 'name': party.nickname,
          if ((party.avatar ?? '').isNotEmpty) 'avatar': party.avatar,
        },
      },
    );
  }

  double? _extractFeeAmount(ShopOrderItem order) {
    return _findNumericValue(order.raw, const [
      'service_fee',
      'serviceFee',
      'fee',
      'commission',
      'commission_fee',
      'commissionFee',
      'charge_fee',
      'chargeFee',
      'tax',
    ]);
  }

  double? _extractIncomeAmount({
    required ShopOrderItem order,
    required double totalPrice,
    required double? feeAmount,
  }) {
    final direct = _findNumericValue(order.raw, const [
      'actual_income',
      'actualIncome',
      'income',
      'seller_income',
      'sellerIncome',
      'real_income',
      'realIncome',
      'final_income',
      'finalIncome',
      'receivable',
      'receivable_amount',
      'receivableAmount',
    ]);
    if (direct != null) {
      return direct;
    }
    if (feeAmount != null) {
      return totalPrice - feeAmount;
    }
    return null;
  }

  Future<void> _refreshBuyerInfo({
    required Map<String, ShopUserInfo> users,
    required ShopOrderItem order,
  }) async {
    final buyerId = _resolveBuyerId(order);
    if (buyerId.isEmpty) {
      return;
    }

    final res = await ApiSteamServer().getSteamUserInfo(id: buyerId);
    if (!res.success || res.datas == null) {
      return;
    }

    final data = res.datas!;
    final current = users[buyerId];
    users[buyerId] = ShopUserInfo(
      id: current?.id ?? buyerId,
      uuid: current?.uuid,
      avatar: data['avatar']?.toString() ?? current?.avatar,
      nickname: data['nickname']?.toString() ?? current?.nickname,
      level: _asInt(data['level']) ?? current?.level,
      yearsLevel: _asInt(data['yearsLevel']) ?? current?.yearsLevel,
    );
  }

  _PartyInfo? _resolvePrimaryParty({
    required Map<String, ShopUserInfo> users,
    required ShopOrderItem order,
    required String currentUserId,
  }) {
    final buyer = _resolveBuyerParty(users, order);
    final seller = _resolveSellerParty(users, order);
    if (_isCurrentUserParty(buyer, currentUserId) && seller != null) {
      return seller;
    }
    if (_isCurrentUserParty(seller, currentUserId) && buyer != null) {
      return buyer;
    }
    if (buyer != null) {
      return buyer;
    }
    return seller;
  }

  _PartyInfo? _resolveSecondaryParty({
    required Map<String, ShopUserInfo> users,
    required ShopOrderItem order,
    required _PartyInfo? primary,
    required String currentUserId,
  }) {
    final buyer = _resolveBuyerParty(users, order);
    final seller = _resolveSellerParty(users, order);
    final candidates = [
      if (!_isCurrentUserParty(seller, currentUserId)) seller,
      if (!_isCurrentUserParty(buyer, currentUserId)) buyer,
      seller,
      buyer,
    ];
    for (final item in candidates) {
      if (item == null) {
        continue;
      }
      if (primary == null) {
        return item;
      }
      if (!_isSameParty(primary, item)) {
        return item;
      }
    }
    return null;
  }

  _PartyInfo? _resolveBuyerParty(
    Map<String, ShopUserInfo> users,
    ShopOrderItem order,
  ) {
    return _buildPartyInfo(
      users: users,
      userId: order.raw['buyer'] ?? order.raw['buyer_id'] ?? order.buyerId,
      fallbackUser: null,
      roleLabel: _text(zh: '买家', en: 'Buyer'),
      sectionTitle: _text(zh: '买家信息', en: 'Buyer Info'),
    );
  }

  String _resolveBuyerId(ShopOrderItem order) {
    return (order.raw['buyer'] ?? order.raw['buyer_id'] ?? order.buyerId ?? '')
        .toString()
        .trim();
  }

  _PartyInfo? _resolveSellerParty(
    Map<String, ShopUserInfo> users,
    ShopOrderItem order,
  ) {
    return _buildPartyInfo(
      users: users,
      userId: order.raw['seller'] ?? order.raw['seller_id'],
      fallbackUser: order.user,
      roleLabel: _text(zh: '卖家', en: 'Seller'),
      sectionTitle: _text(zh: '卖家信息', en: 'Seller Info'),
    );
  }

  _PartyInfo? _buildPartyInfo({
    required Map<String, ShopUserInfo> users,
    required dynamic userId,
    required ShopUserInfo? fallbackUser,
    required String roleLabel,
    required String sectionTitle,
  }) {
    final user = _lookupUser(users, userId) ?? fallbackUser;
    final nickname = user?.nickname?.trim();
    final resolvedId = userId?.toString() ?? user?.id ?? user?.uuid;
    if ((nickname == null || nickname.isEmpty) &&
        (resolvedId == null || resolvedId.isEmpty) &&
        user == null) {
      return null;
    }
    return _PartyInfo(
      roleLabel: roleLabel,
      sectionTitle: sectionTitle,
      id: resolvedId,
      nickname: nickname?.isNotEmpty == true ? nickname : roleLabel,
      avatar: user?.avatar,
      shopUuid: user?.uuid,
      level: user?.level,
      yearsLevel: user?.yearsLevel,
    );
  }

  ShopUserInfo? _lookupUser(Map<String, ShopUserInfo> users, dynamic userId) {
    if (userId == null) {
      return null;
    }
    final key = userId.toString();
    if (users.containsKey(key)) {
      return users[key];
    }
    for (final entry in users.entries) {
      if (entry.key == key ||
          entry.value.id == key ||
          entry.value.uuid == key) {
        return entry.value;
      }
    }
    return null;
  }

  String _currentUserId() {
    if (!Get.isRegistered<UserController>()) {
      return '';
    }
    return Get.find<UserController>().user.value?.id?.trim() ?? '';
  }

  bool _isCurrentUserParty(_PartyInfo? party, String currentUserId) {
    if (party == null || currentUserId.isEmpty) {
      return false;
    }
    return (party.id ?? '').trim() == currentUserId;
  }

  bool _isSameParty(_PartyInfo? left, _PartyInfo? right) {
    if (left == null || right == null) {
      return false;
    }
    final sameId =
        (left.id ?? '').isNotEmpty &&
        (right.id ?? '').isNotEmpty &&
        left.id == right.id;
    final sameName =
        (left.nickname ?? '').isNotEmpty && left.nickname == right.nickname;
    return sameId || sameName;
  }

  ShopSchemaInfo? _lookupSchema({
    required Map<String, ShopSchemaInfo> schemas,
    required String? marketHashName,
    required int? schemaId,
  }) {
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
      final value = tags[key];
      if (value is Map<String, dynamic>) {
        return TagInfo.fromRaw(value);
      }
      if (value is Map) {
        return TagInfo.fromRaw(
          value.map((innerKey, innerValue) {
            return MapEntry(innerKey.toString(), innerValue);
          }),
        );
      }
    }
    return null;
  }

  int _resolveDetailAppId(ShopOrderDetail detail, ShopSchemaInfo? schema) {
    final rawApp = detail.raw['app_id'] ?? detail.raw['appId'];
    final schemaApp = schema?.raw['app_id'] ?? schema?.raw['appId'];
    return _asInt(rawApp) ?? _asInt(schemaApp) ?? GameStorage.getGameType();
  }

  List<_OrderStickerDetailData> _resolveDetailStickerDetails({
    required ShopOrderDetail detail,
    required ShopSchemaInfo? schema,
    required int appId,
    required Map<String, dynamic> stickerMap,
  }) {
    for (final candidate in _detailStickerCandidates(detail, schema, appId)) {
      final entries = _normalizeStickerEntries(candidate);
      if (entries.isEmpty) {
        continue;
      }
      final details = entries
          .map((entry) => _resolveStickerDetail(entry, stickerMap))
          .whereType<_OrderStickerDetailData>()
          .toList(growable: false);
      if (details.isNotEmpty) {
        return details;
      }
    }
    return const [];
  }

  List<dynamic> _detailStickerCandidates(
    ShopOrderDetail detail,
    ShopSchemaInfo? schema,
    int appId,
  ) {
    final raw = detail.raw;
    final schemaRaw = schema?.raw;
    final rawAsset = _pickAssetRaw(raw, appId);
    final rawCsgoAsset = _asMap(raw['csgoAsset']);
    final rawTf2Asset = _asMap(raw['tf2Asset']);
    final rawDotaAsset = _asMap(raw['dota2Asset']);
    final schemaAsset = schemaRaw == null
        ? null
        : _pickAssetRaw(schemaRaw, appId);
    final schemaCsgoAsset = _asMap(schemaRaw?['csgoAsset']);
    final schemaTf2Asset = _asMap(schemaRaw?['tf2Asset']);
    final schemaDotaAsset = _asMap(schemaRaw?['dota2Asset']);

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
      rawTf2Asset?['stickers'],
      rawTf2Asset?['stickerList'],
      rawTf2Asset?['sticker_list'],
      rawTf2Asset?['sticker'],
      rawDotaAsset?['stickers'],
      rawDotaAsset?['stickerList'],
      rawDotaAsset?['sticker_list'],
      rawDotaAsset?['sticker'],
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
      schemaTf2Asset?['stickers'],
      schemaTf2Asset?['stickerList'],
      schemaTf2Asset?['sticker_list'],
      schemaTf2Asset?['sticker'],
      schemaDotaAsset?['stickers'],
      schemaDotaAsset?['stickerList'],
      schemaDotaAsset?['sticker_list'],
      schemaDotaAsset?['sticker'],
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
      if (value.startsWith('[') && value.endsWith(']')) {
        try {
          final decoded = jsonDecode(value);
          if (decoded is List) {
            return decoded;
          }
        } catch (_) {}
      }
      if (value.contains(',')) {
        final values = value
            .split(',')
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .toList(growable: false);
        if (values.isNotEmpty) {
          return values;
        }
      }
      return <dynamic>[value];
    }
    return const [];
  }

  _OrderStickerDetailData? _resolveStickerDetail(
    dynamic entry,
    Map<String, dynamic> stickerMap,
  ) {
    String? imageUrl;
    String? name;
    String? stickerId;
    String? slotLabel;
    String? wearText;
    double? price;

    if (entry is Map) {
      imageUrl = _findTextValue(entry, const [
        'image_url',
        'imageUrl',
        'image',
      ]);
      name = _findTextValue(entry, const [
        'market_name',
        'marketName',
        'localized_name',
        'localizedName',
        'name',
      ]);
      price = _findNumericValue(entry, const [
        'market_price',
        'marketPrice',
        'price',
        'reference_price',
        'referencePrice',
        'buff_price',
        'buffPrice',
        'steam_price',
        'steamPrice',
      ]);
      stickerId = _findTextValue(entry, const [
        'sticker_id',
        'stickerId',
        'schema_id',
        'schemaId',
        'id',
      ]);
      slotLabel = _findTextValue(entry, const [
        'slot_name',
        'slotName',
        'position_name',
        'positionName',
        'position',
        'slot',
      ]);
      wearText = _findTextValue(entry, const [
        'wear_text',
        'wearText',
        'sticker_wear_text',
        'stickerWearText',
      ]);
      wearText ??= _formatStickerWear(
        _findNumericValue(entry, const [
          'wear',
          'wear_rate',
          'wearRate',
          'sticker_wear',
          'stickerWear',
          'paint_wear',
          'paintWear',
        ]),
      );
    } else if (entry is num || entry is String) {
      final value = entry.toString().trim();
      if (value.isEmpty) {
        return null;
      }
      if (RegExp(r'^\d+$').hasMatch(value)) {
        stickerId = value;
      } else {
        imageUrl = value;
      }
    }

    final stickerMeta = stickerId == null
        ? null
        : _resolveStickerMeta(stickerId, stickerMap);

    imageUrl ??=
        _findTextValue(stickerMeta, const ['image_url', 'imageUrl', 'image']) ??
        _resolveStickerImage(entry, stickerMap);
    name ??= _findTextValue(stickerMeta, const [
      'market_name',
      'marketName',
      'localized_name',
      'localizedName',
      'name',
    ]);
    price ??= _findNumericValue(stickerMeta, const [
      'market_price',
      'marketPrice',
      'price',
      'reference_price',
      'referencePrice',
      'buff_price',
      'buffPrice',
      'steam_price',
      'steamPrice',
    ]);
    slotLabel ??= _findTextValue(stickerMeta, const [
      'slot_name',
      'slotName',
      'position_name',
      'positionName',
      'position',
      'slot',
    ]);
    wearText ??= _findTextValue(stickerMeta, const [
      'wear_text',
      'wearText',
      'sticker_wear_text',
      'stickerWearText',
    ]);
    wearText ??= _formatStickerWear(
      _findNumericValue(stickerMeta, const [
        'wear',
        'wear_rate',
        'wearRate',
        'sticker_wear',
        'stickerWear',
      ]),
    );

    if (imageUrl == null || imageUrl.isEmpty) {
      return null;
    }

    return _OrderStickerDetailData(
      imageUrl: _normalizeSteamImageUrl(imageUrl),
      name: name,
      slotLabel: slotLabel,
      wearText: wearText,
      price: price,
    );
  }

  String? _resolveStickerImage(dynamic entry, Map<String, dynamic> stickerMap) {
    final parsed = parseStickerList(
      <dynamic>[entry],
      stickerMap: stickerMap,
      schemaMap: stickerMap,
    );
    if (parsed.isNotEmpty) {
      return parsed.first.imageUrl;
    }
    return null;
  }

  Map<String, dynamic>? _resolveStickerMeta(
    String stickerId,
    Map<String, dynamic> stickerMap,
  ) {
    dynamic value;
    if (stickerMap.containsKey(stickerId)) {
      value = stickerMap[stickerId];
    }
    if (value == null) {
      final intKey = int.tryParse(stickerId);
      if (intKey != null && stickerMap.containsKey(intKey.toString())) {
        value = stickerMap[intKey.toString()];
      }
    }
    if (value == null) {
      for (final entry in stickerMap.entries) {
        if (entry.key.toString() == stickerId) {
          value = entry.value;
          break;
        }
      }
    }
    if (value is ShopSchemaInfo) {
      return value.raw;
    }
    return _asMap(value);
  }

  Map<String, dynamic>? _pickAssetRaw(Map<String, dynamic> json, int? appId) {
    if (appId == 730 && json['csgoAsset'] is Map<String, dynamic>) {
      return json['csgoAsset'] as Map<String, dynamic>;
    }
    if (appId == 440 && json['tf2Asset'] is Map<String, dynamic>) {
      return json['tf2Asset'] as Map<String, dynamic>;
    }
    if (appId == 570 && json['dota2Asset'] is Map<String, dynamic>) {
      return json['dota2Asset'] as Map<String, dynamic>;
    }
    if (json['asset'] is Map<String, dynamic>) {
      return json['asset'] as Map<String, dynamic>;
    }
    if (json['asset'] is Map) {
      return Map<String, dynamic>.from(json['asset'] as Map);
    }
    return null;
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

  String _normalizeSteamImageUrl(String url) {
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return url;
    }
    return 'https://community.steamstatic.com/economy/image/$url';
  }

  String? _formatStickerWear(double? wear) {
    if (wear == null) {
      return null;
    }
    return wear.toString();
  }

  String _stickerFallbackName(int index) =>
      _text(zh: '印花 ${index + 1}', en: 'Sticker ${index + 1}');

  String _resolveAvatarUrl(String? avatar) {
    if (avatar == null || avatar.isEmpty) {
      return '';
    }
    if (avatar.startsWith('http')) {
      return avatar;
    }
    return 'https://www.tronskins.com/fms/image$avatar';
  }

  String? _buildWearText(ShopOrderDetail detail, double? paintWear) {
    final direct =
        detail.raw['paint_wear_text'] ??
        detail.raw['paintWearText'] ??
        detail.raw['paint_wear'] ??
        detail.raw['paintWear'];
    final directText = direct?.toString().trim();
    if (directText != null && directText.isNotEmpty) {
      return directText;
    }
    if (paintWear != null) {
      return paintWear.toString();
    }
    return null;
  }

  double? _detailDisplayPrice(ShopOrderDetail detail) {
    return detail.price ??
        _detailDouble(detail, const [
          'price',
          'market_price',
          'marketPrice',
          'sale_price',
          'salePrice',
          'deal_price',
          'dealPrice',
        ]) ??
        detail.totalPrice ??
        _detailDouble(detail, const [
          'total_price',
          'totalPrice',
          'amount',
          'pay_price',
          'payPrice',
        ]);
  }

  double? _detailDouble(ShopOrderDetail detail, List<String> keys) {
    for (final key in keys) {
      final value = detail.raw[key];
      final parsed = _asDouble(value);
      if (parsed != null) {
        return parsed;
      }
    }
    return null;
  }

  String _partyMetaText(_PartyInfo party) {
    final parts = <String>[];
    if (party.level != null) {
      parts.add('Lv.${party.level}');
    }
    if (party.yearsLevel != null) {
      parts.add(
        _text(
          zh: 'Steam 年限 ${party.yearsLevel}',
          en: 'Steam ${party.yearsLevel}y',
        ),
      );
    }
    return parts.isEmpty ? party.roleLabel : parts.join(' · ');
  }

  String _buildStatusText(ShopOrderItem order) {
    final status = order.status;
    if (status == 6) {
      return _text(zh: '交易成功', en: 'Completed');
    }
    if (status == 5) {
      return _text(zh: '结算中', en: 'Settling');
    }
    final cancelDesc = order.cancelDesc?.trim();
    final statusName = order.statusName?.trim();
    if (status == -1 || status == -2) {
      if (cancelDesc != null && cancelDesc.isNotEmpty) {
        return cancelDesc;
      }
      if (statusName != null && statusName.isNotEmpty) {
        return statusName;
      }
      return _text(zh: '订单已关闭', en: 'Order Closed');
    }
    if (statusName != null && statusName.isNotEmpty) {
      return statusName;
    }
    if (cancelDesc != null && cancelDesc.isNotEmpty) {
      return cancelDesc;
    }
    if (status == 2) {
      return 'app.market.product.wait_for_sending'.tr;
    }
    if (status == 3) {
      return 'app.trade.filter.in'.tr;
    }
    if (status == 4) {
      return 'app.market.product.wait_for_receipt'.tr;
    }
    return _text(zh: '处理中', en: 'Processing');
  }

  String _resolveTypeName(ShopOrderItem order) {
    final typeName =
        order.raw['typeName']?.toString() ??
        order.raw['type_name']?.toString() ??
        order.raw['typeNameText']?.toString() ??
        order.raw['type_name_text']?.toString();
    if (typeName != null && typeName.isNotEmpty) {
      return typeName;
    }
    return order.type?.toString() ?? '-';
  }

  String _formatPrice(CurrencyController? currency, double value) {
    if (currency != null) {
      return currency.format(value);
    }
    return '¥${value.toStringAsFixed(2)}';
  }

  String _formatTime(int? timestamp) {
    if (timestamp == null) {
      return '-';
    }
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    return DateFormat('yyyy-MM-dd HH:mm').format(date);
  }

  List<String> _tipItems() {
    if (isPendingFlow) {
      return [
        'app.trade.order.seller_tips_1'.tr,
        'app.trade.order.seller_tips_2'.tr,
        'app.trade.order.seller_tips_3'.tr,
      ].where((item) => item.trim().isNotEmpty).toList();
    }
    return [
      'app.trade.order.buyer_tips_1'.tr,
      'app.trade.order.buyer_tips_2'.tr,
      'app.trade.order.buyer_tips_3'.tr,
      'app.trade.order.buyer_tips_4'.tr,
    ].where((item) => item.trim().isNotEmpty).toList();
  }

  Future<void> _copyOrderId(BuildContext context, String orderId) async {
    await Clipboard.setData(ClipboardData(text: orderId));
    if (!context.mounted) {
      return;
    }
    await showCopySuccessNoticeDialog(context);
  }

  String _text({required String zh, required String en}) {
    final locale = Get.locale ?? Get.deviceLocale;
    if ((locale?.languageCode ?? '').toLowerCase().startsWith('zh')) {
      return zh;
    }
    return en;
  }

  String? _findTextValue(dynamic data, List<String> keys) {
    final value = _findValue(
      data,
      keys.map((item) => item.toLowerCase()).toSet(),
    );
    return value?.toString();
  }

  double? _findNumericValue(dynamic data, List<String> keys) {
    final value = _findValue(
      data,
      keys.map((item) => item.toLowerCase()).toSet(),
    );
    return _asDouble(value);
  }

  dynamic _findValue(
    dynamic data,
    Set<String> normalizedKeys, [
    int depth = 0,
  ]) {
    if (depth > 3 || data == null) {
      return null;
    }
    if (data is Map) {
      for (final entry in data.entries) {
        final key = entry.key.toString().toLowerCase();
        if (normalizedKeys.contains(key) && entry.value != null) {
          return entry.value;
        }
      }
      for (final entry in data.entries) {
        final result = _findValue(entry.value, normalizedKeys, depth + 1);
        if (result != null) {
          return result;
        }
      }
    }
    if (data is List) {
      for (final item in data) {
        final result = _findValue(item, normalizedKeys, depth + 1);
        if (result != null) {
          return result;
        }
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

  double? _asDouble(dynamic value) {
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
}

class _ShopOrderDetailArgs {
  const _ShopOrderDetailArgs({
    this.order,
    this.statusText,
    this.orders = const [],
    this.schemas = const {},
    this.users = const {},
    this.stickers = const {},
    this.disableOrderActions = false,
    this.fromDeliveryGoodsDrawer = false,
  });

  final ShopOrderItem? order;
  final String? statusText;
  final List<ShopOrderItem> orders;
  final Map<String, ShopSchemaInfo> schemas;
  final Map<String, ShopUserInfo> users;
  final Map<String, dynamic> stickers;
  final bool disableOrderActions;
  final bool fromDeliveryGoodsDrawer;

  factory _ShopOrderDetailArgs.fromDynamic(dynamic raw) {
    if (raw is! Map) {
      return const _ShopOrderDetailArgs();
    }
    final order = _parseOrder(raw['order'] ?? raw['item']);
    return _ShopOrderDetailArgs(
      order: order,
      statusText: _parseText(raw['statusText'] ?? raw['statusName']),
      orders: _parseOrders(raw['orders']),
      schemas: _parseSchemas(raw['schemas']),
      users: _parseUsers(raw['users']),
      stickers: _parseStickers(raw['stickers']),
      disableOrderActions: _parseBool(raw['disableOrderActions']),
      fromDeliveryGoodsDrawer: _parseBool(raw['fromDeliveryGoodsDrawer']),
    );
  }

  static String? _parseText(dynamic value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  static bool _parseBool(dynamic value) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    final text = value?.toString().trim().toLowerCase();
    return text == 'true' || text == '1';
  }

  static ShopOrderItem? _parseOrder(dynamic value) {
    if (value is ShopOrderItem) {
      return value;
    }
    if (value is Map<String, dynamic>) {
      return ShopOrderItem.fromJson(value);
    }
    if (value is Map) {
      return ShopOrderItem.fromJson(
        value.map((key, val) {
          return MapEntry(key.toString(), val);
        }),
      );
    }
    return null;
  }

  static List<ShopOrderItem> _parseOrders(dynamic value) {
    if (value is! List) {
      return const <ShopOrderItem>[];
    }
    final result = <ShopOrderItem>[];
    for (final item in value) {
      final parsed = _parseOrder(item);
      if (parsed != null) {
        result.add(parsed);
      }
    }
    return result;
  }

  static Map<String, ShopSchemaInfo> _parseSchemas(dynamic value) {
    final result = <String, ShopSchemaInfo>{};
    if (value is! Map) {
      return result;
    }
    value.forEach((key, val) {
      if (val is ShopSchemaInfo) {
        result[key.toString()] = val;
      } else if (val is Map<String, dynamic>) {
        result[key.toString()] = ShopSchemaInfo.fromJson(val);
      } else if (val is Map) {
        result[key.toString()] = ShopSchemaInfo.fromJson(
          val.map((innerKey, innerValue) {
            return MapEntry(innerKey.toString(), innerValue);
          }),
        );
      }
    });
    return result;
  }

  static Map<String, ShopUserInfo> _parseUsers(dynamic value) {
    final result = <String, ShopUserInfo>{};
    if (value is! Map) {
      return result;
    }
    value.forEach((key, val) {
      if (val is ShopUserInfo) {
        result[key.toString()] = val;
      } else if (val is Map<String, dynamic>) {
        result[key.toString()] = ShopUserInfo.fromJson(val);
      } else if (val is Map) {
        result[key.toString()] = ShopUserInfo.fromJson(
          val.map((innerKey, innerValue) {
            return MapEntry(innerKey.toString(), innerValue);
          }),
        );
      }
    });
    return result;
  }

  static Map<String, dynamic> _parseStickers(dynamic value) {
    final result = <String, dynamic>{};
    if (value is! Map) {
      return result;
    }
    value.forEach((key, val) {
      result[key.toString()] = val;
    });
    return result;
  }
}

class _StatusRowData {
  const _StatusRowData({
    required this.label,
    required this.value,
    this.copyable = false,
  });

  final String label;
  final String value;
  final bool copyable;
}

class _PartyInfo {
  const _PartyInfo({
    required this.roleLabel,
    required this.sectionTitle,
    this.id,
    this.nickname,
    this.avatar,
    this.shopUuid,
    this.level,
    this.yearsLevel,
  });

  final String roleLabel;
  final String sectionTitle;
  final String? id;
  final String? nickname;
  final String? avatar;
  final String? shopUuid;
  final int? level;
  final int? yearsLevel;
}

class _OrderStickerDetailData {
  const _OrderStickerDetailData({
    required this.imageUrl,
    this.name,
    this.slotLabel,
    this.wearText,
    this.price,
  });

  final String imageUrl;
  final String? name;
  final String? slotLabel;
  final String? wearText;
  final double? price;
}
