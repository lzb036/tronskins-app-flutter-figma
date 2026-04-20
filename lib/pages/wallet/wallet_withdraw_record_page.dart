import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:tronskins_app/api/model/wallet/wallet_models.dart';
import 'package:tronskins_app/common/hooks/currency/CurrencyController.dart';
import 'package:tronskins_app/common/utils/app_snackbar.dart';
import 'package:tronskins_app/common/widgets/settings_style_app_bar.dart';
import 'package:tronskins_app/components/layout/list_end_tip.dart';
import 'package:tronskins_app/controllers/wallet/wallet_controller.dart';

class WalletWithdrawRecordPage extends StatefulWidget {
  const WalletWithdrawRecordPage({super.key});

  @override
  State<WalletWithdrawRecordPage> createState() =>
      _WalletWithdrawRecordPageState();
}

class _WalletWithdrawRecordPageState extends State<WalletWithdrawRecordPage> {
  final WalletController controller = Get.isRegistered<WalletController>()
      ? Get.find<WalletController>()
      : Get.put(WalletController());
  final ScrollController _scrollController = ScrollController();

  static const Color _pageBackground = Color(0xFFF8FAFC);
  static const Color _brandColor = Color(0xFF1E40AF);
  static const Color _refreshBlue = Color(0xFF00288E);
  static const Color _brandLightColor = Color(0xFFEFF6FF);
  static const Color _textPrimary = Color(0xFF191C1E);
  static const Color _textSecondary = Color(0xFF444653);
  static const Color _textMuted = Color(0xFF757684);
  static const Color _loadingLine = Color(0xFFF2F4F6);

  @override
  void initState() {
    super.initState();
    controller.loadWithdrawRecords(reset: true);
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
      controller.loadWithdrawRecords();
    }
  }

  String _formatTime(int? value) {
    if (value == null) {
      return '-';
    }
    var timestamp = value;
    if (timestamp < 10000000000) {
      timestamp *= 1000;
    }
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return DateFormat('yyyy-MM-dd HH:mm:ss').format(date);
  }

  Future<void> _copyText(String text) async {
    if (text.trim().isEmpty) {
      return;
    }
    await Clipboard.setData(ClipboardData(text: text));
    AppSnackbar.success('app.system.message.copy_success'.tr);
  }

  bool get _isChineseLocale =>
      (Get.locale?.languageCode ?? '').toLowerCase().startsWith('zh');

  String get _withdrawDetailTitle =>
      _isChineseLocale ? '提现详情' : 'Withdrawal Details';

  String get _serialNoLabel => _isChineseLocale ? '流水号' : 'Serial No';

  String get _copySerialText => _isChineseLocale ? '复制流水号' : 'Copy Serial No';

  String get _closeText => _isChineseLocale ? '关闭' : 'Close';

  Future<void> _showWithdrawDetail({
    required WalletWithdrawRecord item,
    required String time,
    required String amount,
    required _StatusTone tone,
  }) async {
    await showDialog<void>(
      context: context,
      barrierColor: const Color(0x33191C1E),
      builder: (dialogContext) {
        return _WithdrawDetailDialog(
          title: _withdrawDetailTitle,
          serialNoLabel: _serialNoLabel,
          copySerialText: _copySerialText,
          closeText: _closeText,
          timeLabel: 'app.market.filter.time'.tr,
          amountLabel: 'app.user.withdraw.amount'.tr,
          addressLabel: 'app.user.wallet.address'.tr,
          statusLabel: 'app.trade.order.status'.tr,
          serialNo: _displayValue(item.id),
          time: time,
          amount: amount,
          walletAddress: _displayValue(item.account),
          statusText: _displayValue(item.statusName),
          tone: tone,
          onCopySerial: () => _copyText(item.id ?? ''),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currency = Get.find<CurrencyController>();
    return Scaffold(
      backgroundColor: _pageBackground,
      appBar: SettingsStyleAppBar(
        title: Text('app.user.wallet.withdraw_record'.tr),
      ),
      body: Obx(() {
        final records = controller.withdrawRecords.toList(growable: false);
        final isLoading = controller.isLoadingWithdrawRecords.value;
        if (records.isEmpty && isLoading) {
          return CustomScrollView(
            key: const PageStorageKey<String>(
              'wallet-withdraw-records-loading',
            ),
            physics: const NeverScrollableScrollPhysics(),
            slivers: const [_WithdrawRecordLoadingSliver()],
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
          onRefresh: () => controller.loadWithdrawRecords(reset: true),
          child: CustomScrollView(
            key: const PageStorageKey<String>('wallet-withdraw-records'),
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
                        constraints: const BoxConstraints(maxWidth: 448),
                        child: _WithdrawEmptyState(
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
                    itemCount: records.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final item = records[index];
                      final time = _formatTime(item.createTime);
                      final amount = currency.formatUsd(item.amount ?? 0);
                      final tone = _statusTone(item.status, item.statusName);

                      return Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 448),
                          child: _WithdrawRecordTile(
                            item: item,
                            time: time,
                            amount: amount,
                            tone: tone,
                            onTap: () => _showWithdrawDetail(
                              item: item,
                              time: time,
                              amount: amount,
                              tone: tone,
                            ),
                            onCopy: () => _copyText(item.id ?? ''),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                if (isLoading && controller.hasMoreWithdrawRecords)
                  const _WithdrawRecordLoadingSliver(
                    topPadding: 16,
                    itemCount: 2,
                    bottomPadding: 12,
                  )
                else if (!controller.hasMoreWithdrawRecords)
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

  _StatusTone _statusTone(int? status, String? statusName) {
    final normalizedName = (statusName ?? '').toLowerCase();
    if (status == 0 ||
        normalizedName.contains('pending') ||
        normalizedName.contains('process') ||
        normalizedName.contains('审核') ||
        normalizedName.contains('处理中')) {
      return const _StatusTone(
        foreground: Color(0xFF3B82F6),
        background: Color(0xFFEFF6FF),
      );
    }
    if (normalizedName.contains('cancel') ||
        normalizedName.contains('reject') ||
        normalizedName.contains('取消') ||
        normalizedName.contains('拒绝')) {
      return const _StatusTone(
        foreground: Color(0xFF8E8E93),
        background: Color(0xFFF1F5F9),
      );
    }
    if (normalizedName.contains('fail') || normalizedName.contains('失败')) {
      return const _StatusTone(
        foreground: Color(0xFFBA1A1A),
        background: Color(0xFFFFF1F2),
      );
    }
    return const _StatusTone(
      foreground: Color(0xFF059669),
      background: Color(0xFFECFDF5),
    );
  }
}

class _WithdrawRecordTile extends StatelessWidget {
  const _WithdrawRecordTile({
    required this.item,
    required this.time,
    required this.amount,
    required this.tone,
    required this.onTap,
    required this.onCopy,
  });

  final WalletWithdrawRecord item;
  final String time;
  final String amount;
  final _StatusTone tone;
  final VoidCallback onTap;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final id = _displayValue(item.id);
    final statusText = _displayValue(item.statusName);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.zero,
      child: InkWell(
        borderRadius: BorderRadius.zero,
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.zero,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF191C1E).withValues(alpha: 0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      'SN: $id',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                        height: 16.5 / 11,
                        letterSpacing: -0.55,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  _RecordCopyButton(onTap: onCopy),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          time,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            height: 16 / 12,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          amount,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _WalletWithdrawRecordPageState._brandColor,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            height: 28 / 20,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  _StatusPill(
                    text: statusText,
                    tone: tone,
                    foregroundWeight: FontWeight.w600,
                    fontSize: 11,
                    horizontalPadding: 12,
                    verticalPadding: 4,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecordCopyButton extends StatelessWidget {
  const _RecordCopyButton({required this.onTap, this.iconSize = 15});

  final VoidCallback onTap;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Icon(
            Icons.content_copy_rounded,
            size: iconSize,
            color: const Color(0xFFCBD5E1),
          ),
        ),
      ),
    );
  }
}

class _WithdrawDetailDialog extends StatelessWidget {
  const _WithdrawDetailDialog({
    required this.title,
    required this.serialNoLabel,
    required this.copySerialText,
    required this.closeText,
    required this.timeLabel,
    required this.amountLabel,
    required this.addressLabel,
    required this.statusLabel,
    required this.serialNo,
    required this.time,
    required this.amount,
    required this.walletAddress,
    required this.statusText,
    required this.tone,
    required this.onCopySerial,
  });

  final String title;
  final String serialNoLabel;
  final String copySerialText;
  final String closeText;
  final String timeLabel;
  final String amountLabel;
  final String addressLabel;
  final String statusLabel;
  final String serialNo;
  final String time;
  final String amount;
  final String walletAddress;
  final String statusText;
  final _StatusTone tone;
  final VoidCallback onCopySerial;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.10),
                blurRadius: 50,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: _WalletWithdrawRecordPageState._textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    height: 27 / 18,
                    letterSpacing: -0.45,
                  ),
                ),
                const SizedBox(height: 20),
                _WithdrawDetailField(
                  label: serialNoLabel,
                  trailing: _RecordCopyButton(
                    onTap: onCopySerial,
                    iconSize: 16,
                  ),
                  child: Text(
                    serialNo,
                    style: const TextStyle(
                      color: _WalletWithdrawRecordPageState._textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      height: 16 / 12,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _WithdrawDetailField(
                  label: timeLabel,
                  child: Text(
                    time,
                    style: const TextStyle(
                      color: _WalletWithdrawRecordPageState._textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      height: 16 / 12,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(height: 1, color: Color(0xFFECEEF0)),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2F4F6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          amountLabel,
                          style: const TextStyle(
                            color: _WalletWithdrawRecordPageState._textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            height: 19.5 / 13,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        amount,
                        style: const TextStyle(
                          color: _WalletWithdrawRecordPageState._brandColor,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          height: 22.5 / 15,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(height: 1, color: Color(0xFFECEEF0)),
                const SizedBox(height: 16),
                _WithdrawDetailField(
                  label: addressLabel,
                  child: Text(
                    walletAddress,
                    style: const TextStyle(
                      color: _WalletWithdrawRecordPageState._textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      height: 16 / 12,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _WithdrawDetailField(
                  label: statusLabel,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: tone.foreground,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          statusText,
                          style: TextStyle(
                            color: tone.foreground,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            height: 16 / 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _DetailActionButton(
                  label: copySerialText,
                  onTap: onCopySerial,
                  isPrimary: true,
                ),
                const SizedBox(height: 12),
                _DetailActionButton(
                  label: closeText,
                  onTap: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WithdrawDetailField extends StatelessWidget {
  const _WithdrawDetailField({
    required this.label,
    required this.child,
    this.trailing,
  });

  final String label;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: _WalletWithdrawRecordPageState._textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w500,
            height: 16.5 / 11,
            letterSpacing: 0.55,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: child),
            if (trailing != null) ...[const SizedBox(width: 12), trailing!],
          ],
        ),
      ],
    );
  }
}

class _DetailActionButton extends StatelessWidget {
  const _DetailActionButton({
    required this.label,
    required this.onTap,
    this.isPrimary = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    final gradient = isPrimary
        ? const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1E40AF), Color(0xFF3B82F6)],
          )
        : null;
    final foregroundColor = isPrimary ? Colors.white : const Color(0xFF444653);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Ink(
          height: 44,
          decoration: BoxDecoration(
            gradient: gradient,
            color: gradient == null ? Colors.white : null,
            borderRadius: BorderRadius.circular(8),
            border: gradient == null
                ? Border.all(color: const Color(0xFFC4C5D5))
                : null,
            boxShadow: isPrimary
                ? [
                    BoxShadow(
                      color: const Color(0xFF00288E).withValues(alpha: 0.20),
                      blurRadius: 15,
                      offset: const Offset(0, 10),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: foregroundColor,
                fontSize: 14,
                fontWeight: isPrimary ? FontWeight.w600 : FontWeight.w500,
                height: 20 / 14,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WithdrawRecordLoadingSliver extends StatelessWidget {
  const _WithdrawRecordLoadingSliver({
    this.topPadding = 24,
    this.bottomPadding = 24,
    this.itemCount = 4,
  });

  final double topPadding;
  final double bottomPadding;
  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: EdgeInsets.fromLTRB(16, topPadding, 16, bottomPadding),
      sliver: SliverList.separated(
        itemCount: itemCount,
        separatorBuilder: (context, index) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 448),
              child: const _WithdrawRecordLoadingTile(),
            ),
          );
        },
      ),
    );
  }
}

class _WithdrawRecordLoadingTile extends StatelessWidget {
  const _WithdrawRecordLoadingTile();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.zero,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF191C1E).withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _WithdrawLoadingBlock(height: 12)),
              SizedBox(width: 40),
              _WithdrawLoadingBlock(width: 14, height: 14, radius: 4),
            ],
          ),
          SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _WithdrawLoadingBlock(width: 148, height: 12),
                    SizedBox(height: 6),
                    _WithdrawLoadingBlock(width: 96, height: 24),
                  ],
                ),
              ),
              SizedBox(width: 18),
              _WithdrawLoadingBlock(width: 86, height: 28, radius: 999),
            ],
          ),
        ],
      ),
    );
  }
}

class _WithdrawLoadingBlock extends StatelessWidget {
  const _WithdrawLoadingBlock({
    this.width,
    required this.height,
    this.radius = 6,
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
        color: _WalletWithdrawRecordPageState._loadingLine,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class _WithdrawEmptyState extends StatelessWidget {
  const _WithdrawEmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: _WalletWithdrawRecordPageState._brandLightColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.north_east_rounded,
              color: _WalletWithdrawRecordPageState._brandColor,
              size: 26,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _WalletWithdrawRecordPageState._textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              height: 20 / 14,
            ),
          ),
        ],
      ),
    );
  }
}

String _displayValue(String? value) {
  final text = value?.trim() ?? '';
  return text.isEmpty ? '-' : text;
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.text,
    required this.tone,
    this.horizontalPadding = 10,
    this.verticalPadding = 6,
    this.fontSize = 12,
    this.foregroundWeight = FontWeight.w700,
  });

  final String text;
  final _StatusTone tone;
  final double horizontalPadding;
  final double verticalPadding;
  final double fontSize;
  final FontWeight foregroundWeight;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 148),
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: verticalPadding,
      ),
      decoration: BoxDecoration(
        color: tone.background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        maxLines: 2,
        overflow: TextOverflow.visible,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: tone.foreground,
          fontSize: fontSize,
          fontWeight: foregroundWeight,
          height: 16 / fontSize,
        ),
      ),
    );
  }
}

class _StatusTone {
  const _StatusTone({required this.foreground, required this.background});

  final Color foreground;
  final Color background;
}
