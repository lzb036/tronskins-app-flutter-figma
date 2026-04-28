import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tronskins_app/common/hooks/currency/CurrencyController.dart';
import 'package:tronskins_app/components/game_item/game_item_image.dart';
import 'package:tronskins_app/components/game_item/game_item_models.dart';
import 'package:tronskins_app/components/game_item/game_item_utils.dart';
import 'package:tronskins_app/components/game_item/game_item_wear_overlay.dart';

class WalletOrderAssetCard extends StatelessWidget {
  const WalletOrderAssetCard({
    super.key,
    required this.title,
    required this.appId,
    this.subtitle,
    this.imageUrl,
    this.priceText,
    this.count,
    this.raw = const {},
    this.schemaRaw = const {},
    this.stickerMap = const {},
    this.rarity,
    this.quality,
    this.exterior,
    this.phase,
    this.percentage,
    this.paintWear,
    this.wearText,
  });

  static const _titleColor = Color(0xFF191C1E);
  static const _mutedColor = Color(0xFF757684);

  final String title;
  final String? subtitle;
  final String? imageUrl;
  final int appId;
  final String? priceText;
  final int? count;
  final Map<String, dynamic> raw;
  final Map<String, dynamic> schemaRaw;
  final Map<String, dynamic> stickerMap;
  final TagInfo? rarity;
  final TagInfo? quality;
  final TagInfo? exterior;
  final String? phase;
  final String? percentage;
  final double? paintWear;
  final String? wearText;

  bool get _isChineseLocale =>
      (Get.locale?.languageCode ?? '').toLowerCase().startsWith('zh');

  String _text({required String zh, required String en}) {
    return _isChineseLocale ? zh : en;
  }

  @override
  Widget build(BuildContext context) {
    final resolvedWear = normalizeGameItemWearValue(
      paintWear ?? _findNumericValue(raw, const ['paint_wear', 'paintWear']),
    );
    final resolvedWearText = formatGameItemWearText(
      wearText ??
          _findTextValue(raw, const ['paint_wear_text', 'paintWearText']) ??
          _findTextValue(raw, const ['paint_wear', 'paintWear']) ??
          _findTextValue(schemaRaw, const ['paint_wear', 'paintWear']),
      resolvedWear,
    );
    final stickerDetails = _resolveStickerDetails();
    final exteriorAccentColor = parseHexColor(exterior?.color);
    final displayCount = count != null && count! > 1 ? count : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildItemImage(
                        imageUrl: imageUrl,
                        rarity: rarity,
                        quality: quality,
                        exterior: exterior,
                        count: displayCount,
                        wearText: resolvedWearText,
                        paintWear: resolvedWear,
                        wearAccentColor: exteriorAccentColor,
                        wearConditionLabel: exterior?.label?.trim(),
                      ),
                      const SizedBox(width: 16),
                      _buildItemInfo(
                        title: title,
                        subtitle: subtitle,
                        priceText: priceText,
                        count: displayCount,
                        stickers: stickerDetails,
                      ),
                    ],
                  ),
                ),
                if (stickerDetails.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _buildStickerDetailCards(stickerDetails),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildItemImage({
    required String? imageUrl,
    required TagInfo? rarity,
    required TagInfo? quality,
    required TagInfo? exterior,
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

  Widget _buildItemInfo({
    required String title,
    required String? subtitle,
    required String? priceText,
    required int? count,
    required List<_WalletStickerDetailData> stickers,
  }) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _titleColor,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              height: 1.25,
            ),
          ),
          if (subtitle != null && subtitle.isNotEmpty && subtitle != title) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _mutedColor,
                fontSize: 11,
                fontWeight: FontWeight.w500,
                height: 15 / 11,
              ),
            ),
          ],
          if (priceText != null && priceText.isNotEmpty) ...[
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
          if (stickers.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildStickerIconRow(stickers),
          ],
          if (count != null) ...[
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

  Widget _buildStickerIconRow(List<_WalletStickerDetailData> stickers) {
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
    required _WalletStickerDetailData sticker,
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

  Widget _buildStickerDetailCards(List<_WalletStickerDetailData> stickers) {
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
    required _WalletStickerDetailData sticker,
    required int index,
  }) {
    final currency = Get.isRegistered<CurrencyController>()
        ? Get.find<CurrencyController>()
        : null;
    final name = sticker.name?.trim().isNotEmpty == true
        ? sticker.name!
        : _stickerFallbackName(index);
    final price = sticker.price;
    final priceText = price == null
        ? '-'
        : (currency?.formatUsd(price) ?? '\$ ${price.toStringAsFixed(2)}');
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

  List<_WalletStickerDetailData> _resolveStickerDetails() {
    for (final candidate in _stickerCandidates()) {
      final entries = _normalizeStickerEntries(candidate);
      if (entries.isEmpty) {
        continue;
      }
      final details = entries
          .map(_resolveStickerDetail)
          .whereType<_WalletStickerDetailData>()
          .toList(growable: false);
      if (details.isNotEmpty) {
        return details;
      }
    }
    return const [];
  }

  List<dynamic> _stickerCandidates() {
    final rawAsset = _pickAssetRaw(raw, appId);
    final schemaAsset = _pickAssetRaw(schemaRaw, appId);
    final rawCsgoAsset = _asMap(raw['csgoAsset']);
    final schemaCsgoAsset = _asMap(schemaRaw['csgoAsset']);
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
      schemaRaw['stickers'],
      schemaRaw['stickerList'],
      schemaRaw['sticker_list'],
      schemaRaw['sticker'],
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

  _WalletStickerDetailData? _resolveStickerDetail(dynamic entry) {
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

    imageUrl ??= _findTextValue(stickerMeta, const [
      'image_url',
      'imageUrl',
      'image',
    ]);
    imageUrl ??= _resolveStickerImage(entry);
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

    return _WalletStickerDetailData(
      imageUrl: _normalizeSteamImageUrl(imageUrl),
      name: name,
      slotLabel: slotLabel,
      wearText: wearText,
      price: price,
    );
  }

  String? _resolveStickerImage(dynamic entry) {
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
    return _asMap(value);
  }

  Map<String, dynamic>? _pickAssetRaw(Map<String, dynamic> json, int? appId) {
    if (appId == 730 && json['csgoAsset'] is Map) {
      return _asMap(json['csgoAsset']);
    }
    if (appId == 440 && json['tf2Asset'] is Map) {
      return _asMap(json['tf2Asset']);
    }
    if (appId == 570 && json['dota2Asset'] is Map) {
      return _asMap(json['dota2Asset']);
    }
    if (json['asset'] is Map) {
      return _asMap(json['asset']);
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

  String? _findTextValue(dynamic source, List<String> keys) {
    final map = _asMap(source);
    if (map == null) {
      return null;
    }
    for (final key in keys) {
      final value = map[key];
      final text = value?.toString().trim();
      if (text != null && text.isNotEmpty && text != 'null') {
        return text;
      }
    }
    return null;
  }

  double? _findNumericValue(dynamic source, List<String> keys) {
    final map = _asMap(source);
    if (map == null) {
      return null;
    }
    for (final key in keys) {
      final value = map[key];
      if (value is num) {
        return value.toDouble();
      }
      if (value is String) {
        final parsed = double.tryParse(value.trim());
        if (parsed != null) {
          return parsed;
        }
      }
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
}

class _WalletStickerDetailData {
  const _WalletStickerDetailData({
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
