import 'package:flutter/material.dart';

class HeaderFilterButton extends StatelessWidget {
  const HeaderFilterButton({
    super.key,
    required this.tooltip,
    required this.onTap,
    this.active = false,
    this.icon,
    this.size = 32,
    this.iconSize = 24,
  });

  final String tooltip;
  final VoidCallback onTap;
  final bool active;
  final IconData? icon;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final iconColor = active
        ? const Color(0xFF1E40AF)
        : const Color(0xFF1E293B);

    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: SizedBox(
            width: size,
            height: size,
            child: Center(
              child: icon != null
                  ? Icon(icon, size: iconSize, color: iconColor)
                  : SizedBox(
                      width: iconSize,
                      height: iconSize,
                      child: CustomPaint(
                        painter: _HeaderFilterGlyphPainter(color: iconColor),
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderFilterGlyphPainter extends CustomPainter {
  const _HeaderFilterGlyphPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final left = size.width * 0.20;
    final right = size.width * 0.80;
    final lineYs = <double>[
      size.height * 0.29,
      size.height * 0.50,
      size.height * 0.71,
    ];

    for (final lineY in lineYs) {
      final start = Offset(left, lineY);
      final end = Offset(right, lineY);
      canvas.drawLine(start, end, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _HeaderFilterGlyphPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
