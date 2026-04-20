import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tronskins_app/common/hooks/theme/use_theme.dart';
import 'package:tronskins_app/common/widgets/settings_style_app_bar.dart';

class ThemeSettingsPage extends StatelessWidget {
  const ThemeSettingsPage({super.key});

  static const _pageBackground = Color(0xFFF8F8FC);
  static const _titleColor = Color(0xFF0F172A);
  static const _brandColor = Color(0xFF3B82F6);
  static const _cardBorder = Color(0xFFE5E7EB);
  static const _tileTextColor = Color(0xFF191C1E);
  static const _tileMutedColor = Color(0xFF64748B);
  static const _infoCardColor = Color(0xFFECEEF0);
  static const _footerTextColor = Color(0xFF94A3B8);

  @override
  Widget build(BuildContext context) {
    final useTheme = Get.find<UseTheme>();

    return Scaffold(
      backgroundColor: _pageBackground,
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
                      Obx(
                        () => _ThemeOptionCard(
                          currentMode: useTheme.themeMode,
                          onChanged: useTheme.changeThemeMode,
                        ),
                      ),
                      const SizedBox(height: 40),
                      const _InfoCard(
                        title: 'Eye Comfort',
                        description:
                            'System-wide dark mode can reduce eye strain in low-light environments and save battery on OLED displays.',
                      ),
                      const SizedBox(height: 18),
                      const _InfoCard(
                        title: 'Custom Scheduling',
                        description:
                            'Enable automatic scheduling in System Settings to transition between themes based on local sunrise and sunset.',
                      ),
                      const SizedBox(height: 56),
                      const _FooterHint(),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const _TopBar(),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return SettingsStyleTopNavigation(title: 'app.user.setting.theme'.tr);
  }
}

class _ThemeOptionCard extends StatelessWidget {
  const _ThemeOptionCard({required this.currentMode, required this.onChanged});

  final ThemeMode currentMode;
  final ValueChanged<ThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.zero,
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
          _ThemeTile(
            icon: Icons.settings_suggest_outlined,
            title: 'Follow System',
            selected: currentMode == ThemeMode.system,
            onTap: () => onChanged(ThemeMode.system),
          ),
          const Divider(height: 1, color: ThemeSettingsPage._cardBorder),
          _ThemeTile(
            icon: Icons.wb_sunny_outlined,
            title: 'Light Mode',
            selected: currentMode == ThemeMode.light,
            onTap: () => onChanged(ThemeMode.light),
          ),
          const Divider(height: 1, color: ThemeSettingsPage._cardBorder),
          _ThemeTile(
            icon: Icons.dark_mode_outlined,
            title: 'Dark Mode',
            selected: currentMode == ThemeMode.dark,
            onTap: () => onChanged(ThemeMode.dark),
          ),
        ],
      ),
    );
  }
}

class _ThemeTile extends StatelessWidget {
  const _ThemeTile({
    required this.icon,
    required this.title,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final iconColor = selected
        ? ThemeSettingsPage._brandColor
        : ThemeSettingsPage._tileMutedColor;
    final textColor = selected
        ? ThemeSettingsPage._brandColor
        : ThemeSettingsPage._tileTextColor;

    return Material(
      color: selected ? const Color.fromRGBO(239, 246, 255, 0.3) : Colors.white,
      borderRadius: BorderRadius.zero,
      child: InkWell(
        borderRadius: BorderRadius.zero,
        onTap: onTap,
        child: SizedBox(
          height: 56,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Icon(icon, size: 20, color: iconColor),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 15,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      height: 22.5 / 15,
                    ),
                  ),
                ),
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 180),
                  opacity: selected ? 1 : 0,
                  child: const Icon(
                    Icons.check_rounded,
                    size: 20,
                    color: ThemeSettingsPage._brandColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.description});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(21),
      decoration: BoxDecoration(
        color: ThemeSettingsPage._infoCardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color.fromRGBO(255, 255, 255, 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: ThemeSettingsPage._titleColor,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              height: 20 / 14,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(
              color: Color(0xFF444653),
              fontSize: 12,
              fontWeight: FontWeight.w400,
              height: 19.5 / 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _FooterHint extends StatelessWidget {
  const _FooterHint();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Theme changes will take effect immediately',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: ThemeSettingsPage._footerTextColor,
            fontSize: 13,
            fontWeight: FontWeight.w500,
            height: 19.5 / 13,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          width: 128,
          height: 4,
          decoration: BoxDecoration(
            color: const Color(0xFFE2E8F0),
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ],
    );
  }
}
