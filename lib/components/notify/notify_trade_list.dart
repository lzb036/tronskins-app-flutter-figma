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
  static const int _skeletonCount = 4;
  static const int _loadMoreSkeletonCount = 2;

  static const Color _cardBorder = Color.fromRGBO(196, 197, 213, 0.08);
  static const Color _cardShadow = Color.fromRGBO(0, 0, 0, 0.02);
  static const Color _iconBackground = Color(0xFFD8E2FF);
  static const Color _iconColor = Color(0xFF1D5DD6);
  static const Color _messageColor = Color(0xFF191C1E);
  static const Color _timeColor = Color(0xFF444653);
  static const Color _emptyHintColor = Color(0xFF757684);
  static const Color _chevronColor = Color(0xFFC4C5D5);
  static const Color _unreadDotColor = Color(0xFFBA1A1A);
  static const Color _accentBlue = Color(0xFF1E40AF);

  final ScrollController _scrollController = ScrollController();

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

  void _openDetail(TradeNotifyItem item) {
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

  _TradeMessageIconSpec _resolveTradeIcon(TradeNotifyItem item) {
    final type = item.type;
    final plainMessage = _stripHtml(item.message).toLowerCase();

    if (type == 1) {
      return const _TradeMessageIconSpec(icon: Icons.swap_horiz_rounded);
    }
    if (type == 3 || type == 31) {
      return const _TradeMessageIconSpec(icon: Icons.inventory_2_outlined);
    }
    if (plainMessage.contains('充值') ||
        plainMessage.contains('recharge') ||
        plainMessage.contains('到账')) {
      return const _TradeMessageIconSpec(
        icon: Icons.account_balance_wallet_outlined,
      );
    }
    if (plainMessage.contains('安全') ||
        plainMessage.contains('security') ||
        plainMessage.contains('登录') ||
        plainMessage.contains('device')) {
      return const _TradeMessageIconSpec(icon: Icons.shield_outlined);
    }
    if (plainMessage.contains('deliver') ||
        plainMessage.contains('ship') ||
        plainMessage.contains('发货') ||
        plainMessage.contains('收货')) {
      return const _TradeMessageIconSpec(icon: Icons.inventory_2_outlined);
    }
    return const _TradeMessageIconSpec(icon: Icons.notifications_none_rounded);
  }

  Widget _buildMessagePreview(TradeNotifyItem item) {
    final message = _stripHtml(item.message);
    if (message.isEmpty) {
      return Text(
        'app.common.no_data'.tr,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: _emptyHintColor,
          fontSize: 13,
          fontWeight: FontWeight.w500,
          height: 18 / 13,
        ),
      );
    }

    return Text(
      message,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: _messageColor,
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 19.25 / 14,
      ),
    );
  }

  Widget _buildTradeCard(BuildContext context, TradeNotifyItem item) {
    final isUnread = !item.read;
    final time = _formatTime(item.createTime);
    final iconSpec = _resolveTradeIcon(item);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _cardBorder),
        boxShadow: const [
          BoxShadow(color: _cardShadow, blurRadius: 20, offset: Offset(0, 4)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => _openDetail(item),
          borderRadius: BorderRadius.circular(12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 90),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 18, 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: iconSpec.backgroundColor,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      iconSpec.icon,
                      size: 22,
                      color: iconSpec.iconColor,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                time,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: _timeColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  height: 16 / 12,
                                  letterSpacing: 0.6,
                                  fontFeatures: [FontFeature.tabularFigures()],
                                ),
                              ),
                            ),
                            if (isUnread) ...[
                              const Padding(
                                padding: EdgeInsets.only(top: 3),
                                child: _ReadDot(),
                              ),
                              const SizedBox(width: 12),
                            ],
                            const Padding(
                              padding: EdgeInsets.only(top: 2),
                              child: Icon(
                                Icons.chevron_right_rounded,
                                size: 18,
                                color: _chevronColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        _buildMessagePreview(item),
                      ],
                    ),
                  ),
                ],
              ),
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
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
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
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
      itemCount: count,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
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
            color: _accentBlue,
            onRefresh: () => widget.controller.loadTradeList(refresh: true),
            child: showSkeletonList
                ? _buildSkeletonList()
                : list.isEmpty
                ? _buildEmptyState()
                : SlidableAutoCloseBehavior(
                    child: ListView.builder(
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
                      itemCount: list.length + footerCount,
                      itemBuilder: (context, index) {
                        if (index >= list.length) {
                          if (showLoadingFooter) {
                            return const Padding(
                              padding: EdgeInsets.only(bottom: 16),
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
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Slidable(
                            key: ValueKey(
                              item.id ??
                                  'trade-$index-${item.createTime ?? ''}',
                            ),
                            enabled: canDelete,
                            endActionPane: canDelete
                                ? ActionPane(
                                    motion: const StretchMotion(),
                                    extentRatio: 0.34,
                                    children: [
                                      SlidableAction(
                                        onPressed: (_) => _handleDelete(item),
                                        backgroundColor: const Color(
                                          0xFFDC2626,
                                        ),
                                        foregroundColor: Colors.white,
                                        icon: Icons.delete_outline_rounded,
                                        label: 'app.common.delete'.tr,
                                        borderRadius: BorderRadius.circular(12),
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
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              color: _accentBlue,
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
}

class _TradeMessageIconSpec {
  const _TradeMessageIconSpec({required this.icon});

  final IconData icon;

  Color get backgroundColor => _NotifyTradeListState._iconBackground;

  Color get iconColor => _NotifyTradeListState._iconColor;
}

class _TradeSkeletonCard extends StatelessWidget {
  const _TradeSkeletonCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _NotifyTradeListState._cardBorder),
        boxShadow: const [
          BoxShadow(
            color: _NotifyTradeListState._cardShadow,
            blurRadius: 20,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 18, 20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _NotifySkeletonBox(width: 48, height: 48, radius: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Row(
                    children: [
                      _NotifySkeletonBox(width: 112, height: 12, radius: 6),
                      Spacer(),
                      _NotifySkeletonBox(width: 8, height: 8, radius: 4),
                      SizedBox(width: 12),
                      _NotifySkeletonBox(width: 16, height: 16, radius: 8),
                    ],
                  ),
                  SizedBox(height: 10),
                  _NotifySkeletonBox(
                    width: double.infinity,
                    height: 14,
                    radius: 7,
                  ),
                  SizedBox(height: 6),
                  _NotifySkeletonBox(width: 168, height: 14, radius: 7),
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
        color: const Color(0xFFF1F5F9),
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
            color: _NotifyTradeListState._iconBackground,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 30, color: _NotifyTradeListState._iconColor),
        ),
        const SizedBox(height: 18),
        Text(
          title,
          style: const TextStyle(
            color: _NotifyTradeListState._messageColor,
            fontSize: 15,
            fontWeight: FontWeight.w700,
            height: 20 / 15,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'app.common.no_data'.tr,
          style: const TextStyle(
            color: _NotifyTradeListState._emptyHintColor,
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
      width: 8,
      height: 8,
      decoration: const BoxDecoration(
        color: _NotifyTradeListState._unreadDotColor,
        shape: BoxShape.circle,
      ),
    );
  }
}
