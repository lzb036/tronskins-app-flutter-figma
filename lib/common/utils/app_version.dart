import 'package:flutter/services.dart';

class AppVersion {
  static Future<String>? _cachedDisplayVersion;

  static Future<String> displayVersion() {
    _cachedDisplayVersion ??= _loadDisplayVersion();
    return _cachedDisplayVersion!;
  }

  static Future<String> _loadDisplayVersion() async {
    try {
      final pubspec = await rootBundle.loadString('pubspec.yaml');
      final reg = RegExp(r'^\s*version:\s*([^\s#]+)', multiLine: true);
      final match = reg.firstMatch(pubspec);
      final raw = match?.group(1)?.trim() ?? '';
      if (raw.isEmpty) {
        return '--';
      }
      if (raw.startsWith('v') || raw.startsWith('V')) {
        return raw;
      }
      return 'v$raw';
    } catch (_) {
      return '--';
    }
  }
}
