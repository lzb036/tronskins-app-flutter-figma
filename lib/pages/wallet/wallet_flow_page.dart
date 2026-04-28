import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:tronskins_app/api/model/wallet/wallet_models.dart';
import 'package:tronskins_app/common/hooks/currency/CurrencyController.dart';
import 'package:tronskins_app/common/widgets/settings_style_app_bar.dart';
import 'package:tronskins_app/components/layout/list_end_tip.dart';
import 'package:tronskins_app/controllers/wallet/wallet_controller.dart';
import 'package:tronskins_app/routes/app_routes.dart';

class WalletFlowPage extends StatefulWidget {
  const WalletFlowPage({super.key});

  @override
  State<WalletFlowPage> createState() => _WalletFlowPageState();
}

class _WalletFlowPageState extends State<WalletFlowPage> {
  static const Color _pageBackground = Color(0xFFF8F8FC);
  static const Color _cardBackground = Colors.white;
  static const Color _cardShadowColor = Color.fromRGBO(15, 23, 42, 0.02);
  static const Color _refreshBlue = Color(0xFF00288E);
  static const Color _primaryText = Color(0xFF334155);
  static const Color _secondaryText = Color(0xFF94A3B8);
  static const Color _loadingLine = Color(0xFFF2F4F6);
  static const Color _blue = Color(0xFF2563EB);
  static const Color _blueText = Color(0xFF1D4ED8);
  static const Color _blueSoft = Color(0xFFEFF6FF);
  static const Color _red = Color(0xFFBA1A1A);
  static const Color _redText = Color(0xFFDC2626);
  static const Color _redSoft = Color(0xFFFEF2F2);
  static const Color _neutralText = Color(0xFF475569);
  static const Color _neutralSoft = Color(0xFFF1F5F9);
  static const Color _rowDivider = Color(0xFFF8FAFC);

  final WalletController controller = Get.isRegistered<WalletController>()
      ? Get.find<WalletController>()
      : Get.put(WalletController());
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    controller.loadFundFlows(reset: true);
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
      controller.loadFundFlows();
    }
  }

  bool _isPositive(int? type) {
    return type != null && [1, 2, 4, 6, 10].contains(type);
  }

  DateTime? _dateTimeFromTimestamp(int? value) {
    if (value == null) {
      return null;
    }
    var timestamp = value;
    if (timestamp < 10000000000) {
      timestamp *= 1000;
    }
    return DateTime.fromMillisecondsSinceEpoch(timestamp);
  }

  String _formatDate(int? value) {
    final date = _dateTimeFromTimestamp(value);
    if (date == null) {
      return '-';
    }
    return DateFormat('yyyy-MM-dd').format(date);
  }

  String _formatClock(int? value) {
    final date = _dateTimeFromTimestamp(value);
    if (date == null) {
      return '';
    }
    return DateFormat('HH:mm:ss').format(date);
  }

  String _flowTypeLabel(WalletFundFlowItem item) {
    final label = item.typeName?.trim();
    if (label == null || label.isEmpty) {
      return '-';
    }
    return label;
  }

  _FlowTone _flowTone(WalletFundFlowItem item, {required bool positive}) {
    final typeName = (item.typeName ?? '').toLowerCase();
    final looksLikeRefund =
        typeName.contains('refund') ||
        typeName.contains('返') ||
        typeName.contains('退');

    if (looksLikeRefund) {
      return _FlowTone.neutral;
    }
    return positive ? _FlowTone.income : _FlowTone.expense;
  }

  Color _toneBackground(_FlowTone tone) {
    switch (tone) {
      case _FlowTone.income:
        return _blueSoft;
      case _FlowTone.expense:
        return _redSoft;
      case _FlowTone.neutral:
        return _neutralSoft;
    }
  }

  Color _toneText(_FlowTone tone) {
    switch (tone) {
      case _FlowTone.income:
        return _blueText;
      case _FlowTone.expense:
        return _redText;
      case _FlowTone.neutral:
        return _neutralText;
    }
  }

  Color _amountColor(_FlowTone tone) {
    switch (tone) {
      case _FlowTone.income:
        return _blue;
      case _FlowTone.expense:
        return _red;
      case _FlowTone.neutral:
        return const Color(0xFF1E293B);
    }
  }

  String _formatSignedAmount(
    CurrencyController currency,
    double amountValue, {
    required bool positive,
  }) {
    final formatted = currency.formatUsd(amountValue).replaceFirst('\$ ', r'$');
    return '${positive ? '+' : '-'}$formatted';
  }

  @override
  Widget build(BuildContext context) {
    final currency = Get.find<CurrencyController>();
    return Scaffold(
      backgroundColor: _pageBackground,
      appBar: SettingsStyleAppBar(title: Text('app.user.wallet.flow'.tr)),
      body: Obx(() {
        final isLoading = controller.isLoadingFundFlows.value;
        if (isLoading && controller.fundFlows.isEmpty) {
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: ListView(
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
                children: [
                  _buildFlowTable(
                    context,
                    currency,
                    loading: true,
                    hasMore: controller.hasMoreFundFlows,
                  ),
                ],
              ),
            ),
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
          onRefresh: () => controller.loadFundFlows(reset: true),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: ListView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(
                  parent: ClampingScrollPhysics(),
                ),
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
                children: [
                  _buildFlowTable(
                    context,
                    currency,
                    loading: isLoading,
                    hasMore: controller.hasMoreFundFlows,
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildFlowTable(
    BuildContext context,
    CurrencyController currency, {
    required bool loading,
    required bool hasMore,
  }) {
    final items = controller.fundFlows;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: _cardBackground,
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(
            color: _cardShadowColor,
            blurRadius: 20,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Column(
          children: [
            if (items.isEmpty && loading)
              const _FlowLoadingRows(itemCount: 6)
            else if (items.isEmpty)
              _buildEmptyState(context)
            else ...[
              for (var index = 0; index < items.length; index++)
                _buildFlowRow(
                  context,
                  currency,
                  item: items[index],
                  showTopDivider: index > 0,
                ),
              _buildLoadMoreFooter(context, loading: loading, hasMore: hasMore),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 72),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: _rowDivider)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _neutralSoft,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.receipt_long_outlined,
              color: _secondaryText,
              size: 24,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'app.common.no_data'.tr,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: _secondaryText,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlowRow(
    BuildContext context,
    CurrencyController currency, {
    required WalletFundFlowItem item,
    required bool showTopDivider,
  }) {
    final positive = _isPositive(item.type);
    final tone = _flowTone(item, positive: positive);
    final amountValue = item.amount?.abs() ?? 0;
    final amountText = _formatSignedAmount(
      currency,
      amountValue,
      positive: positive,
    );
    final serialLabel = item.serialNumber?.trim().isNotEmpty == true
        ? item.serialNumber!.trim()
        : '-';
    final typeLabel = _flowTypeLabel(item);
    final clockText = _formatClock(item.createTime);
    final beforeBalanceText = currency.formatUsd(item.beforeBalance ?? 0);

    return DecoratedBox(
      decoration: BoxDecoration(
        border: showTopDivider
            ? const Border(top: BorderSide(color: _rowDivider))
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Get.toNamed(Routers.WALLET_FLOW_DETAIL, arguments: item);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        serialLabel,
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.visible,
                        style: const TextStyle(
                          color: _primaryText,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          height: 20 / 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 86),
                      child: Text(
                        amountText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                        style: TextStyle(
                          color: _amountColor(tone),
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          height: 24 / 16,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _formatDate(item.createTime),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _secondaryText,
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              height: 16 / 12,
                            ),
                          ),
                          if (clockText.isNotEmpty)
                            Text(
                              clockText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _secondaryText,
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                                height: 16 / 12,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      fit: FlexFit.loose,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const ClampingScrollPhysics(),
                          child: Tooltip(
                            message: typeLabel,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _toneBackground(tone),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                typeLabel.toUpperCase(),
                                maxLines: 1,
                                softWrap: false,
                                overflow: TextOverflow.visible,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: _toneText(tone),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  height: 1.5,
                                  letterSpacing: 0,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 82),
                      child: Text(
                        beforeBalanceText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                        style: const TextStyle(
                          color: _secondaryText,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          height: 16.5 / 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadMoreFooter(
    BuildContext context, {
    required bool loading,
    required bool hasMore,
  }) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) {
        return FadeTransition(opacity: animation, child: child);
      },
      child: loading
          ? const Padding(
              key: ValueKey('flow_loading'),
              padding: EdgeInsets.only(bottom: 12),
              child: _FlowLoadingRows(itemCount: 2),
            )
          : hasMore
          ? const SizedBox(key: ValueKey('flow_idle'), height: 4)
          : const ListEndTip(
              key: ValueKey('flow_no_more'),
              padding: EdgeInsets.fromLTRB(24, 16, 24, 18),
            ),
    );
  }
}

class _FlowLoadingRows extends StatelessWidget {
  const _FlowLoadingRows({required this.itemCount});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var index = 0; index < itemCount; index++)
          _FlowLoadingRow(showTopDivider: index > 0),
      ],
    );
  }
}

class _FlowLoadingRow extends StatelessWidget {
  const _FlowLoadingRow({required this.showTopDivider});

  final bool showTopDivider;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: showTopDivider
            ? const Border(
                top: BorderSide(color: _WalletFlowPageState._rowDivider),
              )
            : null,
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              flex: 5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _FlowLoadingBlock(width: 132, height: 16),
                  SizedBox(height: 8),
                  _FlowLoadingBlock(width: 82, height: 12),
                  SizedBox(height: 6),
                  _FlowLoadingBlock(width: 58, height: 12),
                ],
              ),
            ),
            SizedBox(width: 14),
            Expanded(
              flex: 4,
              child: Align(
                alignment: Alignment.centerLeft,
                child: _FlowLoadingBlock(width: 96, height: 24),
              ),
            ),
            SizedBox(width: 14),
            Expanded(
              flex: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _FlowLoadingBlock(width: 104, height: 18),
                  SizedBox(height: 8),
                  _FlowLoadingBlock(width: 78, height: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FlowLoadingBlock extends StatelessWidget {
  const _FlowLoadingBlock({required this.width, required this.height});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: _WalletFlowPageState._loadingLine,
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}

enum _FlowTone { income, expense, neutral }
