import 'package:flutter/foundation.dart';

/// Network type reported to the hot-update policy service.
enum HotUpdateNetworkType {
  wifi,
  cellular,
  ethernet,
  offline,
  unknown;

  /// Parses a backend or app-provided network type.
  static HotUpdateNetworkType parse(Object? value) {
    final normalized = value?.toString().trim().toLowerCase();
    switch (normalized) {
      case 'wifi':
      case 'wi-fi':
        return HotUpdateNetworkType.wifi;
      case 'cellular':
      case 'mobile':
      case '4g':
      case '5g':
        return HotUpdateNetworkType.cellular;
      case 'ethernet':
      case 'lan':
        return HotUpdateNetworkType.ethernet;
      case 'offline':
      case 'none':
        return HotUpdateNetworkType.offline;
      default:
        return HotUpdateNetworkType.unknown;
    }
  }

  /// The value sent to the policy service.
  String get wireName => name;
}

/// Download source selected by the hot-update service.
enum HotUpdateDownloadSource {
  cnCdn,
  globalCdn,
  official,
  cache,
  unknown;

  /// Parses a download source returned by the policy service.
  static HotUpdateDownloadSource parse(Object? value) {
    final normalized = value?.toString().trim().toLowerCase();
    switch (normalized) {
      case 'cn':
      case 'cn_cdn':
      case 'china_cdn':
      case 'domestic':
        return HotUpdateDownloadSource.cnCdn;
      case 'global':
      case 'global_cdn':
      case 'oversea':
      case 'overseas':
        return HotUpdateDownloadSource.globalCdn;
      case 'official':
      case 'shorebird':
        return HotUpdateDownloadSource.official;
      case 'cache':
      case 'cached':
        return HotUpdateDownloadSource.cache;
      default:
        return HotUpdateDownloadSource.unknown;
    }
  }

  /// The value used in telemetry logs.
  String get wireName {
    switch (this) {
      case HotUpdateDownloadSource.cnCdn:
        return 'cn_cdn';
      case HotUpdateDownloadSource.globalCdn:
        return 'global_cdn';
      case HotUpdateDownloadSource.official:
        return 'official';
      case HotUpdateDownloadSource.cache:
        return 'cache';
      case HotUpdateDownloadSource.unknown:
        return 'unknown';
    }
  }
}

/// Indicates where a hot-update policy came from.
enum HotUpdatePolicySource { remote, fallback }

/// Result status for one hot-update check.
enum HotUpdateRunStatus {
  skipped,
  unavailable,
  upToDate,
  restartRequired,
  downloaded,
  failed,
}

/// Reason why a hot-update check was skipped or unavailable.
enum HotUpdateSkipReason {
  none,
  unsupportedPlatform,
  updaterUnavailable,
  checkInProgress,
  policyDisabled,
  checkDisabled,
  downloadDisabled,
  wifiOnly,
}

/// Context sent to the policy service before a Shorebird update check.
@immutable
class HotUpdateRequestContext {
  const HotUpdateRequestContext({
    required this.releaseVersion,
    required this.deviceId,
    this.channel = 'stable',
    this.platform = 'android',
    this.appId,
    this.patchNumber,
    this.networkType = HotUpdateNetworkType.unknown,
    this.extra = const <String, String>{},
  });

  /// The release version, for example `1.0.1+1`.
  final String releaseVersion;

  /// The Shorebird track or product channel.
  final String channel;

  /// The target platform. This module is intended for Android.
  final String platform;

  /// Optional Shorebird app id.
  final String? appId;

  /// Stable installation id used for rollout bucketing.
  final String deviceId;

  /// Currently installed Shorebird patch number.
  final int? patchNumber;

  /// Current network type if the caller knows it.
  final HotUpdateNetworkType networkType;

  /// Extra query fields reserved for later rollout dimensions.
  final Map<String, String> extra;

  /// Returns a copy with selected fields changed.
  HotUpdateRequestContext copyWith({
    String? releaseVersion,
    String? channel,
    String? platform,
    String? appId,
    String? deviceId,
    int? patchNumber,
    HotUpdateNetworkType? networkType,
    Map<String, String>? extra,
  }) {
    return HotUpdateRequestContext(
      releaseVersion: releaseVersion ?? this.releaseVersion,
      channel: channel ?? this.channel,
      platform: platform ?? this.platform,
      appId: appId ?? this.appId,
      deviceId: deviceId ?? this.deviceId,
      patchNumber: patchNumber ?? this.patchNumber,
      networkType: networkType ?? this.networkType,
      extra: extra ?? this.extra,
    );
  }

  /// Converts the context to query parameters for a policy request.
  Map<String, String> toQueryParameters() {
    final params = <String, String>{
      'release_version': releaseVersion,
      'channel': channel,
      'platform': platform,
      'device_id': deviceId,
      'network_type': networkType.wireName,
      ...extra,
    };
    final currentAppId = appId;
    if (currentAppId != null && currentAppId.isNotEmpty) {
      params['app_id'] = currentAppId;
    }
    final currentPatchNumber = patchNumber;
    if (currentPatchNumber != null) {
      params['patch_number'] = currentPatchNumber.toString();
    }
    return params;
  }
}

/// Policy returned by the update service before calling Shorebird.
@immutable
class HotUpdatePolicy {
  const HotUpdatePolicy({
    required this.enabled,
    required this.allowCheck,
    required this.allowDownload,
    required this.wifiOnly,
    required this.track,
    required this.rolloutPercent,
    required this.source,
    this.preferredSource = HotUpdateDownloadSource.unknown,
    this.message,
    this.reason,
    this.extra = const <String, Object?>{},
  });

  /// Allows checks and downloads when the policy service is unavailable.
  factory HotUpdatePolicy.allowAll({
    String track = 'stable',
    String? reason,
    HotUpdatePolicySource source = HotUpdatePolicySource.fallback,
  }) {
    return HotUpdatePolicy(
      enabled: true,
      allowCheck: true,
      allowDownload: true,
      wifiOnly: false,
      track: track,
      rolloutPercent: 100,
      source: source,
      reason: reason,
    );
  }

  /// Creates a disabled policy with a human-readable reason.
  factory HotUpdatePolicy.disabled(String reason) {
    return HotUpdatePolicy(
      enabled: false,
      allowCheck: false,
      allowDownload: false,
      wifiOnly: false,
      track: 'stable',
      rolloutPercent: 0,
      source: HotUpdatePolicySource.remote,
      reason: reason,
    );
  }

  /// Parses flexible backend JSON into a policy.
  factory HotUpdatePolicy.fromJson(Map<String, dynamic> json) {
    final payload = _extractPayload(json);
    final enabled = _readBool(payload, const [
      'enabled',
      'hot_update_enabled',
      'hotUpdateEnabled',
    ], fallback: true);
    final allowCheck = _readBool(payload, const [
      'allow_check',
      'allowCheck',
      'check_enabled',
      'checkEnabled',
    ], fallback: enabled);
    final allowDownload = _readBool(payload, const [
      'allow_download',
      'allowDownload',
      'download_enabled',
      'downloadEnabled',
    ], fallback: enabled);
    final wifiOnly = _readBool(payload, const [
      'wifi_only',
      'wifiOnly',
      'only_wifi',
      'onlyWifi',
    ], fallback: false);
    final track = _readString(payload, const ['track', 'channel']) ?? 'stable';
    final rollout = _readInt(payload, const [
      'rollout_percent',
      'rolloutPercent',
      'gray_percent',
    ], fallback: 100);

    return HotUpdatePolicy(
      enabled: enabled,
      allowCheck: allowCheck,
      allowDownload: allowDownload,
      wifiOnly: wifiOnly,
      track: track,
      rolloutPercent: rollout.clamp(0, 100),
      source: HotUpdatePolicySource.remote,
      preferredSource: HotUpdateDownloadSource.parse(
        _readString(payload, const ['download_source', 'downloadSource']),
      ),
      message: _readString(payload, const ['message', 'title']),
      reason: _readString(payload, const ['reason', 'pause_reason']),
      extra: Map<String, Object?>.from(payload),
    );
  }

  /// Whether hot update is enabled for the current request.
  final bool enabled;

  /// Whether the app should call Shorebird `checkForUpdate`.
  final bool allowCheck;

  /// Whether the app should download the patch when one is available.
  final bool allowDownload;

  /// Whether downloads should wait for Wi-Fi.
  final bool wifiOnly;

  /// Shorebird track to check, such as `stable` or `beta`.
  final String track;

  /// Rollout percent selected by the service.
  final int rolloutPercent;

  /// Download source expected for this policy.
  final HotUpdateDownloadSource preferredSource;

  /// Optional message for future UI.
  final String? message;

  /// Optional reason when a policy pauses updates.
  final String? reason;

  /// Whether the policy came from the server or fallback behavior.
  final HotUpdatePolicySource source;

  /// Raw policy payload kept for telemetry and debugging.
  final Map<String, Object?> extra;

  /// Returns a copy with selected fields changed.
  HotUpdatePolicy copyWith({
    bool? enabled,
    bool? allowCheck,
    bool? allowDownload,
    bool? wifiOnly,
    String? track,
    int? rolloutPercent,
    HotUpdateDownloadSource? preferredSource,
    String? message,
    String? reason,
    HotUpdatePolicySource? source,
    Map<String, Object?>? extra,
  }) {
    return HotUpdatePolicy(
      enabled: enabled ?? this.enabled,
      allowCheck: allowCheck ?? this.allowCheck,
      allowDownload: allowDownload ?? this.allowDownload,
      wifiOnly: wifiOnly ?? this.wifiOnly,
      track: track ?? this.track,
      rolloutPercent: rolloutPercent ?? this.rolloutPercent,
      preferredSource: preferredSource ?? this.preferredSource,
      message: message ?? this.message,
      reason: reason ?? this.reason,
      source: source ?? this.source,
      extra: extra ?? this.extra,
    );
  }
}

/// Outcome of a multi-source hot-update check.
@immutable
class HotUpdateRunResult {
  const HotUpdateRunResult({
    required this.status,
    required this.context,
    required this.duration,
    this.skipReason = HotUpdateSkipReason.none,
    this.policy,
    this.currentPatchNumber,
    this.nextPatchNumber,
    this.track,
    this.downloadSource = HotUpdateDownloadSource.unknown,
    this.message,
    this.error,
  });

  /// The final status.
  final HotUpdateRunStatus status;

  /// Request context used for the run.
  final HotUpdateRequestContext context;

  /// Skip reason when status is skipped or unavailable.
  final HotUpdateSkipReason skipReason;

  /// Policy used for this run.
  final HotUpdatePolicy? policy;

  /// Patch number active before this run.
  final int? currentPatchNumber;

  /// Patch number prepared for next cold start.
  final int? nextPatchNumber;

  /// Track used for Shorebird.
  final String? track;

  /// Download source selected by the update service.
  final HotUpdateDownloadSource downloadSource;

  /// Short human-readable message.
  final String? message;

  /// Error text when the run failed.
  final String? error;

  /// Time spent on this run.
  final Duration duration;

  /// Whether the app should ask the user to fully reopen it.
  bool get needsRestart {
    return status == HotUpdateRunStatus.restartRequired ||
        status == HotUpdateRunStatus.downloaded;
  }
}

Map<String, dynamic> _extractPayload(Map<String, dynamic> json) {
  for (final key in const ['data', 'datas', 'result']) {
    final value = json[key];
    if (value is Map) {
      return value.map((key, value) => MapEntry(key.toString(), value));
    }
  }
  return json;
}

bool _readBool(
  Map<String, dynamic> map,
  List<String> keys, {
  required bool fallback,
}) {
  for (final key in keys) {
    final value = map[key];
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    final normalized = value?.toString().trim().toLowerCase();
    if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
      return true;
    }
    if (normalized == 'false' || normalized == '0' || normalized == 'no') {
      return false;
    }
  }
  return fallback;
}

int _readInt(
  Map<String, dynamic> map,
  List<String> keys, {
  required int fallback,
}) {
  for (final key in keys) {
    final value = map[key];
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    final parsed = int.tryParse(value?.toString() ?? '');
    if (parsed != null) {
      return parsed;
    }
  }
  return fallback;
}

String? _readString(Map<String, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final value = map[key]?.toString().trim();
    if (value != null && value.isNotEmpty) {
      return value;
    }
  }
  return null;
}
