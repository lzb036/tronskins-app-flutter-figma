import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

class SteamStyleConfirmSummaryItem {
  const SteamStyleConfirmSummaryItem({
    required this.label,
    required this.value,
    this.valueColor,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final bool emphasized;
}

Future<bool?> showSteamStyleAmountConfirmDialog(
  BuildContext context, {
  required String title,
  required String amount,
  List<SteamStyleConfirmSummaryItem> summaryItems = const [],
  String? amountLabel,
  String? noticeText,
  String? cancelText,
  String? confirmText,
  Color? accentColor,
}) {
  return showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black.withValues(alpha: 0.20),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return _SteamStyleAmountConfirmDialog(
        title: title,
        amount: amount,
        summaryItems: summaryItems,
        amountLabel: amountLabel ?? 'app.market.price_total'.tr,
        noticeText: noticeText,
        cancelText: cancelText ?? 'app.common.cancel'.tr,
        confirmText: confirmText ?? 'app.common.confirm'.tr,
        accentColor: accentColor,
      );
    },
    transitionBuilder: (dialogContext, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.94, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class _SteamStyleAmountConfirmDialog extends StatefulWidget {
  const _SteamStyleAmountConfirmDialog({
    required this.title,
    required this.amount,
    required this.summaryItems,
    required this.amountLabel,
    required this.cancelText,
    required this.confirmText,
    this.noticeText,
    this.accentColor,
  });

  final String title;
  final String amount;
  final List<SteamStyleConfirmSummaryItem> summaryItems;
  final String amountLabel;
  final String cancelText;
  final String confirmText;
  final String? noticeText;
  final Color? accentColor;

  @override
  State<_SteamStyleAmountConfirmDialog> createState() =>
      _SteamStyleAmountConfirmDialogState();
}

class _SteamStyleAmountConfirmDialogState
    extends State<_SteamStyleAmountConfirmDialog> {
  bool _agreed = false;
  bool _showAgreementHint = false;

  void _toggleAgreement([bool? value]) {
    setState(() {
      _agreed = value ?? !_agreed;
      if (_agreed) {
        _showAgreementHint = false;
      }
    });
  }

  void _handleConfirmTap() {
    if (!_agreed) {
      HapticFeedback.lightImpact();
      setState(() => _showAgreementHint = true);
      return;
    }
    Navigator.of(context).pop(true);
  }

  Widget _buildAgreementCheckbox({
    required Color borderColor,
    required Color accent,
  }) {
    final checkboxBorderColor = _showAgreementHint
        ? const Color(0xFFD92D20)
        : (_agreed ? accent : borderColor);
    return SizedBox(
      width: 20,
      height: 20,
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: _agreed ? accent : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: checkboxBorderColor, width: 1.4),
          ),
          child: _agreed
              ? const Icon(Icons.check_rounded, size: 13, color: Colors.white)
              : null,
        ),
      ),
    );
  }

  Widget _buildCenteredInfoRow({
    required Widget leading,
    required Widget text,
    VoidCallback? onTap,
    double gap = 10,
    double maxTextWidth = 240,
  }) {
    final content = Center(
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: gap,
        children: [
          leading,
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxTextWidth),
            child: text,
          ),
        ],
      ),
    );
    if (onTap == null) {
      return content;
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: content,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final accent =
        widget.accentColor ??
        (isDark ? colors.primary : const Color(0xFF155EEF));
    final dialogColor = isDark ? const Color(0xFF101828) : Colors.white;
    final borderColor = isDark
        ? const Color(0xFF344054)
        : const Color(0xFFE4E7EC);
    final summaryColor = isDark
        ? const Color(0xFF1F2937)
        : const Color(0xFFF2F4F7);
    final titleColor = isDark ? Colors.white : const Color(0xFF101828);
    final bodyColor = isDark
        ? const Color(0xFF98A2B3)
        : const Color(0xFF475467);
    final noticeColor = isDark
        ? const Color(0xFF6CE9A6)
        : const Color(0xFF039855);
    final amountColor = const Color(0xFFFB6514);

    return Dialog(
      alignment: Alignment.center,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18),
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: dialogColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.12),
                blurRadius: 28,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.title,
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: titleColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      visualDensity: VisualDensity.compact,
                      splashRadius: 18,
                      icon: Icon(Icons.close_rounded, color: bodyColor),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Divider(height: 1, color: borderColor),
                const SizedBox(height: 20),
                Text(
                  widget.amountLabel.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: bodyColor,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.amount,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: amountColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (widget.summaryItems.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: summaryColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      child: Column(
                        children: [
                          for (
                            var i = 0;
                            i < widget.summaryItems.length;
                            i++
                          ) ...[
                            _SummaryRow(
                              item: widget.summaryItems[i],
                              textColor: titleColor,
                              subTextColor: bodyColor,
                            ),
                            if (i != widget.summaryItems.length - 1) ...[
                              const SizedBox(height: 12),
                              Divider(height: 1, color: borderColor),
                              const SizedBox(height: 12),
                            ],
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
                if ((widget.noticeText ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _buildCenteredInfoRow(
                    gap: 8,
                    leading: Icon(
                      Icons.verified_user_outlined,
                      size: 18,
                      color: noticeColor,
                    ),
                    text: Text(
                      widget.noticeText!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: noticeColor,
                        height: 1.4,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                _buildCenteredInfoRow(
                  onTap: _toggleAgreement,
                  leading: _buildAgreementCheckbox(
                    borderColor: borderColor,
                    accent: accent,
                  ),
                  text: RichText(
                    text: TextSpan(
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: bodyColor,
                        height: 1.35,
                      ),
                      children: [
                        TextSpan(text: 'app.trade.buy.agree_prefix'.tr),
                        TextSpan(
                          text: 'app.trade.buy.purchase_agreement'.tr,
                          style: TextStyle(
                            color: accent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        TextSpan(text: 'app.trade.buy.agree_and'.tr),
                        TextSpan(
                          text: 'app.trade.buy.user_terms'.tr,
                          style: TextStyle(
                            color: accent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  child: _showAgreementHint
                      ? Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 280),
                            child: Padding(
                              padding: const EdgeInsets.only(top: 6, left: 30),
                              child: Text(
                                'app.trade.buy.agreement_required'.tr,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: const Color(0xFFD92D20),
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.tonal(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(46),
                          backgroundColor: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : const Color(0xFFF2F4F7),
                          foregroundColor: titleColor,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () => Navigator.of(context).pop(false),
                        child: Text(widget.cancelText),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(46),
                          backgroundColor: accent,
                          foregroundColor: Colors.white,
                          elevation: isDark ? 0 : 3,
                          shadowColor: accent.withValues(alpha: 0.28),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: _handleConfirmTap,
                        child: Text(widget.confirmText),
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
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.item,
    required this.textColor,
    required this.subTextColor,
  });

  final SteamStyleConfirmSummaryItem item;
  final Color textColor;
  final Color subTextColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final emphasized = item.emphasized;
    final labelStyle = emphasized
        ? theme.textTheme.labelSmall?.copyWith(
            color: subTextColor,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          )
        : theme.textTheme.bodyMedium?.copyWith(
            color: subTextColor,
            height: 1.35,
          );
    final valueStyle = emphasized
        ? theme.textTheme.titleSmall?.copyWith(
            color: item.valueColor ?? const Color(0xFF155EEF),
            fontWeight: FontWeight.w800,
            height: 1.3,
          )
        : theme.textTheme.bodyMedium?.copyWith(
            color: item.valueColor ?? textColor,
            fontWeight: FontWeight.w700,
            height: 1.35,
          );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          flex: 6,
          child: Text(
            item.label,
            maxLines: null,
            softWrap: true,
            overflow: TextOverflow.visible,
            style: labelStyle,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 4,
          child: Align(
            alignment: Alignment.centerRight,
            child: Text(
              item.value,
              textAlign: TextAlign.right,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: valueStyle,
            ),
          ),
        ),
      ],
    );
  }
}
