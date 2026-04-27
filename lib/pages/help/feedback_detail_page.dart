import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:tronskins_app/common/widgets/settings_style_app_bar.dart';
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
  String? _statusLabel;
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
      _statusLabel = args['statusName']?.toString();
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

  String _formatTime(int? value) {
    if (value == null) return '--';
    final ts = value < 1000000000000 ? value * 1000 : value;
    return DateFormat(
      'yyyy-MM-dd HH:mm:ss',
    ).format(DateTime.fromMillisecondsSinceEpoch(ts));
  }

  String _resolveStatusLabel(FeedbackDetail detail) {
    final detailLabel = detail.statusName?.trim();
    if (detailLabel != null && detailLabel.isNotEmpty) {
      return detailLabel;
    }
    final routeLabel = _statusLabel?.trim();
    if (routeLabel != null && routeLabel.isNotEmpty) {
      return routeLabel;
    }
    return _FeedbackDetailStyle.statusLabel(detail.status ?? _status ?? -1);
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
      appBar: SettingsStyleAppBar(title: Text('app.user.feedback.details'.tr)),
      bottomNavigationBar: Obx(() {
        final effectiveStatus = controller.detail.value?.status ?? _status;
        final closed = effectiveStatus == 2 || effectiveStatus == 3;
        return closed ? const SizedBox.shrink() : _buildBottomActionBar();
      }),
      body: Obx(() {
        final loading = controller.replyLoading.value;
        final detailLoading = controller.detailLoading.value;
        final list = controller.replies;
        final detail = controller.detail.value;
        final showLoadingFooter = loading && list.isNotEmpty;
        final showNoMoreFooter =
            list.isNotEmpty && !loading && !controller.repliesHasMore;
        final showSkeleton =
            _refreshing ||
            (detailLoading && detail == null) ||
            (loading && list.isEmpty);
        return RefreshIndicator(
          color: _FeedbackDetailStyle.brandBlue,
          backgroundColor: Colors.white,
          strokeWidth: 2.2,
          onRefresh: _refreshDetail,
          child: ListView(
            controller: _scrollController,
            physics: showSkeleton
                ? const NeverScrollableScrollPhysics()
                : const AlwaysScrollableScrollPhysics(
                    parent: ClampingScrollPhysics(),
                  ),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: showSkeleton
                ? [
                    _buildHeaderLoading(context),
                    const SizedBox(height: 14),
                    _buildConversationLoading(context),
                  ]
                : [
                    if (detail != null) _buildHeader(context, detail),
                    if (detail != null) const SizedBox(height: 14),
                    if (list.isEmpty)
                      _buildEmptyReplies()
                    else
                      ...list.map((item) => _buildReplyBubble(context, item)),
                    _buildLoadMoreFooter(
                      showLoading: showLoadingFooter,
                      showNoMore: showNoMoreFooter,
                    ),
                  ],
          ),
        );
      }),
    );
  }

  Widget _buildBottomActionBar() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: _FeedbackDetailStyle.border)),
          boxShadow: _FeedbackDetailStyle.bottomShadow,
        ),
        child: Row(
          children: [
            Expanded(
              child: _DetailActionButton(
                label: _bottomActionLabel(resolved: true),
                icon: Icons.check_circle_outline_rounded,
                onPressed: _confirmSolveTicket,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _DetailActionButton(
                label: _bottomActionLabel(resolved: false),
                icon: Icons.add_comment_outlined,
                filled: true,
                onPressed: _addReply,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _bottomActionLabel({required bool resolved}) {
    final isZh =
        Get.locale?.languageCode.toLowerCase().startsWith('zh') == true;
    if (resolved) {
      return isZh ? '解决' : 'Solved';
    }
    return isZh ? '补充' : 'Reply';
  }

  Widget _buildEmptyReplies() {
    return Container(
      margin: const EdgeInsets.only(top: 2, bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
      decoration: _FeedbackDetailStyle.cardDecoration,
      child: Column(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: _FeedbackDetailStyle.softBlue,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.chat_bubble_outline_rounded,
              color: _FeedbackDetailStyle.brandBlue,
              size: 26,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'app.common.no_data'.tr,
            style: const TextStyle(
              color: _FeedbackDetailStyle.text,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
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
    return Container(
      decoration: _FeedbackDetailStyle.cardDecoration,
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLoadingLine(context, width: 44, height: 44, radius: 14),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildLoadingLine(
                        context,
                        width: double.infinity,
                        height: 18,
                      ),
                    ),
                    const SizedBox(width: 42),
                    _buildLoadingLine(
                      context,
                      width: 64,
                      height: 28,
                      radius: 999,
                    ),
                  ],
                ),
                const SizedBox(height: 13),
                _buildLoadingLine(context, width: 150, height: 13),
                const SizedBox(height: 17),
                _buildLoadingLine(context, width: double.infinity, height: 14),
                const SizedBox(height: 8),
                _buildLoadingLine(context, width: 220, height: 14),
              ],
            ),
          ),
        ],
      ),
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
    final statusLabel = _resolveStatusLabel(detail);
    final status = detail.status ?? _status ?? -1;
    final colors = _FeedbackDetailStyle.statusColors(status);
    final title = detail.title?.trim();
    final content = detail.context?.trim();
    return Container(
      decoration: _FeedbackDetailStyle.cardDecoration,
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: colors.background,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colors.border),
            ),
            child: Icon(
              _FeedbackDetailStyle.statusIcon(status),
              color: colors.foreground,
              size: 22,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        title?.isNotEmpty == true ? title! : '--',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _FeedbackDetailStyle.text,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          height: 1.22,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _StatusChip(status: status, label: statusLabel),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.schedule_rounded,
                      size: 15,
                      color: _FeedbackDetailStyle.mutedText.withValues(
                        alpha: 0.82,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _formatTime(detail.createTime),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _FeedbackDetailStyle.secondaryText,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ],
                ),
                if (content?.isNotEmpty == true) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
                    decoration: BoxDecoration(
                      color: _FeedbackDetailStyle.softSurface,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      content!,
                      style: const TextStyle(
                        color: _FeedbackDetailStyle.text,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        height: 1.48,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReplyBubble(BuildContext context, FeedbackReply item) {
    final isAdmin = item.isAdmin == true;
    final bubbleColor = isAdmin
        ? _FeedbackDetailStyle.card
        : _FeedbackDetailStyle.userBubble;
    final borderColor = isAdmin
        ? _FeedbackDetailStyle.border
        : _FeedbackDetailStyle.userBubbleBorder;
    final avatarColor = isAdmin
        ? _FeedbackDetailStyle.softSurface
        : _FeedbackDetailStyle.softBlue;
    final iconColor = isAdmin
        ? _FeedbackDetailStyle.secondaryText
        : _FeedbackDetailStyle.brandBlue;
    final title = isAdmin
        ? 'app.user.feedback.customer_service_reply'.tr
        : 'app.user.feedback.text_before'.tr;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(15, 14, 15, 15),
      decoration: BoxDecoration(
        color: bubbleColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
        boxShadow: isAdmin ? _FeedbackDetailStyle.cardShadow : const [],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: avatarColor,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              isAdmin
                  ? Icons.support_agent_rounded
                  : Icons.person_outline_rounded,
              color: iconColor,
              size: 21,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _FeedbackDetailStyle.text,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          height: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatTime(item.createTime),
                      style: const TextStyle(
                        color: _FeedbackDetailStyle.secondaryText,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  item.context ?? '',
                  style: const TextStyle(
                    color: _FeedbackDetailStyle.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    height: 1.48,
                  ),
                ),
                if (item.images.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 9,
                    runSpacing: 9,
                    children: item.images.map<Widget>((url) {
                      return GestureDetector(
                        onTap: () => _previewImage(url),
                        child: Container(
                          width: 92,
                          height: 92,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: _FeedbackDetailStyle.border,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(13),
                            child: CachedNetworkImage(
                              imageUrl: url,
                              fit: BoxFit.cover,
                              placeholder: (context, _) => const Center(
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    color: _FeedbackDetailStyle.brandBlue,
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                              errorWidget: (context, _, __) => const Icon(
                                Icons.image_not_supported_outlined,
                                color: _FeedbackDetailStyle.mutedText,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
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

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status, required this.label});

  final int status;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = _FeedbackDetailStyle.statusColors(status);
    final resolvedLabel = label.trim().isNotEmpty
        ? label.trim()
        : _FeedbackDetailStyle.statusLabel(status);
    return Container(
      constraints: const BoxConstraints(minWidth: 64),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.border),
      ),
      alignment: Alignment.center,
      child: Text(
        resolvedLabel,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: colors.foreground,
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
          height: 1,
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
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(15, 14, 15, 15),
      decoration: BoxDecoration(
        color: bubbleColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
        boxShadow: isAdmin ? _FeedbackDetailStyle.cardShadow : const [],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          loadingLine(38, 38),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    loadingLine(96, 12),
                    const SizedBox(width: 8),
                    loadingLine(72, 10),
                  ],
                ),
                const SizedBox(height: 12),
                loadingLine(double.infinity, 14),
                const SizedBox(height: 8),
                loadingLine(210, 14),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailActionButton extends StatelessWidget {
  const _DetailActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.filled = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final gradient = filled
        ? const LinearGradient(colors: [Color(0xFF2644C2), Color(0xFF3B82F6)])
        : null;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: filled ? null : Colors.white,
        gradient: gradient,
        borderRadius: BorderRadius.circular(14),
        border: filled
            ? null
            : Border.all(color: _FeedbackDetailStyle.brandBlue),
        boxShadow: filled ? _FeedbackDetailStyle.buttonShadow : const [],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onPressed,
          child: SizedBox(
            height: 50,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 19,
                  color: filled ? Colors.white : _FeedbackDetailStyle.brandBlue,
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.visible,
                  softWrap: false,
                  style: TextStyle(
                    color: filled
                        ? Colors.white
                        : _FeedbackDetailStyle.brandBlue,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    height: 1,
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

class _FeedbackDetailStyle {
  const _FeedbackDetailStyle._();

  static const pageBackground = Color(0xFFF7F9FB);
  static const card = Color(0xFFFFFFFF);
  static const text = Color(0xFF191C1E);
  static const secondaryText = Color(0xFF4B5563);
  static const mutedText = Color(0xFF6B7280);
  static const border = Color(0xFFE6E8EA);
  static const brandBlue = Color(0xFF00288E);
  static const softBlue = Color(0xFFEAF0FF);
  static const softSurface = Color(0xFFF1F5F9);
  static const skeleton = Color(0xFFE8EEF4);
  static const userBubble = Color(0xFFEAF4F8);
  static const userBubbleBorder = Color(0xFFC8DDE7);
  static const userSkeleton = Color(0xFFD4E5ED);

  static final cardShadow = [
    BoxShadow(
      color: brandBlue.withValues(alpha: 0.045),
      blurRadius: 22,
      offset: const Offset(0, 12),
    ),
  ];

  static final bottomShadow = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.055),
      blurRadius: 18,
      offset: const Offset(0, -8),
    ),
  ];

  static final buttonShadow = [
    BoxShadow(
      color: brandBlue.withValues(alpha: 0.20),
      blurRadius: 18,
      offset: const Offset(0, 8),
    ),
  ];

  static final cardDecoration = BoxDecoration(
    color: card,
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: border),
    boxShadow: cardShadow,
  );

  static ({Color background, Color foreground, Color border}) statusColors(
    int status,
  ) {
    return switch (status) {
      0 => (
        background: const Color(0xFFFFF4DE),
        foreground: const Color(0xFFB45309),
        border: const Color(0xFFF6D59A),
      ),
      1 => (
        background: softBlue,
        foreground: brandBlue,
        border: const Color(0xFFC9D7FF),
      ),
      2 => (
        background: const Color(0xFFE8F7EE),
        foreground: const Color(0xFF15803D),
        border: const Color(0xFFBFE7CD),
      ),
      3 => (
        background: const Color(0xFFEFF2F5),
        foreground: const Color(0xFF56616D),
        border: const Color(0xFFD7DEE5),
      ),
      _ => (
        background: const Color(0xFFE9EEF1),
        foreground: const Color(0xFF394047),
        border: const Color(0xFFD0D7DC),
      ),
    };
  }

  static IconData statusIcon(int status) {
    return switch (status) {
      0 => Icons.hourglass_top_rounded,
      1 => Icons.autorenew_rounded,
      2 => Icons.check_circle_rounded,
      3 => Icons.lock_rounded,
      _ => Icons.help_outline_rounded,
    };
  }

  static String statusLabel(int status) {
    final isZh =
        Get.locale?.languageCode.toLowerCase().startsWith('zh') == true;
    return switch (status) {
      0 => isZh ? '待处理' : 'Pending',
      1 => isZh ? '处理中' : 'Processing',
      2 => isZh ? '已解决' : 'Resolved',
      3 => isZh ? '已关闭' : 'Closed',
      _ => isZh ? '未知' : 'Unknown',
    };
  }
}
