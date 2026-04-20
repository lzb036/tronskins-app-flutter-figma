import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:tronskins_app/common/logging/app_logger.dart';

class LoggingInterceptor extends Interceptor {
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
    return '${options.method.toUpperCase()} ${options.uri}';
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
