import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:tronskins_app/common/theme/settings_top_bar_style.dart';
import 'package:tronskins_app/common/widgets/settings_style_app_bar.dart';

class FilterSheetStyle {
  static const Color pageBackground = Color(0xFFF7F9FB);
  static const Color cardBackground = Colors.white;
  static const Color mutedBackground = Color(0xFFF2F4F6);
  static const Color subtleBackground = Color(0xFFE6E8EA);
  static const Color divider = Color(0xFFF1F5F9);
  static const Color border = Color(0xFFC4C5D5);
  static const Color title = Color(0xFF191C1E);
  static const Color body = Color(0xFF444653);
  static const Color hint = Color(0xFF6B7280);
  static const Color primary = Color(0xFF00288E);
  static const Color primaryBright = Color(0xFF0058BE);
  static const Color priceAccent = Color(0xFF1E40AF);
  static const Color selectedSoft = Color(0x1A00288E);
  static const Color selectedSoftBorder = Color(0x3300288E);
  static const Color white80 = Color(0xCCFFFFFF);
  static const Color surfaceStroke = Color(0xFFF2F4F6);

  static const BorderRadius panelRadius = BorderRadius.only(
    topLeft: Radius.circular(22),
    topRight: Radius.circular(22),
  );
  static const BorderRadius cardRadius = BorderRadius.all(Radius.circular(8));
  static const BorderRadius chipRadius = BorderRadius.all(Radius.circular(8));
  static const BorderRadius buttonRadius = BorderRadius.all(
    Radius.circular(12),
  );

  static const List<BoxShadow> cardShadow = <BoxShadow>[
    BoxShadow(color: Color(0x0D000000), blurRadius: 2, offset: Offset(0, 1)),
  ];

  static InputDecoration inputDecoration({
    required String hintText,
    String? prefixText,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(
        color: hint,
        fontSize: 14,
        height: 20 / 14,
        fontWeight: FontWeight.w400,
      ),
      prefixText: prefixText,
      prefixStyle: const TextStyle(
        color: body,
        fontSize: 14,
        height: 20 / 14,
        fontWeight: FontWeight.w400,
      ),
      filled: true,
      fillColor: mutedBackground,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: cardRadius,
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: cardRadius,
        borderSide: BorderSide.none,
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: cardRadius,
        borderSide: BorderSide(color: primary, width: 1.25),
      ),
    );
  }
}

class FilterSheetFrame extends StatelessWidget {
  const FilterSheetFrame({
    super.key,
    required this.title,
    required this.body,
    required this.confirmLabel,
    this.confirmCount,
    required this.onConfirm,
    required this.onClose,
    this.onReset,
    this.resetLabel,
    this.bottomPadding = 0,
    this.footerContent,
  });

  final String title;
  final Widget body;
  final String confirmLabel;
  final int? confirmCount;
  final VoidCallback onConfirm;
  final VoidCallback onClose;
  final VoidCallback? onReset;
  final String? resetLabel;
  final double bottomPadding;
  final Widget? footerContent;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: FilterSheetStyle.pageBackground,
      child: Column(
        children: [
          _FilterSheetHeader(
            title: title,
            onClose: onClose,
            onReset: onReset,
            resetLabel: resetLabel,
          ),
          Expanded(child: body),
          _FilterSheetFooter(
            confirmLabel: confirmLabel,
            confirmCount: confirmCount,
            onConfirm: onConfirm,
            bottomPadding: bottomPadding,
            child: footerContent,
          ),
        ],
      ),
    );
  }
}

class FilterSheetSection extends StatelessWidget {
  const FilterSheetSection({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
    this.carded = true,
    this.contentPadding = const EdgeInsets.all(20),
  });

  final String title;
  final Widget child;
  final Widget? trailing;
  final bool carded;
  final EdgeInsetsGeometry contentPadding;

  @override
  Widget build(BuildContext context) {
    final content = carded
        ? Container(
            width: double.infinity,
            padding: contentPadding,
            decoration: const BoxDecoration(
              color: FilterSheetStyle.cardBackground,
              borderRadius: FilterSheetStyle.cardRadius,
              boxShadow: FilterSheetStyle.cardShadow,
            ),
            child: child,
          )
        : child;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: FilterSheetStyle.title,
                    fontSize: 15,
                    height: 22.5 / 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.375,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        ),
        const SizedBox(height: 16),
        content,
      ],
    );
  }
}

class FilterSheetOptionChip extends StatelessWidget {
  const FilterSheetOptionChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.fullWidth = false,
    this.selectedStyle = FilterChipSelectedStyle.solid,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
    this.selectedColor,
    this.selectedBorderColor,
    this.selectedTextColor,
    this.unselectedColor,
    this.unselectedBorderColor,
    this.unselectedTextColor,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    this.minHeight = 36,
    this.selectedFontWeight = FontWeight.w600,
    this.unselectedFontWeight = FontWeight.w500,
    this.fontSize = 13,
    this.height = 19.5 / 13,
    this.boxShadow = const <BoxShadow>[],
    this.selectedBoxShadow,
    this.unselectedBoxShadow,
    this.scaleDownLabel = false,
    this.maxLines = 2,
    this.contentAlignment = Alignment.center,
    this.textAlign = TextAlign.center,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool fullWidth;
  final FilterChipSelectedStyle selectedStyle;
  final BorderRadius borderRadius;
  final Color? selectedColor;
  final Color? selectedBorderColor;
  final Color? selectedTextColor;
  final Color? unselectedColor;
  final Color? unselectedBorderColor;
  final Color? unselectedTextColor;
  final EdgeInsetsGeometry padding;
  final double minHeight;
  final FontWeight selectedFontWeight;
  final FontWeight unselectedFontWeight;
  final double fontSize;
  final double height;
  final List<BoxShadow> boxShadow;
  final List<BoxShadow>? selectedBoxShadow;
  final List<BoxShadow>? unselectedBoxShadow;
  final bool scaleDownLabel;
  final int maxLines;
  final AlignmentGeometry contentAlignment;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    final bool useSolid = selectedStyle == FilterChipSelectedStyle.solid;
    final Color background = selected
        ? (selectedColor ??
              (useSolid
                  ? FilterSheetStyle.primary
                  : FilterSheetStyle.selectedSoft))
        : (unselectedColor ?? FilterSheetStyle.subtleBackground);
    final Color border = selected
        ? (selectedBorderColor ??
              (useSolid
                  ? Colors.transparent
                  : FilterSheetStyle.selectedSoftBorder))
        : (unselectedBorderColor ?? FilterSheetStyle.border);
    final Color textColor = selected
        ? (selectedTextColor ??
              (useSolid ? Colors.white : FilterSheetStyle.primary))
        : (unselectedTextColor ?? FilterSheetStyle.body);
    final List<BoxShadow> resolvedBoxShadow = selected
        ? (selectedBoxShadow ?? boxShadow)
        : (unselectedBoxShadow ?? boxShadow);

    final child = InkWell(
      borderRadius: borderRadius,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        constraints: BoxConstraints(minHeight: minHeight),
        padding: padding,
        decoration: BoxDecoration(
          color: background,
          borderRadius: borderRadius,
          border: Border.all(color: border),
          boxShadow: resolvedBoxShadow,
        ),
        child: Align(
          alignment: contentAlignment,
          widthFactor: fullWidth ? null : 1,
          heightFactor: 1,
          child: scaleDownLabel
              ? FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    textAlign: textAlign,
                    maxLines: maxLines,
                    style: TextStyle(
                      color: textColor,
                      fontSize: fontSize,
                      height: height,
                      fontWeight: selected
                          ? selectedFontWeight
                          : unselectedFontWeight,
                    ),
                  ),
                )
              : Text(
                  label,
                  textAlign: textAlign,
                  maxLines: maxLines,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: textColor,
                    fontSize: fontSize,
                    height: height,
                    fontWeight: selected
                        ? selectedFontWeight
                        : unselectedFontWeight,
                  ),
                ),
        ),
      ),
    );

    if (!fullWidth) {
      return child;
    }
    return SizedBox(width: double.infinity, child: child);
  }
}

enum FilterChipSelectedStyle { solid, soft }

class FilterSheetRadioTile extends StatelessWidget {
  const FilterSheetRadioTile({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.showDivider = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: FilterSheetStyle.title,
                      fontSize: 14,
                      height: 21 / 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? FilterSheetStyle.primary : Colors.white,
                    border: Border.all(
                      color: selected
                          ? Colors.transparent
                          : FilterSheetStyle.border,
                    ),
                  ),
                  child: selected
                      ? const Icon(Icons.check, color: Colors.white, size: 14)
                      : null,
                ),
              ],
            ),
          ),
        ),
        if (showDivider)
          const Divider(
            height: 1,
            thickness: 1,
            color: FilterSheetStyle.divider,
          ),
      ],
    );
  }
}

class FilterSheetCheckboxTile extends StatelessWidget {
  const FilterSheetCheckboxTile({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.labelColor,
    this.selectedLabelColor,
    this.unselectedLabelColor,
    this.selectedFillColor,
    this.unselectedFillColor,
    this.selectedBorderColor,
    this.unselectedBorderColor,
    this.checkColor = Colors.white,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? labelColor;
  final Color? selectedLabelColor;
  final Color? unselectedLabelColor;
  final Color? selectedFillColor;
  final Color? unselectedFillColor;
  final Color? selectedBorderColor;
  final Color? unselectedBorderColor;
  final Color checkColor;

  @override
  Widget build(BuildContext context) {
    final resolvedLabelColor = selected
        ? (selectedLabelColor ?? labelColor ?? FilterSheetStyle.title)
        : (unselectedLabelColor ?? labelColor ?? FilterSheetStyle.title);
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: selected
                    ? (selectedFillColor ?? FilterSheetStyle.primary)
                    : (unselectedFillColor ?? Colors.white),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: selected
                      ? (selectedBorderColor ?? Colors.transparent)
                      : (unselectedBorderColor ?? FilterSheetStyle.border),
                ),
              ),
              child: selected
                  ? Icon(Icons.check, size: 15, color: checkColor)
                  : null,
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: resolvedLabelColor,
                  fontSize: 14,
                  height: 21 / 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FilterSheetDateField extends StatelessWidget {
  const FilterSheetDateField({
    super.key,
    required this.title,
    required this.value,
    required this.onTap,
  });

  final String title;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: FilterSheetStyle.cardRadius,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: const BoxDecoration(
          color: FilterSheetStyle.mutedBackground,
          borderRadius: FilterSheetStyle.cardRadius,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: FilterSheetStyle.hint,
                fontSize: 12,
                height: 18 / 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                color: FilterSheetStyle.title,
                fontSize: 14,
                height: 20 / 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterSheetHeader extends StatelessWidget {
  const _FilterSheetHeader({
    required this.title,
    required this.onClose,
    this.onReset,
    this.resetLabel,
  });

  final String title;
  final VoidCallback onClose;
  final VoidCallback? onReset;
  final String? resetLabel;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            color: settingsTopBarBlurBackground,
            border: Border(
              bottom: BorderSide(color: settingsTopBarBorderColor),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: SettingsStyleNavigationRow(
              title: title,
              onBack: onClose,
              actions: [
                if (onReset != null)
                  TextButton(
                    onPressed: onReset,
                    style: TextButton.styleFrom(
                      foregroundColor: FilterSheetStyle.body,
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(38, 20),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      textStyle: const TextStyle(
                        fontSize: 14,
                        height: 20 / 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    child: Text(resetLabel ?? ''),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FilterSheetFooter extends StatelessWidget {
  const _FilterSheetFooter({
    required this.confirmLabel,
    this.confirmCount,
    required this.onConfirm,
    required this.bottomPadding,
    this.child,
  });

  final String confirmLabel;
  final int? confirmCount;
  final VoidCallback onConfirm;
  final double bottomPadding;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final resolvedConfirmLabel = confirmCount == null
        ? confirmLabel
        : '$confirmLabel($confirmCount)';
    return ClipRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: const BoxDecoration(
            color: FilterSheetStyle.white80,
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Color(0x0A000000),
                blurRadius: 30,
                offset: Offset(0, -8),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomPadding),
              child:
                  child ??
                  DecoratedBox(
                    decoration: const BoxDecoration(
                      borderRadius: FilterSheetStyle.buttonRadius,
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: <Color>[
                          FilterSheetStyle.primary,
                          FilterSheetStyle.primaryBright,
                        ],
                      ),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: Color(0x19000000),
                          blurRadius: 15,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: TextButton(
                        onPressed: onConfirm,
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                          shape: const RoundedRectangleBorder(
                            borderRadius: FilterSheetStyle.buttonRadius,
                          ),
                          textStyle: const TextStyle(
                            fontSize: 18,
                            height: 28 / 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        child: Text(resolvedConfirmLabel),
                      ),
                    ),
                  ),
            ),
          ),
        ),
      ),
    );
  }
}
