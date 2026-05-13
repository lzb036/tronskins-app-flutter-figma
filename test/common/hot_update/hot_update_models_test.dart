import 'package:flutter_test/flutter_test.dart';
import 'package:tronskins_app/common/hot_update/hot_update_models.dart';

void main() {
  group('HotUpdatePolicy', () {
    test('parses wrapped backend payload', () {
      final policy = HotUpdatePolicy.fromJson({
        'code': 0,
        'data': {
          'enabled': true,
          'allow_download': false,
          'wifi_only': true,
          'track': 'beta',
          'rollout_percent': 20,
          'download_source': 'cn_cdn',
        },
      });

      expect(policy.enabled, isTrue);
      expect(policy.allowCheck, isTrue);
      expect(policy.allowDownload, isFalse);
      expect(policy.wifiOnly, isTrue);
      expect(policy.track, 'beta');
      expect(policy.rolloutPercent, 20);
      expect(policy.preferredSource, HotUpdateDownloadSource.cnCdn);
      expect(policy.source, HotUpdatePolicySource.remote);
    });

    test('clamps rollout percent', () {
      final policy = HotUpdatePolicy.fromJson({
        'enabled': true,
        'rollout_percent': 180,
      });

      expect(policy.rolloutPercent, 100);
    });
  });

  group('HotUpdateRequestContext', () {
    test('builds policy query parameters', () {
      const context = HotUpdateRequestContext(
        releaseVersion: '1.0.1+1',
        appId: 'app-id',
        deviceId: 'device-id',
        channel: 'stable',
        patchNumber: 3,
        networkType: HotUpdateNetworkType.wifi,
        extra: {'flavor': 'domestic'},
      );

      expect(context.toQueryParameters(), {
        'release_version': '1.0.1+1',
        'channel': 'stable',
        'platform': 'android',
        'device_id': 'device-id',
        'network_type': 'wifi',
        'flavor': 'domestic',
        'app_id': 'app-id',
        'patch_number': '3',
      });
    });
  });
}
