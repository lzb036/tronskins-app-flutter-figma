/// Resolves a shop online status from API data.
bool resolveShopOnlineStatus(dynamic source, {bool fallback = false}) {
  return extractShopOnlineStatus(source) ?? fallback;
}

/// Extracts a shop online flag when the API payload exposes one.
bool? extractShopOnlineStatus(dynamic source) {
  final raw = _asStringKeyedMap(source);
  if (raw == null || raw.isEmpty) {
    return null;
  }

  final directShopValue = _extractOnlineValue(raw, _shopOnlineKeys);
  if (directShopValue != null) {
    return directShopValue;
  }

  for (final key in _nestedShopKeys) {
    final value = extractShopOnlineStatus(raw[key]);
    if (value != null) {
      return value;
    }
  }

  return _extractOnlineValue(raw, _genericOnlineKeys);
}

const _shopOnlineKeys = <String>[
  'isOnline',
  'is_online',
  'shopOnline',
  'shop_online',
  'shopStatus',
  'shop_status',
  'businessStatus',
  'business_status',
];

const _genericOnlineKeys = <String>['online'];

const _nestedShopKeys = <String>['shop', 'shopInfo', 'store', 'userShop'];

bool? _extractOnlineValue(Map<String, dynamic> raw, List<String> keys) {
  for (final key in keys) {
    if (!raw.containsKey(key)) {
      continue;
    }
    final value = _parseOnlineValue(raw[key]);
    if (value != null) {
      return value;
    }
  }
  return null;
}

Map<String, dynamic>? _asStringKeyedMap(dynamic source) {
  if (source is Map<String, dynamic>) {
    return source;
  }
  if (source is Map) {
    return source.map((key, value) => MapEntry(key.toString(), value));
  }
  return null;
}

bool? _parseOnlineValue(dynamic value) {
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value != 0;
  }

  final text = value?.toString().trim().toLowerCase();
  if (text == null || text.isEmpty) {
    return null;
  }
  if (text == 'true' ||
      text == '1' ||
      text == 'online' ||
      text == 'open' ||
      text == 'on') {
    return true;
  }
  if (text == 'false' ||
      text == '0' ||
      text == 'offline' ||
      text == 'closed' ||
      text == 'close' ||
      text == 'off') {
    return false;
  }
  return null;
}
