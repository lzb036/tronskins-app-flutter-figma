import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:tronskins_app/api/loginServer.dart';
import 'package:tronskins_app/common/theme/app_colors.dart';
import 'package:tronskins_app/common/theme/app_text_theme.dart';
import 'package:tronskins_app/common/utils/app_snackbar.dart';
import 'package:tronskins_app/common/widgets/settings_style_app_bar.dart';

class ScanLoginPage extends StatefulWidget {
  const ScanLoginPage({super.key});

  @override
  State<ScanLoginPage> createState() => _ScanLoginPageState();
}

class _ScanLoginPageState extends State<ScanLoginPage> {
  final ApiLoginServer _api = ApiLoginServer();
  final MobileScannerController _scannerController = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
  );

  bool _handling = false;
  bool _submitting = false;
  String? _pendingQrCode;

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handling || _pendingQrCode != null || _submitting) {
      return;
    }
    final rawValue = capture.barcodes.first.rawValue?.trim() ?? '';
    final qrCode = _extractQrCode(rawValue);
    if (qrCode == null || qrCode.isEmpty) {
      _handling = true;
      AppSnackbar.error('app.user.login.message.error'.tr);
      await Future<void>.delayed(const Duration(milliseconds: 800));
      _handling = false;
      return;
    }

    _handling = true;
    await _scannerController.stop();
    if (mounted) {
      setState(() {
        _pendingQrCode = qrCode;
      });
    }
    _handling = false;
  }

  Future<void> _confirmScan(String qrCode) async {
    setState(() {
      _submitting = true;
    });
    try {
      final res = await _api.loginScanConfirm(qrCode: qrCode);
      final data = res.datas;
      final status = data is Map<String, dynamic>
          ? data['status']
          : (data is Map ? data['status'] : null);
      final normalizedStatus = status is num
          ? status.toInt()
          : int.tryParse(status?.toString() ?? '');

      if (res.success && normalizedStatus == 2) {
        AppSnackbar.success('app.user.login.message.success'.tr);
        if (mounted) {
          Navigator.of(context).maybePop();
        }
        return;
      }

      final message = _resolveErrorMessage(res);
      AppSnackbar.error(message);
      await _resumeScanner();
    } catch (_) {
      AppSnackbar.error('app.user.login.message.error'.tr);
      await _resumeScanner();
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  Future<void> _cancelScan(String qrCode) async {
    setState(() {
      _submitting = true;
    });
    try {
      final res = await _api.cancelScanConfirm(qrCode: qrCode);
      if (res.success) {
        if (mounted) {
          Navigator.of(context).maybePop();
        }
        return;
      }
      AppSnackbar.error(_resolveErrorMessage(res));
      await _resumeScanner();
    } catch (_) {
      AppSnackbar.error('app.user.login.message.error'.tr);
      await _resumeScanner();
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  Future<void> _resumeScanner() async {
    if (!mounted) {
      return;
    }
    setState(() {
      _pendingQrCode = null;
      _handling = false;
    });
    await _scannerController.start();
  }

  String _resolveErrorMessage(dynamic res) {
    final dataText = res.datas?.toString().trim() ?? '';
    if (dataText.isNotEmpty) {
      return dataText;
    }
    final messageText = res.message?.toString().trim() ?? '';
    if (messageText.isNotEmpty) {
      return messageText;
    }
    return 'app.user.login.message.error'.tr;
  }

  String? _extractQrCode(String rawValue) {
    if (rawValue.isEmpty) {
      return null;
    }
    final match = RegExp(r'code=([^&]+)').firstMatch(rawValue);
    return match?.group(1);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appColors =
        theme.extension<AppColors>() ??
        (theme.brightness == Brightness.dark
            ? AppColors.dark
            : AppColors.light);
    final appTextTheme =
        theme.extension<AppTextTheme>() ??
        (theme.brightness == Brightness.dark
            ? AppTextTheme.dark()
            : AppTextTheme.light());

    return PopScope(
      canPop: _pendingQrCode == null || _submitting,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop || _pendingQrCode == null || _submitting) {
          return;
        }
        await _resumeScanner();
      },
      child: Scaffold(
        backgroundColor: appColors.scaffoldBackground,
        appBar: SettingsStyleAppBar(
          title: Text('app.user.login.scan_title'.tr),
        ),
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: _pendingQrCode == null
              ? _buildScannerView(appColors, appTextTheme)
              : _buildConfirmView(appColors, appTextTheme),
        ),
      ),
    );
  }

  Widget _buildScannerView(AppColors appColors, AppTextTheme appTextTheme) {
    return Stack(
      key: const ValueKey('scan'),
      fit: StackFit.expand,
      children: [
        MobileScanner(controller: _scannerController, onDetect: _onDetect),
        IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: appColors.info.withValues(alpha: 0.46),
            ),
          ),
        ),
        IgnorePointer(
          child: Center(
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                color: appColors.surface.withValues(alpha: 0.08),
                border: Border.all(
                  color: appColors.primary.withValues(alpha: 0.95),
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: appColors.primary.withValues(alpha: 0.18),
                    blurRadius: 24,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          left: 24,
          right: 24,
          bottom: 36,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: appColors.surface.withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: appColors.primary.withValues(alpha: 0.16),
              ),
              boxShadow: [
                BoxShadow(
                  color: appColors.info.withValues(alpha: 0.12),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Text(
              'app.user.login.scan_prompt'.tr,
              textAlign: TextAlign.center,
              style: appTextTheme.bodyMedium.copyWith(
                color: appColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConfirmView(AppColors appColors, AppTextTheme appTextTheme) {
    return Container(
      key: const ValueKey('confirm'),
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            appColors.scaffoldBackground,
            appColors.surfaceVariant,
            appColors.primary.withValues(alpha: 0.1),
          ],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          child: Column(
            children: [
              const Spacer(),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: appColors.surface.withValues(alpha: 0.96),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: appColors.border.withValues(alpha: 0.35),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: appColors.info.withValues(alpha: 0.08),
                      blurRadius: 36,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _buildDesktopPreview(appColors),
                    const SizedBox(height: 22),
                    Text(
                      'app.user.login.browser_confirm'.tr,
                      textAlign: TextAlign.center,
                      style: appTextTheme.titleLarge.copyWith(
                        color: appColors.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _submitting
                                ? null
                                : () => _cancelScan(_pendingQrCode!),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: appColors.primary,
                              backgroundColor: appColors.surfaceVariant,
                              side: BorderSide(
                                color: appColors.primary.withValues(
                                  alpha: 0.45,
                                ),
                              ),
                              minimumSize: const Size.fromHeight(48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Text('app.common.cancel'.tr),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: _submitting
                                ? null
                                : () => _confirmScan(_pendingQrCode!),
                            style: FilledButton.styleFrom(
                              foregroundColor: appColors.onPrimary,
                              backgroundColor: appColors.primary,
                              disabledBackgroundColor: appColors.primary
                                  .withValues(alpha: 0.58),
                              minimumSize: const Size.fromHeight(48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: _submitting
                                ? SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: appColors.onPrimary,
                                    ),
                                  )
                                : Text('app.user.login.title'.tr),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopPreview(AppColors appColors) {
    return SizedBox(
      width: 170,
      height: 132,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: 0,
            child: Container(
              width: 152,
              height: 98,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    appColors.primary.withValues(alpha: 0.18),
                    appColors.surfaceVariant,
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: appColors.primary.withValues(alpha: 0.26),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: appColors.primary.withValues(alpha: 0.12),
                    child: Icon(
                      Icons.desktop_windows_rounded,
                      color: appColors.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'PC',
                    style: TextStyle(
                      color: appColors.primary,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 18,
            child: Container(
              width: 44,
              height: 10,
              decoration: BoxDecoration(
                color: appColors.border,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          Positioned(
            bottom: 8,
            child: Container(
              width: 78,
              height: 8,
              decoration: BoxDecoration(
                color: appColors.border.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
