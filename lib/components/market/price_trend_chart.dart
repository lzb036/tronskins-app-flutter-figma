import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:tronskins_app/api/model/market/market_models.dart';
import 'package:tronskins_app/common/hooks/currency/CurrencyController.dart';

const Color _trendSlate100 = Color(0xFFF1F5F9);
const Color _trendSlate200 = Color(0xFFE2E8F0);
const Color _trendSlate300 = Color(0xFFCBD5E1);
const Color _trendSlate500 = Color(0xFF64748B);
const Color _trendSlate900 = Color(0xFF0F172A);
const Color _trendBlue700 = Color(0xFF1E40AF);
const Color _trendBlue500 = Color(0xFF3B82F6);
const double _trendChartTopPadding = 14;
const double _trendBottomTitlesReservedHeight = 34;
const double _trendMinLeftAxisWidth = 28;
const double _trendMaxLeftAxisWidth = 44;

class _TrendYAxisMetrics {
  const _TrendYAxisMetrics({
    required this.min,
    required this.max,
    required this.interval,
  });

  final double min;
  final double max;
  final double interval;
}

class PriceTrendChart extends StatefulWidget {
  const PriceTrendChart({super.key, required this.points});

  final List<MarketPricePoint> points;

  @override
  State<PriceTrendChart> createState() => _PriceTrendChartState();
}

class _PriceTrendChartState extends State<PriceTrendChart> {
  final ScrollController _scrollController = ScrollController();
  late String _pointSignature;
  int? _selectedSpotIndex;
  bool _pendingResetScrollPosition = false;
  bool _pendingScrollAnimated = false;

  @override
  void initState() {
    super.initState();
    _pointSignature = _buildPointSignature(widget.points);
    _queueScrollToStart(animated: false);
  }

  @override
  void didUpdateWidget(covariant PriceTrendChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextSignature = _buildPointSignature(widget.points);
    if (nextSignature != _pointSignature) {
      _pointSignature = nextSignature;
      _selectedSpotIndex = null;
      _queueScrollToStart(animated: true);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.points.isEmpty) {
      return Center(child: Text('app.common.no_data'.tr));
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currency = Get.find<CurrencyController>();
    final sorted = List<MarketPricePoint>.from(widget.points)
      ..sort((a, b) => a.time.compareTo(b.time));
    final spots = <FlSpot>[];
    final times = <DateTime>[];
    final convertedPrices = <double>[];

    for (var i = 0; i < sorted.length; i += 1) {
      final convertedPrice = _convertPrice(sorted[i].price, currency);
      convertedPrices.add(convertedPrice);
      spots.add(FlSpot(i.toDouble(), convertedPrice));
      times.add(_toDateTime(sorted[i].time));
    }

    final yAxisMetrics = _calculateYAxisMetrics(
      convertedPrices,
      currencyCode: currency.code,
    );
    final displayMin = yAxisMetrics.min;
    final displayMax = yAxisMetrics.max;
    final leftInterval = yAxisMetrics.interval;
    final axisDateFormat = DateFormat('yyyy-MM-dd');
    final subtitleColor = isDark ? _trendSlate300 : _trendSlate500;
    final int? selectedSpotIndex =
        _selectedSpotIndex != null && _selectedSpotIndex! < spots.length
        ? _selectedSpotIndex
        : null;
    final lineBarData = LineChartBarData(
      spots: spots,
      showingIndicators: selectedSpotIndex == null
          ? const <int>[]
          : <int>[selectedSpotIndex],
      gradient: const LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: <Color>[_trendBlue700, _trendBlue500],
      ),
      barWidth: 3,
      isCurved: spots.length > 2,
      curveSmoothness: 0.24,
      preventCurveOverShooting: true,
      isStrokeCapRound: true,
      isStrokeJoinRound: true,
      dotData: FlDotData(
        show: true,
        checkToShowDot: (spot, barData) => true,
        getDotPainter: (spot, percent, barData, index) {
          final dotRadius = _resolveDotRadius(spots.length);
          return FlDotCirclePainter(
            radius: dotRadius,
            color: _trendBlue500,
            strokeColor: isDark ? _trendSlate900 : Colors.white,
            strokeWidth: math.max(1.2, dotRadius * 0.55),
          );
        },
      ),
      belowBarData: BarAreaData(
        show: true,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            _trendBlue500.withValues(alpha: 0.22),
            _trendBlue700.withValues(alpha: 0.10),
            _trendBlue700.withValues(alpha: 0.00),
          ],
          stops: const <double>[0.0, 0.45, 1.0],
        ),
      ),
    );
    final showingTooltipIndicators = selectedSpotIndex == null
        ? const <ShowingTooltipIndicators>[]
        : <ShowingTooltipIndicators>[
            ShowingTooltipIndicators([
              LineBarSpot(lineBarData, 0, lineBarData.spots[selectedSpotIndex]),
            ]),
          ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final axisLabelStyle = TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: subtitleColor,
        );
        final yAxisValues = _buildYAxisValues(
          min: displayMin,
          max: displayMax,
          interval: leftInterval,
        );
        final leftAxisWidth = _measureLeftAxisWidth(
          context,
          values: yAxisValues,
          style: axisLabelStyle,
          labelBuilder: (value) =>
              _formatAxisPrice(value, currency, interval: leftInterval),
        );
        final plotViewportWidth = math.max(
          0.0,
          constraints.maxWidth - leftAxisWidth,
        );
        final chartWidth = _resolveChartWidth(
          pointCount: spots.length,
          viewportWidth: plotViewportWidth,
        );
        final labelIndices = _buildLabelIndices(
          length: times.length,
          chartWidth: chartWidth,
        );
        final bottomInterval = _resolveBottomInterval(labelIndices);
        final shouldScroll = chartWidth > plotViewportWidth + 1;

        if (_pendingResetScrollPosition) {
          _pendingResetScrollPosition = false;
          _scheduleScrollToOffset(0.0, animated: _pendingScrollAnimated);
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: leftAxisWidth,
              child: Padding(
                padding: const EdgeInsets.only(top: _trendChartTopPadding),
                child: Column(
                  children: [
                    Expanded(
                      child: _FixedYAxisLabels(
                        values: yAxisValues,
                        minY: displayMin,
                        maxY: displayMax,
                        labelBuilder: (value) => _formatAxisPrice(
                          value,
                          currency,
                          interval: leftInterval,
                        ),
                        subtitleColor: subtitleColor,
                        textStyle: axisLabelStyle,
                      ),
                    ),
                    const SizedBox(height: _trendBottomTitlesReservedHeight),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Scrollbar(
                controller: _scrollController,
                thumbVisibility: shouldScroll,
                interactive: shouldScroll,
                notificationPredicate: (notification) =>
                    notification.metrics.axis == Axis.horizontal,
                child: SingleChildScrollView(
                  controller: _scrollController,
                  scrollDirection: Axis.horizontal,
                  physics: shouldScroll
                      ? const BouncingScrollPhysics()
                      : const NeverScrollableScrollPhysics(),
                  child: SizedBox(
                    width: chartWidth,
                    child: Padding(
                      padding: const EdgeInsets.only(
                        top: _trendChartTopPadding,
                      ),
                      child: LineChart(
                        LineChartData(
                          minX: 0,
                          maxX: spots.isEmpty ? 0 : spots.last.x,
                          minY: displayMin,
                          maxY: displayMax,
                          showingTooltipIndicators: showingTooltipIndicators,
                          clipData: const FlClipData(
                            top: true,
                            bottom: true,
                            left: false,
                            right: false,
                          ),
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: false,
                            horizontalInterval: leftInterval,
                            getDrawingHorizontalLine: (value) => FlLine(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : _trendSlate100,
                              strokeWidth: 1,
                            ),
                          ),
                          borderData: FlBorderData(show: false),
                          titlesData: FlTitlesData(
                            topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            leftTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: _trendBottomTitlesReservedHeight,
                                interval: bottomInterval,
                                getTitlesWidget: (value, meta) {
                                  final index = value.round();
                                  if (index < 0 ||
                                      index >= times.length ||
                                      !labelIndices.contains(index)) {
                                    return const SizedBox.shrink();
                                  }
                                  final label = axisDateFormat.format(
                                    times[index],
                                  );
                                  final edgeOffset = _resolveBottomLabelOffset(
                                    index: index,
                                    totalCount: times.length,
                                  );
                                  return SideTitleWidget(
                                    axisSide: meta.axisSide,
                                    space: 8,
                                    child: Transform.translate(
                                      offset: Offset(edgeOffset, 0),
                                      child: Text(label, style: axisLabelStyle),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          lineBarsData: [lineBarData],
                          lineTouchData: LineTouchData(
                            handleBuiltInTouches: false,
                            touchSpotThreshold: 22,
                            touchCallback: _handleChartTap,
                            touchTooltipData: LineTouchTooltipData(
                              tooltipRoundedRadius: 16,
                              tooltipPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              tooltipMargin: 14,
                              fitInsideHorizontally: true,
                              fitInsideVertically: true,
                              tooltipBgColor: isDark
                                  ? _trendSlate900
                                  : Colors.white,
                              tooltipBorder: BorderSide(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.08)
                                    : _trendSlate200,
                              ),
                              getTooltipItems: (items) {
                                return items.map((item) {
                                  final date = DateFormat(
                                    'yyyy-MM-dd',
                                  ).format(times[item.spotIndex]);
                                  return LineTooltipItem(
                                    '$date\n${_formatConvertedPrice(item.y, currency)}',
                                    TextStyle(
                                      color: isDark
                                          ? Colors.white
                                          : _trendSlate900,
                                      fontWeight: FontWeight.w700,
                                      height: 1.5,
                                    ),
                                  );
                                }).toList();
                              },
                            ),
                            getTouchedSpotIndicator: (barData, spotIndexes) {
                              return spotIndexes.map((index) {
                                return TouchedSpotIndicatorData(
                                  FlLine(
                                    color: _trendBlue500.withValues(
                                      alpha: 0.24,
                                    ),
                                    strokeWidth: 1.2,
                                  ),
                                  FlDotData(
                                    show: true,
                                    getDotPainter:
                                        (spot, percent, data, spotIndex) {
                                          return FlDotCirclePainter(
                                            radius: 5.4,
                                            color: _trendBlue500,
                                            strokeColor: isDark
                                                ? _trendSlate900
                                                : Colors.white,
                                            strokeWidth: 2.8,
                                          );
                                        },
                                  ),
                                );
                              }).toList();
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _handleChartTap(FlTouchEvent event, LineTouchResponse? response) {
    if (event is! FlTapUpEvent) {
      return;
    }

    final touchedSpots = response?.lineBarSpots;
    if (touchedSpots == null || touchedSpots.isEmpty) {
      return;
    }

    final spotIndex = touchedSpots.first.spotIndex;

    setState(() {
      _selectedSpotIndex = _selectedSpotIndex == spotIndex ? null : spotIndex;
    });
  }

  void _queueScrollToStart({required bool animated}) {
    _pendingResetScrollPosition = true;
    _pendingScrollAnimated = animated;
  }

  void _scheduleScrollToOffset(
    double targetOffset, {
    required bool animated,
    int retries = 6,
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      if (!_scrollController.hasClients) {
        if (retries > 0) {
          _scheduleScrollToOffset(
            targetOffset,
            animated: animated,
            retries: retries - 1,
          );
        }
        return;
      }

      final position = _scrollController.position;
      final target = targetOffset.clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      );
      if ((position.pixels - target).abs() < 1) {
        return;
      }

      if (animated && position.haveDimensions) {
        _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        );
        return;
      }

      _scrollController.jumpTo(target);
    });
  }

  String _buildPointSignature(List<MarketPricePoint> points) {
    if (points.isEmpty) {
      return 'empty';
    }
    return '${points.length}:${points.first.time}:${points.last.time}';
  }

  DateTime _toDateTime(int value) {
    var timestamp = value;
    if (timestamp < 10000000000) {
      timestamp *= 1000;
    }
    return DateTime.fromMillisecondsSinceEpoch(timestamp);
  }

  Set<int> _buildLabelIndices({
    required int length,
    required double chartWidth,
  }) {
    if (length <= 0) {
      return const <int>{};
    }
    if (length <= 2) {
      return List<int>.generate(length, (index) => index).toSet();
    }

    final usableWidth = math.max(0.0, chartWidth - 32);
    final desiredLabels = (usableWidth / 104).floor().clamp(2, length);
    if (desiredLabels >= length) {
      return List<int>.generate(length, (index) => index).toSet();
    }

    final indices = <int>{0, length - 1};
    final step = math.max(
      1,
      ((length - 1) / math.max(desiredLabels - 1, 1)).round(),
    );
    for (var index = step; index < length - 1; index += step) {
      indices.add(index);
    }
    return indices;
  }

  double _resolveBottomInterval(Set<int> indices) {
    if (indices.length <= 1) {
      return 1;
    }
    final ordered = indices.toList()..sort();
    return math.max(1, ordered[1] - ordered[0]).toDouble();
  }

  double _resolveBottomLabelOffset({
    required int index,
    required int totalCount,
  }) {
    if (index == 0) {
      return 26;
    }
    if (index == totalCount - 1) {
      return -30;
    }
    return 0;
  }

  double _resolveChartWidth({
    required int pointCount,
    required double viewportWidth,
  }) {
    if (pointCount <= 1) {
      return viewportWidth;
    }

    final pointSpacing = math.max(
      _resolvePointSpacing(pointCount),
      _resolveLabelSpacing(pointCount),
    );
    final contentWidth = (pointCount - 1) * pointSpacing;
    return math.max(viewportWidth, contentWidth);
  }

  List<double> _buildYAxisValues({
    required double min,
    required double max,
    required double interval,
  }) {
    if (interval <= 0 || max <= min) {
      return <double>[min, max];
    }

    final stepCount = ((max - min) / interval).round();
    return List<double>.generate(
      stepCount + 1,
      (index) => _normalizeAxisValue(min + interval * index),
    );
  }

  double _measureLeftAxisWidth(
    BuildContext context, {
    required List<double> values,
    required TextStyle style,
    required String Function(double value) labelBuilder,
  }) {
    if (values.isEmpty) {
      return _trendMinLeftAxisWidth;
    }

    final textDirection = Directionality.of(context);
    final textScaler = MediaQuery.textScalerOf(context);
    var widest = 0.0;

    for (final value in values) {
      final painter = TextPainter(
        text: TextSpan(text: labelBuilder(value), style: style),
        textDirection: textDirection,
        textScaler: textScaler,
        maxLines: 1,
      )..layout();
      widest = math.max(widest, painter.width);
    }

    return (widest + 2)
        .clamp(_trendMinLeftAxisWidth, _trendMaxLeftAxisWidth)
        .toDouble();
  }

  double _resolvePointSpacing(int pointCount) {
    if (pointCount <= 7) {
      return 68;
    }
    if (pointCount <= 14) {
      return 54;
    }
    if (pointCount <= 30) {
      return 34;
    }
    if (pointCount <= 90) {
      return 22;
    }
    if (pointCount <= 180) {
      return 16;
    }
    return 12;
  }

  double _resolveLabelSpacing(int pointCount) {
    if (pointCount <= 7) {
      return 88;
    }
    if (pointCount <= 30) {
      return 72;
    }
    if (pointCount <= 90) {
      return 56;
    }
    if (pointCount <= 180) {
      return 42;
    }
    return 32;
  }

  double _resolveDotRadius(int pointCount) {
    if (pointCount <= 7) {
      return 4.0;
    }
    if (pointCount <= 30) {
      return 3.2;
    }
    if (pointCount <= 90) {
      return 2.4;
    }
    return 1.8;
  }

  _TrendYAxisMetrics _calculateYAxisMetrics(
    List<double> values, {
    required String currencyCode,
  }) {
    final minimumStep = _minimumYAxisStepForCode(currencyCode);
    if (values.isEmpty) {
      return _TrendYAxisMetrics(
        min: 0,
        max: minimumStep * 4,
        interval: minimumStep,
      );
    }

    final minValue = values.reduce(math.min);
    final maxValue = values.reduce(math.max);
    final delta = maxValue - minValue;

    if (delta.abs() < 1e-9) {
      final center = maxValue;
      final interval = center == 0
          ? minimumStep
          : math.max(
              minimumStep,
              _niceNumber(center.abs() * 0.15, round: true),
            );
      final min = center <= 0 ? 0.0 : math.max(0.0, center - interval * 2);
      final max = math.max(interval * 4, center + interval * 2);
      return _TrendYAxisMetrics(
        min: _normalizeAxisValue(min),
        max: _normalizeAxisValue(max),
        interval: _normalizeAxisValue(interval),
      );
    }

    final padding = math.max(delta * 0.15, minimumStep * 0.5);
    final rawMin = math.max(0.0, minValue - padding);
    final rawMax = maxValue + padding;
    final interval = math.max(
      minimumStep,
      _niceNumber((rawMax - rawMin) / 4, round: true),
    );
    final min = rawMin <= 0
        ? 0.0
        : (rawMin / interval).floorToDouble() * interval;
    var max = (rawMax / interval).ceilToDouble() * interval;
    if (max <= min) {
      max = min + interval * 4;
    }
    if ((max - min) / interval < 3) {
      max = min + interval * 4;
    }
    return _TrendYAxisMetrics(
      min: _normalizeAxisValue(min),
      max: _normalizeAxisValue(max),
      interval: _normalizeAxisValue(interval),
    );
  }

  double _minimumYAxisStepForCode(String currencyCode) {
    const zeroDecimalCurrencies = <String>{'JPY', 'KRW', 'VND', 'IDR'};
    if (zeroDecimalCurrencies.contains(currencyCode)) {
      return 1;
    }
    return 0.01;
  }

  double _niceNumber(double value, {required bool round}) {
    if (!value.isFinite || value <= 0) {
      return 1;
    }

    final exponent = math.pow(10, (math.log(value) / math.ln10).floor());
    final fraction = value / exponent;

    late final double niceFraction;
    if (round) {
      if (fraction < 1.5) {
        niceFraction = 1;
      } else if (fraction < 3) {
        niceFraction = 2;
      } else if (fraction < 7) {
        niceFraction = 5;
      } else {
        niceFraction = 10;
      }
    } else {
      if (fraction <= 1) {
        niceFraction = 1;
      } else if (fraction <= 2) {
        niceFraction = 2;
      } else if (fraction <= 5) {
        niceFraction = 5;
      } else {
        niceFraction = 10;
      }
    }

    return niceFraction * exponent;
  }

  double _normalizeAxisValue(double value) {
    return double.parse(value.toStringAsFixed(6));
  }

  double _convertPrice(double usdAmount, CurrencyController currency) {
    return usdAmount * currency.currentRate;
  }

  String _formatAxisPrice(
    double value,
    CurrencyController currency, {
    required double interval,
  }) {
    final digits = _axisFractionDigitsForInterval(interval, currency.code);
    return '${currency.symbol}${value.toStringAsFixed(digits)}';
  }

  String _formatConvertedPrice(double amount, CurrencyController currency) {
    final digits = _fractionDigitsForValue(
      amount,
      currencyCode: currency.code,
      compact: true,
    );
    return '${currency.symbol} ${amount.toStringAsFixed(digits)}';
  }

  int _axisFractionDigitsForInterval(double interval, String currencyCode) {
    const zeroDecimalCurrencies = <String>{'JPY', 'KRW', 'VND', 'IDR'};
    if (zeroDecimalCurrencies.contains(currencyCode)) {
      return 0;
    }

    if (!interval.isFinite || interval <= 0) {
      return 2;
    }

    if (interval >= 1) {
      return 2;
    }

    final digits = (-math.log(interval) / math.ln10).ceil();
    return digits.clamp(2, 4);
  }

  int _fractionDigitsForValue(
    double value, {
    required String currencyCode,
    required bool compact,
  }) {
    const zeroDecimalCurrencies = <String>{'JPY', 'KRW', 'VND', 'IDR'};
    if (zeroDecimalCurrencies.contains(currencyCode)) {
      return 0;
    }

    final absValue = value.abs();
    if (absValue >= 1) {
      return 2;
    }
    if (absValue >= 0.1) {
      return compact ? 2 : 3;
    }
    if (absValue >= 0.01) {
      return compact ? 3 : 4;
    }
    return compact ? 4 : 5;
  }
}

class _FixedYAxisLabels extends StatelessWidget {
  const _FixedYAxisLabels({
    required this.values,
    required this.minY,
    required this.maxY,
    required this.labelBuilder,
    required this.subtitleColor,
    required this.textStyle,
  });

  final List<double> values;
  final double minY;
  final double maxY;
  final String Function(double value) labelBuilder;
  final Color subtitleColor;
  final TextStyle textStyle;

  @override
  Widget build(BuildContext context) {
    final range = maxY - minY;
    final textDirection = Directionality.of(context);
    final textScaler = MediaQuery.textScalerOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          clipBehavior: Clip.none,
          children: values.map((value) {
            final label = labelBuilder(value);
            final labelPainter = TextPainter(
              text: TextSpan(text: label, style: textStyle),
              textDirection: textDirection,
              textScaler: textScaler,
              maxLines: 1,
            )..layout();
            final labelHeight = labelPainter.height;
            final ratio = range == 0 ? 0.0 : ((value - minY) / range);
            final top = ((1 - ratio) * constraints.maxHeight) - labelHeight / 2;
            final clampedTop = top
                .clamp(0.0, math.max(0.0, constraints.maxHeight - labelHeight))
                .toDouble();
            return Positioned(
              top: clampedTop,
              left: 0,
              right: 0,
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  label,
                  maxLines: 1,
                  textAlign: TextAlign.right,
                  style: textStyle.copyWith(color: subtitleColor),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class PriceTrendChartSkeleton extends StatefulWidget {
  const PriceTrendChartSkeleton({super.key});

  @override
  State<PriceTrendChartSkeleton> createState() =>
      _PriceTrendChartSkeletonState();
}

class _PriceTrendChartSkeletonState extends State<PriceTrendChartSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final placeholder = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : const Color(0xFFE2E8F0);
    final placeholderSoft = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : const Color(0xFFF1F5F9);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final shimmerWidth = constraints.maxWidth * 0.45;
            final travel = constraints.maxWidth + shimmerWidth * 2;
            final left = -shimmerWidth + travel * _controller.value;
            return Stack(
              fit: StackFit.expand,
              children: [
                Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _TrendSkeletonBox(
                                width: 132,
                                height: 26,
                                color: placeholder,
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  _TrendSkeletonBox(
                                    width: 118,
                                    height: 28,
                                    radius: 999,
                                    color: placeholderSoft,
                                  ),
                                  const SizedBox(width: 10),
                                  _TrendSkeletonBox(
                                    width: 64,
                                    height: 14,
                                    radius: 7,
                                    color: placeholder,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          children: [
                            _TrendSkeletonBox(
                              width: 84,
                              height: 30,
                              radius: 14,
                              color: placeholderSoft,
                            ),
                            const SizedBox(height: 8),
                            _TrendSkeletonBox(
                              width: 84,
                              height: 30,
                              radius: 14,
                              color: placeholderSoft,
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          color: placeholderSoft.withValues(
                            alpha: isDark ? 0.55 : 0.75,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(14, 18, 14, 14),
                          child: Column(
                            children: [
                              Expanded(
                                child: Column(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: List<Widget>.generate(4, (_) {
                                    return Container(
                                      height: 1,
                                      color: placeholder,
                                    );
                                  }),
                                ),
                              ),
                              const SizedBox(height: 18),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: List<Widget>.generate(8, (_) {
                                  return _TrendSkeletonBox(
                                    width: 30,
                                    height: 10,
                                    radius: 5,
                                    color: placeholder,
                                  );
                                }),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                Positioned(
                  top: 0,
                  bottom: 0,
                  left: left,
                  child: IgnorePointer(
                    child: Container(
                      width: shimmerWidth,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: <Color>[
                            Colors.white.withValues(alpha: 0.0),
                            Colors.white.withValues(
                              alpha: isDark ? 0.10 : 0.35,
                            ),
                            Colors.white.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _TrendSkeletonBox extends StatelessWidget {
  const _TrendSkeletonBox({
    required this.width,
    required this.height,
    required this.color,
    this.radius = 8,
  });

  final double width;
  final double height;
  final double radius;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
