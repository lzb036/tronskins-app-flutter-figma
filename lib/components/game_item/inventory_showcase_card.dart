import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tronskins_app/api/model/shop/shop_models.dart';
import 'package:tronskins_app/common/hooks/currency/CurrencyController.dart';
import 'package:tronskins_app/components/game_item/gem_row.dart';
import 'package:tronskins_app/components/game_item/game_item_models.dart';
import 'package:tronskins_app/components/game_item/game_item_utils.dart';
import 'package:tronskins_app/components/game_item/game_item_wear_overlay.dart';
import 'package:tronskins_app/components/game_item/sticker_row.dart';

const Color _inventoryShowcaseTextPrimary = Color(0xFF191C1E);
const Color _inventoryShowcaseBrandBlue = Color(0xFF00288E);
const Color _inventoryShowcasePhasePurple = Color(0xFF7C3AED);

class InventoryShowcaseCard extends StatelessWidget {
  const InventoryShowcaseCard({
    super.key,
    required this.item,
    this.schema,
    this.schemaMap,
    this.stickerMap,
    this.useSchemaBuffMinPrice = true,
    this.selected = false,
    this.showSelectionControl = false,
    this.showOnSaleBadge = true,
    this.disabledLabel,
    this.onImageTap,
    this.onInfoTap,
    this.onTap,
  });

  final InventoryItem item;
  final ShopSchemaInfo? schema;
  final Map<dynamic, dynamic>? schemaMap;
  final Map<dynamic, dynamic>? stickerMap;
  final bool useSchemaBuffMinPrice;
  final bool selected;
  final bool showSelectionControl;
  final bool showOnSaleBadge;
  final String? disabledLabel;
  final VoidCallback? onImageTap;
  final VoidCallback? onInfoTap;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    const outerRadiusValue = 0.0;
    final outerRadius = BorderRadius.circular(outerRadiusValue);
    final innerRadius = BorderRadius.circular(outerRadiusValue);
    final imageTapHandler = onImageTap ?? onTap;
    final infoTapHandler = onInfoTap ?? onTap;
    final appId = item.appId;
    final isDota = appId == 570;
    final isTf2 = appId == 440;
    final imageUrl = _normalizeMarketImageUrl(
      item.imageUrl ?? schema?.imageUrl ?? '',
    );
    final title =
        item.marketName ?? schema?.marketName ?? item.marketHashName ?? '-';
    final tags = schema?.raw['tags'];
    final quality = TagInfo.fromRaw(tags is Map ? tags['quality'] : null);
    final rarity = TagInfo.fromRaw(tags is Map ? tags['rarity'] : null);
    final exterior = TagInfo.fromRaw(tags is Map ? tags['exterior'] : null);
    final asset = _resolveAsset(item);
    final rawWearText = _extractText(asset, const ['paint_wear', 'paintWear']);
    final rawWearValue =
        item.paintWear ??
        _extractDouble(asset, const ['paint_wear', 'paintWear']);
    final wearValue = normalizeGameItemWearValue(rawWearValue);
    final wearDisplay = formatGameItemWearText(rawWearText, wearValue);
    final patternLabel = _normalizePatternLabel(
      item.paintSeed ?? _extractText(asset, const ['paint_seed', 'paintSeed']),
    );
    final phaseLabel = _normalizePhaseLabel(
      item.phase ??
          _extractText(asset, const ['phase']) ??
          _extractText(item.raw, const ['phase']),
    );
    final percentageLabel = _normalizePercentageLabel(
      _extractText(asset, const ['percentage']) ??
          _extractText(item.raw, const ['percentage']),
    );
    final stickers = parseStickerList(
      asset?['stickers'] ?? item.raw['stickers'],
      schemaMap: schemaMap,
      stickerMap: stickerMap,
    ).take(4).toList();
    final gems = parseGemList(
      asset?['gemList'] ??
          asset?['gems'] ??
          item.raw['gemList'] ??
          item.raw['gems'],
    ).take(4).toList();
    final showQualityRibbon = _shouldShowQualityRibbon(
      quality,
      isDota: isDota,
      isTf2: isTf2,
    );
    final hasAccessoryDetails =
        stickers.isNotEmpty || gems.isNotEmpty || wearDisplay != null;
    final conditionLabel = exterior?.label?.trim();
    final exteriorAccentColor =
        parseHexColor(exterior?.color) ??
        (conditionLabel != null && conditionLabel.isNotEmpty
            ? gameItemConditionColor(conditionLabel)
            : null);
    final rarityLabel = rarity?.label?.trim();
    final statusLabel = disabledLabel?.trim();
    final cooldownLabel = _resolveCooldownLabel(item, asset);
    final shouldShowOnSaleBadge =
        showOnSaleBadge && (item.status == 1 || item.status == 2);
    final price = _resolveDisplayPrice(
      schema: schema,
      itemPrice: item.price,
      useSchemaBuffMinPrice: useSchemaBuffMinPrice,
    );

    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: outerRadius,
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.zero,
          child: ClipRRect(
            borderRadius: innerRadius,
            child: ColoredBox(
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: imageTapHandler,
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: const Color(0xFF120C10),
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(outerRadiusValue),
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Positioned.fill(
                              child: DecoratedBox(
                                decoration: itemImageBackgroundDecoration(),
                              ),
                            ),
                            Positioned.fill(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.08),
                                ),
                              ),
                            ),
                            if (imageUrl.isNotEmpty)
                              Padding(
                                padding: isDota
                                    ? EdgeInsets.zero
                                    : const EdgeInsets.fromLTRB(6, 8, 6, 10),
                                child: isDota
                                    ? ClipRect(
                                        child: Transform.scale(
                                          scale: 1.1,
                                          alignment: Alignment.center,
                                          child: CachedNetworkImage(
                                            imageUrl: imageUrl,
                                            fit: BoxFit.contain,
                                            fadeInDuration: const Duration(
                                              milliseconds: 120,
                                            ),
                                            errorWidget: (context, _, __) =>
                                                const Icon(
                                                  Icons
                                                      .image_not_supported_outlined,
                                                  color: Colors.white54,
                                                  size: 28,
                                                ),
                                          ),
                                        ),
                                      )
                                    : CachedNetworkImage(
                                        imageUrl: imageUrl,
                                        fit: BoxFit.contain,
                                        fadeInDuration: const Duration(
                                          milliseconds: 120,
                                        ),
                                        errorWidget: (context, _, __) =>
                                            const Icon(
                                              Icons
                                                  .image_not_supported_outlined,
                                              color: Colors.white54,
                                              size: 28,
                                            ),
                                      ),
                              ),
                            Positioned(
                              left: 5,
                              top: 5,
                              right: showQualityRibbon ? 54 : 5,
                              child: Wrap(
                                spacing: 3,
                                runSpacing: 3,
                                children: [
                                  if (statusLabel != null &&
                                      statusLabel.isNotEmpty)
                                    _buildBadge(
                                      label: statusLabel,
                                      backgroundColor: _statusBadgeColor(),
                                      textColor: Colors.white,
                                    ),
                                  if (isDota &&
                                      rarityLabel != null &&
                                      rarityLabel.isNotEmpty)
                                    _buildBadge(
                                      label: rarityLabel,
                                      backgroundColor:
                                          parseHexColor(rarity?.color) ??
                                          const Color(0xCC111827),
                                      textColor: Colors.white,
                                    ),
                                  if (!isDota &&
                                      conditionLabel != null &&
                                      conditionLabel.isNotEmpty)
                                    _buildBadge(
                                      label: conditionLabel.toUpperCase(),
                                      backgroundColor:
                                          exteriorAccentColor ??
                                          gameItemConditionColor(
                                            conditionLabel,
                                          ),
                                      textColor: Colors.white,
                                    ),
                                  if (patternLabel != null &&
                                      patternLabel.isNotEmpty)
                                    _buildBadge(
                                      label: patternLabel,
                                      backgroundColor: const Color(0xFF0B8793),
                                      textColor: Colors.white,
                                    ),
                                  if (phaseLabel != null &&
                                      phaseLabel.isNotEmpty)
                                    _buildBadge(
                                      label: phaseLabel,
                                      backgroundColor:
                                          _inventoryShowcasePhasePurple,
                                      textColor: Colors.white,
                                    ),
                                  if (percentageLabel != null &&
                                      percentageLabel.isNotEmpty)
                                    _buildBadge(
                                      label: percentageLabel,
                                      backgroundColor: const Color(0xFFF59E0B),
                                      textColor: Colors.white,
                                    ),
                                ],
                              ),
                            ),
                            if (showQualityRibbon && quality != null)
                              Positioned(
                                top: 0,
                                right: 0,
                                child: _buildQualityRibbon(quality),
                              ),
                            if (showSelectionControl)
                              Positioned(
                                top: 8,
                                right: 8,
                                child: selected
                                    ? _buildCheckedSelectionControl()
                                    : _buildUncheckedSelectionControl(),
                              ),
                            if (hasAccessoryDetails)
                              Positioned(
                                left: 0,
                                right: 0,
                                bottom: 0,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (stickers.isNotEmpty || gems.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                          6,
                                          0,
                                          6,
                                          2,
                                        ),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            if (stickers.isNotEmpty) ...[
                                              StickerRow(
                                                stickers: stickers,
                                                size: 18,
                                              ),
                                              if (gems.isNotEmpty)
                                                const SizedBox(height: 2),
                                            ],
                                            if (gems.isNotEmpty)
                                              GemRow(
                                                gems: gems,
                                                size: isDota ? 20 : 16,
                                              ),
                                          ],
                                        ),
                                      ),
                                    if (wearDisplay != null)
                                      GameItemWearOverlay(
                                        label: _isEnglishLocale
                                            ? 'Wear'
                                            : '磨损度',
                                        text: wearDisplay,
                                        value: wearValue,
                                        accentColor: exteriorAccentColor,
                                        conditionLabel: conditionLabel,
                                      ),
                                  ],
                                ),
                              ),
                            if (shouldShowOnSaleBadge)
                              Positioned(
                                right: 6,
                                bottom: 6,
                                child: Image.asset(
                                  'assets/images/game/item/on-sale.png',
                                  width: 18,
                                  height: 18,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: infoTapHandler,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _inventoryShowcaseTextPrimary,
                              fontSize: 10,
                              height: 12 / 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Obx(
                                  () => Text(
                                    CurrencyController.to.format(price),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: _inventoryShowcaseBrandBlue,
                                      fontSize: 14,
                                      height: 18 / 14,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                              if (cooldownLabel != null &&
                                  cooldownLabel.isNotEmpty) ...[
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    cooldownLabel,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(
                                      color: Color(0xFF2563EB),
                                      fontSize: 9,
                                      height: 12 / 9,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool get _isEnglishLocale =>
      Get.locale?.languageCode.toLowerCase().startsWith('en') ?? false;

  Widget _buildBadge({
    required String label,
    required Color backgroundColor,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(color: backgroundColor),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: textColor,
          fontSize: 7,
          height: 9 / 7,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  Widget _buildCheckedSelectionControl() {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: const Color(0xFF2563EB),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: const Icon(Icons.check_rounded, size: 14, color: Colors.white),
    );
  }

  Widget _buildUncheckedSelectionControl() {
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.20),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.50),
              width: 2,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQualityRibbon(TagInfo quality) {
    final label = quality.label?.trim();
    if (label == null || label.isEmpty) {
      return const SizedBox.shrink();
    }
    final color = parseHexColor(quality.color) ?? const Color(0xFFFF9A3C);
    return IgnorePointer(
      child: SizedBox(
        width: 58,
        height: 58,
        child: ClipRect(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                top: 9,
                right: -20,
                child: Transform.rotate(
                  angle: 0.785398,
                  child: Container(
                    width: 82,
                    height: 18,
                    alignment: Alignment.center,
                    color: Colors.black.withValues(alpha: 0.84),
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.fade,
                      softWrap: false,
                      style: TextStyle(
                        color: color,
                        fontSize: 9,
                        height: 1,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _statusBadgeColor() {
    if (item.status == 1) {
      return const Color(0xFFD62D20);
    }
    if (item.status == 2) {
      return const Color(0xFF2563EB);
    }
    if (item.coolingDown == true) {
      return const Color(0xFFF59E0B);
    }
    return const Color(0xFFD62D20);
  }
}

bool _shouldShowQualityRibbon(
  TagInfo? quality, {
  required bool isDota,
  required bool isTf2,
}) {
  if (quality == null) {
    return false;
  }
  final name = quality.name?.trim().toLowerCase();
  final label = quality.label?.trim().toLowerCase();
  if (name == 'normal' || name == 'unusual') {
    return false;
  }
  if (isDota && (name == 'standard' || label == 'standard')) {
    return false;
  }
  if (isTf2 && (name == 'unique' || label == 'unique')) {
    return false;
  }
  return quality.hasLabel;
}

String? _normalizePatternLabel(String? rawText) {
  final text = rawText?.trim();
  if (text == null || text.isEmpty || _isZeroLikeText(text)) {
    return null;
  }
  return text;
}

String? _normalizePhaseLabel(String? rawText) {
  final text = rawText?.trim();
  if (text == null || text.isEmpty || _isZeroLikeText(text)) {
    return null;
  }
  return text;
}

String? _normalizePercentageLabel(String? rawText) {
  final text = rawText?.trim();
  if (text == null || text.isEmpty || _isZeroLikeText(text)) {
    return null;
  }
  return text.contains('%') ? text : '$text%';
}

bool _isZeroLikeText(String text) {
  final normalized = text.trim();
  if (normalized.isEmpty) {
    return true;
  }
  final parsed = double.tryParse(normalized);
  return parsed != null && parsed <= 0;
}

double _parsePriceValue(dynamic value) {
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

double _normalizePrice(double value) {
  if (!value.isFinite || value <= 0) {
    return 0;
  }
  return double.parse(value.toStringAsFixed(2));
}

double _resolveDisplayPrice({
  required ShopSchemaInfo? schema,
  required double? itemPrice,
  required bool useSchemaBuffMinPrice,
}) {
  if (!useSchemaBuffMinPrice) {
    final directPrice = _parsePriceValue(itemPrice);
    if (directPrice > 0) {
      return _normalizePrice(directPrice);
    }
    return 0;
  }

  if (schema != null) {
    final raw = schema.raw;
    final buffMinPrice = _parsePriceValue(
      raw['buff_min_price'] ?? raw['buffMinPrice'],
    );
    if (buffMinPrice > 0) {
      return _normalizePrice(buffMinPrice);
    }
  }

  final directPrice = _parsePriceValue(itemPrice);
  if (directPrice > 0) {
    return _normalizePrice(directPrice);
  }
  return 0;
}

String? _resolveCooldownLabel(InventoryItem item, Map<String, dynamic>? asset) {
  final directCooldown = item.cooldown?.trim();
  if (directCooldown != null && directCooldown.isNotEmpty) {
    return directCooldown;
  }

  final assetCooldown = _extractText(asset, const ['cd', 'cooldown'])?.trim();
  if (assetCooldown != null && assetCooldown.isNotEmpty) {
    return assetCooldown;
  }

  final rawCooldown = _extractText(item.raw, const ['cd', 'cooldown'])?.trim();
  if (rawCooldown != null && rawCooldown.isNotEmpty) {
    return rawCooldown;
  }

  return null;
}

Map<String, dynamic>? _resolveAsset(InventoryItem item) {
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

String _normalizeMarketImageUrl(String raw) {
  if (raw.isEmpty) {
    return raw;
  }
  if (raw.startsWith('http://') || raw.startsWith('https://')) {
    return raw;
  }
  if (raw.startsWith('/')) {
    return 'https://www.tronskins.com$raw';
  }
  return 'https://community.steamstatic.com/economy/image/$raw';
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
