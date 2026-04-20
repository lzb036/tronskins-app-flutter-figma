import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tronskins_app/api/user_profile.dart';
import 'package:tronskins_app/common/utils/app_snackbar.dart';
import 'package:tronskins_app/common/widgets/app_request_loading_overlay.dart';
import 'package:tronskins_app/common/widgets/login_required_prompt.dart';
import 'package:tronskins_app/common/widgets/settings_style_app_bar.dart';
import 'package:tronskins_app/controllers/user/user_controller.dart';
import 'package:tronskins_app/pages/user/setting/account_settings_page_style.dart';

class EditNicknamePage extends StatefulWidget {
  const EditNicknamePage({super.key});

  @override
  State<EditNicknamePage> createState() => _EditNicknamePageState();
}

class _EditNicknamePageState extends State<EditNicknamePage> {
  final ApiUserProfileServer _api = ApiUserProfileServer();
  final UserController userController = Get.find<UserController>();
  final TextEditingController _controller = TextEditingController();
  bool _saving = false;

  void _showSuccessSnack(String message) {
    AppSnackbar.success(message);
  }

  void _showErrorSnack(String message) {
    AppSnackbar.error(message);
  }

  @override
  void dispose() {
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
    AppRequestLoading.show();
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
      AppRequestLoading.hide();
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final loggedIn = userController.isLoggedIn.value;
      return Scaffold(
        backgroundColor: AccountSettingsPalette.background,
        appBar: SettingsStyleAppBar(
          title: Text('app.user.setting.nickname_change'.tr),
        ),
        body: loggedIn
            ? ListView(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
                children: [
                  AccountSettingsHero(
                    title: 'app.user.setting.nickname_change'.tr,
                  ),
                  const SizedBox(height: 32),
                  TextField(
                    controller: _controller,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _submit(),
                    decoration: buildAccountSettingsInputDecoration(
                      hintText: 'app.user.setting.nickname_placeholder'.tr,
                    ),
                  ),
                  const SizedBox(height: 28),
                  AccountSettingsPrimaryButton(
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
                              _PrimaryButtonText('app.common.confirm'.tr),
                            ],
                          )
                        : _PrimaryButtonText('app.common.confirm'.tr),
                  ),
                  const SizedBox(height: 28),
                  _tipLine('1. ${'app.user.setting.nickname_tips_1'.tr}'),
                  _tipLine(
                    '2. ${'app.user.setting.nickname_tips_2'.tr}',
                    topPadding: 12,
                  ),
                  _tipLine(
                    '3. ${'app.user.setting.nickname_tips_3'.tr}',
                    topPadding: 12,
                  ),
                ],
              )
            : const LoginRequiredPrompt(),
      );
    });
  }

  Widget _tipLine(String text, {double topPadding = 0}) {
    return AccountSettingsTipLine(
      topPadding: topPadding,
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: AccountSettingsPalette.body,
          fontSize: 12,
          height: 19.5 / 12,
        ),
      ),
    );
  }
}

class _PrimaryButtonText extends StatelessWidget {
  const _PrimaryButtonText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.w700,
        height: 1.5,
      ),
    );
  }
}
