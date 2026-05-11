import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:tronskins_app/api/model/market/market_models.dart';
import 'package:tronskins_app/common/hooks/currency/CurrencyController.dart';

const Color _trendSlate300 = Color(0xFFCBD5E1);
const Color _trendSlate900 = Color(0xFF0F172A);
const Color _trendBuffBlue = Color(0xFF4A6FD4);
const Color _trendBuffGrid = Color(0xFFE6E8EE);
const Color _trendBuffAxis = Color(0xFFDADDE5);
const Color _trendBuffText = Color(0xFF8A8F99);
const Color _trendBuffTooltip = Color(0xFFF5F7FC);
const Color _trendBuffTooltipBorder = Color(0xFFD6DCE8);
const double _trendChartTopPadding = 14;
const double _trendBottomTitlesReservedHeight = 34;
const double _trendMinLeftAxisWidth = 28;
const double _trendMaxLeftAxisWidth = 44;
const double _trendMinHorizontalDomainPadding = 0.45;
const int _trendMaxVisibleDotCount = 7;

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

class _TrendXAxisLabel {
  const _TrendXAxisLabel({required this.index, required this.label});

  final int index;
  final String label;
}

class PriceTrendChart extends StatefulWidget {
  const PriceTrendChart({super.key, required this.points});

  final List<MarketPricePoint> points;

  @override
  State<PriceTrendChart> createState() => _PriceTrendChartState();
}

class _PriceTrendChartState extends State<PriceTrendChart> {
  late String _pointSignature;
  int? _selectedSpotIndex;

  @override
  void initState() {
    super.initState();
    _pointSignature = _buildPointSignature(widget.points);
  }

  @override
  void didUpdateWidget(covariant PriceTrendChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextSignature = _buildPointSignature(widget.points);
    if (nextSignature != _pointSignature) {
      _pointSignature = nextSignature;
      _selectedSpotIndex = null;
    }
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
    final xAxisDateFormat = DateFormat('MM-dd');
    final xAxisYearLabel = _buildXAxisYearLabel(times);
    final subtitleColor = isDark ? _trendSlate300 : _trendBuffText;
    final int? selectedSpotIndex =
        _selectedSpotIndex != null && _selectedSpotIndex! < spots.length
        ? _selectedSpotIndex
        : null;
    final visibleDotIndices = _buildVisibleDotIndices(spots);
    final lineBarData = LineChartBarData(
      spots: spots,
      showingIndicators: selectedSpotIndex == null
          ? const <int>[]
          : <int>[selectedSpotIndex],
      color: _trendBuffBlue,
      barWidth: 2.8,
      isCurved: spots.length > 2,
      curveSmoothness: 0.22,
      preventCurveOverShooting: true,
      isStrokeCapRound: true,
      isStrokeJoinRound: true,
      dotData: FlDotData(
        show: true,
        checkToShowDot: (spot, barData) {
          final index = spot.x.round();
          return visibleDotIndices.contains(index) ||
              index == selectedSpotIndex;
        },
        getDotPainter: (spot, percent, barData, index) {
          final isSelected = spot.x.round() == selectedSpotIndex;
          final dotRadius = isSelected ? 5.4 : 4.2;
          return FlDotCirclePainter(
            radius: dotRadius,
            color: _trendBuffBlue,
            strokeColor: isDark ? _trendSlate900 : Colors.white,
            strokeWidth: isSelected ? 2.8 : 2.2,
          );
        },
      ),
      belowBarData: BarAreaData(show: false),
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
        final chartWidth = plotViewportWidth;
        final horizontalDomainPadding = _resolveHorizontalDomainPadding(
          spots.length,
        );
        final chartMinX = -horizontalDomainPadding;
        final chartMaxX = spots.isEmpty
            ? horizontalDomainPadding
            : spots.last.x + horizontalDomainPadding;
        final xAxisLabels = _buildXAxisLabels(
          times: times,
          formatter: xAxisDateFormat,
          visibleDotIndices: visibleDotIndices,
        );

        return ColoredBox(
          color: isDark ? _trendSlate900 : Colors.white,
          child: Column(
            children: [
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: leftAxisWidth,
                      child: Padding(
                        padding: const EdgeInsets.only(
                          top: _trendChartTopPadding,
                        ),
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
                            const SizedBox(
                              height: _trendBottomTitlesReservedHeight,
                            ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: SizedBox(
                        width: chartWidth,
                        child: Padding(
                          padding: const EdgeInsets.only(
                            top: _trendChartTopPadding,
                          ),
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Positioned.fill(
                                bottom: _trendBottomTitlesReservedHeight,
                                child: LineChart(
                                  LineChartData(
                                    minX: chartMinX,
                                    maxX: chartMaxX,
                                    minY: displayMin,
                                    maxY: displayMax,
                                    showingTooltipIndicators:
                                        showingTooltipIndicators,
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
                                      getDrawingHorizontalLine: (value) =>
                                          FlLine(
                                            color: isDark
                                                ? Colors.white.withValues(
                                                    alpha: 0.08,
                                                  )
                                                : _trendBuffGrid,
                                            strokeWidth: 1,
                                          ),
                                    ),
                                    borderData: FlBorderData(
                                      show: true,
                                      border: Border(
                                        left: BorderSide(
                                          color: isDark
                                              ? Colors.white.withValues(
                                                  alpha: 0.14,
                                                )
                                              : _trendBuffAxis,
                                          width: 1,
                                        ),
                                        bottom: BorderSide(
                                          color: isDark
                                              ? Colors.white.withValues(
                                                  alpha: 0.14,
                                                )
                                              : _trendBuffAxis,
                                          width: 1,
                                        ),
                                      ),
                                    ),
                                    titlesData: const FlTitlesData(
                                      topTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: false,
                                        ),
                                      ),
                                      rightTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: false,
                                        ),
                                      ),
                                      leftTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: false,
                                        ),
                                      ),
                                      bottomTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: false,
                                        ),
                                      ),
                                    ),
                                    lineBarsData: [lineBarData],
                                    lineTouchData: LineTouchData(
                                      handleBuiltInTouches: false,
                                      touchSpotThreshold: 22,
                                      touchCallback: _handleChartTap,
                                      touchTooltipData: LineTouchTooltipData(
                                        tooltipRoundedRadius: 2,
                                        tooltipPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 10,
                                            ),
                                        tooltipMargin: 14,
                                        maxContentWidth: 210,
                                        fitInsideHorizontally: true,
                                        fitInsideVertically: true,
                                        tooltipBgColor: isDark
                                            ? _trendSlate900
                                            : _trendBuffTooltip.withValues(
                                                alpha: 0.94,
                                              ),
                                        tooltipBorder: BorderSide(
                                          color: isDark
                                              ? Colors.white.withValues(
                                                  alpha: 0.08,
                                                )
                                              : _trendBuffTooltipBorder,
                                        ),
                                        getTooltipItems: (items) {
                                          return items.map((item) {
                                            final date = DateFormat(
                                              'yyyy-MM-dd',
                                            ).format(times[item.spotIndex]);
                                            return LineTooltipItem(
                                              '',
                                              TextStyle(
                                                color: isDark
                                                    ? Colors.white
                                                    : _trendSlate900,
                                                fontSize: 12,
                                                height: 1.55,
                                              ),
                                              textAlign: TextAlign.left,
                                              children: [
                                                const TextSpan(
                                                  text: '● ',
                                                  style: TextStyle(
                                                    color: _trendBuffBlue,
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                                TextSpan(
                                                  text: _formatConvertedPrice(
                                                    item.y,
                                                    currency,
                                                  ),
                                                  style: TextStyle(
                                                    color: isDark
                                                        ? Colors.white
                                                        : _trendSlate900,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                                TextSpan(
                                                  text: '\n$date',
                                                  style: TextStyle(
                                                    color: subtitleColor,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            );
                                          }).toList();
                                        },
                                      ),
                                      getTouchedSpotIndicator:
                                          (barData, spotIndexes) {
                                            return spotIndexes.map((index) {
                                              return TouchedSpotIndicatorData(
                                                FlLine(
                                                  color: isDark
                                                      ? Colors.white.withValues(
                                                          alpha: 0.18,
                                                        )
                                                      : _trendBuffAxis,
                                                  strokeWidth: 1,
                                                ),
                                                FlDotData(
                                                  show: true,
                                                  getDotPainter:
                                                      (
                                                        spot,
                                                        percent,
                                                        data,
                                                        spotIndex,
                                                      ) {
                                                        return FlDotCirclePainter(
                                                          radius: 5.4,
                                                          color: _trendBuffBlue,
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
                              Positioned(
                                top: 14,
                                right: 14,
                                child: IgnorePointer(
                                  child: Text(
                                    xAxisYearLabel,
                                    maxLines: 1,
                                    style: TextStyle(
                                      color: subtitleColor.withValues(
                                        alpha: 0.72,
                                      ),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                left: 0,
                                right: 0,
                                bottom: 0,
                                height: _trendBottomTitlesReservedHeight,
                                child: _FixedXAxisLabels(
                                  labels: xAxisLabels,
                                  minX: chartMinX,
                                  maxX: chartMaxX,
                                  textStyle: axisLabelStyle,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
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

  String _buildXAxisYearLabel(List<DateTime> times) {
    if (times.isEmpty) {
      return '';
    }

    final firstYear = times.first.year;
    final lastYear = times.last.year;
    if (firstYear == lastYear) {
      return '$firstYear';
    }
    return '$firstYear-$lastYear';
  }

  List<_TrendXAxisLabel> _buildXAxisLabels({
    required List<DateTime> times,
    required DateFormat formatter,
    required Set<int> visibleDotIndices,
  }) {
    if (times.isEmpty || visibleDotIndices.isEmpty) {
      return const <_TrendXAxisLabel>[];
    }

    final labels = <_TrendXAxisLabel>[];
    final seenLabels = <String>{};
    final orderedIndices = visibleDotIndices.toList()..sort();

    for (final index in orderedIndices) {
      if (index < 0 || index >= times.length) {
        continue;
      }
      final label = formatter.format(times[index]);
      if (seenLabels.add(label)) {
        labels.add(_TrendXAxisLabel(index: index, label: label));
      }
    }

    return labels;
  }

  double _resolveHorizontalDomainPadding(int pointCount) {
    if (pointCount <= 1) {
      return _trendMinHorizontalDomainPadding;
    }

    final range = (pointCount - 1).toDouble();
    return math.max(_trendMinHorizontalDomainPadding, range * 0.04);
  }

  Set<int> _buildVisibleDotIndices(List<FlSpot> spots) {
    if (spots.length <= _trendMaxVisibleDotCount) {
      return List<int>.generate(spots.length, (index) => index).toSet();
    }

    final indices = <int>{0, spots.length - 1};
    indices.add(_resolveExtremeSpotIndex(spots, findMax: false));
    indices.add(_resolveExtremeSpotIndex(spots, findMax: true));

    for (
      var slot = 1;
      slot < _trendMaxVisibleDotCount - 1 &&
          indices.length < _trendMaxVisibleDotCount;
      slot += 1
    ) {
      final index = (slot * (spots.length - 1) / (_trendMaxVisibleDotCount - 1))
          .round();
      indices.add(index);
    }

    return indices;
  }

  int _resolveExtremeSpotIndex(List<FlSpot> spots, {required bool findMax}) {
    var result = 0;
    for (var index = 1; index < spots.length; index += 1) {
      final current = spots[index].y;
      final target = spots[result].y;
      if (findMax ? current > target : current < target) {
        result = index;
      }
    }
    return result;
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

    final exponent = math
        .pow(10, (math.log(value) / math.ln10).floor())
        .toDouble();
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

  List<double> _buildYAxisValues({
    required double min,
    required double max,
    required double interval,
  }) {
    if (interval <= 0 || max <= min) {
      return <double>[min, max];
    }

    final values = <double>[];
    for (var value = min; value <= max + interval * 0.5; value += interval) {
      values.add(_normalizeAxisValue(value));
    }
    if (values.isEmpty || (values.last - max).abs() > 1e-6) {
      values.add(_normalizeAxisValue(max));
    }

    return values;
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
    return '${currency.symbol}${amount.toStringAsFixed(digits)}';
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

class _FixedXAxisLabels extends StatelessWidget {
  const _FixedXAxisLabels({
    required this.labels,
    required this.minX,
    required this.maxX,
    required this.textStyle,
  });

  final List<_TrendXAxisLabel> labels;
  final double minX;
  final double maxX;
  final TextStyle textStyle;

  @override
  Widget build(BuildContext context) {
    if (labels.isEmpty || maxX <= minX) {
      return const SizedBox.shrink();
    }

    final textDirection = Directionality.of(context);
    final textScaler = MediaQuery.textScalerOf(context);
    final xRange = maxX - minX;

    return LayoutBuilder(
      builder: (context, constraints) {
        final measuredLabels =
            <({_TrendXAxisLabel label, double left, double width})>[];
        for (final label in labels) {
          final painter = TextPainter(
            text: TextSpan(text: label.label, style: textStyle),
            textDirection: textDirection,
            textScaler: textScaler,
            maxLines: 1,
          )..layout();
          final labelWidth = painter.width + 8;
          final x = ((label.index - minX) / xRange) * constraints.maxWidth;
          final left = (x - labelWidth / 2)
              .clamp(0.0, math.max(0.0, constraints.maxWidth - labelWidth))
              .toDouble();
          measuredLabels.add((label: label, left: left, width: labelWidth));
        }

        final positionedLabels = _positionXAxisLabels(measuredLabels);
        return Stack(
          clipBehavior: Clip.none,
          children: positionedLabels.map((item) {
            return Positioned(
              left: item.left,
              top: item.top,
              width: item.width,
              child: Text(
                item.label.label,
                maxLines: 1,
                overflow: TextOverflow.visible,
                textAlign: TextAlign.center,
                style: textStyle,
              ),
            );
          }).toList(),
        );
      },
    );
  }

  List<({_TrendXAxisLabel label, double left, double width, double top})>
  _positionXAxisLabels(
    List<({_TrendXAxisLabel label, double left, double width})> labels,
  ) {
    const minGap = 4.0;
    const rowTops = <double>[5, 18];
    final rowRightEdges = <double>[-double.maxFinite, -double.maxFinite];
    final positioned =
        <({_TrendXAxisLabel label, double left, double width, double top})>[];

    for (final item in labels) {
      final left = item.left;
      final row = left >= rowRightEdges[0] + minGap
          ? 0
          : left >= rowRightEdges[1] + minGap
          ? 1
          : rowRightEdges[0] <= rowRightEdges[1]
          ? 0
          : 1;
      rowRightEdges[row] = left + item.width;
      positioned.add((
        label: item.label,
        left: item.left,
        width: item.width,
        top: rowTops[row],
      ));
    }

    return positioned..sort((a, b) => a.label.index.compareTo(b.label.index));
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
