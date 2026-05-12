import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tronskins_app/common/hooks/currency/CurrencyController.dart';
import 'package:tronskins_app/components/filter/filter_price_support.dart';

class _FakeCurrencyController extends CurrencyController {
  _FakeCurrencyController({
    required this.fakeCode,
    required this.fakeSymbol,
    required this.fakeRate,
  });

  final String fakeCode;
  final String fakeSymbol;
  final double fakeRate;

  @override
  String get code => fakeCode;

  @override
  String get symbol => fakeSymbol;

  @override
  double get currentRate => fakeRate;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        pathProviderChannel,
        (call) async => Directory.systemTemp.path,
      );

  test('formats USD as selected currency editable text', () {
    final currency = _FakeCurrencyController(
      fakeCode: 'CNY',
      fakeSymbol: 'CNY',
      fakeRate: 7.18,
    );

    expect(FilterPriceSupport.formatEditableNumber(currency, 0.03), '0.22');
  });

  test('parses selected currency input back to rounded USD', () {
    final currency = _FakeCurrencyController(
      fakeCode: 'CNY',
      fakeSymbol: 'CNY',
      fakeRate: 7.18,
    );

    expect(FilterPriceSupport.displayToRoundedUsd(currency, 'CNY0.22'), 0.03);
  });

  test('keeps no-decimal currencies integer formatted', () {
    final currency = _FakeCurrencyController(
      fakeCode: 'JPY',
      fakeSymbol: 'JPY',
      fakeRate: 149,
    );

    expect(FilterPriceSupport.formatEditableNumber(currency, 0.02), '3');
  });
}
