import 'package:flutter/material.dart';

/// A dropdown menu whose popup has no top or bottom menu padding.
class ZeroPaddingDropdown<T extends Object> extends StatelessWidget {
  const ZeroPaddingDropdown({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
    this.selectedLabel,
    this.textStyle,
    this.iconColor,
    this.dropdownColor = Colors.white,
    this.selectedItemColor = const Color(0xFFE5E5E5),
    this.menuBorderRadius = const BorderRadius.all(Radius.circular(12)),
    this.fieldBorderRadius = const BorderRadius.all(Radius.circular(8)),
    this.itemPadding = const EdgeInsets.symmetric(horizontal: 18),
    this.itemHeight = 52,
    this.menuMaxHeight = 280,
    this.elevation = 8,
  });

  final T value;
  final List<ZeroPaddingDropdownOption<T>> options;
  final ValueChanged<T>? onChanged;
  final String? selectedLabel;
  final TextStyle? textStyle;
  final Color? iconColor;
  final Color dropdownColor;
  final Color selectedItemColor;
  final BorderRadius menuBorderRadius;
  final BorderRadius fieldBorderRadius;
  final EdgeInsetsGeometry itemPadding;
  final double itemHeight;
  final double menuMaxHeight;
  final double elevation;

  @override
  Widget build(BuildContext context) {
    final effectiveStyle = textStyle ?? DefaultTextStyle.of(context).style;
    final effectiveIconColor = iconColor ?? IconTheme.of(context).color;
    final enabled = onChanged != null && options.isNotEmpty;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: fieldBorderRadius,
        onTap: enabled ? () => _showMenu(context) : null,
        child: Row(
          children: [
            Expanded(
              child: Text(
                selectedLabel ?? _labelFor(value) ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: effectiveStyle,
              ),
            ),
            Icon(Icons.keyboard_arrow_down_rounded, color: effectiveIconColor),
          ],
        ),
      ),
    );
  }

  String? _labelFor(T optionValue) {
    for (final option in options) {
      if (option.value == optionValue) {
        return option.label;
      }
    }
    return null;
  }

  Future<void> _showMenu(BuildContext context) async {
    final renderObject = context.findRenderObject();
    final overlayObject = Overlay.of(context).context.findRenderObject();
    if (renderObject is! RenderBox || overlayObject is! RenderBox) {
      return;
    }

    final targetTopLeft = renderObject.localToGlobal(
      Offset.zero,
      ancestor: overlayObject,
    );
    final targetBottomRight = renderObject.localToGlobal(
      renderObject.size.bottomRight(Offset.zero),
      ancestor: overlayObject,
    );
    final targetRect = Rect.fromLTRB(
      targetTopLeft.dx,
      targetTopLeft.dy,
      targetBottomRight.dx,
      targetBottomRight.dy,
    );
    final selectedValue = await showMenu<T>(
      context: context,
      position: RelativeRect.fromLTRB(
        targetRect.left,
        targetRect.bottom,
        overlayObject.size.width - targetRect.right,
        overlayObject.size.height - targetRect.bottom,
      ),
      constraints: BoxConstraints(
        minWidth: targetRect.width,
        maxWidth: targetRect.width,
        maxHeight: menuMaxHeight,
      ),
      color: dropdownColor,
      surfaceTintColor: Colors.transparent,
      elevation: elevation,
      shape: RoundedRectangleBorder(borderRadius: menuBorderRadius),
      clipBehavior: Clip.antiAlias,
      menuPadding: EdgeInsets.zero,
      items: options
          .map(
            (option) => PopupMenuItem<T>(
              value: option.value,
              height: itemHeight,
              padding: EdgeInsets.zero,
              child: Container(
                width: double.infinity,
                height: itemHeight,
                alignment: Alignment.centerLeft,
                padding: itemPadding,
                color: option.value == value
                    ? selectedItemColor
                    : Colors.transparent,
                child: Text(
                  option.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textStyle,
                ),
              ),
            ),
          )
          .toList(growable: false),
    );

    if (!context.mounted || selectedValue == null) {
      return;
    }
    onChanged?.call(selectedValue);
  }
}

/// A selectable value and display label for [ZeroPaddingDropdown].
class ZeroPaddingDropdownOption<T extends Object> {
  const ZeroPaddingDropdownOption({required this.value, required this.label});

  final T value;
  final String label;
}
