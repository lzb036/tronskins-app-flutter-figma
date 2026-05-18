import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_patcher/flutter_patcher.dart';
import 'package:restart_app/restart_app.dart';
import 'package:tronskins_app/common/logging/app_logger.dart';
import 'package:tronskins_app/common/theme/app_colors.dart';
import 'package:tronskins_app/common/theme/app_text_theme.dart';
import 'package:tronskins_app/common/utils/app_snackbar.dart';

/// Local-only hot update gate used to verify flutter_patcher packages.
class LocalFlutterPatcherUpdateGate extends StatefulWidget {
  const LocalFlutterPatcherUpdateGate({super.key, required this.child});

  static const bool enabled = bool.fromEnvironment(
    'TRONSKINS_LOCAL_PATCHER_ENABLED',
    defaultValue: false,
  );
  static const String manifestUrl = String.fromEnvironment(
    'TRONSKINS_LOCAL_PATCHER_MANIFEST_URL',
    defaultValue: '',
  );
  static const String patchUrl = String.fromEnvironment(
    'TRONSKINS_LOCAL_PATCHER_URL',
    defaultValue: '',
  );
  static const String patchVersion = String.fromEnvironment(
    'TRONSKINS_LOCAL_PATCHER_VERSION',
    defaultValue: '',
  );
  static const String md5 = String.fromEnvironment(
    'TRONSKINS_LOCAL_PATCHER_MD5',
    defaultValue: '',
  );
  static const String signature = String.fromEnvironment(
    'TRONSKINS_LOCAL_PATCHER_SIGNATURE',
    defaultValue: '',
  );
  static const int _targetVersionCode = int.fromEnvironment(
    'TRONSKINS_LOCAL_PATCHER_TARGET_VERSION_CODE',
    defaultValue: 0,
  );

  final Widget child;

  static int? get targetVersionCode =>
      _targetVersionCode > 0 ? _targetVersionCode : null;

  @override
  State<LocalFlutterPatcherUpdateGate> createState() =>
      _LocalFlutterPatcherUpdateGateState();
}

class _LocalFlutterPatcherUpdateGateState
    extends State<LocalFlutterPatcherUpdateGate>
    with WidgetsBindingObserver {
  static const Duration _checkTimeout = Duration(seconds: 8);
  static const Duration _resumeCheckThrottle = Duration(seconds: 30);
  static const Duration _restartNoticeDelay = Duration(milliseconds: 600);

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: _checkTimeout,
      receiveTimeout: _checkTimeout,
      responseType: ResponseType.json,
      contentType: Headers.jsonContentType,
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
      unawaited(_checkLocalPatch(force: true));
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _dio.close(force: true);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_checkLocalPatch());
    }
  }

  Future<void> _checkLocalPatch({bool force = false}) async {
    if (!_shouldCheck(force: force)) {
      return;
    }

    _isChecking = true;
    _lastCheckAt = DateTime.now();
    try {
      final patch = await _loadLocalPatch();
      if (!mounted || patch == null) {
        return;
      }

      final currentPatch = await FlutterPatcher.currentVersion;
      if (currentPatch != null &&
          currentPatch.isNotEmpty &&
          currentPatch == patch.version) {
        AppLogger.info(
          'LOCAL_PATCHER',
          'Patch ${patch.version} is already installed.',
          scope: 'CHECK',
        );
        return;
      }

      await _applyLocalPatch(patch);
    } on PatcherException catch (error, stackTrace) {
      AppLogger.warn(
        'LOCAL_PATCHER',
        'Local patch check failed.',
        scope: 'CHECK',
        error: error,
        stackTrace: stackTrace,
      );
      _showFailedNotice(error.toString());
    } catch (error, stackTrace) {
      AppLogger.warn(
        'LOCAL_PATCHER',
        'Unexpected local patch check failure.',
        scope: 'CHECK',
        error: error,
        stackTrace: stackTrace,
      );
      _showFailedNotice(error.toString());
    } finally {
      _isChecking = false;
    }
  }

  bool _shouldCheck({required bool force}) {
    if (!mounted ||
        !_isAndroid ||
        _isChecking ||
        _isApplying ||
        _hasPatchReadyForColdStart) {
      return false;
    }
    if (force) {
      return true;
    }

    final lastCheckAt = _lastCheckAt;
    return lastCheckAt == null ||
        DateTime.now().difference(lastCheckAt) >= _resumeCheckThrottle;
  }

  Future<PatchInfo?> _loadLocalPatch() async {
    if (LocalFlutterPatcherUpdateGate.manifestUrl.isNotEmpty) {
      return _loadPatchFromManifest(LocalFlutterPatcherUpdateGate.manifestUrl);
    }
    if (LocalFlutterPatcherUpdateGate.patchUrl.isNotEmpty) {
      return _buildPatchInfo(
        rawPatchUrl: LocalFlutterPatcherUpdateGate.patchUrl,
        baseUri: null,
        raw: const <String, dynamic>{},
      );
    }

    AppLogger.warn(
      'LOCAL_PATCHER',
      'Local patcher is enabled but no patch URL or manifest URL is set.',
      scope: 'CHECK',
    );
    AppSnackbar.neutral('本地热更已开启，但没有配置补丁地址。', title: '本地热更');
    return null;
  }

  Future<PatchInfo?> _loadPatchFromManifest(String manifestUrl) async {
    final manifestUri = Uri.parse(manifestUrl);
    AppLogger.info(
      'LOCAL_PATCHER',
      'Checking local manifest $manifestUri',
      scope: 'CHECK',
    );

    final response = await _dio.getUri<Object?>(manifestUri);
    final map = _asMap(response.data);
    if (map == null) {
      throw const FormatException('Local patch manifest is not a JSON object.');
    }

    final payload = _unwrapResponsePayload(map);
    final forwardUrl = _firstNonEmptyString(payload, const [
      'forwardUrl',
      'patchUrl',
      'patch_url',
    ]);
    if (forwardUrl == null) {
      AppLogger.info(
        'LOCAL_PATCHER',
        'No forwardUrl in local manifest.',
        scope: 'CHECK',
      );
      return null;
    }

    return _buildPatchInfo(
      rawPatchUrl: forwardUrl,
      baseUri: manifestUri,
      raw: payload,
    );
  }

  Future<PatchInfo> _buildPatchInfo({
    required String rawPatchUrl,
    required Uri? baseUri,
    required Map<String, dynamic> raw,
  }) async {
    final patchUrl = _resolvePatchUrl(rawPatchUrl, baseUri: baseUri);
    final targetVersionCode =
        _firstInt(raw, const ['targetVersionCode', 'target_version_code']) ??
        LocalFlutterPatcherUpdateGate.targetVersionCode ??
        await FlutterPatcher.appVersionCode;
    final version =
        _firstNonEmptyString(raw, const [
          'patchVersion',
          'patch_version',
          'version',
          'versionName',
          'hotVersion',
        ]) ??
        LocalFlutterPatcherUpdateGate.patchVersion.ifBlank(
          'local-${DateTime.now().millisecondsSinceEpoch}',
        );

    return PatchInfo(
      version: version,
      patchUrl: patchUrl,
      md5:
          (_firstNonEmptyString(raw, const [
                    'md5',
                    'fileMd5',
                    'file_md5',
                    'checksum',
                    'hash',
                  ]) ??
                  LocalFlutterPatcherUpdateGate.md5)
              .trim()
              .toLowerCase(),
      signature:
          _firstNonEmptyString(raw, const ['signature', 'sign']) ??
          LocalFlutterPatcherUpdateGate.signature,
      targetVersionCode: targetVersionCode,
      raw: raw,
    );
  }

  Future<void> _applyLocalPatch(PatchInfo patch) async {
    _setApplying(true);
    AppLogger.info(
      'LOCAL_PATCHER',
      'Applying local patch version=${patch.version}',
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
        'LOCAL_PATCHER',
        'Local patch apply failed error=${result.error?.name} '
            'message=${result.message ?? '-'}',
        scope: 'APPLY',
      );
      _showFailedNotice(result.message ?? result.error?.name ?? 'unknown');
    } catch (error, stackTrace) {
      AppLogger.errorLog(
        'LOCAL_PATCHER',
        'Unexpected local patch apply failure.',
        scope: 'APPLY',
        error: error,
        stackTrace: stackTrace,
      );
      _showFailedNotice(error.toString());
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

  void _showFailedNotice(String message) {
    if (!mounted) {
      return;
    }
    AppSnackbar.error(message, title: '本地热更失败');
  }

  Future<void> _restartAfterPatch() async {
    final result = await Restart.restartApp(mode: RestartMode.process);
    if (result.success) {
      AppLogger.info(
        'LOCAL_PATCHER',
        'Automatic restart requested after local patch install. '
            'mode=${result.mode.name}',
        scope: 'RESTART',
      );
      return;
    }

    AppLogger.warn(
      'LOCAL_PATCHER',
      'Automatic restart failed. code=${result.code ?? '-'} '
          'message=${result.message ?? '-'}',
      scope: 'RESTART',
    );
    if (mounted) {
      AppSnackbar.success('本地热更已安装，请完全关闭应用后重新打开，本地热更才会生效。', title: '本地热更已安装');
    }
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
                ? _LocalFlutterPatcherOverlay(
                    progress: _downloadProgress,
                    phase: _applyPhase,
                  )
                : const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }
}

class _LocalFlutterPatcherOverlay extends StatelessWidget {
  const _LocalFlutterPatcherOverlay({required this.progress, this.phase});

  final double? progress;
  final PatchApplyPhase? phase;

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

    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.54),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: appColors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 22),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 340),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 48,
                      height: 48,
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 4,
                        color: appColors.primary,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      '正在安装本地热更',
                      textAlign: TextAlign.center,
                      style: textTheme.titleMedium.copyWith(
                        color: appColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _messageForPhase(phase),
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

  String _messageForPhase(PatchApplyPhase? phase) {
    switch (phase) {
      case PatchApplyPhase.verifying:
        return '补丁已下载，正在校验。';
      case PatchApplyPhase.finalizing:
        return '补丁正在保存，下次冷启动后生效。';
      case PatchApplyPhase.downloading:
      case null:
        return '正在从本地测试地址下载 libapp.so。';
    }
  }
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

String _resolvePatchUrl(String url, {required Uri? baseUri}) {
  final trimmed = url.trim();
  final uri = Uri.tryParse(trimmed);
  if (uri != null && uri.hasScheme) {
    return trimmed;
  }
  return (baseUri ?? Uri.base).resolve(trimmed).toString();
}

extension _BlankStringExtension on String {
  String ifBlank(String fallback) {
    return trim().isEmpty ? fallback : trim();
  }
}
