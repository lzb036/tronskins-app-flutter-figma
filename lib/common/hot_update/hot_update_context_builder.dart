import 'package:tronskins_app/common/device/device_id_helper.dart';
import 'package:tronskins_app/common/hot_update/hot_update_models.dart';
import 'package:tronskins_app/common/utils/app_version.dart';

/// Builds request context for the dormant multi-source hot-update flow.
class HotUpdateContextBuilder {
  const HotUpdateContextBuilder();

  /// Loads app version and stable install id from existing project helpers.
  Future<HotUpdateRequestContext> build({
    String channel = 'stable',
    String platform = 'android',
    String? appId,
    HotUpdateNetworkType networkType = HotUpdateNetworkType.unknown,
    Map<String, String> extra = const <String, String>{},
  }) async {
    final version = await AppVersion.baseVersion();
    return HotUpdateRequestContext(
      releaseVersion: _normalizeVersion(version),
      channel: channel,
      platform: platform,
      appId: appId,
      deviceId: DeviceIdHelper.getUdid(),
      networkType: networkType,
      extra: extra,
    );
  }
}

String _normalizeVersion(String version) {
  final trimmed = version.trim();
  if (trimmed.startsWith('v') || trimmed.startsWith('V')) {
    return trimmed.substring(1);
  }
  return trimmed;
}
