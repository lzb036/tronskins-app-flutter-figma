import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:tronskins_app/api/model/wallet/wallet_models.dart';
import 'package:tronskins_app/common/hooks/currency/CurrencyController.dart';
import 'package:tronskins_app/common/widgets/settings_style_app_bar.dart';
import 'package:tronskins_app/components/layout/list_end_tip.dart';
import 'package:tronskins_app/controllers/wallet/wallet_controller.dart';

class WalletRechargeRecordPage extends StatefulWidget {
  const WalletRechargeRecordPage({super.key});

  @override
  State<WalletRechargeRecordPage> createState() =>
      _WalletRechargeRecordPageState();
}

class _WalletRechargeRecordPageState extends State<WalletRechargeRecordPage> {
  static const Color _pageBackground = Color(0xFFF8FAFC);
  static const Color _brandBlue = Color(0xFF1E40AF);
  static const Color _refreshBlue = Color(0xFF00288E);
  static const Color _loadingLine = Color(0xFFF2F4F6);
  static const Color _strongText = Color(0xFF191C1E);
  static const Color _bodyText = Color(0xFF444653);

  final WalletController controller = Get.isRegistered<WalletController>()
      ? Get.find<WalletController>()
      : Get.put(WalletController());
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    controller.loadRechargeRecords(reset: true);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >
        _scrollController.position.maxScrollExtent - 200) {
      controller.loadRechargeRecords();
    }
  }

  String _formatRecordDate(int? value) {
    final date = _dateFromTimestamp(value);
    if (date == null) {
      return '-';
    }
    return DateFormat('yyyy-MM-dd').format(date);
  }

  String _formatRecordTime(int? value) {
    final date = _dateFromTimestamp(value);
    if (date == null) {
      return '--:--:--';
    }
    return DateFormat('HH:mm:ss').format(date);
  }

  DateTime? _dateFromTimestamp(int? value) {
    if (value == null) {
      return null;
    }
    var timestamp = value;
    if (timestamp < 10000000000) {
      timestamp *= 1000;
    }
    return DateTime.fromMillisecondsSinceEpoch(timestamp);
  }

  _StatusTone _statusTone(WalletRechargeRecord item) {
    return (item.status ?? 0) == 0 ? _StatusTone.failed : _StatusTone.success;
  }

  @override
  Widget build(BuildContext context) {
    final currency = Get.find<CurrencyController>();
    return Scaffold(
      backgroundColor: _pageBackground,
      appBar: SettingsStyleAppBar(
        title: Text('app.user.wallet.recharge_record'.tr),
      ),
      body: Obx(() {
        final records = controller.rechargeRecords.toList(growable: false);
        final isLoading = controller.isLoadingRechargeRecords.value;
        if (records.isEmpty && isLoading) {
          return CustomScrollView(
            key: const PageStorageKey<String>(
              'wallet-recharge-records-loading',
            ),
            physics: const NeverScrollableScrollPhysics(),
            slivers: const [_RechargeRecordLoadingSliver()],
          );
        }
        return RefreshIndicator(
          color: _refreshBlue,
          backgroundColor: Colors.white,
          strokeWidth: 2.2,
          displacement: 22,
          edgeOffset: 2,
          elevation: 0,
          notificationPredicate: (notification) => notification.depth == 0,
          onRefresh: () => controller.loadRechargeRecords(reset: true),
          child: CustomScrollView(
            key: const PageStorageKey<String>('wallet-recharge-records'),
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(
              parent: ClampingScrollPhysics(),
            ),
            slivers: [
              if (records.isEmpty)
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    24,
                    16,
                    32 + MediaQuery.of(context).padding.bottom,
                  ),
                  sliver: SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 896),
                        child: _EmptyArchive(message: 'app.common.no_data'.tr),
                      ),
                    ),
                  ),
                )
              else ...[
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                  sliver: SliverList.separated(
                    itemCount: records.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = records[index];
                      return Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 896),
                          child: _RechargeRecordTile(
                            date: _formatRecordDate(item.createTime),
                            time: _formatRecordTime(item.createTime),
                            amount: currency.formatUsd(item.amount ?? 0),
                            status: item.statusName?.trim().isNotEmpty == true
                                ? item.statusName!.trim()
                                : '-',
                            modeName: item.modeName,
                            tone: _statusTone(item),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                if (isLoading && controller.hasMoreRechargeRecords)
                  const _RechargeRecordLoadingSliver(
                    topPadding: 12,
                    itemCount: 2,
                    bottomPadding: 12,
                  )
                else if (!controller.hasMoreRechargeRecords)
                  const SliverToBoxAdapter(
                    child: ListEndTip(
                      padding: EdgeInsets.fromLTRB(8, 18, 8, 18),
                    ),
                  ),
              ],
            ],
          ),
        );
      }),
    );
  }
}

class _RechargeRecordLoadingSliver extends StatelessWidget {
  const _RechargeRecordLoadingSliver({
    this.itemCount = 6,
    this.topPadding = 24,
    this.bottomPadding = 32,
  });

  final int itemCount;
  final double topPadding;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: EdgeInsets.fromLTRB(16, topPadding, 16, bottomPadding),
      sliver: SliverList.separated(
        itemCount: itemCount,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 896),
              child: _RechargeRecordLoadingTile(),
            ),
          );
        },
      ),
    );
  }
}

class _RechargeRecordLoadingTile extends StatelessWidget {
  const _RechargeRecordLoadingTile();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 112,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.zero,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                _LoadingBlock(width: 108, height: 16),
                SizedBox(height: 10),
                _LoadingBlock(width: 74, height: 12),
                SizedBox(height: 10),
                _LoadingBlock(width: 52, height: 12),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              _LoadingBlock(width: 92, height: 24),
              SizedBox(height: 10),
              _LoadingBlock(width: 112, height: 20),
            ],
          ),
        ],
      ),
    );
  }
}

class _LoadingBlock extends StatelessWidget {
  const _LoadingBlock({required this.width, required this.height});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: _WalletRechargeRecordPageState._loadingLine,
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}

class _RechargeRecordTile extends StatelessWidget {
  const _RechargeRecordTile({
    required this.date,
    required this.time,
    required this.amount,
    required this.status,
    required this.tone,
    this.modeName,
  });

  final String date;
  final String time;
  final String amount;
  final String status;
  final String? modeName;
  final _StatusTone tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.zero,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF191C1E).withValues(alpha: 0.04),
            blurRadius: 60,
            offset: const Offset(0, 40),
            spreadRadius: -20,
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  date,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _WalletRechargeRecordPageState._strongText,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 20 / 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  time,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _WalletRechargeRecordPageState._bodyText,
                    fontSize: 10,
                    height: 15 / 10,
                  ),
                ),
                if ((modeName ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    modeName!.trim(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _WalletRechargeRecordPageState._bodyText
                          .withValues(alpha: 0.65),
                      fontSize: 10,
                      height: 15 / 10,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              _StatusPill(text: status, tone: tone),
              const SizedBox(height: 4),
              Text(
                amount,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: const TextStyle(
                  color: _WalletRechargeRecordPageState._brandBlue,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  height: 28 / 18,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.text, required this.tone});

  final String text;
  final _StatusTone tone;

  @override
  Widget build(BuildContext context) {
    final colors = switch (tone) {
      _StatusTone.success => (
        background: const Color(0xFFECFDF5),
        foreground: const Color(0xFF059669),
      ),
      _StatusTone.failed => (
        background: const Color(0xFFFFF1F2),
        foreground: const Color(0xFFE11D48),
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: colors.foreground,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colors.foreground,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              height: 16.5 / 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyArchive extends StatelessWidget {
  const _EmptyArchive({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 96),
      child: Center(
        child: Text(
          message,
          style: const TextStyle(
            color: _WalletRechargeRecordPageState._bodyText,
            fontSize: 14,
            height: 20 / 14,
          ),
        ),
      ),
    );
  }
}

enum _StatusTone { success, failed }
