import 'package:tronskins_app/common/hot_update/hot_update_models.dart';
import 'package:tronskins_app/common/logging/app_logger.dart';

/// Receives hot-update telemetry without coupling the coordinator to analytics.
abstract class HotUpdateTelemetrySink {
  const HotUpdateTelemetrySink();

  /// Called before the policy and Shorebird checks begin.
  void checkStarted(HotUpdateRequestContext context);

  /// Called when a hot-update run completes.
  void checkFinished(HotUpdateRunResult result);

  /// Called when a hot-update run throws before producing a result.
  void checkFailed(
    HotUpdateRequestContext context,
    Object error,
    StackTrace stackTrace,
  );
}

/// No-op telemetry sink for tests or disabled integrations.
class NoopHotUpdateTelemetrySink implements HotUpdateTelemetrySink {
  const NoopHotUpdateTelemetrySink();

  @override
  void checkStarted(HotUpdateRequestContext context) {}

  @override
  void checkFinished(HotUpdateRunResult result) {}

  @override
  void checkFailed(
    HotUpdateRequestContext context,
    Object error,
    StackTrace stackTrace,
  ) {}
}

/// Logs hot-update telemetry through the app logger.
class AppLoggerHotUpdateTelemetrySink implements HotUpdateTelemetrySink {
  const AppLoggerHotUpdateTelemetrySink();

  @override
  void checkStarted(HotUpdateRequestContext context) {
    AppLogger.info(
      'HOT_UPDATE',
      'check_started version=${context.releaseVersion} '
          'channel=${context.channel} network=${context.networkType.wireName}',
      scope: 'RUN',
    );
  }

  @override
  void checkFinished(HotUpdateRunResult result) {
    AppLogger.info(
      'HOT_UPDATE',
      'check_finished status=${result.status.name} '
          'reason=${result.skipReason.name} '
          'track=${result.track ?? '-'} '
          'source=${result.downloadSource.wireName} '
          'current=${result.currentPatchNumber ?? '-'} '
          'next=${result.nextPatchNumber ?? '-'} '
          'duration_ms=${result.duration.inMilliseconds}',
      scope: 'RUN',
    );
  }

  @override
  void checkFailed(
    HotUpdateRequestContext context,
    Object error,
    StackTrace stackTrace,
  ) {
    AppLogger.errorLog(
      'HOT_UPDATE',
      'check_failed version=${context.releaseVersion}',
      scope: 'RUN',
      error: error,
      stackTrace: stackTrace,
    );
  }
}
