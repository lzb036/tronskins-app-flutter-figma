import 'dart:async';

import 'package:flutter/foundation.dart';

/// Formats app logs into a consistent, grep-friendly console shape.
class AppLogger {
  AppLogger._();

  static const String _defaultTag = 'APP';
  static const int _chunkSize = 900;
  static final RegExp _leadingTagPattern = RegExp(r'^\[([^\]]+)\]');
  static bool _installed = false;

  /// Installs global hooks for raw prints, framework errors, and async errors.
  static Future<void> run(Future<void> Function() bootstrap) async {
    install();

    await runZonedGuarded(
      bootstrap,
      (error, stackTrace) {
        errorLog(
          _defaultTag,
          'Unhandled async error.',
          error: error,
          stackTrace: stackTrace,
        );
      },
      zoneSpecification: ZoneSpecification(
        print: (self, parent, zone, line) {
          legacy(line);
        },
      ),
    );
  }

  /// Installs the global logger once.
  static void install() {
    if (_installed) {
      return;
    }

    _installed = true;
    debugPrint = legacy;
    FlutterError.onError = logFlutterError;
    PlatformDispatcher.instance.onError = (error, stackTrace) {
      errorLog(
        'FLUTTER',
        'Unhandled platform error.',
        error: error,
        stackTrace: stackTrace,
      );
      return true;
    };
  }

  static void legacy(String? message, {int? wrapWidth}) {
    final text = message?.trim();
    if (text == null || text.isEmpty) {
      return;
    }

    final parsed = _parseLegacyMessage(text);
    _emit(
      parsed.level,
      parsed.tag,
      parsed.message,
      scope: parsed.scope,
      wrapWidth: wrapWidth,
    );
  }

  static void debug(String tag, String message, {String? scope}) {
    _emit(AppLogLevel.debug, tag, message, scope: scope);
  }

  static void info(String tag, String message, {String? scope}) {
    _emit(AppLogLevel.info, tag, message, scope: scope);
  }

  static void success(String tag, String message, {String? scope}) {
    _emit(AppLogLevel.success, tag, message, scope: scope);
  }

  static void warn(
    String tag,
    String message, {
    String? scope,
    Object? error,
    StackTrace? stackTrace,
  }) {
    _emit(AppLogLevel.warn, tag, _composeMessage(message, error), scope: scope);
    _emitStack(
      AppLogLevel.warn,
      tag,
      stackTrace,
      scope: scope == null ? 'STACK' : '$scope/STACK',
    );
  }

  static void errorLog(
    String tag,
    String message, {
    String? scope,
    Object? error,
    StackTrace? stackTrace,
  }) {
    _emit(
      AppLogLevel.error,
      tag,
      _composeMessage(message, error),
      scope: scope,
    );
    _emitStack(
      AppLogLevel.error,
      tag,
      stackTrace,
      scope: scope == null ? 'STACK' : '$scope/STACK',
    );
  }

  static void logFlutterError(FlutterErrorDetails details) {
    final segments = <String>[
      if ((details.library ?? '').trim().isNotEmpty) details.library!.trim(),
      if (details.context != null) details.context!.toDescription(),
      details.exceptionAsString(),
    ];

    errorLog('FLUTTER', segments.join(' | '), stackTrace: details.stack);
  }

  static void _emit(
    AppLogLevel level,
    String tag,
    String message, {
    String? scope,
    int? wrapWidth,
  }) {
    final normalizedTag = _normalizeSegment(tag, fallback: _defaultTag);
    final normalizedScope = _normalizeScope(scope);
    final prefix = _buildPrefix(level, normalizedTag, normalizedScope);
    final width = wrapWidth ?? _chunkSize;

    for (final line in _normalizeLines(message)) {
      for (final chunk in _chunkLine(line, width)) {
        Zone.root.print('$prefix$chunk');
      }
    }
  }

  static void _emitStack(
    AppLogLevel level,
    String tag,
    StackTrace? stackTrace, {
    String? scope,
  }) {
    if (stackTrace == null) {
      return;
    }

    _emit(level, tag, stackTrace.toString(), scope: scope);
  }

  static String _buildPrefix(AppLogLevel level, String tag, String? scope) {
    final now = DateTime.now();
    final hh = now.hour.toString().padLeft(2, '0');
    final mm = now.minute.toString().padLeft(2, '0');
    final ss = now.second.toString().padLeft(2, '0');
    final ms = now.millisecond.toString().padLeft(3, '0');
    final channel = scope == null ? tag : '$tag/$scope';

    return '$hh:$mm:$ss.$ms | ${level.label.padRight(7)} | '
        '${channel.padRight(18)} | ';
  }

  static Iterable<String> _normalizeLines(String message) sync* {
    final normalized = message.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    for (final line in normalized.split('\n')) {
      final value = line.trimRight();
      yield value.isEmpty ? '(empty)' : value;
    }
  }

  static Iterable<String> _chunkLine(String line, int width) sync* {
    if (line.length <= width) {
      yield line;
      return;
    }

    for (var start = 0; start < line.length; start += width) {
      final end = (start + width < line.length) ? start + width : line.length;
      yield line.substring(start, end);
    }
  }

  static _LegacyLog _parseLegacyMessage(String message) {
    final tokens = <String>[];
    var rest = message;

    while (true) {
      final match = _leadingTagPattern.firstMatch(rest);
      if (match == null) {
        break;
      }

      tokens.add(match.group(1)!.trim());
      rest = rest.substring(match.end).trimLeft();
    }

    final level = _resolveLegacyLevel(tokens, rest);
    final tagTokens = <String>[];

    for (final token in tokens) {
      if (_levelFromToken(token) == null) {
        tagTokens.add(token);
      }
    }

    final tag = tagTokens.isNotEmpty
        ? _normalizeSegment(tagTokens.first, fallback: _defaultTag)
        : _defaultTag;
    final scopeTokens = tagTokens.skip(1).toList();
    final scope = scopeTokens.isEmpty
        ? null
        : scopeTokens
              .map((value) => _normalizeSegment(value, fallback: 'LOG'))
              .join('/');
    final body = rest.isNotEmpty ? rest : _fallbackLegacyBody(tokens, message);

    return _LegacyLog(level: level, tag: tag, scope: scope, message: body);
  }

  static AppLogLevel _resolveLegacyLevel(List<String> tokens, String rest) {
    for (final token in tokens.reversed) {
      final resolved = _levelFromToken(token);
      if (resolved != null) {
        return resolved;
      }
    }

    final lower = rest.toLowerCase();
    if (lower.contains('timeout') || lower.contains('retry')) {
      return AppLogLevel.warn;
    }
    if (lower.contains('failed') ||
        lower.contains('error') ||
        lower.contains('exception')) {
      return AppLogLevel.error;
    }
    if (lower.contains('success')) {
      return AppLogLevel.success;
    }
    if (lower.contains('warn')) {
      return AppLogLevel.warn;
    }
    if (lower.contains('info')) {
      return AppLogLevel.info;
    }
    return AppLogLevel.debug;
  }

  static AppLogLevel? _levelFromToken(String token) {
    switch (token.trim().toUpperCase()) {
      case 'TRACE':
        return AppLogLevel.debug;
      case 'DEBUG':
        return AppLogLevel.debug;
      case 'INFO':
        return AppLogLevel.info;
      case 'SUCCESS':
      case 'OK':
      case 'DONE':
        return AppLogLevel.success;
      case 'WARN':
      case 'WARNING':
      case 'RETRY':
      case 'TIMEOUT':
        return AppLogLevel.warn;
      case 'FAIL':
      case 'FAILED':
      case 'ERROR':
      case 'STACK':
        return AppLogLevel.error;
    }

    return null;
  }

  static String _fallbackLegacyBody(List<String> tokens, String rawMessage) {
    if (tokens.any((token) => token.trim().toUpperCase() == 'STACK')) {
      return 'stack trace follows';
    }
    return rawMessage;
  }

  static String _composeMessage(String message, Object? error) {
    if (error == null) {
      return message;
    }
    return '$message | error=$error';
  }

  static String _normalizeSegment(String value, {required String fallback}) {
    final compact = value
        .trim()
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll('/', '_');

    if (compact.isEmpty) {
      return fallback;
    }

    return compact.toUpperCase();
  }

  static String? _normalizeScope(String? scope) {
    final value = scope?.trim();
    if (value == null || value.isEmpty) {
      return null;
    }

    final pieces = value
        .split('/')
        .map((piece) => _normalizeSegment(piece, fallback: 'LOG'))
        .where((piece) => piece.isNotEmpty)
        .toList();

    return pieces.isEmpty ? null : pieces.join('/');
  }
}

enum AppLogLevel {
  debug('DEBUG'),
  info('INFO'),
  success('SUCCESS'),
  warn('WARN'),
  error('ERROR');

  const AppLogLevel(this.label);

  final String label;
}

class _LegacyLog {
  const _LegacyLog({
    required this.level,
    required this.tag,
    required this.message,
    this.scope,
  });

  final AppLogLevel level;
  final String tag;
  final String? scope;
  final String message;
}
