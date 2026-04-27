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
import 'package:tronskins_app/components/game_item/game_item_image.dart';
import 'package:tronskins_app/components/game_item/game_item_models.dart';
import 'package:tronskins_app/components/game_item/sticker_row.dart';
import 'package:tronskins_app/components/game_item/wear_progress_bar.dart';
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
                  bottomInset + 120,
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
                        if (record.details.isEmpty)
                          _buildEmptyCard()
                        else
                          ...record.details.map(
                            (detail) => Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: _buildDetailCard(
                                detail: detail,
                                currency: currency,
                              ),
                            ),
                          ),
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

  bool get _isChineseLocale =>
      (Get.locale?.languageCode ?? '').toLowerCase().startsWith('zh');

  String _text({required String zh, required String en}) {
    return _isChineseLocale ? zh : en;
  }

  String _pageTitle() {
    return _text(zh: '订单详情', en: 'Order Details');
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
                child: Text(
                  _statusHeadline(),
                  style: TextStyle(
                    color: statusStyle.headlineColor,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    height: 32 / 24,
                    letterSpacing: -0.5,
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
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildGlassMetricChip(
                label: _text(zh: '售价', en: 'Price'),
                value: _formatPrice(currency, _resolveRecordListedAmount()),
              ),
              _buildGlassMetricChip(
                label: _text(zh: '到账金额', en: 'Received'),
                value: _formatPrice(currency, _resolveRecordReceivedAmount()),
              ),
              _buildGlassMetricChip(
                label: _text(zh: '件数', en: 'Items'),
                value: _totalItemCount().toString(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCard() {
    return _buildCard(
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
    );
  }

  Widget _buildDetailCard({
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
    final receivedAmount = _resolveDetailReceivedAmount(detail);
    final wearText = _paintWearText(detail);
    final wearValue = _paintWearValue(detail);
    final detailStickers = _detailStickers(detail);
    final qualityLabel = quality?.label ?? rarity?.label;

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
                    count: count > 1 ? count : null,
                  ),
                ),
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
                      style: const TextStyle(
                        color: _titleColor,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        height: 28 / 20,
                      ),
                    ),
                    if (subtitle != null &&
                        subtitle.isNotEmpty &&
                        subtitle != title) ...[
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
                        if (qualityLabel != null && qualityLabel.isNotEmpty)
                          _buildInfoChip(
                            label: qualityLabel,
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
                        if (count > 1)
                          _buildInfoChip(
                            label: 'x$count',
                            background: const Color(0xFFF8FAFC),
                            foreground: const Color(0xFF475569),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _buildDetailValueRow(
            label: _text(zh: '售价', en: 'Price'),
            value: _formatPrice(currency, listedAmount),
          ),
          const SizedBox(height: 8),
          _buildDetailValueRow(
            label: _text(zh: '到账金额', en: 'Received Price'),
            value: _formatPrice(currency, receivedAmount),
          ),
          const SizedBox(height: 8),
          _buildStatusValueRow(
            label: _text(zh: '状态', en: 'State'),
            value: _statusText(),
          ),
          if (wearText != null && wearText.isNotEmpty) ...[
            const SizedBox(height: 22),
            _buildWearValueRow(
              label: _text(zh: '磨损度', en: 'Wear'),
              value: wearText,
            ),
          ],
          if (wearValue != null) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: WearProgressBar(
                paintWear: wearValue,
                height: 18,
                style: WearProgressBarStyle.figmaCompact,
              ),
            ),
          ],
          if (detailStickers.isNotEmpty) ...[
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
            StickerRow(stickers: detailStickers, size: 28),
          ],
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

  Widget _buildGlassMetricChip({required String label, required String value}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color.fromRGBO(255, 255, 255, 0.78),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              height: 16 / 11,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              height: 20 / 15,
            ),
          ),
        ],
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
          width: 112,
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
                child: Text(
                  value,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: Color.fromRGBO(255, 255, 255, 0.94),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    height: 20 / 14,
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

  Widget _buildStatusValueRow({required String label, required String value}) {
    final style = _statusStyle();
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
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: style.badgeBackground,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            value,
            style: TextStyle(
              color: style.badgeForeground,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              height: 16 / 11,
            ),
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
        badgeBackground: Color(0xFFEFF6FF),
        badgeForeground: Color(0xFF2563EB),
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
        badgeBackground: Color(0xFFF0FDF4),
        badgeForeground: Color(0xFF16A34A),
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
        badgeBackground: Color(0xFFF1F5F9),
        badgeForeground: Color(0xFF64748B),
        icon: Icons.cancel_outlined,
      );
    }

    return const _SettlementDetailStatusStyle(
      headlineColor: kOrderDetailStatusTextProcessing,
      badgeBackground: Color(0xFFF1F5F9),
      badgeForeground: Color(0xFF64748B),
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

  List<GameItemSticker> _detailStickers(WalletSettlementDetail detail) {
    final rawAsset = _pickRawMap(_pickRawValue(detail.raw, const ['asset']));
    final rawCsgoAsset = _pickRawMap(
      _pickRawValue(detail.raw, const ['csgoAsset']),
    );
    final stickerRaw =
        _pickRawValue(detail.raw, const ['stickers']) ??
        _pickRawValue(rawAsset, const ['stickers']) ??
        _pickRawValue(rawCsgoAsset, const ['stickers']);
    return parseStickerList(
      stickerRaw,
      schemaMap: schemas,
      stickerMap: stickers,
    );
  }

  int _detailCount(WalletSettlementDetail detail) {
    final count =
        _pickRawInt(detail.raw, const ['count', 'num', 'quantity']) ?? 1;
    return count < 1 ? 1 : count;
  }

  Map? _pickRawMap(dynamic value) {
    if (value is Map) {
      return value;
    }
    return null;
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

    if (record.details.length == 1) {
      final recordLevel = _resolveRecordReceivedAmount();
      if (recordLevel > 0) {
        return recordLevel;
      }
    }

    return listed;
  }

  String _formatPrice(CurrencyController? currency, double value) {
    if (currency != null) {
      return currency.formatUsd(value);
    }
    return '\$ ${value.toStringAsFixed(2)}';
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
    required this.badgeBackground,
    required this.badgeForeground,
    required this.icon,
  });

  final Color headlineColor;
  final Color badgeBackground;
  final Color badgeForeground;
  final IconData icon;
}
