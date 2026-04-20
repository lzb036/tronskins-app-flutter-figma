import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:tronskins_app/api/model/notify/notify_models.dart';
import 'package:tronskins_app/common/utils/app_snackbar.dart';
import 'package:tronskins_app/components/layout/list_end_tip.dart';
import 'package:tronskins_app/controllers/user/notify_controller.dart';
import 'package:tronskins_app/routes/app_routes.dart';

class NotifyTradeList extends StatefulWidget {
  const NotifyTradeList({super.key, required this.controller});

  final NotifyController controller;

  @override
  State<NotifyTradeList> createState() => _NotifyTradeListState();
}

class _NotifyTradeListState extends State<NotifyTradeList> {
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
      widget.controller.loadTradeList();
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

  Future<void> _handleRead(TradeNotifyItem item) async {
    final message = await widget.controller.readTrade(item);
    if (message == null || message.isEmpty || item.status == 2) {
      return;
    }
    AppSnackbar.info(message);
  }

  Future<void> _openDetail(TradeNotifyItem item) async {
    await _handleRead(item);
    Get.toNamed(Routers.TRADE_NOTICE_DETAIL, arguments: item);
  }

  Future<void> _handleDelete(TradeNotifyItem item) async {
    final id = item.id;
    if (id == null || id.isEmpty) {
      return;
    }

    final list = widget.controller.tradeList;
    final index = list.indexWhere((element) => element.id == id);
    if (index < 0) {
      return;
    }

    final removed = list.removeAt(index);
    final total = widget.controller.tradeTotal.value;
    if (total > 0) {
      widget.controller.tradeTotal.value = total - 1;
    }

    try {
      final message = await widget.controller.deleteTrade(id);
      if (message == null) {
        final insertIndex = index.clamp(0, list.length);
        list.insert(insertIndex, removed);
        if (total > 0) {
          widget.controller.tradeTotal.value = total;
        }
        return;
      }
      AppSnackbar.success(
        message.isNotEmpty ? message : 'app.system.message.success'.tr,
      );
    } catch (_) {
      final insertIndex = index.clamp(0, list.length);
      list.insert(insertIndex, removed);
      if (total > 0) {
        widget.controller.tradeTotal.value = total;
      }
    }
  }

  String _stripHtml(String? value) {
    if (value == null || value.isEmpty) {
      return '';
    }
    return value
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll('&nbsp;', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  Widget _buildMessagePreview(TradeNotifyItem item) {
    final message = _stripHtml(item.message);
    if (message.isEmpty) {
      return Text(
        'app.common.no_data'.tr,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Color(0xFF94A3B8),
          fontSize: 13,
          fontWeight: FontWeight.w500,
          height: 18 / 13,
        ),
      );
    }

    return Text(
      message,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: Color(0xFF0F172A),
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 22 / 14,
      ),
    );
  }

  Widget _buildTradeCard(BuildContext context, TradeNotifyItem item) {
    final isUnread = !item.read;
    final time = _formatTime(item.createTime);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isUnread
              ? const [Color(0xFFFFFFFF), Color(0xFFF2FBFF)]
              : const [Color(0xFFFFFFFF), Color(0xFFF8FAFC)],
        ),
        borderRadius: BorderRadius.zero,
        border: Border.all(
          color: isUnread
              ? const Color.fromRGBO(14, 165, 233, 0.18)
              : const Color(0xFFE2E8F0),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(15, 23, 42, 0.04),
            blurRadius: 20,
            spreadRadius: -14,
            offset: Offset(0, 14),
          ),
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.04),
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.zero,
          onTap: () => _openDetail(item),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: isUnread
                        ? const Color(0xFFA5F3FC)
                        : const Color(0xFFE2E8F0),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.swap_horiz_rounded,
                    size: 22,
                    color: isUnread
                        ? const Color(0xFF0F172A)
                        : const Color(0xFF475569),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color.fromRGBO(
                                    148,
                                    163,
                                    184,
                                    0.10,
                                  ),
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
                            ),
                          ),
                          if (isUnread) ...[
                            const _ReadDot(),
                            const SizedBox(width: 8),
                          ],
                          const Icon(
                            Icons.chevron_right_rounded,
                            size: 20,
                            color: Color(0xFF94A3B8),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _buildMessagePreview(item),
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
          icon: Icons.mark_email_read_outlined,
          title: 'app.system.notice.transaction'.tr,
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
      itemBuilder: (_, __) => const _TradeSkeletonCard(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final list = widget.controller.tradeList;
      final loading = widget.controller.tradeLoading.value;
      final showSkeletonList =
          (loading && list.isEmpty) || widget.controller.tradeRefreshing.value;
      final showLoadingFooter = widget.controller.tradeLoadingMore.value;
      final showNoMoreFooter =
          list.isNotEmpty && !loading && !widget.controller.tradeHasMore;
      final footerCount = showLoadingFooter
          ? _loadMoreSkeletonCount
          : (showNoMoreFooter ? 1 : 0);

      return Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 672),
          child: RefreshIndicator(
            onRefresh: () => widget.controller.loadTradeList(refresh: true),
            child: showSkeletonList
                ? _buildSkeletonList()
                : list.isEmpty
                ? _buildEmptyState()
                : SlidableAutoCloseBehavior(
                    child: ListView.builder(
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: list.length + footerCount,
                      itemBuilder: (context, index) {
                        if (index >= list.length) {
                          if (showLoadingFooter) {
                            return const Padding(
                              padding: EdgeInsets.only(bottom: 14),
                              child: _TradeSkeletonCard(),
                            );
                          }
                          return _buildLoadMoreFooter(
                            showLoading: false,
                            showNoMore: showNoMoreFooter,
                          );
                        }

                        final item = list[index];
                        final canDelete =
                            item.id != null && item.id!.isNotEmpty;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: Slidable(
                            key: ValueKey(
                              item.id ??
                                  'trade-$index-${item.createTime ?? ''}',
                            ),
                            enabled: canDelete,
                            endActionPane: canDelete
                                ? ActionPane(
                                    motion: const StretchMotion(),
                                    extentRatio: 0.42,
                                    children: [
                                      SlidableAction(
                                        onPressed: (_) => _handleDelete(item),
                                        backgroundColor: const Color(
                                          0xFFDC2626,
                                        ),
                                        foregroundColor: Colors.white,
                                        icon: Icons.delete_outline_rounded,
                                        label: 'app.common.delete'.tr,
                                        borderRadius:
                                            const BorderRadius.horizontal(
                                              left: Radius.circular(20),
                                              right: Radius.circular(20),
                                            ),
                                      ),
                                    ],
                                  )
                                : null,
                            child: _buildTradeCard(context, item),
                          ),
                        );
                      },
                    ),
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

class _TradeSkeletonCard extends StatelessWidget {
  const _TradeSkeletonCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.zero,
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(15, 23, 42, 0.04),
            blurRadius: 20,
            spreadRadius: -14,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _NotifySkeletonBox(width: 46, height: 46, radius: 23),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Row(
                    children: [
                      _NotifySkeletonBox(width: 128, height: 28, radius: 999),
                      Spacer(),
                      _NotifySkeletonBox(width: 10, height: 10, radius: 5),
                      SizedBox(width: 8),
                      _NotifySkeletonBox(width: 18, height: 18, radius: 9),
                    ],
                  ),
                  SizedBox(height: 10),
                  _NotifySkeletonBox(
                    width: double.infinity,
                    height: 14,
                    radius: 7,
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
            color: Color(0xFFEFF6FF),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 30, color: Color(0xFF3B82F6)),
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
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: const Color(0xFFDC2626),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
      ),
    );
  }
}
