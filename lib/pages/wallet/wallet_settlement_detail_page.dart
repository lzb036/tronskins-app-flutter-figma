import 'package:flutter/material.dart';
import 'dart:ui';

import 'package:tronskins_app/common/widgets/settings_style_app_bar.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:tronskins_app/api/model/wallet/wallet_models.dart';
import 'package:tronskins_app/common/hooks/currency/CurrencyController.dart';
import 'package:tronskins_app/common/storage/game_storage.dart';
import 'package:tronskins_app/common/theme/order_detail_status_style.dart';
import 'package:tronskins_app/common/widgets/back_to_top_overlay.dart';
import 'package:tronskins_app/common/widgets/glass_notice_dialog.dart';
import 'package:tronskins_app/components/game_item/game_item_models.dart';
import 'package:tronskins_app/l10n/inline_i18n.dart';
import 'package:tronskins_app/pages/wallet/widgets/wallet_order_asset_card.dart';
import 'package:tronskins_app/routes/app_routes.dart';

class WalletSettlementDetailPage extends StatelessWidget {
  static const _pageBg = Color(0xFFF7F9FB);
  static const _cardBg = Colors.white;
  static const _titleColor = Color(0xFF191C1E);
  static const _mutedColor = Color(0xFF757684);
  static const _bodyColor = Color(0xFF444653);

  const WalletSettlementDetailPage({
    super.key,
    required this.record,
    required this.schemas,
    required this.users,
    required this.stickers,
  });

  final WalletSettlementRecord record;
  final Map<String, WalletSchemaInfo> schemas;
  final Map<String, dynamic> users;
  final Map<String, dynamic> stickers;

  @override
  Widget build(BuildContext context) {
    final currency = Get.isRegistered<CurrencyController>()
        ? Get.find<CurrencyController>()
        : null;
    final topInset = MediaQuery.of(context).padding.top;
    final bottomInset = MediaQuery.of(context).padding.bottom;

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
                        _buildStatusCard(context, currency),
                        const SizedBox(height: 16),
                        _buildOrderStatusCard(),
                        const SizedBox(height: 16),
                        _buildProductCard(currency: currency),
                        const SizedBox(height: 16),
                        _buildPriceCard(currency: currency),
                        const SizedBox(height: 16),
                        _buildTipsCard(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            _buildTopNavigation(context),
            _buildBottomActionBar(bottomInset),
          ],
        ),
      ),
    );
  }

  String _text({required String zh, required String en}) {
    return InlineI18n.text(zh: zh, en: en);
  }

  String _pageTitle() {
    return _text(zh: '订单明细', en: 'Order Details');
  }

  Widget _buildTopNavigation(BuildContext context) {
    return SettingsStyleTopNavigation(
      title: _pageTitle(),
      onBack: () => Navigator.of(context).maybePop(),
    );
  }

  Widget _buildStatusCard(BuildContext context, CurrencyController? currency) {
    final statusStyle = _statusStyle();
    final orderId = record.id?.trim() ?? '-';
    final createdTime = _formatTimestamp(_resolveCreatedTime());
    final releaseTime = _formatTimestamp(_resolveReleaseTime());
    final buyerName = _resolveUserName(
      _pickRawValue(record.raw, const ['buyer', 'buyer_id']),
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: kOrderDetailStatusCardGradientColors,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: kOrderDetailStatusCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Icon(statusStyle.icon, color: Colors.white, size: 24),
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
                        _statusHeadline(),
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
          const SizedBox(height: 18),
          Text(
            'app.user.wallet.unsettled_tips'.tr,
            style: const TextStyle(
              color: Color.fromRGBO(255, 255, 255, 0.92),
              fontSize: 14,
              fontWeight: FontWeight.w400,
              height: 22 / 14,
            ),
          ),
          const SizedBox(height: 20),
          _buildGlassStatusRow(
            label: '${_text(zh: '订单号', en: 'Order No')}:',
            value: orderId,
            onCopy: orderId == '-' ? null : () => _copy(context, orderId),
          ),
          if (createdTime != '-') ...[
            const SizedBox(height: 8),
            _buildGlassStatusRow(
              label: '${_text(zh: '创建时间', en: 'Created')}:',
              value: createdTime,
            ),
          ],
          if (releaseTime != '-') ...[
            const SizedBox(height: 8),
            _buildGlassStatusRow(
              label: '${_text(zh: '预计到账', en: 'Release')}:',
              value: releaseTime,
            ),
          ],
          if (buyerName != null && buyerName.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildGlassStatusRow(
              label: '${_text(zh: '买家', en: 'Buyer')}:',
              value: buyerName,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOrderStatusCard() {
    final statusStyle = _statusStyle();
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
                  Icon(
                    statusStyle.icon,
                    color: statusStyle.headlineColor,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      _statusText(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: statusStyle.headlineColor,
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

  Widget _buildProductCard({required CurrencyController? currency}) {
    final title = record.details.length > 1
        ? '${_text(zh: '商品信息', en: 'Product Info')} (${_totalItemCount()})'
        : _text(zh: '商品信息', en: 'Product Info');
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(title),
          const SizedBox(height: 16),
          if (record.details.isEmpty)
            _buildEmptyBlock()
          else
            ...List.generate(record.details.length, (index) {
              final detail = record.details[index];
              return Column(
                children: [
                  _buildDetailItem(detail: detail, currency: currency),
                  if (index != record.details.length - 1) ...[
                    const SizedBox(height: 16),
                    const Divider(height: 1, color: Color(0xFFECEEF0)),
                    const SizedBox(height: 16),
                  ],
                ],
              );
            }),
        ],
      ),
    );
  }

  Widget _buildDetailItem({
    required WalletSettlementDetail detail,
    required CurrencyController? currency,
  }) {
    final schema = _lookupSchema(detail);
    final title = _resolveTitle(detail, schema);
    final subtitle = _resolveSubtitle(detail, schema, title);
    final imageUrl = _resolveImageUrl(detail, schema);
    final rarity = _schemaTag(schema, 'rarity');
    final quality = _schemaTag(schema, 'quality');
    final exterior = _schemaTag(schema, 'exterior');
    final phase =
        _pickRawText(detail.raw, const ['phase']) ??
        _pickRawText(schema?.raw, const ['phase']);
    final percentage =
        _pickRawText(detail.raw, const ['percentage']) ??
        _pickRawText(schema?.raw, const ['percentage']);
    final appId = _resolveDetailAppId(detail, schema);
    final count = _detailCount(detail);
    final listedAmount = _resolveDetailListedAmount(detail);
    final wearText = _paintWearText(detail);
    final wearValue = _paintWearValue(detail);

    return WalletOrderAssetCard(
      title: title,
      subtitle: subtitle,
      imageUrl: imageUrl,
      appId: appId,
      priceText: _formatPrice(currency, listedAmount),
      count: count,
      raw: detail.raw,
      schemaRaw: schema?.raw ?? const {},
      stickerMap: stickers,
      rarity: rarity,
      quality: quality,
      exterior: exterior,
      phase: phase,
      percentage: percentage,
      paintWear: wearValue,
      wearText: wearText,
    );
  }

  Widget _buildPriceCard({required CurrencyController? currency}) {
    final listedAmount = _resolveRecordListedAmount();
    final receivedAmount = _resolveRecordReceivedAmount();
    final feeAmount = _resolveRecordFeeAmount(
      listedAmount: listedAmount,
      receivedAmount: receivedAmount,
    );
    final pointsAmount = _resolveRecordPointsAmount();

    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(_text(zh: '结算明细', en: 'Settlement Breakdown')),
          const SizedBox(height: 16),
          _buildPriceRow(
            _text(zh: '件数', en: 'Items'),
            _totalItemCount().toString(),
          ),
          const SizedBox(height: 12),
          _buildPriceRow(
            _text(zh: '成交金额', en: 'Sale Price'),
            _formatPrice(currency, listedAmount),
          ),
          if (feeAmount != null) ...[
            const SizedBox(height: 12),
            _buildPriceRow(
              _text(zh: '服务费', en: 'Service Fee'),
              '-${_formatPrice(currency, feeAmount)}',
              valueColor: const Color(0xFFBA1A1A),
            ),
          ],
          if (_hasPoints(pointsAmount)) ...[
            const SizedBox(height: 12),
            _buildPriceRow(
              _text(zh: '积分', en: 'Points'),
              _formatPointsText(pointsAmount!),
            ),
          ],
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFECEEF0)),
          const SizedBox(height: 12),
          _buildPriceRow(
            _text(zh: '实际到账', en: 'Actual Income'),
            _formatPrice(currency, receivedAmount),
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
      ),
    );
  }

  Widget _buildTipsCard() {
    final tips = [
      'app.user.wallet.unsettled_tips'.tr,
      _text(
        zh: '若预计到账时间后仍未到账，可通过底部入口联系平台客服。',
        en: 'If the income is not credited after the release time, contact support from the bottom action.',
      ),
    ].where((item) => item.trim().isNotEmpty).toList();

    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(_text(zh: '温馨提示', en: 'Warm Tips')),
          const SizedBox(height: 14),
          ...tips.map(
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

  Widget _buildBottomActionBar(double bottomInset) {
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
                    icon: Icons.support_agent_rounded,
                    label: _text(zh: '联系客服', en: 'Contact'),
                    foreground: Colors.white,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF1D4ED8), Color(0xFF3B82F6)],
                    ),
                    onTap: () => Get.toNamed(Routers.FEEDBACK_LIST),
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

  Widget _buildGlassStatusRow({
    required String label,
    required String value,
    VoidCallback? onCopy,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
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

  WalletSchemaInfo? _lookupSchema(WalletSettlementDetail detail) {
    final hash = detail.marketHashName ?? '';
    if (hash.isNotEmpty && schemas.containsKey(hash)) {
      return schemas[hash];
    }
    final schemaIdKey = detail.schemaId?.toString();
    if (schemaIdKey != null && schemas.containsKey(schemaIdKey)) {
      return schemas[schemaIdKey];
    }
    return null;
  }

  TagInfo? _schemaTag(WalletSchemaInfo? schema, String key) {
    final tags = schema?.raw['tags'];
    if (tags is Map) {
      return TagInfo.fromRaw(tags[key]);
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

  int? _pickRawInt(dynamic source, List<String> keys) {
    return _asInt(_pickRawValue(source, keys));
  }

  double? _pickRawDouble(dynamic source, List<String> keys) {
    return _asDouble(_pickRawValue(source, keys));
  }

  double? _sumDetailNumericValues(
    double? Function(WalletSettlementDetail detail) mapper,
  ) {
    var hasValue = false;
    double total = 0;
    for (final detail in record.details) {
      final value = mapper(detail);
      if (value == null) {
        continue;
      }
      hasValue = true;
      total += value * _detailCount(detail);
    }
    return hasValue ? total : null;
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

  int _resolveDetailAppId(
    WalletSettlementDetail detail,
    WalletSchemaInfo? schema,
  ) {
    return detail.appId ??
        schema?.appId ??
        _pickRawInt(detail.raw, const ['app_id', 'appId']) ??
        _pickRawInt(schema?.raw, const ['app_id', 'appId']) ??
        GameStorage.getGameType();
  }

  _SettlementDetailStatusStyle _statusStyle() {
    final text = _statusText().toLowerCase();
    final status = record.status;

    final isPending =
        status == 5 ||
        text.contains('settlement') ||
        text.contains('pending') ||
        text.contains('待结算') ||
        text.contains('结算');
    if (isPending) {
      return const _SettlementDetailStatusStyle(
        headlineColor: kOrderDetailStatusTextSettlement,
        icon: Icons.schedule_rounded,
      );
    }

    final isCompleted =
        status == 4 ||
        status == 6 ||
        text.contains('complete') ||
        text.contains('success') ||
        text.contains('完成');
    if (isCompleted) {
      return const _SettlementDetailStatusStyle(
        headlineColor: kOrderDetailStatusTextSuccess,
        icon: Icons.check_circle_outline_rounded,
      );
    }

    final isCancelled =
        status == 2 ||
        status == 3 ||
        text.contains('cancel') ||
        text.contains('close') ||
        text.contains('取消');
    if (isCancelled) {
      return const _SettlementDetailStatusStyle(
        headlineColor: kOrderDetailStatusTextDanger,
        icon: Icons.cancel_outlined,
      );
    }

    return const _SettlementDetailStatusStyle(
      headlineColor: kOrderDetailStatusTextProcessing,
      icon: Icons.info_outline_rounded,
    );
  }

  String _statusHeadline() {
    return _statusText();
  }

  String _statusText() {
    final statusName = _pickRawText(record.raw, const [
      'statusName',
      'status_name',
      'statusText',
      'status_text',
    ]);
    if (statusName != null && statusName.isNotEmpty) {
      return statusName;
    }

    switch (record.status) {
      case 4:
      case 6:
        return _text(zh: '已完成', en: 'Completed');
      case 5:
        return _text(zh: '待结算', en: 'Pending Settlement');
      case 2:
      case 3:
        return _text(zh: '已取消', en: 'Cancelled');
      default:
        return _text(zh: '处理中', en: 'Processing');
    }
  }

  String _resolveImageUrl(
    WalletSettlementDetail detail,
    WalletSchemaInfo? schema,
  ) {
    return detail.imageUrl ??
        schema?.imageUrl ??
        _pickRawText(detail.raw, const ['image_url', 'imageUrl', 'image']) ??
        _pickRawText(schema?.raw, const ['image_url', 'imageUrl', 'image']) ??
        '';
  }

  String _resolveTitle(
    WalletSettlementDetail detail,
    WalletSchemaInfo? schema,
  ) {
    return detail.marketName ??
        schema?.marketName ??
        detail.marketHashName ??
        '-';
  }

  String? _resolveSubtitle(
    WalletSettlementDetail detail,
    WalletSchemaInfo? schema,
    String title,
  ) {
    final subtitle = detail.marketHashName ?? schema?.marketHashName;
    if (subtitle == null || subtitle.isEmpty || subtitle == title) {
      return null;
    }
    return subtitle;
  }

  String? _resolveUserName(dynamic userId) {
    if (userId == null) {
      return null;
    }
    final key = userId.toString();
    final direct = _extractUserName(users[key]);
    if (direct != null && direct.isNotEmpty) {
      return direct;
    }
    for (final entry in users.entries) {
      if (entry.key.toString() == key) {
        final nickname = _extractUserName(entry.value);
        if (nickname != null && nickname.isNotEmpty) {
          return nickname;
        }
      }
    }
    return null;
  }

  String? _extractUserName(dynamic value) {
    if (value is String) {
      final text = value.trim();
      return text.isEmpty ? null : text;
    }
    if (value is Map) {
      final nickname =
          value['nickname'] ??
          value['nickName'] ??
          value['name'] ??
          value['userName'] ??
          value['username'];
      if (nickname == null) {
        return null;
      }
      final text = nickname.toString().trim();
      return text.isEmpty ? null : text;
    }
    return null;
  }

  String _formatTimestamp(int? timestamp) {
    if (timestamp == null || timestamp <= 0) {
      return '-';
    }
    var normalized = timestamp;
    if (normalized < 10000000000) {
      normalized *= 1000;
    }
    return DateFormat(
      'yyyy-MM-dd HH:mm',
    ).format(DateTime.fromMillisecondsSinceEpoch(normalized).toLocal());
  }

  String? _paintWearText(WalletSettlementDetail detail) {
    return _pickRawText(detail.raw, const ['paint_wear', 'paintWear']) ??
        detail.paintWear?.toString();
  }

  double? _paintWearValue(WalletSettlementDetail detail) {
    return detail.paintWear ??
        _pickRawDouble(detail.raw, const ['paint_wear', 'paintWear']);
  }

  int _detailCount(WalletSettlementDetail detail) {
    final count =
        _pickRawInt(detail.raw, const ['count', 'num', 'quantity']) ?? 1;
    return count < 1 ? 1 : count;
  }

  int? _resolveCreatedTime() {
    return _pickRawInt(record.raw, const [
      'createTime',
      'create_time',
      'createdAt',
      'created_at',
      'time',
    ]);
  }

  int? _resolveReleaseTime() {
    return record.protectionTime ??
        _pickRawInt(record.raw, const [
          'protectionTime',
          'protection_time',
          'releaseTime',
          'release_time',
          'settlementTime',
          'settlement_time',
        ]);
  }

  double _resolveRecordListedAmount() {
    final direct = _pickRawDouble(record.raw, const [
      'total_price',
      'totalPrice',
      'price',
      'sale_price',
      'salePrice',
      'list_price',
      'listPrice',
    ]);
    if (direct != null) {
      return direct;
    }
    final total = _sumDetailAmounts(_resolveDetailListedAmount);
    if (total > 0) {
      return total;
    }
    return record.price ?? 0;
  }

  double _resolveRecordReceivedAmount() {
    final direct = _pickRawDouble(record.raw, const [
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
      'received_price',
      'receivedPrice',
      'settlement_amount',
      'settlementAmount',
    ]);
    if (direct != null) {
      return direct;
    }

    final listed = _resolveRecordListedAmount();
    final fee = _pickRawDouble(record.raw, const [
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
    if (fee != null) {
      return listed - fee;
    }

    final detailTotal = _sumDetailAmounts(_resolveDetailReceivedAmount);
    if (detailTotal > 0) {
      return detailTotal;
    }

    return listed;
  }

  double? _resolveRecordPointsAmount() {
    const keys = [
      'score',
      'points',
      'point',
      'integral',
      'reward_points',
      'rewardPoints',
      'reward_score',
      'rewardScore',
      'integral_amount',
      'integralAmount',
    ];
    final direct = _pickRawDouble(record.raw, keys);
    if (direct != null) {
      return direct;
    }
    return _sumDetailNumericValues(
      (detail) => _pickRawDouble(detail.raw, keys),
    );
  }

  double? _resolveRecordFeeAmount({
    required double listedAmount,
    required double receivedAmount,
  }) {
    final direct = _pickRawDouble(record.raw, const [
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
    if (direct != null && direct != 0) {
      return direct.abs();
    }

    final diff = listedAmount - receivedAmount;
    if (diff > 0.0001) {
      return diff;
    }
    return null;
  }

  double _sumDetailAmounts(double Function(WalletSettlementDetail) mapper) {
    double total = 0;
    for (final detail in record.details) {
      total += mapper(detail);
    }
    return total;
  }

  int _totalItemCount() {
    var total = 0;
    for (final detail in record.details) {
      total += _detailCount(detail);
    }
    return total < 1 ? 1 : total;
  }

  double _resolveDetailListedAmount(WalletSettlementDetail detail) {
    final count = _detailCount(detail);
    return _pickRawDouble(detail.raw, const [
          'total_price',
          'totalPrice',
          'price',
          'sale_price',
          'salePrice',
          'list_price',
          'listPrice',
        ]) ??
        ((detail.price ?? 0) * count);
  }

  double _resolveDetailReceivedAmount(WalletSettlementDetail detail) {
    final direct = _pickRawDouble(detail.raw, const [
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
      'received_price',
      'receivedPrice',
      'settlement_amount',
      'settlementAmount',
    ]);
    if (direct != null) {
      return direct;
    }

    final listed = _resolveDetailListedAmount(detail);
    final fee = _pickRawDouble(detail.raw, const [
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
    if (fee != null) {
      return listed - fee;
    }

    return listed;
  }

  String _formatPrice(CurrencyController? currency, double value) {
    if (currency != null) {
      return currency.formatUsd(value);
    }
    return '\$ ${value.toStringAsFixed(2)}';
  }

  bool _hasPoints(double? value) {
    return value != null && value.abs() > 0.0001;
  }

  String _formatPointsText(double value) {
    var text = value.toStringAsFixed(value == value.roundToDouble() ? 0 : 2);
    if (text.contains('.')) {
      text = text.replaceFirst(RegExp(r'\.?0+$'), '');
    }
    return '$text ${_text(zh: '积分', en: 'Points')}';
  }

  Future<void> _copy(BuildContext context, String text) async {
    if (text.isEmpty) {
      return;
    }
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) {
      return;
    }
    await showCopySuccessNoticeDialog(context);
  }
}

class _SettlementDetailStatusStyle {
  const _SettlementDetailStatusStyle({
    required this.headlineColor,
    required this.icon,
  });

  final Color headlineColor;
  final IconData icon;
}
