import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tronskins_app/common/hooks/currency/CurrencyController.dart';
import 'package:tronskins_app/common/hooks/locale/use_locale.dart';
import 'package:tronskins_app/common/hooks/theme/use_theme.dart';
import 'package:tronskins_app/common/utils/app_snackbar.dart';
import 'package:tronskins_app/common/utils/app_version.dart';
import 'package:tronskins_app/common/storage/server_storage.dart';
import 'package:tronskins_app/common/storage/twofa_storage.dart';
import 'package:tronskins_app/common/widgets/avatar_preview_dialog.dart';
import 'package:tronskins_app/common/widgets/back_to_top_overlay.dart';
import 'package:tronskins_app/common/widgets/settings_style_app_bar.dart';
import 'package:tronskins_app/controllers/user/user_controller.dart';
import 'package:tronskins_app/routes/app_routes.dart';

const _avatarHeroTag = 'user-avatar-hero-setting';

class UserSetting extends StatelessWidget {
  const UserSetting({super.key});

  static const _pageBg = Color(0xFFF7F9FB);
  static const _cardBg = Colors.white;
  static const _cardBorder = Color(0xFFF1F5F9);
  static const _titleColor = Color(0xFF334155);
  static const _mutedColor = Color(0xFF94A3B8);
  static const _brandColor = Color(0xFF1E3A8A);

  @override
  Widget build(BuildContext context) {
    final userCtrl = Get.find<UserController>();
    final useTheme = Get.find<UseTheme>();
    final useLocale = Get.find<UseLocale>();
    final currencyCtrl = Get.find<CurrencyController>();

    return BackToTopScope(
      enabled: false,
      child: Scaffold(
        backgroundColor: _pageBg,
        body: Stack(
          children: [
            Positioned.fill(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 96, 16, 48),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 672),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Obx(() => _buildProfileCard(context, userCtrl)),
                        const SizedBox(height: 32),
                        const _SectionLabel('Security & Account'),
                        const SizedBox(height: 12),
                        _buildGroupedCard([
                          _buildActionTile(
                            icon: Icons.password_outlined,
                            title: 'app.user.setting.password_change'.tr,
                            onTap: () =>
                                Get.toNamed(Routers.USER_EDIT_PASSWORD),
                          ),
                          _buildActionTile(
                            icon: Icons.security_outlined,
                            title: 'app.user.menu.guard'.tr,
                            trailing: Obx(
                              () => _buildTwoFaStatusChip(userCtrl),
                            ),
                            onTap: () {
                              final navFuture = Get.toNamed(Routers.USER_GUARD);
                              navFuture?.then((_) {
                                userCtrl.user.refresh();
                              });
                            },
                          ),
                          _buildActionTile(
                            icon: Icons.sports_esports_outlined,
                            title: 'app.user.setting.steam_management'.tr,
                            trailing: Obx(
                              () =>
                                  _buildTrailingText(_steamBoundName(userCtrl)),
                            ),
                            onTap: () => Get.toNamed(Routers.STEAM_SETTING),
                          ),
                        ]),
                        const SizedBox(height: 24),
                        const _SectionLabel('Preferences'),
                        const SizedBox(height: 12),
                        _buildGroupedCard([
                          _buildActionTile(
                            icon: Icons.language_rounded,
                            title: 'app.user.setting.multilingual'.tr,
                            trailing: Obx(
                              () => _buildTrailingText(
                                useLocale.getLanguageName(
                                  useLocale.currentLocale,
                                ),
                              ),
                            ),
                            onTap: () =>
                                Get.toNamed(Routers.USER_SETTING_LANGUAGE),
                          ),
                          _buildActionTile(
                            icon: Icons.account_balance_wallet_outlined,
                            title: 'app.user.setting.exchange_rate'.tr,
                            trailing: Obx(
                              () => _buildTrailingText(currencyCtrl.code),
                            ),
                            onTap: () => Get.toNamed(Routers.USER_SETTING_RATE),
                          ),
                          _buildActionTile(
                            icon: Icons.light_mode_outlined,
                            title: 'app.user.setting.theme'.tr,
                            trailing: Obx(
                              () => _buildTrailingText(
                                _themeModeLabel(useTheme.themeMode),
                              ),
                            ),
                            onTap: () =>
                                Get.toNamed(Routers.USER_SETTING_THEME),
                          ),
                          _buildActionTile(
                            icon: Icons.dns_outlined,
                            title: 'app.user.setting.server'.tr,
                            trailing: Obx(() {
                              ServerStorage.changeToken.value;
                              return ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 92),
                                child: _buildTrailingText(_currentServerName()),
                              );
                            }),
                            onTap: () =>
                                Get.toNamed(Routers.USER_SETTING_SERVER),
                          ),
                        ]),
                        const SizedBox(height: 24),
                        const _SectionLabel('Support'),
                        const SizedBox(height: 12),
                        _buildGroupedCard([
                          _buildActionTile(
                            icon: Icons.help_outline_rounded,
                            title: 'app.user.server.help'.tr,
                            onTap: () => Get.toNamed(Routers.HELP_CENTER),
                          ),
                          _buildActionTile(
                            icon: Icons.chat_bubble_outline_rounded,
                            title: 'app.user.menu.feedback'.tr,
                            onTap: () => Get.toNamed(Routers.FEEDBACK_LIST),
                          ),
                          _buildActionTile(
                            icon: Icons.info_outline,
                            title: 'app.user.setting.about'.tr,
                            onTap: () => Get.toNamed(Routers.USER_ABOUT),
                          ),
                          _buildActionTile(
                            icon: Icons.bug_report_outlined,
                            title: '认证测试中心',
                            onTap: () => Get.toNamed(Routers.USER_AUTH_TEST),
                          ),
                        ]),
                        const SizedBox(height: 12),
                        Center(child: _buildVersionCaption()),
                        const SizedBox(height: 12),
                        Obx(() => _buildLogoutButton(context, userCtrl)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            _buildTopNavigation(context),
          ],
        ),
      ),
    );
  }

  Widget _buildTopNavigation(BuildContext context) {
    return SettingsStyleTopNavigation(title: 'app.user.setting.title'.tr);
  }

  Widget _buildProfileCard(BuildContext context, UserController userCtrl) {
    final loggedIn = userCtrl.isLoggedIn.value;
    if (!loggedIn) {
      return _buildLoggedOutProfileCard(userCtrl);
    }

    final nickname = userCtrl.nickname.isNotEmpty
        ? userCtrl.nickname
        : 'app.user.setting.nickname_not_set'.tr;
    final email = userCtrl.email.isNotEmpty ? userCtrl.email : '--';
    const VoidCallback? loginTap = null;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cardBorder),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.05),
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned(
            right: -48,
            top: -48,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                width: 128,
                height: 128,
                decoration: const BoxDecoration(
                  color: Color.fromRGBO(59, 130, 246, 0.08),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          Positioned(
            left: -48,
            bottom: -48,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                width: 128,
                height: 128,
                decoration: const BoxDecoration(
                  color: Color.fromRGBO(30, 64, 175, 0.08),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(25),
            child: Row(
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: () => showAvatarPreviewDialog(
                    context,
                    imageProvider: userCtrl.avatarProvider,
                    heroTag: _avatarHeroTag,
                  ),
                  child: Hero(
                    tag: _avatarHeroTag,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color.fromRGBO(30, 64, 175, 0.1),
                          width: 2,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: ClipOval(
                          child: Image(
                            image: userCtrl.avatarProvider,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            fit: FlexFit.loose,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: loginTap,
                              child: Text(
                                nickname,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: _brandColor,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                  height: 1.0,
                                  letterSpacing: -0.6,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          InkWell(
                            borderRadius: BorderRadius.circular(999),
                            onTap: () =>
                                Get.toNamed(Routers.USER_EDIT_NICKNAME),
                            child: const Padding(
                              padding: EdgeInsets.all(4),
                              child: Icon(
                                Icons.edit_outlined,
                                size: 12,
                                color: _mutedColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: loginTap,
                              child: Text(
                                email,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFF64748B),
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
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoggedOutProfileCard(UserController userCtrl) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cardBorder),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.05),
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned(
            right: -48,
            top: -48,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                width: 128,
                height: 128,
                decoration: const BoxDecoration(
                  color: Color.fromRGBO(59, 130, 246, 0.08),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          Positioned(
            left: -48,
            bottom: -48,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                width: 128,
                height: 128,
                decoration: const BoxDecoration(
                  color: Color.fromRGBO(30, 64, 175, 0.08),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => Get.toNamed(Routers.LOGIN),
              child: Padding(
                padding: const EdgeInsets.all(25),
                child: Row(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color.fromRGBO(30, 64, 175, 0.1),
                          width: 2,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: ClipOval(
                          child: Image(
                            image: userCtrl.avatarProvider,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: Text(
                        'app.user.login.nologin'.tr,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _brandColor,
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          height: 1.0,
                          letterSpacing: -0.6,
                        ),
                      ),
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

  Widget _buildGroupedCard(List<Widget> tiles) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cardBorder),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.05),
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        children: [
          for (var i = 0; i < tiles.length; i++) ...[
            tiles[i],
            if (i != tiles.length - 1)
              const Divider(
                height: 1,
                thickness: 1,
                indent: 16,
                endIndent: 16,
                color: _cardBorder,
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap:
            onTap ?? () => AppSnackbar.info('app.system.message.not_open'.tr),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 20, color: const Color(0xFF64748B)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _titleColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    height: 24 / 16,
                  ),
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 12),
                Align(alignment: Alignment.centerRight, child: trailing),
                const SizedBox(width: 12),
              ],
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFFCBD5E1),
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTrailingText(String text) {
    return Text(
      text,
      softWrap: false,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.right,
      style: const TextStyle(
        color: _mutedColor,
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 20 / 14,
      ),
    );
  }

  Widget _buildStatusChip(bool active) {
    final label = _twoFaStatusLabel(active);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: active ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9),
        border: Border.all(
          color: active ? const Color(0xFFA7F3D0) : const Color(0xFFE2E8F0),
        ),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: active ? const Color(0xFF059669) : const Color(0xFF94A3B8),
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          height: 15 / 10,
        ),
      ),
    );
  }

  Widget _buildTwoFaStatusChip(UserController userCtrl) {
    return FutureBuilder<bool>(
      future: _isTwoFaSynced(userCtrl),
      builder: (context, snapshot) {
        final active = snapshot.data ?? false;
        return _buildStatusChip(active);
      },
    );
  }

  String _normalizeText(String? value) {
    return value?.trim().toLowerCase() ?? '';
  }

  String _normalizeServer(String? value) {
    final raw = _normalizeText(value);
    if (raw.isEmpty) {
      return '';
    }
    final withScheme = raw.contains('://') ? raw : 'https://$raw';
    final uri = Uri.tryParse(withScheme);
    if (uri != null && uri.host.isNotEmpty) {
      final host = uri.host.toLowerCase();
      return uri.hasPort ? '$host:${uri.port}' : host;
    }
    return raw.replaceFirst(RegExp(r'^\w+://'), '').split('/').first;
  }

  bool _matchesServer(String? tokenServer, String normalizedServer) {
    final normalizedTokenServer = _normalizeServer(tokenServer);
    if (normalizedTokenServer.isEmpty) {
      // 兼容历史 token 中未保存 server 的情况。
      return true;
    }
    return normalizedTokenServer == normalizedServer;
  }

  bool _emailPatternMatches(String pattern, String value) {
    final escapedPattern = RegExp.escape(pattern).replaceAll(r'\*', '.*');
    final reg = RegExp('^$escapedPattern\$');
    return reg.hasMatch(value);
  }

  bool _emailsMatch(String a, String b) {
    final left = _normalizeText(a);
    final right = _normalizeText(b);
    if (left.isEmpty || right.isEmpty) {
      return false;
    }
    if (left == right) {
      return true;
    }
    return _emailPatternMatches(left, right) ||
        _emailPatternMatches(right, left);
  }

  Future<bool> _isTwoFaSynced(UserController userCtrl) async {
    final user = userCtrl.user.value;
    if (user == null || !userCtrl.isLoggedIn.value) {
      return false;
    }
    final normalizedServer = _normalizeServer(ServerStorage.getServer());
    if (normalizedServer.isEmpty) {
      return false;
    }

    final normalizedEmails = <String>{
      _normalizeText(user.safeTokenName),
      _normalizeText(user.showEmail),
      if ((user.account ?? '').contains('@')) _normalizeText(user.account),
    }..removeWhere((item) => item.isEmpty);
    if (normalizedEmails.isEmpty) {
      return false;
    }

    final tokens = await TwoFactorStorage.getList();
    for (final token in tokens) {
      if (token.secret.trim().isEmpty) {
        continue;
      }
      if (!_matchesServer(token.server, normalizedServer)) {
        continue;
      }
      final tokenEmail = token.showEmail;
      if (normalizedEmails.any((email) => _emailsMatch(tokenEmail, email))) {
        return true;
      }
    }
    return false;
  }

  String _steamBoundName(UserController userCtrl) {
    final user = userCtrl.user.value;
    if (user == null || !userCtrl.isLoggedIn.value) {
      return '--';
    }
    final steamNickname = user.config?.nickname?.trim() ?? '';
    if (steamNickname.isNotEmpty) {
      return steamNickname;
    }
    final steamId = user.config?.steamId?.trim() ?? '';
    if (steamId.isNotEmpty) {
      return steamId;
    }
    return '--';
  }

  String _currentServerName() {
    final name = ServerStorage.getCurrentServerName().trim();
    if (name.isEmpty) {
      return '--';
    }
    return name;
  }

  String _twoFaStatusLabel(bool active) {
    final locale = Get.locale;
    final lang = locale?.languageCode.toLowerCase();
    final country = (locale?.countryCode ?? '').toUpperCase();
    if (lang == 'zh') {
      return active
          ? (country == 'TW' ? '已綁定' : '已绑定')
          : (country == 'TW' ? '未綁定' : '未绑定');
    }
    return (active ? 'Active' : 'Inactive').toUpperCase();
  }

  Widget _buildVersionCaption() {
    return FutureBuilder<String>(
      future: AppVersion.displayVersion(),
      builder: (context, snapshot) {
        final version = snapshot.data ?? '--';
        final caption = '${'app.user.setting.version'.tr}: $version';
        return Text(
          caption,
          style: const TextStyle(
            color: _mutedColor,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
            height: 1.5,
          ),
        );
      },
    );
  }

  Widget _buildLogoutButton(BuildContext context, UserController userCtrl) {
    final loggedIn = userCtrl.isLoggedIn.value;
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: loggedIn
              ? const Color.fromRGBO(186, 26, 26, 0.1)
              : const Color(0xFFE2E8F0),
          foregroundColor: loggedIn
              ? const Color(0xFFBA1A1A)
              : const Color(0xFF94A3B8),
          disabledBackgroundColor: const Color(0xFFE2E8F0),
          disabledForegroundColor: const Color(0xFF94A3B8),
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color.fromRGBO(186, 26, 26, 0.1)),
          ),
          elevation: 0,
          textStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            height: 16 / 12,
          ),
        ),
        onPressed: loggedIn ? () => userCtrl.logout(context) : null,
        child: Text('app.user.login.logout'.tr.toUpperCase()),
      ),
    );
  }

  String _themeModeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'app.user.setting.theme_light'.tr;
      case ThemeMode.dark:
        return 'app.user.setting.theme_dark'.tr;
      case ThemeMode.system:
        return 'app.user.setting.theme_system'.tr;
    }
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: Color(0xFF94A3B8),
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          height: 16 / 12,
        ),
      ),
    );
  }
}
