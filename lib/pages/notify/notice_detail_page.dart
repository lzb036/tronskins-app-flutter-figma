import 'package:flutter/material.dart';
import 'package:tronskins_app/common/widgets/settings_style_app_bar.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:tronskins_app/api/model/notify/notify_models.dart';
import 'package:tronskins_app/api/notify.dart';
import 'package:tronskins_app/controllers/user/notify_controller.dart';

class NoticeDetailPage extends StatefulWidget {
  const NoticeDetailPage({super.key});

  @override
  State<NoticeDetailPage> createState() => _NoticeDetailPageState();
}

class _NoticeDetailPageState extends State<NoticeDetailPage> {
  final ApiNotifyServer _api = ApiNotifyServer();
  final NotifyController _notifyController =
      Get.isRegistered<NotifyController>()
      ? Get.find<NotifyController>()
      : Get.put(NotifyController());

  NoticeDetail? _detail;
  NoticeMessageItem? _item;
  bool _loading = true;
  String? _id;

  @override
  void initState() {
    super.initState();
    _resolveArgument();
    _loadDetail();
    _markRead();
  }

  void _resolveArgument() {
    final arg = Get.arguments;
    if (arg is NoticeMessageItem) {
      _item = arg;
      _id = arg.id;
      return;
    }

    _id = arg?.toString();
    final id = _id;
    if (id == null || id.isEmpty) {
      return;
    }

    for (final element in _notifyController.noticeList) {
      if (element.id == id) {
        _item = element;
        break;
      }
    }
  }

  Future<void> _markRead() async {
    final item = _item;
    if (item == null) {
      return;
    }
    await _notifyController.readNotice(item);
  }

  Future<void> _loadDetail() async {
    final id = _id;
    if (id == null || id.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    try {
      final res = await _api.noticeDetail(id: id);
      if (res.success) {
        _detail = res.datas;
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  String _formatTime(int? value) {
    if (value == null) return '--';
    final ts = value < 1000000000000 ? value * 1000 : value;
    return DateFormat(
      'yyyy-MM-dd HH:mm:ss',
    ).format(DateTime.fromMillisecondsSinceEpoch(ts));
  }

  String _stripHtml(String? value) {
    if (value == null || value.isEmpty) return '';
    return value.replaceAll(RegExp(r'<[^>]*>'), '');
  }

  @override
  Widget build(BuildContext context) {
    final title = _detail?.title ?? 'app.system.notice.announcement'.tr;
    return Scaffold(
      appBar: SettingsStyleAppBar(title: Text(title)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _detail == null
          ? Center(child: Text('app.common.no_data'.tr))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              '${'app.system.notice.author'.tr}: ',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            Expanded(
                              child: Text(
                                _detail?.createName ?? '--',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Text(
                              '${'app.system.notice.publish_time'.tr}: ',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            Text(
                              _formatTime(_detail?.createTime),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _stripHtml(_detail?.content),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
    );
  }
}
