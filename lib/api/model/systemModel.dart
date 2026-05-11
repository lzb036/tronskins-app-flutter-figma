// ignore_for_file: file_names

class SystemCurrencyModel {
  final int id;
  final String currencyCode;
  final double rate;
  final String createTime;
  final String updateTime;

  SystemCurrencyModel({
    required this.id,
    required this.currencyCode,
    required this.rate,
    required this.createTime,
    required this.updateTime,
  });

  factory SystemCurrencyModel.fromJson(Map<String, dynamic> json) {
    return SystemCurrencyModel(
      id: json['id'],
      currencyCode: json['currencyCode'],
      rate: json['rate'],
      createTime: json['createTime'],
      updateTime: json['updateTime'],
    );
  }
}

class SystemNoticeEntity {
  final String? id;
  final String? title;
  final String? content;
  final String? createName;
  final int? createTime;
  final String? publishTime;
  final bool flag;
  final bool isRead;

  const SystemNoticeEntity({
    this.id,
    this.title,
    this.content,
    this.createName,
    this.createTime,
    this.publishTime,
    this.flag = false,
    this.isRead = false,
  });

  factory SystemNoticeEntity.fromJson(Map<String, dynamic> json) {
    return SystemNoticeEntity(
      id: json['id']?.toString(),
      title: json['title']?.toString(),
      content: json['content']?.toString(),
      createName:
          json['createName']?.toString() ?? json['create_name']?.toString(),
      createTime: _asInt(json['createTime'] ?? json['create_time']),
      publishTime:
          json['publishTime']?.toString() ?? json['publish_time']?.toString(),
      flag: _asBool(json['flag']),
      isRead: _asBool(json['isRead'] ?? json['read'] ?? json['is_read']),
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
  final normalized = value.toString().toLowerCase();
  return normalized == '1' || normalized == 'true' || normalized == 'yes';
}
