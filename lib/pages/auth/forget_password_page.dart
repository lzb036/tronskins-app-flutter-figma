import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:tronskins_app/api/loginServer.dart';
import 'package:tronskins_app/common/http/model/base_response.dart';
import 'package:tronskins_app/common/utils/app_snackbar.dart';
import 'package:tronskins_app/common/widgets/auth_floating_input_field.dart';
import 'package:tronskins_app/common/widgets/app_request_loading_overlay.dart';
import 'package:tronskins_app/pages/auth/auth_visual_style.dart';

class ForgetPasswordPage extends StatefulWidget {
  const ForgetPasswordPage({super.key});

  @override
  State<ForgetPasswordPage> createState() => _ForgetPasswordPageState();
}

class _ForgetPasswordPageState extends State<ForgetPasswordPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();

  Timer? _timer;
  int _countdown = 0;
  bool _submitting = false;
  bool _sending = false;
  bool _emailTouched = false;
  bool _codeTouched = false;
  String? _emailError;
  String? _codeError;

  @override
  void dispose() {
    _timer?.cancel();
    _emailController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _countdown = 300);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown <= 1) {
        timer.cancel();
        setState(() => _countdown = 0);
      } else {
        setState(() => _countdown -= 1);
      }
    });
  }

  String? _extractMessage(dynamic datas) {
    if (datas is String && datas.trim().isNotEmpty) {
      return datas;
    }
    if (datas is Map) {
      for (final key in ['message', 'msg', 'error', 'detail', 'desc']) {
        final value = datas[key];
        if (value is String && value.trim().isNotEmpty) {
          return value;
        }
      }
    }
    return null;
  }

  String _resolveMessage(BaseHttpResponse<dynamic> result, String fallbackKey) {
    if (result.message.isNotEmpty) {
      return result.message;
    }
    final dataMessage = _extractMessage(result.datas);
    if (dataMessage != null) {
      return dataMessage;
    }
    return fallbackKey.tr;
  }

  void _showError(String message) {
    AppSnackbar.error(message);
  }

  void _showSuccess(String message) {
    AppSnackbar.success(message);
  }

  String? _emailErrorText(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return 'app.user.login.message.email_error'.tr;
    }
    if (!GetUtils.isEmail(trimmed)) {
      return 'app.user.login.message.email_format_error'.tr;
    }
    return null;
  }

  String? _codeErrorText(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return 'app.user.login.message.code_error'.tr;
    }
    return null;
  }

  void _onEmailChanged(String value) {
    final error = _emailErrorText(value);
    if (!_emailTouched || error != _emailError) {
      setState(() {
        _emailTouched = true;
        _emailError = error;
      });
    }
  }

  void _onCodeChanged(String value) {
    final error = _codeErrorText(value);
    if (!_codeTouched || error != _codeError) {
      setState(() {
        _codeTouched = true;
        _codeError = error;
      });
    }
  }

  bool _validateEmail() {
    final error = _emailErrorText(_emailController.text);
    setState(() {
      _emailTouched = true;
      _emailError = error;
    });
    return error == null;
  }

  bool _validateResetInputs() {
    final emailError = _emailErrorText(_emailController.text);
    final codeError = _codeErrorText(_codeController.text);
    setState(() {
      _emailTouched = true;
      _codeTouched = true;
      _emailError = emailError;
      _codeError = codeError;
    });
    return emailError == null && codeError == null;
  }

  Future<void> _sendCode() async {
    if (_sending || _countdown > 0) return;
    if (!_validateEmail()) {
      return;
    }
    final email = _emailController.text.trim();

    setState(() => _sending = true);
    try {
      final verify = await ApiLoginServer().verifyResetEmail(email: email);
      if (!verify.success) {
        _showError(_resolveMessage(verify, 'app.user.login.message.error'));
        return;
      }

      final result = await ApiLoginServer().sendEmailCodeBySubmit(
        email: email,
        purpose: 3,
      );
      if (result.success) {
        _startCountdown();
        _showSuccess('app.user.login.message.send_to_email'.tr);
      } else {
        _showError(_resolveMessage(result, 'app.user.login.message.error'));
      }
    } catch (_) {
      _showError('app.user.login.message.error'.tr);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _resetPassword() async {
    if (_submitting) return;
    if (!_validateResetInputs()) {
      return;
    }
    final email = _emailController.text.trim();
    final code = _codeController.text.trim();

    setState(() => _submitting = true);
    AppRequestLoading.show();
    try {
      final result = await ApiLoginServer().resetPassword(
        email: email,
        captcha: code,
      );
      if (result.success) {
        _showSuccess('app.user.login.message.send_to_email'.tr);
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) {
            Navigator.of(context).maybePop();
          }
        });
      } else {
        _showError(_resolveMessage(result, 'app.user.login.message.error'));
      }
    } catch (_) {
      _showError('app.user.login.message.error'.tr);
    } finally {
      AppRequestLoading.hide();
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final resendLabel = _countdown > 0
        ? '${'app.user.login.reacquire'.tr}(${_countdown}s)'
        : 'app.user.login.reacquire'.tr;

    return Scaffold(
      backgroundColor: AuthVisualStyle.background,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: AuthVisualStyle.screenGradient,
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 16),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: IconButton(
                            icon: const Icon(
                              Icons.arrow_back_ios_new,
                              color: AuthVisualStyle.text,
                              size: 20,
                            ),
                            onPressed: () => Navigator.of(context).maybePop(),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ),
                        const Spacer(flex: 2),
                        AuthCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AuthPageHeader(
                                title: 'app.user.login.reset_password'.tr,
                                subtitle:
                                    'app.user.login.forget_password_desc'.tr,
                              ),
                              const SizedBox(height: 28),
                              AuthFloatingInputField(
                                controller: _emailController,
                                label: 'app.user.login.email_placeholder'.tr,
                                keyboardType: TextInputType.emailAddress,
                                prefixIcon: Icons.email_outlined,
                                fillColor: AuthVisualStyle.inputFill,
                                textColor: AuthVisualStyle.text,
                                hintColor: AuthVisualStyle.mutedText,
                                focusColor: AuthVisualStyle.primary,
                                onChanged: _onEmailChanged,
                                error: _emailTouched ? _emailError : null,
                              ),
                              const SizedBox(height: 18),
                              AuthFloatingInputField(
                                controller: _codeController,
                                label: 'app.user.login.enter_captcha'.tr,
                                keyboardType: TextInputType.number,
                                prefixIcon: Icons.security_outlined,
                                maxLength: 6,
                                fillColor: AuthVisualStyle.inputFill,
                                textColor: AuthVisualStyle.text,
                                hintColor: AuthVisualStyle.mutedText,
                                focusColor: AuthVisualStyle.primary,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                onChanged: _onCodeChanged,
                                error: _codeTouched ? _codeError : null,
                                suffix: AuthInlineActionButton(
                                  label: resendLabel,
                                  onPressed: _countdown > 0 || _sending
                                      ? null
                                      : _sendCode,
                                ),
                              ),
                              const SizedBox(height: 30),
                              AuthPrimaryButton(
                                label: 'app.user.login.reset_password'.tr,
                                loading: _submitting,
                                onPressed: _submitting ? null : _resetPassword,
                              ),
                            ],
                          ),
                        ),
                        const Spacer(flex: 2),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
