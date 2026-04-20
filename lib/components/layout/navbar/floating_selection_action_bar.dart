import 'dart:ui';

import 'package:flutter/material.dart';

enum SelectionActionBarButtonVariant { neutral, primary, destructive }

class SelectionActionBarButtonData {
  const SelectionActionBarButtonData({
    required this.label,
    required this.onTap,
    this.variant = SelectionActionBarButtonVariant.neutral,
  });

  final String label;
  final VoidCallback onTap;
  final SelectionActionBarButtonVariant variant;
}

class FloatingSelectionActionBar extends StatelessWidget {
  const FloatingSelectionActionBar({
    super.key,
    required this.isAllSelected,
    required this.selectAllLabel,
    required this.toggleTooltip,
    required this.selectedCountText,
    required this.onToggleSelectAll,
    required this.actions,
  });

  final bool isAllSelected;
  final String selectAllLabel;
  final String toggleTooltip;
  final String selectedCountText;
  final VoidCallback onToggleSelectAll;
  final List<SelectionActionBarButtonData> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final barBackground = isDark
        ? const Color(0xE6141A22)
        : Colors.white.withValues(alpha: 0.95);
    final barBorder = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : const Color(0xFFF1F5F9);
    final shadowColor = Colors.black.withValues(alpha: isDark ? 0.24 : 0.12);

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Transform.translate(
        offset: const Offset(0, 8),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: shadowColor,
                blurRadius: 24,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: barBackground,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: barBorder),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Tooltip(
                        message: toggleTooltip,
                        child: _SelectAllControl(
                          isAllSelected: isAllSelected,
                          label: selectAllLabel,
                          onTap: onToggleSelectAll,
                        ),
                      ),
                      const SizedBox(width: 10),
                      _SelectedCount(countText: selectedCountText),
                      const SizedBox(width: 10),
                      Expanded(child: _ActionButtons(actions: actions)),
                    ],
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

class _SelectAllControl extends StatelessWidget {
  const _SelectAllControl({
    required this.isAllSelected,
    required this.label,
    required this.onTap,
  });

  final bool isAllSelected;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF2563EB);
    final labelStyle = Theme.of(context).textTheme.labelMedium?.copyWith(
      color: const Color(0xFF334155),
      fontSize: 12,
      height: 16 / 12,
      fontWeight: FontWeight.w600,
    );

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: SizedBox(
          width: 80,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: isAllSelected ? primaryColor : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: primaryColor, width: 2),
                  ),
                  child: isAllSelected
                      ? const Icon(
                          Icons.check_rounded,
                          size: 14,
                          color: Colors.white,
                        )
                      : null,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SizedBox(
                    height: 16,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          label,
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.ellipsis,
                          style: labelStyle,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectedCount extends StatelessWidget {
  const _SelectedCount({required this.countText});

  final String countText;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.titleSmall?.copyWith(
      color: const Color(0xFF2563EB),
      fontSize: 16,
      height: 20 / 16,
      fontWeight: FontWeight.w700,
    );

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 48),
      child: Text(countText, textAlign: TextAlign.center, style: style),
    );
  }
}

class _ActionButtons extends StatelessWidget {
  const _ActionButtons({required this.actions});

  final List<SelectionActionBarButtonData> actions;

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) {
      return const SizedBox.shrink();
    }

    if (actions.length == 1) {
      return Align(
        alignment: Alignment.centerRight,
        heightFactor: 1,
        child: SizedBox(width: 108, child: _ActionButton(data: actions.first)),
      );
    }

    return Row(
      children: [
        for (var index = 0; index < actions.length; index++) ...[
          Expanded(child: _ActionButton(data: actions[index])),
          if (index < actions.length - 1) const SizedBox(width: 8),
        ],
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.data});

  final SelectionActionBarButtonData data;

  @override
  Widget build(BuildContext context) {
    final colors = _resolveColors(data.variant);
    final textStyle = Theme.of(context).textTheme.labelMedium?.copyWith(
      color: colors.foreground,
      fontSize: 12,
      height: 16 / 12,
      fontWeight: FontWeight.w700,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(12),
        boxShadow: colors.shadow == null
            ? null
            : [
                BoxShadow(
                  color: colors.shadow!,
                  blurRadius: 15,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: data.onTap,
          child: SizedBox(
            height: 40,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: SizedBox(
                  height: 16,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      data.label,
                      maxLines: 1,
                      softWrap: false,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: textStyle,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  _ActionButtonColors _resolveColors(SelectionActionBarButtonVariant variant) {
    switch (variant) {
      case SelectionActionBarButtonVariant.primary:
        return const _ActionButtonColors(
          background: Color(0xFF2563EB),
          foreground: Colors.white,
          shadow: Color(0x333B82F6),
        );
      case SelectionActionBarButtonVariant.destructive:
        return const _ActionButtonColors(
          background: Color(0xFFE11D48),
          foreground: Colors.white,
          shadow: Color(0x33E11D48),
        );
      case SelectionActionBarButtonVariant.neutral:
        return const _ActionButtonColors(
          background: Color(0xFFF1F5F9),
          foreground: Color(0xFF334155),
        );
    }
  }
}

class _ActionButtonColors {
  const _ActionButtonColors({
    required this.background,
    required this.foreground,
    this.shadow,
  });

  final Color background;
  final Color foreground;
  final Color? shadow;
}
