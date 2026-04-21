import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:tronskins_app/common/storage/server_storage.dart';
import 'package:tronskins_app/common/utils/app_version.dart';
import 'package:tronskins_app/common/widgets/glass_notice_dialog.dart';
import 'package:tronskins_app/common/widgets/settings_style_app_bar.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  static const _pageBg = Color(0xFFF7F9FB);
  static const _cardBg = Colors.white;
  static const _cardBorder = Color(0xFFF1F5F9);
  static const _dividerColor = Color(0xFFE2E8F0);
  static const _brandColor = Color(0xFF1E3A8A);
  static const _accentColor = Color(0xFF3B82F6);
  static const _titleColor = Color(0xFF0F172A);
  static const _bodyColor = Color(0xFF475569);
  static const _mutedColor = Color(0xFF94A3B8);
  static const _officialWebsite = 'https://www.tronskins.com/';

  Future<void> _copyText(BuildContext context, String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!context.mounted) {
      return;
    }
    await showCopySuccessNoticeDialog(context);
  }

  @override
  Widget build(BuildContext context) {
    final server = ServerStorage.getServer();

    return Scaffold(
      backgroundColor: _pageBg,
      body: Stack(
        children: [
          Positioned.fill(
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 96, 16, 40),
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 672),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _AboutHeroCard(
                        address: server,
                        onCopy: () => _copyText(context, server),
                      ),
                      const SizedBox(height: 24),
                      _SectionLabel('app.common.details'.tr),
                      const SizedBox(height: 12),
                      FutureBuilder<String>(
                        future: AppVersion.displayVersion(),
                        builder: (context, snapshot) {
                          final version = snapshot.data ?? '--';
                          return _AboutDetailsCard(
                            version: version,
                            server: server,
                            onCopyWebsite: () =>
                                _copyText(context, _officialWebsite),
                            onCopyServer: server == _officialWebsite
                                ? null
                                : () => _copyText(context, server),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const _AboutTopBar(),
        ],
      ),
    );
  }
}

class _AboutTopBar extends StatelessWidget {
  const _AboutTopBar();

  @override
  Widget build(BuildContext context) {
    return SettingsStyleTopNavigation(title: 'app.user.setting.about'.tr);
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: const TextStyle(
        color: AboutPage._mutedColor,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        height: 18 / 12,
      ),
    );
  }
}

class _AboutHeroCard extends StatelessWidget {
  const _AboutHeroCard({required this.address, required this.onCopy});

  final String address;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AboutPage._cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AboutPage._cardBorder),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(15, 23, 42, 0.05),
            blurRadius: 24,
            spreadRadius: -18,
            offset: Offset(0, 18),
          ),
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.04),
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned(
            right: -36,
            top: -40,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                width: 120,
                height: 120,
                decoration: const BoxDecoration(
                  color: Color.fromRGBO(59, 130, 246, 0.10),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          Positioned(
            left: -44,
            bottom: -56,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                width: 132,
                height: 132,
                decoration: const BoxDecoration(
                  color: Color.fromRGBO(30, 58, 138, 0.08),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color.fromRGBO(59, 130, 246, 0.08),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: const Color.fromRGBO(59, 130, 246, 0.12),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.language_rounded,
                        size: 15,
                        color: AboutPage._accentColor,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'app.user.setting.website'.tr,
                        style: const TextStyle(
                          color: AboutPage._accentColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          height: 16 / 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'TronSkins',
                  style: TextStyle(
                    color: AboutPage._brandColor,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.8,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  address,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AboutPage._bodyColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    height: 23 / 15,
                  ),
                ),
                const SizedBox(height: 20),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onCopy,
                    borderRadius: BorderRadius.circular(16),
                    child: Ink(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: const Color.fromRGBO(59, 130, 246, 0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color.fromRGBO(59, 130, 246, 0.10),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.copy_rounded,
                            size: 18,
                            color: AboutPage._accentColor,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'app.common.copy'.tr,
                              style: const TextStyle(
                                color: AboutPage._titleColor,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                height: 20 / 14,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right_rounded,
                            size: 20,
                            color: AboutPage._mutedColor,
                          ),
                        ],
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

class _AboutDetailsCard extends StatelessWidget {
  const _AboutDetailsCard({
    required this.version,
    required this.server,
    required this.onCopyWebsite,
    required this.onCopyServer,
  });

  final String version;
  final String server;
  final VoidCallback onCopyWebsite;
  final VoidCallback? onCopyServer;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AboutPage._cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AboutPage._cardBorder),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(15, 23, 42, 0.04),
            blurRadius: 18,
            spreadRadius: -14,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        children: [
          _AboutInfoRow(
            icon: Icons.verified_outlined,
            title: 'app.user.setting.version'.tr,
            value: version,
          ),
          const Divider(
            height: 1,
            indent: 16,
            endIndent: 16,
            color: AboutPage._dividerColor,
          ),
          _AboutInfoRow(
            icon: Icons.public_rounded,
            title: 'app.user.setting.website'.tr,
            subtitle: AboutPage._officialWebsite,
            onTap: onCopyWebsite,
          ),
          if (onCopyServer != null) ...[
            const Divider(
              height: 1,
              indent: 16,
              endIndent: 16,
              color: AboutPage._dividerColor,
            ),
            _AboutInfoRow(
              icon: Icons.dns_outlined,
              title: 'app.user.setting.server'.tr,
              subtitle: server,
              onTap: onCopyServer,
            ),
          ],
        ],
      ),
    );
  }
}

class _AboutInfoRow extends StatelessWidget {
  const _AboutInfoRow({
    required this.icon,
    required this.title,
    this.subtitle,
    this.value,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color.fromRGBO(59, 130, 246, 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 18, color: AboutPage._accentColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AboutPage._titleColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    height: 20 / 15,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    subtitle!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AboutPage._bodyColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      height: 20 / 13,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (value != null)
            Padding(
              padding: const EdgeInsets.only(left: 12, top: 2),
              child: Text(
                value!,
                style: const TextStyle(
                  color: AboutPage._brandColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  height: 20 / 14,
                ),
              ),
            ),
          if (onTap != null)
            const Padding(
              padding: EdgeInsets.only(left: 12, top: 2),
              child: Icon(
                Icons.copy_rounded,
                size: 18,
                color: AboutPage._mutedColor,
              ),
            ),
        ],
      ),
    );

    if (onTap == null) {
      return content;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(onTap: onTap, child: content),
    );
  }
}
