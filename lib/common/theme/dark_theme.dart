import 'package:flutter/material.dart';
import 'package:tronskins_app/common/theme/app_colors.dart';
import 'package:tronskins_app/common/theme/app_text_theme.dart';
import 'package:tronskins_app/common/theme/settings_top_bar_style.dart';

const _figmaInputCursorColorDark = Color(0xFF3B82F6);

ThemeData darkTheme() => ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  colorScheme: ColorScheme.fromSeed(
    seedColor: AppColors.dark.primary,
    brightness: Brightness.dark,
  ),
  textSelectionTheme: const TextSelectionThemeData(
    cursorColor: _figmaInputCursorColorDark,
    selectionHandleColor: _figmaInputCursorColorDark,
    selectionColor: Color(0x4D3B82F6),
  ),
  scaffoldBackgroundColor: AppColors.dark.scaffoldBackground,
  appBarTheme: settingsTopBarAppBarTheme(),
  splashFactory: InkRipple.splashFactory,
  extensions: [AppColors.dark, AppTextTheme.dark()],
);
