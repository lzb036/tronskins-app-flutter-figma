import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:tronskins_app/api/model/feedback/feedback_models.dart';
import 'package:tronskins_app/common/utils/app_snackbar.dart';
import 'package:tronskins_app/common/widgets/login_required_prompt.dart';
import 'package:tronskins_app/common/widgets/settings_style_app_bar.dart';
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

  String _formatTime(int? value) {
    if (value == null) return '--';
    final ts = value < 1000000000000 ? value * 1000 : value;
    return DateFormat(
      'yyyy-MM-dd HH:mm:ss',
    ).format(DateTime.fromMillisecondsSinceEpoch(ts));
  }

  void _createFeedback() {
    if (!userController.isLoggedIn.value) {
      return;
    }
    if (controller.hasUnfinishedFeedback) {
      AppSnackbar.info('app.user.feedback.have_unfinished_feedback'.tr);
      return;
    }
    Get.toNamed(Routers.FEEDBACK_CREATE);
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final loggedIn = userController.isLoggedIn.value;
      return Scaffold(
        backgroundColor: _FeedbackStyle.pageBackground,
        appBar: SettingsStyleAppBar(
          title: Text('app.user.menu.feedback'.tr),
          actions: loggedIn
              ? [
                  IconButton(
                    icon: const Icon(
                      Icons.add_circle_outline,
                      color: _FeedbackStyle.brandBlue,
                    ),
                    onPressed: _createFeedback,
                  ),
                ]
              : const [],
        ),
        body: loggedIn ? _buildFeedbackList() : _buildLoginPrompt(),
      );
    });
  }

  Widget _buildLoginPrompt() {
    return const LoginRequiredPrompt();
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
    return RefreshIndicator(
      color: _FeedbackStyle.brandBlue,
      backgroundColor: Colors.white,
      strokeWidth: 2.2,
      displacement: 22,
      edgeOffset: 2,
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
            const SliverFillRemaining(
              hasScrollBody: false,
              child: _FeedbackEmptyState(),
            )
          else ...[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
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
                separatorBuilder: (_, _) => const SizedBox(height: 16),
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
  }

  Widget _buildLoadMoreFooter({required bool loading, required bool hasMore}) {
    if (loading && hasMore) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(20, 16, 20, 18),
        child: _FeedbackTicketSkeleton(),
      );
    }

    if (!hasMore) {
      return const ListEndTip(padding: EdgeInsets.fromLTRB(8, 18, 8, 20));
    }

    return const SizedBox(height: 20);
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
    final colors = _FeedbackStyle.statusColors(status);
    final title = item.title?.trim();
    final content = item.context?.trim();
    return DecoratedBox(
      decoration: _FeedbackStyle.cardDecoration,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 15, 14, 15),
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
                    _FeedbackStyle.statusIcon(status),
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
                                color: _FeedbackStyle.text,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                height: 1.25,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          _StatusChip(
                            status: status,
                            label: item.statusName ?? '',
                          ),
                        ],
                      ),
                      if (content?.isNotEmpty == true) ...[
                        const SizedBox(height: 9),
                        Text(
                          content!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _FeedbackStyle.secondaryText,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            height: 1.45,
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Icon(
                            Icons.schedule_rounded,
                            size: 15,
                            color: _FeedbackStyle.mutedText.withValues(
                              alpha: 0.82,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              formattedTime,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _FeedbackStyle.secondaryText,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                height: 1.2,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: _FeedbackStyle.softSurface,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Icon(
                              Icons.chevron_right_rounded,
                              color: _FeedbackStyle.brandBlue,
                              size: 22,
                            ),
                          ),
                        ],
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

class _FeedbackEmptyState extends StatelessWidget {
  const _FeedbackEmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 34, 20, 24),
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
                const SizedBox(height: 9),
                Text(
                  _emptySubtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _FeedbackStyle.secondaryText.withValues(alpha: 0.84),
                    fontSize: 14,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String get _emptySubtitle {
    final languageCode = Get.locale?.languageCode.toLowerCase() ?? '';
    if (languageCode.startsWith('zh')) {
      return '下拉刷新获取最新反馈';
    }
    return 'Pull down to refresh your feedback list.';
  }
}

class _FeedbackSkeletonList extends StatelessWidget {
  const _FeedbackSkeletonList();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 5,
      itemBuilder: (_, _) => const _FeedbackTicketSkeleton(),
      separatorBuilder: (_, _) => const SizedBox(height: 16),
    );
  }
}

class _FeedbackTicketSkeleton extends StatelessWidget {
  const _FeedbackTicketSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 15, 14, 15),
      decoration: _FeedbackStyle.cardDecoration,
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FeedbackSkeletonBox(width: 44, height: 44, radius: 14),
          SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _FeedbackSkeletonBox(height: 18, radius: 9),
                    ),
                    SizedBox(width: 42),
                    _FeedbackSkeletonBox(width: 64, height: 28, radius: 999),
                  ],
                ),
                SizedBox(height: 11),
                _FeedbackSkeletonBox(height: 13, radius: 7),
                SizedBox(height: 8),
                _FeedbackSkeletonBox(width: 172, height: 13, radius: 7),
                SizedBox(height: 16),
                Row(
                  children: [
                    _FeedbackSkeletonBox(width: 15, height: 15, radius: 999),
                    SizedBox(width: 7),
                    _FeedbackSkeletonBox(width: 150, height: 13, radius: 7),
                    Spacer(),
                    _FeedbackSkeletonBox(width: 28, height: 28, radius: 999),
                  ],
                ),
              ],
            ),
          ),
        ],
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

  static final softShadow = [
    BoxShadow(
      color: brandBlue.withValues(alpha: 0.045),
      blurRadius: 22,
      offset: const Offset(0, 12),
    ),
  ];

  static final cardDecoration = BoxDecoration(
    color: card,
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: border),
    boxShadow: softShadow,
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
