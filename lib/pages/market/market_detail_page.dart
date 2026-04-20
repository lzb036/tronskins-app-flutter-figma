import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:tronskins_app/api/market.dart';
import 'package:tronskins_app/api/model/market/market_models.dart';
import 'package:tronskins_app/api/model/shop/shop_models.dart';
import 'package:tronskins_app/api/shop_product.dart';
import 'package:tronskins_app/common/storage/user_storage.dart';
import 'package:tronskins_app/components/game_item/game_item_models.dart';
import 'package:tronskins_app/components/game_item/gem_row.dart';
import 'package:tronskins_app/components/game_item/sticker_row.dart';
import 'package:tronskins_app/components/game_item/wear_progress_bar.dart';
import 'package:tronskins_app/components/filter/filter_sheet_style.dart';
import 'package:tronskins_app/components/layout/list_end_tip.dart';
import 'package:tronskins_app/components/market/price_trend_chart.dart';
import 'package:tronskins_app/controllers/market/market_detail_controller.dart';
import 'package:tronskins_app/common/hooks/currency/CurrencyController.dart';
import 'package:tronskins_app/common/utils/app_snackbar.dart';
import 'package:tronskins_app/common/widgets/back_to_top_overlay.dart';
import 'package:tronskins_app/common/widgets/figma_confirmation_dialog.dart';
import 'package:tronskins_app/common/widgets/settings_style_app_bar.dart';
import 'package:tronskins_app/common/widgets/steam_style_confirm_dialog.dart';
import 'package:tronskins_app/routes/app_routes.dart';

class MarketDetailPage extends StatefulWidget {
  const MarketDetailPage({super.key});

  @override
  State<MarketDetailPage> createState() => _MarketDetailPageState();
}

class _MarketDetailPageState extends State<MarketDetailPage>
    with TickerProviderStateMixin {
  static const double _topActionToolbarMaxHeight = 34;
  static const double _detailListBackToTopBottomPadding = 18;
  static const int _detailOnSaleLoadMorePlaceholderCount = 2;
  static const int _detailBuyRequestLoadMorePlaceholderCount = 2;
  static const int _detailTransactionLoadMorePlaceholderCount = 2;
  static const double _onSaleListingImageBoxWidth = 84;
  static const double _onSaleListingImageAspectRatio = 3 / 2;
  static const double _onSaleListingImageBoxHeight =
      _onSaleListingImageBoxWidth / _onSaleListingImageAspectRatio;
  static const double _historyStatusBadgeWidth = 70;
  static const Color _figmaSlate100 = Color(0xFFF1F5F9);
  static const Color _figmaSlate300 = Color(0xFFCBD5E1);
  static const Color _figmaSlate400 = Color(0xFF94A3B8);
  static const Color _figmaSlate500 = Color(0xFF64748B);
  static const Color _figmaSlate800 = Color(0xFF1E293B);
  static const Color _figmaSlate900 = Color(0xFF0F172A);
  static const Color _figmaPageCoolBackground = Color(0xFFF4F6FB);
  static const Color _figmaBlue700 = Color(0xFF1E40AF);
  static const Color _figmaBlue500 = Color(0xFF3B82F6);
  static const Color _figmaGreen600 = Color(0xFF0D9B6B);
  static const Color _figmaGreen400 = Color(0xFF33C28A);
  static const Color _figmaRed600 = Color(0xFFD92D20);
  static const Color _figmaRed400 = Color(0xFFF1695C);
  static const Color _figmaOrange = Color(0xFFFF9800);
  final MarketDetailController controller = Get.put(MarketDetailController());
  final GlobalKey _onSaleSortButtonKey = GlobalKey();
  final GlobalKey _onSaleWearButtonKey = GlobalKey();
  final GlobalKey _onSalePhaseButtonKey = GlobalKey();
  final ApiMarketServer _marketApi = ApiMarketServer();
  final ApiShopProductServer _shopProductApi = ApiShopProductServer();
  late final TabController _tabController;
  int _currentTabIndex = 0;
  int _selectedDays = 30;
  MarketTemplateDetail? _templateDetail;
  bool _loadingTemplate = false;
  List<_WearOption> _wearOptions = <_WearOption>[];
  List<String> _qualityKeys = <String>[];
  int _qualityIndex = 0;
  int? _pendingWearSchemaId;
  int _templateRequestSerial = 0;
  double? _onSaleMinPrice;
  double? _onSaleMaxPrice;
  String? _onSalePaintSeed;
  int? _onSalePaintIndex;
  double? _onSaleWearMin;
  double? _onSaleWearMax;
  String? _onSaleSortField;
  bool? _onSaleSortAsc;
  final Set<String> _onSalePurchasingIds = <String>{};
  bool _collectionSubmitting = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.animation?.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
    _tabController.addListener(() {
      final nextIndex = _tabController.index;
      if (nextIndex != _currentTabIndex && mounted) {
        setState(() => _currentTabIndex = nextIndex);
      }
    });
    Future.microtask(_loadTemplate);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<bool> _promptLoginIfNeeded() async {
    if (UserStorage.getUserInfo() != null) {
      return true;
    }

    final confirmed = await showFigmaModal<bool>(
      context: context,
      child: FigmaConfirmationDialog(
        icon: Icons.login_rounded,
        iconColor: const Color(0xFF1E40AF),
        iconBackgroundColor: const Color.fromRGBO(30, 64, 175, 0.10),
        title: 'app.user.login.nologin'.tr,
        message: 'app.system.message.nologin'.tr,
        primaryLabel: 'app.user.login.nologin'.tr,
        secondaryLabel: 'app.common.cancel'.tr,
        onPrimary: () => popModalRoute(context, true),
        onSecondary: () => popModalRoute(context, false),
      ),
    );
    if (confirmed == true) {
      await Get.toNamed(Routers.LOGIN);
    }
    return false;
  }

  String? _onSalePurchaseKey(MarketListItem item) {
    final id = item.id?.toString();
    if (id != null && id.isNotEmpty) {
      return id;
    }
    final rawId = item.raw['id']?.toString();
    if (rawId != null && rawId.isNotEmpty) {
      return rawId;
    }
    return null;
  }

  MarketSchemaInfo? _lookupMarketSchema(MarketListItem item) {
    final key = item.schemaId?.toString();
    if (key != null && controller.schemas.containsKey(key)) {
      return controller.schemas[key];
    }
    final hash = item.marketHashName;
    if (hash != null && controller.schemas.containsKey(hash)) {
      return controller.schemas[hash];
    }
    return null;
  }

  String _resolveAvatar(String? avatar) {
    if (avatar == null || avatar.isEmpty) {
      return '';
    }
    if (avatar.startsWith('http')) {
      return avatar;
    }
    return 'https://www.tronskins.com/fms/image$avatar';
  }

  Future<void> _openBuying() async {
    if (!await _promptLoginIfNeeded()) {
      return;
    }
    final schemaId = controller.schemaId;
    if (schemaId == null) {
      return;
    }
    final result = await Get.toNamed(
      Routers.PRODUCT_BUYING,
      arguments: {'appId': controller.appId, 'schemaId': schemaId},
    );
    if (result == true) {
      await controller.loadBuyRequests(reset: true);
    }
  }

  Future<void> _openBulkBuying() async {
    if (!await _promptLoginIfNeeded()) {
      return;
    }
    final schemaId = controller.schemaId;
    if (schemaId == null) {
      return;
    }
    final result = await Get.toNamed(
      Routers.BULK_BUYING,
      arguments: {'appId': controller.appId, 'schemaId': schemaId},
    );
    if (result == true) {
      await controller.loadOnSale(reset: true);
      await controller.loadTransactions(reset: true);
    }
  }

  Future<void> _loadTemplate({int? schemaId}) async {
    final appId = controller.appId;
    final targetId = schemaId ?? controller.schemaId;
    if (targetId == null) {
      return;
    }
    final requestSerial = ++_templateRequestSerial;
    if (mounted && !_loadingTemplate) {
      setState(() => _loadingTemplate = true);
    }
    try {
      final useAuth = UserStorage.getUserInfo() != null;
      final res = await _marketApi.marketTemplateDetail(
        appId: appId,
        schemaId: targetId,
        useAuth: useAuth,
        fallbackToPublicOnFail: true,
      );
      final detail = res.datas;
      if (!mounted || requestSerial != _templateRequestSerial) {
        return;
      }
      if (detail == null) {
        return;
      }
      _templateDetail = detail;
      _buildWearOptions(detail);
      final schema = detail.schema;
      if (schema != null) {
        final mappedItem = _mapTemplateToItem(schema);
        final mappedSchemaId = mappedItem.schemaId ?? mappedItem.id;
        final currentSchemaId = controller.schemaId;
        final mappedAppId = mappedItem.appId ?? controller.appId;
        final mappedHash =
            mappedItem.marketHashName ?? mappedItem.marketName ?? '';
        final currentHash = controller.marketHashName;
        final shouldRefreshList =
            mappedSchemaId != currentSchemaId ||
            mappedAppId != controller.appId ||
            (mappedHash.isNotEmpty && mappedHash != currentHash);
        if (shouldRefreshList) {
          controller.updateItem(mappedItem, preserveVisibleItems: true);
        }
      }
    } finally {
      if (mounted && requestSerial == _templateRequestSerial) {
        setState(() {
          _loadingTemplate = false;
        });
      }
    }
  }

  void _buildWearOptions(MarketTemplateDetail detail) {
    _wearOptions = <_WearOption>[];
    _qualityKeys = <String>[];
    _qualityIndex = 0;
    if (detail.schema?.appId != 730) {
      return;
    }
    final qualityMap = detail.qualityMap;
    if (qualityMap == null) {
      return;
    }
    final keys = qualityMap.keys.toList();
    if (keys.isEmpty) {
      return;
    }
    _qualityKeys = keys;
    final qualityName = detail.schema?.tags?.quality?.localizedName;
    final index = qualityName == null ? -1 : keys.indexOf(qualityName);
    _qualityIndex = index >= 0 ? index : 0;
    final selectedKey = _qualityKeys[_qualityIndex];
    _wearOptions = _parseWearOptions(qualityMap[selectedKey]);
  }

  Future<void> _cycleQualityKey() async {
    if (_qualityKeys.length < 2) {
      return;
    }
    final qualityMap = _templateDetail?.qualityMap;
    if (qualityMap == null) {
      return;
    }
    final nextIndex = (_qualityIndex + 1) % _qualityKeys.length;
    final targetKey = _qualityKeys[nextIndex];
    final targetOptions = _parseWearOptions(qualityMap[targetKey]);
    if (targetOptions.isEmpty) {
      setState(() {
        _qualityIndex = nextIndex;
        _wearOptions = targetOptions;
      });
      return;
    }
    final currentExteriorLabel = _templateDetail
        ?.schema
        ?.tags
        ?.exterior
        ?.localizedName
        ?.trim();
    final matchedOption =
        _matchWearOptionByExterior(targetOptions, currentExteriorLabel) ??
        targetOptions.first;
    await _selectWear(
      matchedOption.id,
      optimisticQualityIndex: nextIndex,
      optimisticWearOptions: targetOptions,
    );
  }

  Future<void> _selectWear(
    int schemaId, {
    int? optimisticQualityIndex,
    List<_WearOption>? optimisticWearOptions,
  }) async {
    final currentSchemaId =
        _templateDetail?.schema?.schemaId ?? controller.schemaId;
    if (_pendingWearSchemaId == schemaId) {
      return;
    }
    if (_pendingWearSchemaId != null && currentSchemaId == schemaId) {
      _templateRequestSerial++;
      setState(() {
        _pendingWearSchemaId = null;
        _loadingTemplate = false;
      });
      return;
    }
    if (currentSchemaId == schemaId) {
      return;
    }

    final previousQualityIndex = _qualityIndex;
    final previousWearOptions = List<_WearOption>.of(_wearOptions);

    if (mounted) {
      setState(() {
        _pendingWearSchemaId = schemaId;
        if (optimisticQualityIndex != null) {
          _qualityIndex = optimisticQualityIndex;
        }
        if (optimisticWearOptions != null) {
          _wearOptions = optimisticWearOptions;
        }
      });
    }

    try {
      await _loadTemplate(schemaId: schemaId);
    } finally {
      if (mounted) {
        final resolvedSchemaId =
            _templateDetail?.schema?.schemaId ?? controller.schemaId;
        setState(() {
          if (_pendingWearSchemaId != schemaId) {
            return;
          }
          _pendingWearSchemaId = null;
          if (resolvedSchemaId != schemaId) {
            _qualityIndex = previousQualityIndex;
            _wearOptions = previousWearOptions;
          }
        });
      }
    }
  }

  Future<void> _toggleCollection() async {
    if (_collectionSubmitting) {
      return;
    }
    if (UserStorage.getUserInfo() == null) {
      await Get.toNamed(Routers.LOGIN);
      return;
    }
    final schemaId = controller.schemaId ?? _templateDetail?.schema?.schemaId;
    if (schemaId == null) {
      AppSnackbar.error('app.trade.filter.failed'.tr);
      return;
    }
    final isCollected = _templateDetail?.isCollected == true;
    setState(() => _collectionSubmitting = true);
    try {
      final res = isCollected
          ? await _marketApi.removeCollection(schemaId: schemaId)
          : await _marketApi.addCollection(
              appId: controller.appId,
              schemaId: schemaId,
            );
      if (!res.success) {
        AppSnackbar.error(
          res.message.isNotEmpty ? res.message : 'app.trade.filter.failed'.tr,
        );
        return;
      }
      final detail = _templateDetail;
      if (detail != null) {
        _templateDetail = MarketTemplateDetail(
          schema: detail.schema,
          qualityMap: detail.qualityMap,
          paintKits: detail.paintKits,
          isCollected: !isCollected,
        );
      }
      if (mounted) {
        setState(() {});
      }
      AppSnackbar.success(
        (!isCollected
                ? 'app.user.collection.message.success'
                : 'app.user.collection.uncollect_success')
            .tr,
      );
    } catch (_) {
      AppSnackbar.error('app.trade.filter.failed'.tr);
    } finally {
      if (mounted) {
        setState(() => _collectionSubmitting = false);
      }
    }
  }

  List<_WearOption> _parseWearOptions(dynamic raw) {
    if (raw is! List) {
      return <_WearOption>[];
    }
    final options = <_WearOption>[];
    for (final item in raw) {
      if (item is Map) {
        final id = _asInt(item['id']);
        final label = item['label']?.toString();
        final price = item['price'];
        if (id != null && label != null) {
          options.add(_WearOption(id: id, label: label, price: price));
        }
      }
    }
    return options;
  }

  _WearOption? _matchWearOptionByExterior(
    List<_WearOption> options,
    String? exteriorLabel,
  ) {
    final normalizedExterior = _normalizeWearLabel(exteriorLabel);
    if (normalizedExterior == null) {
      return null;
    }
    for (final option in options) {
      final normalizedLabel = _normalizeWearLabel(option.label);
      if (normalizedLabel == null) {
        continue;
      }
      if (normalizedLabel.contains(normalizedExterior) ||
          normalizedExterior.contains(normalizedLabel)) {
        return option;
      }
    }
    return null;
  }

  String? _normalizeWearLabel(String? value) {
    if (value == null) {
      return null;
    }
    final normalized = value.trim().toLowerCase();
    if (normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  MarketItemEntity _mapTemplateToItem(MarketTemplateSchema schema) {
    return MarketItemEntity(
      id: schema.schemaId,
      schemaId: schema.schemaId,
      appId: schema.appId,
      marketName: schema.marketName,
      marketHashName: schema.marketHashName,
      imageUrl: schema.imageUrl,
      marketPrice: schema.referencePrice,
      sellNum: schema.sellNum,
      tags: schema.tags,
    );
  }

  Widget _buildFigmaTopSection({
    required CurrencyController currency,
    required MarketItemEntity item,
    required String displayName,
    required String displayImage,
    required double referencePrice,
    required int? sellNum,
    required int? buyNum,
    required MarketItemTags? displayTags,
  }) {
    return Container(
      width: double.infinity,
      color: _figmaSlate900,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildFigmaHeaderImage(
                itemId: item.id,
                imageUrl: displayImage,
                backgroundAsset: _figmaItemBackgroundAsset(
                  displayTags?.rarity?.color,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildFigmaHeaderMeta(
                  currency: currency,
                  displayName: displayName,
                  displayTags: displayTags,
                  referencePrice: referencePrice,
                ),
              ),
            ],
          ),
          if (_wearOptions.isNotEmpty) ...[
            const SizedBox(height: 6),
            _buildWearList(currency),
          ],
          const SizedBox(height: 6),
          _buildFigmaStatsAndActions(sellNum: sellNum, buyNum: buyNum),
        ],
      ),
    );
  }

  Widget _buildFigmaHeaderImage({
    required int? itemId,
    required String imageUrl,
    required String backgroundAsset,
  }) {
    return Container(
      width: 92,
      height: 68,
      decoration: BoxDecoration(
        color: _figmaSlate800,
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              backgroundAsset,
              fit: BoxFit.cover,
              errorBuilder: (context, _, __) =>
                  Container(color: _figmaSlate800),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.18),
              ),
            ),
          ),
          Positioned.fill(
            child: Center(
              child: Hero(
                tag: 'market_item_$itemId',
                child: imageUrl.isEmpty
                    ? Icon(
                        Icons.image_not_supported_outlined,
                        color: Colors.white.withValues(alpha: 0.4),
                        size: 22,
                      )
                    : CachedNetworkImage(
                        imageUrl: imageUrl,
                        width: 78,
                        height: 78,
                        fit: BoxFit.contain,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFigmaHeaderMeta({
    required CurrencyController currency,
    required String displayName,
    required MarketItemTags? displayTags,
    required double referencePrice,
  }) {
    final plainTags = _buildFigmaPlainTags(displayTags);
    final rarityName = _cleanText(displayTags?.rarity?.localizedName);
    final rarityColor =
        _parseHex(displayTags?.rarity?.color) ?? const Color(0xFF8847FF);
    final rarityTextColor = Color.lerp(rarityColor, Colors.white, 0.35)!;

    return SizedBox(
      height: 68,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            displayName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              height: 16 / 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 4,
            runSpacing: 2,
            children: [
              Text(_figmaReferencePriceLabel, style: _figmaMetaPrefixTextStyle),
              Obx(
                () => Text(
                  currency.format(referencePrice),
                  style: const TextStyle(
                    color: _figmaOrange,
                    fontSize: 14,
                    height: 16 / 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(
            height: 14,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  Text(
                    _figmaAttributePrefixLabel,
                    style: _figmaMetaPrefixTextStyle,
                  ),
                  if (rarityName != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: rarityColor.withValues(alpha: 0.20),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: Text(
                        rarityName,
                        style: TextStyle(
                          color: rarityTextColor,
                          fontSize: 8,
                          height: 10 / 8,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  for (final tag in plainTags) ...[
                    const SizedBox(width: 6),
                    Text(
                      tag,
                      style: const TextStyle(
                        color: _figmaSlate400,
                        fontSize: 8,
                        height: 10 / 8,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<String> _buildFigmaPlainTags(MarketItemTags? tags) {
    if (tags == null) {
      return const <String>[];
    }
    if (controller.appId == 570) {
      return <String>[
        if (_cleanText(tags.slot?.localizedName) case final slot?) slot,
        if (_cleanText(tags.type?.localizedName) case final type?) type,
      ];
    }
    return <String>[
      if (_cleanText(tags.quality?.localizedName) case final quality?) quality,
      if (_cleanText(tags.type?.localizedName) case final type?) type,
    ];
  }

  Widget _buildFigmaStatsAndActions({
    required int? sellNum,
    required int? buyNum,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 340;
        final dividerSpacing = compact ? 5.0 : 10.0;
        final sectionGap = compact ? 4.0 : 5.0;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              flex: compact ? 9 : 8,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: _buildFigmaStatBlock(
                      value: _formatFigmaCounter(sellNum),
                      label: _figmaListedLabel,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 18,
                    margin: EdgeInsets.symmetric(horizontal: dividerSpacing),
                    color: Colors.white.withValues(alpha: 0.10),
                  ),
                  Expanded(
                    child: _buildFigmaStatBlock(
                      value: _formatFigmaCounter(buyNum),
                      label: _figmaBuyOrdersLabel,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: sectionGap),
            Expanded(
              flex: compact ? 11 : 10,
              child: Row(
                children: [
                  Expanded(
                    child: _buildFigmaActionButton(
                      label: _figmaBuyOrderButtonLabel,
                      onTap: _openBuying,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: _buildFigmaActionButton(
                      label: _figmaBulkBuyButtonLabel,
                      isPrimary: true,
                      onTap: _openBulkBuying,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFigmaStatBlock({required String value, required String label}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          height: 14,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                height: 14 / 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(height: 0.25),
        SizedBox(
          height: 9,
          child: FittedBox(
            alignment: Alignment.center,
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _figmaSlate400,
                fontSize: 7,
                height: 8 / 7,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFigmaActionButton({
    required String label,
    required VoidCallback onTap,
    bool isPrimary = false,
  }) {
    final buttonChild = SizedBox(
      height: 28,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 8.5,
                height: 9 / 8.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );

    if (isPrimary) {
      return _PressableScale(
        onTap: onTap,
        borderRadius: BorderRadius.circular(7),
        overlayColor: Colors.white.withValues(alpha: 0.10),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(7),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[_figmaBlue700, _figmaBlue500],
            ),
            boxShadow: [
              BoxShadow(
                color: _figmaBlue700.withValues(alpha: 0.20),
                blurRadius: 7,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: buttonChild,
        ),
      );
    }

    return _PressableScale(
      onTap: onTap,
      borderRadius: BorderRadius.circular(7),
      overlayColor: Colors.white.withValues(alpha: 0.12),
      child: Ink(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(7),
        ),
        child: buttonChild,
      ),
    );
  }

  String _formatFigmaCounter(int? value) {
    if (value == null) {
      return '--';
    }
    if (value > 999) {
      return '1000+';
    }
    return value.toString();
  }

  String _figmaItemBackgroundAsset(String? color) {
    final normalized = (color ?? 'b0c3d9').replaceAll('#', '').toLowerCase();
    return 'assets/images/game/item/$normalized.png';
  }

  bool get _isEnglishLocale =>
      (Get.locale?.languageCode.toLowerCase() ?? '') == 'en';

  bool get _usesWideColon {
    final languageCode = (Get.locale?.languageCode ?? '').toLowerCase();
    return languageCode == 'zh' || languageCode == 'ja';
  }

  String get _figmaMetaLabelColon => _usesWideColon ? '：' : ':';

  TextStyle get _figmaMetaPrefixTextStyle => const TextStyle(
    color: _figmaSlate400,
    fontSize: 8,
    height: 10 / 8,
    fontWeight: FontWeight.w600,
  );

  String get _figmaPageTitle =>
      _isEnglishLocale ? 'Market Details' : 'app.market.product.details'.tr;

  String get _figmaReferencePriceLabel =>
      '${'app.market.detail.steam_price'.tr}$_figmaMetaLabelColon';

  String get _figmaAttributePrefixLabel =>
      '${'app.market.detail.attribute'.tr}$_figmaMetaLabelColon';

  String get _figmaListedLabel =>
      _isEnglishLocale ? 'LISTED' : 'app.trade.onSale.text'.tr;

  String get _figmaBuyOrdersLabel =>
      _isEnglishLocale ? 'BUY ORDERS' : 'app.trade.purchase.text'.tr;

  String get _figmaBuyOrderButtonLabel =>
      _isEnglishLocale ? 'Buy Order' : 'app.market.detail.release_purchase'.tr;

  String get _figmaBulkBuyButtonLabel =>
      _isEnglishLocale ? 'Bulk Buy' : 'app.market.detail.bulk_buying.title'.tr;

  String get _figmaListingsTabLabel =>
      _isEnglishLocale ? 'Listings' : 'app.trade.onSale.text'.tr;

  String get _figmaTabBuyOrdersLabel =>
      _isEnglishLocale ? 'Buy Orders' : 'app.trade.purchase.text'.tr;

  String get _figmaHistoryTabLabel =>
      _isEnglishLocale ? 'History' : 'app.market.detail.trade_record'.tr;

  String get _figmaTrendTabLabel =>
      _isEnglishLocale ? 'Trend' : 'app.market.detail.price_trend.title'.tr;

  String get _figmaToolbarFloatLabel =>
      _isEnglishLocale ? 'Wear' : 'app.market.filter.csgo.wear_interval'.tr;

  String get _figmaToolbarPhaseLabel =>
      _isEnglishLocale ? 'Phase' : 'app.market.filter.selection_phase'.tr;

  String get _figmaQuantityTitle =>
      _isEnglishLocale ? 'Quantity' : 'app.inventory.count'.tr;

  String get _figmaWearTitle => _isEnglishLocale ? 'Wear' : '磨损';

  String get _figmaAcceptedPatternsTitle =>
      _isEnglishLocale ? 'Accepted Patterns' : '接受图案';

  String get _figmaNoRequirementTitle =>
      _isEnglishLocale ? 'No requirement' : '无要求';

  String get _figmaBuyerFallbackName => _isEnglishLocale ? 'Buyer' : '买家';

  Widget _buildTopNavButton({
    required Widget child,
    required VoidCallback? onPressed,
    required bool collapsed,
    required bool isDark,
    String? tooltip,
  }) {
    final button = SizedBox(
      width: 34,
      height: 34,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onPressed,
          child: Center(child: child),
        ),
      ),
    );

    final wrapped = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: button,
    );
    if (tooltip == null || tooltip.isEmpty) {
      return wrapped;
    }
    return Tooltip(message: tooltip, child: wrapped);
  }

  Widget _buildTopToolbarTextAction({
    required String label,
    required Color color,
    IconData? icon,
    double iconSize = 14,
    VoidCallback? onTap,
    Key? actionKey,
  }) {
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: color,
            fontSize: 11,
            height: 14 / 11,
            fontWeight: FontWeight.w500,
          ),
        ),
        if (icon != null) ...[
          const SizedBox(width: 1),
          Icon(icon, size: iconSize, color: color),
        ],
      ],
    );
    if (onTap == null) {
      return content;
    }
    return _PressableScale(
      key: actionKey,
      onTap: onTap,
      borderRadius: BorderRadius.circular(7),
      overlayColor: color.withValues(alpha: 0.12),
      minScale: 0.97,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 0),
        child: content,
      ),
    );
  }

  Widget _buildTopToolbarSortAction({
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return _buildTopToolbarTextAction(
      actionKey: _onSaleSortButtonKey,
      label: label,
      color: color,
      icon: Icons.keyboard_arrow_down_rounded,
      iconSize: 13,
      onTap: onTap,
    );
  }

  Widget _buildTopToolbarIconButton({
    required Widget child,
    required Color backgroundColor,
    required BorderRadius borderRadius,
    required VoidCallback? onTap,
    VoidCallback? onLongPress,
    String? tooltip,
  }) {
    final button = _PressableScale(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: borderRadius,
      overlayColor: _figmaSlate800.withValues(alpha: 0.08),
      minScale: 0.94,
      child: Ink(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: borderRadius,
        ),
        child: SizedBox(width: 28, height: 28, child: child),
      ),
    );
    if (tooltip == null || tooltip.isEmpty) {
      return button;
    }
    return Tooltip(message: tooltip, child: button);
  }

  @override
  Widget build(BuildContext context) {
    final item = controller.item;
    final currency = Get.find<CurrencyController>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final templateSchema = _templateDetail?.schema;
    final displayTags = templateSchema?.tags ?? item.tags;
    final displayName = templateSchema?.marketName ?? item.marketName ?? '';
    final displayImage = templateSchema?.imageUrl ?? item.imageUrl ?? '';
    final referencePrice =
        templateSchema?.referencePrice ?? item.marketPrice ?? 0;
    final sellNum = templateSchema?.sellNum;
    final buyNum = templateSchema?.buyNum;
    const tabBarHeight = 38.0;
    const navIconColor = _figmaBlue700;
    final tabBar = Container(
      height: tabBarHeight,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _figmaSlate100)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: TabBar(
        controller: _tabController,
        dividerColor: Colors.transparent,
        padding: EdgeInsets.zero,
        indicatorPadding: EdgeInsets.zero,
        labelPadding: EdgeInsets.zero,
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: _figmaBlue700,
        unselectedLabelColor: _figmaSlate500,
        labelStyle: const TextStyle(
          fontSize: 12,
          height: 16 / 12,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 12,
          height: 16 / 12,
          fontWeight: FontWeight.w600,
        ),
        overlayColor: WidgetStateProperty.resolveWith<Color?>((states) {
          if (states.contains(WidgetState.pressed)) {
            return _figmaBlue700.withValues(alpha: 0.08);
          }
          if (states.contains(WidgetState.hovered)) {
            return _figmaBlue700.withValues(alpha: 0.04);
          }
          return null;
        }),
        indicator: const UnderlineTabIndicator(
          borderSide: BorderSide(color: _figmaBlue700, width: 2.5),
          insets: EdgeInsets.symmetric(horizontal: 16),
        ),
        tabs: [
          Tab(text: _figmaListingsTabLabel),
          Tab(text: _figmaTabBuyOrdersLabel),
          Tab(text: _figmaHistoryTabLabel),
          Tab(text: _figmaTrendTabLabel),
        ],
      ),
    );
    final fixedTabBar = LayoutBuilder(
      builder: (context, constraints) {
        final dragWidth = constraints.maxWidth;
        final maxIndex = (_tabController.length - 1).toDouble();

        void settleToClosestTab() {
          if (_tabController.indexIsChanging) {
            return;
          }
          final value =
              _tabController.animation?.value ??
              _tabController.index.toDouble();
          final targetIndex = value.round().clamp(0, _tabController.length - 1);
          if (targetIndex == _tabController.index) {
            _tabController.offset = 0;
            return;
          }
          _tabController.animateTo(
            targetIndex,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
          );
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragUpdate: (details) {
            if (_tabController.indexIsChanging || dragWidth <= 0) {
              return;
            }
            final currentValue =
                _tabController.animation?.value ??
                _tabController.index.toDouble();
            final nextValue = (currentValue - (details.delta.dx / dragWidth))
                .clamp(0.0, maxIndex)
                .toDouble();
            final nextOffset = (nextValue - _tabController.index)
                .clamp(-1.0, 1.0)
                .toDouble();
            if (nextOffset >= 0.98 &&
                _tabController.index < _tabController.length - 1) {
              _tabController.index = _tabController.index + 1;
              _tabController.offset = 0;
              return;
            }
            if (nextOffset <= -0.98 && _tabController.index > 0) {
              _tabController.index = _tabController.index - 1;
              _tabController.offset = 0;
              return;
            }
            _tabController.offset = nextOffset;
          },
          onHorizontalDragEnd: (_) => settleToClosestTab(),
          onHorizontalDragCancel: settleToClosestTab,
          child: tabBar,
        );
      },
    );

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF1B1C20)
          : _figmaPageCoolBackground,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark,
        child: SafeArea(
          bottom: false,
          child: BackToTopScope(
            enabled: false,
            child: Column(
              children: [
                SettingsStyleInlineTopBar(
                  title: _figmaPageTitle,
                  actions: [
                    _buildTopNavButton(
                      collapsed: false,
                      isDark: false,
                      onPressed: _collectionSubmitting
                          ? null
                          : _toggleCollection,
                      tooltip: _templateDetail?.isCollected == true
                          ? 'app.user.collection.uncollect'.tr
                          : null,
                      child: _collectionSubmitting
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: navIconColor,
                              ),
                            )
                          : Icon(
                              _templateDetail?.isCollected == true
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              color: navIconColor,
                              size: 18,
                            ),
                    ),
                  ],
                ),
                _buildFigmaTopSection(
                  currency: currency,
                  item: item,
                  displayName: displayName,
                  displayImage: displayImage,
                  referencePrice: referencePrice,
                  sellNum: sellNum,
                  buyNum: buyNum,
                  displayTags: displayTags,
                ),
                fixedTabBar,
                if (_topActionToolbarHeight > 0 || _showTopActionToolbar)
                  SizedBox(
                    height: _topActionToolbarHeight,
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: _buildTopActionToolbar(),
                    ),
                  ),
                Expanded(
                  child: Container(
                    color: isDark
                        ? const Color(0xFF1B1C20)
                        : _figmaPageCoolBackground,
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildOnSaleTab(currency),
                        _buildBuyRequestTab(currency),
                        _buildTransactionTab(currency),
                        _buildPriceTrendTab(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInnerScrollView({
    required BuildContext context,
    required String storageKey,
    required List<Widget> children,
    EdgeInsets padding = EdgeInsets.zero,
    Future<void> Function()? onRefresh,
    bool Function(ScrollNotification notification)? onScrollNotification,
  }) {
    Widget scrollView = CustomScrollView(
      key: PageStorageKey<String>(storageKey),
      physics: onRefresh == null
          ? const NeverScrollableScrollPhysics()
          : const AlwaysScrollableScrollPhysics(
              parent: ClampingScrollPhysics(),
            ),
      slivers: [
        if (children.isEmpty)
          const SliverToBoxAdapter(child: SizedBox.shrink())
        else
          SliverPadding(
            padding: padding,
            sliver: SliverList(delegate: SliverChildListDelegate(children)),
          ),
      ],
    );
    if (onRefresh != null) {
      scrollView = _buildStyledRefreshIndicator(
        onRefresh: onRefresh,
        child: scrollView,
      );
    }
    if (onScrollNotification != null) {
      scrollView = NotificationListener<ScrollNotification>(
        onNotification: onScrollNotification,
        child: scrollView,
      );
    }
    return scrollView;
  }

  Widget _buildInnerFillRemaining({
    required BuildContext context,
    required String storageKey,
    required Widget child,
    Future<void> Function()? onRefresh,
  }) {
    final scrollView = CustomScrollView(
      key: PageStorageKey<String>(storageKey),
      physics: onRefresh == null
          ? const ClampingScrollPhysics()
          : const AlwaysScrollableScrollPhysics(
              parent: ClampingScrollPhysics(),
            ),
      slivers: [
        SliverFillRemaining(hasScrollBody: false, child: Center(child: child)),
      ],
    );
    if (onRefresh == null) {
      return scrollView;
    }
    return _buildStyledRefreshIndicator(
      onRefresh: onRefresh,
      child: scrollView,
    );
  }

  Widget _buildStyledRefreshIndicator({
    required Future<void> Function() onRefresh,
    required Widget child,
  }) {
    return RefreshIndicator(
      color: _figmaBlue700,
      backgroundColor: Colors.white,
      strokeWidth: 2.2,
      displacement: 22,
      edgeOffset: 2,
      elevation: 0,
      notificationPredicate: (notification) => notification.depth == 0,
      onRefresh: onRefresh,
      child: child,
    );
  }

  int _calculateVerticalLoadingPlaceholderCount(
    BoxConstraints constraints, {
    required EdgeInsets padding,
    required double itemExtent,
    required double spacing,
    int minCount = 3,
    int maxCount = 6,
  }) {
    if (!constraints.hasBoundedHeight) {
      return minCount;
    }
    final contentHeight = constraints.maxHeight - padding.top - padding.bottom;
    final effectiveHeight = contentHeight <= 0 ? itemExtent : contentHeight;
    final rowExtent = itemExtent + spacing;
    final visibleCount = ((effectiveHeight + spacing) / rowExtent).ceil();
    return visibleCount.clamp(minCount, maxCount);
  }

  Widget _buildLoadingPill({
    double? width,
    required double height,
    BorderRadiusGeometry? borderRadius,
    Color color = const Color(0xFFF2F4F6),
  }) {
    final line = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: borderRadius ?? BorderRadius.circular(999),
      ),
    );
    if (width == null) {
      return SizedBox(width: double.infinity, child: line);
    }
    return line;
  }

  Widget _buildMarketOnSaleLoadingCard() {
    return const Padding(
      padding: EdgeInsets.only(bottom: 6),
      child: _MarketOnSaleLoadingCard(),
    );
  }

  Widget _buildMarketBuyRequestLoadingCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120F172A),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  color: Color(0xFFF2F4F6),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(child: _buildLoadingPill(height: 12)),
              const SizedBox(width: 8),
              _buildLoadingPill(
                width: 96,
                height: 28,
                borderRadius: BorderRadius.circular(8),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildLoadingPill(width: 92, height: 18),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F5F8),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLoadingPill(height: 12),
                const SizedBox(height: 8),
                _buildLoadingPill(height: 12),
                const SizedBox(height: 8),
                _buildLoadingPill(width: 136, height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionLoadingSection({required int rowCount}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var index = 0; index < rowCount; index++)
            _buildTransactionLoadingRow(index: index),
        ],
      ),
    );
  }

  Widget _buildTransactionLoadingRow({required int index}) {
    return Container(
      color: _historyRowBackground(index, false),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: Color(0xFFEAF1FF),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLoadingPill(width: 82, height: 16),
                const SizedBox(height: 6),
                _buildLoadingPill(width: 68, height: 11),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _buildLoadingPill(width: 78, height: 12),
        ],
      ),
    );
  }

  Widget _buildOnSaleInitialLoadingView({Future<void> Function()? onRefresh}) {
    const padding = EdgeInsets.fromLTRB(12, 8, 12, 12);
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemCount = _calculateVerticalLoadingPlaceholderCount(
          constraints,
          padding: padding,
          itemExtent: 118,
          spacing: 0,
          minCount: 3,
          maxCount: 6,
        );
        return _buildInnerScrollView(
          context: context,
          storageKey: 'market_detail_on_sale_loading',
          padding: padding,
          children: List<Widget>.generate(
            itemCount,
            (_) => _buildMarketOnSaleLoadingCard(),
          ),
          onRefresh: onRefresh,
        );
      },
    );
  }

  Widget _buildBuyRequestInitialLoadingView({
    Future<void> Function()? onRefresh,
  }) {
    const padding = EdgeInsets.fromLTRB(16, 16, 16, 16);
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemCount = _calculateVerticalLoadingPlaceholderCount(
          constraints,
          padding: padding,
          itemExtent: 142,
          spacing: 12,
          minCount: 2,
          maxCount: 4,
        );
        return _buildInnerScrollView(
          context: context,
          storageKey: 'market_detail_buy_request_loading',
          padding: padding,
          children: List<Widget>.generate(itemCount, (index) {
            return Padding(
              padding: EdgeInsets.only(top: index == 0 ? 0 : 12),
              child: _buildMarketBuyRequestLoadingCard(),
            );
          }),
          onRefresh: onRefresh,
        );
      },
    );
  }

  Widget _buildTransactionInitialLoadingView({
    Future<void> Function()? onRefresh,
  }) {
    const padding = EdgeInsets.fromLTRB(16, 16, 16, 16);
    return LayoutBuilder(
      builder: (context, constraints) {
        final rowCount = _calculateVerticalLoadingPlaceholderCount(
          constraints,
          padding: padding,
          itemExtent: 60,
          spacing: 0,
          minCount: 4,
          maxCount: 8,
        );
        return _buildInnerScrollView(
          context: context,
          storageKey: 'market_detail_transaction_loading',
          padding: padding,
          children: [_buildTransactionLoadingSection(rowCount: rowCount)],
          onRefresh: onRefresh,
        );
      },
    );
  }

  // Widget _buildInspectButton(IconData icon, String label) {
  //   return Container(
  //     padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
  //     decoration: BoxDecoration(
  //       color: Colors.white.withOpacity(0.15),
  //       borderRadius: BorderRadius.circular(4),
  //     ),
  //     child: Row(
  //       mainAxisSize: MainAxisSize.min,
  //       children: [
  //         Icon(icon, color: Colors.white, size: 16),
  //         const SizedBox(width: 4),
  //         Text(
  //           label,
  //           style: const TextStyle(color: Colors.white, fontSize: 12),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  Color? _parseHex(String? hex) {
    if (hex == null || hex.isEmpty) {
      return null;
    }
    final normalized = hex.replaceAll('#', '');
    if (normalized.length == 6) {
      return Color(int.parse('FF$normalized', radix: 16));
    }
    return null;
  }

  String? _cleanText(String? value) {
    if (value == null) {
      return null;
    }
    final trimmed = value.trim();
    if (trimmed.isEmpty || trimmed == 'null') {
      return null;
    }
    return trimmed;
  }

  Widget _buildWearList(CurrencyController currency) {
    final exteriorLabel =
        _templateDetail?.schema?.tags?.exterior?.localizedName;
    final pendingWearSchemaId = _pendingWearSchemaId;
    final activeId = pendingWearSchemaId ?? _templateDetail?.schema?.schemaId;
    final swapLabel = _qualityKeys.isNotEmpty
        ? _qualityKeys[(_qualityIndex + 1) % _qualityKeys.length]
        : null;

    final items = _wearOptions;
    final showSwap = _qualityKeys.length > 1;
    final totalCount = items.length + (showSwap ? 1 : 0);
    return LayoutBuilder(
      builder: (context, constraints) {
        final spacing = totalCount > 1 ? 5.0 * (totalCount - 1) : 0.0;
        final availableWidth = constraints.maxWidth - spacing;
        final targetWidth = totalCount > 0
            ? (availableWidth / totalCount).clamp(70.0, 96.0).toDouble()
            : 78.0;

        return SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: totalCount,
            separatorBuilder: (_, __) => const SizedBox(width: 5),
            itemBuilder: (context, index) {
              if (showSwap && index == items.length) {
                return _buildWearChip(
                  width: targetWidth,
                  label: swapLabel ?? '',
                  price: '',
                  active: false,
                  onTap: _cycleQualityKey,
                  showSwap: true,
                );
              }
              final option = items[index];
              final isActive = pendingWearSchemaId != null
                  ? option.id == pendingWearSchemaId
                  : option.label == exteriorLabel || option.id == activeId;
              return _buildWearChip(
                width: targetWidth,
                label: option.label,
                price: _formatWearPrice(option.price, currency),
                active: isActive,
                onTap: () => _selectWear(option.id),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildWearChip({
    required double width,
    required String label,
    required String price,
    required bool active,
    VoidCallback? onTap,
    bool showSwap = false,
  }) {
    final backgroundColor = active
        ? _figmaBlue700.withValues(alpha: 0.20)
        : Colors.white.withValues(alpha: 0.05);
    final borderColor = active
        ? _figmaBlue700.withValues(alpha: 0.40)
        : Colors.transparent;
    final titleColor = active ? Colors.white : _figmaSlate300;
    final priceColor = active ? Colors.white : _figmaSlate400;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(7),
        onTap: onTap,
        child: Ink(
          width: width,
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                height: 14,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              label,
                              maxLines: 1,
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: titleColor,
                                fontSize: 8,
                                height: 1.0,
                                fontWeight: active
                                    ? FontWeight.w500
                                    : FontWeight.w400,
                              ),
                            ),
                          ),
                        ),
                        if (showSwap) ...[
                          const SizedBox(width: 2),
                          Icon(
                            Icons.swap_horiz_rounded,
                            size: 9,
                            color: titleColor,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              if (price.isNotEmpty)
                Text(
                  price,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: priceColor, fontSize: 8, height: 1.0),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatWearPrice(dynamic price, CurrencyController currency) {
    if (price == null) {
      return '';
    }
    if (price is num) {
      return currency.format(price.toDouble());
    }
    final parsed = double.tryParse(price.toString());
    if (parsed != null) {
      return currency.format(parsed);
    }
    return '${currency.symbol} ${price.toString()}';
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

  String _formatI18nPlaceholder(String template, String value) {
    return template
        .replaceAll('{0}', value)
        .replaceAll('｛0｝', value)
        .replaceAll(r'${0}', value);
  }

  List<_OnSaleSortOption> _buildOnSaleSortOptions() {
    return const <_OnSaleSortOption>[
      _OnSaleSortOption(
        field: null,
        asc: null,
        labelKey: 'app.market.filter.sort',
      ),
      _OnSaleSortOption(
        field: 'hot',
        asc: true,
        labelKey: 'app.market.filter.hot_sorting',
        suffix: '↑',
      ),
      _OnSaleSortOption(
        field: 'hot',
        asc: false,
        labelKey: 'app.market.filter.hot_sorting',
        suffix: '↓',
      ),
      _OnSaleSortOption(
        field: 'price',
        asc: true,
        labelKey: 'app.market.filter.price_sorting',
        suffix: '↑',
      ),
      _OnSaleSortOption(
        field: 'price',
        asc: false,
        labelKey: 'app.market.filter.price_sorting',
        suffix: '↓',
      ),
    ];
  }

  String _formatOnSaleSortLabel(_OnSaleSortOption option) {
    final template = option.labelKey.tr;
    final suffix = option.suffix;
    if (suffix == null || suffix.isEmpty) {
      return template;
    }
    return _formatI18nPlaceholder(template, suffix);
  }

  bool _isSelectedOnSaleSortOption(_OnSaleSortOption option) {
    return option.field == _onSaleSortField && option.asc == _onSaleSortAsc;
  }

  _OnSaleSortOption get _currentOnSaleSortOption {
    final options = _buildOnSaleSortOptions();
    for (final option in options) {
      if (_isSelectedOnSaleSortOption(option)) {
        return option;
      }
    }
    return options.first;
  }

  String get _currentOnSaleSortLabel {
    final option = _currentOnSaleSortOption;
    return _formatOnSaleSortLabel(option);
  }

  Future<void> _selectOnSaleSortOption(_OnSaleSortOption option) async {
    final isSameSelection = _isSelectedOnSaleSortOption(option);
    if (isSameSelection) {
      return;
    }
    setState(() {
      _onSaleSortField = option.field;
      _onSaleSortAsc = option.asc;
    });
    await _applyOnSaleFilterWithCurrentState();
  }

  Future<void> _openOnSaleSortMenu() async {
    if (controller.isLoadingOnSale.value) {
      return;
    }
    final currentContext = _onSaleSortButtonKey.currentContext;
    if (currentContext == null) {
      return;
    }
    final target = currentContext.findRenderObject() as RenderBox?;
    final overlay =
        Overlay.of(currentContext).context.findRenderObject() as RenderBox?;
    if (target == null || overlay == null) {
      return;
    }
    final targetTopLeft = target.localToGlobal(Offset.zero, ancestor: overlay);
    final targetBottomRight = target.localToGlobal(
      target.size.bottomRight(Offset.zero),
      ancestor: overlay,
    );
    final menuPosition = RelativeRect.fromRect(
      Rect.fromLTWH(
        targetTopLeft.dx,
        targetBottomRight.dy + 6,
        target.size.width,
        0,
      ),
      Offset.zero & overlay.size,
    );
    final options = _buildOnSaleSortOptions();
    final selected = await showMenu<_OnSaleSortOption>(
      context: context,
      position: menuPosition,
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 10,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      items: options
          .map((option) {
            final isSelected = _isSelectedOnSaleSortOption(option);
            return PopupMenuItem<_OnSaleSortOption>(
              value: option,
              height: 0,
              padding: EdgeInsets.zero,
              child: Container(
                constraints: const BoxConstraints(minWidth: 124),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? _figmaBlue700.withValues(alpha: 0.06)
                      : Colors.transparent,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _formatOnSaleSortLabel(option),
                        style: TextStyle(
                          color: isSelected ? _figmaBlue700 : _figmaSlate800,
                          fontSize: 13,
                          height: 18 / 13,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                    if (isSelected)
                      const Icon(
                        Icons.check_rounded,
                        size: 16,
                        color: _figmaBlue700,
                      ),
                  ],
                ),
              ),
            );
          })
          .toList(growable: false),
    );
    if (selected == null || !mounted) {
      return;
    }
    await _selectOnSaleSortOption(selected);
  }

  String? get _toolbarWearExteriorKey =>
      _templateDetail?.schema?.tags?.exterior?.key ??
      controller.item.tags?.exterior?.key;

  List<_WearQuickOption> get _toolbarWearQuickOptions =>
      _buildWearQuickOptions(_toolbarWearExteriorKey);

  bool _isSelectedWearQuickOption(_WearQuickOption option) {
    final min = _onSaleWearMin?.toStringAsFixed(2);
    final max = _onSaleWearMax?.toStringAsFixed(2);
    return min == option.minText && max == option.maxText;
  }

  String get _currentWearQuickLabel {
    for (final option in _toolbarWearQuickOptions) {
      if (_isSelectedWearQuickOption(option)) {
        return option.label;
      }
    }
    return _figmaToolbarFloatLabel;
  }

  Future<void> _selectWearQuickOption(_WearQuickOption? option) async {
    final nextMin = option == null ? null : double.tryParse(option.minText);
    final nextMax = option == null ? null : double.tryParse(option.maxText);
    final sameSelection =
        _onSaleWearMin == nextMin && _onSaleWearMax == nextMax;
    if (sameSelection) {
      return;
    }
    setState(() {
      _onSaleWearMin = nextMin;
      _onSaleWearMax = nextMax;
    });
    await _applyOnSaleFilterWithCurrentState();
  }

  Future<void> _openOnSaleWearMenu() async {
    if (controller.isLoadingOnSale.value) {
      return;
    }
    final options = _toolbarWearQuickOptions;
    if (options.isEmpty) {
      return;
    }
    final currentContext = _onSaleWearButtonKey.currentContext;
    if (currentContext == null) {
      return;
    }
    final target = currentContext.findRenderObject() as RenderBox?;
    final overlay =
        Overlay.of(currentContext).context.findRenderObject() as RenderBox?;
    if (target == null || overlay == null) {
      return;
    }
    final targetTopLeft = target.localToGlobal(Offset.zero, ancestor: overlay);
    final targetBottomRight = target.localToGlobal(
      target.size.bottomRight(Offset.zero),
      ancestor: overlay,
    );
    final menuPosition = RelativeRect.fromRect(
      Rect.fromLTWH(
        targetTopLeft.dx,
        targetBottomRight.dy + 6,
        target.size.width,
        0,
      ),
      Offset.zero & overlay.size,
    );

    final selected = await showMenu<_WearQuickMenuSelection>(
      context: context,
      position: menuPosition,
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 10,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      items: [
        PopupMenuItem<_WearQuickMenuSelection>(
          value: _WearQuickMenuSelection.clear(),
          height: 0,
          padding: EdgeInsets.zero,
          child: Container(
            constraints: const BoxConstraints(minWidth: 124),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: (_onSaleWearMin == null && _onSaleWearMax == null)
                  ? _figmaBlue700.withValues(alpha: 0.06)
                  : Colors.transparent,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _figmaToolbarFloatLabel,
                    style: TextStyle(
                      color: (_onSaleWearMin == null && _onSaleWearMax == null)
                          ? _figmaBlue700
                          : _figmaSlate800,
                      fontSize: 13,
                      height: 18 / 13,
                      fontWeight:
                          (_onSaleWearMin == null && _onSaleWearMax == null)
                          ? FontWeight.w600
                          : FontWeight.w500,
                    ),
                  ),
                ),
                if (_onSaleWearMin == null && _onSaleWearMax == null)
                  const Icon(
                    Icons.check_rounded,
                    size: 16,
                    color: _figmaBlue700,
                  ),
              ],
            ),
          ),
        ),
        ...options.map((option) {
          final isSelected = _isSelectedWearQuickOption(option);
          return PopupMenuItem<_WearQuickMenuSelection>(
            value: _WearQuickMenuSelection(option),
            height: 0,
            padding: EdgeInsets.zero,
            child: Container(
              constraints: const BoxConstraints(minWidth: 124),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isSelected
                    ? _figmaBlue700.withValues(alpha: 0.06)
                    : Colors.transparent,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      option.label,
                      style: TextStyle(
                        color: isSelected ? _figmaBlue700 : _figmaSlate800,
                        fontSize: 13,
                        height: 18 / 13,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                  if (isSelected)
                    const Icon(
                      Icons.check_rounded,
                      size: 16,
                      color: _figmaBlue700,
                    ),
                ],
              ),
            ),
          );
        }),
      ],
    );
    if (selected == null || !mounted) {
      return;
    }
    await _selectWearQuickOption(selected.option);
  }

  List<_PaintKitOption> get _toolbarPhaseOptions => _buildPaintKitOptions();

  String get _defaultToolbarPhaseLabel {
    if (_toolbarPhaseOptions.isEmpty) {
      return _figmaToolbarPhaseLabel;
    }
    return 'app.market.csgo.phase_unlimited'.tr;
  }

  String get _currentToolbarPhaseLabel {
    if (_toolbarPhaseOptions.isEmpty) {
      return _figmaToolbarPhaseLabel;
    }
    for (final option in _toolbarPhaseOptions) {
      if (option.id == _onSalePaintIndex) {
        return option.label;
      }
    }
    return _defaultToolbarPhaseLabel;
  }

  Future<void> _selectOnSalePhaseOption(_PaintKitOption? option) async {
    final nextPaintIndex = option?.id;
    if (nextPaintIndex == _onSalePaintIndex) {
      return;
    }
    setState(() => _onSalePaintIndex = nextPaintIndex);
    await _applyOnSaleFilterWithCurrentState();
  }

  Future<void> _openOnSalePhaseMenu() async {
    if (controller.isLoadingOnSale.value) {
      return;
    }
    final options = _toolbarPhaseOptions;
    if (options.isEmpty) {
      return;
    }
    final currentContext = _onSalePhaseButtonKey.currentContext;
    if (currentContext == null) {
      return;
    }
    final target = currentContext.findRenderObject() as RenderBox?;
    final overlay =
        Overlay.of(currentContext).context.findRenderObject() as RenderBox?;
    if (target == null || overlay == null) {
      return;
    }
    final targetTopLeft = target.localToGlobal(Offset.zero, ancestor: overlay);
    final targetBottomRight = target.localToGlobal(
      target.size.bottomRight(Offset.zero),
      ancestor: overlay,
    );
    final menuPosition = RelativeRect.fromRect(
      Rect.fromLTWH(
        targetTopLeft.dx,
        targetBottomRight.dy + 6,
        target.size.width,
        0,
      ),
      Offset.zero & overlay.size,
    );

    final selected = await showMenu<_PhaseMenuSelection>(
      context: context,
      position: menuPosition,
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 10,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      items: [
        PopupMenuItem<_PhaseMenuSelection>(
          value: _PhaseMenuSelection.clear(),
          height: 0,
          padding: EdgeInsets.zero,
          child: Container(
            constraints: const BoxConstraints(minWidth: 156),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: _onSalePaintIndex == null
                  ? _figmaBlue700.withValues(alpha: 0.06)
                  : Colors.transparent,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _defaultToolbarPhaseLabel,
                    style: TextStyle(
                      color: _onSalePaintIndex == null
                          ? _figmaBlue700
                          : _figmaSlate800,
                      fontSize: 13,
                      height: 18 / 13,
                      fontWeight: _onSalePaintIndex == null
                          ? FontWeight.w600
                          : FontWeight.w500,
                    ),
                  ),
                ),
                if (_onSalePaintIndex == null)
                  const Icon(
                    Icons.check_rounded,
                    size: 16,
                    color: _figmaBlue700,
                  ),
              ],
            ),
          ),
        ),
        ...options.map((option) {
          final isSelected = option.id == _onSalePaintIndex;
          return PopupMenuItem<_PhaseMenuSelection>(
            value: _PhaseMenuSelection(option),
            height: 0,
            padding: EdgeInsets.zero,
            child: Container(
              constraints: const BoxConstraints(minWidth: 156),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isSelected
                    ? _figmaBlue700.withValues(alpha: 0.06)
                    : Colors.transparent,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      option.label,
                      style: TextStyle(
                        color: isSelected ? _figmaBlue700 : _figmaSlate800,
                        fontSize: 13,
                        height: 18 / 13,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                  if (isSelected)
                    const Icon(
                      Icons.check_rounded,
                      size: 16,
                      color: _figmaBlue700,
                    ),
                ],
              ),
            ),
          );
        }),
      ],
    );
    if (selected == null || !mounted) {
      return;
    }
    await _selectOnSalePhaseOption(selected.option);
  }

  Future<void> _applyOnSaleFilterWithCurrentState({
    bool preserveVisibleItems = false,
  }) {
    return controller.applyOnSaleFilter(
      sortField: _onSaleSortField,
      sortAsc: _onSaleSortAsc,
      minPrice: _onSaleMinPrice,
      maxPrice: _onSaleMaxPrice,
      paintSeed: _onSalePaintSeed,
      paintIndex: _onSalePaintIndex,
      paintWearMin: _onSaleWearMin,
      paintWearMax: _onSaleWearMax,
      preserveVisibleItems: preserveVisibleItems,
    );
  }

  Future<void> _refreshOnSaleList() async {
    if (controller.isLoadingOnSale.value) {
      return;
    }
    await _applyOnSaleFilterWithCurrentState(preserveVisibleItems: true);
  }

  Future<void> _refreshBuyRequestList() async {
    if (controller.isLoadingBuyRequests.value) {
      return;
    }
    await controller.loadBuyRequests(reset: true, preserveVisibleItems: true);
  }

  Future<void> _refreshTransactionList() async {
    if (controller.isLoadingTransactions.value) {
      return;
    }
    await controller.loadTransactions(reset: true, preserveVisibleItems: true);
  }

  bool _handleLoadMoreScrollNotification(
    ScrollNotification notification,
    Future<void> Function() onLoadMore,
  ) {
    if (notification.depth != 0) {
      return false;
    }
    final metrics = notification.metrics;
    if (metrics.axis != Axis.vertical || metrics.maxScrollExtent <= 0) {
      return false;
    }
    if (metrics.pixels >= metrics.maxScrollExtent - 240) {
      onLoadMore();
    }
    return false;
  }

  Future<void> _loadMoreOnSaleList() async {
    if (controller.isLoadingOnSale.value || !controller.onSaleHasMore) {
      return;
    }
    await controller.loadOnSale();
  }

  Future<void> _loadMoreBuyRequestList() async {
    if (controller.isLoadingBuyRequests.value ||
        !controller.buyRequestHasMore) {
      return;
    }
    await controller.loadBuyRequests();
  }

  Future<void> _loadMoreTransactionList() async {
    if (controller.isLoadingTransactions.value ||
        !controller.transactionHasMore) {
      return;
    }
    await controller.loadTransactions();
  }

  bool _onSaleScrollNotification(ScrollNotification notification) {
    return _handleLoadMoreScrollNotification(notification, _loadMoreOnSaleList);
  }

  bool _buyRequestScrollNotification(ScrollNotification notification) {
    return _handleLoadMoreScrollNotification(
      notification,
      _loadMoreBuyRequestList,
    );
  }

  bool _transactionScrollNotification(ScrollNotification notification) {
    return _handleLoadMoreScrollNotification(
      notification,
      _loadMoreTransactionList,
    );
  }

  double get _tabAnimationValue {
    final raw = _tabController.animation?.value ?? _currentTabIndex.toDouble();
    return raw.clamp(0.0, (_tabController.length - 1).toDouble()).toDouble();
  }

  double get _topActionToolbarProgress {
    return (1.0 - _tabAnimationValue).clamp(0.0, 1.0).toDouble();
  }

  double get _topActionToolbarHeight =>
      _topActionToolbarMaxHeight * _topActionToolbarProgress;

  bool get _showTopActionToolbar => _topActionToolbarHeight > 0.001;

  double get _topFilterButtonProgress {
    if (!_showOnSaleFilter) {
      return 0;
    }
    return (1.0 - _tabAnimationValue.abs()).clamp(0.0, 1.0).toDouble();
  }

  bool get _isToolbarInteractive => _topActionToolbarProgress > 0.98;

  Widget _buildTopActionToolbar() {
    final toolbarProgress = _topActionToolbarProgress;
    final quickFilterColor = _figmaSlate500;
    final quickFilterActiveColor = _figmaBlue700;
    final actionButtonBackground = _figmaSlate100;
    final actionBorderRadius = BorderRadius.circular(8);
    final showWearQuickFilter = _toolbarWearQuickOptions.isNotEmpty;
    final showPhaseQuickFilter = _toolbarPhaseOptions.isNotEmpty;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 2, 12, 2),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _figmaSlate100)),
      ),
      child: IgnorePointer(
        ignoring: !_isToolbarInteractive,
        child: Opacity(
          opacity: toolbarProgress,
          child: SizedBox(
            height: 26,
            child: Row(
              children: [
                Expanded(
                  child: ClipRect(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      widthFactor: _topFilterButtonProgress,
                      child: Opacity(
                        opacity: _topFilterButtonProgress,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildTopToolbarSortAction(
                                label: _currentOnSaleSortLabel,
                                color: _hasOnSaleSort
                                    ? quickFilterActiveColor
                                    : quickFilterColor,
                                onTap: _openOnSaleSortMenu,
                              ),
                              if (showWearQuickFilter) ...[
                                const SizedBox(width: 18),
                                _buildTopToolbarTextAction(
                                  actionKey: _onSaleWearButtonKey,
                                  label: _currentWearQuickLabel,
                                  color: _hasOnSaleWear
                                      ? quickFilterActiveColor
                                      : quickFilterColor,
                                  icon: Icons.keyboard_arrow_down_rounded,
                                  iconSize: 13,
                                  onTap: _openOnSaleWearMenu,
                                ),
                              ],
                              if (showPhaseQuickFilter) ...[
                                SizedBox(width: showWearQuickFilter ? 14 : 18),
                                _buildTopToolbarTextAction(
                                  actionKey: _onSalePhaseButtonKey,
                                  label: _currentToolbarPhaseLabel,
                                  color: _onSalePaintIndex != null
                                      ? quickFilterActiveColor
                                      : quickFilterColor,
                                  icon: Icons.keyboard_arrow_down_rounded,
                                  iconSize: 13,
                                  onTap: _openOnSalePhaseMenu,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                ClipRect(
                  child: Align(
                    alignment: Alignment.centerRight,
                    widthFactor: _topFilterButtonProgress,
                    child: IgnorePointer(
                      ignoring: _topFilterButtonProgress < 0.98,
                      child: Opacity(
                        opacity: _topFilterButtonProgress,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(width: 4),
                            _buildTopToolbarIconButton(
                              tooltip: 'app.market.filter.text'.tr,
                              backgroundColor: actionButtonBackground,
                              borderRadius: actionBorderRadius,
                              onTap: () {
                                if (controller.isLoadingOnSale.value) {
                                  return;
                                }
                                _openOnSaleFilterSheet();
                              },
                              onLongPress: () {
                                if (controller.isLoadingOnSale.value ||
                                    !_hasOnSaleFilter) {
                                  return;
                                }
                                _clearOnSaleFilter();
                              },
                              child: Stack(
                                children: [
                                  Center(
                                    child: _TopToolbarFilterGlyph(
                                      color: _hasOnSaleFilter
                                          ? quickFilterActiveColor
                                          : _figmaSlate800,
                                    ),
                                  ),
                                  if (_hasOnSaleFilter)
                                    Positioned(
                                      right: 6,
                                      top: 6,
                                      child: Container(
                                        width: 5,
                                        height: 5,
                                        decoration: const BoxDecoration(
                                          color: _figmaBlue500,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOnSaleTab(CurrencyController currency) {
    return BackToTopScope(
      enabled: true,
      overlayBottomPadding: _detailListBackToTopBottomPadding,
      child: Obx(() {
        final isLoading = controller.isLoadingOnSale.value;
        final isRefreshing = controller.isRefreshingOnSale.value;
        final items = controller.onSaleItems.toList(growable: false);
        final users = Map<String, MarketUserInfo>.from(controller.users);
        final showLoadingFooter =
            isLoading && items.isNotEmpty && !isRefreshing;
        final showNoMoreFooter =
            items.isNotEmpty && !isLoading && !controller.onSaleHasMore;
        final showFooter = showLoadingFooter || showNoMoreFooter;

        return Builder(
          builder: (context) {
            if (isRefreshing) {
              return _buildOnSaleInitialLoadingView();
            }
            if (isLoading && items.isEmpty) {
              return _buildOnSaleInitialLoadingView();
            }
            if (items.isEmpty) {
              return _buildInnerFillRemaining(
                context: context,
                storageKey: 'market_detail_on_sale_empty',
                child: Text('app.common.no_data'.tr),
                onRefresh: _refreshOnSaleList,
              );
            }

            final children = <Widget>[];
            for (var index = 0; index < items.length; index++) {
              final item = items[index];
              final user = users[item.userId?.toString() ?? ''];
              children.add(_buildItemCard(item, user, currency));
            }

            if (showFooter) {
              if (showLoadingFooter) {
                for (
                  var index = 0;
                  index < _detailOnSaleLoadMorePlaceholderCount;
                  index++
                ) {
                  children.add(_buildMarketOnSaleLoadingCard());
                }
              } else if (children.isNotEmpty) {
                children.add(const SizedBox(height: 8));
                children.add(
                  _buildLoadMoreFooter(
                    showLoading: false,
                    showNoMore: showNoMoreFooter,
                  ),
                );
              }
            }

            return _buildInnerScrollView(
              context: context,
              storageKey: 'market_detail_on_sale',
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              children: children,
              onRefresh: _refreshOnSaleList,
              onScrollNotification: _onSaleScrollNotification,
            );
          },
        );
      }),
    );
  }

  bool get _showOnSaleFilter => controller.appId != 440;

  bool get _hasOnSaleSort => _onSaleSortField != null || _onSaleSortAsc != null;

  bool get _hasOnSaleWear => _onSaleWearMin != null || _onSaleWearMax != null;

  bool get _hasOnSaleFilter =>
      _onSaleSortField != null ||
      _onSaleMinPrice != null ||
      _onSaleMaxPrice != null ||
      (_onSalePaintSeed?.isNotEmpty ?? false) ||
      _onSalePaintIndex != null ||
      _onSaleWearMin != null ||
      _onSaleWearMax != null;

  Future<void> _clearOnSaleFilter() async {
    setState(() {
      _onSaleSortField = null;
      _onSaleSortAsc = null;
      _onSaleMinPrice = null;
      _onSaleMaxPrice = null;
      _onSalePaintSeed = null;
      _onSalePaintIndex = null;
      _onSaleWearMin = null;
      _onSaleWearMax = null;
    });
    await _applyOnSaleFilterWithCurrentState();
  }

  Future<void> _openOnSaleFilterSheet() async {
    final sortOptions = _buildOnSaleSortOptions();
    final paintKits = _buildPaintKitOptions();
    final wearQuickOptions = _buildWearQuickOptions(
      _templateDetail?.schema?.tags?.exterior?.key,
    );
    final showCsgoFilter = controller.appId == 730;

    final barrierLabel = MaterialLocalizations.of(
      context,
    ).modalBarrierDismissLabel;
    final result = await showGeneralDialog<_OnSaleFilterValue>(
      context: context,
      barrierDismissible: true,
      barrierLabel: barrierLabel,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        final media = MediaQuery.of(dialogContext);
        final width = media.size.width;
        final height = media.size.height;
        return Align(
          alignment: Alignment.centerRight,
          child: SizedBox(
            width: width,
            height: height,
            child: _OnSaleFilterSheetDialog(
              initialSortField: _onSaleSortField,
              initialSortAsc: _onSaleSortAsc,
              initialPaintSeed: _onSalePaintSeed,
              initialPaintIndex: _onSalePaintIndex,
              initialWearMin: _onSaleWearMin,
              initialWearMax: _onSaleWearMax,
              initialMinPrice: _onSaleMinPrice,
              initialMaxPrice: _onSaleMaxPrice,
              sortOptions: sortOptions,
              paintKits: paintKits,
              wearQuickOptions: wearQuickOptions,
              showCsgoFilter: showCsgoFilter,
              formatSortLabel: _formatOnSaleSortLabel,
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        );
      },
    );

    if (result == null) {
      return;
    }
    setState(() {
      _onSaleSortField = result.sortField;
      _onSaleSortAsc = result.sortAsc;
      _onSaleMinPrice = result.minPrice;
      _onSaleMaxPrice = result.maxPrice;
      _onSalePaintSeed = result.paintSeed;
      _onSalePaintIndex = result.paintIndex;
      _onSaleWearMin = result.paintWearMin;
      _onSaleWearMax = result.paintWearMax;
    });
    await _applyOnSaleFilterWithCurrentState();
  }

  List<_PaintKitOption> _buildPaintKitOptions() {
    final paintKits = _templateDetail?.paintKits;
    if (paintKits == null || paintKits.isEmpty) {
      return const <_PaintKitOption>[];
    }
    final options = <int, _PaintKitOption>{};
    for (final raw in paintKits) {
      if (raw is! Map) {
        continue;
      }
      final map = Map<String, dynamic>.from(raw);
      final id = _asInt(map['id']);
      if (id == null) {
        continue;
      }
      final label =
          _cleanText(map['phase']?.toString()) ??
          _cleanText(map['name']?.toString()) ??
          id.toString();
      options[id] = _PaintKitOption(id: id, label: label);
    }
    return options.values.toList(growable: false);
  }

  List<_WearQuickOption> _buildWearQuickOptions(String? exteriorKey) {
    switch (exteriorKey) {
      case 'WearCategory0':
        return const <_WearQuickOption>[
          _WearQuickOption('0.00-0.01', '0.00', '0.01'),
          _WearQuickOption('0.01-0.02', '0.01', '0.02'),
          _WearQuickOption('0.02-0.03', '0.02', '0.03'),
          _WearQuickOption('0.03-0.04', '0.03', '0.04'),
          _WearQuickOption('0.04-0.07', '0.04', '0.07'),
        ];
      case 'WearCategory1':
        return const <_WearQuickOption>[
          _WearQuickOption('0.07-0.08', '0.07', '0.08'),
          _WearQuickOption('0.08-0.09', '0.08', '0.09'),
          _WearQuickOption('0.09-0.10', '0.09', '0.10'),
          _WearQuickOption('0.10-0.11', '0.10', '0.11'),
          _WearQuickOption('0.11-0.15', '0.11', '0.15'),
        ];
      case 'WearCategory2':
        return const <_WearQuickOption>[
          _WearQuickOption('0.15-0.18', '0.15', '0.18'),
          _WearQuickOption('0.18-0.21', '0.18', '0.21'),
          _WearQuickOption('0.21-0.24', '0.21', '0.24'),
          _WearQuickOption('0.24-0.27', '0.24', '0.27'),
          _WearQuickOption('0.27-0.38', '0.27', '0.38'),
        ];
      case 'WearCategory3':
        return const <_WearQuickOption>[
          _WearQuickOption('0.38-0.39', '0.38', '0.39'),
          _WearQuickOption('0.39-0.40', '0.39', '0.40'),
          _WearQuickOption('0.40-0.41', '0.40', '0.41'),
          _WearQuickOption('0.41-0.42', '0.41', '0.42'),
          _WearQuickOption('0.42-0.45', '0.42', '0.45'),
        ];
      case 'WearCategory4':
        return const <_WearQuickOption>[
          _WearQuickOption('0.45-0.50', '0.45', '0.50'),
          _WearQuickOption('0.50-0.63', '0.50', '0.63'),
          _WearQuickOption('0.63-0.76', '0.63', '0.76'),
          _WearQuickOption('0.76-0.90', '0.76', '0.90'),
          _WearQuickOption('0.90-1.00', '0.90', '1.00'),
        ];
      default:
        return const <_WearQuickOption>[];
    }
  }

  Widget _buildItemCard(
    MarketListItem item,
    MarketUserInfo? user,
    CurrencyController currency,
  ) {
    final schema = _lookupMarketSchema(item);
    final appId = item.appId ?? controller.appId;
    final schemaTags = schema?.tags;
    final imageUrl =
        schema?.imageUrl ?? item.raw['image_url']?.toString() ?? '';
    final asset = _resolveAsset(item);
    final paintWearValue = _extractDouble(asset, ['paint_wear', 'paintWear']);
    final paintWearText =
        _extractText(asset, ['paint_wear', 'paintWear']) ??
        _extractText(item.raw, ['paint_wear', 'paintWear']) ??
        paintWearValue?.toString();
    final stickers = _parseStickers(
      asset: asset,
      raw: item.raw,
      schemas: controller.schemas,
      stickerMap: controller.stickers,
    );
    final gems = parseGemList(
      asset?['gemList'] ??
          asset?['gems'] ??
          item.raw['gemList'] ??
          item.raw['gems'],
    );
    final keychains = _parseKeychains(
      asset?['keychains'] ?? item.raw['keychains'],
      controller.schemas,
      controller.stickers,
    );
    final avatar = _resolveAvatar(user?.avatar);
    final canBuy = item.id != null && item.price != null;
    final purchaseKey = _onSalePurchaseKey(item);
    final isPurchasing =
        purchaseKey != null && _onSalePurchasingIds.contains(purchaseKey);
    final isOwn = _isOwnOnSaleItem(item);
    final nickname = user?.nickname ?? '';
    final phaseLabel =
        _cleanText(item.raw['phase']?.toString()) ??
        _cleanText(schemaTags?.exterior?.localizedName);
    final metaLabels = <String>[
      if (_cleanText(schemaTags?.quality?.localizedName) case final quality?)
        quality,
      if (_cleanText(schemaTags?.type?.localizedName) case final type?) type,
      if (phaseLabel case final phase?) phase,
    ];
    final hasWear =
        appId == 730 && paintWearValue != null && paintWearText != null;
    final hasDecorations =
        stickers.isNotEmpty || gems.isNotEmpty || keychains.isNotEmpty;
    const imageBoxWidth = _onSaleListingImageBoxWidth;
    const imageBoxHeight = _onSaleListingImageBoxHeight;
    const listingBuyButtonBlue = Color(0xFF2D4EA2);
    const listingChangePriceBlue = Color(0xFF2B46A2);
    const listingDelistRed = Color(0xFFC4322B);
    const listingBuyButtonBlueStart = Color(0xFF4C80F1);
    const listingChangePriceBlueStart = Color(0xFF4A7BEE);
    const listingDelistRedStart = Color(0xFFE5635B);
    final imageBackgroundAsset = _figmaItemBackgroundAsset(
      schema?.tags?.rarity?.color,
    );

    Widget buildItemPreviewImage() {
      return Container(
        width: imageBoxWidth,
        height: imageBoxHeight,
        decoration: BoxDecoration(
          color: _figmaSlate800,
          borderRadius: BorderRadius.circular(9),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                imageBackgroundAsset,
                fit: BoxFit.cover,
                errorBuilder: (context, _, __) =>
                    Container(color: _figmaSlate800),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.18),
                ),
              ),
            ),
            Positioned.fill(
              child: Center(
                child: imageUrl.isEmpty
                    ? Icon(
                        Icons.image_not_supported_outlined,
                        color: Colors.white.withValues(alpha: 0.4),
                        size: 14,
                      )
                    : CachedNetworkImage(
                        imageUrl: imageUrl,
                        width: imageBoxWidth,
                        height: imageBoxHeight,
                        fit: BoxFit.contain,
                        placeholder: (context, _) => const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 1.8),
                        ),
                        errorWidget: (context, _, __) =>
                            const Icon(Icons.image_not_supported_outlined),
                      ),
              ),
            ),
          ],
        ),
      );
    }

    Widget buildMetaChip(String label) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFFF4F6FB),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: _figmaSlate500,
            fontSize: 8.5,
            height: 10 / 8.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    Widget buildMetaRow() {
      if (metaLabels.isEmpty) {
        return const SizedBox.shrink();
      }
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (var index = 0; index < metaLabels.length; index++) ...[
              if (index > 0) const SizedBox(width: 5),
              buildMetaChip(metaLabels[index]),
            ],
          ],
        ),
      );
    }

    Widget buildSellerChip() {
      if (nickname.isEmpty) {
        return const SizedBox.shrink();
      }
      return ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 182),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(1, 0, 4, 0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 8,
                backgroundImage: avatar.isNotEmpty
                    ? CachedNetworkImageProvider(avatar)
                    : null,
                child: avatar.isEmpty
                    ? const Icon(Icons.person, size: 10)
                    : null,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  nickname,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _figmaSlate800,
                    fontSize: 10.5,
                    height: 12 / 10.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    Widget buildWearPanel() {
      return Padding(
        padding: const EdgeInsets.fromLTRB(1, 1, 4, 1),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              hasWear ? 'Wear: $paintWearText' : 'Wear',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _figmaSlate500,
                fontSize: 8.5,
                height: 10 / 8.5,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (hasWear) ...[
              const SizedBox(height: 2),
              WearProgressBar(
                paintWear: paintWearValue,
                height: 5,
                style: WearProgressBarStyle.figmaCompact,
              ),
            ],
          ],
        ),
      );
    }

    Widget buildDecorationsPanel() {
      return Padding(
        padding: const EdgeInsets.fromLTRB(1, 0, 0, 0),
        child: Align(
          alignment: Alignment.centerLeft,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                if (stickers.isNotEmpty)
                  StickerRow(stickers: stickers, size: 22),
                if (stickers.isNotEmpty && gems.isNotEmpty)
                  const SizedBox(width: 4),
                if (gems.isNotEmpty) GemRow(gems: gems, size: 22),
                if ((stickers.isNotEmpty || gems.isNotEmpty) &&
                    keychains.isNotEmpty)
                  const SizedBox(width: 4),
                if (keychains.isNotEmpty)
                  StickerRow(stickers: keychains, size: 22),
              ],
            ),
          ),
        ),
      );
    }

    Widget buildGradientActionButton({
      required VoidCallback? onPressed,
      required Widget child,
      required List<Color> colors,
      BoxShadow? shadow,
    }) {
      final isDisabled = onPressed == null;
      const borderRadius = BorderRadius.all(Radius.circular(7));
      return _PressableScale(
        onTap: onPressed,
        borderRadius: borderRadius,
        overlayColor: Colors.white.withValues(alpha: 0.12),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDisabled
                  ? const [Color(0xFFBAC4D8), Color(0xFF9CAAC4)]
                  : colors,
            ),
            boxShadow: isDisabled
                ? null
                : [
                    shadow ??
                        const BoxShadow(
                          color: Color(0x1F2D4EA2),
                          blurRadius: 5,
                          offset: Offset(0, 2),
                        ),
                  ],
          ),
          child: Center(child: child),
        ),
      );
    }

    Widget buildBuyButton() {
      return SizedBox(
        width: 96,
        height: 26,
        child: buildGradientActionButton(
          onPressed: canBuy && !isPurchasing ? () => _purchaseItem(item) : null,
          colors: const [listingBuyButtonBlue, listingBuyButtonBlueStart],
          child: isPurchasing
              ? const SizedBox(
                  width: 10,
                  height: 10,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: Colors.white,
                  ),
                )
              : Text(
                  'app.trade.buy.text'.tr,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    height: 11 / 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      );
    }

    Widget buildOwnActionRow() {
      final changePriceLabel = _isEnglishLocale
          ? 'Adjust'
          : 'app.inventory.price_change'.tr;

      Widget buildButtonLabel(String text) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.fade,
            softWrap: false,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9,
              height: 11 / 9,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      }

      return SizedBox(
        width: 136,
        child: Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 28,
                child: buildGradientActionButton(
                  onPressed: () =>
                      _changePriceOnSaleItem(item: item, schema: schema),
                  colors: const [
                    listingChangePriceBlue,
                    listingChangePriceBlueStart,
                  ],
                  child: buildButtonLabel(changePriceLabel),
                ),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: SizedBox(
                height: 28,
                child: buildGradientActionButton(
                  onPressed: () => _delistOnSaleItem(item),
                  colors: const [listingDelistRed, listingDelistRedStart],
                  shadow: const BoxShadow(
                    color: Color(0x22C4322B),
                    blurRadius: 5,
                    offset: Offset(0, 2),
                  ),
                  child: buildButtonLabel('app.inventory.delist'.tr),
                ),
              ),
            ),
          ],
        ),
      );
    }

    Widget buildDetailEyeButton() {
      return SizedBox(
        width: 18,
        height: 18,
        child: _PressableScale(
          onTap: () => _openItemDetail(item, schema, user),
          borderRadius: BorderRadius.circular(999),
          overlayColor: _figmaSlate400.withValues(alpha: 0.14),
          minScale: 0.9,
          child: DecoratedBox(
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(999)),
            child: const Center(
              child: Icon(
                Icons.visibility_outlined,
                size: 13,
                color: _figmaSlate400,
              ),
            ),
          ),
        ),
      );
    }

    Widget buildButtonRow() {
      if (isOwn) {
        return buildOwnActionRow();
      }
      return buildBuyButton();
    }

    return Material(
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [
              BoxShadow(
                color: Color(0x120F172A),
                blurRadius: 14,
                offset: Offset(0, 4),
              ),
              BoxShadow(
                color: Color(0x0D0F172A),
                blurRadius: 4,
                offset: Offset(0, 1),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(8, 5, 8, 5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  buildItemPreviewImage(),
                  const SizedBox(width: 7),
                  Expanded(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: imageBoxHeight),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Obx(
                                  () => Text(
                                    currency.format(item.price ?? 0),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: _figmaOrange,
                                      fontSize: 15,
                                      height: 16 / 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 5),
                              buildDetailEyeButton(),
                            ],
                          ),
                          const SizedBox(height: 4),
                          buildMetaRow(),
                          const SizedBox(height: 5),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              if (nickname.isNotEmpty)
                                Expanded(child: buildSellerChip()),
                              if (nickname.isNotEmpty) const SizedBox(width: 6),
                              if (nickname.isEmpty) const Spacer(),
                              buildButtonRow(),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              if (hasWear || hasDecorations) ...[
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (hasWear)
                      SizedBox(width: imageBoxWidth, child: buildWearPanel()),
                    if (hasWear && hasDecorations) const SizedBox(width: 6),
                    if (hasDecorations)
                      Expanded(child: buildDecorationsPanel()),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  bool _isOwnOnSaleItem(MarketListItem item) {
    if (item.own == true) {
      return true;
    }
    final currentUser = UserStorage.getUserInfo();
    final currentUserId = _asInt(currentUser?.id);
    final currentShopId = _asInt(currentUser?.shop?.id);
    final sellerId = item.userId;
    if (sellerId == null) {
      return false;
    }
    return sellerId == currentUserId || sellerId == currentShopId;
  }

  Future<void> _changePriceOnSaleItem({
    required MarketListItem item,
    required MarketSchemaInfo? schema,
  }) async {
    final id = item.id;
    if (id == null) {
      return;
    }

    final raw = Map<String, dynamic>.from(item.raw);
    final shopItem = ShopItemAsset(
      raw: raw,
      id: id,
      appId: item.appId ?? controller.appId,
      schemaId: item.schemaId,
      marketName:
          schema?.marketName ??
          raw['market_name']?.toString() ??
          raw['marketName']?.toString(),
      marketHashName: schema?.marketHashName ?? item.marketHashName,
      imageUrl:
          schema?.imageUrl ??
          raw['image_url']?.toString() ??
          raw['imageUrl']?.toString(),
      price: item.price,
      count: _asInt(raw['count']) ?? 1,
      userId: item.userId,
      status: _asInt(raw['status']),
      statusName:
          raw['statusName']?.toString() ?? raw['status_name']?.toString(),
      createTime: _asInt(raw['create_time'] ?? raw['createTime']),
    );

    final schemaMap = <String, ShopSchemaInfo>{};
    if (schema != null && schema.raw.isNotEmpty) {
      try {
        final mappedSchema = ShopSchemaInfo.fromJson(
          Map<String, dynamic>.from(schema.raw),
        );
        final hash = mappedSchema.marketHashName;
        if (hash != null && hash.isNotEmpty) {
          schemaMap[hash] = mappedSchema;
        }
        final schemaId = item.schemaId;
        if (schemaId != null) {
          schemaMap[schemaId.toString()] = mappedSchema;
        }
      } catch (_) {}
    }

    await Get.toNamed(
      Routers.SHOP_PRICE_CHANGE,
      arguments: <String, dynamic>{
        'items': <ShopItemAsset>[shopItem],
        'schemas': schemaMap,
        'appId': item.appId ?? controller.appId,
      },
    );
    await controller.loadOnSale(reset: true);
  }

  Future<void> _delistOnSaleItem(MarketListItem item) async {
    final id = item.id;
    if (id == null) {
      return;
    }

    var didDelist = false;
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
              final res = await _shopProductApi.orderItemRemoved(
                ids: <int>[id],
              );
              if (res.success) {
                didDelist = true;
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
    if (!didDelist) {
      return;
    }

    await controller.loadOnSale(reset: true);
    await controller.loadTransactions(reset: true);
  }

  Widget _buildPriceTrendTab() {
    return BackToTopScope(
      enabled: false,
      child: Obx(() {
        final isLoading = controller.isLoadingTrend.value;
        final points = controller.pricePoints.toList(growable: false);

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(
            children: [
              _buildTrendDaySelector(),
              const SizedBox(height: 18),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  child: isLoading
                      ? const PriceTrendChartSkeleton(
                          key: ValueKey<String>('trend-skeleton'),
                        )
                      : PriceTrendChart(
                          key: const ValueKey<String>('trend-chart'),
                          points: points,
                        ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildTrendDaySelector() {
    final options = <({int days, String label})>[
      (days: 7, label: '7 days'),
      (days: 30, label: '1 month'),
      (days: 180, label: '6 month'),
      (days: 365, label: '1 year'),
    ];

    return Container(
      height: 34,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _figmaSlate300),
      ),
      child: Row(
        children: [
          for (var index = 0; index < options.length; index++) ...[
            Expanded(
              child: _buildTrendDaySegment(
                days: options[index].days,
                label: options[index].label,
              ),
            ),
            if (index < options.length - 1)
              Container(
                width: 1,
                height: double.infinity,
                color: _figmaSlate300,
              ),
          ],
        ],
      ),
    );
  }

  Future<void> _supplyBuyRequestItem(
    BuyRequestItem item,
    ShopSchemaInfo? schema,
  ) async {
    if (!await _promptLoginIfNeeded()) {
      return;
    }
    final result = await Get.toNamed(
      Routers.BUYING_SUPPLY,
      arguments: {'item': item, 'schema': schema},
    );
    if (result == true) {
      await controller.loadBuyRequests(reset: true);
      await Get.dialog<void>(
        AlertDialog(
          title: Text('app.system.tips.title'.tr),
          content: Text('app.trade.supply.message.confirm'.tr),
          actions: [
            TextButton(
              onPressed: () => Get.back(),
              child: Text('app.common.confirm'.tr),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _openBuyRequestPriceChange(
    BuyRequestItem item,
    ShopSchemaInfo? schema,
  ) async {
    final result = await Get.toNamed(
      Routers.BUYING_UPDATE_PRICE,
      arguments: {'item': item, 'schema': schema},
    );
    if (result == true) {
      await controller.loadBuyRequests(reset: true);
    }
  }

  Future<void> _confirmTerminateBuyRequest(BuyRequestItem item) async {
    final id = item.id?.toString();
    if (id == null) {
      return;
    }

    final confirm = await Get.dialog<bool>(
      AlertDialog(
        title: Text('app.system.tips.title'.tr),
        content: Text('app.trade.purchase.message.confirm_terminate'.tr),
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
    if (confirm != true) {
      return;
    }

    try {
      final res = await _shopProductApi.orderItemCancelBuy(id: id);
      if (res.success) {
        AppSnackbar.success('app.system.message.success'.tr);
      } else {
        AppSnackbar.error(
          res.message.isNotEmpty ? res.message : 'app.trade.filter.failed'.tr,
        );
      }
    } catch (_) {
      AppSnackbar.error('app.trade.filter.failed'.tr);
    }

    await controller.loadBuyRequests(reset: true);
  }

  String _formatBuyRequestWearRequirement(BuyRequestItem item) {
    final wearMaxText =
        _cleanText(
          item.raw['paint_wear_max']?.toString() ??
              item.raw['paintWearMax']?.toString(),
        ) ??
        item.paintWearMax?.toString();
    final wearMinText =
        _cleanText(
          item.raw['paint_wear_min']?.toString() ??
              item.raw['paintWearMin']?.toString(),
        ) ??
        item.paintWearMin?.toString();

    if (wearMinText != null && wearMaxText != null) {
      return '$wearMinText - $wearMaxText';
    }

    return _figmaNoRequirementTitle;
  }

  String _formatBuyRequestQuantity(BuyRequestItem item) {
    final total = item.nums ?? item.need ?? item.count;
    final received = item.received;

    if (total != null && total > 0) {
      if (received != null && received >= 0) {
        return '$received/$total';
      }
      return total.toString();
    }

    return _figmaNoRequirementTitle;
  }

  bool _hasBuyRequestRequirementValue(String value) =>
      value != _figmaNoRequirementTitle;

  String _formatBuyRequestPatternRequirement(BuyRequestItem item) {
    final text =
        _pickRequirementText(item.raw, const [
          'accepted_patterns',
          'acceptedPatterns',
          'phaseList',
          'phase_list',
          'phases',
          'patterns',
          'pattern',
          'phase',
        ]) ??
        _cleanText(item.phase);
    return text ?? _figmaNoRequirementTitle;
  }

  String? _pickRequirementText(Map<String, dynamic> raw, List<String> keys) {
    for (final key in keys) {
      final values = _flattenRequirementValues(raw[key]);
      if (values.isNotEmpty) {
        return values.join(', ');
      }
    }
    return null;
  }

  List<String> _flattenRequirementValues(dynamic value) {
    if (value == null) {
      return const <String>[];
    }
    if (value is Iterable) {
      return value
          .expand<String>((entry) => _flattenRequirementValues(entry))
          .where((entry) => entry.isNotEmpty)
          .toList(growable: false);
    }
    if (value is Map) {
      for (final key in ['label', 'name', 'text', 'value', 'phase']) {
        final text = _cleanText(value[key]?.toString());
        if (text != null) {
          return <String>[text];
        }
      }
      return value.values
          .expand<String>((entry) => _flattenRequirementValues(entry))
          .where((entry) => entry.isNotEmpty)
          .toList(growable: false);
    }
    final text = _cleanText(value.toString());
    return text == null ? const <String>[] : <String>[text];
  }

  Widget _buildBuyRequestRequirementRow({
    required String label,
    required String value,
    required bool isActive,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(
            Icons.check_circle_outline_rounded,
            size: 11,
            color: isActive ? _figmaGreen600 : _figmaSlate400,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '$label: ',
                  style: const TextStyle(
                    color: _figmaSlate800,
                    fontSize: 10.5,
                    height: 13 / 10.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                TextSpan(
                  text: value,
                  style: const TextStyle(
                    color: _figmaSlate500,
                    fontSize: 10.5,
                    height: 13 / 10.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBuyRequestGradientButton({
    required VoidCallback? onPressed,
    required String label,
    required List<Color> colors,
    BoxShadow? shadow,
  }) {
    final isDisabled = onPressed == null;
    const borderRadius = BorderRadius.all(Radius.circular(7));

    return _PressableScale(
      onTap: onPressed,
      borderRadius: borderRadius,
      overlayColor: Colors.white.withValues(alpha: 0.12),
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDisabled
                ? const [Color(0xFFBAC4D8), Color(0xFF9CAAC4)]
                : colors,
          ),
          boxShadow: isDisabled
              ? null
              : [
                  shadow ??
                      const BoxShadow(
                        color: Color(0x220D9B6B),
                        blurRadius: 5,
                        offset: Offset(0, 2),
                      ),
                ],
        ),
        child: SizedBox(
          height: 28,
          child: Center(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10.5,
                height: 12 / 10.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBuyRequestTab(CurrencyController currency) {
    return BackToTopScope(
      enabled: true,
      overlayBottomPadding: _detailListBackToTopBottomPadding,
      child: Obx(() {
        final isLoading = controller.isLoadingBuyRequests.value;
        final isRefreshing = controller.isRefreshingBuyRequests.value;
        final items = controller.buyRequests.toList(growable: false);
        final users = Map<String, ShopUserInfo>.from(controller.buyUsers);
        final schemas = Map<String, ShopSchemaInfo>.from(controller.buySchemas);
        final showLoadingFooter =
            isLoading && items.isNotEmpty && !isRefreshing;
        final showNoMoreFooter =
            items.isNotEmpty && !isLoading && !controller.buyRequestHasMore;
        final showFooter = showLoadingFooter || showNoMoreFooter;

        return Builder(
          builder: (context) {
            if (isRefreshing) {
              return _buildBuyRequestInitialLoadingView();
            }
            if (isLoading && items.isEmpty) {
              return _buildBuyRequestInitialLoadingView();
            }
            if (items.isEmpty) {
              return _buildInnerFillRemaining(
                context: context,
                storageKey: 'market_detail_buy_request_empty',
                child: Text('app.common.no_data'.tr),
                onRefresh: _refreshBuyRequestList,
              );
            }

            final children = <Widget>[];

            for (var index = 0; index < items.length; index++) {
              if (index > 0) {
                children.add(const SizedBox(height: 12));
              }
              final item = items[index];
              final schemaKey = item.schemaId?.toString();
              final schema = schemaKey == null ? null : schemas[schemaKey];
              final userKey = item.userId?.toString();
              final user = userKey == null ? null : users[userKey];
              final avatar = _resolveAvatar(user?.avatar);
              final need = item.need ?? item.nums ?? 0;
              final isOwn = item.own == true;
              final canSupply = need > 0;
              final isDark = Theme.of(context).brightness == Brightness.dark;
              final buyerName =
                  _cleanText(user?.nickname) ?? _figmaBuyerFallbackName;
              final quantityRequirement = _formatBuyRequestQuantity(item);
              final wearRequirement = _formatBuyRequestWearRequirement(item);
              final patternRequirement = _formatBuyRequestPatternRequirement(
                item,
              );

              Widget buildHeaderActionButtons() {
                if (!isOwn) {
                  return SizedBox(
                    width: 96,
                    child: _buildBuyRequestGradientButton(
                      onPressed: canSupply
                          ? () => _supplyBuyRequestItem(item, schema)
                          : null,
                      colors: const [_figmaGreen600, _figmaGreen400],
                      label: 'app.trade.supply.text'.tr,
                    ),
                  );
                }

                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 74,
                      child: _buildBuyRequestGradientButton(
                        onPressed: () =>
                            _openBuyRequestPriceChange(item, schema),
                        colors: const [_figmaGreen600, _figmaGreen400],
                        label: _isEnglishLocale
                            ? 'Adjust'
                            : 'app.inventory.price_change'.tr,
                      ),
                    ),
                    const SizedBox(width: 6),
                    SizedBox(
                      width: 74,
                      child: _buildBuyRequestGradientButton(
                        onPressed: () => _confirmTerminateBuyRequest(item),
                        colors: const [_figmaRed600, _figmaRed400],
                        shadow: const BoxShadow(
                          color: Color(0x26D92D20),
                          blurRadius: 5,
                          offset: Offset(0, 2),
                        ),
                        label: 'app.common.delete'.tr,
                      ),
                    ),
                  ],
                );
              }

              children.add(
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF242830) : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: isDark ? 0.18 : 0.07,
                        ),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          CircleAvatar(
                            radius: 12,
                            backgroundImage: avatar.isNotEmpty
                                ? CachedNetworkImageProvider(avatar)
                                : null,
                            child: avatar.isEmpty
                                ? const Icon(Icons.person, size: 12)
                                : null,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              buyerName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _figmaSlate900,
                                fontSize: 11.5,
                                height: 13 / 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          buildHeaderActionButtons(),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Obx(
                        () => Text(
                          currency.format(item.price ?? 0),
                          style: const TextStyle(
                            color: _figmaGreen600,
                            fontSize: 18,
                            height: 20 / 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.07)
                              : const Color(0xFFF3F5F8),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildBuyRequestRequirementRow(
                              label: _figmaQuantityTitle,
                              value: quantityRequirement,
                              isActive: _hasBuyRequestRequirementValue(
                                quantityRequirement,
                              ),
                            ),
                            const SizedBox(height: 6),
                            _buildBuyRequestRequirementRow(
                              label: _figmaWearTitle,
                              value: wearRequirement,
                              isActive: _hasBuyRequestRequirementValue(
                                wearRequirement,
                              ),
                            ),
                            const SizedBox(height: 6),
                            _buildBuyRequestRequirementRow(
                              label: _figmaAcceptedPatternsTitle,
                              value: patternRequirement,
                              isActive: _hasBuyRequestRequirementValue(
                                patternRequirement,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            if (showFooter) {
              if (showLoadingFooter) {
                for (
                  var index = 0;
                  index < _detailBuyRequestLoadMorePlaceholderCount;
                  index++
                ) {
                  if (children.isNotEmpty) {
                    children.add(const SizedBox(height: 12));
                  }
                  children.add(_buildMarketBuyRequestLoadingCard());
                }
              } else {
                if (children.isNotEmpty) {
                  children.add(const SizedBox(height: 12));
                }
                children.add(
                  _buildLoadMoreFooter(
                    showLoading: false,
                    showNoMore: showNoMoreFooter,
                  ),
                );
              }
            }

            return _buildInnerScrollView(
              context: context,
              storageKey: 'market_detail_buy_request',
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              children: children,
              onRefresh: _refreshBuyRequestList,
              onScrollNotification: _buyRequestScrollNotification,
            );
          },
        );
      }),
    );
  }

  Widget _buildTransactionTab(CurrencyController currency) {
    return BackToTopScope(
      enabled: true,
      overlayBottomPadding: _detailListBackToTopBottomPadding,
      child: Obx(() {
        final isLoading = controller.isLoadingTransactions.value;
        final isRefreshing = controller.isRefreshingTransactions.value;
        final items = controller.transactionItems.toList(growable: false);
        final showLoadingFooter =
            isLoading && items.isNotEmpty && !isRefreshing;
        final showNoMoreFooter =
            items.isNotEmpty && !isLoading && !controller.transactionHasMore;
        final showFooter = showLoadingFooter || showNoMoreFooter;

        return Builder(
          builder: (context) {
            if (isRefreshing) {
              return _buildTransactionInitialLoadingView();
            }
            if (isLoading && items.isEmpty) {
              return _buildTransactionInitialLoadingView();
            }
            if (items.isEmpty) {
              return _buildInnerFillRemaining(
                context: context,
                storageKey: 'market_detail_transaction_empty',
                child: Text('app.common.no_data'.tr),
                onRefresh: _refreshTransactionList,
              );
            }

            final children = <Widget>[];
            final isDark = Theme.of(context).brightness == Brightness.dark;
            children.add(
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var index = 0; index < items.length; index++)
                    _buildTransactionHistoryItem(
                      context: context,
                      currency: currency,
                      item: items[index],
                      index: index,
                      isDark: isDark,
                    ),
                ],
              ),
            );

            if (showFooter) {
              if (showLoadingFooter) {
                if (children.isNotEmpty) {
                  children.add(const SizedBox(height: 12));
                }
                children.add(
                  _buildTransactionLoadingSection(
                    rowCount: _detailTransactionLoadMorePlaceholderCount,
                  ),
                );
              } else {
                if (children.isNotEmpty) {
                  children.add(const SizedBox(height: 12));
                }
                children.add(
                  _buildLoadMoreFooter(
                    showLoading: false,
                    showNoMore: showNoMoreFooter,
                  ),
                );
              }
            }

            return _buildInnerScrollView(
              context: context,
              storageKey: 'market_detail_transaction',
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              children: children,
              onRefresh: _refreshTransactionList,
              onScrollNotification: _transactionScrollNotification,
            );
          },
        );
      }),
    );
  }

  String _resolveTransactionStatusLabel(MarketListItem item) {
    return _cleanText(item.typeName) ??
        _cleanText(item.raw['statusName']?.toString()) ??
        _cleanText(item.raw['status_name']?.toString()) ??
        '-';
  }

  String _formatTransactionStatusLabel(String label) {
    if (!_isEnglishLocale) {
      return label;
    }
    return label.toUpperCase();
  }

  List<_HistoryDetailChipData> _buildTransactionDetailChips(
    MarketListItem item,
    bool isDark,
  ) {
    final paintSeed = _resolveTransactionPaintSeed(item);
    final paintIndex = _resolveTransactionPaintIndex(item);
    final paintWearValue = _resolveTransactionPaintWear(item);
    final exterior = _resolveTransactionExteriorLabel(item, paintWearValue);
    final chips = <_HistoryDetailChipData>[];

    void addChip({
      required String? value,
      required int flex,
      required Color lightBackgroundColor,
      required Color darkBackgroundColor,
      required Color lightTextColor,
      required Color darkTextColor,
    }) {
      final normalized = _normalizeTransactionChipValue(value);
      if (normalized == null) {
        return;
      }
      chips.add(
        _HistoryDetailChipData(
          value: normalized,
          flex: flex,
          backgroundColor: isDark ? darkBackgroundColor : lightBackgroundColor,
          textColor: isDark ? darkTextColor : lightTextColor,
          dimmed: false,
        ),
      );
    }

    addChip(
      value: paintSeed,
      flex: 10,
      lightBackgroundColor: const Color(0xFFEAF1FF),
      darkBackgroundColor: const Color(0xFF2A3854),
      lightTextColor: _figmaBlue700,
      darkTextColor: const Color(0xFFBFD3FF),
    );
    addChip(
      value: paintIndex,
      flex: 10,
      lightBackgroundColor: const Color(0xFFF1F5F9),
      darkBackgroundColor: const Color(0xFF2A313D),
      lightTextColor: _figmaSlate800,
      darkTextColor: const Color(0xFFD8E0EB),
    );
    addChip(
      value: paintWearValue?.toStringAsFixed(4),
      flex: 12,
      lightBackgroundColor: const Color(0xFFE9F8F2),
      darkBackgroundColor: const Color(0xFF21392F),
      lightTextColor: _figmaGreen600,
      darkTextColor: const Color(0xFFB6E8D0),
    );
    addChip(
      value: exterior,
      flex: 18,
      lightBackgroundColor: const Color(0xFFFFF1DD),
      darkBackgroundColor: const Color(0xFF3B311F),
      lightTextColor: _figmaOrange,
      darkTextColor: const Color(0xFFFFD59D),
    );

    return chips;
  }

  String? _normalizeTransactionChipValue(String? value) {
    final normalized = _cleanText(value);
    if (normalized == null || normalized == '-') {
      return null;
    }
    final numericValue = num.tryParse(normalized);
    if (numericValue != null && numericValue == 0) {
      return null;
    }
    return normalized;
  }

  String? _resolveTransactionPaintSeed(MarketListItem item) {
    final asset = _resolveAsset(item);
    return _cleanText(
      _extractText(asset, [
            'paint_seed',
            'paintSeed',
            'pattern_seed',
            'patternSeed',
            'seed',
          ]) ??
          _extractText(item.raw, [
            'paint_seed',
            'paintSeed',
            'pattern_seed',
            'patternSeed',
            'seed',
          ]),
    );
  }

  String? _resolveTransactionPaintIndex(MarketListItem item) {
    final asset = _resolveAsset(item);
    final direct = _cleanText(
      _extractText(asset, [
            'paint_index',
            'paintIndex',
            'paint_kit',
            'paintKit',
          ]) ??
          _extractText(item.raw, [
            'paint_index',
            'paintIndex',
            'paint_kit',
            'paintKit',
          ]),
    );
    if (direct != null) {
      return direct;
    }

    final phase =
        _cleanText(_extractText(asset, ['phase'])) ??
        _cleanText(item.raw['phase']?.toString());
    if (phase == null) {
      return null;
    }

    final target = phase.toLowerCase();
    final paintKits = _templateDetail?.paintKits;
    if (paintKits == null || paintKits.isEmpty) {
      return null;
    }

    for (final raw in paintKits) {
      if (raw is! Map) {
        continue;
      }
      final map = Map<String, dynamic>.from(raw);
      final id = _asInt(map['id']);
      if (id == null) {
        continue;
      }
      final phaseValue = _cleanText(map['phase']?.toString())?.toLowerCase();
      final nameValue = _cleanText(map['name']?.toString())?.toLowerCase();
      if (phaseValue == target || nameValue == target) {
        return id.toString();
      }
    }

    return null;
  }

  double? _resolveTransactionPaintWear(MarketListItem item) {
    final asset = _resolveAsset(item);
    final direct =
        _extractDouble(asset, ['paint_wear', 'paintWear']) ??
        _extractDouble(item.raw, ['paint_wear', 'paintWear']);
    if (direct != null) {
      return direct;
    }
    final text = _cleanText(
      _extractText(asset, ['paint_wear', 'paintWear']) ??
          _extractText(item.raw, ['paint_wear', 'paintWear']),
    );
    if (text == null) {
      return null;
    }
    return double.tryParse(text);
  }

  String? _resolveTransactionExteriorLabel(
    MarketListItem item,
    double? paintWearValue,
  ) {
    final schema = _lookupMarketSchema(item);
    final localizedLabel =
        _cleanText(schema?.tags?.exterior?.localizedName) ??
        _cleanText(_templateDetail?.schema?.tags?.exterior?.localizedName) ??
        _cleanText(controller.item.tags?.exterior?.localizedName) ??
        _extractTagLabel(item.raw['tags'], 'exterior');
    if (localizedLabel != null) {
      return localizedLabel;
    }

    final exteriorKey =
        schema?.tags?.exterior?.key ??
        _extractTagKey(item.raw['tags'], 'exterior') ??
        _extractText(_resolveAsset(item), ['exterior_key', 'exteriorKey']);

    switch (exteriorKey) {
      case 'WearCategory0':
        return 'Factory New';
      case 'WearCategory1':
        return 'Minimal Wear';
      case 'WearCategory2':
        return 'Field-Tested';
      case 'WearCategory3':
        return 'Well-Worn';
      case 'WearCategory4':
        return 'Battle-Scarred';
    }

    if (paintWearValue == null) {
      return null;
    }
    if (paintWearValue < 0.07) {
      return 'Factory New';
    }
    if (paintWearValue < 0.15) {
      return 'Minimal Wear';
    }
    if (paintWearValue < 0.38) {
      return 'Field-Tested';
    }
    if (paintWearValue < 0.45) {
      return 'Well-Worn';
    }
    return 'Battle-Scarred';
  }

  String? _extractTagLabel(dynamic rawTags, String key) {
    if (rawTags is! Map) {
      return null;
    }
    final rawTag = rawTags[key];
    if (rawTag is! Map) {
      return null;
    }
    return _cleanText(
      rawTag['localized_name']?.toString() ??
          rawTag['localizedName']?.toString() ??
          rawTag['name']?.toString(),
    );
  }

  String? _extractTagKey(dynamic rawTags, String key) {
    if (rawTags is! Map) {
      return null;
    }
    final rawTag = rawTags[key];
    if (rawTag is! Map) {
      return null;
    }
    final define = rawTag['define'];
    if (define is Map && define['key'] != null) {
      return define['key'].toString();
    }
    return _cleanText(rawTag['key']?.toString());
  }

  _HistoryStatusStyle _resolveTransactionStatusStyle(String label) {
    final normalized = label.trim().toLowerCase();
    final compact = normalized.replaceAll(RegExp(r'[\s_-]+'), '');
    if (compact.contains('supply') || label.contains('供货')) {
      return const _HistoryStatusStyle(
        backgroundColor: Color(0xFFE9F8F2),
        statusColor: Color(0xFF0D9B6B),
        priceColor: Color(0xFFE04F34),
      );
    }
    if (compact.contains('sell') ||
        label.contains('出售') ||
        label.contains('上架')) {
      return const _HistoryStatusStyle(
        backgroundColor: Color(0xFFEAF1FF),
        statusColor: Color(0xFF2563EB),
        priceColor: Color(0xFFE04F34),
      );
    }
    return const _HistoryStatusStyle(
      backgroundColor: Color(0xFFEAF1FF),
      statusColor: Color(0xFF2563EB),
      priceColor: Color(0xFFE04F34),
    );
  }

  Future<void> _openItemDetail(
    MarketListItem item,
    MarketSchemaInfo? schema,
    MarketUserInfo? user,
  ) async {
    final result = await Get.toNamed(
      Routers.MARKET_ITEM_DETAIL,
      arguments: {
        'item': item,
        'schema': schema,
        'user': user,
        'schemas': Map<String, MarketSchemaInfo>.from(controller.schemas),
        'stickers': Map<String, dynamic>.from(controller.stickers),
      },
    );
    if (result == true) {
      AppSnackbar.success('app.trade.buy.message.success'.tr);
      await controller.loadOnSale(reset: true);
      await controller.loadTransactions(reset: true);
    }
  }

  Future<void> _purchaseItem(MarketListItem item) async {
    final purchaseKey = _onSalePurchaseKey(item);
    if (purchaseKey != null && _onSalePurchasingIds.contains(purchaseKey)) {
      return;
    }
    if (!await _promptLoginIfNeeded()) {
      return;
    }
    if (!mounted) {
      return;
    }
    final user = UserStorage.getUserInfo();
    final id = item.id?.toString();
    final price = item.price;
    final appId = item.appId ?? controller.appId;
    if (id == null || price == null) {
      AppSnackbar.error('app.trade.filter.failed'.tr);
      return;
    }
    final currency = Get.find<CurrencyController>();
    final amountText = currency.format(price);
    final serviceFeeText = currency.format(0);
    final rewardPoints = price.floor().toString();
    final confirmed = await showSteamStyleAmountConfirmDialog(
      context,
      title: 'app.trade.buy.pay_title'.tr,
      amount: amountText,
      amountLabel: 'app.trade.buy.total_price'.tr,
      summaryItems: [
        SteamStyleConfirmSummaryItem(
          label: 'app.trade.buy.item_price'.tr,
          value: amountText,
        ),
        SteamStyleConfirmSummaryItem(
          label: 'app.trade.buy.service_fee'.tr,
          value: serviceFeeText,
        ),
        SteamStyleConfirmSummaryItem(
          label: 'app.trade.buy.est_points_earned'.tr,
          value: '+ $rewardPoints pts',
          valueColor: const Color(0xFF155EEF),
          emphasized: true,
        ),
      ],
      noticeText: 'app.trade.buy.pay_text_3'.tr,
      confirmText: 'app.common.confirm'.tr,
      cancelText: 'app.common.cancel'.tr,
    );
    if (confirmed != true) {
      return;
    }
    if (purchaseKey != null && mounted) {
      setState(() => _onSalePurchasingIds.add(purchaseKey));
    }
    try {
      final res = await _shopProductApi.orderItemPurchase(
        appId: appId,
        id: id,
        price: price,
      );
      final datas = res.datas;
      if (datas is String) {
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
          final nickname = user?.config?.nickname ?? user?.nickname ?? '';
          await Get.dialog<void>(
            AlertDialog(
              title: Text('app.system.tips.title'.tr),
              content: Text('${'app.inventory.message.privacy'.tr}$nickname'),
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
      }
      if (res.success) {
        AppSnackbar.success('app.trade.buy.message.success'.tr);
        await controller.loadOnSale(reset: true);
        await controller.loadTransactions(reset: true);
      } else {
        AppSnackbar.error(
          res.message.isNotEmpty ? res.message : 'app.trade.filter.failed'.tr,
        );
      }
    } catch (_) {
      AppSnackbar.error('app.trade.filter.failed'.tr);
    } finally {
      if (purchaseKey != null && mounted) {
        setState(() => _onSalePurchasingIds.remove(purchaseKey));
      }
    }
  }

  Map<String, dynamic>? _resolveAsset(MarketListItem item) {
    final raw = item.raw;
    if (item.appId == 730 && raw['csgoAsset'] is Map<String, dynamic>) {
      return raw['csgoAsset'] as Map<String, dynamic>;
    }
    if (item.appId == 440 && raw['tf2Asset'] is Map<String, dynamic>) {
      return raw['tf2Asset'] as Map<String, dynamic>;
    }
    if (item.appId == 570 && raw['dota2Asset'] is Map<String, dynamic>) {
      return raw['dota2Asset'] as Map<String, dynamic>;
    }
    return raw;
  }

  String? _extractText(dynamic raw, List<String> keys) {
    if (raw is Map) {
      for (final key in keys) {
        final value = raw[key];
        if (value != null) {
          return value.toString();
        }
      }
    }
    return null;
  }

  double? _extractDouble(dynamic raw, List<String> keys) {
    if (raw is Map) {
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
    }
    return null;
  }

  List<GameItemSticker> _parseKeychains(
    dynamic raw,
    Map<String, MarketSchemaInfo> schemas,
    Map<String, dynamic> stickerMap,
  ) {
    final fromRaw = parseStickerList(
      raw,
      schemaMap: schemas,
      stickerMap: stickerMap,
    );
    if (fromRaw.isNotEmpty) {
      return fromRaw;
    }
    if (raw is! List) {
      return const [];
    }
    final list = <GameItemSticker>[];
    for (final entry in raw) {
      if (entry is Map) {
        final image =
            entry['image_url']?.toString() ??
            entry['imageUrl']?.toString() ??
            entry['image']?.toString();
        if (image != null && image.isNotEmpty) {
          list.add(GameItemSticker(image));
          continue;
        }
        final schemaId = entry['schema_id'] ?? entry['schemaId'] ?? entry['id'];
        if (schemaId != null) {
          final schema = schemas[schemaId.toString()];
          final url = schema?.imageUrl;
          if (url != null && url.isNotEmpty) {
            list.add(GameItemSticker(url));
          }
        }
      } else if (entry is num || entry is String) {
        final schema = schemas[entry.toString()];
        final url = schema?.imageUrl;
        if (url != null && url.isNotEmpty) {
          list.add(GameItemSticker(url));
        }
      }
    }
    return list;
  }

  List<GameItemSticker> _parseStickers({
    required Map<String, dynamic>? asset,
    required Map<String, dynamic> raw,
    required Map<String, MarketSchemaInfo> schemas,
    required Map<String, dynamic> stickerMap,
  }) {
    final rawAsset = _asMap(raw['asset']) ?? _asMap(raw['itemAsset']);
    final rawCsgoAsset = _asMap(raw['csgoAsset']) ?? _asMap(raw['csgo_asset']);
    final rawTf2Asset = _asMap(raw['tf2Asset']) ?? _asMap(raw['tf2_asset']);
    final rawDotaAsset =
        _asMap(raw['dota2Asset']) ?? _asMap(raw['dota2_asset']);
    final candidates = <dynamic>[
      asset?['stickers'],
      asset?['stickerList'],
      asset?['sticker_list'],
      asset?['sticker'],
      rawAsset?['stickers'],
      rawAsset?['stickerList'],
      rawAsset?['sticker_list'],
      rawCsgoAsset?['stickers'],
      rawCsgoAsset?['stickerList'],
      rawCsgoAsset?['sticker_list'],
      rawTf2Asset?['stickers'],
      rawTf2Asset?['stickerList'],
      rawTf2Asset?['sticker_list'],
      rawDotaAsset?['stickers'],
      rawDotaAsset?['stickerList'],
      rawDotaAsset?['sticker_list'],
      raw['stickers'],
      raw['stickerList'],
      raw['sticker_list'],
      raw['sticker'],
    ];
    for (final candidate in candidates) {
      final parsed = parseStickerList(
        _normalizeStickerRaw(candidate),
        schemaMap: schemas,
        stickerMap: stickerMap,
      );
      if (parsed.isNotEmpty) {
        return parsed;
      }
    }
    return const [];
  }

  dynamic _normalizeStickerRaw(dynamic raw) {
    if (raw is List) {
      return raw;
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
      final values = raw.values.toList(growable: false);
      if (values.isNotEmpty) {
        return values;
      }
    }
    if (raw is String) {
      final value = raw.trim();
      if (value.isEmpty || value == 'null') {
        return const <dynamic>[];
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
            .map((entry) => entry.trim())
            .where((entry) => entry.isNotEmpty)
            .toList(growable: false);
        if (values.isNotEmpty) {
          return values;
        }
      }
    }
    if (raw is Iterable) {
      return raw.toList(growable: false);
    }
    return raw;
  }

  Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      final mapped = <String, dynamic>{};
      value.forEach((key, mapValue) {
        mapped[key.toString()] = mapValue;
      });
      return mapped;
    }
    return null;
  }

  Widget _buildLoadMoreFooter({
    required bool showLoading,
    required bool showNoMore,
  }) {
    if (showLoading) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(0, 4, 0, 12),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.2),
          ),
        ),
      );
    }
    if (showNoMore) {
      return const ListEndTip(padding: EdgeInsets.fromLTRB(8, 6, 8, 12));
    }
    return const SizedBox(height: 4);
  }

  Widget _buildTrendDaySegment({required int days, required String label}) {
    final isSelected = _selectedDays == days;

    return Container(
      decoration: BoxDecoration(
        color: isSelected ? _figmaBlue700 : Colors.transparent,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (isSelected) {
              return;
            }
            setState(() => _selectedDays = days);
            controller.loadTrend(reset: true, days: days);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            child: Center(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.clip,
                style: TextStyle(
                  fontSize: 12,
                  height: 1,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? Colors.white : _figmaSlate800,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatTime(int? value) {
    if (value == null) {
      return '-';
    }
    var timestamp = value;
    if (timestamp < 10000000000) {
      timestamp *= 1000;
    }
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final difference = DateTime.now().difference(date);
    if (!difference.isNegative && difference.inHours < 24) {
      final hours = difference.inMinutes < 60 ? 1 : difference.inHours;
      return _formatI18nPlaceholder(
        'app.common.hours_ago_short'.tr,
        hours.toString(),
      );
    }
    return DateFormat('yyyy-MM-dd').format(date);
  }

  Widget _buildTransactionHistoryItem({
    required BuildContext context,
    required CurrencyController currency,
    required MarketListItem item,
    required int index,
    required bool isDark,
  }) {
    final statusLabel = _resolveTransactionStatusLabel(item);
    final statusText = _formatTransactionStatusLabel(statusLabel);
    final statusStyle = _resolveTransactionStatusStyle(statusLabel);
    final detailChips = _buildTransactionDetailChips(item, isDark);

    return Container(
      color: _historyRowBackground(index, isDark),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: _historyStatusBadgeWidth,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: isDark
                    ? statusStyle.backgroundColor.withValues(alpha: 0.18)
                    : statusStyle.backgroundColor,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                statusText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: statusStyle.statusColor,
                  fontSize: 10.5,
                  height: 12 / 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: _isEnglishLocale ? 0.3 : 0,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Obx(
                          () => Text(
                            currency.format(item.price ?? 0),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: const Color(0xFFBA1A1A),
                              fontSize: 19,
                              height: 21 / 19,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 116),
                        child: Text(
                          _formatTime(item.createTime),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            color: isDark ? _figmaSlate300 : _figmaSlate500,
                            fontSize: 10.5,
                            height: 14 / 10.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (detailChips.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        for (
                          var index = 0;
                          index < detailChips.length;
                          index++
                        ) ...[
                          if (index > 0) const SizedBox(width: 4),
                          Expanded(
                            flex: detailChips[index].flex,
                            child: _buildTransactionDetailChip(
                              chip: detailChips[index],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionDetailChip({required _HistoryDetailChipData chip}) {
    return Container(
      height: 18,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: chip.dimmed
            ? chip.backgroundColor.withValues(alpha: 0.55)
            : chip.backgroundColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        chip.value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: chip.dimmed
              ? chip.textColor.withValues(alpha: 0.58)
              : chip.textColor,
          fontSize: 7.5,
          height: 1,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Color _historyRowBackground(int index, bool isDark) {
    if (isDark) {
      const colors = <Color>[Color(0xFF1F2732), Color(0xFF232D39)];
      return colors[index % colors.length];
    }

    const colors = <Color>[Color(0xFFFFFFFF), Color(0xFFF2F4F6)];
    return colors[index % colors.length];
  }
}

class _HistoryStatusStyle {
  const _HistoryStatusStyle({
    required this.backgroundColor,
    required this.statusColor,
    required this.priceColor,
  });

  final Color backgroundColor;
  final Color statusColor;
  final Color priceColor;
}

class _HistoryDetailChipData {
  const _HistoryDetailChipData({
    required this.value,
    required this.flex,
    required this.backgroundColor,
    required this.textColor,
    this.dimmed = false,
  });

  final String value;
  final int flex;
  final Color backgroundColor;
  final Color textColor;
  final bool dimmed;
}

class _MarketOnSaleLoadingCard extends StatelessWidget {
  const _MarketOnSaleLoadingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120F172A),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
          BoxShadow(
            color: Color(0x0D0F172A),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(8, 5, 8, 5),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: _MarketDetailPageState._onSaleListingImageBoxWidth,
                height: _MarketDetailPageState._onSaleListingImageBoxHeight,
                decoration: BoxDecoration(
                  color: const Color(0xFFEDF1F4),
                  borderRadius: BorderRadius.circular(9),
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: SizedBox(
                  height: 74,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 16,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF2F4F6),
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            width: 18,
                            height: 18,
                            decoration: const BoxDecoration(
                              color: Color(0xFFF2F4F6),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 7),
                      Container(
                        width: 116,
                        height: 12,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF2F4F6),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      const SizedBox(height: 11),
                      Row(
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Container(
                                  width: 16,
                                  height: 16,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFF2F4F6),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  width: 72,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF2F4F6),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            width: 118,
                            height: 26,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF2F4F6),
                              borderRadius: BorderRadius.circular(7),
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
          const SizedBox(height: 8),
          Container(
            width: 82,
            height: 10,
            decoration: BoxDecoration(
              color: const Color(0xFFF2F4F6),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ],
      ),
    );
  }
}

class _OnSaleFilterSheetDialog extends StatefulWidget {
  const _OnSaleFilterSheetDialog({
    required this.initialSortField,
    required this.initialSortAsc,
    required this.initialPaintSeed,
    required this.initialPaintIndex,
    required this.initialWearMin,
    required this.initialWearMax,
    required this.initialMinPrice,
    required this.initialMaxPrice,
    required this.sortOptions,
    required this.paintKits,
    required this.wearQuickOptions,
    required this.showCsgoFilter,
    required this.formatSortLabel,
  });

  final String? initialSortField;
  final bool? initialSortAsc;
  final String? initialPaintSeed;
  final int? initialPaintIndex;
  final double? initialWearMin;
  final double? initialWearMax;
  final double? initialMinPrice;
  final double? initialMaxPrice;
  final List<_OnSaleSortOption> sortOptions;
  final List<_PaintKitOption> paintKits;
  final List<_WearQuickOption> wearQuickOptions;
  final bool showCsgoFilter;
  final String Function(_OnSaleSortOption option) formatSortLabel;

  @override
  State<_OnSaleFilterSheetDialog> createState() =>
      _OnSaleFilterSheetDialogState();
}

class _OnSaleFilterSheetDialogState extends State<_OnSaleFilterSheetDialog> {
  late final TextEditingController _paintSeedController;
  late final TextEditingController _wearMinController;
  late final TextEditingController _wearMaxController;
  late final TextEditingController _minPriceController;
  late final TextEditingController _maxPriceController;
  late String? _selectedSortField;
  late bool? _selectedSortAsc;
  late int? _selectedPaintIndex;

  @override
  void initState() {
    super.initState();
    _paintSeedController = TextEditingController(text: widget.initialPaintSeed);
    _wearMinController = TextEditingController(
      text: widget.initialWearMin?.toString(),
    );
    _wearMaxController = TextEditingController(
      text: widget.initialWearMax?.toString(),
    );
    _minPriceController = TextEditingController(
      text: widget.initialMinPrice?.toString(),
    );
    _maxPriceController = TextEditingController(
      text: widget.initialMaxPrice?.toString(),
    );
    _selectedSortField = widget.initialSortField;
    _selectedSortAsc = widget.initialSortAsc;
    _selectedPaintIndex = widget.initialPaintIndex;
  }

  @override
  void dispose() {
    _paintSeedController.dispose();
    _wearMinController.dispose();
    _wearMaxController.dispose();
    _minPriceController.dispose();
    _maxPriceController.dispose();
    super.dispose();
  }

  String? _trimToNull(String value) {
    final normalized = value.trim();
    return normalized.isEmpty ? null : normalized;
  }

  double? _parseOptionalDouble(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      return null;
    }
    return double.tryParse(normalized);
  }

  int get _activeFilterCount {
    var count = 0;
    if (_selectedSortField != null && _selectedSortField!.isNotEmpty) {
      count += 1;
    }
    if ((_trimToNull(_paintSeedController.text)?.isNotEmpty ?? false) &&
        widget.showCsgoFilter) {
      count += 1;
    }
    if (_selectedPaintIndex != null && widget.showCsgoFilter) {
      count += 1;
    }
    if ((_parseOptionalDouble(_wearMinController.text) != null ||
            _parseOptionalDouble(_wearMaxController.text) != null) &&
        widget.showCsgoFilter) {
      count += 1;
    }
    if (_parseOptionalDouble(_minPriceController.text) != null ||
        _parseOptionalDouble(_maxPriceController.text) != null) {
      count += 1;
    }
    return count;
  }

  void _resetDraft() {
    setState(() {
      _selectedSortField = null;
      _selectedSortAsc = null;
      _selectedPaintIndex = null;
      _paintSeedController.clear();
      _wearMinController.clear();
      _wearMaxController.clear();
      _minPriceController.clear();
      _maxPriceController.clear();
    });
  }

  void _applyAndClose() {
    Navigator.of(context).pop(
      _OnSaleFilterValue(
        sortField: _selectedSortField,
        sortAsc: _selectedSortAsc,
        minPrice: _parseOptionalDouble(_minPriceController.text),
        maxPrice: _parseOptionalDouble(_maxPriceController.text),
        paintSeed: _trimToNull(_paintSeedController.text),
        paintIndex: _selectedPaintIndex,
        paintWearMin: _parseOptionalDouble(_wearMinController.text),
        paintWearMax: _parseOptionalDouble(_wearMaxController.text),
      ),
    );
  }

  Widget _buildOptionChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return FilterSheetOptionChip(
      label: label,
      selected: selected,
      onTap: onTap,
      selectedStyle: FilterChipSelectedStyle.soft,
      selectedColor: FilterSheetStyle.selectedSoft,
      selectedBorderColor: FilterSheetStyle.selectedSoftBorder,
      selectedTextColor: FilterSheetStyle.primary,
      unselectedColor: FilterSheetStyle.subtleBackground,
      unselectedBorderColor: FilterSheetStyle.border,
      unselectedTextColor: FilterSheetStyle.body,
      borderRadius: FilterSheetStyle.chipRadius,
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required TextInputType keyboardType,
    required String hintText,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: FilterSheetStyle.inputDecoration(hintText: hintText),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final theme = Theme.of(context);

    return FilterSheetFrame(
      title: 'app.market.filter.text'.tr,
      confirmLabel: 'app.market.filter.finish'.tr,
      confirmCount: _activeFilterCount,
      onConfirm: _applyAndClose,
      onClose: () => Navigator.of(context).pop(),
      onReset: _resetDraft,
      resetLabel: 'app.market.filter.reset'.tr,
      bottomPadding: bottomInset,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FilterSheetSection(
              title: 'app.market.filter.sort'.tr,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: widget.sortOptions
                    .map(
                      (option) => _buildOptionChip(
                        label: widget.formatSortLabel(option),
                        selected:
                            option.field == _selectedSortField &&
                            option.asc == _selectedSortAsc,
                        onTap: () {
                          setState(() {
                            _selectedSortField = option.field;
                            _selectedSortAsc = option.asc;
                          });
                        },
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
            if (widget.showCsgoFilter) ...[
              const SizedBox(height: 16),
              FilterSheetSection(
                title: 'app.market.csgo.paint_index'.tr,
                child: _buildField(
                  controller: _paintSeedController,
                  keyboardType: TextInputType.number,
                  hintText: 'app.market.csgo.paint_index_placeholder'.tr,
                ),
              ),
              if (widget.paintKits.isNotEmpty) ...[
                const SizedBox(height: 16),
                FilterSheetSection(
                  title: 'app.market.filter.selection_phase'.tr,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildOptionChip(
                        label: 'app.market.csgo.phase_unlimited'.tr,
                        selected: _selectedPaintIndex == null,
                        onTap: () => setState(() => _selectedPaintIndex = null),
                      ),
                      ...widget.paintKits.map(
                        (option) => _buildOptionChip(
                          label: option.label,
                          selected: _selectedPaintIndex == option.id,
                          onTap: () =>
                              setState(() => _selectedPaintIndex = option.id),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (widget.wearQuickOptions.isNotEmpty) ...[
                const SizedBox(height: 16),
                FilterSheetSection(
                  title: 'app.market.filter.csgo.wear_interval'.tr,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildField(
                              controller: _wearMinController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              hintText: '0.00',
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              '~',
                              style: TextStyle(
                                color: FilterSheetStyle.body,
                                fontSize: 16,
                                height: 24 / 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Expanded(
                            child: _buildField(
                              controller: _wearMaxController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              hintText: '1.00',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'app.market.filter.selection_quick'.tr,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: FilterSheetStyle.hint,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: widget.wearQuickOptions
                            .map((option) {
                              final isSelected =
                                  _wearMinController.text == option.minText &&
                                  _wearMaxController.text == option.maxText;
                              return _buildOptionChip(
                                label: option.label,
                                selected: isSelected,
                                onTap: () {
                                  setState(() {
                                    _wearMinController.text = option.minText;
                                    _wearMaxController.text = option.maxText;
                                  });
                                },
                              );
                            })
                            .toList(growable: false),
                      ),
                    ],
                  ),
                ),
              ],
            ],
            const SizedBox(height: 16),
            FilterSheetSection(
              title: 'app.market.filter.price_range'.tr,
              child: Row(
                children: [
                  Expanded(
                    child: _buildField(
                      controller: _minPriceController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      hintText: 'app.market.filter.price_lowest'.tr,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      '~',
                      style: TextStyle(
                        color: FilterSheetStyle.body,
                        fontSize: 16,
                        height: 24 / 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Expanded(
                    child: _buildField(
                      controller: _maxPriceController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      hintText: 'app.market.filter.price_highest'.tr,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopToolbarFilterGlyph extends StatelessWidget {
  const _TopToolbarFilterGlyph({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 16,
      height: 16,
      child: CustomPaint(painter: _TopToolbarFilterGlyphPainter(color: color)),
    );
  }
}

class _TopToolbarFilterGlyphPainter extends CustomPainter {
  const _TopToolbarFilterGlyphPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;

    final left = size.width * 0.20;
    final right = size.width * 0.80;
    final lineYs = <double>[
      size.height * 0.29,
      size.height * 0.50,
      size.height * 0.71,
    ];

    for (final lineY in lineYs) {
      canvas.drawLine(Offset(left, lineY), Offset(right, lineY), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _TopToolbarFilterGlyphPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _PressableScale extends StatefulWidget {
  const _PressableScale({
    super.key,
    required this.child,
    required this.onTap,
    required this.borderRadius,
    required this.overlayColor,
    this.minScale = 0.96,
    this.onLongPress,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final BorderRadius borderRadius;
  final Color overlayColor;
  final double minScale;

  @override
  State<_PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<_PressableScale> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) {
      return;
    }
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _pressed && widget.onTap != null ? widget.minScale : 1,
      duration: const Duration(milliseconds: 90),
      curve: Curves.easeOutCubic,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          onLongPress: widget.onLongPress,
          borderRadius: widget.borderRadius,
          onTapDown: (_) => _setPressed(true),
          onTapUp: (_) => _setPressed(false),
          onTapCancel: () => _setPressed(false),
          overlayColor: WidgetStateProperty.resolveWith<Color?>((states) {
            if (states.contains(WidgetState.pressed)) {
              return widget.overlayColor;
            }
            if (states.contains(WidgetState.hovered)) {
              return widget.overlayColor.withValues(alpha: 0.55);
            }
            return null;
          }),
          splashFactory: InkRipple.splashFactory,
          child: widget.child,
        ),
      ),
    );
  }
}

class _WearOption {
  const _WearOption({required this.id, required this.label, this.price});

  final int id;
  final String label;
  final dynamic price;
}

class _OnSaleSortOption {
  const _OnSaleSortOption({
    required this.field,
    required this.asc,
    required this.labelKey,
    this.suffix,
  });

  final String? field;
  final bool? asc;
  final String labelKey;
  final String? suffix;
}

class _OnSaleFilterValue {
  const _OnSaleFilterValue({
    this.sortField,
    this.sortAsc,
    this.minPrice,
    this.maxPrice,
    this.paintSeed,
    this.paintIndex,
    this.paintWearMin,
    this.paintWearMax,
  });

  final String? sortField;
  final bool? sortAsc;
  final double? minPrice;
  final double? maxPrice;
  final String? paintSeed;
  final int? paintIndex;
  final double? paintWearMin;
  final double? paintWearMax;
}

class _PaintKitOption {
  const _PaintKitOption({required this.id, required this.label});

  final int id;
  final String label;
}

class _WearQuickOption {
  const _WearQuickOption(this.label, this.minText, this.maxText);

  final String label;
  final String minText;
  final String maxText;
}

class _WearQuickMenuSelection {
  const _WearQuickMenuSelection(this.option);

  const _WearQuickMenuSelection.clear() : option = null;

  final _WearQuickOption? option;
}

class _PhaseMenuSelection {
  const _PhaseMenuSelection(this.option);

  const _PhaseMenuSelection.clear() : option = null;

  final _PaintKitOption? option;
}
