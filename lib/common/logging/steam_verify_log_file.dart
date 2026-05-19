import 'dart:async';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

class SteamVerifyLogFile {
  SteamVerifyLogFile._();

  static File? _cachedFile;
  static Future<File>? _pendingFile;
  static Future<void> _writeQueue = Future<void>.value();

  static Future<File> getFile() {
    final cached = _cachedFile;
    if (cached != null) {
      return Future<File>.value(cached);
    }
    final pending = _pendingFile;
    if (pending != null) {
      return pending;
    }

    final future = _resolveFile();
    _pendingFile = future;
    future.whenComplete(() {
      if (identical(_pendingFile, future)) {
        _pendingFile = null;
      }
    });
    return future;
  }

  static Future<File> _resolveFile() async {
    final directory =
        await getExternalStorageDirectory() ??
        await getApplicationSupportDirectory();
    final logsDirectory = Directory('${directory.path}/logs');
    if (!await logsDirectory.exists()) {
      await logsDirectory.create(recursive: true);
    }
    final file = File('${logsDirectory.path}/steam_verify.log');
    _cachedFile = file;
    return file;
  }

  static Future<void> reset() {
    _writeQueue = _writeQueue.then((_) async {
      final file = await getFile();
      await file.writeAsString('', flush: true);
    });
    return _writeQueue;
  }

  static Future<void> appendLine(String line) {
    _writeQueue = _writeQueue.then((_) async {
      final file = await getFile();
      await file.writeAsString('$line\n', mode: FileMode.append, flush: true);
    });
    return _writeQueue;
  }
}
