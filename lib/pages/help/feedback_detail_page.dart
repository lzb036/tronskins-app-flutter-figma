import 'dart:io';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:tronskins_app/api/model/feedback/feedback_models.dart';
import 'package:tronskins_app/common/utils/app_snackbar.dart';
import 'package:tronskins_app/common/widgets/figma_confirmation_dialog.dart';
import 'package:tronskins_app/components/layout/list_end_tip.dart';
import 'package:tronskins_app/controllers/help/feedback_controller.dart';

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
  final TextEditingController _replyController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final List<String> _replyImagePaths = [];
  final List<String> _replyImageIds = [];

  String _ticketId = '';
  int? _status;
  String? _statusName;
  bool _refreshing = false;
  bool _replyUploading = false;
  bool _replySubmitting = false;
  bool _replySolving = false;

  static const int _maxReplyImageCount = 5;

  @override
  void initState() {
    super.initState();
    final args = Get.arguments;
    if (args is Map) {
      _ticketId = args['id']?.toString() ?? '';
      _status = args['status'] is int
          ? args['status'] as int
          : int.tryParse(args['status']?.toString() ?? '');
      _statusName = args['statusName']?.toString();
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
    _replyController.dispose();
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
    if (value == null) return '--';
    final ts = value < 1000000000000 ? value * 1000 : value;
    return DateFormat(
      'yyyy-MM-dd HH:mm:ss',
    ).format(DateTime.fromMillisecondsSinceEpoch(ts));
  }

  String _timelineLabel(int? value) {
    return _formatShortTime(value);
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

  Future<void> _pickReplyImage() async {
    if (_replyUploading || _replySubmitting) return;
    if (_replyImagePaths.length >= _maxReplyImageCount) {
      AppSnackbar.info(_replyImageLimitNotice);
      return;
    }
    setState(() => _replyUploading = true);
    try {
      final file = await _picker.pickImage(source: ImageSource.gallery);
      if (file == null) return;
      final id = await controller.uploadImage(
        filePath: file.path,
        isReply: true,
      );
      if (!mounted) return;
      if (id != null) {
        setState(() {
          _replyImagePaths.add(file.path);
          _replyImageIds.add(id);
        });
        AppSnackbar.success(
          'app.user.feedback.message.image_upload_success'.tr,
        );
      } else {
        AppSnackbar.error('app.user.feedback.message.image_upload_failed'.tr);
      }
    } catch (_) {
      AppSnackbar.error('app.user.feedback.message.image_upload_failed'.tr);
    } finally {
      if (mounted) {
        setState(() => _replyUploading = false);
      }
    }
  }

  void _removeReplyImage(int index) {
    if (index < 0 || index >= _replyImagePaths.length) return;
    setState(() {
      _replyImagePaths.removeAt(index);
      if (index < _replyImageIds.length) {
        _replyImageIds.removeAt(index);
      }
    });
  }

  Future<void> _sendReply() async {
    final text = _replyController.text.trim();
    if (_replySubmitting || _replyUploading) return;
    if (_ticketId.isEmpty) {
      AppSnackbar.error('app.user.login.message.error'.tr);
      return;
    }
    if (text.isEmpty) {
      AppSnackbar.error('app.user.feedback.message.fill_feedback'.tr);
      return;
    }
    setState(() => _replySubmitting = true);
    try {
      final ok = await controller.addReply(
        ticketId: _ticketId,
        context: text,
        ids: _replyImageIds,
      );
      if (!mounted) return;
      if (ok) {
        _replyController.clear();
        setState(() {
          _replyImagePaths.clear();
          _replyImageIds.clear();
        });
        AppSnackbar.success('app.user.feedback.message.reply_success'.tr);
        controller.loadTickets(refresh: true);
        await controller.loadReplies(ticketId: _ticketId, refresh: true);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!_scrollController.hasClients) return;
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOut,
          );
        });
      } else {
        AppSnackbar.info('app.system.message.not_open'.tr);
      }
    } catch (_) {
      AppSnackbar.error('app.user.login.message.error'.tr);
    } finally {
      if (mounted) {
        setState(() => _replySubmitting = false);
      }
    }
  }

  Future<bool> _solveTicket() async {
    if (_replySolving || _replySubmitting || _replyUploading) return false;
    if (_ticketId.isEmpty) {
      AppSnackbar.error('app.user.login.message.error'.tr);
      return false;
    }
    setState(() => _replySolving = true);
    try {
      final res = await controller.solveFeedback(_ticketId);
      if (!mounted) return false;
      if (res.success) {
        _replyController.clear();
        _markDetailSolvedLocally();
        AppSnackbar.success('app.user.feedback.message.solve_success'.tr);
        controller.loadTickets(refresh: true);
        await Future.wait([
          controller.loadDetail(_ticketId),
          controller.loadReplies(ticketId: _ticketId, refresh: true),
        ]);
        return true;
      } else {
        final message = res.message.isNotEmpty
            ? res.message
            : 'app.system.message.not_open'.tr;
        AppSnackbar.info(message);
      }
    } catch (_) {
      AppSnackbar.error('app.user.login.message.error'.tr);
    } finally {
      if (mounted) {
        setState(() => _replySolving = false);
      }
    }
    return false;
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
        iconColor: const Color(0xFF16A34A),
        iconBackgroundColor: const Color.fromRGBO(22, 163, 74, 0.10),
        accentColor: const Color(0xFF16A34A),
        onSecondary: () => popModalRoute(context),
        onConfirm: (dialogContext) async {
          final solved = await _solveTicket();
          if (!solved) return;
          if (dialogContext.mounted) {
            popModalRoute(dialogContext);
          }
        },
      ),
    );
  }

  void _markDetailSolvedLocally() {
    final current = controller.detail.value;
    setState(() {
      _status = 2;
      _replyImagePaths.clear();
      _replyImageIds.clear();
    });
    if (current == null) return;
    controller.detail.value = FeedbackDetail(
      id: current.id,
      title: current.title,
      context: current.context,
      status: 2,
      statusName: 'app.user.feedback.solved'.tr,
      createTime: current.createTime,
      images: current.images,
    );
  }

  String get _replyImageLimitNotice {
    final isZh =
        Get.locale?.languageCode.toLowerCase().startsWith('zh') == true;
    if (isZh) {
      return '最多可上传 5 张图片';
    }
    return 'You can upload up to 5 images.';
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
        final initialReply = detail == null
            ? null
            : _initialFeedbackReply(list);
        final conversationReplies = initialReply == null
            ? List<FeedbackReply>.of(list)
            : list.skip(1).toList(growable: false);
        final effectiveStatus = detail?.status ?? _status;
        final effectiveStatusName = detail?.statusName ?? _statusName;
        final closed = effectiveStatus == 2 || effectiveStatus == 3;
        final canInput = !closed;
        final showLoadingFooter = loading && conversationReplies.isNotEmpty;
        final showNoMoreFooter =
            conversationReplies.isNotEmpty &&
            !loading &&
            !controller.repliesHasMore;
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
                    canInput
                        ? _FeedbackDetailStyle.footerHeight(
                                context,
                                _replyImagePaths.length,
                              ) +
                              24
                        : MediaQuery.paddingOf(context).bottom + 24,
                  ),
                  children: showSkeleton
                      ? [
                          _buildHeaderLoading(context),
                          const SizedBox(height: 32),
                          _buildConversationLoading(context),
                        ]
                      : [
                          if (detail != null)
                            _buildHeader(
                              context,
                              detail,
                              initialReply: initialReply,
                            ),
                          if (detail != null) const SizedBox(height: 32),
                          if (conversationReplies.isNotEmpty)
                            _TimelineChip(
                              label: _timelineLabel(
                                conversationReplies.first.createTime ??
                                    detail?.createTime,
                              ),
                            ),
                          if (conversationReplies.isNotEmpty)
                            const SizedBox(height: 24),
                          if (conversationReplies.isEmpty)
                            _buildEmptyReplies()
                          else
                            ...conversationReplies.map(
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
              status: effectiveStatus,
              statusName: effectiveStatusName,
            ),
            if (canInput)
              _FeedbackChatFooter(
                controller: _replyController,
                placeholder: 'app.user.feedback.problem_placeholder'.tr,
                imagePaths: _replyImagePaths,
                uploading: _replyUploading,
                submitting: _replySubmitting,
                solving: _replySolving,
                resolveLabel: _resolveActionLabel,
                onPickImage: _pickReplyImage,
                onRemoveImage: _removeReplyImage,
                onSend: _sendReply,
                onResolve: _confirmSolveTicket,
              ),
          ],
        );
      }),
    );
  }

  String get _resolveActionLabel => 'app.user.feedback.mark_resolved'.tr;

  FeedbackReply? _initialFeedbackReply(List<FeedbackReply> replies) {
    if (replies.isEmpty) return null;
    final first = replies.first;
    return first.isAdmin ? null : first;
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
            child: CircularProgressIndicator(
              color: _FeedbackDetailStyle.brandBlue,
              strokeWidth: 2.2,
            ),
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

  Widget _buildHeader(
    BuildContext context,
    FeedbackDetail detail, {
    FeedbackReply? initialReply,
  }) {
    final detailContent = detail.context?.trim();
    final replyContent = initialReply?.context?.trim();
    final content = detailContent?.isNotEmpty == true
        ? detailContent
        : replyContent;
    final images = detail.images.isNotEmpty
        ? detail.images
        : initialReply?.images ?? const <String>[];
    final createTime = initialReply?.createTime ?? detail.createTime;
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
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  _formatShortTime(createTime),
                  style: const TextStyle(
                    color: _FeedbackDetailStyle.mutedTextAlt,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    height: 15 / 10,
                  ),
                ),
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
    final content = item.context?.trim() ?? '';
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
                    if (content.isNotEmpty)
                      Text(
                        content,
                        style: const TextStyle(
                          color: _FeedbackDetailStyle.text,
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          height: 22.75 / 14,
                        ),
                      ),
                    if (item.images.isNotEmpty) ...[
                      if (content.isNotEmpty) const SizedBox(height: 12),
                      _FeedbackMessageImages(
                        images: item.images,
                        onPreview: _previewImage,
                        placeholderColor: _FeedbackDetailStyle.fieldSurface,
                        errorIconColor: _FeedbackDetailStyle.mutedTextAlt,
                      ),
                    ],
                    if (content.isEmpty && item.images.isEmpty)
                      const Text(
                        '--',
                        style: TextStyle(
                          color: _FeedbackDetailStyle.text,
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          height: 22.75 / 14,
                        ),
                      ),
                    const SizedBox(height: 8),
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
    final content = item.context?.trim() ?? '';
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
                      _FeedbackMessageImages(
                        images: item.images,
                        onPreview: _previewImage,
                        placeholderColor: const Color.fromRGBO(0, 0, 0, 0.2),
                        errorIconColor: Colors.white,
                      ),
                      if (content.isNotEmpty) const SizedBox(height: 10.88),
                    ],
                    if (content.isNotEmpty)
                      Text(
                        content,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          height: 22.75 / 14,
                        ),
                      )
                    else if (item.images.isEmpty)
                      const Text(
                        '--',
                        style: TextStyle(
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
                      color: _FeedbackDetailStyle.brandBlue,
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

class _FeedbackMessageImages extends StatelessWidget {
  const _FeedbackMessageImages({
    required this.images,
    required this.onPreview,
    required this.placeholderColor,
    required this.errorIconColor,
  });

  final List<String> images;
  final ValueChanged<String> onPreview;
  final Color placeholderColor;
  final Color errorIconColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final entry in images.asMap().entries) ...[
          if (entry.key > 0) const SizedBox(height: 8),
          _FeedbackMessageImage(
            url: entry.value,
            onTap: () => onPreview(entry.value),
            placeholderColor: placeholderColor,
            errorIconColor: errorIconColor,
          ),
        ],
      ],
    );
  }
}

class _FeedbackMessageImage extends StatelessWidget {
  const _FeedbackMessageImage({
    required this.url,
    required this.onTap,
    required this.placeholderColor,
    required this.errorIconColor,
  });

  final String url;
  final VoidCallback onTap;
  final Color placeholderColor;
  final Color errorIconColor;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: GestureDetector(
        onTap: onTap,
        child: CachedNetworkImage(
          imageUrl: url,
          height: 177.78,
          width: double.infinity,
          fit: BoxFit.cover,
          placeholder: (context, _) => ColoredBox(
            color: placeholderColor,
            child: const SizedBox(height: 177.78),
          ),
          errorWidget: (context, _, __) => ColoredBox(
            color: placeholderColor,
            child: SizedBox(
              height: 177.78,
              child: Center(
                child: Icon(
                  Icons.image_not_supported_outlined,
                  color: errorIconColor,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FeedbackHeaderImages extends StatefulWidget {
  const _FeedbackHeaderImages({required this.images, required this.onPreview});

  final List<String> images;
  final ValueChanged<String> onPreview;

  @override
  State<_FeedbackHeaderImages> createState() => _FeedbackHeaderImagesState();
}

class _FeedbackHeaderImagesState extends State<_FeedbackHeaderImages> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final images = widget.images;
    if (images.length == 1) {
      return _FeedbackHeaderImage(
        url: images.first,
        height: 200,
        onTap: () => widget.onPreview(images.first),
      );
    }

    return SizedBox(
      height: 128,
      child: Scrollbar(
        controller: _scrollController,
        thumbVisibility: true,
        trackVisibility: true,
        interactive: true,
        radius: const Radius.circular(999),
        thickness: 3,
        scrollbarOrientation: ScrollbarOrientation.bottom,
        child: ListView.separated(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.only(bottom: 16),
          physics: const BouncingScrollPhysics(),
          itemCount: images.length,
          separatorBuilder: (_, _) => const SizedBox(width: 12),
          itemBuilder: (context, index) {
            final url = images[index];
            return _FeedbackHeaderImage(
              url: url,
              width: 150,
              height: 112,
              onTap: () => widget.onPreview(url),
            );
          },
        ),
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
              child: CircularProgressIndicator(
                color: _FeedbackDetailStyle.brandBlue,
                strokeWidth: 2,
              ),
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
    required this.status,
    required this.statusName,
  });

  final String title;
  final VoidCallback onBack;
  final int? status;
  final String? statusName;

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
                    color: _FeedbackDetailStyle.brandBlueAlt,
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
                      color: _FeedbackDetailStyle.brandBlueAlt,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      height: 28 / 20,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                _FeedbackStatusChip(status: status, statusName: statusName),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FeedbackStatusChip extends StatelessWidget {
  const _FeedbackStatusChip({required this.status, required this.statusName});

  final int? status;
  final String? statusName;

  @override
  Widget build(BuildContext context) {
    final value = status ?? -1;
    final colors = _FeedbackDetailStyle.statusColors(value);
    final label = statusName?.trim().isNotEmpty == true
        ? statusName!.trim()
        : _FeedbackDetailStyle.statusLabel(value);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 150),
      child: Container(
        constraints: const BoxConstraints(minHeight: 34),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _FeedbackDetailStyle.statusIcon(value),
              color: colors.foreground,
              size: 16,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.foreground,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  height: 18 / 13,
                ),
              ),
            ),
          ],
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
  const _FeedbackChatFooter({
    required this.controller,
    required this.placeholder,
    required this.imagePaths,
    required this.uploading,
    required this.submitting,
    required this.solving,
    required this.resolveLabel,
    required this.onPickImage,
    required this.onRemoveImage,
    required this.onSend,
    required this.onResolve,
  });

  final TextEditingController controller;
  final String placeholder;
  final List<String> imagePaths;
  final bool uploading;
  final bool submitting;
  final bool solving;
  final String resolveLabel;
  final VoidCallback onPickImage;
  final ValueChanged<int> onRemoveImage;
  final VoidCallback onSend;
  final VoidCallback onResolve;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final disabled = uploading || submitting || solving;
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
                Align(
                  alignment: Alignment.centerRight,
                  child: _FeedbackResolveButton(
                    label: resolveLabel,
                    loading: solving,
                    onTap: disabled ? null : onResolve,
                  ),
                ),
                const SizedBox(height: 12),
                if (imagePaths.isNotEmpty) ...[
                  _FeedbackReplyImageStrip(
                    paths: imagePaths,
                    onRemove: disabled ? null : onRemoveImage,
                  ),
                  const SizedBox(height: 12),
                ],
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
                        onPressed: disabled ? null : onPickImage,
                        visualDensity: VisualDensity.compact,
                        icon: uploading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  color: _FeedbackDetailStyle.brandBlue,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(
                                Icons.attach_file_rounded,
                                color: _FeedbackDetailStyle.mutedTextAlt,
                                size: 20,
                              ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: TextField(
                          controller: controller,
                          enabled: !submitting,
                          minLines: 1,
                          maxLines: 1,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) {
                            if (!disabled) onSend();
                          },
                          style: const TextStyle(
                            color: _FeedbackDetailStyle.text,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            height: 20 / 14,
                          ),
                          decoration: InputDecoration(
                            hintText: placeholder,
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                            hintStyle: const TextStyle(
                              color: Color.fromRGBO(117, 118, 132, 0.6),
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: disabled ? null : onSend,
                        child: Opacity(
                          opacity: disabled ? 0.55 : 1,
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
                            child: submitting
                                ? const Padding(
                                    padding: EdgeInsets.all(10),
                                    child: CircularProgressIndicator(
                                      color: _FeedbackDetailStyle.fieldSurface,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(
                                    Icons.arrow_forward_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
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

class _FeedbackReplyImageStrip extends StatelessWidget {
  const _FeedbackReplyImageStrip({required this.paths, required this.onRemove});

  final List<String> paths;
  final ValueChanged<int>? onRemove;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 62,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: paths.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          return _FeedbackReplyImageTile(
            path: paths[index],
            onRemove: onRemove == null ? null : () => onRemove!(index),
          );
        },
      ),
    );
  }
}

class _FeedbackResolveButton extends StatelessWidget {
  const _FeedbackResolveButton({
    required this.label,
    required this.loading,
    required this.onTap,
  });

  final String label;
  final bool loading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: enabled ? 1 : 0.58,
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFE4F7EA),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (loading)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    color: Color(0xFF16A34A),
                    strokeWidth: 2,
                  ),
                )
              else
                const Icon(
                  Icons.check_circle_outline_rounded,
                  color: Color(0xFF16A34A),
                  size: 16,
                ),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF15803D),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  height: 18 / 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeedbackReplyImageTile extends StatelessWidget {
  const _FeedbackReplyImageTile({required this.path, required this.onRemove});

  final String path;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 62,
      height: 62,
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                File(path),
                fit: BoxFit.cover,
                errorBuilder: (context, _, __) => const ColoredBox(
                  color: _FeedbackDetailStyle.fieldSurface,
                  child: Center(
                    child: Icon(
                      Icons.image_not_supported_outlined,
                      color: _FeedbackDetailStyle.mutedTextAlt,
                      size: 18,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 3,
            right: 3,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.58),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close_rounded,
                  color: Colors.white,
                  size: 14,
                ),
              ),
            ),
          ),
        ],
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
  static const brandBlueAlt = Color(0xFF1E3A8A);
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

  static double footerHeight(BuildContext context, int imageCount) {
    final previewHeight = imageCount > 0 ? 74.0 : 0.0;
    return 138 + previewHeight + MediaQuery.paddingOf(context).bottom;
  }

  static ({Color background, Color foreground}) statusColors(int status) {
    return switch (status) {
      0 => (
        background: const Color(0xFFFEF3C7),
        foreground: const Color(0xFF92400E),
      ),
      1 => (
        background: const Color(0xFFFEF3C7),
        foreground: const Color(0xFF92400E),
      ),
      2 => (
        background: const Color(0xFFE4F7EA),
        foreground: const Color(0xFF15803D),
      ),
      3 => (
        background: const Color(0xFFFEE2E2),
        foreground: const Color(0xFF991B1B),
      ),
      _ => (
        background: const Color(0xFFE9EEF1),
        foreground: const Color(0xFF394047),
      ),
    };
  }

  static IconData statusIcon(int status) {
    return switch (status) {
      0 => Icons.history_rounded,
      1 => Icons.history_rounded,
      2 => Icons.check_circle_outline_rounded,
      3 => Icons.error_outline_rounded,
      _ => Icons.help_outline_rounded,
    };
  }

  static String statusLabel(int status) {
    final isZh =
        Get.locale?.languageCode.toLowerCase().startsWith('zh') == true;
    return switch (status) {
      0 => isZh ? '待处理' : 'Pending',
      1 => isZh ? '已回复' : 'Replied',
      2 => isZh ? '已解决' : 'Resolved',
      3 => isZh ? '已关闭' : 'Closed',
      _ => isZh ? '未知' : 'Unknown',
    };
  }
}
