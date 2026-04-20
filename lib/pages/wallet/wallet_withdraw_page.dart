import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tronskins_app/api/model/entity/user/user_info_entity.dart';
import 'package:tronskins_app/api/model/wallet/wallet_models.dart';
import 'package:tronskins_app/common/hooks/currency/CurrencyController.dart';
import 'package:tronskins_app/common/storage/twofa_storage.dart';
import 'package:tronskins_app/common/utils/app_snackbar.dart';
import 'package:tronskins_app/common/widgets/settings_style_app_bar.dart';
import 'package:tronskins_app/controllers/wallet/wallet_controller.dart';
import 'package:tronskins_app/routes/app_routes.dart';

class WalletWithdrawPage extends StatefulWidget {
  const WalletWithdrawPage({super.key});

  @override
  State<WalletWithdrawPage> createState() => _WalletWithdrawPageState();
}

class _WalletWithdrawPageState extends State<WalletWithdrawPage> {
  static const Color _pageBackground = Color(0xFFF7F9FB);
  static const Color _surfaceColor = Colors.white;
  static const Color _softSurfaceColor = Color(0xFFF2F4F6);
  static const Color _titleColor = Color(0xFF191C1E);
  static const Color _bodyColor = Color(0xFF444653);
  static const Color _hintColor = Color(0xFFD8DADC);
  static const Color _borderColor = Color(0xFFE6E8EA);
  static const Color _brandDarkColor = Color(0xFF1E40AF);
  static const Color _brandColor = Color(0xFF0058BE);
  static const Color _brandDeepColor = Color(0xFF00288E);

  final WalletController controller = Get.isRegistered<WalletController>()
      ? Get.find<WalletController>()
      : Get.put(WalletController());

  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _addressNameController = TextEditingController();
  final TextEditingController _addressAccountController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    controller.refreshUser();
    controller.loadWithdrawAddresses();
    controller.loadWithdrawFee();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _addressNameController.dispose();
    _addressAccountController.dispose();
    super.dispose();
  }

  bool get _isChineseLocale =>
      (Get.locale?.languageCode ?? '').toLowerCase().startsWith('zh');

  String _rulesTitle() {
    return _isChineseLocale ? '提现规则' : 'Withdrawal Rules';
  }

  String _selectWalletSheetTitle() {
    return _isChineseLocale ? '选择钱包地址' : 'Select Wallet Address';
  }

  String _addAddressActionLabel() {
    return _isChineseLocale ? '添加新地址' : 'Add New Address';
  }

  String _currentBalanceLabel() {
    return _isChineseLocale ? '当前零钱余额' : 'Available Balance';
  }

  String _amountHintText() {
    return _isChineseLocale ? '请输入提现金额' : 'Enter withdrawal amount';
  }

  String _walletAddressSectionTitle() {
    return _isChineseLocale ? '提现至钱包地址' : 'Withdraw to wallet address';
  }

  String _selectWalletPlaceholder() {
    return _isChineseLocale ? '请选择您的钱包地址' : 'Please select your wallet address';
  }

  String _arrivalRuleText() {
    return _isChineseLocale
        ? '由于提现需要时间审核，最长次日到账'
        : 'Withdrawal requires review and may arrive by the next day.';
  }

  String _minMaxRule(String symbol) {
    return _isChineseLocale
        ? '提现最低 ${symbol}10 起，最高 ${symbol}20000'
        : 'Minimum withdrawal is ${symbol}10, maximum is ${symbol}20000';
  }

  String _feeRule(String symbol, double fee) {
    final feeText = '$symbol${_formatRuleAmount(fee)}';
    return _isChineseLocale
        ? '每笔提现需收 $feeText 的手续费'
        : 'Each withdrawal charges $feeText as a handling fee';
  }

  String _confirmWithdrawDialogTitle() {
    return _isChineseLocale ? '确认提现' : 'Confirm Withdrawal';
  }

  String _confirmWithdrawAddressLabel() {
    return _isChineseLocale ? '提现地址' : 'Withdrawal Address';
  }

  String _confirmWithdrawAmountLabel() {
    return _isChineseLocale ? '提现金额' : 'Withdrawal Amount';
  }

  String _confirmWithdrawFeeLabel() {
    return _isChineseLocale ? '手续费' : 'Fee';
  }

  String _confirmWithdrawActualLabel() {
    return _isChineseLocale ? '实际到账' : 'Actual Received';
  }

  String _confirmWithdrawWarningText() {
    return _isChineseLocale
        ? '提现申请提交后不可撤销'
        : 'Withdrawal requests cannot be revoked after submission';
  }

  String _formatRuleAmount(double value) {
    if (value == value.truncateToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(2);
  }

  void _fillAll() {
    final available = controller.userInfo.value?.fund?.available ?? 0;
    _amountController.text = available.toStringAsFixed(2);
  }

  String _shortAddress(String? raw) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty || value.length <= 18) {
      return value;
    }
    return '${value.substring(0, 8)}...${value.substring(value.length - 6)}';
  }

  bool _isAddressSelected(
    WalletWithdrawAddress item,
    WalletWithdrawAddress? selected,
  ) {
    if (selected == null) {
      return false;
    }
    if ((item.id ?? '').isNotEmpty && item.id == selected.id) {
      return true;
    }
    return (item.account ?? '') == (selected.account ?? '');
  }

  bool _isValidAmountInput(String value) {
    return RegExp(r'^\d{0,9}(\.\d{0,2})?$').hasMatch(value);
  }

  String _limitAmountText(String raw, {bool showToast = false}) {
    var value = raw.trim();
    if (value.isEmpty) {
      return '';
    }

    value = value.replaceAll(',', '.').replaceAll(RegExp(r'\s+'), '');
    value = value.replaceAll(RegExp(r'[^0-9\.]'), '');
    final firstDot = value.indexOf('.');
    if (firstDot >= 0) {
      final integer = value.substring(0, firstDot);
      final decimal = value.substring(firstDot + 1).replaceAll('.', '');
      value = '$integer.$decimal';
    }

    if (value.startsWith('.')) {
      value = '0$value';
    }

    final parsed = double.tryParse(value);
    if (parsed == null) {
      if (showToast) {
        AppSnackbar.error('app.market.filter.message.price_error'.tr);
      }
      return '';
    }

    var limited = parsed;
    final available = controller.userInfo.value?.fund?.available;
    if (available != null && limited > available) {
      limited = available;
    }

    final fixed = limited.toStringAsFixed(2);
    if (value.contains('.')) {
      final decimals = value.split('.').last;
      if (decimals.isEmpty) {
        value = '${limited.truncate()}.';
      } else if (decimals.length == 1) {
        value = fixed.substring(0, fixed.length - 1);
      } else {
        value = fixed;
      }
    } else {
      value = limited.truncate().toString();
    }

    if (!_isValidAmountInput(value)) {
      return limited.toStringAsFixed(2);
    }
    return value;
  }

  void _onAmountChanged(String value) {
    final limited = _limitAmountText(value, showToast: true);
    if (limited != value) {
      _amountController.value = TextEditingValue(
        text: limited,
        selection: TextSelection.collapsed(offset: limited.length),
      );
    }
  }

  void _normalizeAmountOnBlur() {
    final value = _amountController.text.trim();
    if (value.isEmpty) {
      return;
    }
    final amount = double.tryParse(value);
    if (amount == null) {
      _amountController.clear();
      return;
    }
    _amountController.text = amount.toStringAsFixed(2);
  }

  Future<void> _submitWithdraw() async {
    final amountText = _amountController.text.trim();
    final amount = double.tryParse(amountText) ?? 0;
    if (amount <= 0) {
      AppSnackbar.error('app.user.withdraw.message.enter_amount'.tr);
      return;
    }
    if (amount < 10) {
      AppSnackbar.error('app.user.withdraw.message.amount_error'.tr);
      return;
    }
    if (amount > 20000) {
      AppSnackbar.error('app.user.withdraw.max_message'.tr);
      return;
    }
    final available = controller.userInfo.value?.fund?.available ?? 0;
    if (amount > available) {
      AppSnackbar.error('app.user.withdraw.message.enter_amount'.tr);
      _amountController.text = available.toStringAsFixed(2);
      return;
    }
    final address = controller.selectedWithdrawAddress.value;
    if (address == null || (address.account ?? '').isEmpty) {
      AppSnackbar.error('app.user.withdraw.enter_address'.tr);
      return;
    }
    final currency = Get.find<CurrencyController>();
    final confirm = await _showWithdrawConfirmDialog(
      currency: currency,
      amount: amount,
      address: address.account ?? '',
    );
    if (confirm != true) {
      return;
    }
    final user = controller.userInfo.value;
    final token = await _findCurrentUserToken(user);
    if (user?.need2FA != true ||
        user?.safeTokenStatus != true ||
        token == null ||
        token.secret.isEmpty) {
      await _promptGuardSetup();
      return;
    }
    final twoFa = TwoFactorHelper.generateCode(token.secret);
    if (twoFa.isEmpty) {
      await _promptGuardSetup();
      return;
    }
    final success = await controller.submitWithdraw(
      amount: amount,
      account: address.account ?? '',
      twoFa: twoFa,
    );
    if (success) {
      _amountController.clear();
      AppSnackbar.success('app.user.withdraw.message.success'.tr);
    }
  }

  Future<bool?> _showWithdrawConfirmDialog({
    required CurrencyController currency,
    required double amount,
    required String address,
  }) {
    final fee = controller.withdrawFee.value;
    final actualAmount = amount > fee ? amount - fee : 0.0;

    return showGeneralDialog<bool>(
      context: context,
      barrierLabel: _confirmWithdrawDialogTitle(),
      barrierDismissible: true,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (_, __, ___) {
        return _WithdrawConfirmDialog(
          title: _confirmWithdrawDialogTitle(),
          addressLabel: _confirmWithdrawAddressLabel(),
          amountLabel: _confirmWithdrawAmountLabel(),
          feeLabel: _confirmWithdrawFeeLabel(),
          actualLabel: _confirmWithdrawActualLabel(),
          warningText: _confirmWithdrawWarningText(),
          address: address,
          amountText: currency.formatUsd(amount),
          feeText: currency.formatUsd(fee),
          actualText: currency.formatUsd(actualAmount),
          confirmLabel: _confirmWithdrawDialogTitle(),
          cancelLabel: 'app.common.cancel'.tr,
          onConfirm: () => Navigator.of(context).pop(true),
          onCancel: () => Navigator.of(context).pop(false),
        );
      },
      transitionBuilder: (_, animation, __, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  Future<TwoFactorToken?> _findCurrentUserToken(UserInfoEntity? user) async {
    if (user == null) {
      return null;
    }
    final userId = user.id ?? '';
    final appUse = user.appUse ?? '';
    if (userId.isEmpty) {
      return null;
    }

    final tokens = await TwoFactorStorage.getList();

    if (appUse.isNotEmpty) {
      final exactMatch = tokens.firstWhereOrNull(
        (token) =>
            token.userId == userId &&
            token.appUse == appUse &&
            token.secret.isNotEmpty,
      );
      if (exactMatch != null) {
        return exactMatch;
      }
    }

    final sameUserTokens = tokens
        .where((token) => token.userId == userId && token.secret.isNotEmpty)
        .toList();
    if (sameUserTokens.length == 1) {
      return sameUserTokens.first;
    }

    return null;
  }

  Future<void> _promptGuardSetup() async {
    final confirm = await Get.dialog<bool>(
      AlertDialog(
        title: Text('app.system.tips.title'.tr),
        content: Text('app.user.guard.set_tips'.tr),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: Text('app.common.cancel'.tr),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            child: Text('app.common.confirm'.tr),
          ),
        ],
      ),
    );
    if (confirm == true) {
      Get.toNamed(Routers.USER_GUARD);
    }
  }

  void _showAddressSheet() {
    FocusScope.of(context).unfocus();
    controller.loadWithdrawAddresses();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final screenHeight = MediaQuery.of(sheetContext).size.height;
        final maxListHeight = screenHeight < 720
            ? screenHeight * 0.38
            : screenHeight * 0.46;

        return SafeArea(
          top: false,
          child: Align(
            alignment: Alignment.bottomCenter,
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 448),
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: _pageBackground,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [
                    BoxShadow(
                      color: Color.fromRGBO(0, 0, 0, 0.15),
                      blurRadius: 60,
                      offset: Offset(0, -20),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 12),
                    _buildSheetHandle(),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                      child: _buildBottomSheetHeader(
                        context: sheetContext,
                        title: _selectWalletSheetTitle(),
                        showCloseButton: false,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Obx(() {
                        final list = controller.withdrawAddresses;
                        if (controller.isLoadingAddresses.value) {
                          return _buildAddressSheetLoadingList(maxListHeight);
                        }
                        if (list.isEmpty) {
                          return SizedBox(
                            height: 120,
                            child: Center(
                              child: Text(
                                'app.common.no_data'.tr,
                                style: const TextStyle(
                                  color: _bodyColor,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          );
                        }
                        return ConstrainedBox(
                          constraints: BoxConstraints(maxHeight: maxListHeight),
                          child: ListView.separated(
                            shrinkWrap: true,
                            padding: EdgeInsets.zero,
                            itemCount: list.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 12),
                            itemBuilder: (itemContext, index) {
                              final item = list[index];
                              final isSelected = _isAddressSelected(
                                item,
                                controller.selectedWithdrawAddress.value,
                              );
                              return _buildAddressSheetItem(
                                itemContext,
                                item,
                                isSelected: isSelected,
                              );
                            },
                          ),
                        );
                      }),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                      child: SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.of(sheetContext).pop();
                            Future<void>.delayed(Duration.zero, () {
                              if (mounted) {
                                _showAddAddressSheet();
                              }
                            });
                          },
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: Text(_addAddressActionLabel()),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _brandDeepColor,
                            side: const BorderSide(
                              color: _brandDeepColor,
                              width: 1.5,
                            ),
                            minimumSize: const Size.fromHeight(56),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              height: 24 / 16,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmDeleteAddress(String? id) async {
    if (id == null) {
      return;
    }
    final confirm = await Get.dialog<bool>(
      AlertDialog(
        title: Text('app.system.tips.title'.tr),
        content: Text('app.user.withdraw.message.delete_address'.tr),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: Text('app.common.cancel'.tr),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            child: Text('app.common.confirm'.tr),
          ),
        ],
      ),
    );
    if (confirm == true) {
      final ok = await controller.removeWithdrawAddress(id);
      if (ok) {
        AppSnackbar.success('app.system.message.success'.tr);
      }
    }
  }

  void _showAddAddressSheet() {
    FocusScope.of(context).unfocus();
    _addressNameController.clear();
    _addressAccountController.clear();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
            ),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 448),
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: _pageBackground,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Color.fromRGBO(0, 0, 0, 0.15),
                        blurRadius: 60,
                        offset: Offset(0, -20),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildSheetHandle(),
                        const SizedBox(height: 8),
                        _buildBottomSheetHeader(
                          context: sheetContext,
                          title: 'app.user.withdraw.add_address'.tr,
                        ),
                        const SizedBox(height: 20),
                        TextField(
                          controller: _addressNameController,
                          textInputAction: TextInputAction.next,
                          decoration: _sheetInputDecoration(
                            hintText: 'app.user.withdraw.message.enter_name'.tr,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _addressAccountController,
                          textInputAction: TextInputAction.done,
                          decoration: _sheetInputDecoration(
                            hintText: 'app.user.wallet.address'.tr,
                          ),
                        ),
                        const SizedBox(height: 20),
                        _buildPrimaryActionButton(
                          label: 'app.common.confirm'.tr,
                          onTap: () async {
                            final name = _addressNameController.text.trim();
                            final account = _addressAccountController.text
                                .trim();
                            if (name.isEmpty) {
                              AppSnackbar.error(
                                'app.user.withdraw.message.name_empty'.tr,
                              );
                              return;
                            }
                            if (account.isEmpty) {
                              AppSnackbar.error(
                                'app.user.withdraw.enter_address'.tr,
                              );
                              return;
                            }
                            final ok = await controller.addWithdrawAddress(
                              name: name,
                              account: account,
                            );
                            if (ok) {
                              if (!sheetContext.mounted) {
                                return;
                              }
                              Navigator.of(sheetContext).pop();
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                AppSnackbar.success(
                                  'app.system.message.success'.tr,
                                );
                              });
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSheetHandle() {
    return Center(
      child: Container(
        width: 48,
        height: 6,
        decoration: BoxDecoration(
          color: _hintColor,
          borderRadius: BorderRadius.circular(99),
        ),
      ),
    );
  }

  Widget _buildBottomSheetHeader({
    required BuildContext context,
    required String title,
    bool showCloseButton = true,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _titleColor,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              height: 28 / 20,
            ),
          ),
        ),
        if (showCloseButton) ...[
          const SizedBox(width: 8),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded),
            color: _bodyColor,
            splashRadius: 20,
          ),
        ],
      ],
    );
  }

  InputDecoration _sheetInputDecoration({required String hintText}) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(
        color: Color(0xFF94A3B8),
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      filled: true,
      fillColor: _surfaceColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _brandDeepColor, width: 1.4),
      ),
    );
  }

  Widget _buildAddressSheetItem(
    BuildContext context,
    WalletWithdrawAddress item, {
    required bool isSelected,
  }) {
    final name = item.name?.trim() ?? '';
    final account = item.account?.trim() ?? '';
    final title = name.isNotEmpty ? name : _shortAddress(account);
    final subtitle = account.isNotEmpty ? _shortAddress(account) : '';
    final canDelete = !isSelected && (item.id ?? '').isNotEmpty;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          controller.selectedWithdrawAddress.value = item;
          Navigator.of(context).pop();
        },
        borderRadius: BorderRadius.zero,
        child: Ink(
          decoration: BoxDecoration(
            color: _surfaceColor,
            borderRadius: BorderRadius.zero,
            border: Border.all(
              color: isSelected
                  ? const Color.fromRGBO(0, 40, 142, 0.12)
                  : const Color.fromRGBO(196, 197, 213, 0.08),
              width: isSelected ? 2 : 1,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color.fromRGBO(0, 0, 0, 0.05),
                blurRadius: 2,
                offset: Offset(0, 1),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          child: Row(
            children: [
              _buildWalletBadge(selected: isSelected),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title.isEmpty ? 'app.user.wallet.address'.tr : title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _titleColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        height: 20 / 14,
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _bodyColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          height: 16 / 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (canDelete)
                IconButton(
                  onPressed: () => _confirmDeleteAddress(item.id),
                  icon: const Icon(Icons.close_rounded, size: 18),
                  color: const Color(0xFF94A3B8),
                  splashRadius: 18,
                  constraints: const BoxConstraints.tightFor(
                    width: 32,
                    height: 32,
                  ),
                  padding: EdgeInsets.zero,
                ),
              if (canDelete) const SizedBox(width: 8),
              _buildSelectionIndicator(isSelected: isSelected),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddressSheetLoadingList(double maxListHeight) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxListHeight),
      child: ListView.separated(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 2,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, __) => _buildAddressSheetSkeletonItem(),
      ),
    );
  }

  Widget _buildAddressSheetSkeletonItem() {
    return Container(
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.zero,
        border: Border.all(color: const Color.fromRGBO(196, 197, 213, 0.08)),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.05),
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      child: Row(
        children: [
          _buildSkeletonBox(width: 48, height: 48, radius: 12),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSkeletonBox(width: 104, height: 14),
                const SizedBox(height: 10),
                _buildSkeletonBox(width: 152, height: 12),
              ],
            ),
          ),
          const SizedBox(width: 16),
          _buildSkeletonBox(width: 24, height: 24, radius: 12),
        ],
      ),
    );
  }

  Widget _buildSkeletonBox({
    required double width,
    required double height,
    double radius = 999,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFE6EDF4),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }

  Widget _buildWalletBadge({required bool selected}) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: selected
            ? const Color.fromRGBO(0, 40, 142, 0.05)
            : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        Icons.account_balance_wallet_outlined,
        size: 20,
        color: selected ? _brandDeepColor : const Color(0xFF4B5563),
      ),
    );
  }

  Widget _buildSelectionIndicator({required bool isSelected}) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: isSelected ? _brandDeepColor : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? _brandDeepColor : const Color(0xFFC4C5D5),
          width: 2,
        ),
      ),
      child: isSelected
          ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
          : null,
    );
  }

  Widget _buildPrimaryActionButton({
    required String label,
    required VoidCallback onTap,
  }) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_brandDarkColor, Color(0xFF3B82F6)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(59, 130, 246, 0.2),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            height: 56,
            width: double.infinity,
            child: Center(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  height: 24 / 16,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCard({
    required Widget child,
    Color backgroundColor = _surfaceColor,
    bool showShadow = true,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        boxShadow: showShadow
            ? const [
                BoxShadow(
                  color: Color.fromRGBO(0, 0, 0, 0.05),
                  blurRadius: 2,
                  offset: Offset(0, 1),
                ),
              ]
            : null,
      ),
      padding: const EdgeInsets.all(24),
      child: child,
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: _bodyColor,
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 20 / 14,
      ),
    );
  }

  Widget _buildAddressCard() {
    final selected = controller.selectedWithdrawAddress.value;
    final name = selected?.name?.trim() ?? '';
    final account = selected?.account?.trim() ?? '';
    final primaryText = name.isNotEmpty
        ? name
        : account.isNotEmpty
        ? _shortAddress(account)
        : _selectWalletPlaceholder();
    final secondaryText = account.isNotEmpty && account != primaryText
        ? _shortAddress(account)
        : '';

    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(_walletAddressSectionTitle()),
          const SizedBox(height: 16),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _showAddressSheet,
              borderRadius: BorderRadius.circular(8),
              child: Ink(
                decoration: BoxDecoration(
                  color: _softSurfaceColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 17,
                  vertical: 17,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color.fromRGBO(0, 88, 190, 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.account_balance_wallet_outlined,
                        size: 20,
                        color: _brandColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            primaryText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _titleColor,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              height: 24 / 16,
                            ),
                          ),
                          if (secondaryText.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              secondaryText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _bodyColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                height: 16 / 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 22,
                      color: Color(0xFF6B7280),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountCard(CurrencyController currency) {
    final available = controller.userInfo.value?.fund?.available ?? 0;

    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('app.user.withdraw.amount'.tr),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.only(bottom: 10),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: _borderColor, width: 2)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  currency.usdSymbol,
                  style: const TextStyle(
                    color: _titleColor,
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    height: 36 / 30,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textInputAction: TextInputAction.done,
                    onChanged: _onAmountChanged,
                    onEditingComplete: _normalizeAmountOnBlur,
                    style: const TextStyle(
                      color: _titleColor,
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      height: 32 / 24,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: _amountHintText(),
                      hintMaxLines: 1,
                      hintStyle: const TextStyle(
                        color: _hintColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        height: 24 / 16,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_currentBalanceLabel()}:',
                      style: const TextStyle(
                        color: _bodyColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        height: 20 / 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      currency.formatUsd(available),
                      style: const TextStyle(
                        color: _titleColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        height: 20 / 14,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              TextButton(
                onPressed: _fillAll,
                style: TextButton.styleFrom(
                  foregroundColor: _brandColor,
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'app.user.withdraw.full_title'.tr,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 20 / 14,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRulesCard(CurrencyController currency) {
    final rules = [
      _minMaxRule(currency.usdSymbol),
      _feeRule(currency.usdSymbol, controller.withdrawFee.value),
      _arrivalRuleText(),
    ];

    return _buildCard(
      backgroundColor: _softSurfaceColor,
      showShadow: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(_rulesTitle()),
          const SizedBox(height: 16),
          for (var index = 0; index < rules.length; index++)
            Padding(
              padding: EdgeInsets.only(
                bottom: index == rules.length - 1 ? 0 : 12,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.only(top: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2170E4),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      rules[index],
                      style: const TextStyle(
                        color: _bodyColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        height: 22.75 / 14,
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

  Widget _buildBottomActionBar() {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: const BoxDecoration(
            color: Color.fromRGBO(255, 255, 255, 0.8),
            border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
          ),
          child: SafeArea(
            top: false,
            minimum: const EdgeInsets.fromLTRB(24, 13, 24, 24),
            child: Align(
              alignment: Alignment.topCenter,
              heightFactor: 1,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 672),
                child: _buildPrimaryActionButton(
                  label: 'app.user.withdraw.title'.tr,
                  onTap: () {
                    FocusScope.of(context).unfocus();
                    _normalizeAmountOnBlur();
                    _submitWithdraw();
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currency = Get.find<CurrencyController>();
    return Scaffold(
      backgroundColor: _pageBackground,
      appBar: SettingsStyleAppBar(
        title: Text('app.user.withdraw.title'.tr),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              onPressed: () => Get.toNamed(Routers.WALLET_WITHDRAW_RECORD),
              icon: const Icon(Icons.history_rounded),
              color: _brandDarkColor,
              tooltip: 'app.user.wallet.withdraw_record'.tr,
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomActionBar(),
      body: Obx(() {
        return ListView(
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
          children: [
            Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 672),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildAddressCard(),
                    const SizedBox(height: 24),
                    _buildAmountCard(currency),
                    const SizedBox(height: 24),
                    _buildRulesCard(currency),
                  ],
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}

class _WithdrawConfirmDialog extends StatelessWidget {
  const _WithdrawConfirmDialog({
    required this.title,
    required this.addressLabel,
    required this.amountLabel,
    required this.feeLabel,
    required this.actualLabel,
    required this.warningText,
    required this.address,
    required this.amountText,
    required this.feeText,
    required this.actualText,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.onConfirm,
    required this.onCancel,
  });

  final String title;
  final String addressLabel;
  final String amountLabel;
  final String feeLabel;
  final String actualLabel;
  final String warningText;
  final String address;
  final String amountText;
  final String feeText;
  final String actualText;
  final String confirmLabel;
  final String cancelLabel;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: onCancel,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
                child: Container(color: const Color.fromRGBO(25, 28, 30, 0.2)),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 300),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: const [
                        BoxShadow(
                          color: Color.fromRGBO(0, 0, 0, 0.12),
                          blurRadius: 100,
                          offset: Offset(0, 40),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Text(
                            title,
                            style: const TextStyle(
                              color: _WalletWithdrawPageState._titleColor,
                              fontSize: 20,
                              fontWeight: FontWeight.w500,
                              height: 28 / 20,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          addressLabel,
                          style: const TextStyle(
                            color: _WalletWithdrawPageState._bodyColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            height: 16.5 / 11,
                            letterSpacing: 1.1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          address,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _WalletWithdrawPageState._titleColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                            height: 19.5 / 13,
                          ),
                        ),
                        const SizedBox(height: 18),
                        const Divider(
                          height: 1,
                          thickness: 1,
                          color: Color(0xFFECEEF0),
                        ),
                        const SizedBox(height: 18),
                        _WithdrawConfirmValueRow(
                          label: amountLabel,
                          value: amountText,
                          valueColor: _WalletWithdrawPageState._brandColor,
                          emphasized: true,
                        ),
                        const SizedBox(height: 12),
                        _WithdrawConfirmValueRow(
                          label: feeLabel,
                          value: feeText,
                        ),
                        const SizedBox(height: 12),
                        const _WithdrawConfirmDashedDivider(),
                        const SizedBox(height: 9),
                        _WithdrawConfirmValueRow(
                          label: actualLabel,
                          value: actualText,
                          emphasized: true,
                          valueFontSize: 20,
                        ),
                        const SizedBox(height: 32),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF2F4F6),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.info_outline_rounded,
                                size: 14,
                                color: _WalletWithdrawPageState._bodyColor,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  warningText,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: _WalletWithdrawPageState._bodyColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    height: 19.5 / 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),
                        _WithdrawConfirmPrimaryButton(
                          label: confirmLabel,
                          onTap: onConfirm,
                        ),
                        const SizedBox(height: 12),
                        _WithdrawConfirmSecondaryButton(
                          label: cancelLabel,
                          onTap: onCancel,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WithdrawConfirmValueRow extends StatelessWidget {
  const _WithdrawConfirmValueRow({
    required this.label,
    required this.value,
    this.valueColor = _WalletWithdrawPageState._titleColor,
    this.emphasized = false,
    this.valueFontSize = 16,
  });

  final String label;
  final String value;
  final Color valueColor;
  final bool emphasized;
  final double valueFontSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: emphasized
                  ? _WalletWithdrawPageState._titleColor
                  : _WalletWithdrawPageState._bodyColor,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              height: 20 / 14,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: valueFontSize,
            fontWeight: emphasized ? FontWeight.w700 : FontWeight.w400,
            height: 28 / valueFontSize,
          ),
        ),
      ],
    );
  }
}

class _WithdrawConfirmDashedDivider extends StatelessWidget {
  const _WithdrawConfirmDashedDivider();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const dashWidth = 4.0;
        const dashGap = 4.0;
        final dashCount = (constraints.maxWidth / (dashWidth + dashGap))
            .floor()
            .clamp(1, 200);

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(
            dashCount,
            (_) => Container(
              width: dashWidth,
              height: 1,
              color: const Color(0xFFC4C5D5),
            ),
          ),
        );
      },
    );
  }
}

class _WithdrawConfirmPrimaryButton extends StatelessWidget {
  const _WithdrawConfirmPrimaryButton({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFF1E40AF), Color(0xFF2170E4)],
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: Center(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  height: 24 / 16,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WithdrawConfirmSecondaryButton extends StatelessWidget {
  const _WithdrawConfirmSecondaryButton({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Ink(
          width: double.infinity,
          height: 52,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color.fromRGBO(196, 197, 213, 0.5)),
          ),
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                color: _WalletWithdrawPageState._bodyColor,
                fontSize: 16,
                fontWeight: FontWeight.w500,
                height: 24 / 16,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
