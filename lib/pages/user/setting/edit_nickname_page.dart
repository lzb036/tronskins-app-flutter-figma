import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:tronskins_app/api/user_profile.dart';
import 'package:tronskins_app/common/utils/app_snackbar.dart';
import 'package:tronskins_app/common/widgets/login_required_prompt.dart';
import 'package:tronskins_app/common/widgets/settings_style_app_bar.dart';
import 'package:tronskins_app/controllers/user/user_controller.dart';

class EditNicknamePage extends StatefulWidget {
  const EditNicknamePage({super.key});

  @override
  State<EditNicknamePage> createState() => _EditNicknamePageState();
}

class _EditNicknamePageState extends State<EditNicknamePage> {
  static const Color _pageBackground = Color(0xFFF8FAFC);
  static const Color _surface = Color(0xFFFFFFFF);
  static const Color _surfaceMuted = Color(0xFFECEEF0);
  static const Color _surfaceAvatar = Color(0xFFE0E3E5);
  static const Color _textPrimary = Color(0xFF0F172A);
  static const Color _textSecondary = Color(0xFF64748B);
  static const Color _textLabel = Color(0xFF444653);
  static const Color _ghostBorder = Color.fromRGBO(196, 197, 213, 0.30);
  static const Color _buttonStart = Color(0xFF1E40AF);
  static const Color _buttonEnd = Color(0xFF3B82F6);
  static const Color _buttonShadow = Color.fromRGBO(59, 130, 246, 0.20);

  final ApiUserProfileServer _api = ApiUserProfileServer();
  final UserController userController = Get.find<UserController>();
  final TextEditingController _controller = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final initialNickname = userController.nickname.trim();
    if (initialNickname.isNotEmpty) {
      _controller.text = initialNickname;
    }
    _controller.addListener(_handleNicknameChanged);
  }

  void _handleNicknameChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _showSuccessSnack(String message) {
    AppSnackbar.success(message);
  }

  void _showErrorSnack(String message) {
    AppSnackbar.error(message);
  }

  @override
  void dispose() {
    _controller.removeListener(_handleNicknameChanged);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final navigator = Navigator.of(context);
    final nickname = _controller.text.trim();
    if (nickname.isEmpty) {
      _showErrorSnack('app.user.setting.nickname_placeholder'.tr);
      return;
    }
    if (_saving) {
      return;
    }
    setState(() => _saving = true);
    try {
      final res = await _api.editNickname(nickname: nickname);
      final message = res.datas?.toString().isNotEmpty == true
          ? res.datas.toString()
          : res.message;
      if (res.success) {
        _showSuccessSnack(
          message.isNotEmpty ? message : 'app.system.message.success'.tr,
        );
        if (Get.isRegistered<UserController>()) {
          await Get.find<UserController>().fetchUserData(showLoading: false);
        }
        if (mounted) {
          navigator.pop();
        }
      } else {
        _showErrorSnack(
          message.isNotEmpty ? message : 'app.system.message.not_open'.tr,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  String get _previewNickname {
    final nickname = _controller.text.trim();
    return nickname.isNotEmpty ? nickname : '--';
  }

  int get _nicknameLength {
    final length = _controller.text.characters.length;
    if (length < 0) {
      return 0;
    }
    if (length > 20) {
      return 20;
    }
    return length;
  }

  String _localizedText({required String zh, required String en}) {
    final languageCode = Get.locale?.languageCode.toLowerCase();
    return languageCode == 'zh' ? zh : en;
  }

  String get _labelText => _localizedText(zh: '当前昵称', en: 'Current Nickname');

  String get _supportText => _localizedText(
    zh: '仅支持英文、数字与下划线',
    en: 'Supports English, numbers, and underscores only',
  );

  String get _previewDescription => _localizedText(
    zh: '你的新昵称将同步更新到所有平台',
    en: 'Your new nickname will be updated across all platforms',
  );

  String get _footerText => _localizedText(
    zh: '修改昵称后，好友将看到你的新名字。\n${'app.user.setting.nickname_tips_3'.tr}',
    en: 'After changing your nickname, friends will see your new name.\n${'app.user.setting.nickname_tips_3'.tr}',
  );

  double _bodyBottomPadding(BuildContext context) {
    return 196 + MediaQuery.of(context).padding.bottom;
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final loggedIn = userController.isLoggedIn.value;
      return Scaffold(
        backgroundColor: _pageBackground,
        appBar: SettingsStyleAppBar(
          title: Text('app.user.setting.nickname_change'.tr),
        ),
        body: loggedIn
            ? Stack(
                children: [
                  Positioned.fill(
                    child: ListView(
                      padding: EdgeInsets.fromLTRB(
                        24,
                        32,
                        24,
                        _bodyBottomPadding(context),
                      ),
                      children: [
                        _buildInputSection(context),
                        const SizedBox(height: 24),
                        _buildPreviewCard(context),
                      ],
                    ),
                  ),
                  _buildBottomActionShell(context),
                ],
              )
            : const LoginRequiredPrompt(),
      );
    });
  }

  Widget _buildInputSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            _labelText,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: _textLabel,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              height: 20 / 14,
            ),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _controller,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
          inputFormatters: [LengthLimitingTextInputFormatter(20)],
          cursorColor: _buttonEnd,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: _textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w500,
            height: 1.25,
          ),
          decoration: InputDecoration(
            hintText: 'app.user.setting.nickname_placeholder'.tr,
            hintStyle: const TextStyle(
              color: _textSecondary,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            filled: true,
            fillColor: _surface,
            contentPadding: const EdgeInsets.fromLTRB(21, 18, 21, 18),
            suffixIconConstraints: const BoxConstraints(),
            suffixIcon: Padding(
              padding: const EdgeInsets.only(right: 20),
              child: _NicknameCountBadge(text: '$_nicknameLength/20'),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _ghostBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _ghostBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFBFD0FF)),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              const Icon(
                Icons.info_outline_rounded,
                size: 14,
                color: _textSecondary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _supportText,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: _textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    height: 16 / 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _surfaceMuted,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _NicknameAvatar(provider: userController.avatarProvider),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _previewNickname,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: _textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    height: 24 / 16,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _previewDescription,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: _textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    height: 16 / 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActionShell(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.only(bottom: mediaQuery.viewInsets.bottom),
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              color: _pageBackground.withValues(alpha: 0.9),
              padding: EdgeInsets.fromLTRB(
                24,
                16,
                24,
                32 + mediaQuery.padding.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _NicknamePrimaryButton(
                    onPressed: _saving ? null : _submit,
                    child: _saving
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                _localizedText(zh: '保存修改', en: 'Save Changes'),
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      height: 24 / 16,
                                    ),
                              ),
                            ],
                          )
                        : Text(
                            _localizedText(zh: '保存修改', en: 'Save Changes'),
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  height: 24 / 16,
                                ),
                          ),
                  ),
                  const SizedBox(height: 23),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 320),
                    child: Text(
                      _footerText,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: _textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        height: 17.88 / 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NicknameCountBadge extends StatelessWidget {
  const _NicknameCountBadge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFECEEF0),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: const Color(0xFF64748B),
          fontSize: 12,
          fontWeight: FontWeight.w500,
          height: 16 / 12,
        ),
      ),
    );
  }
}

class _NicknameAvatar extends StatelessWidget {
  const _NicknameAvatar({required this.provider});

  final ImageProvider provider;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46.58,
      height: 64,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _EditNicknamePageState._surfaceAvatar,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white, width: 4),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image(image: provider, fit: BoxFit.cover),
      ),
    );
  }
}

class _NicknamePrimaryButton extends StatelessWidget {
  const _NicknamePrimaryButton({required this.child, this.onPressed});

  final Widget child;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Opacity(
      opacity: enabled ? 1 : 0.72,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              _EditNicknamePageState._buttonStart,
              _EditNicknamePageState._buttonEnd,
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(
              color: _EditNicknamePageState._buttonShadow,
              blurRadius: 15,
              offset: Offset(0, 10),
              spreadRadius: -3,
            ),
            BoxShadow(
              color: _EditNicknamePageState._buttonShadow,
              blurRadius: 6,
              offset: Offset(0, 4),
              spreadRadius: -4,
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: Center(child: child),
            ),
          ),
        ),
      ),
    );
  }
}
