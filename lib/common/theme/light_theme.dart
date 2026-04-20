import 'package:flutter/material.dart';
import 'package:tronskins_app/common/theme/app_colors.dart';
import 'package:tronskins_app/common/theme/app_text_theme.dart';
import 'package:tronskins_app/common/theme/settings_top_bar_style.dart';

const _figmaInputCursorColor = Color(0xFF00288E);

ThemeData lightTheme() => ThemeData(
  useMaterial3: true,
  brightness: Brightness.light,
  colorScheme: ColorScheme.fromSeed(seedColor: AppColors.light.primary),
  textSelectionTheme: const TextSelectionThemeData(
    cursorColor: _figmaInputCursorColor,
    selectionHandleColor: _figmaInputCursorColor,
    selectionColor: Color(0x3300288E),
  ),
  scaffoldBackgroundColor: AppColors.light.scaffoldBackground,
  appBarTheme: settingsTopBarAppBarTheme(),
  splashFactory: InkSparkle.splashFactory,
  extensions: [AppColors.light, AppTextTheme.light()],
);
