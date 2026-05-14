import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tronskins_app/api/model/wallet/wallet_models.dart';
import 'package:tronskins_app/common/hooks/currency/CurrencyController.dart';
import 'package:tronskins_app/common/theme/settings_top_bar_style.dart';
import 'package:tronskins_app/common/utils/app_snackbar.dart';
import 'package:tronskins_app/common/widgets/figma_confirmation_dialog.dart';
import 'package:tronskins_app/controllers/wallet/gift_card_controller.dart';
import 'package:tronskins_app/routes/app_routes.dart';

class GiftCardCreatePage extends StatefulWidget {
  const GiftCardCreatePage({super.key});

  @override
  State<GiftCardCreatePage> createState() => _GiftCardCreatePageState();
}

class _GiftCardCreatePageState extends State<GiftCardCreatePage> {
  static const Color _pageBackground = Color(0xFFF8FAFC);
  static const Color _surfaceContainer = Color(0xFFF1F5F9);
  static const Color _surfaceLowest = Colors.white;
  static const Color _brandBlue = Color(0xFF00288E);
  static const Color _primaryBlue = Color(0xFF1E40AF);
  static const Color _secondaryBlue = Color(0xFF3B82F6);
  static const Color _titleColor = Color(0xFF0F172A);
  static const Color _bodyColor = Color(0xFF444653);
  static const Color _mutedColor = Color(0xFF94A3B8);
  static const int _maxQuantity = 10;

  final GiftCardController controller = Get.isRegistered<GiftCardController>()
      ? Get.find<GiftCardController>()
      : Get.put(GiftCardController());

  WalletGiftCardAmountOption? _selectedAmount;
  int _quantity = 1;
  bool _isSubmittingFromConfirmDialog = false;

  @override
  void initState() {
    super.initState();
    _loadAmountOptions();
  }

  Future<void> _loadAmountOptions() async {
    try {
      await controller.loadAmountOptions();
    } catch (_) {
      if (mounted) {
        AppSnackbar.error('app.user.gift_card.load_amount_failed'.tr);
      }
    }
  }

  WalletGiftCardAmountOption? _currentAmount(
    List<WalletGiftCardAmountOption> options,
  ) {
    final selected = _selectedAmount;
    if (selected != null) {
      for (final option in options) {
        if (option.id == selected.id &&
            option.submitValue == selected.submitValue) {
          return option;
        }
      }
      return selected;
    }
    if (options.isEmpty) {
      return null;
    }
    return options.first;
  }

  void _decreaseQuantity() {
    if (_quantity <= 1) {
      return;
    }
    setState(() => _quantity -= 1);
  }

  void _increaseQuantity() {
    if (_quantity >= _maxQuantity) {
      return;
    }
    setState(() => _quantity += 1);
  }

  Future<void> _submit(List<WalletGiftCardAmountOption> options) async {
    final amount = _currentAmount(options);
    if (amount == null) {
      AppSnackbar.error('app.user.gift_card.select_amount_required'.tr);
      return;
    }

    await showFigmaModal<void>(
      context: context,
      barrierDismissible: false,
      child: FigmaAsyncConfirmationDialog(
        title: 'app.user.gift_card.create_title'.tr,
        primaryLabel: 'app.common.confirm'.tr,
        secondaryLabel: 'app.common.cancel'.tr,
        icon: Icons.card_giftcard_rounded,
        iconColor: _brandBlue,
        iconBackgroundColor: const Color.fromRGBO(0, 40, 142, 0.10),
        accentColor: _brandBlue,
        content: _GenerateGiftCardConfirmContent(
          amount: amount,
          quantity: _quantity,
        ),
        onSecondary: () => popModalRoute(context),
        onConfirm: (dialogContext) => _generateConfirmed(
          amount: amount,
          quantity: _quantity,
          dialogContext: dialogContext,
        ),
      ),
    );
  }

  Future<void> _generateConfirmed({
    required WalletGiftCardAmountOption amount,
    required int quantity,
    required BuildContext dialogContext,
  }) async {
    if (mounted) {
      setState(() => _isSubmittingFromConfirmDialog = true);
    }
    try {
      final success = await controller.generateCard(
        amount: amount,
        quantity: quantity,
      );
      if (!mounted) {
        return;
      }
      if (success) {
        if (dialogContext.mounted) {
          popModalRoute(dialogContext);
        }
        AppSnackbar.success('app.user.gift_card.generate_success'.tr);
        if (Navigator.of(context).canPop()) {
          Get.back(result: true);
        } else {
          Get.offNamed(Routers.WALLET_GIFT_CARD);
        }
      } else {
        AppSnackbar.error('app.user.gift_card.generate_failed'.tr);
      }
    } catch (_) {
      if (mounted) {
        AppSnackbar.error('app.user.gift_card.generate_failed'.tr);
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmittingFromConfirmDialog = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top + 96;
    final bottomPadding = MediaQuery.of(context).padding.bottom + 112;

    return Obx(() {
      final options = controller.amountOptions.toList(growable: false);
      final currentAmount = _currentAmount(options);
      final isLoadingOptions = controller.isLoadingAmountOptions.value;
      final isGenerating = controller.isGenerating.value;
      final isActionBarGenerating =
          isGenerating && !_isSubmittingFromConfirmDialog;
      final submitEnabled =
          !isLoadingOptions && !isActionBarGenerating && currentAmount != null;

      return Scaffold(
        backgroundColor: _pageBackground,
        body: Stack(
          children: [
            ListView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: ClampingScrollPhysics(),
              ),
              padding: EdgeInsets.fromLTRB(24, topPadding, 24, bottomPadding),
              children: [
                Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 672),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _GiftCardHero(amount: currentAmount),
                        const SizedBox(height: 36),
                        _AmountSelector(
                          options: options,
                          selectedAmount: currentAmount,
                          isLoading: isLoadingOptions,
                          onChanged: (value) {
                            setState(() => _selectedAmount = value);
                          },
                          onRetry: () => _loadAmountOptions(),
                        ),
                        const SizedBox(height: 24),
                        _QuantitySelector(
                          quantity: _quantity,
                          maxQuantity: _maxQuantity,
                          onDecrease: _decreaseQuantity,
                          onIncrease: _increaseQuantity,
                        ),
                        const SizedBox(height: 30),
                        _OrderSummary(
                          selectedAmount: currentAmount,
                          quantity: _quantity,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const _CreateGiftCardTopBar(),
            _CreateGiftCardActionBar(
              quantity: _quantity,
              enabled: submitEnabled,
              isLoading: isActionBarGenerating,
              onSubmit: () => _submit(options),
            ),
          ],
        ),
      );
    });
  }

  static String formatMoney(double value) {
    final currency = Get.find<CurrencyController>();
    return currency.formatUsd(value).replaceFirst('\$ ', r'$');
  }
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
              alpha: 0.78,
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
                            color: settingsTopBarBrandColor,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'app.user.gift_card.create_title'.tr,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: settingsTopBarTitleTextStyle,
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
  const _GiftCardHero({required this.amount});

  final WalletGiftCardAmountOption? amount;

  @override
  Widget build(BuildContext context) {
    final amountLabel = amount == null
        ? '--'
        : _GiftCardCreatePageState.formatMoney(amount!.amount);

    return Container(
      height: 244,
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: _GiftCardCreatePageState._surfaceContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            top: 18,
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
            top: 64,
            child: Text(
              'app.user.gift_card.hero_label'.tr.toUpperCase(),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.68),
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 2.4,
              ),
            ),
          ),
          Positioned(
            left: 18,
            right: 18,
            top: 94,
            child: Text(
              amountLabel,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 42,
                fontWeight: FontWeight.w900,
                height: 1,
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
    required this.options,
    required this.selectedAmount,
    required this.isLoading,
    required this.onChanged,
    required this.onRetry,
  });

  final List<WalletGiftCardAmountOption> options;
  final WalletGiftCardAmountOption? selectedAmount;
  final bool isLoading;
  final ValueChanged<WalletGiftCardAmountOption> onChanged;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Text(
                'app.user.gift_card.select_amount'.tr,
                style: const TextStyle(
                  color: _GiftCardCreatePageState._titleColor,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  height: 28 / 20,
                ),
              ),
            ),
            Text(
              'app.user.gift_card.values_in_usd'.tr.toUpperCase(),
              style: const TextStyle(
                color: _GiftCardCreatePageState._mutedColor,
                fontSize: 10,
                fontWeight: FontWeight.w500,
                height: 15 / 10,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        if (isLoading && options.isEmpty)
          const _AmountSkeletonGrid()
        else if (options.isEmpty)
          _AmountEmptyState(onRetry: onRetry)
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth < 360 ? 3 : 4;
              return GridView.builder(
                padding: EdgeInsets.zero,
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                itemCount: options.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  mainAxisExtent: 56,
                ),
                itemBuilder: (context, index) {
                  final option = options[index];
                  return _AmountButton(
                    label: option.displayLabel,
                    selected: _isSameAmount(option, selectedAmount),
                    onTap: () => onChanged(option),
                  );
                },
              );
            },
          ),
      ],
    );
  }

  bool _isSameAmount(
    WalletGiftCardAmountOption option,
    WalletGiftCardAmountOption? selected,
  ) {
    if (selected == null) {
      return false;
    }
    return option.id == selected.id &&
        option.submitValue == selected.submitValue;
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
                  ? _GiftCardCreatePageState._brandBlue.withValues(alpha: 0.42)
                  : Colors.transparent,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color.fromRGBO(15, 23, 42, 0.03),
                blurRadius: 12,
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

class _AmountEmptyState extends StatelessWidget {
  const _AmountEmptyState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      decoration: BoxDecoration(
        color: _GiftCardCreatePageState._surfaceContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.card_giftcard_rounded,
            color: _GiftCardCreatePageState._mutedColor,
            size: 30,
          ),
          const SizedBox(height: 10),
          Text(
            'app.user.gift_card.amount_empty'.tr,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _GiftCardCreatePageState._bodyColor,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              height: 18 / 13,
            ),
          ),
          const SizedBox(height: 14),
          TextButton(onPressed: onRetry, child: Text('app.common.retry'.tr)),
        ],
      ),
    );
  }
}

class _AmountSkeletonGrid extends StatelessWidget {
  const _AmountSkeletonGrid();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth < 360 ? 3 : 4;
        return GridView.builder(
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemCount: crossAxisCount * 2,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            mainAxisExtent: 56,
          ),
          itemBuilder: (context, index) {
            return Container(
              decoration: BoxDecoration(
                color: _GiftCardCreatePageState._surfaceLowest,
                borderRadius: BorderRadius.circular(8),
              ),
            );
          },
        );
      },
    );
  }
}

class _QuantitySelector extends StatelessWidget {
  const _QuantitySelector({
    required this.quantity,
    required this.maxQuantity,
    required this.onDecrease,
    required this.onIncrease,
  });

  final int quantity;
  final int maxQuantity;
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'app.user.gift_card.quantity'.tr,
                  style: const TextStyle(
                    color: _GiftCardCreatePageState._titleColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    height: 28 / 18,
                  ),
                ),
                const SizedBox(height: 2),
                SizedBox(
                  width: double.infinity,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'app.user.gift_card.quantity_hint'.trArgs([
                        '$maxQuantity',
                      ]),
                      maxLines: 1,
                      softWrap: false,
                      style: const TextStyle(
                        color: _GiftCardCreatePageState._bodyColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        height: 20 / 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
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
                  width: 36,
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
                _QuantityButton(
                  icon: Icons.add_rounded,
                  onTap: onIncrease,
                  enabled: quantity < maxQuantity,
                ),
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
          width: 34,
          height: 36,
          child: Icon(
            icon,
            size: 19,
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
  const _OrderSummary({required this.selectedAmount, required this.quantity});

  final WalletGiftCardAmountOption? selectedAmount;
  final int quantity;

  @override
  Widget build(BuildContext context) {
    final amountValue = selectedAmount?.amount ?? 0;
    final total = amountValue * quantity;

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
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'app.user.gift_card.order_summary'.tr.toUpperCase(),
                style: const TextStyle(
                  color: _GiftCardCreatePageState._mutedColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  height: 20 / 14,
                  letterSpacing: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              _SummaryRow(
                label: 'app.user.gift_card.selected_amount'.tr,
                value: _GiftCardCreatePageState.formatMoney(amountValue),
              ),
              const SizedBox(height: 16),
              _SummaryRow(
                label: 'app.user.gift_card.quantity'.tr,
                value: '$quantity',
              ),
              const SizedBox(height: 16),
              _SummaryRow(
                label: 'app.user.gift_card.service_fee'.tr,
                value: _GiftCardCreatePageState.formatMoney(0),
                valueColor: _GiftCardCreatePageState._brandBlue,
              ),
              const SizedBox(height: 17),
              Container(height: 1, color: const Color(0xFFECEEF0)),
              const SizedBox(height: 17),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Text(
                      'app.user.gift_card.total'.tr,
                      style: const TextStyle(
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
                        _GiftCardCreatePageState.formatMoney(total),
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

class _GenerateGiftCardConfirmContent extends StatelessWidget {
  const _GenerateGiftCardConfirmContent({
    required this.amount,
    required this.quantity,
  });

  final WalletGiftCardAmountOption amount;
  final int quantity;

  @override
  Widget build(BuildContext context) {
    final amountValue = amount.amount;
    final total = amountValue * quantity;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _GiftCardCreatePageState._surfaceContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ConfirmSummaryRow(
            label: 'app.user.gift_card.selected_amount'.tr,
            value: _GiftCardCreatePageState.formatMoney(amountValue),
          ),
          const SizedBox(height: 10),
          _ConfirmSummaryRow(
            label: 'app.user.gift_card.quantity'.tr,
            value: '$quantity',
          ),
          const SizedBox(height: 10),
          Container(height: 1, color: const Color(0xFFE2E8F0)),
          const SizedBox(height: 10),
          _ConfirmSummaryRow(
            label: 'app.user.gift_card.total'.tr,
            value: _GiftCardCreatePageState.formatMoney(total),
            valueColor: _GiftCardCreatePageState._brandBlue,
            strong: true,
          ),
        ],
      ),
    );
  }
}

class _ConfirmSummaryRow extends StatelessWidget {
  const _ConfirmSummaryRow({
    required this.label,
    required this.value,
    this.valueColor = _GiftCardCreatePageState._titleColor,
    this.strong = false,
  });

  final String label;
  final String value;
  final Color valueColor;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            textAlign: TextAlign.left,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _GiftCardCreatePageState._bodyColor,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              height: 18 / 13,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Align(
            alignment: Alignment.centerRight,
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: valueColor,
                fontSize: strong ? 16 : 14,
                fontWeight: strong ? FontWeight.w800 : FontWeight.w700,
                height: strong ? 22 / 16 : 20 / 14,
              ),
            ),
          ),
        ),
      ],
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
    required this.enabled,
    required this.isLoading,
    required this.onSubmit,
  });

  final int quantity;
  final bool enabled;
  final bool isLoading;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final label = 'app.user.gift_card.generate_button'.trArgs(['$quantity']);
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
                onTap: enabled ? onSubmit : null,
                child: Ink(
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: enabled
                          ? const [
                              _GiftCardCreatePageState._primaryBlue,
                              _GiftCardCreatePageState._secondaryBlue,
                            ]
                          : const [Color(0xFFCBD5E1), Color(0xFFE2E8F0)],
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
                      if (isLoading)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      else
                        const Icon(
                          Icons.auto_awesome_rounded,
                          size: 22,
                          color: Colors.white,
                        ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          label.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            height: 20 / 14,
                            letterSpacing: 1.4,
                          ),
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
