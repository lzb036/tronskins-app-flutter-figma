import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:tronskins_app/api/model/wallet/wallet_models.dart';
import 'package:tronskins_app/common/hooks/currency/CurrencyController.dart';
import 'package:tronskins_app/common/widgets/settings_style_app_bar.dart';
import 'package:tronskins_app/components/layout/list_end_tip.dart';
import 'package:tronskins_app/controllers/wallet/wallet_controller.dart';
import 'package:tronskins_app/l10n/inline_i18n.dart';
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
  static const Color _dateFieldBorder = Color(0xFFE2E8F0);

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

  String _formatFilterDate(DateTime? date) {
    if (date == null) {
      return '-';
    }
    return DateFormat('yyyy-MM-dd').format(date);
  }

  String _dateFilterLabel() {
    final start = controller.fundFlowStartDate.value;
    final end = controller.fundFlowEndDate.value;
    if (start == null && end == null) {
      return '';
    }
    return '${_formatFilterDate(start)} ~ ${_formatFilterDate(end)}';
  }

  bool get _hasDateFilter => controller.hasFundFlowDateFilter;

  String _text({required String zh, required String en}) {
    return InlineI18n.text(zh: zh, en: en);
  }

  Future<void> _openDateRangeSheet() async {
    final now = DateTime.now();
    final result = await showModalBottomSheet<_WalletFlowDateRange>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0x8A000000),
      builder: (context) {
        return _WalletFlowDateRangeSheet(
          initialStartDate: controller.fundFlowStartDate.value,
          initialEndDate: controller.fundFlowEndDate.value,
          firstDate: DateTime(now.year - 5),
          lastDate: DateTime(now.year + 1, 12, 31),
        );
      },
    );
    if (result == null) {
      return;
    }
    if (result.clear) {
      await controller.clearFundFlowDateRange();
      return;
    }
    await controller.applyFundFlowDateRange(
      startDate: result.startDate,
      endDate: result.endDate,
    );
  }

  @override
  Widget build(BuildContext context) {
    final currency = Get.find<CurrencyController>();
    return Scaffold(
      backgroundColor: _pageBackground,
      appBar: SettingsStyleAppBar(
        title: Text('app.user.wallet.flow'.tr),
        actions: [Obx(_buildDateFilterAction)],
      ),
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
                  if (_hasDateFilter) ...[
                    _buildActiveDateFilter(context),
                    const SizedBox(height: 12),
                  ],
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
                  if (_hasDateFilter) ...[
                    _buildActiveDateFilter(context),
                    const SizedBox(height: 12),
                  ],
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

  Widget _buildDateFilterAction() {
    final active = _hasDateFilter;
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: Tooltip(
        message: _text(zh: '按时间查询', en: 'Filter by date'),
        child: Material(
          color: active ? _blueSoft : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: _openDateRangeSheet,
            child: SizedBox(
              width: 42,
              height: 42,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    Icons.calendar_month_outlined,
                    color: active ? _blueText : _primaryText,
                    size: 22,
                  ),
                  if (active)
                    PositionedDirectional(
                      top: 9,
                      end: 8,
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: _blue,
                          shape: BoxShape.circle,
                        ),
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

  Widget _buildActiveDateFilter(BuildContext context) {
    return Material(
      color: _neutralSoft,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: _openDateRangeSheet,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              const Icon(
                Icons.calendar_month_outlined,
                color: _blueText,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _dateFilterLabel(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _primaryText,
                    fontSize: 13,
                    height: 19.5 / 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              InkResponse(
                radius: 18,
                onTap: controller.clearFundFlowDateRange,
                child: const Icon(
                  Icons.close_rounded,
                  color: _secondaryText,
                  size: 18,
                ),
              ),
            ],
          ),
        ),
      ),
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

class _WalletFlowDateRange {
  const _WalletFlowDateRange({this.startDate, this.endDate}) : clear = false;

  const _WalletFlowDateRange.clear()
    : startDate = null,
      endDate = null,
      clear = true;

  final DateTime? startDate;
  final DateTime? endDate;
  final bool clear;
}

enum _WalletFlowDateEndpoint { start, end }

class _WalletFlowDateRangeSheet extends StatefulWidget {
  const _WalletFlowDateRangeSheet({
    required this.initialStartDate,
    required this.initialEndDate,
    required this.firstDate,
    required this.lastDate,
  });

  final DateTime? initialStartDate;
  final DateTime? initialEndDate;
  final DateTime firstDate;
  final DateTime lastDate;

  @override
  State<_WalletFlowDateRangeSheet> createState() =>
      _WalletFlowDateRangeSheetState();
}

class _WalletFlowDateRangeSheetState extends State<_WalletFlowDateRangeSheet> {
  static const double _pickerHeight = 210;
  static const double _pickerItemExtent = 58;
  static const Color _sheetBackground = Colors.white;
  static const Color _mutedBackground = Color(0xFFF8FAFC);
  static const Color _primary = Color(0xFF1E40AF);
  static const Color _primaryBright = Color(0xFF3B82F6);
  static const Color _title = Color(0xFF191C1E);
  static const Color _body = Color(0xFF444653);
  static const Color _hint = Color(0xFF9CA3AF);
  static const Color _selectionLine = Color(0xFFB8BDC7);
  static const Color _clearButton = Color(0xFF4B5875);

  late final List<int> _years;
  late final FixedExtentScrollController _yearController;
  late final FixedExtentScrollController _monthController;
  late final FixedExtentScrollController _dayController;
  late DateTime _startDate;
  late DateTime _endDate;
  _WalletFlowDateEndpoint _activeEndpoint = _WalletFlowDateEndpoint.start;

  @override
  void initState() {
    super.initState();
    final today = _dateOnly(DateTime.now());
    final defaultStart = DateTime(today.year - 1, today.month, today.day);
    final initialStart = widget.initialStartDate ?? defaultStart;
    final initialEnd = widget.initialEndDate ?? today;
    _startDate = _clampDate(initialStart);
    _endDate = _clampDate(initialEnd);
    if (_startDate.isAfter(_endDate)) {
      _startDate = _endDate;
    }
    _years = List<int>.generate(
      widget.lastDate.year - widget.firstDate.year + 1,
      (index) => widget.firstDate.year + index,
    );
    _yearController = FixedExtentScrollController(
      initialItem: _selectedYearIndex,
    );
    _monthController = FixedExtentScrollController(
      initialItem: _selectedMonthIndex,
    );
    _dayController = FixedExtentScrollController(
      initialItem: _selectedDayIndex,
    );
  }

  @override
  void dispose() {
    _yearController.dispose();
    _monthController.dispose();
    _dayController.dispose();
    super.dispose();
  }

  DateTime get _activeDate {
    return _activeEndpoint == _WalletFlowDateEndpoint.start
        ? _startDate
        : _endDate;
  }

  int get _selectedYearIndex {
    final index = _years.indexOf(_activeDate.year);
    return index < 0 ? 0 : index;
  }

  int get _selectedMonthIndex => _activeDate.month - 1;

  int get _selectedDayIndex => _activeDate.day - 1;

  int get _dayCount {
    return DateUtils.getDaysInMonth(_activeDate.year, _activeDate.month);
  }

  static DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  DateTime _clampDate(DateTime value) {
    final date = _dateOnly(value);
    final first = _dateOnly(widget.firstDate);
    final last = _dateOnly(widget.lastDate);
    if (date.isBefore(first)) {
      return first;
    }
    if (date.isAfter(last)) {
      return last;
    }
    return date;
  }

  String _formatDate(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  String _text({required String zh, required String en}) {
    return InlineI18n.text(zh: zh, en: en);
  }

  void _setActiveEndpoint(_WalletFlowDateEndpoint endpoint) {
    if (_activeEndpoint == endpoint) {
      return;
    }
    setState(() => _activeEndpoint = endpoint);
    _schedulePickerSync();
  }

  void _schedulePickerSync() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _jumpControllerToItem(_yearController, _selectedYearIndex);
      _jumpControllerToItem(_monthController, _selectedMonthIndex);
      _jumpControllerToItem(_dayController, _selectedDayIndex);
    });
  }

  void _jumpControllerToItem(
    FixedExtentScrollController controller,
    int index,
  ) {
    if (!controller.hasClients) {
      return;
    }
    controller.jumpToItem(index);
  }

  void _updateActiveDate({int? year, int? month, int? day}) {
    final current = _activeDate;
    final nextYear = year ?? current.year;
    final nextMonth = month ?? current.month;
    final daysInMonth = DateUtils.getDaysInMonth(nextYear, nextMonth);
    final nextDay = (day ?? current.day).clamp(1, daysInMonth).toInt();
    final nextDate = _clampDate(DateTime(nextYear, nextMonth, nextDay));

    setState(() {
      if (_activeEndpoint == _WalletFlowDateEndpoint.start) {
        _startDate = nextDate;
        if (_startDate.isAfter(_endDate)) {
          _endDate = _startDate;
        }
      } else {
        _endDate = nextDate;
        if (_endDate.isBefore(_startDate)) {
          _startDate = _endDate;
        }
      }
    });
    _schedulePickerSync();
  }

  void _confirm() {
    Navigator.of(
      context,
    ).pop(_WalletFlowDateRange(startDate: _startDate, endDate: _endDate));
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.82;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: _sheetBackground,
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Color(0x22000000),
              blurRadius: 32,
              offset: Offset(0, -8),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    _text(zh: '选择日期区间', en: 'Select Date Range'),
                    style: const TextStyle(
                      color: _title,
                      fontSize: 18,
                      height: 27 / 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _buildDateFields(),
                ),
                const SizedBox(height: 26),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: _buildPickerSection(),
                ),
                const SizedBox(height: 28),
                _buildFooter(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return SizedBox(
      height: 70,
      child: Align(
        alignment: AlignmentDirectional.bottomStart,
        child: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close_rounded),
          color: _body,
          iconSize: 32,
          padding: const EdgeInsetsDirectional.only(start: 20),
          constraints: const BoxConstraints(minWidth: 64, minHeight: 54),
        ),
      ),
    );
  }

  Widget _buildDateFields() {
    return Row(
      children: [
        Expanded(
          child: _WalletFlowDateField(
            date: _formatDate(_startDate),
            selected: _activeEndpoint == _WalletFlowDateEndpoint.start,
            onTap: () => _setActiveEndpoint(_WalletFlowDateEndpoint.start),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            '~',
            style: TextStyle(
              color: _body,
              fontSize: 20,
              height: 30 / 20,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: _WalletFlowDateField(
            date: _formatDate(_endDate),
            selected: _activeEndpoint == _WalletFlowDateEndpoint.end,
            onTap: () => _setActiveEndpoint(_WalletFlowDateEndpoint.end),
          ),
        ),
      ],
    );
  }

  Widget _buildPickerSection() {
    return SizedBox(
      height: _pickerHeight,
      child: Row(
        children: [
          _buildPickerColumn(
            controller: _yearController,
            itemCount: _years.length,
            selectedIndex: _selectedYearIndex,
            labelForIndex: (index) => '${_years[index]}',
            onSelectedItemChanged: (index) {
              if (index < 0 || index >= _years.length) {
                return;
              }
              _updateActiveDate(year: _years[index]);
            },
          ),
          _buildPickerColumn(
            controller: _monthController,
            itemCount: 12,
            selectedIndex: _selectedMonthIndex,
            labelForIndex: (index) => '${index + 1}',
            onSelectedItemChanged: (index) {
              _updateActiveDate(month: index + 1);
            },
          ),
          _buildPickerColumn(
            controller: _dayController,
            itemCount: _dayCount,
            selectedIndex: _selectedDayIndex,
            labelForIndex: (index) => '${index + 1}'.padLeft(2, '0'),
            onSelectedItemChanged: (index) {
              _updateActiveDate(day: index + 1);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPickerColumn({
    required FixedExtentScrollController controller,
    required int itemCount,
    required int selectedIndex,
    required String Function(int index) labelForIndex,
    required ValueChanged<int> onSelectedItemChanged,
  }) {
    return Expanded(
      child: CupertinoPicker.builder(
        scrollController: controller,
        itemExtent: _pickerItemExtent,
        magnification: 1.03,
        squeeze: 1.12,
        useMagnifier: true,
        diameterRatio: 1.35,
        selectionOverlay: const _WalletFlowPickerSelectionOverlay(),
        childCount: itemCount,
        onSelectedItemChanged: onSelectedItemChanged,
        itemBuilder: (context, index) {
          final selected = index == selectedIndex;
          return Center(
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 140),
              style: TextStyle(
                color: selected ? _title : _hint,
                fontSize: selected ? 22 : 20,
                height: 1.2,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
              child: Text(labelForIndex(index)),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 18),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 52,
              child: TextButton(
                onPressed: () {
                  Navigator.of(context).pop(const _WalletFlowDateRange.clear());
                },
                style: TextButton.styleFrom(
                  backgroundColor: _clearButton,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 17,
                    height: 24 / 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: Text('app.market.filter.clear'.tr),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                gradient: const LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: <Color>[_primary, _primaryBright],
                ),
              ),
              child: SizedBox(
                height: 52,
                child: TextButton(
                  onPressed: _confirm,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 17,
                      height: 24 / 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: Text('app.common.confirm'.tr),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WalletFlowDateField extends StatelessWidget {
  const _WalletFlowDateField({
    required this.date,
    required this.selected,
    required this.onTap,
  });

  final String date;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor = selected
        ? _WalletFlowDateRangeSheetState._primary
        : _WalletFlowPageState._dateFieldBorder;
    return Material(
      color: _WalletFlowDateRangeSheetState._mutedBackground,
      borderRadius: BorderRadius.circular(2),
      child: InkWell(
        borderRadius: BorderRadius.circular(2),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 54,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            border: Border.all(color: borderColor, width: selected ? 1.4 : 1),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              date,
              maxLines: 1,
              style: const TextStyle(
                color: _WalletFlowDateRangeSheetState._body,
                fontSize: 18,
                height: 27 / 18,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WalletFlowPickerSelectionOverlay extends StatelessWidget {
  const _WalletFlowPickerSelectionOverlay();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        border: Border.symmetric(
          horizontal: BorderSide(
            color: _WalletFlowDateRangeSheetState._selectionLine,
            width: 1.2,
          ),
        ),
      ),
    );
  }
}

enum _FlowTone { income, expense, neutral }
