import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_patcher/flutter_patcher.dart';
import 'package:get/get.dart';
import 'package:restart_app/restart_app.dart';
import 'package:tronskins_app/common/logging/app_logger.dart';
import 'package:tronskins_app/common/storage/server_storage.dart';
import 'package:tronskins_app/common/theme/app_colors.dart';
import 'package:tronskins_app/common/theme/app_text_theme.dart';
import 'package:tronskins_app/common/utils/app_snackbar.dart';
import 'package:tronskins_app/common/utils/app_version.dart';

/// Runs the active Android hot-update flow based on `flutter_patcher`.
class FlutterPatcherUpdateGate extends StatefulWidget {
  const FlutterPatcherUpdateGate({super.key, required this.child});

  final Widget child;

  @override
  State<FlutterPatcherUpdateGate> createState() =>
      _FlutterPatcherUpdateGateState();
}

class _FlutterPatcherUpdateGateState extends State<FlutterPatcherUpdateGate>
    with WidgetsBindingObserver {
  static const String _checkPath = 'api/public/app/version/v1/latest/by-app';
  static const String _appKey = 'tronskins-flutter';
  static const Duration _resumeCheckThrottle = Duration(minutes: 10);
  static const Duration _checkTimeout = Duration(seconds: 8);
  static const Duration _restartNoticeDelay = Duration(milliseconds: 600);
  late final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: _checkTimeout,
      receiveTimeout: _checkTimeout,
      responseType: ResponseType.json,
      contentType: 'application/json;charset=UTF-8',
    ),
  );

  bool _isChecking = false;
  bool _isApplying = false;
  bool _hasPatchReadyForColdStart = false;
  double? _downloadProgress;
  PatchApplyPhase? _applyPhase;
  DateTime? _lastCheckAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_reportBootDiagnostic());
      unawaited(_checkForUpdates(force: true));
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_checkForUpdates());
    }
  }

  Future<void> _reportBootDiagnostic() async {
    if (!_isAndroid) {
      return;
    }

    try {
      final diagnostic = await FlutterPatcher.lastBootDiagnostic;
      if (diagnostic == null) {
        return;
      }

      final message =
          'status=${diagnostic.status.name} '
          'patch=${diagnostic.patchVersion ?? '-'} '
          'app_vc=${diagnostic.appVersionCode ?? '-'} '
          'patch_vc=${diagnostic.patchTargetVersionCode ?? '-'} '
          'crashes=${diagnostic.crashCount ?? '-'}';
      if (diagnostic.isHealthy) {
        AppLogger.info('FLUTTER_PATCHER', message, scope: 'BOOT');
      } else {
        AppLogger.warn(
          'FLUTTER_PATCHER',
          message,
          scope: 'BOOT',
          error: diagnostic.message,
        );
      }
    } catch (error, stackTrace) {
      AppLogger.warn(
        'FLUTTER_PATCHER',
        'Failed to read boot diagnostic.',
        scope: 'BOOT',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _checkForUpdates({bool force = false}) async {
    if (!_shouldCheckForUpdates(force: force)) {
      return;
    }

    _isChecking = true;
    _lastCheckAt = DateTime.now();

    try {
      final checkRequest = await _buildCheckRequest();
      AppLogger.info(
        'FLUTTER_PATCHER',
        'Checking update from ${checkRequest.uri}',
        scope: 'CHECK',
      );

      final patch = await _fetchPatch(checkRequest);
      if (!mounted || patch == null) {
        return;
      }

      final currentPatch = await FlutterPatcher.currentVersion;
      if (currentPatch != null &&
          currentPatch.isNotEmpty &&
          currentPatch == patch.version) {
        AppLogger.info(
          'FLUTTER_PATCHER',
          'Patch ${patch.version} is already installed.',
          scope: 'CHECK',
        );
        return;
      }

      await _applyPatch(patch);
    } on PatcherException catch (error, stackTrace) {
      AppLogger.warn(
        'FLUTTER_PATCHER',
        'Patch check failed.',
        scope: 'CHECK',
        error: error,
        stackTrace: stackTrace,
      );
    } catch (error, stackTrace) {
      AppLogger.warn(
        'FLUTTER_PATCHER',
        'Unexpected patch check failure.',
        scope: 'CHECK',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      _isChecking = false;
    }
  }

  bool _shouldCheckForUpdates({required bool force}) {
    if (!mounted || !_isAndroid || _isChecking || _isApplying) {
      return false;
    }
    if (_hasPatchReadyForColdStart) {
      return false;
    }
    if (force) {
      return true;
    }

    final lastCheckAt = _lastCheckAt;
    return lastCheckAt == null ||
        DateTime.now().difference(lastCheckAt) >= _resumeCheckThrottle;
  }

  Future<_FlutterPatcherCheckRequest> _buildCheckRequest() async {
    final baseUri = Uri.parse(ServerStorage.getServer());
    final endpoint = baseUri.resolve(_checkPath);
    final versionCode = await FlutterPatcher.appVersionCode;

    return _FlutterPatcherCheckRequest(
      uri: endpoint.replace(
        queryParameters: <String, String>{
          'appKey': _appKey,
          'platform': 'android',
        },
      ),
      targetVersionCode: versionCode,
    );
  }

  Future<PatchInfo?> _fetchPatch(
    _FlutterPatcherCheckRequest checkRequest,
  ) async {
    final response = await _dio.getUri<Object?>(
      checkRequest.uri,
      options: Options(
        headers: const {'content-type': 'application/json;charset=UTF-8'},
      ),
    );
    final map = _asMap(response.data);
    if (map == null) {
      throw const FormatException('Update response is not a JSON object.');
    }

    final payload = _unwrapResponsePayload(map);
    final baseVersion = _legacyVersionName(await AppVersion.baseVersion());
    final enabled = _firstBool(payload, const ['flag', 'enabled']);
    final serverVersionName = _firstNonEmptyString(payload, const [
      'version',
      'versionName',
      'version_name',
    ]);
    final serverPatchVersion = _firstNonEmptyString(payload, const [
      'timestamp',
      'patchVersion',
      'patch_version',
      'hotVersion',
      'hot_version',
      'versionCode',
    ]);
    if (enabled == false) {
      AppLogger.info(
        'FLUTTER_PATCHER',
        'Update payload disabled by server flag.',
        scope: 'CHECK',
      );
      return null;
    }

    final forwardUrl = _firstNonEmptyString(payload, const [
      'hotPackage',
      'hot_package',
      'forwardUrl',
      'forward_url',
      'patchUrl',
      'patch_url',
      'downloadUrl',
      'download_url',
    ]);
    if (forwardUrl == null) {
      AppLogger.info(
        'FLUTTER_PATCHER',
        'No hotPackage/forwardUrl in update response. '
            'serverVersion=${serverVersionName ?? '-'} '
            'patchVersion=${serverPatchVersion ?? '-'} '
            'localBaseVersion=$baseVersion',
        scope: 'CHECK',
      );
      return null;
    }

    AppLogger.info(
      'FLUTTER_PATCHER',
      'Update payload resolved. '
          'serverVersion=${serverVersionName ?? '-'} '
          'patchVersion=${serverPatchVersion ?? '-'} '
          'localBaseVersion=$baseVersion',
      scope: 'CHECK',
    );

    if (forwardUrl.toLowerCase().endsWith('.apk')) {
      AppLogger.warn(
        'FLUTTER_PATCHER',
        'Received APK update package; flutter_patcher only applies libapp.so.',
        scope: 'CHECK',
      );
      return null;
    }

    final patchUrl = _resolvePatchUrl(forwardUrl);
    if (serverVersionName != null &&
        serverVersionName.trim().isNotEmpty &&
        serverVersionName.trim() != baseVersion) {
      AppLogger.warn(
        'FLUTTER_PATCHER',
        'Skip patch because server version ${serverVersionName.trim()} '
            'does not match local base version $baseVersion.',
        scope: 'CHECK',
      );
      return null;
    }

    final patchVersion =
        _firstNonEmptyString(payload, const [
          'timestamp',
          'patchVersion',
          'patch_version',
          'version',
          'versionName',
          'version_name',
          'hotVersion',
          'hot_version',
          'versionCode',
        ]) ??
        patchUrl;

    return PatchInfo(
      version: patchVersion,
      patchUrl: patchUrl,
      md5: _normalizeMd5(
        _firstNonEmptyString(payload, const [
              'md5',
              'fileMd5',
              'file_md5',
              'checksum',
              'hash',
            ]) ??
            '',
      ),
      signature:
          _firstNonEmptyString(payload, const ['signature', 'sign']) ?? '',
      targetVersionCode:
          _firstInt(payload, const [
            'targetVersionCode',
            'target_version_code',
            'hotVersion',
            'hot_version',
            'versionCode',
          ]) ??
          checkRequest.targetVersionCode,
      raw: payload,
    );
  }

  Future<void> _applyPatch(PatchInfo patch) async {
    _setApplying(true);
    AppLogger.info(
      'FLUTTER_PATCHER',
      'Applying patch version=${patch.version}',
      scope: 'APPLY',
    );

    try {
      final result = await FlutterPatcher.applyPatch(
        patch,
        onProgress: _handleProgress,
      );
      if (!mounted) {
        return;
      }

      if (result.ok) {
        _hasPatchReadyForColdStart = true;
        await Future<void>.delayed(_restartNoticeDelay);
        if (!mounted) {
          return;
        }
        await _restartAfterPatch();
        return;
      }

      AppLogger.warn(
        'FLUTTER_PATCHER',
        'Patch apply failed error=${result.error?.name} '
            'message=${result.message ?? '-'}',
        scope: 'APPLY',
      );
    } catch (error, stackTrace) {
      AppLogger.errorLog(
        'FLUTTER_PATCHER',
        'Unexpected patch apply failure.',
        scope: 'APPLY',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      _setApplying(false);
    }
  }

  void _handleProgress(PatchApplyProgress progress) {
    if (!mounted) {
      return;
    }

    setState(() {
      _applyPhase = progress.phase;
      _downloadProgress = progress.fraction;
    });
  }

  void _setApplying(bool value) {
    if (!mounted || _isApplying == value) {
      return;
    }

    setState(() {
      _isApplying = value;
      if (!value) {
        _applyPhase = null;
        _downloadProgress = null;
      }
    });
  }

  void _showRestartNotice() {
    final copy = _copyForLocale();
    AppSnackbar.info(copy.restartMessage, title: copy.restartTitle);
  }

  Future<void> _restartAfterPatch() async {
    final result = await Restart.restartApp(mode: RestartMode.process);
    if (result.success) {
      AppLogger.info(
        'FLUTTER_PATCHER',
        'Automatic restart requested after patch install. '
            'mode=${result.mode.name}',
        scope: 'RESTART',
      );
      return;
    }

    AppLogger.warn(
      'FLUTTER_PATCHER',
      'Automatic restart failed. code=${result.code ?? '-'} '
          'message=${result.message ?? '-'}',
      scope: 'RESTART',
    );
    if (mounted) {
      _showRestartNotice();
    }
  }

  _FlutterPatcherCopy _copyForLocale() {
    final locale =
        Get.locale ?? WidgetsBinding.instance.platformDispatcher.locale;
    final isChinese = locale.languageCode.toLowerCase().startsWith('zh');
    return isChinese ? _FlutterPatcherCopy.zh() : _FlutterPatcherCopy.en();
  }

  bool get _isAndroid {
    return !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        IgnorePointer(
          ignoring: !_isApplying,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: _isApplying
                ? _FlutterPatcherOverlay(
                    progress: _downloadProgress,
                    phase: _applyPhase,
                    copy: _copyForLocale(),
                  )
                : const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }
}

class _FlutterPatcherOverlay extends StatelessWidget {
  const _FlutterPatcherOverlay({
    required this.progress,
    required this.phase,
    required this.copy,
  });

  final double? progress;
  final PatchApplyPhase? phase;
  final _FlutterPatcherCopy copy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appColors =
        theme.extension<AppColors>() ??
        (theme.brightness == Brightness.dark
            ? AppColors.dark
            : AppColors.light);
    final textTheme =
        theme.extension<AppTextTheme>() ??
        (theme.brightness == Brightness.dark
            ? AppTextTheme.dark()
            : AppTextTheme.light());
    final progressValue = progress;

    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.54),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: appColors.surface,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.24),
                  blurRadius: 32,
                  offset: const Offset(0, 18),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 22),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 48,
                      height: 48,
                      child: CircularProgressIndicator(
                        value: progressValue,
                        strokeWidth: 4,
                        color: appColors.primary,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      copy.downloadingTitle,
                      textAlign: TextAlign.center,
                      style: textTheme.titleMedium.copyWith(
                        color: appColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _messageForPhase(copy, phase),
                      textAlign: TextAlign.center,
                      style: textTheme.bodyMedium.copyWith(
                        color: appColors.textSecondary,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _messageForPhase(_FlutterPatcherCopy copy, PatchApplyPhase? phase) {
    switch (phase) {
      case PatchApplyPhase.verifying:
        return copy.verifyingMessage;
      case PatchApplyPhase.finalizing:
        return copy.finalizingMessage;
      case PatchApplyPhase.downloading:
      case null:
        return copy.downloadingMessage;
    }
  }
}

class _FlutterPatcherCopy {
  const _FlutterPatcherCopy({
    required this.downloadingTitle,
    required this.downloadingMessage,
    required this.verifyingMessage,
    required this.finalizingMessage,
    required this.restartTitle,
    required this.restartMessage,
  });

  factory _FlutterPatcherCopy.zh() {
    return const _FlutterPatcherCopy(
      downloadingTitle: '正在加载热更新',
      downloadingMessage: '请稍候，补丁正在下载。',
      verifyingMessage: '补丁已下载，正在校验完整性。',
      finalizingMessage: '补丁正在安装，下次冷启动后生效。',
      restartTitle: '热更新已就绪',
      restartMessage: '请完全关闭应用后重新打开，以使用最新版本。',
    );
  }

  factory _FlutterPatcherCopy.en() {
    return const _FlutterPatcherCopy(
      downloadingTitle: 'Loading hot update',
      downloadingMessage: 'Please wait while the patch is downloaded.',
      verifyingMessage: 'Patch downloaded. Verifying integrity.',
      finalizingMessage:
          'Patch is being installed and will work after a cold start.',
      restartTitle: 'Hot update is ready',
      restartMessage: 'Fully close and reopen the app to use the latest patch.',
    );
  }

  final String downloadingTitle;
  final String downloadingMessage;
  final String verifyingMessage;
  final String finalizingMessage;
  final String restartTitle;
  final String restartMessage;
}

class _FlutterPatcherCheckRequest {
  const _FlutterPatcherCheckRequest({
    required this.uri,
    required this.targetVersionCode,
  });

  final Uri uri;
  final int? targetVersionCode;
}

String _normalizeVersion(String version) {
  final trimmed = version.trim();
  if (trimmed.startsWith('v') || trimmed.startsWith('V')) {
    return trimmed.substring(1);
  }
  return trimmed;
}

String _legacyVersionName(String version) {
  final normalized = _normalizeVersion(version);
  final buildSeparatorIndex = normalized.indexOf('+');
  if (buildSeparatorIndex <= 0) {
    return normalized;
  }
  return normalized.substring(0, buildSeparatorIndex);
}

Map<String, dynamic>? _asMap(Object? value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, value) => MapEntry(key.toString(), value));
  }
  if (value is String && value.trim().isNotEmpty) {
    final decoded = jsonDecode(value);
    return _asMap(decoded);
  }
  return null;
}

Map<String, dynamic> _unwrapResponsePayload(Map<String, dynamic> map) {
  if (_firstNonEmptyString(map, const ['forwardUrl']) != null) {
    return map;
  }
  for (final key in const ['data', 'datas']) {
    final nested = _asMap(map[key]);
    if (nested != null) {
      return nested;
    }
  }
  return map;
}

String? _firstNonEmptyString(Map<String, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final value = map[key];
    if (value == null) {
      continue;
    }
    final text = value.toString().trim();
    if (text.isNotEmpty) {
      return text;
    }
  }
  return null;
}

int? _firstInt(Map<String, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final value = map[key];
    if (value is num) {
      return value.toInt();
    }
    if (value is String && value.trim().isNotEmpty) {
      final parsed = int.tryParse(value.trim());
      if (parsed != null) {
        return parsed;
      }
    }
  }
  return null;
}

bool? _firstBool(Map<String, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final value = map[key];
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized.isEmpty) {
        continue;
      }
      if (normalized == 'true' || normalized == '1') {
        return true;
      }
      if (normalized == 'false' || normalized == '0') {
        return false;
      }
    }
  }
  return null;
}

String _resolvePatchUrl(String url) {
  final trimmed = url.trim();
  final uri = Uri.tryParse(trimmed);
  if (uri != null && uri.hasScheme) {
    return trimmed;
  }
  return Uri.parse(ServerStorage.getServer()).resolve(trimmed).toString();
}

String _normalizeMd5(String value) {
  return value.trim().toLowerCase();
}
