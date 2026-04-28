import 'package:flutter/services.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';

class AppVersion {
  static Future<String>? _cachedBaseVersion;
  static Future<String>? _cachedDisplayVersion;
  static Future<String>? _cachedHotUpdateVersion;
  static final ShorebirdUpdater _shorebirdUpdater = ShorebirdUpdater();

  static Future<String> baseVersion() {
    _cachedBaseVersion ??= _loadBaseVersion();
    return _cachedBaseVersion!;
  }

  static Future<String> displayVersion() {
    _cachedDisplayVersion ??= _loadDisplayVersion();
    return _cachedDisplayVersion!;
  }

  static Future<String> hotUpdateVersion() {
    _cachedHotUpdateVersion ??= _loadHotUpdateVersion();
    return _cachedHotUpdateVersion!;
  }

  static Future<String> _loadDisplayVersion() async {
    try {
      final version = await baseVersion();
      if (version == '--') {
        return version;
      }

      final patchSuffix = await _loadPatchSuffix();
      return '$version$patchSuffix';
    } catch (_) {
      return '--';
    }
  }

  static Future<String> _loadBaseVersion() async {
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

  static Future<String> _loadPatchSuffix() async {
    final hotUpdateVersion = await AppVersion.hotUpdateVersion();
    if (hotUpdateVersion == '--') {
      return '';
    }
    return ' $hotUpdateVersion';
  }

  static Future<String> _loadHotUpdateVersion() async {
    try {
      final patch = await _shorebirdUpdater.readCurrentPatch();
      final number = patch?.number;
      if (number == null) {
        return '--';
      }
      return 'patch.$number';
    } catch (_) {
      return '--';
    }
  }
}
