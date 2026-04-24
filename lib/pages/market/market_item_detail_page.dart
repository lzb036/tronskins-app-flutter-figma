import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:tronskins_app/common/widgets/settings_style_app_bar.dart';
import 'package:get/get.dart';
import 'package:tronskins_app/api/market.dart';
import 'package:tronskins_app/api/model/market/market_models.dart';
import 'package:tronskins_app/api/shop.dart';
import 'package:tronskins_app/api/shop_product.dart';
import 'package:tronskins_app/common/hooks/currency/CurrencyController.dart';
import 'package:tronskins_app/common/storage/user_storage.dart';
import 'package:tronskins_app/common/utils/app_snackbar.dart';
import 'package:tronskins_app/common/widgets/back_to_top_overlay.dart';
import 'package:tronskins_app/common/widgets/glass_notice_dialog.dart';
import 'package:tronskins_app/common/widgets/steam_style_confirm_dialog.dart';
import 'package:tronskins_app/components/game_item/game_item_models.dart';
import 'package:tronskins_app/components/game_item/gem_row.dart';
import 'package:tronskins_app/components/game_item/sticker_row.dart';
import 'package:tronskins_app/components/game_item/wear_progress_bar.dart';
import 'package:tronskins_app/routes/app_routes.dart';

class MarketItemDetailPage extends StatefulWidget {
  const MarketItemDetailPage({super.key});

  @override
  State<MarketItemDetailPage> createState() => _MarketItemDetailPageState();
}

class _MarketItemDetailPageState extends State<MarketItemDetailPage> {
  static const Color _pageBackground = Color(0xFFF7F9FB);
  static const Color _surfaceCard = Colors.white;
  static const Color _surfaceSoft = Color(0xFFF2F4F6);
  static const Color _lineColor = Color(0xFFF1F5F9);
  static const Color _textPrimary = Color(0xFF191C1E);
  static const Color _textSecondary = Color(0xFF757684);
  static const Color _brandBlue = Color(0xFF00288E);
  static const Color _brandBlueLight = Color(0xFF3B82F6);
  static const Color _priceOrange = Color(0xFFFF6B35);
  static const Color _dangerRed = Color(0xFFBA1A1A);
  static const Color _dangerRedSoft = Color(0xFFFFDAD6);
  static const Color _successGreen = Color(0xFF22C55E);

  final ApiMarketServer _marketServer = ApiMarketServer();
  final ApiShopServer _shopServer = ApiShopServer();
  final ApiShopProductServer _shopApi = ApiShopProductServer();

  late MarketListItem _item;
  MarketSchemaInfo? _schema;
  MarketUserInfo? _user;
  Map<String, MarketSchemaInfo> _schemas = {};
  Map<String, dynamic> _stickers = {};
  Map<String, dynamic>? _shopInfo;
  bool _loadingShopInfo = false;
  bool _isPurchasing = false;
  bool _favorited = false;
  bool _favoriteSubmitting = false;

  @override
  void initState() {
    super.initState();
    final args = Get.arguments as Map<String, dynamic>? ?? {};
    _item = _parseItem(args['item']);
    _schema = _parseSchema(args['schema']);
    _user = _parseUser(args['user']);
    _schemas = _parseSchemas(args['schemas']);
    _stickers = _parseStickerMap(args['stickers']);
    _favorited = _item.favorited == true;
    _loadShopInfo();
  }

  MarketListItem _parseItem(dynamic raw) {
    if (raw is MarketListItem) {
      return raw;
    }
    if (raw is Map) {
      return MarketListItem.fromJson(Map<String, dynamic>.from(raw));
    }
    return const MarketListItem(raw: {});
  }

  MarketSchemaInfo? _parseSchema(dynamic raw) {
    if (raw is MarketSchemaInfo) {
      return raw;
    }
    if (raw is Map) {
      return MarketSchemaInfo.fromJson(Map<String, dynamic>.from(raw));
    }
    return null;
  }

  MarketUserInfo? _parseUser(dynamic raw) {
    if (raw is MarketUserInfo) {
      return raw;
    }
    if (raw is Map) {
      return MarketUserInfo.fromJson(Map<String, dynamic>.from(raw));
    }
    return null;
  }

  Map<String, MarketSchemaInfo> _parseSchemas(dynamic raw) {
    if (raw is Map) {
      final map = <String, MarketSchemaInfo>{};
      raw.forEach((key, value) {
        if (value is MarketSchemaInfo) {
          map[key.toString()] = value;
        } else if (value is Map) {
          map[key.toString()] = MarketSchemaInfo.fromJson(
            Map<String, dynamic>.from(value),
          );
        }
      });
      return map;
    }
    return {};
  }

  Map<String, dynamic> _parseStickerMap(dynamic raw) {
    if (raw is Map) {
      final map = <String, dynamic>{};
      raw.forEach((key, value) {
        map[key.toString()] = value;
      });
      return map;
    }
    return {};
  }

  Map<String, dynamic>? _resolveAsset() {
    final raw = _item.raw;
    if (_item.appId == 730 && raw['csgoAsset'] is Map<String, dynamic>) {
      return raw['csgoAsset'] as Map<String, dynamic>;
    }
    if (_item.appId == 440 && raw['tf2Asset'] is Map<String, dynamic>) {
      return raw['tf2Asset'] as Map<String, dynamic>;
    }
    if (_item.appId == 570 && raw['dota2Asset'] is Map<String, dynamic>) {
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

  bool _isOwnOnSaleItem() {
    if (_item.own == true) {
      return true;
    }
    final currentUser = UserStorage.getUserInfo();
    final currentUserId = _asInt(currentUser?.id);
    final currentShopId = _asInt(currentUser?.shop?.id);
    final sellerId = _item.userId;
    if (sellerId == null) {
      return false;
    }
    return sellerId == currentUserId || sellerId == currentShopId;
  }

  List<GameItemSticker> _parseKeychains(dynamic raw) {
    final fromRaw = parseStickerList(
      raw,
      schemaMap: _schemas,
      stickerMap: _stickers,
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
          final schema = _schemas[schemaId.toString()];
          final url = schema?.imageUrl;
          if (url != null && url.isNotEmpty) {
            list.add(GameItemSticker(url));
          }
        }
      } else if (entry is num || entry is String) {
        final schema = _schemas[entry.toString()];
        final url = schema?.imageUrl;
        if (url != null && url.isNotEmpty) {
          list.add(GameItemSticker(url));
        }
      }
    }
    return list;
  }

  List<GameItemSticker> _parseStickers(Map<String, dynamic>? asset) {
    for (final candidate in _stickerCandidates(asset)) {
      final parsed = parseStickerList(
        _normalizeStickerEntries(candidate),
        schemaMap: _schemas,
        stickerMap: _stickers,
      );
      if (parsed.isNotEmpty) {
        return parsed;
      }
    }
    return const [];
  }

  List<_StickerDetailData> _resolveStickerDetailsFromItem(
    Map<String, dynamic>? asset,
  ) {
    for (final candidate in _stickerCandidates(asset)) {
      final details = _resolveStickerDetails(candidate);
      if (details.isNotEmpty) {
        return details;
      }
    }
    return const [];
  }

  List<dynamic> _stickerCandidates(Map<String, dynamic>? asset) {
    final rawAsset =
        _asMap(_item.raw['asset']) ?? _asMap(_item.raw['itemAsset']);
    final rawCsgoAsset =
        _asMap(_item.raw['csgoAsset']) ?? _asMap(_item.raw['csgo_asset']);
    final rawTf2Asset =
        _asMap(_item.raw['tf2Asset']) ?? _asMap(_item.raw['tf2_asset']);
    final rawDotaAsset =
        _asMap(_item.raw['dota2Asset']) ?? _asMap(_item.raw['dota2_asset']);

    return <dynamic>[
      asset?['stickers'],
      asset?['stickerList'],
      asset?['sticker_list'],
      asset?['sticker'],
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
      _item.raw['stickers'],
      _item.raw['stickerList'],
      _item.raw['sticker_list'],
      _item.raw['sticker'],
    ];
  }

  List<_StickerDetailData> _resolveStickerDetails(dynamic raw) {
    final entries = _normalizeStickerEntries(raw);
    final details = <_StickerDetailData>[];
    for (final entry in entries) {
      final detail = _resolveStickerDetail(entry);
      if (detail != null) {
        details.add(detail);
      }
    }
    return details;
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
            .map((entry) => entry.trim())
            .where((entry) => entry.isNotEmpty)
            .toList(growable: false);
        if (values.isNotEmpty) {
          return values;
        }
      }
      return <dynamic>[value];
    }
    return const [];
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

  _StickerDetailData? _resolveStickerDetail(dynamic entry) {
    String? imageUrl;
    String? name;
    double? price;
    String? stickerId;

    if (entry is Map) {
      imageUrl = _extractText(entry, <String>[
        'image_url',
        'imageUrl',
        'image',
      ]);
      name = _extractText(entry, <String>['market_name', 'marketName', 'name']);
      price = _extractDouble(entry, <String>[
        'market_price',
        'marketPrice',
        'price',
      ]);
      stickerId = _extractText(entry, <String>[
        'sticker_id',
        'stickerId',
        'schema_id',
        'schemaId',
        'id',
      ]);
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

    final schema = stickerId == null ? null : _schemas[stickerId];
    final stickerMeta = stickerId == null
        ? null
        : _resolveStickerMeta(stickerId);
    imageUrl ??=
        _extractText(stickerMeta, <String>['image_url', 'imageUrl', 'image']) ??
        schema?.imageUrl;
    name ??=
        _extractText(stickerMeta, <String>[
          'market_name',
          'marketName',
          'name',
        ]) ??
        schema?.marketName;
    price ??=
        _extractDouble(stickerMeta, <String>[
          'market_price',
          'marketPrice',
          'price',
        ]) ??
        _extractDouble(schema?.raw, <String>[
          'market_price',
          'marketPrice',
          'price',
        ]);

    if (imageUrl == null || imageUrl.isEmpty) {
      return null;
    }

    return _StickerDetailData(
      imageUrl: _normalizeSteamImageUrl(imageUrl),
      name: name,
      price: price,
    );
  }

  Map<String, dynamic>? _resolveStickerMeta(String stickerId) {
    dynamic value;
    if (_stickers.containsKey(stickerId)) {
      value = _stickers[stickerId];
    }
    if (value == null) {
      for (final entry in _stickers.entries) {
        if (entry.key.toString() == stickerId) {
          value = entry.value;
          break;
        }
      }
    }
    if (value is MarketSchemaInfo) {
      return value.raw;
    }
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

  Future<void> _purchase() async {
    if (_isPurchasing) {
      return;
    }
    final user = UserStorage.getUserInfo();
    if (user == null) {
      AppSnackbar.info('app.system.message.nologin'.tr);
      return;
    }
    final id = _item.id?.toString();
    final price = _item.price;
    final appId = _item.appId ?? _schema?.appId ?? 730;
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
    if (!mounted) {
      return;
    }
    setState(() => _isPurchasing = true);
    try {
      final res = await _shopApi.orderItemPurchase(
        appId: appId,
        id: id,
        price: price,
      );
      final datas = res.datas;
      if (datas is String) {
        if (datas.contains('Steam issue')) {
          AppSnackbar.error('app.steam.message.trading_restrictions'.tr);
          return;
        }
        if (datas.contains('Inventory privacy')) {
          final nickname = user.config?.nickname ?? user.nickname ?? '';
          AppSnackbar.error('${'app.inventory.message.privacy'.tr}$nickname');
          return;
        }
      }
      if (res.success) {
        if (!mounted) {
          return;
        }
        Navigator.of(context).pop(true);
      } else {
        AppSnackbar.error(
          res.message.isNotEmpty
              ? res.message
              : (datas is String && datas.trim().isNotEmpty
                    ? datas
                    : 'app.trade.filter.failed'.tr),
        );
      }
    } catch (_) {
      AppSnackbar.error('app.trade.filter.failed'.tr);
    } finally {
      if (mounted) {
        setState(() => _isPurchasing = false);
      }
    }
  }

  Future<void> _toggleFavorite() async {
    if (_favoriteSubmitting) {
      return;
    }
    if (UserStorage.getUserInfo() == null) {
      await showGlassNoticeDialog(
        context,
        message: 'app.system.message.nologin'.tr,
        icon: Icons.lock_outline_rounded,
      );
      return;
    }
    final itemId = _item.id;
    final appId = _item.appId ?? _schema?.appId ?? 730;
    if (itemId == null) {
      AppSnackbar.error('app.trade.filter.failed'.tr);
      return;
    }
    setState(() => _favoriteSubmitting = true);
    try {
      final res = _favorited
          ? await _marketServer.removeFavorite(itemId: itemId)
          : await _marketServer.addFavorite(appId: appId, itemId: itemId);
      if (!res.success) {
        AppSnackbar.error(
          res.message.isNotEmpty ? res.message : 'app.trade.filter.failed'.tr,
        );
        return;
      }
      setState(() => _favorited = !_favorited);
      AppSnackbar.success(
        (_favorited
                ? 'app.user.collection.message.success'
                : 'app.user.collection.uncollect_success')
            .tr,
      );
    } catch (_) {
      AppSnackbar.error('app.trade.filter.failed'.tr);
    } finally {
      if (mounted) {
        setState(() => _favoriteSubmitting = false);
      }
    }
  }

  String? _resolveSellerUuid() {
    final fromUser = _user?.uuid?.trim();
    if (fromUser != null && fromUser.isNotEmpty) {
      return fromUser;
    }
    final fromRawUser = _item.raw['user'];
    if (fromRawUser is Map) {
      final uuid = fromRawUser['uuid']?.toString().trim();
      if (uuid != null && uuid.isNotEmpty) {
        return uuid;
      }
    }
    final fromRaw = _item.raw['uuid']?.toString().trim();
    if (fromRaw != null && fromRaw.isNotEmpty) {
      return fromRaw;
    }
    final fromShopInfo = _shopInfo?['uuid']?.toString().trim();
    if (fromShopInfo != null && fromShopInfo.isNotEmpty) {
      return fromShopInfo;
    }
    return null;
  }

  String _resolveAvatarUrl(String? avatar) {
    if (avatar == null || avatar.isEmpty) {
      return '';
    }
    if (avatar.startsWith('http')) {
      return avatar;
    }
    return 'https://www.tronskins.com/fms/image$avatar';
  }

  Future<void> _loadShopInfo() async {
    final uuid = _resolveSellerUuid();
    if (uuid == null || uuid.isEmpty) {
      return;
    }
    if (mounted) {
      setState(() => _loadingShopInfo = true);
    }
    try {
      final res = await _shopServer.getUserShopInfo(params: {'uuid': uuid});
      if (!mounted) {
        return;
      }
      if (res.success && res.datas != null) {
        setState(() => _shopInfo = res.datas);
      }
    } catch (_) {
      // Ignore failures here. Shop info is supplemental content.
    } finally {
      if (mounted) {
        setState(() => _loadingShopInfo = false);
      }
    }
  }

  void _openSellerStore() {
    final uuid = _resolveSellerUuid();
    if (uuid == null || uuid.isEmpty) {
      AppSnackbar.error('app.trade.filter.failed'.tr);
      return;
    }
    final existingShopName = _shopInfo?['name']?.toString().trim();
    final existingShopAvatar = _shopInfo?['avatar']?.toString().trim();
    final initialShopInfo = <String, dynamic>{
      if (_shopInfo != null) ...Map<String, dynamic>.from(_shopInfo!),
      if ((existingShopName == null || existingShopName.isEmpty) &&
          (_user?.nickname?.trim().isNotEmpty ?? false))
        'name': _user!.nickname!.trim(),
      if ((existingShopAvatar == null || existingShopAvatar.isEmpty) &&
          (_user?.avatar?.trim().isNotEmpty ?? false))
        'avatar': _user!.avatar!.trim(),
      'uuid': uuid,
    };
    Get.toNamed(
      Routers.MARKET_SELLER_SHOP,
      arguments: {
        'uuid': uuid,
        'appId': _item.appId ?? _schema?.appId ?? 730,
        'shopInfo': initialShopInfo,
      },
    );
  }

  bool get _isEnglishLocale =>
      (Get.locale?.languageCode ?? '').toLowerCase().startsWith('en');

  bool get _isChineseLocale =>
      (Get.locale?.languageCode ?? '').toLowerCase().startsWith('zh');

  bool get _isTraditionalChineseLocale {
    final countryCode = (Get.locale?.countryCode ?? '').toUpperCase();
    return _isChineseLocale &&
        (countryCode == 'TW' || countryCode == 'HK' || countryCode == 'MO');
  }

  String _stickerSectionTitle() =>
      _isChineseLocale ? '包含印花' : 'Containing Stickers';

  String _stickerFallbackName(int index) =>
      _isChineseLocale ? '印花 ${index + 1}' : 'Sticker ${index + 1}';

  String get _pageTitle {
    if (_isEnglishLocale) {
      return 'Skin Details';
    }
    if (_isTraditionalChineseLocale) {
      return '飾品詳情';
    }
    if (_isChineseLocale) {
      return '饰品详情';
    }
    return 'app.market.product.details'.tr;
  }

  String get _currentPriceLabel => _isEnglishLocale ? 'Current' : '现价';

  String get _referencePriceLabel => 'app.market.detail.steam_price'.tr;

  String get _itemAttributesTitle =>
      _isEnglishLocale ? 'Item Attributes' : '物品属性';

  String get _floatValueLabel => _isEnglishLocale ? 'Wear' : '磨损值';

  String get _rarityLabel => _isEnglishLocale ? 'Rarity' : '稀有度';

  String get _typeLabel => _isEnglishLocale ? 'Type' : '类型';

  String get _exteriorLabel => _isEnglishLocale ? 'Exterior' : '外观';

  String get _qualityLabel => _isEnglishLocale ? 'Quality' : '品质';

  String get _collectionLabel => _isEnglishLocale ? 'Collection' : '收藏系列';

  String get _wishlistLabel => _isEnglishLocale ? 'Wishlist' : '收藏';

  String get _buyNowLabel => _isEnglishLocale ? 'Buy Now' : '立即购买';

  String get _viewStoreLabel => _isEnglishLocale ? 'View Store' : '查看店铺';

  String get _patternTemplateLabel =>
      _isEnglishLocale ? 'Pattern Template' : '图案模板';

  String get _skinNumberLabel => _isEnglishLocale ? 'Skin Number' : '皮肤编号';

  String _shopDeliverLabel() {
    return 'app.user.shop.deliver'.tr;
  }

  void _showShopDeliverTips() {
    Get.dialog<void>(
      AlertDialog(
        title: Text('app.system.tips.warm'.tr),
        content: Text('app.user.shop.message.order_placed'.tr),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('app.user.shop.deliver_iknow'.tr),
          ),
        ],
      ),
    );
  }

  Widget _buildRarityBadge(String label, String? colorHex) {
    final baseColor = _parseHex(colorHex) ?? const Color(0xFF9333EA);
    final endColor = Color.lerp(baseColor, Colors.black, 0.35) ?? baseColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [baseColor, endColor],
        ),
        boxShadow: [
          BoxShadow(
            color: baseColor.withValues(alpha: 0.24),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          height: 15 / 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildLoadingPill({
    double? width,
    required double height,
    BorderRadiusGeometry? borderRadius,
    Color color = const Color(0xFFE7EBF0),
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

  Widget _buildShopInfoLoadingCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surfaceSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildLoadingPill(width: 132, height: 14),
                const SizedBox(height: 8),
                _buildLoadingPill(width: 88, height: 11),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _buildLoadingPill(
            width: 84,
            height: 34,
            borderRadius: BorderRadius.circular(10),
            color: Colors.white,
          ),
        ],
      ),
    );
  }

  Widget _buildShopInfoCard() {
    if (_loadingShopInfo) {
      return _buildShopInfoLoadingCard();
    }

    final shopInfo = _shopInfo;
    final hasShopInfo = shopInfo != null && shopInfo.isNotEmpty;
    if (!hasShopInfo && _user == null) {
      return const SizedBox.shrink();
    }

    final fallbackName = _user?.nickname?.trim();
    final shopName =
        _extractText(shopInfo, <String>['name', 'shopName']) ??
        ((fallbackName != null && fallbackName.isNotEmpty)
            ? fallbackName
            : '-');
    final avatar = _resolveAvatarUrl(
      _extractText(shopInfo, <String>['avatar']) ?? _user?.avatar,
    );
    final isOnline =
        shopInfo?['isOnline'] == true || shopInfo?['is_online'] == true;
    final canOpenStore = (_resolveSellerUuid()?.isNotEmpty ?? false);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surfaceSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: ClipOval(
                        child: avatar.isEmpty
                            ? const Icon(
                                Icons.storefront_outlined,
                                size: 20,
                                color: _textSecondary,
                              )
                            : CachedNetworkImage(
                                imageUrl: avatar,
                                fit: BoxFit.cover,
                                errorWidget: (context, _, __) => const Icon(
                                  Icons.storefront_outlined,
                                  size: 20,
                                  color: _textSecondary,
                                ),
                              ),
                      ),
                    ),
                    if (isOnline)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: _successGreen,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              shopName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _textPrimary,
                                fontSize: 14,
                                height: 20 / 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      GestureDetector(
                        onTap: _showShopDeliverTips,
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD8E2FF),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _shopDeliverLabel(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF004395),
                              fontSize: 9,
                              height: 13.5 / 9,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: canOpenStore ? _openSellerStore : null,
              borderRadius: BorderRadius.circular(8),
              child: Ink(
                padding: const EdgeInsets.symmetric(
                  horizontal: 17,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFC4C5D5)),
                ),
                child: Text(
                  _viewStoreLabel,
                  style: TextStyle(
                    color: canOpenStore ? _textPrimary : _textSecondary,
                    fontSize: 12,
                    height: 16 / 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

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

  String? _resolveDescription(Map<String, dynamic>? asset) {
    for (final source in <dynamic>[_item.raw, asset, _schema?.raw]) {
      final descListText = _extractDescListDescription(source);
      if (descListText != null && descListText.isNotEmpty) {
        return descListText;
      }
      final text = _extractText(source, const <String>[
        'description',
        'desc',
        'market_desc',
        'marketDesc',
        'description_en',
        'descriptionEn',
      ]);
      final cleanedText = _cleanDescriptionText(text);
      if (cleanedText != null && cleanedText.isNotEmpty) {
        return _normalizeDescriptionText(cleanedText);
      }
      final listText = _extractDescriptionListText(source);
      if (listText != null && listText.isNotEmpty) {
        return _normalizeDescriptionText(listText);
      }
    }
    return null;
  }

  String? _extractDescListDescription(dynamic raw) {
    if (raw is! Map) {
      return null;
    }
    for (final key in const <String>[
      'descList',
      'desc_list',
      'descriptionList',
      'description_list',
    ]) {
      final value = raw[key];
      if (value is! Iterable) {
        continue;
      }
      for (final entry in value) {
        if (entry is! Map) {
          continue;
        }
        final name = entry['name']?.toString().trim().toLowerCase();
        if (name != 'description' && name != 'desc') {
          continue;
        }
        final text = _cleanDescriptionText(
          entry['value']?.toString() ??
              entry['text']?.toString() ??
              entry['label']?.toString(),
        );
        if (text != null && text.isNotEmpty) {
          return _normalizeDescriptionText(text);
        }
      }
    }
    return null;
  }

  String? _extractDescriptionListText(dynamic raw) {
    if (raw is! Map) {
      return null;
    }
    for (final key in const <String>[
      'descriptions',
      'description_list',
      'descriptionList',
      'owner_descriptions',
      'ownerDescriptions',
      'item_descriptions',
      'itemDescriptions',
      'fraudwarnings',
      'fraudWarnings',
    ]) {
      final texts = _collectDescriptionTexts(raw[key]);
      if (texts.isNotEmpty) {
        return texts.join('\n');
      }
    }
    return null;
  }

  String? _buildLegacyDescriptionFallback({
    required TagInfo? type,
    required TagInfo? rarity,
    required TagInfo? quality,
    required TagInfo? exterior,
    required TagInfo? itemSet,
  }) {
    final lines = <String>[];
    final tags = <String>[
      if (type?.label?.trim().isNotEmpty == true) type!.label!.trim(),
      if (rarity?.label?.trim().isNotEmpty == true) rarity!.label!.trim(),
      if (quality?.label?.trim().isNotEmpty == true) quality!.label!.trim(),
    ];
    if (tags.isNotEmpty) {
      lines.add(tags.join(' · '));
    }
    if (exterior?.label?.trim().isNotEmpty == true) {
      lines.add(
        _isEnglishLocale
            ? 'Exterior: ${exterior!.label!.trim()}'
            : '外观：${exterior!.label!.trim()}',
      );
    }
    if (itemSet?.label?.trim().isNotEmpty == true) {
      lines.add(itemSet!.label!.trim());
    }
    if (lines.isEmpty) {
      return null;
    }
    return lines.join('\n');
  }

  String _normalizeDescriptionText(String raw) {
    return raw
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .replaceAll(RegExp(r'\n\s*\n+'), '\n')
        .replaceAll(RegExp(r'[ \t]+\n'), '\n')
        .trim();
  }

  List<String> _collectDescriptionTexts(dynamic raw) {
    if (raw is String) {
      final text = _cleanDescriptionText(raw);
      return text == null ? const [] : <String>[text];
    }
    if (raw is Iterable) {
      final items = <String>[];
      for (final entry in raw) {
        if (entry is String) {
          final text = _cleanDescriptionText(entry);
          if (text != null) {
            items.add(text);
          }
          continue;
        }
        if (entry is Map) {
          final text = _cleanDescriptionText(
            entry['value']?.toString() ??
                entry['text']?.toString() ??
                entry['label']?.toString(),
          );
          if (text != null) {
            items.add(text);
          }
        }
      }
      return items;
    }
    return const [];
  }

  String? _cleanDescriptionText(String? raw) {
    if (raw == null) {
      return null;
    }
    final text = raw
        .replaceAll('<br>', '\n')
        .replaceAll('<br/>', '\n')
        .replaceAll('<br />', '\n')
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .trim();
    if (text.isEmpty || text == 'null') {
      return null;
    }
    if (text.contains('%owner_steamid%') ||
        text.contains('%assetid%') ||
        text.contains('steam://')) {
      return null;
    }
    return text;
  }

  String? _cleanFieldValue(String? value) {
    if (value == null) {
      return null;
    }
    final normalized = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.isEmpty || normalized == 'null') {
      return null;
    }
    return normalized;
  }

  void _addInfoField(
    List<MapEntry<String, String>> fields,
    Set<String> seenLabels, {
    required String label,
    required String? value,
    String? identity,
  }) {
    final displayLabel = _cleanFieldValue(label);
    final displayValue = _cleanFieldValue(value);
    if (displayLabel == null || displayValue == null) {
      return;
    }
    final key = (identity ?? displayLabel).toLowerCase();
    if (seenLabels.contains(key)) {
      return;
    }
    seenLabels.add(key);
    fields.add(MapEntry(displayLabel, displayValue));
  }

  List<MapEntry<String, String>> _buildNameSummaryFields({
    required String? paintSeedValue,
    required String? paintIndexValue,
  }) {
    final fields = <MapEntry<String, String>>[];
    final seen = <String>{};
    _addInfoField(
      fields,
      seen,
      label: _patternTemplateLabel,
      value: paintSeedValue,
      identity: 'paint_seed',
    );
    _addInfoField(
      fields,
      seen,
      label: _skinNumberLabel,
      value: paintIndexValue,
      identity: 'paint_index',
    );
    return fields;
  }

  List<MapEntry<String, String>> _buildAttributeDescriptionFields({
    required Map<String, dynamic>? asset,
    required int appId,
    required String? typeValue,
    required String? rarityValue,
    required String? qualityValue,
    required String? exteriorValue,
    required String? collectionValue,
    required String? heroValue,
    required String? slotValue,
  }) {
    final fields = <MapEntry<String, String>>[];
    final seen = <String>{};
    _addInfoField(
      fields,
      seen,
      label: _typeLabel,
      value: typeValue,
      identity: 'type',
    );
    _addInfoField(
      fields,
      seen,
      label: _rarityLabel,
      value: rarityValue,
      identity: 'rarity',
    );
    _addInfoField(
      fields,
      seen,
      label: _qualityLabel,
      value: qualityValue,
      identity: 'quality',
    );
    _addInfoField(
      fields,
      seen,
      label: _exteriorLabel,
      value: exteriorValue,
      identity: 'exterior',
    );
    if (appId == 570) {
      _addInfoField(
        fields,
        seen,
        label: _isEnglishLocale ? 'Hero' : '英雄',
        value: heroValue,
        identity: 'hero',
      );
      _addInfoField(
        fields,
        seen,
        label: _isEnglishLocale ? 'Slot' : '槽位',
        value: slotValue,
        identity: 'slot',
      );
    }
    _addDescListAttributeFields(fields, seen, asset);
    _addInfoField(
      fields,
      seen,
      label: _collectionLabel,
      value: collectionValue,
      identity: 'itemset_name',
    );
    return fields;
  }

  void _addDescListAttributeFields(
    List<MapEntry<String, String>> fields,
    Set<String> seen,
    Map<String, dynamic>? asset,
  ) {
    for (final source in <dynamic>[_item.raw, asset, _schema?.raw]) {
      if (source is! Map) {
        continue;
      }
      for (final key in const <String>[
        'descList',
        'desc_list',
        'descriptionList',
        'description_list',
      ]) {
        final value = source[key];
        if (value is! Iterable) {
          continue;
        }
        for (final entry in value) {
          if (entry is! Map) {
            continue;
          }
          final parsed = _parseDescListAttributeField(entry);
          if (parsed == null) {
            continue;
          }
          final descName = entry['name']?.toString().trim();
          final normalizedDescName = descName?.toLowerCase();
          _addInfoField(
            fields,
            seen,
            label: parsed.key,
            value: parsed.value,
            identity: normalizedDescName == 'exterior_wear'
                ? 'exterior'
                : (descName != null && descName.isNotEmpty
                      ? descName
                      : parsed.key),
          );
        }
      }
    }
  }

  MapEntry<String, String>? _parseDescListAttributeField(Map entry) {
    final name = entry['name']?.toString().trim() ?? '';
    final normalizedName = name.toLowerCase();
    if (normalizedName.isEmpty ||
        normalizedName == 'blank' ||
        normalizedName == 'description' ||
        normalizedName == 'desc' ||
        normalizedName == 'sticker_info') {
      return null;
    }
    final rawText =
        entry['value']?.toString() ??
        entry['text']?.toString() ??
        entry['label']?.toString();
    final cleaned = _cleanDescriptionText(rawText);
    if (cleaned == null || cleaned.contains('\n')) {
      return null;
    }
    final text = _cleanFieldValue(_normalizeDescriptionText(cleaned));
    if (text == null || text.length > 80) {
      return null;
    }
    if (normalizedName == 'itemset_name') {
      return MapEntry(_collectionLabel, text);
    }
    if (normalizedName == 'exterior_wear') {
      final split = _splitDescListLabelValue(text);
      return MapEntry(_exteriorLabel, split?.value ?? text);
    }
    final split = _splitDescListLabelValue(text);
    if (split != null) {
      return MapEntry(_normalizeDescListLabel(split.key), split.value);
    }
    final label = _labelForDescListName(name);
    if (label == null) {
      return null;
    }
    return MapEntry(label, text);
  }

  MapEntry<String, String>? _splitDescListLabelValue(String text) {
    final separatorIndex = text.indexOf(':');
    if (separatorIndex <= 0 || separatorIndex >= text.length - 1) {
      return null;
    }
    final label = text.substring(0, separatorIndex).trim();
    final value = text.substring(separatorIndex + 1).trim();
    if (label.isEmpty || value.isEmpty || label.length > 30) {
      return null;
    }
    return MapEntry(label, value);
  }

  String _normalizeDescListLabel(String label) {
    final lower = label.toLowerCase();
    if (lower == 'exterior') {
      return _exteriorLabel;
    }
    if (lower == 'quality') {
      return _qualityLabel;
    }
    if (lower == 'rarity') {
      return _rarityLabel;
    }
    if (lower == 'type') {
      return _typeLabel;
    }
    return label;
  }

  String? _labelForDescListName(String name) {
    final normalized = name.trim();
    if (normalized.isEmpty) {
      return null;
    }
    final lower = normalized.toLowerCase();
    if (lower == 'itemset_name') {
      return _collectionLabel;
    }
    if (lower == 'exterior_wear') {
      return _exteriorLabel;
    }
    return normalized
        .split(RegExp(r'[_\s-]+'))
        .where((part) => part.isNotEmpty)
        .map((part) => part[0].toUpperCase() + part.substring(1))
        .join(' ');
  }

  Widget _buildOverviewStatTile({
    required String label,
    required String value,
    bool showDivider = false,
    bool showTopDivider = false,
    bool allowValueWrap = false,
  }) {
    return Container(
      constraints: const BoxConstraints(minHeight: 94),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
      decoration: BoxDecoration(
        border: Border(
          right: showDivider
              ? const BorderSide(color: Color(0xFFE3E7EE), width: 1)
              : BorderSide.none,
          top: showTopDivider
              ? const BorderSide(color: Color(0xFFE3E7EE), width: 1)
              : BorderSide.none,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 16,
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  softWrap: false,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _textSecondary,
                    fontSize: 10,
                    height: 15 / 10,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (allowValueWrap)
            Center(
              child: Text(
                value,
                textAlign: TextAlign.center,
                softWrap: true,
                style: const TextStyle(
                  color: _textPrimary,
                  fontSize: 11,
                  height: 15 / 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          else
            SizedBox(
              height: 22,
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    value,
                    maxLines: 1,
                    softWrap: false,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: _textPrimary,
                      fontSize: 14,
                      height: 18 / 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAttributeField({required String label, required String value}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: _textSecondary,
            fontSize: 10,
            height: 15 / 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: _textPrimary,
            fontSize: 14,
            height: 20 / 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildDescriptionNote(String description) {
    return Text(
      description,
      style: const TextStyle(
        color: _textSecondary,
        fontSize: 12,
        height: 19.5 / 12,
        fontStyle: FontStyle.italic,
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required VoidCallback? onTap,
    required bool filled,
    Widget? prefix,
    bool loading = false,
  }) {
    final enabled = onTap != null;
    final content = loading
        ? SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: filled ? Colors.white : _brandBlue,
            ),
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (prefix != null) ...[prefix, const SizedBox(width: 6)],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: filled ? Colors.white : _brandBlue,
                    fontSize: 14,
                    height: 20 / 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          );

    final decoration = BoxDecoration(
      borderRadius: BorderRadius.circular(8),
      border: filled
          ? null
          : Border.all(color: const Color(0x3300288E), width: 1),
      gradient: filled
          ? const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_brandBlueLight, _brandBlue],
            )
          : null,
      color: filled ? null : Colors.white,
      boxShadow: filled
          ? const [
              BoxShadow(
                color: Color(0x4D3B82F6),
                blurRadius: 16,
                offset: Offset(0, 6),
              ),
            ]
          : null,
    );

    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: decoration,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            splashColor: filled
                ? Colors.white.withValues(alpha: 0.12)
                : _brandBlue.withValues(alpha: 0.08),
            highlightColor: Colors.transparent,
            child: SizedBox(
              height: 48,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: content,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStickerInfoCard({required List<_StickerDetailData> stickers}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      decoration: BoxDecoration(
        color: _surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x14C4C5D5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _stickerSectionTitle(),
            style: const TextStyle(
              color: _textSecondary,
              fontSize: 11,
              height: 16.5 / 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 72,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: stickers.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (context, index) => _buildStickerDetailRow(
                sticker: stickers[index],
                index: index,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStickerDetailRow({
    required _StickerDetailData sticker,
    required int index,
  }) {
    final title = sticker.name?.trim();

    return Container(
      width: 58,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: _pageBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0x0DC4C5D5)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          SizedBox(
            width: 32,
            height: 32,
            child: CachedNetworkImage(
              imageUrl: sticker.imageUrl,
              fit: BoxFit.contain,
              fadeInDuration: const Duration(milliseconds: 120),
              placeholder: (context, _) => const SizedBox.expand(),
              errorWidget: (context, _, __) => const Icon(
                Icons.image_not_supported_outlined,
                size: 18,
                color: _textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            (title != null && title.isNotEmpty)
                ? title
                : _stickerFallbackName(index),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _textPrimary,
              fontSize: 8,
              height: 10 / 8,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopHeroImage({
    required String imageUrl,
    required TagInfo? rarity,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final imageSideLength = constraints.maxWidth * 0.5;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 20),
          alignment: Alignment.center,
          child: Container(
            width: imageSideLength,
            height: imageSideLength,
            color: Colors.black,
            alignment: Alignment.center,
            child: imageUrl.isEmpty
                ? const Icon(
                    Icons.image_not_supported_outlined,
                    size: 36,
                    color: Colors.white54,
                  )
                : CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.contain,
                    placeholder: (context, _) => const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    errorWidget: (context, _, __) => const Icon(
                      Icons.image_not_supported_outlined,
                      size: 36,
                      color: Colors.white54,
                    ),
                  ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currency = Get.find<CurrencyController>();
    final appId = _item.appId ?? _schema?.appId ?? 730;
    final asset = _resolveAsset();
    final imageUrl =
        _schema?.imageUrl ??
        _extractText(asset, ['image_url', 'imageUrl']) ??
        _item.raw['image_url']?.toString() ??
        '';
    final tags = _schema?.tags;
    final rarity = TagInfo.fromMarketTag(tags?.rarity);
    final quality = TagInfo.fromMarketTag(tags?.quality);
    final exterior = TagInfo.fromMarketTag(tags?.exterior);
    final type = TagInfo.fromMarketTag(tags?.type);
    final hero = TagInfo.fromMarketTag(tags?.hero);
    final slot = TagInfo.fromMarketTag(tags?.slot);
    final itemSet = TagInfo.fromMarketTag(tags?.itemSet);

    final paintSeed =
        _extractText(asset, ['paint_seed', 'paintSeed']) ??
        _extractText(_item.raw, ['paint_seed', 'paintSeed']);
    final paintIndex =
        _extractText(asset, ['paint_index', 'paintIndex']) ??
        _extractText(_item.raw, ['paint_index', 'paintIndex']);
    final paintWearValue = _extractDouble(asset, ['paint_wear', 'paintWear']);
    final paintWearText =
        _extractText(asset, ['paint_wear', 'paintWear']) ??
        _extractText(_item.raw, ['paint_wear', 'paintWear']) ??
        paintWearValue?.toString();

    final stickers = _parseStickers(asset);
    final stickerDetails = _resolveStickerDetailsFromItem(asset);
    final displayStickerDetails = stickerDetails.isNotEmpty
        ? stickerDetails
        : stickers
              .map((sticker) => _StickerDetailData(imageUrl: sticker.imageUrl))
              .toList(growable: false);
    final gems = parseGemList(
      asset?['gemList'] ??
          asset?['gems'] ??
          _item.raw['gemList'] ??
          _item.raw['gems'],
    );
    final keychains = _parseKeychains(
      asset?['keychains'] ?? _item.raw['keychains'],
    );
    final isOwnOnSale = _isOwnOnSaleItem();
    final displayName =
        _schema?.marketName ??
        _item.marketHashName ??
        _item.raw['market_name']?.toString() ??
        '-';
    final currentPrice =
        _item.price ??
        _extractDouble(_item.raw, const ['price', 'market_price']) ??
        _extractDouble(_schema?.raw, const ['price', 'market_price']);
    final lastSoldPrice =
        _extractDouble(_schema?.raw, const [
          'reference_price',
          'market_price',
          'sell_min',
          'sellMin',
          'buy_max',
          'buyMax',
        ]) ??
        _extractDouble(_item.raw, const ['market_price']);
    final rarityLabel = rarity?.label?.trim();
    final typeValue = type?.label?.trim() ?? _item.typeName?.trim();
    final weaponTypeValue = tags?.weapon?.localizedName?.trim() ?? typeValue;
    final qualityValue = quality?.label?.trim();
    final exteriorValue = exterior?.label?.trim();
    final collectionValue = itemSet?.label?.trim();
    final heroValue = hero?.label?.trim();
    final slotValue = slot?.label?.trim();
    final description =
        _resolveDescription(asset) ??
        _buildLegacyDescriptionFallback(
          type: type,
          rarity: rarity,
          quality: quality,
          exterior: exterior,
          itemSet: itemSet,
        );

    final overviewStats = _buildNameSummaryFields(
      paintSeedValue: paintSeed,
      paintIndexValue: paintIndex,
    );

    final attributeFields = _buildAttributeDescriptionFields(
      asset: asset,
      appId: appId,
      typeValue: typeValue ?? weaponTypeValue,
      rarityValue: rarityLabel,
      qualityValue: qualityValue,
      exteriorValue: exteriorValue,
      collectionValue: collectionValue,
      heroValue: heroValue,
      slotValue: slotValue,
    );
    final hasSellerSection =
        _loadingShopInfo ||
        (_shopInfo?.isNotEmpty ?? false) ||
        ((_user?.nickname?.trim().isNotEmpty ?? false));

    return BackToTopScope(
      enabled: false,
      child: Scaffold(
        backgroundColor: _pageBackground,
        appBar: SettingsStyleAppBar(title: Text(_pageTitle)),
        body: ListView(
          padding: EdgeInsets.only(bottom: isOwnOnSale ? 24 : 20),
          children: [
            _buildTopHeroImage(imageUrl: imageUrl, rarity: rarity),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final badgeLabel = _isEnglishLocale
                          ? _currentPriceLabel.toUpperCase()
                          : _currentPriceLabel;
                      final referenceLabel = _referencePriceLabel;

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (currentPrice != null)
                                  Wrap(
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    spacing: 8,
                                    runSpacing: 6,
                                    children: [
                                      Text(
                                        currency.format(currentPrice),
                                        style: const TextStyle(
                                          color: _priceOrange,
                                          fontSize: 34,
                                          height: 38 / 34,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _dangerRedSoft,
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Text(
                                          badgeLabel,
                                          maxLines: 1,
                                          softWrap: false,
                                          style: const TextStyle(
                                            color: _dangerRed,
                                            fontSize: 10,
                                            height: 14 / 10,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.35,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                          if (lastSoldPrice != null) ...[
                            const SizedBox(width: 16),
                            ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: constraints.maxWidth * 0.34,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    referenceLabel,
                                    maxLines: 1,
                                    softWrap: false,
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(
                                      color: _textSecondary,
                                      fontSize: 11,
                                      height: 16 / 11,
                                      fontWeight: FontWeight.w500,
                                      letterSpacing: 1.05,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      currency.format(lastSoldPrice),
                                      maxLines: 1,
                                      softWrap: false,
                                      style: const TextStyle(
                                        color: _textPrimary,
                                        fontSize: 16,
                                        height: 24 / 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          displayName,
                          style: const TextStyle(
                            color: _textPrimary,
                            fontSize: 24,
                            height: 30 / 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (rarityLabel != null && rarityLabel.isNotEmpty) ...[
                        const SizedBox(width: 16),
                        _buildRarityBadge(rarityLabel, rarity?.color),
                      ],
                    ],
                  ),
                  if (overviewStats.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        decoration: BoxDecoration(
                          color: _surfaceCard,
                          border: Border.all(color: const Color(0xFFF0F2F5)),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x120F172A),
                              blurRadius: 14,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            const maxColumns = 3;
                            final columns = overviewStats.length < maxColumns
                                ? overviewStats.length
                                : maxColumns;
                            const gap = 0.0;
                            final itemWidth =
                                (constraints.maxWidth - gap * (columns - 1)) /
                                columns;
                            return Wrap(
                              spacing: gap,
                              runSpacing: gap,
                              children: List.generate(overviewStats.length, (
                                index,
                              ) {
                                final stat = overviewStats[index];
                                final rowIndex = index ~/ columns;
                                final columnIndex = index % columns;
                                return SizedBox(
                                  width: itemWidth,
                                  child: _buildOverviewStatTile(
                                    label: stat.key,
                                    value: stat.value,
                                    showDivider:
                                        columnIndex < columns - 1 &&
                                        index < overviewStats.length - 1,
                                    showTopDivider: rowIndex > 0,
                                    allowValueWrap:
                                        stat.value.length > 12 ||
                                        stat.key == _collectionLabel,
                                  ),
                                );
                              }),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: _surfaceCard,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0x14C4C5D5)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _itemAttributesTitle,
                          style: const TextStyle(
                            color: _textPrimary,
                            fontSize: 18,
                            height: 28 / 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (paintWearValue != null &&
                            paintWearText != null) ...[
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              Text(
                                _floatValueLabel.toUpperCase(),
                                style: const TextStyle(
                                  color: _textSecondary,
                                  fontSize: 11,
                                  height: 16.5 / 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.1,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                paintWearText,
                                style: const TextStyle(
                                  color: _textPrimary,
                                  fontSize: 11,
                                  height: 16.5 / 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          WearProgressBar(
                            paintWear: paintWearValue,
                            height: 8,
                            style: WearProgressBarStyle.figmaCompact,
                          ),
                          const SizedBox(height: 6),
                          const Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '0.00 (FN)',
                                  style: TextStyle(
                                    color: _textSecondary,
                                    fontSize: 9,
                                    height: 13.5 / 9,
                                  ),
                                ),
                              ),
                              Text(
                                '0.07',
                                style: TextStyle(
                                  color: _textSecondary,
                                  fontSize: 9,
                                  height: 13.5 / 9,
                                ),
                              ),
                              Spacer(),
                              Text(
                                '1.00 (BS)',
                                style: TextStyle(
                                  color: _textSecondary,
                                  fontSize: 9,
                                  height: 13.5 / 9,
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (attributeFields.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          Container(
                            decoration: const BoxDecoration(
                              border: Border(
                                top: BorderSide(color: Color(0x14C4C5D5)),
                              ),
                            ),
                            padding: const EdgeInsets.only(top: 20),
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                const gap = 16.0;
                                final itemWidth =
                                    (constraints.maxWidth - gap) / 2;
                                return Wrap(
                                  spacing: gap,
                                  runSpacing: 16,
                                  children: attributeFields
                                      .map((field) {
                                        return SizedBox(
                                          width: itemWidth,
                                          child: _buildAttributeField(
                                            label: field.key,
                                            value: field.value,
                                          ),
                                        );
                                      })
                                      .toList(growable: false),
                                );
                              },
                            ),
                          ),
                        ],
                        if (description != null && description.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          Container(
                            decoration: const BoxDecoration(
                              border: Border(
                                top: BorderSide(color: Color(0x0DC4C5D5)),
                              ),
                            ),
                            padding: const EdgeInsets.only(top: 18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [_buildDescriptionNote(description)],
                            ),
                          ),
                        ],
                        if (gems.isNotEmpty &&
                            (appId == 570 || appId == 440)) ...[
                          const SizedBox(height: 20),
                          Container(
                            decoration: const BoxDecoration(
                              border: Border(
                                top: BorderSide(color: Color(0x0DC4C5D5)),
                              ),
                            ),
                            padding: const EdgeInsets.only(top: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'app.market.filter.dota2.gemstones_contains'
                                      .tr,
                                  style: const TextStyle(
                                    color: _textSecondary,
                                    fontSize: 11,
                                    height: 16.5 / 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.1,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                GemRow(gems: gems, size: 24),
                              ],
                            ),
                          ),
                        ],
                        if (keychains.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          Container(
                            decoration: const BoxDecoration(
                              border: Border(
                                top: BorderSide(color: Color(0x0DC4C5D5)),
                              ),
                            ),
                            padding: const EdgeInsets.only(top: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _isEnglishLocale ? 'Keychains' : '挂件',
                                  style: const TextStyle(
                                    color: _textSecondary,
                                    fontSize: 11,
                                    height: 16.5 / 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.1,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                StickerRow(stickers: keychains, size: 24),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (displayStickerDetails.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildStickerInfoCard(stickers: displayStickerDetails),
                  ],
                  if (hasSellerSection) ...[
                    const SizedBox(height: 16),
                    _buildShopInfoCard(),
                  ],
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: isOwnOnSale
            ? null
            : Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                decoration: const BoxDecoration(
                  color: _surfaceCard,
                  border: Border(top: BorderSide(color: _lineColor)),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x0D000000),
                      blurRadius: 20,
                      offset: Offset(0, -4),
                    ),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildActionButton(
                          label: _wishlistLabel,
                          onTap: _item.id != null && !_favoriteSubmitting
                              ? _toggleFavorite
                              : null,
                          filled: false,
                          loading: _favoriteSubmitting,
                          prefix: Icon(
                            _favorited
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            size: 18,
                            color: _brandBlue,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildActionButton(
                          label: _buyNowLabel,
                          onTap:
                              _item.id != null &&
                                  _item.price != null &&
                                  !_isPurchasing
                              ? _purchase
                              : null,
                          filled: true,
                          loading: _isPurchasing,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

class _StickerDetailData {
  const _StickerDetailData({required this.imageUrl, this.name, this.price});

  final String imageUrl;
  final String? name;
  final double? price;
}
