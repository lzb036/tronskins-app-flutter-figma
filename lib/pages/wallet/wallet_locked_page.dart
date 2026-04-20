import 'package:flutter/material.dart';
import 'package:tronskins_app/common/widgets/settings_style_app_bar.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:tronskins_app/api/model/wallet/wallet_models.dart';
import 'package:tronskins_app/components/layout/list_end_tip.dart';
import 'package:tronskins_app/common/hooks/currency/CurrencyController.dart';
import 'package:tronskins_app/controllers/wallet/wallet_controller.dart';
import 'package:tronskins_app/routes/app_routes.dart';

class WalletLockedPage extends StatefulWidget {
  const WalletLockedPage({super.key});

  @override
  State<WalletLockedPage> createState() => _WalletLockedPageState();
}

class _WalletLockedPageState extends State<WalletLockedPage> {
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
    controller.loadLockedFunds(reset: true);
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
      controller.loadLockedFunds();
    }
  }

  DateTime? _dateTimeFromValue(dynamic value) {
    if (value == null) {
      return null;
    }

    DateTime? dateTime;
    int? timestamp;

    if (value is DateTime) {
      dateTime = value;
    } else if (value is num) {
      timestamp = value.toInt();
    } else {
      final text = value.toString().trim();
      if (text.isEmpty) {
        return null;
      }
      final numeric = num.tryParse(text);
      if (numeric != null) {
        timestamp = numeric.toInt();
      } else {
        dateTime =
            DateTime.tryParse(text) ??
            DateTime.tryParse(text.replaceAll('/', '-'));
        if (dateTime == null) {
          return null;
        }
      }
    }

    if (dateTime == null) {
      if (timestamp == null || timestamp <= 0 || timestamp < 1000000000) {
        return null;
      }
      if (timestamp < 1000000000000) {
        timestamp *= 1000;
      } else if (timestamp >= 1000000000000000) {
        timestamp = (timestamp / 1000).round();
      }
      dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    }

    return dateTime.toLocal();
  }

  DateTime? _lockedTime(WalletLockedItem item) {
    final timeCandidates = [
      item.lockTimeRaw,
      item.lockAmount,
      item.createTimeRaw,
      item.createTime,
    ];
    for (final candidate in timeCandidates) {
      final dateTime = _dateTimeFromValue(candidate);
      if (dateTime != null) {
        return dateTime;
      }
    }
    return null;
  }

  String _formatDate(DateTime? value) {
    if (value == null) {
      return '-';
    }
    return DateFormat('yyyy-MM-dd').format(value);
  }

  String _formatClock(DateTime? value) {
    if (value == null) {
      return '--:--:--';
    }
    return DateFormat('HH:mm:ss').format(value);
  }

  @override
  Widget build(BuildContext context) {
    final currency = Get.find<CurrencyController>();
    return Scaffold(
      backgroundColor: _pageBackground,
      appBar: SettingsStyleAppBar(
        title: Text('app.user.wallet.lock_details'.tr),
      ),
      body: Obx(() {
        final items = controller.lockedItems.toList(growable: false);
        final isLoading = controller.isLoadingLocked.value;
        if (items.isEmpty && isLoading) {
          return CustomScrollView(
            key: const PageStorageKey<String>('wallet-locked-records-loading'),
            physics: const NeverScrollableScrollPhysics(),
            slivers: const [_LockedLoadingSliver()],
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
          onRefresh: () => controller.loadLockedFunds(reset: true),
          child: CustomScrollView(
            key: const PageStorageKey<String>('wallet-locked-records'),
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(
              parent: ClampingScrollPhysics(),
            ),
            slivers: [
              if (items.isEmpty)
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
                        child: _LockedEmptyState(
                          message: 'app.common.no_data'.tr,
                        ),
                      ),
                    ),
                  ),
                )
              else ...[
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                  sliver: SliverList.separated(
                    itemCount: items.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final time = _lockedTime(item);
                      return Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 896),
                          child: _LockedRecordTile(
                            date: _formatDate(time),
                            time: _formatClock(time),
                            lockAmount: currency.formatUsd(item.amount ?? 0),
                            giftAmount: currency.formatUsd(
                              item.giftAmount ?? 0,
                            ),
                            enabled: item.id != null,
                            onTap: item.id == null
                                ? null
                                : () => Get.toNamed(
                                    Routers.WALLET_LOCKED_DETAIL,
                                    arguments: {
                                      'id': item.id.toString(),
                                      'srcId': item.srcId,
                                      'lockType': item.lockType,
                                      'lockAmount': item.amount,
                                      'lockedAmount': item.amount,
                                      'giftAmount': item.giftAmount,
                                      'lockTime': item.lockAmount,
                                      'typeName': item.typeName,
                                    },
                                  ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                if (isLoading && controller.hasMoreLocked)
                  const _LockedLoadingSliver(
                    topPadding: 12,
                    itemCount: 2,
                    bottomPadding: 12,
                  )
                else if (!controller.hasMoreLocked)
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

class _LockedRecordTile extends StatelessWidget {
  const _LockedRecordTile({
    required this.date,
    required this.time,
    required this.lockAmount,
    required this.giftAmount,
    required this.enabled,
    this.onTap,
  });

  final String date;
  final String time;
  final String lockAmount;
  final String giftAmount;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Ink(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF191C1E).withValues(alpha: 0.04),
                blurRadius: 60,
                offset: const Offset(0, 40),
                spreadRadius: -20,
              ),
            ],
          ),
          child: Opacity(
            opacity: enabled ? 1 : 0.62,
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      date,
                      maxLines: 1,
                      softWrap: false,
                      style: const TextStyle(
                        color: _WalletLockedPageState._strongText,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        height: 20 / 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      time,
                      maxLines: 1,
                      softWrap: false,
                      style: const TextStyle(
                        color: _WalletLockedPageState._bodyText,
                        fontSize: 10,
                        height: 15 / 10,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _LockedAmountLine(
                        label: 'app.user.wallet.lock_amount'.tr,
                        value: lockAmount,
                      ),
                      const SizedBox(height: 6),
                      _LockedAmountLine(
                        label: 'app.user.wallet.gift_amount'.tr,
                        value: giftAmount,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Icon(
                  Icons.chevron_right_rounded,
                  color: _WalletLockedPageState._bodyText.withValues(
                    alpha: enabled ? 0.62 : 0.28,
                  ),
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LockedAmountLine extends StatelessWidget {
  const _LockedAmountLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerRight,
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(text: '$label: '),
              TextSpan(
                text: value,
                style: const TextStyle(
                  color: _WalletLockedPageState._brandBlue,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          maxLines: 1,
          softWrap: false,
          textAlign: TextAlign.end,
          style: const TextStyle(
            color: _WalletLockedPageState._bodyText,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            height: 18 / 12,
          ),
        ),
      ),
    );
  }
}

class _LockedLoadingSliver extends StatelessWidget {
  const _LockedLoadingSliver({
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
              child: const _LockedLoadingTile(),
            ),
          );
        },
      ),
    );
  }
}

class _LockedLoadingTile extends StatelessWidget {
  const _LockedLoadingTile();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 92,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _LockedLoadingBlock(width: 108, height: 16),
                SizedBox(height: 10),
                _LockedLoadingBlock(width: 74, height: 12),
              ],
            ),
          ),
          SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LockedLoadingBlock(width: 128, height: 16),
              SizedBox(height: 10),
              _LockedLoadingBlock(width: 108, height: 16),
            ],
          ),
        ],
      ),
    );
  }
}

class _LockedLoadingBlock extends StatelessWidget {
  const _LockedLoadingBlock({required this.width, required this.height});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: _WalletLockedPageState._loadingLine,
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}

class _LockedEmptyState extends StatelessWidget {
  const _LockedEmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 96),
      child: Center(
        child: Text(
          message,
          style: const TextStyle(
            color: _WalletLockedPageState._bodyText,
            fontSize: 14,
            height: 20 / 14,
          ),
        ),
      ),
    );
  }
}
