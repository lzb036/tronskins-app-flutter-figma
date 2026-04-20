import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ListEndTip extends StatelessWidget {
  const ListEndTip({super.key, this.padding});

  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final rawLabel = 'app.common.no_more_data'.tr;
    final label = rawLabel == 'app.common.no_more_data'
        ? 'No more data'
        : rawLabel;
    final textStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: const Color(0xFF94A3B8),
      fontWeight: FontWeight.w600,
      height: 18 / 12,
    );
    return Padding(
      padding:
          padding ?? const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      child: Center(
        child: Text(label, style: textStyle, textAlign: TextAlign.center),
      ),
    );
  }
}
