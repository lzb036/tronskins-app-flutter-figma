import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tronskins_app/common/widgets/settings_style_app_bar.dart';

class InventoryUpShopConfirmPage extends StatefulWidget {
  const InventoryUpShopConfirmPage({
    super.key,
    required this.totalCount,
    required this.totalPriceText,
    required this.handlingFeeText,
    required this.expectedIncomeText,
    required this.confirmAmountText,
    required this.rewardPointsText,
    required this.warningLines,
    required this.onConfirm,
  });

  final int totalCount;
  final String totalPriceText;
  final String handlingFeeText;
  final String expectedIncomeText;
  final String confirmAmountText;
  final String rewardPointsText;
  final List<String> warningLines;
  final Future<bool> Function() onConfirm;

  static const Color _pageBackground = Color(0xFFF7F9FB);
  static const Color _brandColor = Color(0xFF1E40AF);
  static const Color _brandDeepColor = Color(0xFF00288E);
  static const Color _textPrimary = Color(0xFF191C1E);
  static const Color _textSecondary = Color(0xFF444653);
  static const Color _cardBorder = Color.fromRGBO(196, 197, 213, 0.15);
  static const Color _successStart = Color(0xFF10B981);
  static const Color _successEnd = Color(0xFF059669);
  static const Color _dangerColor = Color(0xFFBA1A1A);

  @override
  State<InventoryUpShopConfirmPage> createState() =>
      _InventoryUpShopConfirmPageState();
}

class _InventoryUpShopConfirmPageState
    extends State<InventoryUpShopConfirmPage> {
  bool _isSubmitting = false;

  Future<void> _handleConfirm() async {
    if (_isSubmitting) {
      return;
    }
    setState(() => _isSubmitting = true);
    var closingRoutes = false;
    try {
      final ok = await widget.onConfirm();
      if (!mounted || !ok) {
        return;
      }
      final navigator = Navigator.of(context);
      closingRoutes = true;
      navigator.pop(true);
      navigator.pop(true);
    } finally {
      if (mounted && !closingRoutes) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return PopScope(
      canPop: !_isSubmitting,
      child: Scaffold(
        backgroundColor: InventoryUpShopConfirmPage._pageBackground,
        appBar: SettingsStyleAppBar(
          title: Text('app.inventory.upshop.confirm.title'.tr),
        ),
        body: Stack(
          children: [
            const Positioned(
              top: 80,
              right: -39,
              child: _BlurDecoration(color: Color.fromRGBO(0, 40, 142, 0.05)),
            ),
            const Positioned(
              left: -39,
              bottom: 80,
              child: _BlurDecoration(color: Color.fromRGBO(0, 88, 190, 0.05)),
            ),
            SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(16, 24, 16, 24 + bottomInset),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.warningLines.isNotEmpty) ...[
                    _WarningCard(lines: widget.warningLines),
                    const SizedBox(height: 24),
                  ],
                  _SummaryCard(
                    totalCount: widget.totalCount,
                    totalPriceText: widget.totalPriceText,
                    handlingFeeText: widget.handlingFeeText,
                    expectedIncomeText: widget.expectedIncomeText,
                    rewardPointsText: widget.rewardPointsText,
                  ),
                  const SizedBox(height: 24),
                  _ChecklistCard(
                    items: [
                      _ChecklistEntry(
                        title: '1',
                        content: 'app.trade.order.seller_tips_1'.tr,
                      ),
                      _ChecklistEntry(
                        title: '2',
                        content: 'app.trade.order.seller_tips_2'.tr,
                      ),
                      _ChecklistEntry(
                        title: '3',
                        content: 'app.trade.order.seller_tips_3'.tr,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: _BottomActionBar(
          confirmAmountText: widget.confirmAmountText,
          isSubmitting: _isSubmitting,
          onConfirm: _handleConfirm,
        ),
      ),
    );
  }
}

class _BlurDecoration extends StatelessWidget {
  const _BlurDecoration({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
      child: Container(
        width: 156,
        height: 275.39,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}

class _WarningCard extends StatelessWidget {
  const _WarningCard({required this.lines});

  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7F7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFD7D7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'app.inventory.pricing_abnormal'.tr,
            style: const TextStyle(
              color: InventoryUpShopConfirmPage._dangerColor,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 180),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: lines.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (context, index) {
                return Text(
                  lines[index],
                  style: const TextStyle(
                    color: InventoryUpShopConfirmPage._dangerColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    height: 1.5,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.totalCount,
    required this.totalPriceText,
    required this.handlingFeeText,
    required this.expectedIncomeText,
    required this.rewardPointsText,
  });

  final int totalCount;
  final String totalPriceText;
  final String handlingFeeText;
  final String expectedIncomeText;
  final String rewardPointsText;

  @override
  Widget build(BuildContext context) {
    final itemUnit = totalCount == 1
        ? 'app.inventory.upshop.confirm.item_unit.one'.tr
        : 'app.inventory.upshop.confirm.item_unit.other'.tr;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.05),
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 4,
                      height: 24,
                      decoration: BoxDecoration(
                        color: InventoryUpShopConfirmPage._brandDeepColor,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'app.inventory.upshop.confirm.list_title'.tr,
                        style: const TextStyle(
                          color: InventoryUpShopConfirmPage._textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          height: 1.55,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '$totalCount',
                    style: const TextStyle(
                      color: InventoryUpShopConfirmPage._brandDeepColor,
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(width: 4),
                  SizedBox(
                    height: 20,
                    child: Align(
                      alignment: Alignment.bottomRight,
                      child: Text(
                        itemUnit,
                        softWrap: false,
                        style: const TextStyle(
                          color: InventoryUpShopConfirmPage._textSecondary,
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          height: 20 / 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 17),
          Container(height: 1, color: InventoryUpShopConfirmPage._cardBorder),
          const SizedBox(height: 17),
          _SummaryRow(
            label: 'app.trade.order.total_price'.tr,
            value: totalPriceText,
          ),
          const SizedBox(height: 16),
          _SummaryRow(
            label: 'app.inventory.upshop.handling_charge'.tr,
            value: handlingFeeText.startsWith('-')
                ? handlingFeeText
                : '-$handlingFeeText',
            valueColor: InventoryUpShopConfirmPage._dangerColor,
          ),
          const SizedBox(height: 16),
          _SummaryRow(
            label: 'app.user.integral.unit'.tr,
            value: rewardPointsText,
            valueColor: InventoryUpShopConfirmPage._textPrimary,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              gradient: const LinearGradient(
                colors: [
                  InventoryUpShopConfirmPage._successStart,
                  InventoryUpShopConfirmPage._successEnd,
                ],
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color.fromRGBO(0, 0, 0, 0.1),
                  blurRadius: 6,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 24,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'app.inventory.upshop.expected_income'.tr,
                          softWrap: false,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: SizedBox(
                    height: 36,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          expectedIncomeText,
                          softWrap: false,
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            height: 1.35,
                          ),
                        ),
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
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.valueColor = InventoryUpShopConfirmPage._textPrimary,
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: InventoryUpShopConfirmPage._textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              height: 1.45,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: valueColor,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                height: 1.45,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ChecklistCard extends StatelessWidget {
  const _ChecklistCard({required this.items});

  final List<_ChecklistEntry> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F4F6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.shield_outlined,
                size: 20,
                color: Color(0xFF0058BE),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'app.steam.verification'.tr,
                  style: const TextStyle(
                    color: InventoryUpShopConfirmPage._textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          for (var index = 0; index < items.length; index++) ...[
            _ChecklistItem(entry: items[index]),
            if (index != items.length - 1) const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }
}

class _ChecklistEntry {
  const _ChecklistEntry({required this.title, required this.content});

  final String title;
  final String content;
}

class _ChecklistItem extends StatelessWidget {
  const _ChecklistItem({required this.entry});

  final _ChecklistEntry entry;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: const BoxDecoration(
            color: Color.fromRGBO(33, 112, 228, 0.2),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            entry.title,
            style: const TextStyle(
              color: Color(0xFF0058BE),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              height: 1.5,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            entry.content,
            style: const TextStyle(
              color: InventoryUpShopConfirmPage._textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}

class _BottomActionBar extends StatelessWidget {
  const _BottomActionBar({
    required this.confirmAmountText,
    required this.isSubmitting,
    required this.onConfirm,
  });

  final String confirmAmountText;
  final bool isSubmitting;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: SafeArea(
          top: false,
          child: Container(
            height: 72,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            decoration: BoxDecoration(
              color: const Color.fromRGBO(255, 255, 255, 0.7),
              border: Border(
                top: BorderSide(
                  color: const Color(0xFFE2E8F0).withValues(alpha: 0.35),
                ),
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color.fromRGBO(0, 0, 0, 0.04),
                  blurRadius: 20,
                  offset: Offset(0, -4),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 5,
                  child: _ActionButton(
                    label: 'app.common.cancel'.tr,
                    backgroundColor: const Color(0xFFF1F5F9),
                    labelColor: const Color(0xFF64748B),
                    onTap: isSubmitting
                        ? null
                        : () => Navigator.of(context).pop(false),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 9,
                  child: _ActionButton(
                    label: 'app.common.confirm'.tr,
                    amountText: confirmAmountText,
                    labelColor: Colors.white,
                    loading: isSubmitting,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        InventoryUpShopConfirmPage._brandColor,
                        Color(0xFF3B82F6),
                      ],
                    ),
                    onTap: isSubmitting ? null : onConfirm,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.labelColor,
    this.onTap,
    this.backgroundColor,
    this.gradient,
    this.amountText,
    this.loading = false,
  });

  final String label;
  final Color labelColor;
  final Color? backgroundColor;
  final LinearGradient? gradient;
  final String? amountText;
  final VoidCallback? onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final isEnabled = onTap != null && !loading;
    final content = loading
        ? SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              valueColor: AlwaysStoppedAnimation<Color>(labelColor),
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                maxLines: 1,
                softWrap: false,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: labelColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                  letterSpacing: 0.2,
                ),
              ),
              if ((amountText ?? '').isNotEmpty) ...[
                const SizedBox(width: 6),
                Text(
                  amountText!,
                  maxLines: 1,
                  softWrap: false,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: labelColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    height: 1.3,
                    letterSpacing: 0.1,
                  ),
                ),
              ],
            ],
          );

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: Opacity(
        opacity: isEnabled ? 1 : 0.72,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: isEnabled ? onTap : null,
          child: Ink(
            decoration: BoxDecoration(
              color: backgroundColor,
              gradient: gradient,
              borderRadius: BorderRadius.circular(8),
              boxShadow: gradient == null
                  ? null
                  : const [
                      BoxShadow(
                        color: Color.fromRGBO(0, 0, 0, 0.1),
                        blurRadius: 15,
                        offset: Offset(0, 10),
                      ),
                    ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Center(
              child: FittedBox(fit: BoxFit.scaleDown, child: content),
            ),
          ),
        ),
      ),
    );
  }
}
