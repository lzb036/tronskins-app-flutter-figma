import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:tronskins_app/api/model/market/market_models.dart';

class TagInfo {
  final String? name;
  final String? label;
  final String? color;

  const TagInfo({this.name, this.label, this.color});

  bool get hasLabel => label != null && label!.isNotEmpty;

  static TagInfo? fromMarketTag(MarketItemTag? tag) {
    if (tag == null) {
      return null;
    }
    return TagInfo(name: tag.name, label: tag.localizedName, color: tag.color);
  }

  static TagInfo? fromRaw(dynamic raw) {
    if (raw is Map<String, dynamic>) {
      return TagInfo(
        name: raw['name']?.toString(),
        label:
            raw['localized_name']?.toString() ??
            raw['localizedName']?.toString(),
        color: raw['color']?.toString(),
      );
    }
    return null;
  }
}

class GameItemSticker {
  final String imageUrl;

  const GameItemSticker(this.imageUrl);
}

class GameItemGem {
  final String imageUrl;
  final Color? borderColor;

  const GameItemGem({required this.imageUrl, this.borderColor});
}

List<GameItemSticker> parseStickerList(
  dynamic raw, {
  Map<dynamic, dynamic>? schemaMap,
  Map<dynamic, dynamic>? stickerMap,
}) {
  if (raw is! List) {
    return const [];
  }
  final stickers = <GameItemSticker>[];
  for (final item in raw) {
    var url = _extractStickerImageUrl(item);
    if (url == null || url.isEmpty) {
      final stickerId = _extractStickerId(item);
      if (stickerId != null) {
        url =
            _resolveStickerImageFromMap(stickerId, stickerMap) ??
            _resolveStickerImageFromMap(stickerId, schemaMap);
      }
    }
    if (url == null || url.isEmpty) {
      continue;
    }
    stickers.add(GameItemSticker(_normalizeStickerUrl(url)));
  }
  return stickers;
}

/// Normalizes sticker-like or keychain-like raw data into a list shape.
List<dynamic> normalizeGameItemAccessoryEntries(dynamic raw) {
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
        raw.containsKey('stickerId') ||
        raw.containsKey('schema_id') ||
        raw.containsKey('schemaId')) {
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
      return value
          .split(',')
          .map((entry) => entry.trim())
          .where((entry) => entry.isNotEmpty)
          .toList(growable: false);
    }
    return <dynamic>[value];
  }
  if (raw == null) {
    return const [];
  }
  return <dynamic>[raw];
}

/// Parses the first non-empty accessory candidate into sticker preview data.
List<GameItemSticker> parseFirstAccessoryStickerList(
  Iterable<dynamic> candidates, {
  Map<dynamic, dynamic>? schemaMap,
  Map<dynamic, dynamic>? stickerMap,
}) {
  for (final candidate in candidates) {
    final parsed = parseStickerList(
      normalizeGameItemAccessoryEntries(candidate),
      schemaMap: schemaMap,
      stickerMap: stickerMap,
    );
    if (parsed.isNotEmpty) {
      return parsed;
    }
  }
  return const [];
}

/// Builds preview accessories with up to five stickers plus one keychain.
List<GameItemSticker> buildAccessoryPreviewStickers({
  List<GameItemSticker> stickers = const [],
  List<GameItemSticker> keychains = const [],
}) {
  if (stickers.isEmpty && keychains.isEmpty) {
    return const [];
  }
  return <GameItemSticker>[...stickers.take(5), ...keychains.take(1)];
}

List<GameItemGem> parseGemList(dynamic raw) {
  if (raw is! List) {
    return const [];
  }
  final gems = <GameItemGem>[];
  for (final item in raw) {
    if (item is Map<String, dynamic>) {
      final url =
          item['imageUrl']?.toString() ??
          item['image_url']?.toString() ??
          item['image']?.toString();
      if (url == null || url.isEmpty) {
        continue;
      }
      final border = _parseColor(
        item['borderColor']?.toString() ?? item['border_color']?.toString(),
      );
      gems.add(GameItemGem(imageUrl: url, borderColor: border));
    } else if (item is String && item.isNotEmpty) {
      gems.add(GameItemGem(imageUrl: item));
    }
  }
  return gems;
}

String? _extractStickerImageUrl(dynamic item) {
  if (item is String) {
    final value = item.trim();
    if (value.isEmpty || _isLikelyStickerId(value)) {
      return null;
    }
    return value;
  }
  if (item is Map) {
    return _extractMapImageUrl(item);
  }
  return _extractObjectImageUrl(item);
}

String? _extractStickerId(dynamic item) {
  if (item is num) {
    return item.toString();
  }
  if (item is String) {
    final value = item.trim();
    if (value.isEmpty || !_isLikelyStickerId(value)) {
      return null;
    }
    return value;
  }
  if (item is Map) {
    final id =
        item['sticker_id'] ??
        item['stickerId'] ??
        item['schema_id'] ??
        item['schemaId'] ??
        item['id'];
    final value = id?.toString().trim();
    if (value == null || value.isEmpty) {
      return null;
    }
    return value;
  }
  return null;
}

String? _resolveStickerImageFromMap(
  String stickerId,
  Map<dynamic, dynamic>? map,
) {
  if (map == null || map.isEmpty) {
    return null;
  }
  dynamic value;
  if (map.containsKey(stickerId)) {
    value = map[stickerId];
  }
  if (value == null) {
    final intKey = int.tryParse(stickerId);
    if (intKey != null && map.containsKey(intKey)) {
      value = map[intKey];
    }
  }
  if (value == null) {
    for (final entry in map.entries) {
      if (entry.key.toString() == stickerId) {
        value = entry.value;
        break;
      }
    }
  }
  if (value == null) {
    return null;
  }
  return _extractStickerImageUrl(value);
}

String? _extractMapImageUrl(Map item) {
  return item['image_url']?.toString() ??
      item['imageUrl']?.toString() ??
      item['image']?.toString();
}

String? _extractObjectImageUrl(dynamic item) {
  if (item is MarketSchemaInfo) {
    return item.imageUrl;
  }
  try {
    final dynamic dynamicValue = item;
    final url =
        dynamicValue.imageUrl ?? dynamicValue.image_url ?? dynamicValue.image;
    return url?.toString();
  } catch (_) {
    return null;
  }
}

bool _isLikelyStickerId(String value) {
  if (value.isEmpty) {
    return false;
  }
  final pattern = RegExp(r'^\d+$');
  return pattern.hasMatch(value);
}

String _normalizeStickerUrl(String url) {
  if (url.startsWith('http://') || url.startsWith('https://')) {
    return url;
  }
  const head = 'https://community.steamstatic.com/economy/image/';
  return '$head$url';
}

Color? _parseColor(String? hex) {
  if (hex == null || hex.isEmpty) {
    return null;
  }
  final normalized = hex.replaceAll('#', '');
  if (normalized.length == 6) {
    return Color(int.parse('FF$normalized', radix: 16));
  }
  return null;
}
