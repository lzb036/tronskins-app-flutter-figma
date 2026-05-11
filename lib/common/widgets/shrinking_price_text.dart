import 'package:flutter/material.dart';

/// Displays a one-line price that scales down only when it needs more width.
class ShrinkingPriceText extends StatelessWidget {
  const ShrinkingPriceText({
    super.key,
    required this.text,
    this.style,
    this.textAlign = TextAlign.start,
    this.alignment = Alignment.centerLeft,
  });

  final String text;
  final TextStyle? style;
  final TextAlign textAlign;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: alignment,
        child: Text(
          text,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.visible,
          textAlign: textAlign,
          style: style,
        ),
      ),
    );
  }
}
