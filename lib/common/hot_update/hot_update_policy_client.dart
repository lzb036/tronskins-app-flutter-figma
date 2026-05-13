import 'package:dio/dio.dart';
import 'package:tronskins_app/common/hot_update/hot_update_models.dart';
import 'package:tronskins_app/common/logging/app_logger.dart';

/// Fetches the server-side policy before Shorebird checks for patches.
class HotUpdatePolicyClient {
  HotUpdatePolicyClient({
    Dio? dio,
    this.endpoint,
    this.timeout = const Duration(seconds: 5),
  }) : _dio =
           dio ??
           Dio(
             BaseOptions(
               connectTimeout: timeout,
               receiveTimeout: timeout,
               responseType: ResponseType.json,
               contentType: Headers.jsonContentType,
             ),
           );

  /// Builds a policy client from an update-service base URL.
  factory HotUpdatePolicyClient.fromBaseUrl(
    String baseUrl, {
    String path = '/app/update-policy',
    Duration timeout = const Duration(seconds: 5),
    Dio? dio,
  }) {
    final baseUri = Uri.parse(baseUrl);
    final resolvedPath = path.startsWith('/') ? path.substring(1) : path;
    return HotUpdatePolicyClient(
      dio: dio,
      endpoint: baseUri.resolve(resolvedPath),
      timeout: timeout,
    );
  }

  final Dio _dio;

  /// Full endpoint used to fetch policy. Null means allow-all fallback.
  final Uri? endpoint;

  /// Request timeout for policy checks.
  final Duration timeout;

  /// Fetches policy. Network failure falls back to allow-all behavior.
  Future<HotUpdatePolicy> fetchPolicy(HotUpdateRequestContext context) async {
    final target = endpoint;
    if (target == null) {
      return HotUpdatePolicy.allowAll(
        track: context.channel,
        reason: 'policy_endpoint_not_configured',
      );
    }

    try {
      final response = await _dio.getUri<Object?>(
        _withQuery(target, context.toQueryParameters()),
        options: Options(
          receiveTimeout: timeout,
          sendTimeout: timeout,
          headers: const {'X-TronSkins-Client': 'flutter-hot-update'},
        ),
      );
      final map = _asMap(response.data);
      if (map == null) {
        throw const FormatException('Policy response is not a JSON object.');
      }
      return HotUpdatePolicy.fromJson(map);
    } catch (error, stackTrace) {
      AppLogger.warn(
        'HOT_UPDATE',
        'Policy request failed; continuing with fallback policy.',
        scope: 'POLICY',
        error: error,
        stackTrace: stackTrace,
      );
      return HotUpdatePolicy.allowAll(
        track: context.channel,
        reason: 'policy_request_failed',
      );
    }
  }
}

Uri _withQuery(Uri uri, Map<String, String> params) {
  return uri.replace(queryParameters: {...uri.queryParameters, ...params});
}

Map<String, dynamic>? _asMap(Object? value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, value) => MapEntry(key.toString(), value));
  }
  return null;
}
