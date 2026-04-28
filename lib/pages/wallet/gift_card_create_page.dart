import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tronskins_app/common/utils/app_snackbar.dart';
import 'package:tronskins_app/controllers/wallet/gift_card_controller.dart';
import 'package:tronskins_app/routes/app_routes.dart';

class GiftCardCreatePage extends StatefulWidget {
  const GiftCardCreatePage({super.key});

  @override
  State<GiftCardCreatePage> createState() => _GiftCardCreatePageState();
}

class _GiftCardCreatePageState extends State<GiftCardCreatePage> {
  static const Color _pageBackground = Color(0xFFF8FAFC);
  static const Color _surfaceContainer = Color(0xFFECEEF0);
  static const Color _surfaceLowest = Colors.white;
  static const Color _brandBlue = Color(0xFF00288E);
  static const Color _primaryBlue = Color(0xFF1E40AF);
  static const Color _secondaryBlue = Color(0xFF3B82F6);
  static const Color _titleColor = Color(0xFF191C1E);
  static const Color _bodyColor = Color(0xFF444653);
  static const Color _mutedColor = Color(0xFF757684);

  static const List<double> _amounts = [
    0.1,
    0.2,
    0.5,
    1,
    2,
    5,
    10,
    20,
    50,
    100,
    200,
    500,
    1000,
    2000,
    5000,
    10000,
  ];

  final GiftCardController controller = Get.isRegistered<GiftCardController>()
      ? Get.find<GiftCardController>()
      : Get.put(GiftCardController());

  double _selectedAmount = 10;
  int _quantity = 1;

  double get _total => _selectedAmount * _quantity;

  void _decreaseQuantity() {
    if (_quantity <= 1) {
      return;
    }
    setState(() => _quantity -= 1);
  }

  void _increaseQuantity() {
    setState(() => _quantity += 1);
  }

  void _submit() {
    controller.createCards(amount: _selectedAmount, quantity: _quantity);
    AppSnackbar.success('Gift card generated');
    if (Navigator.of(context).canPop()) {
      Get.back();
    } else {
      Get.offNamed(Routers.WALLET_GIFT_CARD);
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top + 96;
    final bottomPadding = MediaQuery.of(context).padding.bottom + 128;

    return Scaffold(
      backgroundColor: _pageBackground,
      body: Stack(
        children: [
          ListView(
            physics: const ClampingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(24, topPadding, 24, bottomPadding),
            children: [
              Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 672),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _GiftCardHero(),
                      const SizedBox(height: 40),
                      _AmountSelector(
                        amounts: _amounts,
                        selectedAmount: _selectedAmount,
                        onChanged: (value) {
                          setState(() => _selectedAmount = value);
                        },
                      ),
                      const SizedBox(height: 24),
                      _QuantitySelector(
                        quantity: _quantity,
                        onDecrease: _decreaseQuantity,
                        onIncrease: _increaseQuantity,
                      ),
                      const SizedBox(height: 30),
                      _OrderSummary(
                        selectedAmount: _selectedAmount,
                        quantity: _quantity,
                        total: _total,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const _CreateGiftCardTopBar(),
          _CreateGiftCardActionBar(quantity: _quantity, onSubmit: _submit),
        ],
      ),
    );
  }

  static String amountLabel(double value) {
    if (value == value.roundToDouble()) {
      return '\$${value.toInt()}';
    }
    return '\$${value.toStringAsFixed(1)}';
  }

  static String money(double value) => '\$${value.toStringAsFixed(2)}';
}

class _CreateGiftCardTopBar extends StatelessWidget {
  const _CreateGiftCardTopBar();

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            color: _GiftCardCreatePageState._pageBackground.withValues(
              alpha: 0.72,
            ),
            padding: EdgeInsets.only(top: topInset),
            child: SizedBox(
              height: 64,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Material(
                      color: Colors.transparent,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => Navigator.of(context).maybePop(),
                        child: const SizedBox(
                          width: 40,
                          height: 40,
                          child: Icon(
                            Icons.arrow_back,
                            size: 20,
                            color: Color(0xFF1E3A8A),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Text(
                        'Create Gift Card',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Color(0xFF1E3A8A),
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          height: 28 / 18,
                        ),
                      ),
                    ),
                    const Text(
                      'GC',
                      style: TextStyle(
                        color: Color(0xFF1E3A8A),
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        height: 28 / 20,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GiftCardHero extends StatelessWidget {
  const _GiftCardHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 256,
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: _GiftCardCreatePageState._surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(15, 23, 42, 0.05),
            blurRadius: 20,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            top: 24,
            bottom: 6,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF68D6D3),
                    Color(0xFF123B72),
                    Color(0xFF9AA7CE),
                  ],
                  stops: [0, 0.52, 1],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1E3A8A).withValues(alpha: 0.18),
                    blurRadius: 32,
                    offset: const Offset(0, 18),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 18,
            right: 18,
            top: 72,
            child: Text(
              'GIFT VALUED',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.68),
                fontSize: 15,
                fontWeight: FontWeight.w800,
                letterSpacing: 2.6,
              ),
            ),
          ),
          const Positioned(
            left: 18,
            bottom: 42,
            child: Text(
              'PREMIUM EDITION',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w500,
                height: 16 / 10,
                letterSpacing: 1.2,
              ),
            ),
          ),
          const Positioned(
            left: 18,
            right: 18,
            bottom: 18,
            child: Text(
              "The Curator's Card",
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.w900,
                height: 30 / 30,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AmountSelector extends StatelessWidget {
  const _AmountSelector({
    required this.amounts,
    required this.selectedAmount,
    required this.onChanged,
  });

  final List<double> amounts;
  final double selectedAmount;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Text(
                'Select Amount',
                style: TextStyle(
                  color: _GiftCardCreatePageState._titleColor,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  height: 28 / 20,
                ),
              ),
            ),
            Text(
              'VALUES IN USD',
              style: TextStyle(
                color: _GiftCardCreatePageState._mutedColor,
                fontSize: 10,
                fontWeight: FontWeight.w500,
                height: 15 / 10,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        GridView.builder(
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemCount: amounts.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            mainAxisExtent: 56,
          ),
          itemBuilder: (context, index) {
            final amount = amounts[index];
            return _AmountButton(
              label: _GiftCardCreatePageState.amountLabel(amount),
              selected: amount == selectedAmount,
              onTap: () => onChanged(amount),
            );
          },
        ),
      ],
    );
  }
}

class _AmountButton extends StatelessWidget {
  const _AmountButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _GiftCardCreatePageState._surfaceLowest,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              width: 2,
              color: selected
                  ? _GiftCardCreatePageState._brandBlue.withValues(alpha: 0.4)
                  : Colors.transparent,
            ),
            boxShadow: selected
                ? const [
                    BoxShadow(
                      color: Color.fromRGBO(0, 40, 142, 0.05),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ]
                : const [
                    BoxShadow(
                      color: Color.fromRGBO(15, 23, 42, 0.02),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: TextStyle(
                color: selected
                    ? _GiftCardCreatePageState._brandBlue
                    : _GiftCardCreatePageState._titleColor,
                fontSize: 14,
                fontWeight: FontWeight.w900,
                height: 20 / 14,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _QuantitySelector extends StatelessWidget {
  const _QuantitySelector({
    required this.quantity,
    required this.onDecrease,
    required this.onIncrease,
  });

  final int quantity;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _GiftCardCreatePageState._surfaceContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Quantity',
                  style: TextStyle(
                    color: _GiftCardCreatePageState._titleColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    height: 28 / 18,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Number of cards\nto issue',
                  style: TextStyle(
                    color: _GiftCardCreatePageState._bodyColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    height: 20 / 14,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _GiftCardCreatePageState._surfaceLowest,
              borderRadius: BorderRadius.circular(8),
              boxShadow: const [
                BoxShadow(
                  color: Color.fromRGBO(15, 23, 42, 0.05),
                  blurRadius: 10,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _QuantityButton(
                  icon: Icons.remove_rounded,
                  onTap: onDecrease,
                  enabled: quantity > 1,
                ),
                SizedBox(
                  width: 56,
                  child: Text(
                    '$quantity',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: _GiftCardCreatePageState._titleColor,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      height: 32 / 24,
                    ),
                  ),
                ),
                _QuantityButton(icon: Icons.add_rounded, onTap: onIncrease),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuantityButton extends StatelessWidget {
  const _QuantityButton({
    required this.icon,
    required this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(4),
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: enabled ? onTap : null,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(
            icon,
            size: 20,
            color: enabled
                ? _GiftCardCreatePageState._brandBlue
                : const Color(0xFFCBD5E1),
          ),
        ),
      ),
    );
  }
}

class _OrderSummary extends StatelessWidget {
  const _OrderSummary({
    required this.selectedAmount,
    required this.quantity,
    required this.total,
  });

  final double selectedAmount;
  final int quantity;
  final double total;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(32, 80, 32, 32),
      decoration: BoxDecoration(
        color: _GiftCardCreatePageState._surfaceLowest,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(15, 23, 42, 0.03),
            blurRadius: 40,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -4,
            top: -56,
            child: Icon(
              Icons.receipt_long_rounded,
              size: 72,
              color: const Color(0xFFECEEF0).withValues(alpha: 0.8),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'ORDER SUMMARY',
                style: TextStyle(
                  color: _GiftCardCreatePageState._mutedColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  height: 20 / 14,
                  letterSpacing: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              _SummaryRow(
                label: 'Selected Amount',
                value: _GiftCardCreatePageState.money(selectedAmount),
              ),
              const SizedBox(height: 16),
              _SummaryRow(label: 'Quantity', value: '$quantity'),
              const SizedBox(height: 16),
              _SummaryRow(
                label: 'Service Fee',
                value: _GiftCardCreatePageState.money(0),
                valueColor: _GiftCardCreatePageState._brandBlue,
              ),
              const SizedBox(height: 17),
              Container(height: 1, color: const Color(0xFFECEEF0)),
              const SizedBox(height: 17),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Expanded(
                    child: Text(
                      'Total',
                      style: TextStyle(
                        color: _GiftCardCreatePageState._titleColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        height: 24 / 16,
                      ),
                    ),
                  ),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        _GiftCardCreatePageState.money(total),
                        style: const TextStyle(
                          color: _GiftCardCreatePageState._brandBlue,
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                          height: 40 / 36,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.valueColor = _GiftCardCreatePageState._titleColor,
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: _GiftCardCreatePageState._bodyColor,
              fontSize: 16,
              fontWeight: FontWeight.w400,
              height: 24 / 16,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: 16,
            fontWeight: FontWeight.w500,
            height: 24 / 16,
          ),
        ),
      ],
    );
  }
}

class _CreateGiftCardActionBar extends StatelessWidget {
  const _CreateGiftCardActionBar({
    required this.quantity,
    required this.onSubmit,
  });

  final int quantity;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            color: Colors.white.withValues(alpha: 0.8),
            padding: EdgeInsets.fromLTRB(24, 16, 24, bottomInset + 16),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: onSubmit,
                child: Ink(
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    gradient: const LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        _GiftCardCreatePageState._primaryBlue,
                        _GiftCardCreatePageState._secondaryBlue,
                      ],
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color.fromRGBO(15, 23, 42, 0.12),
                        blurRadius: 18,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.auto_awesome_rounded,
                        size: 22,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'GENERATE $quantity GIFT CARD'
                        '${quantity > 1 ? 'S' : ''}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          height: 20 / 14,
                          letterSpacing: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
