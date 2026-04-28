import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tronskins_app/common/utils/app_snackbar.dart';
import 'package:tronskins_app/common/widgets/figma_confirmation_dialog.dart';
import 'package:intl/intl.dart';
import 'package:tronskins_app/api/model/feedback/feedback_models.dart';
import 'package:tronskins_app/components/layout/list_end_tip.dart';
import 'package:tronskins_app/controllers/help/feedback_controller.dart';
import 'package:tronskins_app/routes/app_routes.dart';

class FeedbackDetailPage extends StatefulWidget {
  const FeedbackDetailPage({super.key});

  @override
  State<FeedbackDetailPage> createState() => _FeedbackDetailPageState();
}

class _FeedbackDetailPageState extends State<FeedbackDetailPage> {
  final FeedbackController controller = Get.isRegistered<FeedbackController>()
      ? Get.find<FeedbackController>()
      : Get.put(FeedbackController());
  final ScrollController _scrollController = ScrollController();

  String _ticketId = '';
  int? _status;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    final args = Get.arguments;
    if (args is Map) {
      _ticketId = args['id']?.toString() ?? '';
      _status = args['status'] is int
          ? args['status'] as int
          : int.tryParse(args['status']?.toString() ?? '');
    } else {
      _ticketId = args?.toString() ?? '';
    }
    if (_ticketId.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        controller.replies.clear();
        controller.detail.value = null;
        controller.loadDetail(_ticketId);
        controller.loadReplies(ticketId: _ticketId, refresh: true);
      });
    }
    _scrollController.addListener(_handleScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 120) {
      controller.loadReplies(ticketId: _ticketId);
    }
  }

  String _formatShortTime(int? value) {
    if (value == null) return '--:--';
    final ts = value < 1000000000000 ? value * 1000 : value;
    return DateFormat('HH:mm').format(DateTime.fromMillisecondsSinceEpoch(ts));
  }

  String _timelineLabel(int? value) {
    final timestamp = value == null
        ? DateTime.now()
        : DateTime.fromMillisecondsSinceEpoch(
            value < 1000000000000 ? value * 1000 : value,
          );
    return DateFormat('yyyy-MM-dd HH:mm').format(timestamp);
  }

  String _topBarTitle(FeedbackDetail? detail) {
    final suffix = _ticketSuffix(detail);
    final title = 'app.user.feedback.details'.tr;
    return suffix.isEmpty ? title : '$title #$suffix';
  }

  String _ticketSuffix(FeedbackDetail? detail) {
    final id = (detail?.id?.trim().isNotEmpty == true ? detail!.id! : _ticketId)
        .trim();
    if (id.isEmpty) return '';
    return id.length > 5 ? id.substring(id.length - 5) : id;
  }

  String _attachmentName(String url, String fallbackSuffix) {
    try {
      final uri = Uri.tryParse(url);
      final segment = uri?.pathSegments.isNotEmpty == true
          ? uri!.pathSegments.last
          : '';
      final decoded = Uri.decodeComponent(segment).trim();
      if (decoded.isNotEmpty) return decoded;
    } catch (_) {
      // Keep the generated fallback when the URL cannot be decoded.
    }
    return fallbackSuffix.isEmpty ? 'IMAGE.PNG' : 'ISSUE_$fallbackSuffix.PNG';
  }

  Future<bool> _solveTicket() async {
    try {
      final res = await controller.solveFeedback(_ticketId);
      if (res.success) {
        AppSnackbar.success('app.user.feedback.message.solve_success'.tr);
        controller.loadTickets(refresh: true);
        return true;
      }
      final message = res.message.isNotEmpty
          ? res.message
          : 'app.system.message.not_open'.tr;
      AppSnackbar.info(message);
    } catch (_) {
      AppSnackbar.error('app.user.login.message.error'.tr);
    }
    return false;
  }

  Future<void> _refreshDetail() async {
    if (_refreshing || _ticketId.isEmpty) return;
    setState(() => _refreshing = true);
    try {
      await Future.wait([
        controller.loadDetail(_ticketId),
        controller.loadReplies(ticketId: _ticketId, refresh: true),
      ]);
    } finally {
      if (mounted) {
        setState(() => _refreshing = false);
      }
    }
  }

  void _backToList() {
    var found = false;
    Get.until((route) {
      if (route.settings.name == Routers.FEEDBACK_LIST) {
        found = true;
        return true;
      }
      return false;
    });
    if (!found) {
      Get.offNamed(Routers.FEEDBACK_LIST);
    }
  }

  Future<void> _confirmSolveTicket() async {
    await showFigmaModal<void>(
      context: context,
      barrierDismissible: false,
      child: FigmaAsyncConfirmationDialog(
        title: 'app.system.tips.title'.tr,
        message: 'app.user.feedback.message.solve_confirm'.tr,
        primaryLabel: 'app.common.confirm'.tr,
        secondaryLabel: 'app.common.cancel'.tr,
        icon: Icons.check_circle_outline_rounded,
        iconColor: _FeedbackDetailStyle.brandBlue,
        iconBackgroundColor: _FeedbackDetailStyle.softBlue,
        onSecondary: () => popModalRoute(context),
        onConfirm: (dialogContext) async {
          final solved = await _solveTicket();
          if (!solved) {
            return;
          }
          if (dialogContext.mounted) {
            popModalRoute(dialogContext);
          }
          if (mounted) {
            _backToList();
          }
        },
      ),
    );
  }

  void _addReply() {
    Get.toNamed(
      Routers.FEEDBACK_CREATE,
      arguments: {'type': 'addFeedback', 'id': _ticketId},
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _FeedbackDetailStyle.pageBackground,
      body: Obx(() {
        final loading = controller.replyLoading.value;
        final detailLoading = controller.detailLoading.value;
        final list = controller.replies;
        final detail = controller.detail.value;
        final effectiveStatus = detail?.status ?? _status;
        final closed = effectiveStatus == 2 || effectiveStatus == 3;
        final showLoadingFooter = loading && list.isNotEmpty;
        final showNoMoreFooter =
            list.isNotEmpty && !loading && !controller.repliesHasMore;
        final showSkeleton =
            _refreshing ||
            (detailLoading && detail == null) ||
            (loading && list.isEmpty);
        return Stack(
          children: [
            Positioned.fill(
              child: RefreshIndicator(
                color: _FeedbackDetailStyle.brandBlue,
                backgroundColor: Colors.white,
                strokeWidth: 2.2,
                displacement: 22,
                edgeOffset: _FeedbackDetailStyle.topBarHeight(context),
                onRefresh: _refreshDetail,
                child: ListView(
                  controller: _scrollController,
                  physics: showSkeleton
                      ? const NeverScrollableScrollPhysics()
                      : const AlwaysScrollableScrollPhysics(
                          parent: ClampingScrollPhysics(),
                        ),
                  padding: EdgeInsets.fromLTRB(
                    24,
                    _FeedbackDetailStyle.contentTopPadding(context),
                    24,
                    _FeedbackDetailStyle.footerHeight(context) + 24,
                  ),
                  children: showSkeleton
                      ? [
                          _buildHeaderLoading(context),
                          const SizedBox(height: 32),
                          _buildConversationLoading(context),
                        ]
                      : [
                          if (detail != null) _buildHeader(context, detail),
                          if (detail != null) const SizedBox(height: 32),
                          if (list.isNotEmpty)
                            _TimelineChip(
                              label: _timelineLabel(
                                list.first.createTime ?? detail?.createTime,
                              ),
                            ),
                          if (list.isNotEmpty) const SizedBox(height: 24),
                          if (list.isEmpty)
                            _buildEmptyReplies()
                          else
                            ...list.map(
                              (item) => _buildReplyBubble(context, item),
                            ),
                          _buildLoadMoreFooter(
                            showLoading: showLoadingFooter,
                            showNoMore: showNoMoreFooter,
                          ),
                        ],
                ),
              ),
            ),
            _FeedbackDetailTopBar(
              title: _topBarTitle(detail),
              onBack: () => Navigator.maybePop(context),
              onInfo: closed ? null : _confirmSolveTicket,
            ),
            _FeedbackChatFooter(
              placeholder: 'app.user.feedback.problem_placeholder'.tr,
              onSend: closed ? null : _addReply,
            ),
          ],
        );
      }),
    );
  }

  Widget _buildEmptyReplies() {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: 8, bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF2F4F6),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const DecoratedBox(
              decoration: BoxDecoration(
                color: Color(0xFF0058BE),
                shape: BoxShape.circle,
              ),
              child: SizedBox(width: 6, height: 6),
            ),
            const SizedBox(width: 8),
            Text(
              'app.common.no_data'.tr.toUpperCase(),
              style: const TextStyle(
                color: Color(0xFF444653),
                fontSize: 11,
                fontWeight: FontWeight.w700,
                height: 16.5 / 11,
                letterSpacing: 0.55,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadMoreFooter({
    required bool showLoading,
    required bool showNoMore,
  }) {
    if (showLoading) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(0, 4, 0, 12),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.2),
          ),
        ),
      );
    }
    if (showNoMore) {
      return const ListEndTip(padding: EdgeInsets.fromLTRB(8, 6, 8, 12));
    }
    return const SizedBox(height: 4);
  }

  Widget _buildHeaderLoading(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLoadingLine(context, width: 130, height: 20, radius: 8),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.fromLTRB(21, 20, 21, 21),
          decoration: _FeedbackDetailStyle.initialCardDecoration,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLoadingLine(context, width: double.infinity, height: 14),
              const SizedBox(height: 8),
              _buildLoadingLine(context, width: double.infinity, height: 14),
              const SizedBox(height: 8),
              _buildLoadingLine(context, width: 220, height: 14),
              const SizedBox(height: 16),
              _buildLoadingLine(
                context,
                width: double.infinity,
                height: 200,
                radius: 12,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  _buildLoadingLine(context, width: 190, height: 10),
                  const Spacer(),
                  _buildLoadingLine(context, width: 26, height: 10),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildConversationLoading(BuildContext context) {
    return Column(
      children: const [
        _FeedbackLoadingBubble(isAdmin: false),
        _FeedbackLoadingBubble(isAdmin: true),
        _FeedbackLoadingBubble(isAdmin: false),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, FeedbackDetail detail) {
    final content = detail.context?.trim();
    final images = detail.images;
    final attachmentId = _ticketSuffix(detail);
    final attachmentName = images.isEmpty
        ? ''
        : _attachmentName(images.first, attachmentId);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'app.user.feedback.problem'.tr,
          style: const TextStyle(
            color: _FeedbackDetailStyle.brandBlue,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            height: 28 / 18,
            letterSpacing: -0.45,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(21, 20, 21, 21),
          decoration: _FeedbackDetailStyle.initialCardDecoration,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                content?.isNotEmpty == true ? content! : '--',
                style: const TextStyle(
                  color: _FeedbackDetailStyle.text,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  height: 22.75 / 14,
                  letterSpacing: 0,
                ),
              ),
              if (images.isNotEmpty) ...[
                const SizedBox(height: 16),
                _FeedbackHeaderImages(images: images, onPreview: _previewImage),
                const SizedBox(height: 20),
              ] else
                const SizedBox(height: 12),
              Row(
                mainAxisAlignment: images.isEmpty
                    ? MainAxisAlignment.end
                    : MainAxisAlignment.spaceBetween,
                children: [
                  if (images.isNotEmpty) ...[
                    Flexible(
                      child: Text(
                        attachmentName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _FeedbackDetailStyle.mutedTextAlt,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          height: 15 / 10,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    _formatShortTime(detail.createTime),
                    style: const TextStyle(
                      color: _FeedbackDetailStyle.mutedTextAlt,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      height: 15 / 10,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReplyBubble(BuildContext context, FeedbackReply item) {
    final isAdmin = item.isAdmin == true;
    return isAdmin ? _buildServiceBubble(item) : _buildUserBubble(item);
  }

  Widget _buildServiceBubble(FeedbackReply item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              color: _FeedbackDetailStyle.fieldSurface,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.support_agent_rounded,
              color: _FeedbackDetailStyle.brandBlue,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 238),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topRight: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Color.fromRGBO(0, 0, 0, 0.05),
                      blurRadius: 1,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.context ?? '',
                      style: const TextStyle(
                        color: _FeedbackDetailStyle.text,
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        height: 22.75 / 14,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        _formatShortTime(item.createTime),
                        style: const TextStyle(
                          color: _FeedbackDetailStyle.mutedTextAlt,
                          fontSize: 9,
                          fontWeight: FontWeight.w500,
                          height: 13.5 / 9,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserBubble(FeedbackReply item) {
    return Padding(
      padding: const EdgeInsets.only(left: 51.31, bottom: 24),
      child: Align(
        alignment: Alignment.centerRight,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 290.7),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: item.images.isNotEmpty
                    ? const EdgeInsets.all(12)
                    : const EdgeInsets.fromLTRB(16, 16, 56, 16),
                decoration: BoxDecoration(
                  gradient: _FeedbackDetailStyle.primaryGradient,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.10),
                      blurRadius: 6,
                      offset: const Offset(0, 4),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.10),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (item.images.isNotEmpty) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: GestureDetector(
                          onTap: () => _previewImage(item.images.first),
                          child: CachedNetworkImage(
                            imageUrl: item.images.first,
                            height: 177.78,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            placeholder: (context, _) => const ColoredBox(
                              color: Color.fromRGBO(0, 0, 0, 0.2),
                              child: SizedBox(height: 177.78),
                            ),
                            errorWidget: (context, _, __) => const ColoredBox(
                              color: Color.fromRGBO(0, 0, 0, 0.2),
                              child: SizedBox(
                                height: 177.78,
                                child: Center(
                                  child: Icon(
                                    Icons.image_not_supported_outlined,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10.88),
                    ],
                    Text(
                      item.context ?? '',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        height: 22.75 / 14,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _formatShortTime(item.createTime),
                    style: const TextStyle(
                      color: _FeedbackDetailStyle.mutedTextAlt,
                      fontSize: 9,
                      fontWeight: FontWeight.w500,
                      height: 13.5 / 9,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.done_all_rounded,
                    color: Color(0xFF0058BE),
                    size: 10,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _previewImage(String url) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 22,
            vertical: 42,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: DecoratedBox(
              decoration: const BoxDecoration(color: Colors.black),
              child: InteractiveViewer(
                child: CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.contain,
                  placeholder: (context, _) => const Center(
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.2,
                    ),
                  ),
                  errorWidget: (context, _, __) => const Icon(
                    Icons.image_not_supported_outlined,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoadingLine(
    BuildContext context, {
    required double width,
    required double height,
    double radius = 999,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: _FeedbackDetailStyle.skeleton,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class _FeedbackHeaderImages extends StatelessWidget {
  const _FeedbackHeaderImages({required this.images, required this.onPreview});

  final List<String> images;
  final ValueChanged<String> onPreview;

  @override
  Widget build(BuildContext context) {
    if (images.length == 1) {
      return _FeedbackHeaderImage(
        url: images.first,
        height: 200,
        onTap: () => onPreview(images.first),
      );
    }

    return SizedBox(
      height: 112,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: images.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final url = images[index];
          return _FeedbackHeaderImage(
            url: url,
            width: 150,
            height: 112,
            onTap: () => onPreview(url),
          );
        },
      ),
    );
  }
}

class _FeedbackHeaderImage extends StatelessWidget {
  const _FeedbackHeaderImage({
    required this.url,
    required this.height,
    required this.onTap,
    this.width,
  });

  final String url;
  final double height;
  final double? width;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: GestureDetector(
        onTap: onTap,
        child: CachedNetworkImage(
          imageUrl: url,
          height: height,
          width: width ?? double.infinity,
          fit: BoxFit.cover,
          placeholder: (context, _) => Container(
            height: height,
            width: width ?? double.infinity,
            color: _FeedbackDetailStyle.fieldSurface,
            alignment: Alignment.center,
            child: const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
          errorWidget: (context, _, __) => Container(
            height: height,
            width: width ?? double.infinity,
            color: _FeedbackDetailStyle.fieldSurface,
            alignment: Alignment.center,
            child: const Icon(
              Icons.image_not_supported_outlined,
              color: _FeedbackDetailStyle.mutedTextAlt,
            ),
          ),
        ),
      ),
    );
  }
}

class _FeedbackDetailTopBar extends StatelessWidget {
  const _FeedbackDetailTopBar({
    required this.title,
    required this.onBack,
    required this.onInfo,
  });

  final String title;
  final VoidCallback onBack;
  final VoidCallback? onInfo;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    return Positioned(
      left: 0,
      right: 0,
      top: 0,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            height: _FeedbackDetailStyle.topBarHeight(context),
            padding: EdgeInsets.fromLTRB(16, topInset, 16, 0),
            decoration: BoxDecoration(
              color: _FeedbackDetailStyle.glassTopBar,
              border: Border(
                bottom: BorderSide(
                  color: _FeedbackDetailStyle.fieldSurface.withValues(
                    alpha: 0.3,
                  ),
                ),
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: onBack,
                  icon: const Icon(
                    Icons.arrow_back,
                    color: _FeedbackDetailStyle.brandBlue,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF0F172A),
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      height: 28 / 20,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onInfo,
                  icon: const Icon(
                    Icons.info_outline_rounded,
                    color: _FeedbackDetailStyle.brandBlue,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TimelineChip extends StatelessWidget {
  const _TimelineChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        height: 27,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFE6E8EA),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Color(0xFF444653),
            fontSize: 10,
            fontWeight: FontWeight.w500,
            height: 15 / 10,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}

class _FeedbackChatFooter extends StatelessWidget {
  const _FeedbackChatFooter({required this.placeholder, required this.onSend});

  final String placeholder;
  final VoidCallback? onSend;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: EdgeInsets.fromLTRB(24, 16, 24, 20 + bottomInset),
            color: _FeedbackDetailStyle.glassFooter,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 56,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: _FeedbackDetailStyle.fieldSurface,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: onSend,
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(
                          Icons.attach_file_rounded,
                          color: _FeedbackDetailStyle.mutedTextAlt,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          placeholder,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color.fromRGBO(117, 118, 132, 0.6),
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: onSend,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            gradient: _FeedbackDetailStyle.primaryGradient,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.10),
                                blurRadius: 15,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.arrow_forward_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FeedbackLoadingBubble extends StatelessWidget {
  const _FeedbackLoadingBubble({required this.isAdmin});

  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    final bubbleColor = isAdmin
        ? _FeedbackDetailStyle.card
        : _FeedbackDetailStyle.userBubble;
    final borderColor = isAdmin
        ? _FeedbackDetailStyle.border
        : _FeedbackDetailStyle.userBubbleBorder;
    final lineColor = isAdmin
        ? _FeedbackDetailStyle.skeleton
        : _FeedbackDetailStyle.userSkeleton;

    Widget loadingLine(double width, double height) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: lineColor,
          borderRadius: BorderRadius.circular(999),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.fromLTRB(20, 18, 18, 18),
      decoration: BoxDecoration(
        color: bubbleColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
        boxShadow: isAdmin ? _FeedbackDetailStyle.cardShadow : const [],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          loadingLine(42, 42),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    loadingLine(96, 14),
                    const SizedBox(width: 8),
                    loadingLine(72, 12),
                  ],
                ),
                const SizedBox(height: 12),
                loadingLine(double.infinity, 16),
                const SizedBox(height: 8),
                loadingLine(210, 16),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedbackDetailStyle {
  const _FeedbackDetailStyle._();

  static const pageBackground = Color(0xFFF7F9FB);
  static const card = Color(0xFFFFFFFF);
  static const text = Color(0xFF191C1E);
  static const border = Color(0xFFDDE4EC);
  static const brandBlue = Color(0xFF00288E);
  static const softBlue = Color(0xFFEAF0FF);
  static const fieldSurface = Color(0xFFE0E3E5);
  static const mutedTextAlt = Color(0xFF757684);
  static const skeleton = Color(0xFFE8EEF4);
  static const userBubble = Color(0xFFFFFFFF);
  static const userBubbleBorder = Color(0xFFB8DDEE);
  static const userSkeleton = Color(0xFFD4E5ED);
  static const glassTopBar = Color.fromRGBO(248, 250, 252, 0.7);
  static const glassFooter = Color.fromRGBO(248, 250, 252, 0.8);

  static final cardShadow = [
    BoxShadow(
      color: brandBlue.withValues(alpha: 0.045),
      blurRadius: 22,
      offset: const Offset(0, 12),
    ),
  ];

  static final initialCardDecoration = BoxDecoration(
    color: const Color(0xFFF2F4F6),
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: fieldSurface.withValues(alpha: 0.5)),
  );

  static const primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF00288E), Color(0xFF0058BE)],
  );

  static double topBarHeight(BuildContext context) {
    return MediaQuery.paddingOf(context).top + 56;
  }

  static double contentTopPadding(BuildContext context) {
    return topBarHeight(context) + 16;
  }

  static double footerHeight(BuildContext context) {
    return 92 + MediaQuery.paddingOf(context).bottom;
  }
}
