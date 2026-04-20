import 'package:flutter/material.dart';
import 'package:tronskins_app/api/model/shop/shop_models.dart';
import 'package:tronskins_app/components/game_item/inventory_showcase_card.dart';

class ShopSaleItemCard extends StatelessWidget {
  const ShopSaleItemCard({
    super.key,
    required this.item,
    this.schema,
    this.schemaMap,
    this.stickerMap,
    this.selected = false,
    this.showSelectionControl = false,
    this.onTap,
  });

  final ShopItemAsset item;
  final ShopSchemaInfo? schema;
  final Map<dynamic, dynamic>? schemaMap;
  final Map<dynamic, dynamic>? stickerMap;
  final bool selected;
  final bool showSelectionControl;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final asset = item.asset ?? item.raw['asset'];
    final adaptedItem = InventoryItem(
      raw: item.raw,
      id: item.id,
      appId: item.appId,
      schemaId: item.schemaId,
      marketName: item.marketName,
      marketHashName: item.marketHashName,
      imageUrl: item.imageUrl,
      price: item.price,
      tradable: true,
      coolingDown:
          _extractBool(asset, const ['cd', 'cooling', 'coolingDown']) ||
          _extractBool(item.raw, const ['cd', 'cooling', 'coolingDown']),
      cooldown:
          _extractText(asset, const ['cd', 'cooldown']) ??
          _extractText(item.raw, const ['cd', 'cooldown']),
      paintWear:
          _extractDouble(asset, const ['paint_wear', 'paintWear']) ??
          _extractDouble(item.raw, const ['paint_wear', 'paintWear']),
      paintSeed:
          _extractText(asset, const ['paint_seed', 'paintSeed']) ??
          _extractText(item.raw, const ['paint_seed', 'paintSeed']),
      phase:
          _extractText(asset, const ['phase']) ??
          _extractText(item.raw, const ['phase']),
      status: item.status,
      count: item.count,
    );

    return InventoryShowcaseCard(
      item: adaptedItem,
      schema: schema,
      schemaMap: schemaMap,
      stickerMap: stickerMap,
      useSchemaBuffMinPrice: false,
      selected: selected,
      showSelectionControl: showSelectionControl,
      showOnSaleBadge: false,
      onTap: onTap,
    );
  }
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

bool _extractBool(dynamic raw, List<String> keys) {
  if (raw is Map) {
    for (final key in keys) {
      final value = raw[key];
      if (value == null) {
        continue;
      }
      if (value is bool) {
        return value;
      }
      if (value is num) {
        return value != 0;
      }
      final text = value.toString().trim().toLowerCase();
      if (text == 'true' || text == '1') {
        return true;
      }
      if (text == 'false' || text == '0') {
        return false;
      }
    }
  }
  return false;
}
