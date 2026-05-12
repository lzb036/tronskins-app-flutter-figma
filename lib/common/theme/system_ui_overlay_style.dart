import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const appTransparentSystemUiOverlayStyle = SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  statusBarIconBrightness: Brightness.dark,
  statusBarBrightness: Brightness.light,
  systemStatusBarContrastEnforced: false,
);

void configureTransparentSystemBars() {
  SystemChrome.setSystemUIOverlayStyle(appTransparentSystemUiOverlayStyle);
}
