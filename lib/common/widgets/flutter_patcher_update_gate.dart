import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_patcher/flutter_patcher.dart';
import 'package:get/get.dart';
import 'package:tronskins_app/common/device/device_id_helper.dart';
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
  static const String _checkPath = 'api/public/app/flutter-patcher/check';
  static const Duration _resumeCheckThrottle = Duration(minutes: 10);
  static const Duration _checkTimeout = Duration(seconds: 8);
  static const Duration _restartNoticeDelay = Duration(milliseconds: 600);

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
      final checkUrl = await _buildCheckUrl();
      AppLogger.info(
        'FLUTTER_PATCHER',
        'Checking update from $checkUrl',
        scope: 'CHECK',
      );

      final result = await FlutterPatcher.checkUpdate(
        checkUrl,
        timeout: _checkTimeout,
      );
      final patch = result.patch;
      if (!mounted || !result.hasUpdate || patch == null) {
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

  Future<String> _buildCheckUrl() async {
    final baseUri = Uri.parse(ServerStorage.getServer());
    final endpoint = baseUri.resolve(_checkPath);
    final versionCode = await FlutterPatcher.appVersionCode;
    final deviceAbi = await FlutterPatcher.deviceAbi;
    final currentPatch = await FlutterPatcher.currentVersion;
    final baseVersion = await AppVersion.baseVersion();

    return endpoint
        .replace(
          queryParameters: <String, String>{
            'platform': 'android',
            'app_version': _normalizeVersion(baseVersion),
            if (versionCode != null) 'version_code': versionCode.toString(),
            if (deviceAbi.isNotEmpty) 'abi': deviceAbi,
            if (currentPatch != null && currentPatch.isNotEmpty)
              'current_patch': currentPatch,
            'device_id': DeviceIdHelper.getUdid(),
          },
        )
        .toString();
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
        _showRestartNotice();
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

String _normalizeVersion(String version) {
  final trimmed = version.trim();
  if (trimmed.startsWith('v') || trimmed.startsWith('V')) {
    return trimmed.substring(1);
  }
  return trimmed;
}
