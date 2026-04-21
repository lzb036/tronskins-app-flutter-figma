import 'package:flutter/material.dart';

const Color _menuBrandBlue = Color(0xFF0F4FD6);
const Color _menuTextPrimary = Color(0xFF374151);
const Color _menuPanelFill = Colors.white;
const Color _menuPanelBorder = Color(0xFFE7EBF2);
const Color _menuSelectedFill = Color(0xFFF3F5F8);
const Color _menuPressedFill = Color(0xFFF8FAFC);
const Color _menuPendingDot = Color(0xFFFF9500);

String _pendingCountLabel(int count) {
  if (count <= 0) {
    return '';
  }
  if (count > 99) {
    return '99+';
  }
  return '$count';
}

Future<int?> showGameSwitchMenu({
  required BuildContext iconContext,
  required int currentAppId,
  Map<int, int>? pendingTotalsByAppId,
}) {
  final overlayBox =
      Overlay.of(iconContext).context.findRenderObject() as RenderBox;
  final anchorBox = iconContext.findRenderObject() as RenderBox;
  final iconRect =
      anchorBox.localToGlobal(Offset.zero, ancestor: overlayBox) &
      anchorBox.size;
  final screenSize = overlayBox.size;
  final hasPending =
      pendingTotalsByAppId?.values.any((value) => value > 0) ?? false;
  const horizontalMargin = 12.0;
  const verticalMargin = 12.0;
  const panelGap = 6.0;
  final panelWidth = hasPending ? 188.0 : 180.0;
  const estimatedPanelHeight = 152.0;
  final showAbove =
      iconRect.bottom + panelGap + estimatedPanelHeight >
          screenSize.height - verticalMargin &&
      iconRect.top - panelGap - estimatedPanelHeight >= verticalMargin;
  final panelTop = showAbove
      ? (iconRect.top - panelGap - estimatedPanelHeight)
            .clamp(verticalMargin, screenSize.height - verticalMargin)
            .toDouble()
      : (iconRect.bottom + panelGap)
            .clamp(verticalMargin, screenSize.height - verticalMargin)
            .toDouble();
  final panelLeft = (iconRect.right - panelWidth)
      .clamp(horizontalMargin, screenSize.width - panelWidth - horizontalMargin)
      .toDouble();

  return showGeneralDialog<int>(
    context: iconContext,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(
      iconContext,
    ).modalBarrierDismissLabel,
    barrierColor: Colors.black.withValues(alpha: 0.02),
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (_, __, ___) => const SizedBox.shrink(),
    transitionBuilder: (context, animation, __, ___) {
      return _GameSwitchOverlay(
        animation: animation,
        left: panelLeft,
        top: panelTop,
        showAbove: showAbove,
        width: panelWidth,
        currentAppId: currentAppId,
        pendingTotalsByAppId: pendingTotalsByAppId,
      );
    },
  );
}

class _GameSwitchOverlay extends StatelessWidget {
  const _GameSwitchOverlay({
    required this.animation,
    required this.left,
    required this.top,
    required this.showAbove,
    required this.width,
    required this.currentAppId,
    this.pendingTotalsByAppId,
  });

  final Animation<double> animation;
  final double left;
  final double top;
  final bool showAbove;
  final double width;
  final int currentAppId;
  final Map<int, int>? pendingTotalsByAppId;

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    final beginOffset = showAbove
        ? const Offset(0, 0.04)
        : const Offset(0, -0.04);
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          Positioned(
            top: top,
            left: left,
            width: width,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: beginOffset,
                end: Offset.zero,
              ).animate(curved),
              child: ScaleTransition(
                alignment: showAbove
                    ? Alignment.bottomRight
                    : Alignment.topRight,
                scale: Tween<double>(begin: 0.94, end: 1).animate(curved),
                child: FadeTransition(
                  opacity: curved,
                  child: _GameSwitchPanel(
                    width: width,
                    currentAppId: currentAppId,
                    pendingTotalsByAppId: pendingTotalsByAppId,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GameSwitchPanel extends StatelessWidget {
  const _GameSwitchPanel({
    required this.width,
    required this.currentAppId,
    this.pendingTotalsByAppId,
  });

  final double width;
  final int currentAppId;
  final Map<int, int>? pendingTotalsByAppId;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: _menuPanelFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _menuPanelBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x140F172A),
            blurRadius: 22,
            spreadRadius: -10,
            offset: Offset(0, 12),
          ),
          BoxShadow(
            color: Color(0x0D0F172A),
            blurRadius: 8,
            spreadRadius: -4,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _GameOption(
            appId: 730,
            name: 'CS2',
            selected: currentAppId == 730,
            pendingCount: pendingTotalsByAppId?[730] ?? 0,
          ),
          _GameOption(
            appId: 570,
            name: 'Dota 2',
            selected: currentAppId == 570,
            pendingCount: pendingTotalsByAppId?[570] ?? 0,
          ),
          _GameOption(
            appId: 440,
            name: 'TF2',
            selected: currentAppId == 440,
            pendingCount: pendingTotalsByAppId?[440] ?? 0,
          ),
        ],
      ),
    );
  }
}

class _GameOption extends StatelessWidget {
  const _GameOption({
    required this.appId,
    required this.name,
    required this.selected,
    this.pendingCount = 0,
  });

  final int appId;
  final String name;
  final bool selected;
  final int pendingCount;

  @override
  Widget build(BuildContext context) {
    final textStyle = TextStyle(
      color: selected ? _menuBrandBlue : _menuTextPrimary,
      fontSize: 14,
      height: 20 / 14,
      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: () => Navigator.of(context).pop(appId),
          borderRadius: BorderRadius.circular(8),
          overlayColor: WidgetStateProperty.resolveWith<Color?>((states) {
            if (states.contains(WidgetState.pressed)) {
              return _menuPressedFill;
            }
            return null;
          }),
          child: SizedBox(
            height: 42,
            child: Stack(
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: selected ? _menuSelectedFill : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        12,
                        0,
                        selected ? 18 : 12,
                        0,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: textStyle,
                            ),
                          ),
                          if (pendingCount > 0) ...[
                            const SizedBox(width: 8),
                            Container(
                              constraints: const BoxConstraints(minWidth: 18),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: _menuPendingDot.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(999),
                                boxShadow: [
                                  BoxShadow(
                                    color: _menuPendingDot.withValues(
                                      alpha: 0.16,
                                    ),
                                    blurRadius: 6,
                                    spreadRadius: 0.5,
                                  ),
                                ],
                              ),
                              child: Text(
                                _pendingCountLabel(pendingCount),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: _menuPendingDot,
                                  fontSize: 10,
                                  height: 1.2,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                if (selected)
                  Positioned(
                    top: 6,
                    right: 0,
                    bottom: 6,
                    child: Container(
                      width: 3,
                      decoration: BoxDecoration(
                        color: _menuBrandBlue,
                        borderRadius: BorderRadius.circular(999),
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
