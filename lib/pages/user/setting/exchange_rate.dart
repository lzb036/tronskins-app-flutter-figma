import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tronskins_app/common/hooks/currency/CurrencyController.dart';
import 'package:tronskins_app/common/widgets/settings_style_app_bar.dart';

class ExchangeRatePage extends StatefulWidget {
  const ExchangeRatePage({super.key});

  @override
  State<ExchangeRatePage> createState() => _ExchangeRatePageState();
}

class _ExchangeRatePageState extends State<ExchangeRatePage> {
  static const _pageBackground = Color(0xFFF8F8FC);
  static const _brandColor = Color(0xFF00288E);
  static const _mutedColor = Color(0x99444653);
  static const _sectionColor = Color(0x99444653);

  static const _currencyNames = <String, String>{
    'USD': 'United States Dollar',
    'CNY': 'Chinese Yuan',
    'EUR': 'Euro',
    'GBP': 'British Pound',
    'JPY': 'Japanese Yen',
    'KRW': 'South Korean Won',
    'RUB': 'Russian Ruble',
    'VND': 'Vietnamese Dong',
    'INR': 'Indian Rupee',
    'IDR': 'Indonesian Rupiah',
    'THB': 'Thai Baht',
    'PHP': 'Philippine Peso',
    'BRL': 'Brazilian Real',
    'TRY': 'Turkish Lira',
    'AUD': 'Australian Dollar',
    'CAD': 'Canadian Dollar',
  };

  bool _refreshing = false;
  DateTime? _lastUpdatedAt;

  CurrencyController get _ctrl => Get.find<CurrencyController>();

  @override
  void initState() {
    super.initState();
    if (_ctrl.isLoaded) {
      _lastUpdatedAt = DateTime.now();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshRates(showBlockingLoader: !_ctrl.isLoaded);
    });
  }

  Future<void> _refreshRates({bool showBlockingLoader = false}) async {
    if (_refreshing) {
      return;
    }
    if (showBlockingLoader && mounted) {
      setState(() {
        _refreshing = true;
      });
    } else {
      _refreshing = true;
    }

    try {
      await _ctrl.fetchRealRates(force: true);
      _lastUpdatedAt = DateTime.now();
    } finally {
      if (mounted) {
        setState(() {
          _refreshing = false;
        });
      } else {
        _refreshing = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageBackground,
      body: Stack(
        children: [
          Obx(() {
            if (!_ctrl.isLoaded && _refreshing && _lastUpdatedAt == null) {
              return const Center(child: CircularProgressIndicator());
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 96, 16, 40),
              children: [
                Align(
                  alignment: Alignment.center,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 768),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'SUPPORTED CURRENCIES',
                          style: TextStyle(
                            color: _sectionColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.2,
                            height: 18 / 12,
                          ),
                        ),
                        const SizedBox(height: 18),
                        for (var i = 0; i < _ctrl.allRates.length; i++) ...[
                          _buildRateCard(_ctrl.allRates[i]),
                          if (i != _ctrl.allRates.length - 1)
                            const SizedBox(height: 12),
                        ],
                        const SizedBox(height: 24),
                        _buildFooter(),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }),
          const _ExchangeRateTopBar(),
        ],
      ),
    );
  }

  Widget _buildRateCard(Map<String, dynamic> item) {
    final code = item['code'] as String;
    final symbol = item['symbol'] as String? ?? '';
    final rate = (item['rate'] as num?)?.toDouble() ?? 1.0;
    final isCurrent = item['isCurrent'] == true;
    final title = _currencyNames[code] ?? code;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.zero,
        onTap: () => _ctrl.setCurrency(code),
        child: Container(
          constraints: const BoxConstraints(minHeight: 72),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.zero,
            border: Border.all(
              color: isCurrent
                  ? const Color.fromRGBO(0, 40, 142, 0.08)
                  : Colors.transparent,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color.fromRGBO(0, 0, 0, 0.05),
                blurRadius: 2,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            children: [
              SizedBox(
                width: 44,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      symbol,
                      style: TextStyle(
                        color: isCurrent
                            ? _brandColor
                            : const Color(0xFF191C1E),
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        height: 32 / 24,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      code,
                      style: const TextStyle(
                        color: Color.fromRGBO(68, 70, 83, 0.5),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        height: 15 / 10,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _singleLineFittedText(
                      title,
                      height: 24,
                      style: const TextStyle(
                        color: Color(0xFF191C1E),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        height: 24 / 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    _singleLineFittedText(
                      isCurrent
                          ? (code == 'USD'
                                ? 'Default Currency'
                                : 'Selected Currency')
                          : _usdPreview(code, rate),
                      height: 21,
                      style: const TextStyle(
                        color: _mutedColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        height: 21 / 14,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              if (isCurrent)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDFA),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Selected',
                        style: TextStyle(
                          color: Color(0xFF0F766E),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          height: 18 / 12,
                        ),
                      ),
                      SizedBox(width: 6),
                      Icon(
                        Icons.check_circle_rounded,
                        color: Color(0xFF14B8A6),
                        size: 16,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.info_outline_rounded,
              size: 14,
              color: Color.fromRGBO(68, 70, 83, 0.5),
            ),
            SizedBox(width: 8),
            Flexible(
              child: Text(
                'Rates are updated hourly for reference only',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color.fromRGBO(68, 70, 83, 0.5),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  height: 18 / 12,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Last updated: ${_formatTimestamp(_lastUpdatedAt)}',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color.fromRGBO(68, 70, 83, 0.4),
            fontSize: 10,
            fontWeight: FontWeight.w400,
            letterSpacing: 0.5,
            height: 15 / 10,
          ),
        ),
      ],
    );
  }

  String _usdPreview(String code, double rate) {
    final fractionDigits = const {'JPY', 'KRW', 'VND', 'IDR'}.contains(code)
        ? 0
        : 2;
    final displayRate = rate > 0
        ? rate.toStringAsFixed(fractionDigits)
        : 0.toStringAsFixed(fractionDigits);
    return '1 USD ≈ $displayRate $code';
  }

  Widget _singleLineFittedText(
    String text, {
    required double height,
    required TextStyle style,
  }) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: Align(
        alignment: Alignment.centerLeft,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(text, maxLines: 1, softWrap: false, style: style),
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime? timestamp) {
    if (timestamp == null) {
      return '--';
    }
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    return '${timestamp.year}-${twoDigits(timestamp.month)}-${twoDigits(timestamp.day)} ${twoDigits(timestamp.hour)}:${twoDigits(timestamp.minute)}';
  }
}

class _ExchangeRateTopBar extends StatelessWidget {
  const _ExchangeRateTopBar();

  @override
  Widget build(BuildContext context) {
    return SettingsStyleTopNavigation(
      title: 'app.user.setting.exchange_rate'.tr,
    );
  }
}
