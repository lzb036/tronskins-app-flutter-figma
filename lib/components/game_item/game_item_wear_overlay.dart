import 'dart:ui';

import 'package:flutter/material.dart';

/// Bottom wear overlay used by inventory-style item images.
class GameItemWearOverlay extends StatelessWidget {
  const GameItemWearOverlay({
    super.key,
    required this.label,
    required this.text,
    this.value,
    this.accentColor,
    this.conditionLabel,
    this.showLabel = true,
  });

  final String label;
  final String text;
  final double? value;
  final Color? accentColor;
  final String? conditionLabel;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 24),
          alignment: Alignment.bottomLeft,
          padding: const EdgeInsets.fromLTRB(10, 4, 10, 4),
          decoration: const BoxDecoration(color: Color(0x990F172A)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                showLabel ? '$label: $text' : text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xE6FFFFFF),
                  fontSize: 7,
                  height: 10 / 7,
                  fontWeight: FontWeight.w400,
                ),
              ),
              if (value != null) ...[
                const SizedBox(height: 3),
                _GameItemWearTrack(
                  value: value!,
                  accentColor: accentColor,
                  conditionLabel: conditionLabel,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Returns the canonical inventory wear text, hiding empty and zero values.
String? formatGameItemWearText(String? rawText, double? rawValue) {
  final text = rawText?.trim();
  if (text != null && text.isNotEmpty && !_isZeroLikeText(text)) {
    return text;
  }
  if (rawValue == null) {
    return null;
  }
  return rawValue.toStringAsFixed(8);
}

/// Normalizes wear values for inventory display.
double? normalizeGameItemWearValue(double? rawValue) {
  if (rawValue == null || !rawValue.isFinite || rawValue <= 0) {
    return null;
  }
  return rawValue;
}

/// Maps CS-style wear condition labels to inventory accent colors.
Color gameItemConditionColor(String label) {
  final normalized = label.toLowerCase();
  if (normalized.contains('factory new')) {
    return const Color(0xFF17A673);
  }
  if (normalized.contains('minimal wear')) {
    return const Color(0xFF8B5CF6);
  }
  if (normalized.contains('field-tested')) {
    return const Color(0xFF8BC34A);
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
  return const Color(0xFF00288E);
}

class _GameItemWearTrack extends StatelessWidget {
  const _GameItemWearTrack({
    required this.value,
    this.accentColor,
    this.conditionLabel,
  });

  final double value;
  final Color? accentColor;
  final String? conditionLabel;

  @override
  Widget build(BuildContext context) {
    final normalizedWear = value.clamp(0.0, 1.0).toDouble();
    final fillFactor = normalizedWear <= 0
        ? 0.0
        : normalizedWear.clamp(0.06, 1.0).toDouble();
    final fillColor = _resolveFillColor(normalizedWear);

    return SizedBox(
      height: 3,
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0x80334155),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: fillFactor,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: fillColor,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const SizedBox(height: 3),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _resolveFillColor(double normalizedWear) {
    final label = conditionLabel?.trim();
    if (accentColor != null) {
      return accentColor!;
    }
    if (label != null && label.isNotEmpty) {
      return gameItemConditionColor(label);
    }
    return gameItemConditionColor(_conditionLabelForWear(normalizedWear));
  }
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

bool _isZeroLikeText(String text) {
  final normalized = text.trim();
  if (normalized.isEmpty) {
    return true;
  }
  final parsed = double.tryParse(normalized);
  return parsed != null && parsed <= 0;
}
