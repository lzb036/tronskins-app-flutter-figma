import 'dart:convert';

class FeedbackPager {
  final int page;
  final int pageSize;
  final int total;

  const FeedbackPager({
    required this.page,
    required this.pageSize,
    required this.total,
  });

  factory FeedbackPager.fromJson(Map<String, dynamic> json) {
    return FeedbackPager(
      page: _asInt(json['page']) ?? 1,
      pageSize: _asInt(json['pageSize']) ?? 10,
      total: _asInt(json['total']) ?? 0,
    );
  }
}

class FeedbackListResponse<T> {
  final List<T> list;
  final FeedbackPager? pager;

  const FeedbackListResponse({required this.list, this.pager});

  factory FeedbackListResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) mapper, {
    String listKey = 'list',
  }) {
    final rawList = json[listKey];
    final list = rawList is List
        ? rawList.whereType<Map<String, dynamic>>().map(mapper).toList()
        : <T>[];
    final pager = json['pager'] is Map<String, dynamic>
        ? FeedbackPager.fromJson(json['pager'] as Map<String, dynamic>)
        : null;
    return FeedbackListResponse(list: list, pager: pager);
  }
}

class FeedbackTicket {
  final String? id;
  final String? title;
  final String? context;
  final int? status;
  final String? statusName;
  final int? createTime;

  const FeedbackTicket({
    this.id,
    this.title,
    this.context,
    this.status,
    this.statusName,
    this.createTime,
  });

  factory FeedbackTicket.fromJson(Map<String, dynamic> json) {
    return FeedbackTicket(
      id: json['id']?.toString(),
      title: json['title']?.toString(),
      context: json['context']?.toString(),
      status: _asInt(json['status']),
      statusName:
          json['statusName']?.toString() ?? json['status_name']?.toString(),
      createTime: _asInt(json['createTime'] ?? json['create_time']),
    );
  }
}

class FeedbackDetail {
  final String? id;
  final String? title;
  final String? context;
  final int? status;
  final String? statusName;
  final int? createTime;
  final List<String> images;

  const FeedbackDetail({
    this.id,
    this.title,
    this.context,
    this.status,
    this.statusName,
    this.createTime,
    this.images = const [],
  });

  factory FeedbackDetail.fromJson(Map<String, dynamic> json) {
    return FeedbackDetail(
      id: json['id']?.toString(),
      title: json['title']?.toString(),
      context: json['context']?.toString(),
      status: _asInt(json['status']),
      statusName:
          json['statusName']?.toString() ?? json['status_name']?.toString(),
      createTime: _asInt(json['createTime'] ?? json['create_time']),
      images: _asStringList(
        json['images'] ??
            json['image'] ??
            json['imgs'] ??
            json['imageUrls'] ??
            json['image_urls'] ??
            json['imageList'] ??
            json['image_list'] ??
            json['attachments'] ??
            json['files'],
      ),
    );
  }
}

class FeedbackReply {
  final String? id;
  final String? context;
  final int? createTime;
  final List<String> images;
  final bool isAdmin;

  const FeedbackReply({
    this.id,
    this.context,
    this.createTime,
    required this.images,
    this.isAdmin = false,
  });

  factory FeedbackReply.fromJson(Map<String, dynamic> json) {
    return FeedbackReply(
      id: json['id']?.toString(),
      context: json['context']?.toString(),
      createTime: _asInt(json['createTime'] ?? json['create_time']),
      images: _asStringList(
        json['images'] ??
            json['image'] ??
            json['imgs'] ??
            json['imageUrls'] ??
            json['image_urls'] ??
            json['imageList'] ??
            json['image_list'] ??
            json['attachments'] ??
            json['files'],
      ),
      isAdmin: _asBool(json['is_admin'] ?? json['isAdmin']),
    );
  }
}

int? _asInt(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value.toString());
}

bool _asBool(dynamic value) {
  if (value == null) {
    return false;
  }
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value != 0;
  }
  final str = value.toString().toLowerCase();
  return str == '1' || str == 'true' || str == 'yes';
}

List<String> _asStringList(dynamic value) {
  final result = <String>[];
  final seen = <String>{};

  void addString(dynamic raw) {
    final text = raw?.toString().trim();
    if (text == null || text.isEmpty || !seen.add(text)) return;
    result.add(text);
  }

  void addValue(dynamic raw) {
    if (raw == null) return;
    if (raw is Map) {
      const keys = [
        'url',
        'path',
        'src',
        'image',
        'imageUrl',
        'image_url',
        'fileUrl',
        'file_url',
      ];
      for (final key in keys) {
        if (raw[key] != null) {
          addString(raw[key]);
          return;
        }
      }
      return;
    }
    addString(raw);
  }

  if (value is List) {
    for (final item in value) {
      addValue(item);
    }
    return result;
  }

  if (value is String) {
    final text = value.trim();
    if (text.isEmpty) return result;
    final looksLikeJson =
        (text.startsWith('[') && text.endsWith(']')) ||
        (text.startsWith('{') && text.endsWith('}'));
    if (looksLikeJson) {
      try {
        final decoded = jsonDecode(text);
        if (decoded is List) {
          for (final item in decoded) {
            addValue(item);
          }
        } else {
          addValue(decoded);
        }
        return result;
      } catch (_) {
        // Fall through to comma separated parsing.
      }
    }
    for (final item in text.split(',')) {
      addValue(item);
    }
    return result;
  }

  addValue(value);
  return result;
}
