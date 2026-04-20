import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

class ServerStorageItem {
  const ServerStorageItem({required this.name, required this.url});

  final String name;
  final String url;

  Map<String, String> toJson() {
    return {'name': name, 'url': url};
  }
}

class ServerStorage {
  ServerStorage._();

  //static const String defaultServer = 'https://www.etopmarket.com/'
  static const String defaultServer = 'https://www.tronskins.com/';
  static const String defaultServerName = 'Official website';
  static const String _serverKey = 'es_server';
  static const String _serverListKey = 'es_server_list';
  static final GetStorage _box = GetStorage();
  static final RxInt _changeToken = 0.obs;

  static RxInt get changeToken => _changeToken;

  static String getServer() {
    final raw = _box.read<String>(_serverKey);
    if (raw == null || raw.isEmpty) {
      return defaultServer;
    }
    return _normalize(raw);
  }

  static void setServer(String server) {
    _box.write(_serverKey, _normalize(server));
    _changeToken.value++;
  }

  static List<ServerStorageItem> getServerItems() {
    final raw = _box.read<List<dynamic>>(_serverListKey);
    final currentServer = getServer();
    final result = <ServerStorageItem>[];
    final seenUrls = <String>{};

    void addItem({required String url, String? name}) {
      final normalizedUrl = _normalize(url);
      if (seenUrls.contains(normalizedUrl)) {
        return;
      }
      seenUrls.add(normalizedUrl);
      result.add(
        ServerStorageItem(
          name: _normalizeName(name, normalizedUrl),
          url: normalizedUrl,
        ),
      );
    }

    if (raw == null || raw.isEmpty) {
      addItem(url: defaultServer, name: null);
    } else {
      for (final item in raw) {
        if (item is Map) {
          final normalizedMap = item.map(
            (key, value) => MapEntry(key.toString(), value?.toString() ?? ''),
          );
          final url =
              normalizedMap['url'] ??
              normalizedMap['server'] ??
              normalizedMap['path'] ??
              normalizedMap['value'] ??
              '';
          if (url.trim().isEmpty) {
            continue;
          }
          addItem(url: url, name: normalizedMap['name']);
          continue;
        }
        final value = item?.toString() ?? '';
        if (value.trim().isEmpty) {
          continue;
        }
        addItem(url: value, name: null);
      }
    }

    if (!seenUrls.contains(currentServer)) {
      addItem(url: currentServer, name: null);
    }

    if (result.isEmpty) {
      addItem(url: defaultServer, name: null);
    }
    return result;
  }

  static void setServerItems(List<ServerStorageItem> list) {
    final normalized = <ServerStorageItem>[];
    final seenUrls = <String>{};
    for (final item in list) {
      final normalizedUrl = _normalize(item.url);
      if (seenUrls.contains(normalizedUrl)) {
        continue;
      }
      seenUrls.add(normalizedUrl);
      normalized.add(
        ServerStorageItem(
          name: _normalizeName(item.name, normalizedUrl),
          url: normalizedUrl,
        ),
      );
    }
    if (normalized.isEmpty) {
      normalized.add(
        const ServerStorageItem(name: defaultServerName, url: defaultServer),
      );
    }
    _box.write(
      _serverListKey,
      normalized.map((item) => item.toJson()).toList(),
    );
    _changeToken.value++;
  }

  static List<String> getServerList() {
    return getServerItems().map((item) => item.url).toList();
  }

  static String getCurrentServerName() {
    final currentServer = getServer();
    final items = getServerItems();
    for (final item in items) {
      if (item.url == currentServer) {
        return item.name;
      }
    }
    return _deriveNameFromUrl(currentServer);
  }

  static void setServerList(List<String> list) {
    setServerItems(
      list
          .map(
            (url) => ServerStorageItem(
              name: _deriveNameFromUrl(url),
              url: _normalize(url),
            ),
          )
          .toList(),
    );
  }

  static String _normalize(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return defaultServer;
    return trimmed.endsWith('/') ? trimmed : '$trimmed/';
  }

  static String _normalizeName(String? value, String url) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isNotEmpty) {
      return trimmed;
    }
    return _deriveNameFromUrl(url);
  }

  static String _deriveNameFromUrl(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return defaultServerName;
    }
    final candidate = trimmed.contains('://') ? trimmed : 'https://$trimmed';
    final normalizedCandidate = _normalize(candidate);
    if (normalizedCandidate == defaultServer) {
      return defaultServerName;
    }
    final uri = Uri.tryParse(candidate);
    if (uri != null && uri.host.isNotEmpty) {
      return uri.host;
    }
    return trimmed.replaceFirst(RegExp(r'^https?://'), '').replaceAll('/', '');
  }
}
