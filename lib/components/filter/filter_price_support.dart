import 'package:tronskins_app/common/hooks/currency/CurrencyController.dart';

class FilterPriceSupport {
  static const List<double> usdPresetBreakpoints = <double>[0, 100, 500, 1000];

  static const Set<String> _noDecimalCurrencies = <String>{
    'JPY',
    'KRW',
    'VND',
    'IDR',
  };

  static bool usesNoDecimals(CurrencyController currency) {
    return _noDecimalCurrencies.contains(currency.code);
  }

  static double usdToDisplay(CurrencyController currency, double usdValue) {
    return usdValue * currency.currentRate;
  }

  static double displayToUsd(CurrencyController currency, String rawValue) {
    final normalized = rawValue
        .trim()
        .replaceAll(currency.symbol, '')
        .replaceAll(',', '')
        .replaceAll(' ', '');
    if (normalized.isEmpty) {
      return 0;
    }
    final parsed = double.tryParse(normalized);
    if (parsed == null) {
      return 0;
    }
    final rate = currency.currentRate <= 0 ? 1.0 : currency.currentRate;
    return parsed / rate;
  }

  static String formatEditableNumber(
    CurrencyController currency,
    double usdValue,
  ) {
    final displayValue = usdToDisplay(currency, usdValue);
    return _formatPreciseNumber(
      displayValue,
      keepIntegersOnly: usesNoDecimals(currency),
    );
  }

  static String formatAmount(
    CurrencyController currency,
    double usdValue, {
    bool compact = false,
  }) {
    final number = compact
        ? _formatCompactNumber(
            usdToDisplay(currency, usdValue),
            keepIntegersOnly: usesNoDecimals(currency),
          )
        : formatEditableNumber(currency, usdValue);
    return '${currency.symbol}$number';
  }

  static String formatPresetLabel(
    CurrencyController currency, {
    required double minUsd,
    double? maxUsd,
  }) {
    final minLabel = _formatCompactNumber(
      usdToDisplay(currency, minUsd),
      keepIntegersOnly: usesNoDecimals(currency),
    );
    if (maxUsd == null) {
      return '${currency.symbol}$minLabel+';
    }
    final maxLabel = _formatCompactNumber(
      usdToDisplay(currency, maxUsd),
      keepIntegersOnly: usesNoDecimals(currency),
    );
    return '${currency.symbol}$minLabel-$maxLabel';
  }

  static String _formatPreciseNumber(
    double value, {
    required bool keepIntegersOnly,
  }) {
    if (keepIntegersOnly) {
      return value.round().toString();
    }
    final fixed = value.toStringAsFixed(2);
    return _trimTrailingZeros(fixed);
  }

  static String _formatCompactNumber(
    double value, {
    required bool keepIntegersOnly,
  }) {
    final absValue = value.abs();
    if (absValue >= 1000000000) {
      return '${_compactUnitValue(absValue / 1000000000)}B';
    }
    if (absValue >= 1000000) {
      return '${_compactUnitValue(absValue / 1000000)}M';
    }
    if (absValue >= 1000) {
      return '${_compactUnitValue(absValue / 1000)}K';
    }
    return _formatPreciseNumber(
      value,
      keepIntegersOnly: keepIntegersOnly || absValue >= 100,
    );
  }

  static String _compactUnitValue(double value) {
    final fixed = value >= 10
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(1);
    return _trimTrailingZeros(fixed);
  }

  static String _trimTrailingZeros(String value) {
    if (!value.contains('.')) {
      return value;
    }
    return value.replaceFirst(RegExp(r'\.?0+$'), '');
  }
}
