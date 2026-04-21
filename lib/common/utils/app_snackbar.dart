import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tronskins_app/common/theme/app_colors.dart';

class AppSnackbar {
  AppSnackbar._();

  static const int _maxShowAttempts = 3;
  static const Duration _displayDuration = Duration(milliseconds: 3200);
  static const Duration _animationDuration = Duration(milliseconds: 280);

  static int _showGeneration = 0;
  static OverlayEntry? _overlayEntry;
  static GlobalKey<_AppSnackbarOverlayState>? _overlayKey;

  static void success(String message, {String? title}) {
    _show(message: message, title: title, variant: _AppSnackbarVariant.success);
  }

  static void error(String message, {String? title}) {
    _show(message: message, title: title, variant: _AppSnackbarVariant.error);
  }

  static void neutral(String message, {String? title}) {
    _show(message: message, title: title, variant: _AppSnackbarVariant.neutral);
  }

  static void info(String message, {String? title}) {
    neutral(message, title: title);
  }

  static void dismissCurrent() {
    _overlayKey?.currentState?.dismiss();
  }

  static void _show({
    required String message,
    String? title,
    required _AppSnackbarVariant variant,
  }) {
    final trimmedMessage = message.trim();
    if (trimmedMessage.isEmpty) {
      return;
    }

    final resolvedTitle = title?.trim().isNotEmpty == true
        ? title!.trim()
        : _defaultTitle(variant);
    final generation = ++_showGeneration;
    final data = _AppSnackbarData(
      title: resolvedTitle,
      message: trimmedMessage,
      variant: variant,
    );
    _scheduleShow(generation: generation, data: data);
  }

  static void _scheduleShow({
    required int generation,
    required _AppSnackbarData data,
    int attempt = 0,
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (generation != _showGeneration) {
        return;
      }

      final overlayState = Get.key.currentState?.overlay;
      if (overlayState == null) {
        if (attempt + 1 >= _maxShowAttempts) {
          return;
        }
        _scheduleShow(generation: generation, data: data, attempt: attempt + 1);
        WidgetsBinding.instance.ensureVisualUpdate();
        return;
      }

      final existingState = _overlayKey?.currentState;
      if (_overlayEntry != null && existingState != null) {
        existingState.show(data);
        return;
      }

      final overlayKey = GlobalKey<_AppSnackbarOverlayState>();
      _overlayKey = overlayKey;
      _overlayEntry = OverlayEntry(
        builder: (_) => _AppSnackbarOverlay(
          key: overlayKey,
          initialData: data,
          onClosed: _removeCurrentOverlay,
        ),
      );
      overlayState.insert(_overlayEntry!);
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  static void _removeCurrentOverlay() {
    final entry = _overlayEntry;
    _overlayEntry = null;
    _overlayKey = null;
    if (entry != null && entry.mounted) {
      entry.remove();
    }
  }

  static String _defaultTitle(_AppSnackbarVariant variant) {
    switch (variant) {
      case _AppSnackbarVariant.success:
        return _translateOrFallback(
          'app.system.snackbar.success_title',
          'Success',
        );
      case _AppSnackbarVariant.error:
        return _translateOrFallback(
          'app.system.snackbar.failed_title',
          'Failed',
        );
      case _AppSnackbarVariant.neutral:
        return 'app.system.tips.title'.tr;
    }
  }

  static String _translateOrFallback(String key, String fallback) {
    final translated = key.tr;
    return translated == key ? fallback : translated;
  }
}

enum _AppSnackbarVariant { success, error, neutral }

class _AppSnackbarData {
  const _AppSnackbarData({
    required this.title,
    required this.message,
    required this.variant,
  });

  final String title;
  final String message;
  final _AppSnackbarVariant variant;
}

class _AppSnackbarOverlay extends StatefulWidget {
  const _AppSnackbarOverlay({
    super.key,
    required this.initialData,
    required this.onClosed,
  });

  final _AppSnackbarData initialData;
  final VoidCallback onClosed;

  @override
  State<_AppSnackbarOverlay> createState() => _AppSnackbarOverlayState();
}

class _AppSnackbarOverlayState extends State<_AppSnackbarOverlay> {
  late _AppSnackbarData _data;
  bool _visible = false;
  bool _closing = false;
  int _dismissEpoch = 0;
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    _data = widget.initialData;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        show(widget.initialData);
      }
    });
  }

  void show(_AppSnackbarData data) {
    _dismissTimer?.cancel();
    _dismissEpoch++;
    setState(() {
      _data = data;
      _visible = true;
      _closing = false;
    });
    _dismissTimer = Timer(AppSnackbar._displayDuration, dismiss);
  }

  void dismiss() {
    if (!_visible || _closing) {
      return;
    }
    _dismissTimer?.cancel();
    final epoch = ++_dismissEpoch;
    setState(() {
      _visible = false;
      _closing = true;
    });
    Future<void>.delayed(AppSnackbar._animationDuration, () {
      if (!mounted || !_closing || epoch != _dismissEpoch) {
        return;
      }
      widget.onClosed();
    });
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.maybeOf(context)?.padding.top ?? 0.0;

    return Positioned(
      top: topInset + 8,
      left: 12,
      right: 12,
      child: IgnorePointer(
        ignoring: !_visible,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: AnimatedSlide(
              duration: AppSnackbar._animationDuration,
              curve: Curves.easeOutCubic,
              offset: _visible ? Offset.zero : const Offset(0, -0.12),
              child: AnimatedOpacity(
                duration: AppSnackbar._animationDuration,
                curve: Curves.easeOutCubic,
                opacity: _visible ? 1 : 0,
                child: _AppSnackbarCard(data: _data),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AppSnackbarCard extends StatelessWidget {
  const _AppSnackbarCard({required this.data});

  final _AppSnackbarData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appColors =
        theme.extension<AppColors>() ??
        (theme.brightness == Brightness.dark
            ? AppColors.dark
            : AppColors.light);
    final style = _AppSnackbarStyle.resolve(
      variant: data.variant,
      appColors: appColors,
      brightness: theme.brightness,
    );

    final titleStyle =
        theme.textTheme.titleSmall?.copyWith(
          color: style.titleColor,
          fontWeight: FontWeight.w700,
          height: 1.2,
        ) ??
        TextStyle(
          color: style.titleColor,
          fontSize: 16,
          fontWeight: FontWeight.w700,
          height: 1.2,
        );
    final messageStyle =
        theme.textTheme.bodyMedium?.copyWith(
          color: style.messageColor,
          fontWeight: FontWeight.w500,
          height: 1.45,
        ) ??
        TextStyle(
          color: style.messageColor,
          fontSize: 14,
          fontWeight: FontWeight.w500,
          height: 1.45,
        );

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [style.surfaceStart, style.surfaceEnd],
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: style.borderColor),
            boxShadow: [
              BoxShadow(
                color: style.shadowColor,
                blurRadius: 28,
                spreadRadius: -10,
                offset: const Offset(0, 16),
              ),
              BoxShadow(
                color: style.accentGlowColor,
                blurRadius: 20,
                spreadRadius: -14,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        style.accentColor,
                        style.accentColor.withValues(alpha: 0.18),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: -44,
                right: -26,
                child: IgnorePointer(
                  child: Container(
                    width: 112,
                    height: 112,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          style.accentGlowColor,
                          style.accentGlowColor.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _IconBadge(style: style),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    data.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: titleStyle,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              _DismissButton(style: style),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            data.message,
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                            style: messageStyle,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DismissButton extends StatelessWidget {
  const _DismissButton({required this.style});

  final _AppSnackbarStyle style;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: AppSnackbar.dismissCurrent,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: style.dismissBackgroundColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: style.dismissBorderColor),
        ),
        child: Icon(
          Icons.close_rounded,
          color: style.dismissIconColor,
          size: 18,
        ),
      ),
    );
  }
}

class _IconBadge extends StatelessWidget {
  const _IconBadge({required this.style});

  final _AppSnackbarStyle style;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: style.iconBackgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: style.iconBorderColor),
      ),
      child: SizedBox(
        width: 46,
        height: 46,
        child: Icon(style.icon, color: style.accentColor, size: 24),
      ),
    );
  }
}

class _AppSnackbarStyle {
  const _AppSnackbarStyle({
    required this.icon,
    required this.accentColor,
    required this.surfaceStart,
    required this.surfaceEnd,
    required this.borderColor,
    required this.shadowColor,
    required this.accentGlowColor,
    required this.titleColor,
    required this.messageColor,
    required this.iconBackgroundColor,
    required this.iconBorderColor,
    required this.dismissBackgroundColor,
    required this.dismissBorderColor,
    required this.dismissIconColor,
  });

  final IconData icon;
  final Color accentColor;
  final Color surfaceStart;
  final Color surfaceEnd;
  final Color borderColor;
  final Color shadowColor;
  final Color accentGlowColor;
  final Color titleColor;
  final Color messageColor;
  final Color iconBackgroundColor;
  final Color iconBorderColor;
  final Color dismissBackgroundColor;
  final Color dismissBorderColor;
  final Color dismissIconColor;

  factory _AppSnackbarStyle.resolve({
    required _AppSnackbarVariant variant,
    required AppColors appColors,
    required Brightness brightness,
  }) {
    const figmaSlate50 = Color(0xFFF8FAFC);
    const figmaSlate100 = Color(0xFFF1F5F9);
    const figmaSlate200 = Color(0xFFE2E8F0);
    const figmaSlate400 = Color(0xFF94A3B8);
    const figmaSlate500 = Color(0xFF64748B);
    const figmaSlate900 = Color(0xFF0F172A);
    const figmaDarkBase = Color(0xFF111827);
    const figmaDarkRaised = Color(0xFF1E293B);

    final isDark = brightness == Brightness.dark;

    late final Color accent;
    late final IconData icon;
    switch (variant) {
      case _AppSnackbarVariant.success:
        accent = appColors.success;
        icon = Icons.check_circle_rounded;
        break;
      case _AppSnackbarVariant.error:
        accent = appColors.danger;
        icon = Icons.error_rounded;
        break;
      case _AppSnackbarVariant.neutral:
        accent = appColors.primary;
        icon = Icons.notifications_active_rounded;
        break;
    }

    final baseStart = isDark
        ? figmaDarkBase.withValues(alpha: 0.96)
        : Colors.white.withValues(alpha: 0.96);
    final baseEnd = isDark
        ? figmaDarkRaised.withValues(alpha: 0.94)
        : figmaSlate50.withValues(alpha: 0.98);

    return _AppSnackbarStyle(
      icon: icon,
      accentColor: accent,
      surfaceStart: Color.alphaBlend(
        accent.withValues(alpha: isDark ? 0.14 : 0.08),
        baseStart,
      ),
      surfaceEnd: Color.alphaBlend(
        accent.withValues(alpha: isDark ? 0.04 : 0.02),
        baseEnd,
      ),
      borderColor: Color.alphaBlend(
        accent.withValues(alpha: isDark ? 0.24 : 0.10),
        isDark ? figmaSlate400.withValues(alpha: 0.18) : figmaSlate200,
      ),
      shadowColor: Colors.black.withValues(alpha: isDark ? 0.30 : 0.12),
      accentGlowColor: accent.withValues(alpha: isDark ? 0.22 : 0.10),
      titleColor: isDark ? Colors.white : figmaSlate900,
      messageColor: isDark ? figmaSlate100 : figmaSlate500,
      iconBackgroundColor: accent.withValues(alpha: isDark ? 0.18 : 0.12),
      iconBorderColor: accent.withValues(alpha: isDark ? 0.32 : 0.18),
      dismissBackgroundColor: isDark
          ? Colors.white.withValues(alpha: 0.06)
          : figmaSlate50,
      dismissBorderColor: isDark
          ? Colors.white.withValues(alpha: 0.08)
          : figmaSlate200,
      dismissIconColor: isDark ? figmaSlate100 : figmaSlate500,
    );
  }
}
