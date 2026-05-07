import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:tronskins_app/api/model/wallet/wallet_models.dart';
import 'package:tronskins_app/common/hooks/currency/CurrencyController.dart';
import 'package:tronskins_app/common/storage/game_storage.dart';
import 'package:tronskins_app/common/widgets/back_to_top_overlay.dart';
import 'package:tronskins_app/common/widgets/glass_notice_dialog.dart';
import 'package:tronskins_app/common/widgets/settings_style_app_bar.dart';
import 'package:tronskins_app/components/game_item/game_item_models.dart';
import 'package:tronskins_app/l10n/inline_i18n.dart';
import 'package:tronskins_app/pages/wallet/widgets/wallet_order_asset_card.dart';

class WalletFlowDetailPage extends StatelessWidget {
  const WalletFlowDetailPage({super.key});

  static const _pageBg = Color(0xFFF8FAFC);
  static const _cardBg = Colors.white;
  static const _titleColor = Color(0xFF191C1E);
  static const _mutedColor = Color(0xFF757684);
  static const _bodyColor = Color(0xFF444653);
  static const _brandBlue = Color(0xFF2563EB);

  @override
  Widget build(BuildContext context) {
    final item = _argumentItem();
    final currency = Get.find<CurrencyController>();
    final topInset = MediaQuery.of(context).padding.top;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return BackToTopScope(
      enabled: false,
      child: Scaffold(
        backgroundColor: _pageBg,
        body: Stack(
          children: [
            Positioned.fill(
              child: item == null
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
                        bottomInset + 32,
                      ),
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 672),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildOrderNumberCard(context, item),
                              const SizedBox(height: 12),
                              _buildFlowContentCard(item, currency),
                              const SizedBox(height: 12),
                              _buildNoticeCard(item),
                              const SizedBox(height: 18),
                              _buildSectionLabel(
                                _text(zh: '资金追踪', en: 'Fund Tracking'),
                              ),
                              const SizedBox(height: 10),
                              _buildTrackingList(item, currency),
                            ],
                          ),
                        ),
                      ),
                    ),
            ),
            SettingsStyleTopNavigation(
              title: 'app.user.wallet.flow_details'.tr,
              onBack: () => Navigator.of(context).maybePop(),
            ),
          ],
        ),
      ),
    );
  }

  WalletFundFlowItem? _argumentItem() {
    final raw = Get.arguments;
    if (raw is WalletFundFlowItem) {
      return raw;
    }
    if (raw is Map<String, dynamic>) {
      return WalletFundFlowItem.fromJson(raw);
    }
    if (raw is Map) {
      return WalletFundFlowItem.fromJson(Map<String, dynamic>.from(raw));
    }
    return null;
  }

  String _text({required String zh, required String en}) {
    return InlineI18n.text(zh: zh, en: en);
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

  Widget _buildOrderNumberCard(BuildContext context, WalletFundFlowItem item) {
    final orderNumber = _orderNumber(item);
    return _buildCard(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _text(zh: '订单号', en: 'Order Number').toUpperCase(),
                  style: const TextStyle(
                    color: _mutedColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    height: 16 / 11,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  orderNumber,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _titleColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    height: 20 / 15,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: orderNumber == '-'
                ? null
                : () => _copy(context, orderNumber),
            icon: const Icon(
              Icons.content_copy_rounded,
              size: 18,
              color: _brandBlue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlowContentCard(
    WalletFundFlowItem item,
    CurrencyController currency,
  ) {
    final asset = _resolveAsset(item);
    final amountText = _formatSignedAmount(
      currency,
      item.amount?.abs() ?? 0,
      positive: _isPositive(item.type),
    );

    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (asset != null) ...[
            WalletOrderAssetCard(
              title: asset.title,
              subtitle: asset.subtitle,
              imageUrl: asset.imageUrl,
              appId: asset.appId,
              priceText: asset.priceText,
              count: asset.count,
              raw: asset.raw,
              schemaRaw: asset.schemaRaw,
              stickerMap: asset.stickerMap,
              rarity: asset.rarity,
              quality: asset.quality,
              exterior: asset.exterior,
              phase: asset.phase,
              percentage: asset.percentage,
              paintWear: asset.paintWear,
              wearText: asset.wearText,
            ),
            const SizedBox(height: 18),
          ],
          _buildDetailValueRow(
            label: _text(zh: '变动金额', en: 'Amount'),
            value: amountText,
            valueColor: _amountColor(item),
          ),
          const SizedBox(height: 8),
          _buildDetailValueRow(
            label: _text(zh: '类型', en: 'Type'),
            value: _flowTypeLabel(item),
          ),
          const SizedBox(height: 8),
          _buildTimeValueRow(
            label: _text(zh: '时间', en: 'Time'),
            value: _formatDateTime(item.createTime),
          ),
        ],
      ),
    );
  }

  Widget _buildNoticeCard(WalletFundFlowItem item) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, color: _brandBlue, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _text(
                zh: '该资金变动已记录完成，可在资金流水中继续查看相关订单明细。',
                en: 'This fund change has been recorded. You can review the related order details from fund flows.',
              ),
              style: const TextStyle(
                color: Color(0xFF1D4ED8),
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

  Widget _buildTrackingList(
    WalletFundFlowItem item,
    CurrencyController currency,
  ) {
    final positive = _isPositive(item.type);
    final amountText = _formatSignedAmount(
      currency,
      item.amount?.abs() ?? 0,
      positive: positive,
    );
    final beforeBalance = item.beforeBalance;
    final afterBalance = _afterBalance(item, positive: positive);
    final rows = <Widget>[
      _buildTrackingCard(
        title: _flowTypeLabel(item),
        time: _formatDateTime(item.createTime),
        amount: amountText,
        status: _text(zh: '已完成', en: 'Completed').toUpperCase(),
        active: true,
        amountColor: _amountColor(item),
      ),
      if (afterBalance != null)
        _buildTrackingCard(
          title: _text(zh: '变动后余额', en: 'Balance After'),
          time: _formatDateTime(item.createTime),
          amount: _formatPlainAmount(currency, afterBalance),
          status: _text(zh: '余额', en: 'Balance').toUpperCase(),
          active: false,
        ),
      if (beforeBalance != null)
        _buildTrackingCard(
          title: _text(zh: '变动前余额', en: 'Balance Before'),
          time: _formatDateTime(item.createTime),
          amount: _formatPlainAmount(currency, beforeBalance),
          status: _text(zh: '变动前', en: 'Before').toUpperCase(),
          active: false,
        ),
    ];

    return Column(
      children: [
        for (var index = 0; index < rows.length; index++) ...[
          rows[index],
          if (index != rows.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _buildTrackingCard({
    required String title,
    required String time,
    required String amount,
    required String status,
    required bool active,
    Color? amountColor,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          Container(
            width: 4,
            height: 72,
            color: active ? _brandBlue : const Color(0xFFE2E8F0),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Row(
                children: [
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
                            fontWeight: FontWeight.w700,
                            height: 20 / 14,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          time,
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
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        amount,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          color: amountColor ?? _titleColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          height: 20 / 14,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        status,
                        style: const TextStyle(
                          color: _mutedColor,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          height: 13 / 9,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(20),
  }) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: child,
    );
  }

  Widget _buildSectionLabel(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: _bodyColor,
        fontSize: 15,
        fontWeight: FontWeight.w800,
        height: 22 / 15,
      ),
    );
  }

  Widget _buildDetailValueRow({
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: _bodyColor,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              height: 18 / 13,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: valueColor ?? _titleColor,
              fontSize: 15,
              fontWeight: FontWeight.w800,
              height: 20 / 15,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimeValueRow({required String label, required String value}) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: _bodyColor,
            fontSize: 13,
            fontWeight: FontWeight.w500,
            height: 18 / 13,
          ),
        ),
        const SizedBox(width: 96),
        Expanded(
          child: Text(
            value,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.visible,
            style: const TextStyle(
              color: _titleColor,
              fontSize: 15,
              fontWeight: FontWeight.w800,
              height: 20 / 15,
            ),
          ),
        ),
      ],
    );
  }

  bool _isPositive(int? type) {
    return type != null && [1, 2, 4, 6, 10].contains(type);
  }

  Color _amountColor(WalletFundFlowItem item) {
    final positive = _isPositive(item.type);
    final typeName = (item.typeName ?? '').toLowerCase();
    final looksLikeRefund =
        typeName.contains('refund') ||
        typeName.contains('返') ||
        typeName.contains('退');
    if (looksLikeRefund) {
      return const Color(0xFF1E293B);
    }
    return positive ? _brandBlue : const Color(0xFFBA1A1A);
  }

  String _formatSignedAmount(
    CurrencyController currency,
    double amountValue, {
    required bool positive,
  }) {
    final formatted = currency.formatUsd(amountValue).replaceFirst('\$ ', r'$');
    return '${positive ? '+' : '-'}$formatted';
  }

  String _formatPlainAmount(CurrencyController currency, double value) {
    return currency.formatUsd(value).replaceFirst('\$ ', r'$');
  }

  double? _afterBalance(WalletFundFlowItem item, {required bool positive}) {
    final beforeBalance = item.beforeBalance;
    final amount = item.amount;
    if (beforeBalance == null || amount == null) {
      return null;
    }
    final delta = positive ? amount.abs() : -amount.abs();
    return beforeBalance + delta;
  }

  String _flowTypeLabel(WalletFundFlowItem item) {
    final label = item.typeName?.trim();
    if (label == null || label.isEmpty) {
      return '-';
    }
    return label;
  }

  String _orderNumber(WalletFundFlowItem item) {
    final candidates = [
      item.srcId,
      item.serialNumber,
      item.id,
      _findTextValue(item.raw, const ['orderId', 'order_id', 'tradeNo']),
    ];
    for (final candidate in candidates) {
      final value = candidate?.trim();
      if (value != null && value.isNotEmpty && value != 'null') {
        return value;
      }
    }
    return '-';
  }

  String _formatDateTime(int? timestamp) {
    if (timestamp == null || timestamp <= 0) {
      return '-';
    }
    var normalized = timestamp;
    if (normalized < 10000000000) {
      normalized *= 1000;
    }
    return DateFormat(
      'yyyy-MM-dd HH:mm:ss',
    ).format(DateTime.fromMillisecondsSinceEpoch(normalized).toLocal());
  }

  _FlowAssetPayload? _resolveAsset(WalletFundFlowItem item) {
    final raw = item.raw;
    final detailRaw =
        _firstMap([
          raw['detail'],
          raw['orderDetail'],
          raw['order_detail'],
          raw['sellItem'],
          raw['sell_item'],
          raw['item'],
          raw['asset'],
          raw['csgoAsset'],
          _firstListMap(raw['details']),
          _firstListMap(raw['items']),
          _firstListMap(raw['sellItems']),
        ]) ??
        (_looksLikeAsset(raw) ? raw : null);
    final schemaRaw = _firstMap([
      raw['schema'],
      raw['schemaInfo'],
      raw['schema_info'],
      raw['assetSchema'],
      raw['asset_schema'],
    ]);
    final base = detailRaw ?? schemaRaw;
    if (base == null) {
      return null;
    }

    final appId =
        _asInt(_pickRawValue(base, const ['app_id', 'appId'])) ??
        _asInt(_pickRawValue(schemaRaw, const ['app_id', 'appId'])) ??
        GameStorage.getGameType();
    final title =
        _findTextValue(base, const [
          'market_name',
          'marketName',
          'localized_name',
          'localizedName',
          'name',
        ]) ??
        _findTextValue(schemaRaw, const [
          'market_name',
          'marketName',
          'localized_name',
          'localizedName',
          'name',
        ]) ??
        _findTextValue(base, const ['market_hash_name', 'marketHashName']);
    final subtitle =
        _findTextValue(base, const ['market_hash_name', 'marketHashName']) ??
        _findTextValue(schemaRaw, const ['market_hash_name', 'marketHashName']);
    final imageUrl =
        _findTextValue(base, const ['image_url', 'imageUrl', 'image']) ??
        _findTextValue(schemaRaw, const ['image_url', 'imageUrl', 'image']);

    if ((title == null || title.isEmpty) &&
        (imageUrl == null || imageUrl.isEmpty)) {
      return null;
    }

    final price = _asDouble(
      _pickRawValue(base, const [
        'price',
        'market_price',
        'marketPrice',
        'sale_price',
        'salePrice',
        'total_price',
        'totalPrice',
        'amount',
      ]),
    );
    final count =
        _asInt(_pickRawValue(base, const ['count', 'num', 'quantity'])) ?? 1;

    return _FlowAssetPayload(
      raw: base,
      schemaRaw: schemaRaw ?? const {},
      stickerMap: _asMap(raw['stickers']) ?? const {},
      title: title ?? '-',
      subtitle: subtitle,
      imageUrl: imageUrl,
      appId: appId,
      priceText: price == null
          ? null
          : Get.find<CurrencyController>().formatUsd(price),
      count: count > 1 ? count : null,
      rarity: _schemaTag(schemaRaw, 'rarity'),
      quality: _schemaTag(schemaRaw, 'quality'),
      exterior: _schemaTag(schemaRaw, 'exterior'),
      phase:
          _findTextValue(base, const ['phase']) ??
          _findTextValue(schemaRaw, const ['phase']),
      percentage:
          _findTextValue(base, const ['percentage']) ??
          _findTextValue(schemaRaw, const ['percentage']),
      paintWear: _asDouble(
        _pickRawValue(base, const ['paint_wear', 'paintWear']),
      ),
      wearText: _findTextValue(base, const [
        'paint_wear_text',
        'paintWearText',
      ]),
    );
  }

  bool _looksLikeAsset(Map<String, dynamic> raw) {
    return _findTextValue(raw, const [
          'market_name',
          'marketName',
          'market_hash_name',
          'marketHashName',
          'image_url',
          'imageUrl',
          'image',
        ]) !=
        null;
  }

  Map<String, dynamic>? _firstMap(List<dynamic> values) {
    for (final value in values) {
      final map = _asMap(value);
      if (map != null) {
        return map;
      }
    }
    return null;
  }

  Map<String, dynamic>? _firstListMap(dynamic value) {
    if (value is! List) {
      return null;
    }
    for (final item in value) {
      final map = _asMap(item);
      if (map != null) {
        return map;
      }
    }
    return null;
  }

  TagInfo? _schemaTag(Map<String, dynamic>? schema, String key) {
    final tags = schema?['tags'];
    if (tags is Map) {
      return TagInfo.fromRaw(tags[key]);
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

  dynamic _pickRawValue(dynamic source, List<String> keys) {
    final map = _asMap(source);
    if (map == null) {
      return null;
    }
    for (final key in keys) {
      final value = map[key];
      if (value != null) {
        return value;
      }
    }
    return null;
  }

  String? _findTextValue(dynamic source, List<String> keys) {
    final value = _pickRawValue(source, keys);
    final text = value?.toString().trim();
    if (text == null || text.isEmpty || text == 'null') {
      return null;
    }
    return text;
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

class _FlowAssetPayload {
  const _FlowAssetPayload({
    required this.raw,
    required this.schemaRaw,
    required this.stickerMap,
    required this.title,
    required this.appId,
    this.subtitle,
    this.imageUrl,
    this.priceText,
    this.count,
    this.rarity,
    this.quality,
    this.exterior,
    this.phase,
    this.percentage,
    this.paintWear,
    this.wearText,
  });

  final Map<String, dynamic> raw;
  final Map<String, dynamic> schemaRaw;
  final Map<String, dynamic> stickerMap;
  final String title;
  final String? subtitle;
  final String? imageUrl;
  final int appId;
  final String? priceText;
  final int? count;
  final TagInfo? rarity;
  final TagInfo? quality;
  final TagInfo? exterior;
  final String? phase;
  final String? percentage;
  final double? paintWear;
  final String? wearText;
}
