import 'package:tronskins_app/api/model/shop/shop_models.dart';

const double _numericEpsilon = 0.000000001;

List<InventoryItem> filterSupplyInventoryItems(
  BuyRequestItem request,
  Iterable<InventoryItem> items,
) {
  return items
      .where((item) => matchesBuyRequestSupplyConstraints(request, item))
      .toList(growable: false);
}

bool matchesBuyRequestSupplyConstraints(
  BuyRequestItem request,
  InventoryItem item,
) {
  final asset = _resolveAsset(item);
  if (!_matchesIntConstraint(
    expected:
        _firstInt([request.raw], const ['app_id', 'appId']) ?? request.appId,
    actual:
        item.appId ?? _firstInt([item.raw, asset], const ['app_id', 'appId']),
  )) {
    return false;
  }

  if (!_matchesIntConstraint(
    expected:
        _firstInt([request.raw], const ['schema_id', 'schemaId']) ??
        request.schemaId,
    actual:
        item.schemaId ??
        _firstInt([item.raw, asset], const ['schema_id', 'schemaId']),
  )) {
    return false;
  }

  if (!_matchesWearRange(request, item, asset)) {
    return false;
  }

  if (!_matchesTextRequirement(
    expected: _requirementValues(request.raw, const [
      'paint_index',
      'paintIndex',
      'paintIndexId',
      'paint_index_id',
      'paintKit',
      'paint_kit',
    ]),
    actual: _itemValues(item, asset, const [
      'paint_index',
      'paintIndex',
      'paintIndexId',
      'paint_index_id',
      'paintKit',
      'paint_kit',
    ]),
  )) {
    return false;
  }

  if (!_matchesTextRequirement(
    expected: _requirementValues(request.raw, const [
      'paint_seed',
      'paintSeed',
      'patternSeed',
      'pattern_seed',
      'paintSeedList',
      'paint_seed_list',
    ]),
    actual: _itemValues(item, asset, const [
      'paint_seed',
      'paintSeed',
      'pattern',
      'patternId',
      'pattern_id',
      'patternSeed',
      'pattern_seed',
    ]),
  )) {
    return false;
  }

  if (!_matchesPercentageRange(request, item, asset)) {
    return false;
  }

  return _matchesTextRequirement(
    expected: _requirementValues(request.raw, const [
      'accepted_patterns',
      'acceptedPatterns',
      'phaseList',
      'phase_list',
      'phases',
      'patterns',
      'pattern',
      'phase',
    ]),
    actual: {
      ..._itemValues(item, asset, const [
        'phase',
        'paint_phase',
        'paintPhase',
        'pattern',
        'patternId',
        'pattern_id',
        'paint_seed',
        'paintSeed',
        'paint_index',
        'paintIndex',
      ]),
      if (_normalizeText(item.phase) case final phase?) phase,
      if (_normalizeText(item.paintSeed) case final seed?) seed,
    },
  );
}

bool _matchesWearRange(
  BuyRequestItem request,
  InventoryItem item,
  Map<String, dynamic>? asset,
) {
  final min =
      _firstDouble(request.raw, const ['paint_wear_min', 'paintWearMin']) ??
      request.paintWearMin;
  final max =
      _firstDouble(request.raw, const ['paint_wear_max', 'paintWearMax']) ??
      request.paintWearMax;
  if (min == null && max == null) {
    return true;
  }

  final wear =
      item.paintWear ??
      _firstDoubleFromSources(
        [item.raw, asset],
        const ['paint_wear', 'paintWear'],
      );
  if (wear == null) {
    return false;
  }
  if (min != null && wear < min - _numericEpsilon) {
    return false;
  }
  if (max != null && wear > max + _numericEpsilon) {
    return false;
  }
  return true;
}

bool _matchesPercentageRange(
  BuyRequestItem request,
  InventoryItem item,
  Map<String, dynamic>? asset,
) {
  final min =
      _firstDouble(request.raw, const [
        'percentage_min',
        'percentageMin',
        'paintGradientMin',
        'paint_gradient_min',
      ]) ??
      request.percentageMin;
  final max =
      _firstDouble(request.raw, const [
        'percentage_max',
        'percentageMax',
        'paintGradientMax',
        'paint_gradient_max',
      ]) ??
      request.percentageMax;
  if (min == null && max == null) {
    return true;
  }

  final rawPercentage = _firstDoubleFromSources(
    [item.raw, asset],
    const [
      'percentage',
      'paintGradient',
      'paint_gradient',
      'fadePercentage',
      'fade_percentage',
    ],
  );
  if (rawPercentage == null) {
    return false;
  }

  final percentage = _normalizePercentageScale(rawPercentage, min, max);
  if (min != null && percentage < min - _numericEpsilon) {
    return false;
  }
  if (max != null && percentage > max + _numericEpsilon) {
    return false;
  }
  return true;
}

double _normalizePercentageScale(double value, double? min, double? max) {
  final usesPercentScale = (min != null && min > 1) || (max != null && max > 1);
  if (usesPercentScale && value <= 1) {
    return value * 100;
  }
  if (!usesPercentScale && value > 1 && value <= 100) {
    return value / 100;
  }
  return value;
}

bool _matchesIntConstraint({required int? expected, required int? actual}) {
  if (expected == null) {
    return true;
  }
  return actual != null && expected == actual;
}

bool _matchesTextRequirement({
  required Set<String> expected,
  required Set<String> actual,
}) {
  if (expected.isEmpty) {
    return true;
  }
  if (actual.isEmpty) {
    return false;
  }
  return expected.any(actual.contains);
}

Set<String> _itemValues(
  InventoryItem item,
  Map<String, dynamic>? asset,
  List<String> keys,
) {
  final values = <String>{};
  for (final source in [item.raw, asset]) {
    values.addAll(_requirementValues(source, keys));
  }
  return values;
}

Set<String> _requirementValues(dynamic raw, List<String> keys) {
  final values = <String>{};
  if (raw is! Map) {
    return values;
  }
  for (final key in keys) {
    values.addAll(_flattenValues(raw[key]));
  }
  return values;
}

Set<String> _flattenValues(dynamic value) {
  if (value == null) {
    return const <String>{};
  }
  if (value is Iterable) {
    return value.expand<String>((entry) => _flattenValues(entry)).toSet();
  }
  if (value is Map) {
    final direct = <String>{};
    for (final key in const [
      'id',
      'value',
      'key',
      'name',
      'label',
      'text',
      'phase',
    ]) {
      if (value.containsKey(key)) {
        final normalized = _normalizeText(value[key]);
        if (normalized != null) {
          direct.add(normalized);
        }
      }
    }
    if (direct.isNotEmpty) {
      return direct;
    }
    return value.values
        .expand<String>((entry) => _flattenValues(entry))
        .toSet();
  }
  final normalized = _normalizeText(value);
  return normalized == null ? const <String>{} : <String>{normalized};
}

String? _normalizeText(dynamic value) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty) {
    return null;
  }
  final lower = text.toLowerCase();
  if (lower == 'null' ||
      lower == 'undefined' ||
      lower == 'all' ||
      lower == 'none' ||
      lower == 'no requirement' ||
      lower == 'unlimited' ||
      text == '无要求' ||
      text == '不限') {
    return null;
  }
  return lower;
}

int? _firstInt(Iterable<dynamic> sources, List<String> keys) {
  for (final source in sources) {
    if (source is! Map) {
      continue;
    }
    for (final key in keys) {
      final parsed = _asInt(source[key]);
      if (parsed != null) {
        return parsed;
      }
    }
  }
  return null;
}

int? _asInt(dynamic value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString().trim() ?? '');
}

double? _firstDouble(Map<String, dynamic> source, List<String> keys) {
  return _firstDoubleFromSources([source], keys);
}

double? _firstDoubleFromSources(Iterable<dynamic> sources, List<String> keys) {
  for (final source in sources) {
    if (source is! Map) {
      continue;
    }
    for (final key in keys) {
      final parsed = _asDouble(source[key]);
      if (parsed != null) {
        return parsed;
      }
    }
  }
  return null;
}

double? _asDouble(dynamic value) {
  if (value is double) {
    return value;
  }
  if (value is num) {
    return value.toDouble();
  }
  final text = value?.toString().replaceAll('%', '').trim() ?? '';
  if (text.isEmpty) {
    return null;
  }
  return double.tryParse(text);
}

Map<String, dynamic>? _resolveAsset(InventoryItem item) {
  final raw = item.raw;
  if (item.appId == 730) {
    return _asMap(raw['csgoAsset']);
  }
  if (item.appId == 440) {
    return _asMap(raw['tf2Asset']);
  }
  if (item.appId == 570) {
    return _asMap(raw['dota2Asset']);
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
