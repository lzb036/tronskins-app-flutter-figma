import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class AppRequestLoading {
  static final ValueNotifier<int> _activeCount = ValueNotifier<int>(0);

  static ValueListenable<int> get listenable => _activeCount;

  static void show() {
    _activeCount.value = _activeCount.value + 1;
  }

  static void hide() {
    final current = _activeCount.value;
    if (current <= 0) {
      return;
    }
    _activeCount.value = current - 1;
  }
}

class AppRequestLoadingOverlay extends StatelessWidget {
  const AppRequestLoadingOverlay({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        ValueListenableBuilder<int>(
          valueListenable: AppRequestLoading.listenable,
          builder: (context, count, _) {
            final visible = count > 0;
            return IgnorePointer(
              ignoring: !visible,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: visible
                    ? const _AppRequestLoadingBarrier()
                    : const SizedBox.shrink(),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _AppRequestLoadingBarrier extends StatelessWidget {
  const _AppRequestLoadingBarrier();

  @override
  Widget build(BuildContext context) {
    final languageCode = Localizations.localeOf(context).languageCode;
    final loadingText = languageCode.startsWith('zh') ? '加载中...' : 'Loading...';
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
        child: Center(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.all(Radius.circular(16)),
              boxShadow: [
                BoxShadow(
                  color: Color.fromRGBO(15, 23, 42, 0.12),
                  blurRadius: 24,
                  offset: Offset(0, 12),
                ),
              ],
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2.6),
                  ),
                  SizedBox(height: 12),
                  Text(
                    loadingText,
                    style: const TextStyle(
                      color: Color(0xFF334155),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
