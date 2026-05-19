import 'package:flutter/material.dart';

class HeaderFilterButton extends StatelessWidget {
  const HeaderFilterButton({
    super.key,
    required this.tooltip,
    required this.onTap,
    this.active = false,
    this.icon = Icons.filter_alt_outlined,
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
              child: Icon(icon, size: iconSize, color: iconColor),
            ),
          ),
        ),
      ),
    );
  }
}
