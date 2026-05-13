import 'package:flutter/foundation.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';
import 'package:tronskins_app/common/hot_update/hot_update_models.dart';
import 'package:tronskins_app/common/hot_update/hot_update_policy_client.dart';
import 'package:tronskins_app/common/hot_update/hot_update_telemetry.dart';

/// Dormant coordinator for the future multi-source Shorebird update flow.
class MultiSourceHotUpdateCoordinator {
  MultiSourceHotUpdateCoordinator({
    ShorebirdUpdater? updater,
    HotUpdatePolicyClient? policyClient,
    HotUpdateTelemetrySink telemetry = const AppLoggerHotUpdateTelemetrySink(),
  }) : _updater = updater ?? ShorebirdUpdater(),
       _policyClient = policyClient ?? HotUpdatePolicyClient(),
       _telemetry = telemetry;

  final ShorebirdUpdater _updater;
  final HotUpdatePolicyClient _policyClient;
  final HotUpdateTelemetrySink _telemetry;

  bool _isRunning = false;

  /// Checks policy, then checks and downloads a Shorebird patch if allowed.
  Future<HotUpdateRunResult> checkAndDownload({
    required HotUpdateRequestContext context,
    bool force = false,
  }) async {
    final startedAt = DateTime.now();

    if (!_isAndroidContext(context)) {
      return _finish(
        HotUpdateRunResult(
          status: HotUpdateRunStatus.skipped,
          context: context,
          skipReason: HotUpdateSkipReason.unsupportedPlatform,
          message: 'unsupported_platform',
          duration: DateTime.now().difference(startedAt),
        ),
      );
    }

    if (_isRunning) {
      return _finish(
        HotUpdateRunResult(
          status: HotUpdateRunStatus.skipped,
          context: context,
          skipReason: HotUpdateSkipReason.checkInProgress,
          message: 'check_in_progress',
          duration: DateTime.now().difference(startedAt),
        ),
      );
    }

    _isRunning = true;
    _telemetry.checkStarted(context);

    try {
      if (!_updater.isAvailable) {
        return _finish(
          HotUpdateRunResult(
            status: HotUpdateRunStatus.unavailable,
            context: context,
            skipReason: HotUpdateSkipReason.updaterUnavailable,
            message: 'shorebird_unavailable',
            duration: DateTime.now().difference(startedAt),
          ),
        );
      }

      final currentPatchNumber = await _readCurrentPatchNumber();
      final currentContext = context.copyWith(patchNumber: currentPatchNumber);
      final policy = await _policyClient.fetchPolicy(currentContext);
      final blockedResult = _blockedByPolicy(
        context: currentContext,
        policy: policy,
        force: force,
        startedAt: startedAt,
        currentPatchNumber: currentPatchNumber,
      );
      if (blockedResult != null) {
        return _finish(blockedResult);
      }

      final trackName = policy.track.trim().isEmpty
          ? currentContext.channel
          : policy.track.trim();
      final track = UpdateTrack(trackName);
      final status = await _updater.checkForUpdate(track: track);

      switch (status) {
        case UpdateStatus.outdated:
          return await _downloadPatch(
            context: currentContext,
            policy: policy,
            track: track,
            trackName: trackName,
            startedAt: startedAt,
            currentPatchNumber: currentPatchNumber,
          );
        case UpdateStatus.restartRequired:
          return _finish(
            HotUpdateRunResult(
              status: HotUpdateRunStatus.restartRequired,
              context: currentContext,
              policy: policy,
              currentPatchNumber: currentPatchNumber,
              nextPatchNumber: await _readNextPatchNumber(),
              track: trackName,
              downloadSource: policy.preferredSource,
              message: 'restart_required',
              duration: DateTime.now().difference(startedAt),
            ),
          );
        case UpdateStatus.upToDate:
          return _finish(
            HotUpdateRunResult(
              status: HotUpdateRunStatus.upToDate,
              context: currentContext,
              policy: policy,
              currentPatchNumber: currentPatchNumber,
              track: trackName,
              downloadSource: policy.preferredSource,
              message: 'up_to_date',
              duration: DateTime.now().difference(startedAt),
            ),
          );
        case UpdateStatus.unavailable:
          return _finish(
            HotUpdateRunResult(
              status: HotUpdateRunStatus.unavailable,
              context: currentContext,
              policy: policy,
              currentPatchNumber: currentPatchNumber,
              skipReason: HotUpdateSkipReason.updaterUnavailable,
              track: trackName,
              message: 'shorebird_unavailable',
              duration: DateTime.now().difference(startedAt),
            ),
          );
      }
    } catch (error, stackTrace) {
      _telemetry.checkFailed(context, error, stackTrace);
      return _finish(
        HotUpdateRunResult(
          status: HotUpdateRunStatus.failed,
          context: context,
          message: 'hot_update_failed',
          error: error.toString(),
          duration: DateTime.now().difference(startedAt),
        ),
      );
    } finally {
      _isRunning = false;
    }
  }

  bool _isAndroidContext(HotUpdateRequestContext context) {
    return !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android &&
        context.platform.toLowerCase() == 'android';
  }

  HotUpdateRunResult? _blockedByPolicy({
    required HotUpdateRequestContext context,
    required HotUpdatePolicy policy,
    required bool force,
    required DateTime startedAt,
    required int? currentPatchNumber,
  }) {
    if (!policy.enabled) {
      return _skippedByPolicy(
        context: context,
        policy: policy,
        reason: HotUpdateSkipReason.policyDisabled,
        message: policy.reason ?? 'policy_disabled',
        startedAt: startedAt,
        currentPatchNumber: currentPatchNumber,
      );
    }
    if (!policy.allowCheck) {
      return _skippedByPolicy(
        context: context,
        policy: policy,
        reason: HotUpdateSkipReason.checkDisabled,
        message: policy.reason ?? 'check_disabled',
        startedAt: startedAt,
        currentPatchNumber: currentPatchNumber,
      );
    }
    if (!force &&
        policy.wifiOnly &&
        context.networkType != HotUpdateNetworkType.wifi) {
      return _skippedByPolicy(
        context: context,
        policy: policy,
        reason: HotUpdateSkipReason.wifiOnly,
        message: 'wifi_required',
        startedAt: startedAt,
        currentPatchNumber: currentPatchNumber,
      );
    }
    return null;
  }

  HotUpdateRunResult _skippedByPolicy({
    required HotUpdateRequestContext context,
    required HotUpdatePolicy policy,
    required HotUpdateSkipReason reason,
    required String message,
    required DateTime startedAt,
    required int? currentPatchNumber,
  }) {
    return HotUpdateRunResult(
      status: HotUpdateRunStatus.skipped,
      context: context,
      skipReason: reason,
      policy: policy,
      currentPatchNumber: currentPatchNumber,
      track: policy.track,
      downloadSource: policy.preferredSource,
      message: message,
      duration: DateTime.now().difference(startedAt),
    );
  }

  Future<HotUpdateRunResult> _downloadPatch({
    required HotUpdateRequestContext context,
    required HotUpdatePolicy policy,
    required UpdateTrack track,
    required String trackName,
    required DateTime startedAt,
    required int? currentPatchNumber,
  }) async {
    if (!policy.allowDownload) {
      return _finish(
        HotUpdateRunResult(
          status: HotUpdateRunStatus.skipped,
          context: context,
          skipReason: HotUpdateSkipReason.downloadDisabled,
          policy: policy,
          currentPatchNumber: currentPatchNumber,
          track: trackName,
          downloadSource: policy.preferredSource,
          message: policy.reason ?? 'download_disabled',
          duration: DateTime.now().difference(startedAt),
        ),
      );
    }

    await _updater.update(track: track);
    final nextPatchNumber = await _readNextPatchNumber();
    return _finish(
      HotUpdateRunResult(
        status: HotUpdateRunStatus.downloaded,
        context: context,
        policy: policy,
        currentPatchNumber: currentPatchNumber,
        nextPatchNumber: nextPatchNumber,
        track: trackName,
        downloadSource: policy.preferredSource,
        message: 'patch_downloaded',
        duration: DateTime.now().difference(startedAt),
      ),
    );
  }

  Future<int?> _readCurrentPatchNumber() async {
    try {
      return (await _updater.readCurrentPatch())?.number;
    } catch (_) {
      return null;
    }
  }

  Future<int?> _readNextPatchNumber() async {
    try {
      return (await _updater.readNextPatch())?.number;
    } catch (_) {
      return null;
    }
  }

  HotUpdateRunResult _finish(HotUpdateRunResult result) {
    _telemetry.checkFinished(result);
    return result;
  }
}
