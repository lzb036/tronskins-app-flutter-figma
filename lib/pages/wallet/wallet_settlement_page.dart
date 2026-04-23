import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tronskins_app/common/widgets/settings_style_app_bar.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:tronskins_app/api/model/wallet/wallet_models.dart';
import 'package:tronskins_app/common/hooks/currency/CurrencyController.dart';
import 'package:tronskins_app/common/storage/game_storage.dart';
import 'package:tronskins_app/common/widgets/back_to_top_overlay.dart';
import 'package:tronskins_app/components/game_item/game_item_image.dart';
import 'package:tronskins_app/components/game_item/game_item_models.dart';
import 'package:tronskins_app/components/game_item/game_item_utils.dart';
import 'package:tronskins_app/components/game_item/wear_progress_bar.dart';
import 'package:tronskins_app/components/layout/list_end_tip.dart';
import 'package:tronskins_app/controllers/wallet/wallet_controller.dart';
import 'package:tronskins_app/pages/wallet/wallet_settlement_detail_page.dart';

class WalletSettlementPage extends StatefulWidget {
  const WalletSettlementPage({super.key});

  @override
  State<WalletSettlementPage> createState() => _WalletSettlementPageState();
}

class _WalletSettlementPageState extends State<WalletSettlementPage> {
  static const Color _pageBackground = Color(0xFFF8FAFC);
  static const Color _surfaceColor = Colors.white;
  static const Color _softSurfaceColor = Color(0xFFF1F5F9);
  static const Color _titleColor = Color(0xFF191C1E);
  static const Color _bodyColor = Color(0xFF64748B);
  static const Color _borderColor = Color(0xFFF8FAFC);
  static const Color _brandDeepColor = Color(0xFF1E40AF);
  static const Color _countdownAccent = Color(0xFF3B82F6);
  static const Color _skeletonColor = Color(0xFFE2E8F0);

  final WalletController controller = Get.isRegistered<WalletController>()
      ? Get.find<WalletController>()
      : Get.put(WalletController());
  final ScrollController _scrollController = ScrollController();

  bool get _isChineseLocale =>
      (Get.locale?.languageCode ?? '').toLowerCase().startsWith('zh');

  @override
  void initState() {
    super.initState();
    controller.loadSettlementRecords(reset: true);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) {
      return;
    }
    final position = _scrollController.position;
    if (position.pixels > position.maxScrollExtent - 200) {
      controller.loadSettlementRecords();
    }
  }

  void _openSettlementDetail(WalletSettlementRecord record) {
    Get.to(
      () => WalletSettlementDetailPage(
        record: record,
        schemas: Map<String, WalletSchemaInfo>.from(
          controller.settlementSchemas,
        ),
        users: Map<String, dynamic>.from(controller.settlementUsers),
        stickers: Map<String, dynamic>.from(controller.settlementStickers),
      ),
    );
  }

  String _formatCardDate(int? value) {
    if (value == null) {
      return '-';
    }
    var timestamp = value;
    if (timestamp < 10000000000) {
      timestamp *= 1000;
    }
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return DateFormat('yyyy.M.d').format(date);
  }

  String _multipleItemsSubtitle(int count) {
    if (_isChineseLocale) {
      return '共 $count 件商品';
    }
    return '$count items';
  }

  WalletSchemaInfo? _findSchema(WalletSettlementDetail detail) {
    final marketHashName = detail.marketHashName ?? '';
    if (marketHashName.isNotEmpty &&
        controller.settlementSchemas.containsKey(marketHashName)) {
      return controller.settlementSchemas[marketHashName];
    }
    final schemaIdKey = detail.schemaId?.toString();
    if (schemaIdKey != null &&
        controller.settlementSchemas.containsKey(schemaIdKey)) {
      return controller.settlementSchemas[schemaIdKey];
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
    return value?.toString();
  }

  int? _asInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }

  int _resolveAppId(WalletSettlementDetail detail, WalletSchemaInfo? schema) {
    return detail.appId ??
        schema?.appId ??
        _asInt(_pickRawValue(detail.raw, const ['app_id', 'appId'])) ??
        _asInt(_pickRawValue(schema?.raw, const ['app_id', 'appId'])) ??
        GameStorage.getGameType();
  }

  String _resolveImageUrl(
    WalletSettlementDetail detail,
    WalletSchemaInfo? schema,
  ) {
    return schema?.imageUrl ??
        detail.imageUrl ??
        _pickRawText(detail.raw, const ['image_url', 'imageUrl', 'image']) ??
        _pickRawText(schema?.raw, const ['image_url', 'imageUrl', 'image']) ??
        '';
  }

  String _resolveTitle(
    WalletSettlementDetail detail,
    WalletSchemaInfo? schema,
  ) {
    return schema?.marketName ??
        detail.marketName ??
        detail.marketHashName ??
        '-';
  }

  String? _paintWearText(WalletSettlementDetail detail) {
    final value = detail.raw['paint_wear'] ?? detail.raw['paintWear'];
    if (value != null) {
      return value.toString();
    }
    return detail.paintWear?.toString();
  }

  double? _paintWearValue(WalletSettlementDetail detail) {
    final value = detail.raw['paint_wear'] ?? detail.raw['paintWear'];
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value);
    }
    return detail.paintWear;
  }

  String? _phaseText(WalletSettlementDetail detail, WalletSchemaInfo? schema) {
    return _pickRawText(detail.raw, const ['phase']) ??
        _pickRawText(schema?.raw, const ['phase']);
  }

  String? _percentageText(
    WalletSettlementDetail detail,
    WalletSchemaInfo? schema,
  ) {
    return _pickRawText(detail.raw, const ['percentage']) ??
        _pickRawText(schema?.raw, const ['percentage']);
  }

  List<GameItemSticker> _detailStickers(WalletSettlementDetail detail) {
    final stickerRaw = _pickRawValue(detail.raw, const ['stickers']);
    return parseStickerList(
      stickerRaw,
      stickerMap: controller.settlementStickers,
    );
  }

  Widget _buildPreviewImage(
    WalletSettlementDetail detail, {
    WalletSchemaInfo? schema,
    double width = 40,
    double height = 40,
    bool showTopBadges = false,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: _softSurfaceColor,
        borderRadius: BorderRadius.circular(4),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: GameItemImage(
          imageUrl: _resolveImageUrl(detail, schema),
          appId: _resolveAppId(detail, schema),
          rarity: _schemaTag(schema, 'rarity'),
          quality: _schemaTag(schema, 'quality'),
          exterior: _schemaTag(schema, 'exterior'),
          phase: _phaseText(detail, schema),
          percentage: _percentageText(detail, schema),
          stickers: _detailStickers(detail),
          avoidTopLeftBadgeOverlap: true,
          compactTopLeftBadges: true,
          showTopBadges: showTopBadges,
        ),
      ),
    );
  }

  BoxDecoration _cardDecoration({
    Color color = _surfaceColor,
    BorderRadius borderRadius = const BorderRadius.all(Radius.circular(8)),
  }) {
    return BoxDecoration(
      color: color,
      borderRadius: borderRadius,
      border: Border.all(color: _borderColor),
      boxShadow: const [
        BoxShadow(
          color: Color.fromRGBO(0, 0, 0, 0.05),
          blurRadius: 2,
          offset: Offset(0, 1),
        ),
      ],
    );
  }

  String _statusText(WalletSettlementRecord record) {
    final rawStatus = _pickRawText(record.raw, const [
      'statusName',
      'status_name',
      'statusText',
      'status_text',
    ]);
    if (rawStatus != null && rawStatus.trim().isNotEmpty) {
      return rawStatus.trim();
    }

    switch (record.status) {
      case 4:
      case 6:
        return _isChineseLocale ? '已完成' : 'Completed';
      case 5:
        return _isChineseLocale ? '待结算' : 'Pending Settlement';
      case 2:
      case 3:
        return _isChineseLocale ? '已取消' : 'Cancelled';
      default:
        return _isChineseLocale ? '处理中' : 'Processing';
    }
  }

  _SettlementStatusStyle _statusStyle(WalletSettlementRecord record) {
    final text = _statusText(record).toLowerCase();
    final status = record.status;

    final isPending =
        status == 5 ||
        text.contains('pending') ||
        text.contains('settlement') ||
        text.contains('待结算') ||
        text.contains('待处理');
    if (isPending) {
      return const _SettlementStatusStyle(
        backgroundColor: Color(0xFFEFF6FF),
        textColor: Color(0xFF2563EB),
      );
    }

    final isCancelled =
        status == 2 ||
        status == 3 ||
        text.contains('cancel') ||
        text.contains('closed') ||
        text.contains('取消');
    if (isCancelled) {
      return const _SettlementStatusStyle(
        backgroundColor: Color(0xFFF1F5F9),
        textColor: Color(0xFF64748B),
      );
    }

    final isCompleted =
        status == 4 ||
        status == 6 ||
        text.contains('complete') ||
        text.contains('success') ||
        text.contains('done') ||
        text.contains('完成');
    if (isCompleted) {
      return const _SettlementStatusStyle(
        backgroundColor: Color(0xFFF0FDF4),
        textColor: Color(0xFF16A34A),
      );
    }

    return const _SettlementStatusStyle(
      backgroundColor: Color(0xFFF1F5F9),
      textColor: Color(0xFF64748B),
    );
  }

  Widget _buildStatusChip(WalletSettlementRecord record) {
    final style = _statusStyle(record);
    return Container(
      constraints: const BoxConstraints(minHeight: 23),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: style.backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        _statusText(record),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: style.textColor,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          height: 15 / 10,
          letterSpacing: _isChineseLocale ? 0 : 0.25,
        ),
      ),
    );
  }

  Widget _buildRecordTrailingMeta(WalletSettlementRecord record) {
    final hasCountdown =
        record.protectionTime != null && (record.status ?? 0) == 5;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (hasCountdown)
          CountdownText(
            endTimeSeconds: record.protectionTime!,
            textAlign: TextAlign.end,
            style: const TextStyle(
              color: _countdownAccent,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              height: 16.5 / 11,
            ),
          ),
        if (hasCountdown) const SizedBox(height: 4),
        Text(
          _formatCardDate(record.protectionTime),
          style: const TextStyle(
            color: _bodyColor,
            fontSize: 11,
            fontWeight: FontWeight.w500,
            height: 16.5 / 11,
          ),
        ),
      ],
    );
  }

  Widget _buildSettlementInfoPanel(
    WalletSettlementRecord record,
    double price,
    CurrencyController currency,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFEFF3F8)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildInfoMetric(
              label: _isChineseLocale ? '结算金额' : 'Amount',
              child: _buildRecordPrice(price, currency),
            ),
          ),
          Container(
            width: 1,
            height: 36,
            margin: const EdgeInsets.symmetric(horizontal: 14),
            color: const Color(0xFFE2E8F0),
          ),
          Expanded(
            child: _buildInfoMetric(
              label: _isChineseLocale ? '预计到账' : 'Release',
              crossAxisAlignment: CrossAxisAlignment.end,
              child: _buildRecordTrailingMeta(record),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoMetric({
    required String label,
    required Widget child,
    CrossAxisAlignment crossAxisAlignment = CrossAxisAlignment.start,
  }) {
    return Column(
      crossAxisAlignment: crossAxisAlignment,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 10,
            fontWeight: FontWeight.w700,
            height: 14 / 10,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 4),
        child,
      ],
    );
  }

  Widget _buildRecordPrice(double price, CurrencyController currency) {
    return Text(
      currency.formatUsd(price),
      style: const TextStyle(
        color: _brandDeepColor,
        fontSize: 20,
        fontWeight: FontWeight.w800,
        height: 26 / 20,
        letterSpacing: 0.2,
      ),
    );
  }

  Widget _buildMultiPreviewStack(List<WalletSettlementDetail> details) {
    final previewDetails = details.take(2).toList();
    return SizedBox(
      width: previewDetails.length == 1 ? 48 : 76,
      height: 48,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var index = 0; index < previewDetails.length; index++)
            Positioned(
              left: index * 28,
              child: _buildPreviewImage(
                previewDetails[index],
                schema: _findSchema(previewDetails[index]),
                width: 48,
                height: 48,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRecordCard(
    WalletSettlementRecord record,
    CurrencyController currency,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: _cardDecoration(borderRadius: BorderRadius.zero),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.zero,
          onTap: () => _openSettlementDetail(record),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (record.details.length <= 1)
                  _buildSingleDetailSummary(record, currency)
                else
                  _buildMultipleDetailSummary(record, currency),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSingleDetailSummary(
    WalletSettlementRecord record,
    CurrencyController currency,
  ) {
    final detail = record.details.isNotEmpty ? record.details.first : null;
    if (detail == null) {
      return Row(
        children: [
          Expanded(child: _buildRecordPrice(record.price ?? 0, currency)),
          const SizedBox(width: 12),
          _buildRecordTrailingMeta(record),
        ],
      );
    }

    final schema = _findSchema(detail);
    final exterior = _schemaTag(schema, 'exterior');
    final wearText = _paintWearText(detail);
    final wearValue = _paintWearValue(detail);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPreviewImage(detail, schema: schema, width: 48, height: 48),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          _resolveTitle(detail, schema),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _titleColor,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            height: 20 / 15,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildStatusChip(record),
                    ],
                  ),
                  if (wearText != null && wearText.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      wearText,
                      style: const TextStyle(
                        color: _bodyColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        height: 16 / 12,
                      ),
                    ),
                  ],
                  if (wearValue != null) ...[
                    const SizedBox(height: 6),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 168),
                      child: WearProgressBar(
                        paintWear: wearValue,
                        height: 10,
                        style: WearProgressBarStyle.figmaCompact,
                        accentColor: parseHexColor(exterior?.color),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildSettlementInfoPanel(
          record,
          record.price ?? detail.price ?? 0,
          currency,
        ),
      ],
    );
  }

  Widget _buildMultipleDetailSummary(
    WalletSettlementRecord record,
    CurrencyController currency,
  ) {
    final previewDetails = record.details.take(2).toList();
    final extraCount = record.details.length - previewDetails.length;
    final firstDetail = previewDetails.isNotEmpty ? previewDetails.first : null;
    final firstSchema = firstDetail == null ? null : _findSchema(firstDetail);
    final totalCount = record.details.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildMultiPreviewStack(record.details),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          firstDetail == null
                              ? _multipleItemsSubtitle(totalCount)
                              : _resolveTitle(firstDetail, firstSchema),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _titleColor,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            height: 20 / 15,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      _buildStatusChip(record),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    extraCount > 0
                        ? '${_multipleItemsSubtitle(totalCount)}  •  +$extraCount'
                        : _multipleItemsSubtitle(totalCount),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
          ],
        ),
        const SizedBox(height: 16),
        _buildSettlementInfoPanel(record, record.price ?? 0, currency),
      ],
    );
  }

  Widget _buildLoadMoreFooter({required bool loading, required bool hasMore}) {
    if (loading && hasMore) {
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: _buildSettlementSkeletonList(count: 2, shrinkWrap: true),
      );
    }
    if (!hasMore) {
      return const ListEndTip(padding: EdgeInsets.fromLTRB(8, 4, 8, 8));
    }
    return const SizedBox(height: 4);
  }

  Widget _buildSettlementSkeletonList({
    int count = 3,
    bool shrinkWrap = false,
  }) {
    return ListView.separated(
      controller: shrinkWrap ? null : _scrollController,
      shrinkWrap: shrinkWrap,
      physics: const NeverScrollableScrollPhysics(),
      padding: shrinkWrap
          ? EdgeInsets.zero
          : const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: count,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, __) => _buildSettlementSkeletonCard(),
    );
  }

  Widget _buildSettlementSkeletonCard() {
    return Container(
      decoration: _cardDecoration(borderRadius: BorderRadius.zero),
      padding: const EdgeInsets.all(21),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildSkeletonBox(width: 40, height: 40, radius: 4),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSkeletonBox(width: 132, height: 14, radius: 6),
                    const SizedBox(height: 6),
                    _buildSkeletonBox(width: 62, height: 11, radius: 6),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _buildSkeletonBox(width: 92, height: 23, radius: 12),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: _buildSkeletonBox(width: 110, height: 22, radius: 8),
              ),
              const SizedBox(width: 12),
              _buildSkeletonBox(width: 56, height: 11, radius: 6),
            ],
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
        color: _skeletonColor,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        const SizedBox(height: 160),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
          decoration: _cardDecoration(),
          child: Center(
            child: Text(
              'app.common.no_data'.tr,
              style: const TextStyle(
                color: _bodyColor,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                height: 20 / 14,
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return BackToTopScope(
      enabled: true,
      child: Scaffold(
        backgroundColor: _pageBackground,
        appBar: SettingsStyleAppBar(
          title: Text('app.user.wallet.unsettled_details'.tr),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: _cardDecoration(),
                child: Text(
                  'app.user.wallet.unsettled_tips'.tr,
                  style: const TextStyle(
                    color: _bodyColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    height: 22.75 / 14,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Obx(() {
                final loading = controller.isLoadingSettlement.value;
                final records = controller.settlementRecords;
                final currency = Get.find<CurrencyController>();

                if (loading && records.isEmpty) {
                  return _buildSettlementSkeletonList();
                }

                return RefreshIndicator(
                  color: _brandDeepColor,
                  backgroundColor: _surfaceColor,
                  strokeWidth: 2.6,
                  edgeOffset: 8,
                  displacement: 24,
                  onRefresh: () =>
                      controller.loadSettlementRecords(reset: true),
                  child: records.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          controller: _scrollController,
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                          itemCount: records.length + 1,
                          itemBuilder: (context, index) {
                            if (index >= records.length) {
                              return _buildLoadMoreFooter(
                                loading: loading,
                                hasMore: controller.hasMoreSettlementRecords,
                              );
                            }
                            return _buildRecordCard(records[index], currency);
                          },
                        ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettlementStatusStyle {
  const _SettlementStatusStyle({
    required this.backgroundColor,
    required this.textColor,
  });

  final Color backgroundColor;
  final Color textColor;
}

class CountdownText extends StatefulWidget {
  const CountdownText({
    super.key,
    required this.endTimeSeconds,
    this.style,
    this.textAlign,
  });

  final int endTimeSeconds;
  final TextStyle? style;
  final TextAlign? textAlign;

  @override
  State<CountdownText> createState() => _CountdownTextState();
}

class _CountdownTextState extends State<CountdownText> {
  Timer? _timer;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _updateRemaining();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateRemaining();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _updateRemaining() {
    final endTime = DateTime.fromMillisecondsSinceEpoch(
      widget.endTimeSeconds * 1000,
    );
    final diff = endTime.difference(DateTime.now());
    setState(() => _remaining = diff.isNegative ? Duration.zero : diff);
    if (_remaining == Duration.zero) {
      _timer?.cancel();
    }
  }

  String _formatDuration(Duration duration) {
    final totalSeconds = duration.inSeconds;
    if (totalSeconds <= 0) {
      return '00:00:00';
    }
    final days = duration.inDays;
    final hours = duration.inHours % 24;
    final minutes = duration.inMinutes % 60;
    final seconds = totalSeconds % 60;
    final dayLabel = 'app.common.day'.tr;
    if (days > 0) {
      return '${days.toString().padLeft(2, '0')}$dayLabel '
          '${hours.toString().padLeft(2, '0')}:'
          '${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    }
    return '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _formatDuration(_remaining),
      textAlign: widget.textAlign,
      style: widget.style,
    );
  }
}
