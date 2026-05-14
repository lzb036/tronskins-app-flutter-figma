import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:tronskins_app/api/model/feedback/feedback_models.dart';
import 'package:tronskins_app/common/utils/app_snackbar.dart';
import 'package:tronskins_app/common/widgets/login_required_prompt.dart';
import 'package:tronskins_app/components/layout/list_end_tip.dart';
import 'package:tronskins_app/controllers/help/feedback_controller.dart';
import 'package:tronskins_app/controllers/user/user_controller.dart';
import 'package:tronskins_app/routes/app_routes.dart';

class FeedbackListPage extends StatefulWidget {
  const FeedbackListPage({super.key});

  @override
  State<FeedbackListPage> createState() => _FeedbackListPageState();
}

class _FeedbackListPageState extends State<FeedbackListPage> {
  final FeedbackController controller = Get.isRegistered<FeedbackController>()
      ? Get.find<FeedbackController>()
      : Get.put(FeedbackController());
  final UserController userController = Get.find<UserController>();
  final ScrollController _scrollController = ScrollController();
  Worker? _loginWorker;

  @override
  void initState() {
    super.initState();
    if (userController.isLoggedIn.value) {
      controller.loadTickets(refresh: true);
    }
    _scrollController.addListener(_handleScroll);
    _loginWorker = ever<bool>(userController.isLoggedIn, (loggedIn) {
      if (loggedIn) {
        controller.loadTickets(refresh: true);
      } else {
        controller.resetTickets();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _loginWorker?.dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 120) {
      controller.loadTickets();
    }
  }

  void _createFeedback() {
    if (!userController.isLoggedIn.value) return;
    if (controller.hasUnfinishedFeedback) {
      AppSnackbar.info('app.user.feedback.have_unfinished_feedback'.tr);
      return;
    }
    Get.toNamed(Routers.FEEDBACK_CREATE);
  }

  String _formatTime(int? value) {
    if (value == null) return '--';
    final ts = value < 1000000000000 ? value * 1000 : value;
    return DateFormat(
      'yyyy-MM-dd HH:mm:ss',
    ).format(DateTime.fromMillisecondsSinceEpoch(ts));
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final loggedIn = userController.isLoggedIn.value;
      return Scaffold(
        backgroundColor: _FeedbackStyle.pageBackground,
        body: Stack(
          children: [
            Positioned.fill(
              child: loggedIn ? _buildFeedbackList() : _buildLoginPrompt(),
            ),
            _FeedbackTopBar(
              title: 'app.user.menu.feedback'.tr,
              onBack: () => Navigator.maybePop(context),
              onAdd: loggedIn ? _createFeedback : null,
            ),
          ],
        ),
      );
    });
  }

  Widget _buildLoginPrompt() {
    return Builder(
      builder: (context) {
        final topPadding = _FeedbackStyle.contentTopPadding(context);
        return Padding(
          padding: EdgeInsets.only(
            top: topPadding,
            bottom: _FeedbackStyle.contentBottomPadding,
          ),
          child: const LoginRequiredPrompt(),
        );
      },
    );
  }

  Widget _buildFeedbackList() {
    return Obx(() {
      final loading = controller.listLoading.value;
      final refreshing = controller.listRefreshing.value;
      final initialized = controller.listInitialized.value;
      final list = controller.tickets;
      final showSkeleton =
          !initialized || refreshing || (loading && list.isEmpty);

      return showSkeleton
          ? const _FeedbackSkeletonList()
          : _buildTicketScrollView(list: list);
    });
  }

  Widget _buildTicketScrollView({required List<FeedbackTicket> list}) {
    return Builder(
      builder: (context) {
        return RefreshIndicator(
          color: _FeedbackStyle.brandBlue,
          backgroundColor: Colors.white,
          strokeWidth: 2.2,
          displacement: 22,
          edgeOffset: _FeedbackStyle.topBarHeight(context),
          elevation: 0,
          notificationPredicate: (notification) => notification.depth == 0,
          onRefresh: () => controller.loadTickets(refresh: true),
          child: CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(
              parent: ClampingScrollPhysics(),
            ),
            slivers: [
              if (list.isEmpty)
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    _FeedbackStyle.contentTopPadding(context),
                    16,
                    _FeedbackStyle.contentBottomPadding,
                  ),
                  sliver: const SliverFillRemaining(
                    hasScrollBody: false,
                    child: _FeedbackEmptyState(),
                  ),
                )
              else ...[
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    _FeedbackStyle.contentTopPadding(context),
                    16,
                    0,
                  ),
                  sliver: SliverList.separated(
                    itemCount: list.length,
                    itemBuilder: (context, index) {
                      final item = list[index];
                      return _FeedbackTicketCard(
                        item: item,
                        formattedTime: _formatTime(item.createTime),
                        onTap: () => Get.toNamed(
                          Routers.FEEDBACK_DETAIL,
                          arguments: {
                            'id': item.id,
                            'status': item.status,
                            'statusName': item.statusName,
                          },
                        ),
                      );
                    },
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                  ),
                ),
                SliverToBoxAdapter(
                  child: _buildLoadMoreFooter(
                    loading: controller.listLoadingMore.value,
                    hasMore: controller.hasMore,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildLoadMoreFooter({required bool loading, required bool hasMore}) {
    if (loading && hasMore) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: _FeedbackTicketSkeleton(),
      );
    }

    if (!hasMore) {
      return ListEndTip(
        padding: EdgeInsets.fromLTRB(
          8,
          18,
          8,
          _FeedbackStyle.contentBottomPadding,
        ),
      );
    }

    return const SizedBox(height: _FeedbackStyle.contentBottomPadding);
  }
}

class _FeedbackTicketCard extends StatelessWidget {
  const _FeedbackTicketCard({
    required this.item,
    required this.formattedTime,
    required this.onTap,
  });

  final FeedbackTicket item;
  final String formattedTime;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = item.status ?? -1;
    final title = item.title?.trim();
    final content = item.context?.trim();
    return Container(
      decoration: _FeedbackStyle.ticketCardDecoration,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: _FeedbackStyle.ticketCardRadius,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              height: 140.25,
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
                            color: _FeedbackStyle.text,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            height: 22.5 / 15,
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      _StatusChip(status: status, label: item.statusName ?? ''),
                    ],
                  ),
                  const SizedBox(height: 16.25),
                  if (content?.isNotEmpty == true)
                    Text(
                      content!,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _FeedbackStyle.secondaryText,
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        height: 22.75 / 14,
                        letterSpacing: 0,
                      ),
                    )
                  else
                    const SizedBox(height: 68.25),
                  const Spacer(),
                  Row(
                    children: [
                      Icon(
                        Icons.schedule_rounded,
                        size: 10,
                        color: _FeedbackStyle.mutedText.withValues(alpha: 0.8),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        formattedTime,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _FeedbackStyle.timeText,
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          height: 18 / 12,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FeedbackTopBar extends StatelessWidget {
  const _FeedbackTopBar({
    required this.title,
    required this.onBack,
    required this.onAdd,
  });

  final String title;
  final VoidCallback onBack;
  final VoidCallback? onAdd;

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
            height: _FeedbackStyle.topBarHeight(context),
            padding: EdgeInsets.fromLTRB(24, topInset, 24, 0),
            color: _FeedbackStyle.glassTopBar,
            child: Row(
              children: [
                Material(
                  color: Colors.transparent,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onBack,
                    child: const SizedBox(
                      width: 32,
                      height: 56,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Icon(
                          Icons.arrow_back,
                          color: _FeedbackStyle.brandBlueAlt,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _FeedbackStyle.brandBlueAlt,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      height: 28 / 20,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                if (onAdd == null)
                  const SizedBox(width: 40, height: 40)
                else
                  IconButton(
                    onPressed: onAdd,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 40,
                      height: 40,
                    ),
                    icon: const Icon(
                      Icons.add_circle_outline_rounded,
                      color: _FeedbackStyle.brandBlueAlt,
                      size: 24,
                    ),
                    tooltip: 'app.user.feedback.text'.tr,
                  ),
              ],
            ),
          ),
        ),
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
    final colors = _FeedbackStyle.statusColors(status);
    final resolvedLabel = label.trim().isNotEmpty
        ? label.trim()
        : _FeedbackStyle.statusLabel(status);
    return Container(
      constraints: const BoxConstraints(minHeight: 24),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _FeedbackStyle.statusIcon(status),
            color: colors.foreground,
            size: 12,
          ),
          const SizedBox(width: 6),
          Text(
            resolvedLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colors.foreground,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 16 / 12,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedbackEmptyState extends StatelessWidget {
  const _FeedbackEmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(26, 34, 26, 24),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 42),
            decoration: _FeedbackStyle.cardDecoration,
            child: Column(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: _FeedbackStyle.softBlue,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(
                    Icons.forum_outlined,
                    color: _FeedbackStyle.brandBlue,
                    size: 30,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'app.common.no_data'.tr,
                  style: const TextStyle(
                    color: _FeedbackStyle.text,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedbackSkeletonList extends StatelessWidget {
  const _FeedbackSkeletonList();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(
        16,
        _FeedbackStyle.contentTopPadding(context),
        16,
        _FeedbackStyle.contentBottomPadding,
      ),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 5,
      itemBuilder: (_, _) => const _FeedbackTicketSkeleton(),
      separatorBuilder: (_, _) => const SizedBox(height: 12),
    );
  }
}

class _FeedbackTicketSkeleton extends StatelessWidget {
  const _FeedbackTicketSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _FeedbackStyle.ticketCardDecoration,
      child: const SizedBox(
        height: 140.25,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: _FeedbackSkeletonBox(height: 18, radius: 9)),
                SizedBox(width: 42),
                _FeedbackSkeletonBox(width: 78, height: 24, radius: 999),
              ],
            ),
            SizedBox(height: 18),
            _FeedbackSkeletonBox(height: 14, radius: 7),
            SizedBox(height: 9),
            _FeedbackSkeletonBox(height: 14, radius: 7),
            SizedBox(height: 9),
            _FeedbackSkeletonBox(width: 220, height: 14, radius: 7),
            Spacer(),
            Row(
              children: [
                _FeedbackSkeletonBox(width: 10, height: 10, radius: 999),
                SizedBox(width: 6),
                _FeedbackSkeletonBox(width: 99, height: 12, radius: 6),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FeedbackSkeletonBox extends StatelessWidget {
  const _FeedbackSkeletonBox({
    this.width,
    required this.height,
    required this.radius,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: _FeedbackStyle.skeleton,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class _FeedbackStyle {
  const _FeedbackStyle._();

  static const pageBackground = Color(0xFFF5F5F5);
  static const card = Color(0xFFFFFFFF);
  static const text = Color(0xFF191C1E);
  static const secondaryText = Color(0xFF4B5563);
  static const mutedText = Color(0xFF6B7280);
  static const timeText = Color(0xFF9CA3AF);
  static const border = Color(0x00000000);
  static const brandBlue = Color(0xFF00288E);
  static const brandBlueAlt = Color(0xFF1E3A8A);
  static const softBlue = Color(0xFFE0E7FF);
  static const skeleton = Color(0xFFE8EEF4);
  static const glassTopBar = Color.fromRGBO(248, 250, 252, 0.7);
  static const contentBottomPadding = 24.0;

  static const ticketCardRadius = BorderRadius.zero;
  static final cardRadius = BorderRadius.circular(12);

  static final ticketCardDecoration = BoxDecoration(
    color: card,
    borderRadius: ticketCardRadius,
    border: Border.all(color: border),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.04),
        blurRadius: 4,
        offset: const Offset(0, 2),
      ),
    ],
  );

  static final cardDecoration = BoxDecoration(
    color: card,
    borderRadius: cardRadius,
    border: Border.all(color: border),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.04),
        blurRadius: 4,
        offset: const Offset(0, 2),
      ),
    ],
  );

  static double topBarHeight(BuildContext context) {
    return MediaQuery.paddingOf(context).top + 56;
  }

  static double contentTopPadding(BuildContext context) {
    return topBarHeight(context) + 16;
  }

  static ({Color background, Color foreground, Color border}) statusColors(
    int status,
  ) {
    return switch (status) {
      0 => (
        background: const Color(0xFFFEF3C7),
        foreground: const Color(0xFF92400E),
        border: const Color(0x00FFFFFF),
      ),
      1 => (
        background: const Color(0xFFFEF3C7),
        foreground: const Color(0xFF92400E),
        border: const Color(0x00FFFFFF),
      ),
      2 => (
        background: const Color(0xFFD1FAE5),
        foreground: const Color(0xFF065F46),
        border: const Color(0x00FFFFFF),
      ),
      3 => (
        background: const Color(0xFFFEE2E2),
        foreground: const Color(0xFF991B1B),
        border: const Color(0x00FFFFFF),
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
