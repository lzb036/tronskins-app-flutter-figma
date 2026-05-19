import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:tronskins_app/common/logging/app_logger.dart';

class LoggingInterceptor extends Interceptor {
  static const String _requestStartedAtKey = 'request_started_at_ms';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra[_requestStartedAtKey] = DateTime.now().millisecondsSinceEpoch;
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final requestTag = _requestTag(response.requestOptions);
    final successful = _isSuccessfulResponse(response);
    final statusCode = response.statusCode?.toString() ?? '-';

    if (successful) {
      AppLogger.success('HTTP', '$statusCode $requestTag');
    } else {
      AppLogger.errorLog('HTTP', '$statusCode $requestTag');
    }

    if (!successful) {
      AppLogger.errorLog('HTTP', _stringify(response.data), scope: 'RESULT');
    }

    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final requestTag = _requestTag(err.requestOptions);
    final result =
        err.response?.data ??
        <String, dynamic>{
          'type': err.type.name,
          'message': err.message,
          'error': err.error?.toString(),
        };
    final statusCode = err.response?.statusCode?.toString() ?? err.type.name;

    AppLogger.errorLog('HTTP', '$statusCode $requestTag');
    AppLogger.errorLog('HTTP', _stringify(result), scope: 'RESULT');

    handler.next(err);
  }

  bool _isSuccessfulResponse(Response response) {
    final businessCode = _extractBusinessCode(response.data);
    if (businessCode != null) {
      return businessCode == 0 || businessCode == 200;
    }

    final statusCode = response.statusCode ?? 0;
    return statusCode >= 200 && statusCode < 300;
  }

  int? _extractBusinessCode(dynamic data) {
    if (data is Map<String, dynamic>) {
      final code = data['code'];
      if (code is int) {
        return code;
      }
      if (code is num) {
        return code.toInt();
      }
      if (code is String) {
        return int.tryParse(code.trim());
      }
    }
    return null;
  }

  String _requestTag(RequestOptions options) {
    final label = options.extra['request_label']?.toString().trim();
    final durationMs = _requestDurationMs(options);
    final labelPrefix = label != null && label.isNotEmpty ? '[$label] ' : '';
    final durationSuffix = durationMs == null ? '' : ' (${durationMs}ms)';
    return '$labelPrefix${options.method.toUpperCase()} ${options.uri}'
        '$durationSuffix';
  }

  int? _requestDurationMs(RequestOptions options) {
    final startedAt = options.extra[_requestStartedAtKey];
    final startedMs = startedAt is int
        ? startedAt
        : int.tryParse(startedAt?.toString() ?? '');
    if (startedMs == null) {
      return null;
    }
    return DateTime.now().millisecondsSinceEpoch - startedMs;
  }

  String _stringify(dynamic data) {
    if (data == null) {
      return 'null';
    }
    if (data is String) {
      return data;
    }
    try {
      return const JsonEncoder.withIndent('  ').convert(data);
    } catch (_) {
      return data.toString();
    }
  }
}
