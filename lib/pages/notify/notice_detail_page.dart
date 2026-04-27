import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:tronskins_app/api/model/notify/notify_models.dart';
import 'package:tronskins_app/common/widgets/settings_style_app_bar.dart';
import 'package:tronskins_app/controllers/user/notify_controller.dart';

class NoticeDetailPage extends StatefulWidget {
  const NoticeDetailPage({super.key});

  @override
  State<NoticeDetailPage> createState() => _NoticeDetailPageState();
}

class _NoticeDetailPageState extends State<NoticeDetailPage> {
  final NotifyController _notifyController =
      Get.isRegistered<NotifyController>()
      ? Get.find<NotifyController>()
      : Get.put(NotifyController());

  NoticeMessageItem? _item;

  @override
  void initState() {
    super.initState();
    _resolveArgument();
    _markRead();
  }

  void _resolveArgument() {
    final arg = Get.arguments;
    if (arg is NoticeMessageItem) {
      _item = arg;
      return;
    }
    // 兼容传 id 字符串的场景，从列表中查找
    final id = arg?.toString();
    if (id == null || id.isEmpty) return;
    for (final element in _notifyController.noticeList) {
      if (element.id == id) {
        _item = element;
        break;
      }
    }
  }

  Future<void> _markRead() async {
    final item = _item;
    if (item == null) return;
    await _notifyController.readNotice(item);
    if (mounted) setState(() {});
  }

  String _formatTime(int? value) {
    if (value == null) return '--';
    final ts = value < 1000000000000 ? value * 1000 : value;
    return DateFormat('yyyy-MM-dd HH:mm').format(
      DateTime.fromMillisecondsSinceEpoch(ts),
    );
  }

  Widget _buildContent(BuildContext context, String? content) {
    const bodyColor = Color(0xFF444653);
    const emphasisColor = Color(0xFF191C1E);

    if (content == null || content.trim().isEmpty) {
      return Text(
        'app.common.no_data'.tr,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: const Color(0xFF757684),
        ),
      );
    }

    // 判断是否包含 HTML 标签
    final isHtml = RegExp(r'<[^>]+>').hasMatch(content);
    if (isHtml) {
      return Html(
        data: content,
        style: {
          '*': Style(
            margin: Margins.zero,
            padding: HtmlPaddings.zero,
            color: bodyColor,
            fontSize: FontSize(14),
            fontWeight: FontWeight.w400,
            lineHeight: LineHeight.number(1.625),
          ),
          'html': Style(margin: Margins.zero, padding: HtmlPaddings.zero),
          'body': Style(margin: Margins.zero, padding: HtmlPaddings.zero),
          'p': Style(margin: Margins.zero, padding: HtmlPaddings.zero),
          'span': Style(color: bodyColor),
          'strong': Style(color: emphasisColor, fontWeight: FontWeight.w600),
          'b': Style(color: emphasisColor, fontWeight: FontWeight.w600),
        },
      );
    }

    return Text(
      content,
      style: const TextStyle(
        color: bodyColor,
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.625,
      ),
    );
  }

  Widget _buildDetailCard(BuildContext context, NoticeMessageItem item) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.04),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题
            Text(
              item.title ?? 'app.system.notice.announcement'.tr,
              style: theme.textTheme.titleMedium?.copyWith(
                color: const Color(0xFF191C1E),
                fontWeight: FontWeight.w700,
                height: 20 / 16,
              ),
            ),
            const SizedBox(height: 6),
            // 创建人左对齐，时间右对齐
            Row(
              children: [
                if (item.createName != null && item.createName!.isNotEmpty)
                  Text(
                    item.createName!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF757684),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                const Spacer(),
                Text(
                  _formatTime(item.createTime),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF757684),
                    fontWeight: FontWeight.w500,
                    height: 16 / 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(
              height: 1,
              thickness: 1,
              color: Color.fromRGBO(196, 197, 213, 0.15),
            ),
            const SizedBox(height: 16),
            // 正文内容
            _buildContent(context, item.content),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = _item;
    return Scaffold(
      appBar: SettingsStyleAppBar(
        title: Text('app.system.notice.announcement'.tr),
      ),
      body: Container(
        color: const Color(0xFFF7F9FB),
        child: item == null
            ? Center(child: Text('app.common.no_data'.tr))
            : Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 390),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                    children: [_buildDetailCard(context, item)],
                  ),
                ),
              ),
      ),
    );
  }
}
