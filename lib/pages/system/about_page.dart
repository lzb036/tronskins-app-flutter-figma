import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tronskins_app/common/utils/app_version.dart';
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

  static String get _hotUpdateVersionLabel {
    final languageCode = Get.locale?.languageCode.toLowerCase() ?? '';
    return languageCode.startsWith('zh') ? '热更版本' : 'Hot Update Version';
  }

  Future<_AboutVersionInfo> _loadVersionInfo() async {
    final values = await Future.wait([
      AppVersion.baseVersion(),
      AppVersion.hotUpdateVersion(),
    ]);
    return _AboutVersionInfo(version: values[0], hotUpdateVersion: values[1]);
  }

  @override
  Widget build(BuildContext context) {
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
                  child: FutureBuilder<_AboutVersionInfo>(
                    future: _loadVersionInfo(),
                    builder: (context, snapshot) {
                      final info = snapshot.data;
                      return _AboutDetailsCard(
                        version: info?.version ?? '--',
                        hotUpdateVersion: info?.hotUpdateVersion ?? '--',
                      );
                    },
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

class _AboutVersionInfo {
  const _AboutVersionInfo({
    required this.version,
    required this.hotUpdateVersion,
  });

  final String version;
  final String hotUpdateVersion;
}

class _AboutTopBar extends StatelessWidget {
  const _AboutTopBar();

  @override
  Widget build(BuildContext context) {
    return SettingsStyleTopNavigation(title: 'app.user.setting.about'.tr);
  }
}

class _AboutDetailsCard extends StatelessWidget {
  const _AboutDetailsCard({
    required this.version,
    required this.hotUpdateVersion,
  });

  final String version;
  final String hotUpdateVersion;

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
            icon: Icons.system_update_alt_rounded,
            title: AboutPage._hotUpdateVersionLabel,
            value: hotUpdateVersion,
          ),
        ],
      ),
    );
  }
}

class _AboutInfoRow extends StatelessWidget {
  const _AboutInfoRow({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
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
            child: Text(
              title,
              style: const TextStyle(
                color: AboutPage._titleColor,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                height: 20 / 15,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: AboutPage._brandColor,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                height: 20 / 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
