import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const settingsTopBarBackground = Color(0xFFF8FAFC);
const settingsTopBarBlurBackground = Color.fromRGBO(248, 250, 252, 0.7);
const settingsTopBarBorderColor = Color.fromRGBO(226, 232, 240, 0.5);
const settingsTopBarBrandColor = Color(0xFF1E3A8A);
const settingsTopBarToolbarHeight = 64.0;
const settingsTopBarLeadingWidth = 48.0;
const settingsTopBarTitleSpacing = 8.0;
const settingsTopBarInlineHorizontalPadding = 0.0;
const settingsTopBarActionTrailingPadding = 16.0;
const settingsTopBarActionsPadding = EdgeInsetsDirectional.only(
  end: settingsTopBarActionTrailingPadding,
);

const settingsTopBarTitleTextStyle = TextStyle(
  color: settingsTopBarBrandColor,
  fontSize: 20,
  fontWeight: FontWeight.w700,
  height: 1.4,
  letterSpacing: -0.5,
);

AppBarTheme settingsTopBarAppBarTheme() {
  return const AppBarTheme(
    centerTitle: false,
    leadingWidth: settingsTopBarLeadingWidth,
    titleSpacing: settingsTopBarTitleSpacing,
    toolbarHeight: settingsTopBarToolbarHeight,
    backgroundColor: settingsTopBarBackground,
    foregroundColor: settingsTopBarBrandColor,
    elevation: 0,
    scrolledUnderElevation: 0,
    shadowColor: Colors.transparent,
    surfaceTintColor: Colors.transparent,
    iconTheme: IconThemeData(color: settingsTopBarBrandColor, size: 20),
    actionsIconTheme: IconThemeData(color: settingsTopBarBrandColor, size: 20),
    titleTextStyle: settingsTopBarTitleTextStyle,
    toolbarTextStyle: settingsTopBarTitleTextStyle,
    systemOverlayStyle: SystemUiOverlayStyle.dark,
    shape: Border(bottom: BorderSide(color: settingsTopBarBorderColor)),
    actionsPadding: settingsTopBarActionsPadding,
  );
}
