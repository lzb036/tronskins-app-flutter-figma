import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:tronskins_app/api/model/entity/user/user_info_entity.dart';
import 'package:tronskins_app/common/http/model/base_response.dart';
import 'package:tronskins_app/common/storage/server_storage.dart';
import 'package:tronskins_app/common/storage/twofa_storage.dart';
import 'package:tronskins_app/common/storage/user_storage.dart';
import 'package:tronskins_app/common/utils/app_snackbar.dart';
import 'package:tronskins_app/common/widgets/figma_confirmation_dialog.dart';
import 'package:tronskins_app/common/widgets/glass_notice_dialog.dart';
import 'package:tronskins_app/common/widgets/settings_style_app_bar.dart';
import 'package:tronskins_app/controllers/auth/twofa_controller.dart';
import 'package:tronskins_app/controllers/user/user_controller.dart';

const String _kFigmaSteamLogoUrl =
    'https://www.figma.com/api/mcp/asset/49989b8b-c7e9-43d3-a638-2934a25e1507';
const String _kFigmaDiscordLogoUrl =
    'https://www.figma.com/api/mcp/asset/744a86c2-b032-423e-a05d-968f0966cd51';
const String _kFigmaGitHubLogoUrl =
    'https://www.figma.com/api/mcp/asset/1bc428e5-8cbd-479a-b314-8122aaa4602e';

class TwoFaTokenPage extends StatefulWidget {
  const TwoFaTokenPage({super.key});

  @override
  State<TwoFaTokenPage> createState() => _TwoFaTokenPageState();
}

class _TwoFaTokenPageState extends State<TwoFaTokenPage> {
  final TwoFactorController controller = Get.isRegistered<TwoFactorController>()
      ? Get.find<TwoFactorController>()
      : Get.put(TwoFactorController());
  final UserController userController = Get.find<UserController>();
  bool _manageOtherTokens = false;
  TwoFactorToken? _selectedToken;

  @override
  void initState() {
    super.initState();
    controller.loadTokens();
    if (userController.isLoggedIn.value || UserStorage.getUserInfo() != null) {
      controller.refreshStatus();
    }
  }

  String _normalizeText(String? value) {
    return value?.trim().toLowerCase() ?? '';
  }

  String _normalizeServer(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return '';
    }
    return trimmed.endsWith('/') ? trimmed : '$trimmed/';
  }

  bool _matchesServer(
    TwoFactorToken token,
    String normalizedServer, {
    bool allowLegacy = false,
  }) {
    final tokenServer = _normalizeServer(token.server);
    if (tokenServer.isEmpty) {
      return allowLegacy;
    }
    return tokenServer == normalizedServer;
  }

  bool _sameTokenIdentity(TwoFactorToken left, TwoFactorToken right) {
    return left.userId.trim() == right.userId.trim() &&
        _normalizeText(left.appUse) == _normalizeText(right.appUse) &&
        _normalizeServer(left.server) == _normalizeServer(right.server);
  }

  String _currentServer() {
    return ServerStorage.getServer();
  }

  String _otherTokensTitle() {
    return 'Other User Tokens';
  }

  String _manageLabel() {
    return 'Manage';
  }

  String _doneLabel() {
    return 'Done';
  }

  bool get _isChineseLocale =>
      (Get.locale?.languageCode ?? '').toLowerCase().startsWith('zh');

  String _vaultTitle() {
    return '2FA';
  }

  String _footerTip() {
    return 'Tokens refresh every 30 seconds. Please ensure\n'
        'device time is synced for accurate generation.';
  }

  Iterable<String> _currentUserEmails(UserInfoEntity? currentUser) sync* {
    if (currentUser == null) {
      return;
    }
    final values = <String>{
      _normalizeText(currentUser.safeTokenName),
      _normalizeText(currentUser.showEmail),
    }..removeWhere((item) => item.isEmpty);
    yield* values;
  }

  TwoFactorToken? _findCurrentUserSyncedToken(UserInfoEntity? currentUser) {
    if (currentUser == null) {
      return null;
    }

    final currentUserId = currentUser.id?.trim() ?? '';
    final currentAppUse = _normalizeText(currentUser.appUse);
    final currentServer = _normalizeServer(_currentServer());

    // 精确匹配：userId + appUse + server
    for (final token in controller.tokens) {
      if (token.secret.trim().isEmpty) {
        continue;
      }
      if (token.userId.trim() == currentUserId &&
          _normalizeText(token.appUse) == currentAppUse &&
          _matchesServer(token, currentServer)) {
        return token;
      }
    }

    // 如果 currentAppUse 为空，尝试只匹配 userId + server
    if (currentAppUse.isEmpty && currentUserId.isNotEmpty) {
      final userServerMatches = controller.tokens
          .where((token) {
            return token.secret.trim().isNotEmpty &&
                token.userId.trim() == currentUserId &&
                _matchesServer(token, currentServer);
          })
          .toList(growable: false);
      if (userServerMatches.length == 1) {
        return userServerMatches.first;
      }
    }

    if (currentServer.isNotEmpty) {
      for (final token in controller.tokens) {
        if (token.secret.trim().isEmpty) {
          continue;
        }
        if (token.userId.trim() == currentUserId &&
            _normalizeText(token.appUse) == currentAppUse &&
            _matchesServer(token, currentServer, allowLegacy: true)) {
          return token;
        }
      }
    }

    final emails = _currentUserEmails(currentUser).toList(growable: false);
    if (emails.isEmpty) {
      return null;
    }

    for (final email in emails) {
      final emailMatches = controller.tokens
          .where((token) {
            return token.secret.trim().isNotEmpty &&
                _normalizeText(token.showEmail) == email;
          })
          .toList(growable: false);
      if (emailMatches.isEmpty) {
        continue;
      }

      final exactServerMatches = emailMatches
          .where((token) => _matchesServer(token, currentServer))
          .toList(growable: false);
      if (currentAppUse.isNotEmpty) {
        final appUseMatches = exactServerMatches
            .where((token) => _normalizeText(token.appUse) == currentAppUse)
            .toList(growable: false);
        if (appUseMatches.length == 1) {
          return appUseMatches.first;
        }
      } else if (exactServerMatches.length == 1) {
        return exactServerMatches.first;
      }

      final legacyServerMatches = emailMatches
          .where((token) {
            return _matchesServer(token, currentServer, allowLegacy: true);
          })
          .toList(growable: false);
      if (currentAppUse.isNotEmpty) {
        final appUseMatches = legacyServerMatches
            .where((token) => _normalizeText(token.appUse) == currentAppUse)
            .toList(growable: false);
        if (appUseMatches.length == 1) {
          return appUseMatches.first;
        }
      } else if (legacyServerMatches.length == 1) {
        return legacyServerMatches.first;
      }
    }

    return null;
  }

  bool _hasCurrentUserToken(UserInfoEntity? currentUser) {
    return currentUser != null &&
        _findCurrentUserSyncedToken(currentUser) != null;
  }

  TwoFactorToken? _findSelectedToken(List<TwoFactorToken> tokens) {
    final selected = _selectedToken;
    if (selected == null) {
      return null;
    }
    for (final token in tokens) {
      if (_sameTokenIdentity(token, selected)) {
        return token;
      }
    }
    return null;
  }

  TwoFactorToken? _resolvePrimaryToken({
    required List<TwoFactorToken> boundTokens,
    required TwoFactorToken? currentSyncedToken,
  }) {
    final selected = _findSelectedToken(boundTokens);
    if (selected != null) {
      return selected;
    }
    return currentSyncedToken;
  }

  void _selectToken(TwoFactorToken token) {
    if (_selectedToken != null && _sameTokenIdentity(_selectedToken!, token)) {
      return;
    }
    setState(() {
      _selectedToken = token;
      _manageOtherTokens = false;
    });
  }

  Future<void> _copyCode(String code) async {
    if (code.isEmpty) {
      return;
    }
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    await showCopySuccessNoticeDialog(
      context,
      duration: const Duration(milliseconds: 1200),
    );
  }

  Future<void> _confirmDelete(TwoFactorToken token) async {
    final appLabel = _tokenDisplayApp(token);
    final serverLabel = token.server.trim().isEmpty
        ? '--'
        : _tokenServerLabel(token.server);
    final confirm = await showFigmaModal<bool>(
      context: context,
      child: FigmaConfirmationDialog(
        icon: Icons.delete_outline_rounded,
        iconColor: const Color(0xFFE11D48),
        iconBackgroundColor: const Color.fromRGBO(225, 29, 72, 0.10),
        accentColor: const Color(0xFFE11D48),
        title: _isChineseLocale ? '删除 2FA 条目' : 'Delete 2FA Token',
        message: _isChineseLocale
            ? '删除后，此设备将无法继续生成该条目的验证码。'
            : 'After deletion, this device can no longer generate codes for this token.',
        highlightText:
            '${_tokenDisplayEmail(token)}\n($appLabel) · $serverLabel',
        primaryLabel: 'app.common.delete'.tr,
        secondaryLabel: 'app.common.cancel'.tr,
        onPrimary: () => Navigator.of(context).pop(true),
        onSecondary: () => Navigator.of(context).pop(false),
      ),
    );
    if (confirm == true) {
      if (_selectedToken != null &&
          _sameTokenIdentity(_selectedToken!, token)) {
        setState(() => _selectedToken = null);
      }
      await controller.deleteToken(token);
    }
  }

  Future<void> _openBindDialog() async {
    final email = controller.email.value ?? '';
    if (email.isEmpty) {
      await controller.refreshStatus();
    }
    if (controller.isBound.value != true) {
      AppSnackbar.info('app.user.guard.open_2fa_first'.tr);
      return;
    }
    final emailValue = controller.email.value ?? '';
    if (emailValue.isEmpty) {
      AppSnackbar.info('app.user.guard.open_2fa_first'.tr);
      return;
    }
    if (!mounted) {
      return;
    }
    await showFigmaModal<void>(
      context: context,
      barrierDismissible: true,
      child: _TwoFaBindDialog(email: emailValue, controller: controller),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final loggedIn = userController.isLoggedIn.value;
      final currentUser =
          userController.user.value ?? UserStorage.getUserInfo();
      final _ = controller.tick.value;
      controller.tokens.length; // 订阅 tokens 变化以触发重建
      final remaining = controller.remainingSeconds();
      final progress = remaining / 30;
      final hasCurrentUserToken = _hasCurrentUserToken(currentUser);
      final currentSyncedToken = _findCurrentUserSyncedToken(currentUser);
      final boundTokens = controller.tokens
          .where((token) => token.secret.trim().isNotEmpty)
          .toList(growable: false);
      final primaryToken = _resolvePrimaryToken(
        boundTokens: boundTokens,
        currentSyncedToken: currentSyncedToken,
      );
      final hasPrimaryToken =
          primaryToken != null && primaryToken.secret.trim().isNotEmpty;
      final visibleTokenList = boundTokens
          .where((token) {
            if (currentSyncedToken == null) {
              return true;
            }
            return !_sameTokenIdentity(token, currentSyncedToken);
          })
          .toList(growable: false);
      final showManageButton = visibleTokenList.isNotEmpty;
      final isManageMode = showManageButton && _manageOtherTokens;
      final hasVisibleContent = hasPrimaryToken || visibleTokenList.isNotEmpty;

      return Scaffold(
        backgroundColor: const Color(0xFFF7F9FB),
        body: Column(
          children: [
            _VaultHeader(
              title: _vaultTitle(),
              trailingLabel: hasPrimaryToken
                  ? _tokenDisplayApp(primaryToken)
                  : null,
              showAddButton: loggedIn && !hasCurrentUserToken,
              onBack: () => Navigator.of(context).maybePop(),
              onAdd: _openBindDialog,
            ),
            Expanded(
              child: !hasVisibleContent
                  ? const _TwoFaEmptyState()
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final contentWidth = constraints.maxWidth.clamp(
                          0.0,
                          672.0,
                        );
                        return SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(24, 24, 24, 36),
                          child: Center(
                            child: SizedBox(
                              width: contentWidth,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (hasPrimaryToken)
                                    _VaultPrimaryTokenCard(
                                      token: primaryToken,
                                      code: controller.codeForToken(
                                        primaryToken,
                                      ),
                                      progress: progress,
                                      remaining: remaining,
                                      onCopy: _copyCode,
                                    ),
                                  if (hasPrimaryToken &&
                                      visibleTokenList.isNotEmpty)
                                    const SizedBox(height: 40),
                                  if (visibleTokenList.isNotEmpty)
                                    _VaultOtherTokensSection(
                                      title: _otherTokensTitle(),
                                      manageText: _manageLabel(),
                                      doneText: _doneLabel(),
                                      isManageMode: isManageMode,
                                      onToggleManage: () {
                                        setState(() {
                                          _manageOtherTokens =
                                              !_manageOtherTokens;
                                        });
                                      },
                                      tokens: visibleTokenList,
                                      selectedToken: primaryToken,
                                      onSelect: _selectToken,
                                      onDelete: _confirmDelete,
                                    ),
                                  const SizedBox(height: 20),
                                  _VaultFooter(tips: _footerTip()),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      );
    });
  }
}

class _TwoFaEmptyState extends StatelessWidget {
  const _TwoFaEmptyState();

  static const Color _brandColor = Color(0xFF2F5BFF);
  static const Color _brandDark = Color(0xFF1939B7);
  static const Color _accentColor = Color(0xFF7CA4FF);
  static const Color _textSecondary = Color(0xFF64748B);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 112,
              height: 112,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(34),
                border: Border.all(color: const Color(0xFFDCE7FF), width: 1.2),
                boxShadow: const [
                  BoxShadow(
                    color: Color.fromRGBO(47, 91, 255, 0.10),
                    blurRadius: 32,
                    offset: Offset(0, 18),
                    spreadRadius: -16,
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned(
                    top: 18,
                    right: 18,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: _accentColor.withValues(alpha: 0.24),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 18,
                    left: 18,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: _brandColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFFE9F0FF), Color(0xFFD5E3FF)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [_brandColor, _brandDark],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [
                        BoxShadow(
                          color: Color.fromRGBO(47, 91, 255, 0.26),
                          blurRadius: 18,
                          offset: Offset(0, 10),
                          spreadRadius: -8,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.verified_user_rounded,
                      size: 22,
                      color: Colors.white,
                    ),
                  ),
                  Positioned(
                    bottom: 26,
                    right: 26,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(
                          color: _brandColor.withValues(alpha: 0.12),
                        ),
                      ),
                      child: const Icon(
                        Icons.add_rounded,
                        size: 15,
                        color: _brandColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'app.common.no_data'.tr,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: const Color(0xFF191C1E),
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'app.user.guard.open_2fa_first'.tr,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 20 / 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TwoFaBindDialog extends StatefulWidget {
  const _TwoFaBindDialog({required this.email, required this.controller});

  final String email;
  final TwoFactorController controller;

  @override
  State<_TwoFaBindDialog> createState() => _TwoFaBindDialogState();
}

class _TwoFaBindDialogState extends State<_TwoFaBindDialog> {
  static const Color _brandColor = Color(0xFF1E40AF);
  static const Color _brandDark = Color(0xFF3B82F6);
  static const Color _footerAccentColor = Color(0xFF0058BE);
  static const Color _surfaceColor = Colors.white;
  static const Color _surfaceMuted = Color(0xFFF2F4F6);
  static const Color _surfaceStrong = Color(0xFFE6E8EA);
  static const Color _footerTrackColor = Color(0xFFECEEF0);
  static const Color _strokeColor = Color(0x33C4C5D5);
  static const Color _titleColor = Color(0xFF191C1E);
  static const Color _bodyColor = Color(0xFF444653);
  static const Color _labelColor = Color(0xFF757684);
  static const Color _hintColor = Color(0x80757684);
  static const Color _dangerColor = Color(0xFFE25555);

  final TextEditingController _codeController = TextEditingController();
  Timer? _timer;
  int _countdown = 0;
  bool _codeTouched = false;
  bool _isSyncing = false;
  String? _codeError;

  @override
  void dispose() {
    _timer?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    AppSnackbar.error(message);
  }

  void _showSuccess(String message) {
    AppSnackbar.success(message);
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

  Future<void> _startCountdown() async {
    setState(() => _countdown = 60);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_countdown <= 1) {
        t.cancel();
        if (mounted) {
          setState(() => _countdown = 0);
        }
      } else {
        if (mounted) {
          setState(() => _countdown -= 1);
        }
      }
    });
  }

  String? _codeErrorText(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return 'app.user.login.message.code_error'.tr;
    }
    return null;
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

  bool _validateCode() {
    final error = _codeErrorText(_codeController.text);
    setState(() {
      _codeTouched = true;
      _codeError = error;
    });
    return error == null;
  }

  bool get _isZhLocale =>
      (Get.locale?.languageCode ?? '').toLowerCase().startsWith('zh');

  String get _dialogTitle => 'app.user.guard.text'.tr;

  String get _sectionLabel => _isZhLocale ? '验证码' : 'VERIFICATION CODE';

  String get _codeHintText =>
      _isZhLocale ? '请输入验证码' : 'Enter verification code';

  String get _sendIdleLabel => _isZhLocale ? '发送' : 'Send';

  String get _syncNowLabel => _isZhLocale ? '立即同步' : 'Sync Now';

  @override
  Widget build(BuildContext context) {
    final sendLabel = _countdown == 0 ? _sendIdleLabel : '${_countdown}s';
    final canSendCaptcha = _countdown == 0 && !_isSyncing;

    Future<void> sendCaptcha() async {
      if (!canSendCaptcha) {
        return;
      }
      try {
        final res = await widget.controller.sendEmailCode();
        if (res.success) {
          _showSuccess('app.user.guard.captcha_been_sent'.tr);
          await _startCountdown();
        } else {
          _showError(
            _resolveMessage(res, 'app.user.guard.captcha_send_failed'),
          );
        }
      } catch (_) {
        _showError('app.user.guard.captcha_send_failed'.tr);
      }
    }

    Future<void> confirmSync() async {
      if (_isSyncing) {
        return;
      }
      if (!_validateCode()) {
        return;
      }
      final code = _codeController.text.trim();
      setState(() => _isSyncing = true);
      var shouldResetLoading = true;
      try {
        final res = await widget.controller.syncToken(code);
        if (!mounted) {
          return;
        }
        if (res.success) {
          shouldResetLoading = false;
          if (!context.mounted) {
            return;
          }
          Navigator.of(context).pop();
          _showSuccess('app.user.guard.sync_success'.tr);
          return;
        }
        _showError(_resolveMessage(res, 'app.user.guard.sync_failed'));
      } catch (_) {
        if (mounted) {
          _showError('app.user.guard.sync_failed'.tr);
        }
      } finally {
        if (mounted && shouldResetLoading) {
          setState(() => _isSyncing = false);
        }
      }
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 372),
      child: Material(
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: _surfaceColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(
                color: Color.fromRGBO(0, 0, 0, 0.25),
                blurRadius: 50,
                offset: Offset(0, 25),
                spreadRadius: -12,
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      _dialogTitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: _titleColor,
                        fontSize: 24,
                        height: 32 / 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.email,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: _bodyColor,
                        fontSize: 16,
                        height: 26 / 16,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      _sectionLabel,
                      style: const TextStyle(
                        color: _labelColor,
                        fontSize: 14,
                        height: 20 / 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.4,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      height: 58,
                      decoration: BoxDecoration(
                        color: _surfaceMuted,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _strokeColor),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _codeController,
                              onChanged: _onCodeChanged,
                              keyboardType: TextInputType.number,
                              textAlignVertical: TextAlignVertical.center,
                              style: const TextStyle(
                                color: _titleColor,
                                fontSize: 14,
                                height: 20 / 14,
                                fontWeight: FontWeight.w500,
                              ),
                              decoration: InputDecoration(
                                hintText: _codeHintText,
                                hintStyle: const TextStyle(
                                  color: _hintColor,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w400,
                                ),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 18,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 72,
                            height: 58,
                            child: FilledButton(
                              onPressed: canSendCaptcha ? sendCaptcha : null,
                              style: FilledButton.styleFrom(
                                backgroundColor: _brandColor,
                                disabledBackgroundColor: const Color(
                                  0xFF8AA9F2,
                                ),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.only(
                                    topLeft: Radius.circular(4),
                                    bottomLeft: Radius.circular(4),
                                    topRight: Radius.circular(8),
                                    bottomRight: Radius.circular(8),
                                  ),
                                ),
                              ),
                              child: Text(
                                sendLabel,
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  height: 16 / 15,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_codeTouched && _codeError != null) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            size: 15,
                            color: _dangerColor,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _codeError!,
                              style: const TextStyle(
                                color: _dangerColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                height: 16 / 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 32),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [_brandColor, _brandDark],
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: FilledButton(
                        onPressed: _isSyncing ? null : confirmSync,
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          disabledBackgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          disabledForegroundColor: Colors.white,
                          elevation: 0,
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: _isSyncing
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                _syncNowLabel,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  height: 24 / 16,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _isSyncing
                          ? null
                          : () => Navigator.of(context).maybePop(),
                      style: FilledButton.styleFrom(
                        backgroundColor: _surfaceStrong,
                        foregroundColor: _bodyColor,
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'app.common.cancel'.tr,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          height: 24 / 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 4,
                child: Row(
                  children: const [
                    Expanded(child: ColoredBox(color: _footerAccentColor)),
                    Expanded(
                      flex: 3,
                      child: ColoredBox(color: _footerTrackColor),
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
}

String _tokenDisplayEmail(TwoFactorToken token) {
  final email = token.showEmail.trim();
  if (email.isNotEmpty) {
    return email;
  }
  final userId = token.userId.trim();
  return userId.isEmpty ? '--' : userId;
}

String _tokenDisplayApp(TwoFactorToken token) {
  final app = token.appUse.trim();
  return app.isEmpty ? '2FA' : app;
}

String _tokenServerLabel(String server) {
  final normalized = server.trim();
  if (normalized.isEmpty) {
    return '--';
  }
  final uri = Uri.tryParse(normalized);
  final host = uri?.host ?? '';
  if (host.isEmpty) {
    return normalized;
  }
  if ((uri?.path ?? '').isEmpty || uri?.path == '/') {
    return host;
  }
  return '$host${uri?.path}';
}

String _displayCodeWithGap(String value) {
  final normalized = value.replaceAll(' ', '');
  if (normalized.length != 6) {
    return value;
  }
  return '${normalized.substring(0, 3)} ${normalized.substring(3)}';
}

String? _logoUrlForApp(String appUse) {
  final app = appUse.trim().toLowerCase();
  if (app.contains('steam')) {
    return _kFigmaSteamLogoUrl;
  }
  if (app.contains('discord')) {
    return _kFigmaDiscordLogoUrl;
  }
  if (app.contains('github')) {
    return _kFigmaGitHubLogoUrl;
  }
  return null;
}

bool _sameTokenIdentityForDisplay(TwoFactorToken left, TwoFactorToken right) {
  String normalizeText(String? value) => value?.trim().toLowerCase() ?? '';
  String normalizeServer(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return '';
    }
    return trimmed.endsWith('/') ? trimmed : '$trimmed/';
  }

  return left.userId.trim() == right.userId.trim() &&
      normalizeText(left.appUse) == normalizeText(right.appUse) &&
      normalizeServer(left.server) == normalizeServer(right.server);
}

class _VaultHeader extends StatelessWidget {
  const _VaultHeader({
    required this.title,
    this.trailingLabel,
    required this.showAddButton,
    required this.onBack,
    required this.onAdd,
  });

  final String title;
  final String? trailingLabel;
  final bool showAddButton;
  final VoidCallback onBack;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return SettingsStyleInlineTopBar(
      title: title,
      includeTopInset: true,
      onBack: onBack,
      actions: [
        if (trailingLabel != null && trailingLabel!.trim().isNotEmpty)
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 168),
            child: Text(
              trailingLabel!,
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF191C1E),
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.5,
              ),
            ),
          )
        else if (showAddButton)
          InkWell(
            onTap: onAdd,
            borderRadius: BorderRadius.circular(12),
            child: const Padding(
              padding: EdgeInsets.all(6),
              child: Icon(
                Icons.add_circle_outline_rounded,
                size: 20,
                color: Color(0xFF3B82F6),
              ),
            ),
          ),
      ],
    );
  }
}

class _VaultPrimaryTokenCard extends StatelessWidget {
  const _VaultPrimaryTokenCard({
    required this.token,
    required this.code,
    required this.progress,
    required this.remaining,
    required this.onCopy,
  });

  final TwoFactorToken token;
  final String code;
  final double progress;
  final int remaining;
  final ValueChanged<String> onCopy;

  @override
  Widget build(BuildContext context) {
    final displayCode = _displayCodeWithGap(code.trim());
    final serverLabel = token.server.trim().isEmpty
        ? '--'
        : _tokenServerLabel(token.server);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.02),
            blurRadius: 20,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
      child: Column(
        children: [
          Text(
            _tokenDisplayEmail(token),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF444653),
              fontSize: 14,
              fontWeight: FontWeight.w500,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            serverLabel,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 12,
              fontWeight: FontWeight.w400,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: code.trim().isEmpty ? null : () => onCopy(code.trim()),
            behavior: HitTestBehavior.opaque,
            child: Text(
              displayCode,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF191C1E),
                fontSize: 32,
                fontWeight: FontWeight.w700,
                height: 1.5,
                letterSpacing: 6.4,
              ),
            ),
          ),
          const SizedBox(height: 24),
          _VaultCountdown(progress: progress, remaining: remaining),
        ],
      ),
    );
  }
}

class _VaultOtherTokensSection extends StatelessWidget {
  const _VaultOtherTokensSection({
    required this.title,
    required this.manageText,
    required this.doneText,
    required this.isManageMode,
    required this.onToggleManage,
    required this.tokens,
    this.selectedToken,
    required this.onSelect,
    required this.onDelete,
  });

  final String title;
  final String manageText;
  final String doneText;
  final bool isManageMode;
  final VoidCallback onToggleManage;
  final List<TwoFactorToken> tokens;
  final TwoFactorToken? selectedToken;
  final ValueChanged<TwoFactorToken>? onSelect;
  final Future<void> Function(TwoFactorToken token) onDelete;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF191C1E),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  height: 1.5,
                ),
              ),
            ),
            TextButton(
              onPressed: onToggleManage,
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF00288E),
                padding: EdgeInsets.zero,
                minimumSize: const Size(56, 24),
              ),
              child: Text(
                isManageMode ? doneText : manageText,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...tokens.map((token) {
          final selected =
              selectedToken != null &&
              _sameTokenIdentityForDisplay(token, selectedToken!);
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _VaultOtherTokenItem(
              token: token,
              manageMode: isManageMode,
              selected: selected,
              onSelect: onSelect == null ? null : () => onSelect!(token),
              onDelete: () => onDelete(token),
            ),
          );
        }),
      ],
    );
  }
}

class _VaultOtherTokenItem extends StatelessWidget {
  const _VaultOtherTokenItem({
    required this.token,
    required this.manageMode,
    required this.selected,
    this.onSelect,
    required this.onDelete,
  });

  final TwoFactorToken token;
  final bool manageMode;
  final bool selected;
  final VoidCallback? onSelect;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final appLabel = _tokenDisplayApp(token);
    final logoUrl = _logoUrlForApp(appLabel);
    final subtitle = token.server.trim().isEmpty
        ? '($appLabel)'
        : '($appLabel) · ${_tokenServerLabel(token.server)}';

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: manageMode ? null : onSelect,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xFF1E40AF)
                      : const Color(0xFFECEEF0),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: selected
                      ? const [
                          BoxShadow(
                            color: Color.fromRGBO(30, 64, 175, 0.22),
                            blurRadius: 14,
                            offset: Offset(0, 6),
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: logoUrl == null
                      ? Icon(
                          Icons.verified_user_outlined,
                          size: 22,
                          color: selected
                              ? Colors.white
                              : const Color(0xFF64748B),
                        )
                      : Image.network(
                          logoUrl,
                          width: 24,
                          height: 24,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) {
                            return Icon(
                              Icons.verified_user_outlined,
                              size: 22,
                              color: selected
                                  ? Colors.white
                                  : const Color(0xFF64748B),
                            );
                          },
                        ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _tokenDisplayEmail(token),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF191C1E),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        height: 1.5,
                      ),
                    ),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF444653),
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (manageMode)
                TextButton(
                  onPressed: onDelete,
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFDC2626),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 24),
                  ),
                  child: Text(
                    'app.common.delete'.tr,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 1.5,
                    ),
                  ),
                )
              else if (onSelect != null)
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFFC2C8D4),
                  size: 22,
                )
              else
                const SizedBox(width: 22),
            ],
          ),
        ),
      ),
    );
  }
}

class _VaultCountdown extends StatelessWidget {
  const _VaultCountdown({required this.progress, required this.remaining});

  final double progress;
  final int remaining;

  Color _progressColor() {
    if (remaining <= 5) {
      return const Color(0xFFDC2626);
    }
    if (remaining <= 10) {
      return const Color(0xFFF59E0B);
    }
    return const Color(0xFF00288E);
  }

  Color _progressTrackColor() {
    if (remaining <= 5) {
      return const Color(0xFFFEE2E2);
    }
    if (remaining <= 10) {
      return const Color(0xFFFEF3C7);
    }
    return const Color(0xFFE6ECF6);
  }

  Color _countdownTextColor() {
    if (remaining <= 5) {
      return const Color(0xFFB91C1C);
    }
    if (remaining <= 10) {
      return const Color(0xFFD97706);
    }
    return const Color(0xFF444653);
  }

  @override
  Widget build(BuildContext context) {
    final progressColor = _progressColor();
    return SizedBox(
      width: 128,
      height: 128,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 120,
            height: 120,
            child: CircularProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              strokeWidth: 8,
              color: progressColor,
              backgroundColor: _progressTrackColor(),
              strokeCap: StrokeCap.round,
            ),
          ),
          Text(
            '${remaining}s',
            style: TextStyle(
              color: _countdownTextColor(),
              fontSize: 16,
              fontWeight: FontWeight.w600,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _VaultFooter extends StatelessWidget {
  const _VaultFooter({required this.tips});

  final String tips;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          Text(
            tips,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF444653),
              fontSize: 12,
              fontWeight: FontWeight.w400,
              height: 1.625,
            ),
          ),
        ],
      ),
    );
  }
}
