import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tronskins_app/api/user_profile.dart';
import 'package:tronskins_app/common/storage/app_cache.dart';
import 'package:tronskins_app/common/storage/user_storage.dart';
import 'package:tronskins_app/common/utils/app_snackbar.dart';
import 'package:tronskins_app/common/widgets/app_request_loading_overlay.dart';
import 'package:tronskins_app/common/widgets/login_required_prompt.dart';
import 'package:tronskins_app/common/widgets/settings_style_app_bar.dart';
import 'package:tronskins_app/controllers/user/user_controller.dart';
import 'package:tronskins_app/pages/user/setting/account_settings_page_style.dart';
import 'package:tronskins_app/routes/app_routes.dart';

class EditPasswordPage extends StatefulWidget {
  const EditPasswordPage({super.key});

  @override
  State<EditPasswordPage> createState() => _EditPasswordPageState();
}

class _EditPasswordPageState extends State<EditPasswordPage> {
  final ApiUserProfileServer _api = ApiUserProfileServer();
  final UserController userController = Get.find<UserController>();
  final TextEditingController _oldController = TextEditingController();
  final TextEditingController _newController = TextEditingController();
  final TextEditingController _repeatController = TextEditingController();
  bool _showOld = false;
  bool _showNew = false;
  bool _showRepeat = false;
  bool _saving = false;

  void _showSuccessSnack(String message) {
    AppSnackbar.success(message);
  }

  void _showErrorSnack(String message) {
    AppSnackbar.error(message);
  }

  @override
  void dispose() {
    _oldController.dispose();
    _newController.dispose();
    _repeatController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final oldPwd = _oldController.text.trim();
    final newPwd = _newController.text.trim();
    final repeat = _repeatController.text.trim();
    if (oldPwd.isEmpty || newPwd.isEmpty || repeat.isEmpty) {
      _showErrorSnack('app.user.login.password_placeholder'.tr);
      return;
    }
    if (newPwd != repeat) {
      _newController.clear();
      _repeatController.clear();
      _showErrorSnack('app.user.setting.password_inconsistent_error'.tr);
      return;
    }
    final user = UserStorage.getUserInfo();
    final userId = user?.id?.toString() ?? '';
    if (userId.isEmpty) {
      _showErrorSnack('app.system.message.nologin'.tr);
      return;
    }
    if (_saving) {
      return;
    }
    setState(() => _saving = true);
    AppRequestLoading.show();
    try {
      final res = await _api.editPassword(
        id: userId,
        password: oldPwd,
        newPassword: newPwd,
      );
      final message = res.datas?.toString().isNotEmpty == true
          ? res.datas.toString()
          : res.message;
      if (res.success) {
        _showSuccessSnack(
          message.isNotEmpty ? message : 'app.system.message.success'.tr,
        );
        _oldController.clear();
        _newController.clear();
        _repeatController.clear();
        await AppCache.clearOnLogout();
        if (Get.isRegistered<UserController>()) {
          Get.find<UserController>().clearSession();
        } else {
          UserStorage.setUserInfo(null);
        }
        Get.offAllNamed(Routers.LOGIN);
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
          title: Text('app.user.setting.password_change'.tr),
        ),
        body: loggedIn
            ? ListView(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
                children: [
                  AccountSettingsHero(
                    title: 'app.user.setting.password_change'.tr,
                    description: 'app.user.setting.password_format_tip'.tr,
                  ),
                  const SizedBox(height: 32),
                  _buildPasswordField(
                    controller: _oldController,
                    hintText: 'app.user.setting.password_enter_old_word'.tr,
                    visible: _showOld,
                    onToggle: () => setState(() => _showOld = !_showOld),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 16),
                  _buildPasswordField(
                    controller: _newController,
                    hintText: 'app.user.setting.password_enter_new_word'.tr,
                    visible: _showNew,
                    onToggle: () => setState(() => _showNew = !_showNew),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 16),
                  _buildPasswordField(
                    controller: _repeatController,
                    hintText: 'app.user.setting.password_enter_confirm_word'.tr,
                    visible: _showRepeat,
                    onToggle: () => setState(() => _showRepeat = !_showRepeat),
                    textInputAction: TextInputAction.done,
                    onSubmitted: _submit,
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
                              const _PrimaryButtonText(),
                            ],
                          )
                        : const _PrimaryButtonText(),
                  ),
                ],
              )
            : const LoginRequiredPrompt(),
      );
    });
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String hintText,
    required bool visible,
    required VoidCallback onToggle,
    required TextInputAction textInputAction,
    VoidCallback? onSubmitted,
  }) {
    return TextField(
      controller: controller,
      obscureText: !visible,
      textInputAction: textInputAction,
      onSubmitted: (_) => onSubmitted?.call(),
      decoration: buildAccountSettingsInputDecoration(
        hintText: hintText,
        suffixIcon: IconButton(
          splashRadius: 20,
          icon: Icon(
            visible ? Icons.visibility_outlined : Icons.visibility_off_outlined,
            color: AccountSettingsPalette.hint,
          ),
          onPressed: onToggle,
        ),
      ),
    );
  }
}

class _PrimaryButtonText extends StatelessWidget {
  const _PrimaryButtonText();

  @override
  Widget build(BuildContext context) {
    return Text(
      'app.common.confirm'.tr,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.w700,
        height: 1.5,
      ),
    );
  }
}
