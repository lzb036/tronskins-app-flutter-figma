import 'package:flutter/material.dart';
import 'package:tronskins_app/common/widgets/settings_style_app_bar.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_html_table/flutter_html_table.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:tronskins_app/api/model/help/help_models.dart';
import 'package:tronskins_app/common/widgets/back_to_top_overlay.dart';
import 'package:tronskins_app/pages/help/widgets/help_ui.dart';

class HelpDetailPage extends StatelessWidget {
  const HelpDetailPage({super.key});

  String _formatTime(int? value) {
    if (value == null) return '--';
    final ts = value < 1000000000000 ? value * 1000 : value;
    return DateFormat(
      'yyyy-MM-dd HH:mm:ss',
    ).format(DateTime.fromMillisecondsSinceEpoch(ts));
  }

  @override
  Widget build(BuildContext context) {
    final arg = Get.arguments;
    HelpItem? item;
    if (arg is HelpItem) {
      item = arg;
    } else if (arg is Map) {
      item = HelpItem.fromJson(Map<String, dynamic>.from(arg));
    }
    return Scaffold(
      backgroundColor: HelpUi.pageBackground(context),
      appBar: SettingsStyleAppBar(title: Text('app.common.details'.tr)),
      body: BackToTopScope(
        enabled: false,
        child: item == null
            ? Center(child: Text('app.common.no_data'.tr))
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  Container(
                    decoration: HelpUi.cardDecoration(
                      context,
                      gradient: HelpUi.heroGradient(context),
                    ),
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title ?? '',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 12,
                          runSpacing: 6,
                          children: [
                            if ((item.author ?? '').isNotEmpty)
                              _MetaChip(
                                icon: Icons.person_outline,
                                label:
                                    '${'app.system.notice.author'.tr}: ${item.author ?? ''}',
                              ),
                            if (item.time != null)
                              _MetaChip(
                                icon: Icons.schedule,
                                label:
                                    '${'app.system.notice.publish_time'.tr}: ${_formatTime(item.time)}',
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    decoration: HelpUi.cardDecoration(context),
                    padding: const EdgeInsets.all(16),
                    child: Html(
                      data: item.content ?? '',
                      extensions: [
                        TagWrapExtension(
                          tagsToWrap: {'table'},
                          builder: (child) =>
                              _ScrollableTableView(child: child),
                        ),
                        const TableHtmlExtension(),
                      ],
                      style: {
                        'body': Style(
                          margin: Margins.zero,
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: FontSize(15),
                          lineHeight: const LineHeight(1.6),
                        ),
                        'h1': Style(fontSize: FontSize(22)),
                        'h2': Style(fontSize: FontSize(20)),
                        'h3': Style(fontSize: FontSize(18)),
                        'p': Style(margin: Margins.only(bottom: 10)),
                        'ul': Style(
                          margin: Margins.only(bottom: 10),
                          padding: HtmlPaddings.zero,
                          listStyleType: ListStyleType.disc,
                        ),
                        'ol': Style(
                          margin: Margins.only(bottom: 10),
                          padding: HtmlPaddings.zero,
                          listStyleType: ListStyleType.decimal,
                        ),
                        'li': Style(
                          margin: Margins.zero,
                          padding: HtmlPaddings.zero,
                        ),
                        'a': Style(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        'table': Style(
                          margin: Margins.only(top: 8, bottom: 14),
                        ),
                        'td': Style(
                          padding: HtmlPaddings.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outlineVariant
                                .withValues(alpha: 0.18),
                          ),
                        ),
                        'th': Style(
                          padding: HtmlPaddings.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          fontWeight: FontWeight.w700,
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                        ),
                      },
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _ScrollableTableView extends StatefulWidget {
  const _ScrollableTableView({required this.child});

  final Widget child;

  @override
  State<_ScrollableTableView> createState() => _ScrollableTableViewState();
}

class _ScrollableTableViewState extends State<_ScrollableTableView> {
  late final ScrollController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ScrollController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      controller: _controller,
      thumbVisibility: true,
      trackVisibility: true,
      scrollbarOrientation: ScrollbarOrientation.bottom,
      thickness: 4,
      radius: const Radius.circular(999),
      child: SingleChildScrollView(
        controller: _controller,
        primary: false,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(bottom: 12),
        child: widget.child,
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: HelpUi.softFill(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.24),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
