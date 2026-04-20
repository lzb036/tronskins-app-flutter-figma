import 'dart:ui';

import 'package:flutter/material.dart';

void popModalRoute<T extends Object?>(BuildContext context, [T? result]) {
  Navigator.of(context, rootNavigator: true).pop(result);
}

Future<bool> maybePopModalRoute(BuildContext context) {
  return Navigator.of(context, rootNavigator: true).maybePop();
}

Future<T?> showFigmaModal<T>({
  required BuildContext context,
  required Widget child,
  bool barrierDismissible = true,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return PopScope(
        canPop: barrierDismissible,
        child: _FigmaModalOverlay(
          barrierDismissible: barrierDismissible,
          child: child,
        ),
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.94, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class _FigmaModalOverlay extends StatelessWidget {
  const _FigmaModalOverlay({
    required this.child,
    required this.barrierDismissible,
  });

  final Widget child;
  final bool barrierDismissible;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: barrierDismissible
                  ? () => maybePopModalRoute(context)
                  : null,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 1, sigmaY: 1),
                child: Container(color: Colors.black.withValues(alpha: 0.30)),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: child,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class FigmaConfirmationDialog extends StatelessWidget {
  const FigmaConfirmationDialog({
    super.key,
    required this.title,
    this.message = '',
    required this.primaryLabel,
    required this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
    this.highlightText,
    this.content,
    this.icon = Icons.warning_amber_rounded,
    this.accentColor = const Color(0xFF1E40AF),
    this.iconColor = const Color(0xFFBA1A1A),
    this.iconBackgroundColor = const Color.fromRGBO(186, 26, 26, 0.10),
  });

  final String title;
  final String message;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final String? highlightText;
  final Widget? content;
  final IconData icon;
  final Color accentColor;
  final Color iconColor;
  final Color iconBackgroundColor;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 300),
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Color.fromRGBO(0, 0, 0, 0.25),
              blurRadius: 50,
              spreadRadius: -12,
              offset: Offset(0, 25),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: iconBackgroundColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 34, color: iconColor),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF0F172A),
                fontSize: 20,
                fontWeight: FontWeight.w700,
                height: 28 / 20,
                letterSpacing: 0,
              ),
            ),
            if (message.trim().isNotEmpty || content != null) ...[
              const SizedBox(height: 8),
              if (message.trim().isNotEmpty)
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    height: 22.75 / 14,
                  ),
                ),
              if (content != null) ...[
                if (message.trim().isNotEmpty) const SizedBox(height: 12),
                DefaultTextStyle.merge(
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    height: 22.75 / 14,
                  ),
                  child: content!,
                ),
              ],
            ],
            if (highlightText != null && highlightText!.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                highlightText!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: accentColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  height: 22.75 / 14,
                ),
              ),
            ],
            const SizedBox(height: 24),
            _FigmaDialogActionButton(
              label: primaryLabel,
              height: 52,
              backgroundColor: accentColor,
              foregroundColor: Colors.white,
              onTap: onPrimary,
              boxShadow: [
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.20),
                  blurRadius: 15,
                  spreadRadius: -3,
                  offset: const Offset(0, 10),
                ),
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.20),
                  blurRadius: 6,
                  spreadRadius: -4,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            if (secondaryLabel != null && onSecondary != null) ...[
              const SizedBox(height: 12),
              _FigmaDialogActionButton(
                label: secondaryLabel!,
                height: 52,
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF334155),
                border: Border.all(color: const Color(0xFFE2E8F0), width: 2),
                onTap: onSecondary!,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FigmaDialogActionButton extends StatelessWidget {
  const _FigmaDialogActionButton({
    required this.label,
    required this.height,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.onTap,
    this.border,
    this.boxShadow,
  });

  final String label;
  final double height;
  final Color backgroundColor;
  final Color foregroundColor;
  final VoidCallback onTap;
  final Border? border;
  final List<BoxShadow>? boxShadow;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(8),
              border: border,
              boxShadow: boxShadow,
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                    softWrap: false,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: foregroundColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      height: 24 / 16,
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
}
