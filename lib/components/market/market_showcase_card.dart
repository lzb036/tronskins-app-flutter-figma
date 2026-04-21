import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tronskins_app/common/hooks/currency/CurrencyController.dart';
import 'package:tronskins_app/components/game_item/gem_row.dart';
import 'package:tronskins_app/components/game_item/game_item_models.dart';
import 'package:tronskins_app/components/game_item/game_item_utils.dart';
import 'package:tronskins_app/components/game_item/sticker_row.dart';

const Color _marketShowcaseSurfaceCard = Colors.white;
const Color _marketShowcaseTextPrimary = Color(0xFF191C1E);
const Color _marketShowcaseTextSecondary = Color(0xFF757684);
const Color _marketShowcaseBrandBlue = Color(0xFF00288E);
const double _marketShowcaseCardRadius = 0;

class MarketShowcaseCard extends StatelessWidget {
  const MarketShowcaseCard({
    super.key,
    required this.appId,
    required this.imageUrl,
    required this.title,
    required this.price,
    this.trailingInfo,
    this.rarity,
    this.quality,
    this.exterior,
    this.patternLabel,
    this.stickers = const <GameItemSticker>[],
    this.gems = const <GameItemGem>[],
    this.wearDisplay,
    this.wearValue,
    this.showAccessoryDetails = true,
    this.onTap,
  });

  final int? appId;
  final String imageUrl;
  final String title;
  final double price;
  final String? trailingInfo;
  final TagInfo? rarity;
  final TagInfo? quality;
  final TagInfo? exterior;
  final String? patternLabel;
  final List<GameItemSticker> stickers;
  final List<GameItemGem> gems;
  final String? wearDisplay;
  final double? wearValue;
  final bool showAccessoryDetails;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDota = appId == 570;
    final isTf2 = appId == 440;
    final normalizedImageUrl = _normalizeMarketImageUrl(imageUrl);
    final conditionLabel = exterior?.label?.trim();
    final rarityLabel = rarity?.label?.trim();
    final showQualityRibbon = _shouldShowQualityRibbon(
      quality,
      isDota: isDota,
      isTf2: isTf2,
    );
    final hasAccessoryDetails =
        showAccessoryDetails &&
        (stickers.isNotEmpty || gems.isNotEmpty || wearDisplay != null);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(_marketShowcaseCardRadius),
        child: Ink(
          decoration: BoxDecoration(
            color: _marketShowcaseSurfaceCard,
            borderRadius: BorderRadius.circular(_marketShowcaseCardRadius),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A0F172A),
                blurRadius: 16,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(_marketShowcaseCardRadius),
                    ),
                    color: const Color(0xFF120C10),
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
                      if (normalizedImageUrl.isNotEmpty)
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
                                      imageUrl: normalizedImageUrl,
                                      fit: BoxFit.contain,
                                      fadeInDuration: const Duration(
                                        milliseconds: 120,
                                      ),
                                      errorWidget: (context, _, __) =>
                                          const Icon(
                                            Icons.image_not_supported_outlined,
                                            color: Colors.white54,
                                            size: 28,
                                          ),
                                    ),
                                  ),
                                )
                              : CachedNetworkImage(
                                  imageUrl: normalizedImageUrl,
                                  fit: BoxFit.contain,
                                  fadeInDuration: const Duration(
                                    milliseconds: 120,
                                  ),
                                  errorWidget: (context, _, __) => const Icon(
                                    Icons.image_not_supported_outlined,
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
                                backgroundColor: _conditionColor(
                                  conditionLabel,
                                ),
                                textColor: Colors.white,
                              ),
                            if (patternLabel != null &&
                                patternLabel!.isNotEmpty)
                              _buildBadge(
                                label: patternLabel!,
                                backgroundColor: const Color(0xCC111827),
                                textColor: Colors.white,
                              ),
                          ],
                        ),
                      ),
                      if (showQualityRibbon && quality != null)
                        Positioned(
                          top: 0,
                          right: 0,
                          child: _buildShopItemQualityRibbon(quality!),
                        ),
                      if (hasAccessoryDetails)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: _buildAccessoryOverlay(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (stickers.isNotEmpty) ...[
                                  StickerRow(stickers: stickers, size: 18),
                                  if (gems.isNotEmpty || wearDisplay != null)
                                    const SizedBox(height: 3),
                                ],
                                if (gems.isNotEmpty) ...[
                                  GemRow(gems: gems, size: isDota ? 20 : 16),
                                  if (wearDisplay != null)
                                    const SizedBox(height: 3),
                                ],
                                if (wearDisplay != null) ...[
                                  Text(
                                    '${_isEnglishLocale ? 'Wear' : '磨损'}: $wearDisplay',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Color(0xFFE2E8F0),
                                      fontSize: 7,
                                      height: 10 / 7,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  if (wearValue != null) ...[
                                    const SizedBox(height: 3),
                                    _buildWearTrack(
                                      wearValue: wearValue!,
                                      conditionLabel: conditionLabel,
                                    ),
                                  ],
                                ],
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                child: Text(
                  title,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _marketShowcaseTextPrimary,
                    fontSize: 10,
                    height: 12 / 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Obx(
                        () => Text(
                          CurrencyController.to.format(price),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _marketShowcaseBrandBlue,
                            fontSize: 14,
                            height: 18 / 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    if (trailingInfo != null && trailingInfo!.trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Text(
                          trailingInfo!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _marketShowcaseTextSecondary,
                            fontSize: 10,
                            height: 12 / 10,
                            fontWeight: FontWeight.w500,
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

  Widget _buildAccessoryOverlay({required Widget child}) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 30),
          alignment: Alignment.bottomLeft,
          padding: const EdgeInsets.fromLTRB(6, 6, 6, 4),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: const [
                Color(0x1F2D1B1B),
                Color(0x73251919),
                Color(0xC41A0F0F),
                Color(0xF0100707),
              ],
              stops: const [0, 0.34, 0.7, 1],
            ),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildWearTrack({required double wearValue, String? conditionLabel}) {
    final normalizedWear = wearValue.clamp(0.0, 1.0).toDouble();
    final fillFactor = normalizedWear <= 0
        ? 0
        : normalizedWear.clamp(0.06, 1.0);
    final fillColor = conditionLabel?.trim().isNotEmpty == true
        ? _conditionColor(conditionLabel!)
        : _conditionColor(_conditionLabelForWear(normalizedWear));

    return SizedBox(
      height: 2,
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFFB8C1CC).withValues(alpha: 0.38),
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: fillFactor.toDouble(),
              child: DecoratedBox(
                decoration: BoxDecoration(color: fillColor),
                child: const SizedBox(height: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _conditionLabelForWear(double wearValue) {
    if (wearValue < 0.07) {
      return 'Factory New';
    }
    if (wearValue < 0.15) {
      return 'Minimal Wear';
    }
    if (wearValue < 0.38) {
      return 'Field-Tested';
    }
    if (wearValue < 0.45) {
      return 'Well-Worn';
    }
    return 'Battle-Scarred';
  }

  Color _conditionColor(String label) {
    final normalized = label.toLowerCase();
    if (normalized.contains('factory new')) {
      return const Color(0xFF17A673);
    }
    if (normalized.contains('minimal wear')) {
      return const Color(0xFF8B5CF6);
    }
    if (normalized.contains('field-tested')) {
      return const Color(0xFF2563EB);
    }
    if (normalized.contains('well-worn')) {
      return const Color(0xFFF59E0B);
    }
    if (normalized.contains('battle-scarred')) {
      return const Color(0xFFE11D48);
    }
    if (normalized.contains('not painted')) {
      return const Color(0xFF64748B);
    }
    return _marketShowcaseBrandBlue;
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

  Widget _buildShopItemQualityRibbon(TagInfo quality) {
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
}

class MarketShowcaseLoadingCard extends StatelessWidget {
  const MarketShowcaseLoadingCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _marketShowcaseSurfaceCard,
        borderRadius: BorderRadius.circular(_marketShowcaseCardRadius),
      ),
      child: Column(
        children: [
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFFEDF1F4),
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(_marketShowcaseCardRadius),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Container(
                  height: 14,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2F4F6),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 72,
                  height: 14,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2F4F6),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class MarketProgressSpinner extends StatelessWidget {
  const MarketProgressSpinner({
    super.key,
    this.size = 22,
    this.strokeWidth = 2,
  });

  final double size;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        color: _marketShowcaseBrandBlue,
        strokeWidth: strokeWidth,
      ),
    );
  }
}

class MarketEmptyState extends StatelessWidget {
  const MarketEmptyState({
    super.key,
    required this.title,
    required this.subtitle,
    this.icon = Icons.storefront_outlined,
    this.blendWithBackground = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool blendWithBackground;

  @override
  Widget build(BuildContext context) {
    if (blendWithBackground) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 84,
                height: 84,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            _marketShowcaseBrandBlue.withValues(alpha: 0.12),
                            _marketShowcaseBrandBlue.withValues(alpha: 0.015),
                          ],
                        ),
                      ),
                    ),
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: _marketShowcaseBrandBlue.withValues(
                            alpha: 0.08,
                          ),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _marketShowcaseBrandBlue.withValues(
                              alpha: 0.10,
                            ),
                            blurRadius: 24,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Icon(
                        icon,
                        color: const Color(0xFF6B7280),
                        size: 30,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Container(
                width: 28,
                height: 4,
                decoration: BoxDecoration(
                  color: _marketShowcaseBrandBlue.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF191C1E),
                  fontSize: 18,
                  height: 24 / 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _marketShowcaseTextSecondary,
                  fontSize: 13,
                  height: 20 / 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: _marketShowcaseSurfaceCard,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFFF2F4F6),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: _marketShowcaseTextSecondary, size: 28),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF191C1E),
              fontSize: 16,
              height: 22 / 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _marketShowcaseTextSecondary,
              fontSize: 12,
              height: 18 / 12,
            ),
          ),
        ],
      ),
    );
  }
}
