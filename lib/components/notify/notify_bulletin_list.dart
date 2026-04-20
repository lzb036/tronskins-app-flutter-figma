import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:tronskins_app/api/model/notify/notify_models.dart';
import 'package:tronskins_app/components/layout/list_end_tip.dart';
import 'package:tronskins_app/controllers/user/notify_controller.dart';
import 'package:tronskins_app/routes/app_routes.dart';

class NotifyBulletinList extends StatefulWidget {
  const NotifyBulletinList({super.key, required this.controller});

  final NotifyController controller;

  @override
  State<NotifyBulletinList> createState() => _NotifyBulletinListState();
}

class _NotifyBulletinListState extends State<NotifyBulletinList> {
  final ScrollController _scrollController = ScrollController();
  static const int _skeletonCount = 4;
  static const int _loadMoreSkeletonCount = 2;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) {
      return;
    }
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 120) {
      widget.controller.loadNoticeList();
    }
  }

  String _formatTime(int? value) {
    if (value == null) {
      return '--';
    }
    final ts = value < 1000000000000 ? value * 1000 : value;
    return DateFormat(
      'yyyy-MM-dd HH:mm:ss',
    ).format(DateTime.fromMillisecondsSinceEpoch(ts));
  }

  Widget _buildNoticeCard(NoticeMessageItem item) {
    final isUnread = !item.isRead;
    final time = _formatTime(item.createTime);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isUnread
              ? const Color.fromRGBO(22, 163, 74, 0.18)
              : const Color(0xFFE2E8F0),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(15, 23, 42, 0.04),
            blurRadius: 18,
            spreadRadius: -14,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () async {
            await widget.controller.readNotice(item);
            final id = item.id;
            if (id != null) {
              Get.toNamed(Routers.NOTICE_DETAIL, arguments: id);
            }
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: isUnread
                        ? const Color.fromRGBO(34, 197, 94, 0.12)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.campaign_outlined,
                    size: 20,
                    color: isUnread
                        ? const Color(0xFF15803D)
                        : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF0F172A),
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          height: 22 / 15,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color.fromRGBO(148, 163, 184, 0.10),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              time,
                              style: const TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                height: 16 / 12,
                              ),
                            ),
                          ),
                          const Spacer(),
                          if (isUnread) const _ReadDot(),
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.chevron_right_rounded,
                            size: 20,
                            color: Color(0xFF94A3B8),
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

  Widget _buildEmptyState() {
    return ListView(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        const SizedBox(height: 120),
        _NotifyEmptyState(
          icon: Icons.campaign_outlined,
          title: 'app.system.notice.announcement'.tr,
        ),
      ],
    );
  }

  Widget _buildSkeletonList({int count = _skeletonCount}) {
    return ListView.separated(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: count,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (_, __) => const _NoticeSkeletonCard(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final list = widget.controller.noticeList;
      final loading = widget.controller.noticeLoading.value;
      final showSkeletonList =
          (loading && list.isEmpty) || widget.controller.noticeRefreshing.value;
      final showLoadingFooter = widget.controller.noticeLoadingMore.value;
      final showNoMoreFooter =
          list.isNotEmpty && !loading && !widget.controller.noticeHasMore;
      final footerCount = showLoadingFooter
          ? _loadMoreSkeletonCount
          : (showNoMoreFooter ? 1 : 0);

      return Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 672),
          child: RefreshIndicator(
            onRefresh: () => widget.controller.loadNoticeList(refresh: true),
            child: showSkeletonList
                ? _buildSkeletonList()
                : list.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: list.length + footerCount,
                    itemBuilder: (context, index) {
                      if (index >= list.length) {
                        if (showLoadingFooter) {
                          return const Padding(
                            padding: EdgeInsets.only(bottom: 14),
                            child: _NoticeSkeletonCard(),
                          );
                        }
                        return _buildLoadMoreFooter(
                          showLoading: false,
                          showNoMore: showNoMoreFooter,
                        );
                      }

                      final item = list[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _buildNoticeCard(item),
                      );
                    },
                  ),
          ),
        ),
      );
    });
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
}

class _NoticeSkeletonCard extends StatelessWidget {
  const _NoticeSkeletonCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(15, 23, 42, 0.04),
            blurRadius: 18,
            spreadRadius: -14,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        child: Row(
          children: [
            const _NotifySkeletonBox(width: 42, height: 42, radius: 14),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  _NotifySkeletonBox(
                    width: double.infinity,
                    height: 15,
                    radius: 7,
                  ),
                  SizedBox(height: 10),
                  Row(
                    children: [
                      _NotifySkeletonBox(width: 124, height: 26, radius: 999),
                      Spacer(),
                      _NotifySkeletonBox(width: 9, height: 9, radius: 4.5),
                      SizedBox(width: 8),
                      _NotifySkeletonBox(width: 18, height: 18, radius: 9),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotifySkeletonBox extends StatelessWidget {
  const _NotifySkeletonBox({
    required this.width,
    required this.height,
    required this.radius,
  });

  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class _NotifyEmptyState extends StatelessWidget {
  const _NotifyEmptyState({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: const BoxDecoration(
            color: Color(0xFFF0FDF4),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 30, color: Color(0xFF16A34A)),
        ),
        const SizedBox(height: 18),
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF334155),
            fontSize: 15,
            fontWeight: FontWeight.w700,
            height: 20 / 15,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'app.common.no_data'.tr,
          style: const TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 12,
            fontWeight: FontWeight.w500,
            height: 18 / 12,
          ),
        ),
      ],
    );
  }
}

class _ReadDot extends StatelessWidget {
  const _ReadDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 9,
      height: 9,
      decoration: BoxDecoration(
        color: const Color(0xFF16A34A),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.2),
      ),
    );
  }
}
