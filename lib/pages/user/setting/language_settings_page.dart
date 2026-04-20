import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tronskins_app/common/hooks/locale/use_locale.dart';
import 'package:tronskins_app/common/widgets/settings_style_app_bar.dart';

class LanguageSettingsPage extends StatefulWidget {
  const LanguageSettingsPage({super.key});

  @override
  State<LanguageSettingsPage> createState() => _LanguageSettingsPageState();
}

class _LanguageSettingsPageState extends State<LanguageSettingsPage> {
  late final UseLocale _useLocale;
  late String _selectedCode;
  late String _selectedCountry;

  static const _pageBackground = Color(0xFFF8F8FC);
  static const _borderColor = Color(0xFFE5E7EB);
  static const _hintColor = Color(0xFF94A3B8);
  static const _descriptionColor = Color(0xFF444653);
  static const _checkColor = Color(0xFF14B8A6);

  @override
  void initState() {
    super.initState();
    _useLocale = Get.find<UseLocale>();
    _selectedCode = _useLocale.currentLocale.languageCode;
    _selectedCountry = _useLocale.currentLocale.countryCode ?? 'US';
  }

  @override
  Widget build(BuildContext context) {
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
                    children: [
                      _buildHero(),
                      const SizedBox(height: 28),
                      _buildLanguageCard(),
                      const SizedBox(height: 24),
                      const Text(
                        'Changes will take effect immediately.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _hintColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.3,
                          height: 18 / 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const _LanguageTopBar(),
        ],
      ),
    );
  }

  Widget _buildHero() {
    return Column(
      children: const [
        DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.all(Radius.circular(16)),
            boxShadow: [
              BoxShadow(
                color: Color.fromRGBO(0, 0, 0, 0.05),
                blurRadius: 2,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: SizedBox(
            width: 64,
            height: 64,
            child: Icon(
              Icons.language_rounded,
              size: 30,
              color: Color(0xFF1E40AF),
            ),
          ),
        ),
        SizedBox(height: 20),
        Text(
          'Select your preferred language for the gallery experience',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _descriptionColor,
            fontSize: 14,
            fontWeight: FontWeight.w500,
            height: 20 / 14,
          ),
        ),
      ],
    );
  }

  Widget _buildLanguageCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.05),
            blurRadius: 20,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          for (
            var index = 0;
            index < _useLocale.supportedLanguages.length;
            index++
          ) ...[
            _buildLanguageTile(_useLocale.supportedLanguages[index]),
            if (index != _useLocale.supportedLanguages.length - 1)
              const Divider(
                height: 1,
                thickness: 1,
                indent: 16,
                endIndent: 16,
                color: _borderColor,
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildLanguageTile(Map<String, String> lang) {
    final code = lang['code'] ?? 'en';
    final country = lang['country'] ?? 'US';
    final isSelected = code == _selectedCode && country == _selectedCountry;
    final nativeName = _useLocale.getLocalizedLanguageName(lang);
    final label =
        lang['name'] ?? _useLocale.getLanguageName(Locale(code, country));

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (isSelected) {
            return;
          }
          setState(() {
            _selectedCode = code;
            _selectedCountry = country;
          });
          _useLocale.changeLanguage(code, country);
        },
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 56,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _LanguageIcon(
                  assetPath: _useLocale.getLanguageIcon(lang),
                  fallbackLabel: _fallbackLabel(code, country),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: const Color(0xFF191C1E),
                          fontSize: 16,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w500,
                          height: 20 / 16,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        nativeName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _hintColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          height: 15 / 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 180),
                  opacity: isSelected ? 1 : 0,
                  child: const Icon(
                    Icons.check_rounded,
                    size: 20,
                    color: _checkColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _fallbackLabel(String code, String country) {
    if (code == 'zh' && country == 'CN') {
      return '中';
    }
    if (code == 'zh' && country == 'HK') {
      return '繁';
    }
    return code.toUpperCase();
  }
}

class _LanguageTopBar extends StatelessWidget {
  const _LanguageTopBar();

  @override
  Widget build(BuildContext context) {
    return SettingsStyleTopNavigation(
      title: 'app.user.setting.multilingual'.tr,
    );
  }
}

class _LanguageIcon extends StatelessWidget {
  const _LanguageIcon({required this.assetPath, required this.fallbackLabel});

  final String assetPath;
  final String fallbackLabel;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 28,
        height: 28,
        child: Image.asset(
          assetPath,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) {
            return Container(
              color: const Color(0xFFF2F2F7),
              alignment: Alignment.center,
              child: Text(
                fallbackLabel,
                style: const TextStyle(
                  color: Color(0xFF444653),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
