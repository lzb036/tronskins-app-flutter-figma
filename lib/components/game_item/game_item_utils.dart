import 'package:flutter/material.dart';

const LinearGradient kUnifiedItemImageBackgroundGradient = LinearGradient(
  begin: Alignment.centerLeft,
  end: Alignment.centerRight,
  colors: [Color(0xFF2D1B1B), Color(0xFF1A0F0F)],
);

Color? parseHexColor(String? hex) {
  if (hex == null || hex.isEmpty) {
    return null;
  }
  final normalized = hex.replaceAll('#', '');
  if (normalized.length == 6) {
    return Color(int.parse('FF$normalized', radix: 16));
  }
  return null;
}

Color? qualityBorderColor(String? hex) {
  if (hex == null || hex.isEmpty) {
    return null;
  }
  final normalized = hex.replaceAll('#', '').toUpperCase();
  final safe = normalized == 'D2D2D2' ? 'FFFFFF' : normalized;
  return parseHexColor(safe);
}

BoxDecoration itemImageBackgroundDecoration({
  BorderRadiusGeometry? borderRadius,
}) {
  return BoxDecoration(
    color: const Color(0xFF1A0F0F),
    gradient: kUnifiedItemImageBackgroundGradient,
    borderRadius: borderRadius,
  );
}
