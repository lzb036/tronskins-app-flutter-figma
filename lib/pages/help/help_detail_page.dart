import 'package:flutter/material.dart';
import 'package:tronskins_app/common/widgets/settings_style_app_bar.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_html_table/flutter_html_table.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:tronskins_app/api/model/help/help_models.dart';
import 'package:tronskins_app/common/storage/server_storage.dart';
import 'package:tronskins_app/common/widgets/back_to_top_overlay.dart';

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
      backgroundColor: const Color(0xFFF7F9FB),
      appBar: SettingsStyleAppBar(title: Text('app.common.details'.tr)),
      body: BackToTopScope(
        enabled: false,
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

  Widget _buildDetailCard(BuildContext context, HelpItem item) {
    final theme = Theme.of(context);
    final author = (item.author ?? '').trim();

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
            Text(
              item.title ?? '',
              style: theme.textTheme.titleMedium?.copyWith(
                color: const Color(0xFF191C1E),
                fontWeight: FontWeight.w700,
                height: 20 / 16,
              ),
            ),
            if (author.isNotEmpty || item.time != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      author,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF757684),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (item.time != null) ...[
                    const SizedBox(width: 12),
                    Text(
                      _formatTime(item.time),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF757684),
                        fontWeight: FontWeight.w500,
                        height: 16 / 12,
                      ),
                    ),
                  ],
                ],
              ),
            ],
            const SizedBox(height: 12),
            const Divider(
              height: 1,
              thickness: 1,
              color: Color.fromRGBO(196, 197, 213, 0.15),
            ),
            const SizedBox(height: 16),
            _buildContent(context, item.content),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, String? content) {
    const bodyColor = Color(0xFF444653);
    const emphasisColor = Color(0xFF191C1E);

    if (content == null || content.trim().isEmpty) {
      return Text(
        'app.common.no_data'.tr,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: const Color(0xFF757684)),
      );
    }

    return Html(
      data: content,
      extensions: [
        ImageExtension(
          builder: (context) => _HelpContentImage(
            src: _resolveHelpImageSrc(context.attributes['src']),
            alt: context.attributes['alt'],
          ),
        ),
        TagWrapExtension(
          tagsToWrap: {'table'},
          builder: (child) => _ScrollableTableView(child: child),
        ),
        const TableHtmlExtension(),
      ],
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
        'p': Style(margin: Margins.only(bottom: 10)),
        'h1': Style(
          color: emphasisColor,
          fontSize: FontSize(20),
          fontWeight: FontWeight.w700,
          margin: Margins.only(bottom: 10),
        ),
        'h2': Style(
          color: emphasisColor,
          fontSize: FontSize(18),
          fontWeight: FontWeight.w700,
          margin: Margins.only(bottom: 10),
        ),
        'h3': Style(
          color: emphasisColor,
          fontSize: FontSize(16),
          fontWeight: FontWeight.w700,
          margin: Margins.only(bottom: 8),
        ),
        'strong': Style(color: emphasisColor, fontWeight: FontWeight.w600),
        'b': Style(color: emphasisColor, fontWeight: FontWeight.w600),
        'ul': Style(
          margin: Margins.only(bottom: 10),
          listStyleType: ListStyleType.disc,
        ),
        'ol': Style(
          margin: Margins.only(bottom: 10),
          listStyleType: ListStyleType.decimal,
        ),
        'li': Style(margin: Margins.only(bottom: 4)),
        'a': Style(color: Theme.of(context).colorScheme.primary),
        'table': Style(margin: Margins.only(top: 8, bottom: 14)),
        'td': Style(
          padding: HtmlPaddings.symmetric(horizontal: 10, vertical: 8),
          border: Border.all(
            color: Theme.of(
              context,
            ).colorScheme.outlineVariant.withValues(alpha: 0.18),
          ),
        ),
        'th': Style(
          padding: HtmlPaddings.symmetric(horizontal: 10, vertical: 8),
          color: emphasisColor,
          fontWeight: FontWeight.w700,
          backgroundColor: const Color(0xFFF1F5F9),
        ),
      },
    );
  }
}

String _resolveHelpImageSrc(String? value) {
  final trimmed = value?.trim() ?? '';
  if (trimmed.isEmpty) {
    return '';
  }
  if (trimmed.startsWith('//')) {
    return 'https:$trimmed';
  }
  final uri = Uri.tryParse(trimmed);
  if (uri != null && uri.hasScheme) {
    return trimmed;
  }
  final baseUri =
      Uri.tryParse(ServerStorage.getServer()) ??
      Uri.parse(ServerStorage.defaultServer);
  return baseUri.resolve(trimmed).toString();
}

class _HelpContentImage extends StatelessWidget {
  const _HelpContentImage({required this.src, this.alt});

  static const Map<String, String> _headers = {
    'User-Agent':
        'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/120 Mobile Safari/537.36',
    'Referer': 'https://www.etopmarket.com/',
  };

  final String src;
  final String? alt;

  @override
  Widget build(BuildContext context) {
    if (src.isEmpty) {
      return const SizedBox.shrink();
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width - 64;
        return Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              src,
              width: width,
              fit: BoxFit.contain,
              headers: _headers,
              semanticLabel: alt,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) {
                  return child;
                }
                return Container(
                  width: width,
                  height: 160,
                  alignment: Alignment.center,
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: width,
                  height: 120,
                  alignment: Alignment.center,
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                );
              },
            ),
          ),
        );
      },
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
