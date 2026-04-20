import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tronskins_app/common/theme/settings_top_bar_style.dart';

class SettingsStyleAppBar extends AppBar {
  SettingsStyleAppBar({
    super.key,
    super.leading,
    bool automaticallyImplyLeading = true,
    super.title,
    super.actions,
    Widget? flexibleSpace,
    super.bottom,
    double? elevation,
    Color? shadowColor,
    ShapeBorder? shape,
    Color? backgroundColor,
    Color? foregroundColor,
    super.iconTheme,
    super.actionsIconTheme,
    bool primary = true,
    bool? centerTitle,
    bool excludeHeaderSemantics = false,
    double? titleSpacing,
    double toolbarOpacity = 1.0,
    double bottomOpacity = 1.0,
    double? toolbarHeight,
    double? leadingWidth,
    TextStyle? toolbarTextStyle,
    TextStyle? titleTextStyle,
    SystemUiOverlayStyle? systemOverlayStyle,
    Color? surfaceTintColor,
    Clip? clipBehavior,
    double? scrolledUnderElevation,
  }) : super(
         automaticallyImplyLeading: automaticallyImplyLeading,
         primary: primary,
         centerTitle: centerTitle ?? false,
         excludeHeaderSemantics: excludeHeaderSemantics,
         toolbarOpacity: toolbarOpacity,
         bottomOpacity: bottomOpacity,
         toolbarHeight: toolbarHeight ?? 64,
         leadingWidth: leadingWidth ?? 48,
         titleSpacing: titleSpacing ?? 8,
         elevation: elevation ?? 0,
         scrolledUnderElevation: scrolledUnderElevation ?? 0,
         shadowColor: shadowColor ?? Colors.transparent,
         surfaceTintColor: surfaceTintColor ?? Colors.transparent,
         backgroundColor: backgroundColor ?? settingsTopBarBackground,
         foregroundColor: foregroundColor ?? settingsTopBarBrandColor,
         shape:
             shape ??
             const Border(bottom: BorderSide(color: settingsTopBarBorderColor)),
         toolbarTextStyle: toolbarTextStyle ?? settingsTopBarTitleTextStyle,
         titleTextStyle: titleTextStyle ?? settingsTopBarTitleTextStyle,
         systemOverlayStyle: systemOverlayStyle ?? SystemUiOverlayStyle.dark,
         flexibleSpace:
             flexibleSpace ?? const _SettingsStyleAppBarBlurBackground(),
         clipBehavior: clipBehavior,
       );
}

class _SettingsStyleAppBarBlurBackground extends StatelessWidget {
  const _SettingsStyleAppBarBlurBackground();

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(color: Colors.transparent),
      ),
    );
  }
}

class SettingsStyleTopNavigation extends StatelessWidget {
  const SettingsStyleTopNavigation({
    super.key,
    required this.title,
    this.actions = const [],
    this.onBack,
    this.horizontalPadding = 24,
  });

  final String title;
  final List<Widget> actions;
  final VoidCallback? onBack;
  final double horizontalPadding;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SettingsStyleInlineTopBar(
        title: title,
        actions: actions,
        onBack: onBack,
        horizontalPadding: horizontalPadding,
        includeTopInset: true,
      ),
    );
  }
}

class SettingsStyleInlineTopBar extends StatelessWidget {
  const SettingsStyleInlineTopBar({
    super.key,
    required this.title,
    this.actions = const [],
    this.onBack,
    this.horizontalPadding = 24,
    this.includeTopInset = false,
  });

  final String title;
  final List<Widget> actions;
  final VoidCallback? onBack;
  final double horizontalPadding;
  final bool includeTopInset;

  @override
  Widget build(BuildContext context) {
    final topInset = includeTopInset ? MediaQuery.of(context).padding.top : 0.0;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: const BoxDecoration(
            color: settingsTopBarBlurBackground,
            border: Border(
              bottom: BorderSide(color: settingsTopBarBorderColor),
            ),
          ),
          padding: EdgeInsets.only(top: topInset),
          child: SettingsStyleNavigationRow(
            title: title,
            actions: actions,
            onBack: onBack,
            horizontalPadding: horizontalPadding,
          ),
        ),
      ),
    );
  }
}

class SettingsStyleNavigationRow extends StatelessWidget {
  static const double _backButtonSize = 44;

  const SettingsStyleNavigationRow({
    super.key,
    required this.title,
    this.actions = const [],
    this.onBack,
    this.horizontalPadding = 24,
  });

  final String title;
  final List<Widget> actions;
  final VoidCallback? onBack;
  final double horizontalPadding;

  void _handleDefaultBack(BuildContext context) {
    final navigator = Navigator.maybeOf(context);
    if (navigator == null) {
      return;
    }
    navigator.maybePop();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        child: Row(
          children: [
            Material(
              color: Colors.transparent,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onBack ?? () => _handleDefaultBack(context),
                child: const SizedBox(
                  width: _backButtonSize,
                  height: _backButtonSize,
                  child: Center(
                    child: Icon(
                      Icons.arrow_back,
                      size: 20,
                      color: settingsTopBarBrandColor,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: settingsTopBarTitleTextStyle,
              ),
            ),
            if (actions.isNotEmpty) ...[const SizedBox(width: 8), ...actions],
          ],
        ),
      ),
    );
  }
}
