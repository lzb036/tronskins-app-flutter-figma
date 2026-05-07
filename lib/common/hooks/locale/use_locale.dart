import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

class UseLocale extends GetxController {
  static final _storage = GetStorage('language');
  static const Locale _defaultLocale = Locale('en', 'US');
  static const Map<String, String> _localeAliases = {
    'zh_HK': 'zh_TW',
    'ge_DE': 'de_DE',
    'in_ID': 'id_ID',
    'po_PL': 'pl_PL',
    'po_PT': 'pt_PT',
    'sp_ES': 'es_ES',
    'tu_TR': 'tr_TR',
  };
  static const Map<String, String> _languageNameKeyAliases = {
    'zh_HK': 'zh_TW',
    'de_DE': 'ge_DE',
    'id_ID': 'in_ID',
    'pl_PL': 'po_PL',
    'pt_PT': 'po_PT',
    'es_ES': 'sp_ES',
    'tr_TR': 'tu_TR',
  };

  final Rx<Locale> _currentLocale = _defaultLocale.obs;

  Locale get currentLocale => _currentLocale.value;
  Rx<Locale> get localeRx => _currentLocale;
  List<Locale> get supportedLocales => supportedLanguages
      .map((lang) => Locale(lang['code'] ?? 'en', lang['country'] ?? 'US'))
      .toList(growable: false);

  // 支持的语言列表
  final List<Map<String, String>> supportedLanguages = [
    {'code': 'en', 'country': 'US', 'name': 'English', 'icon': 'en_US'},
    {
      'code': 'zh',
      'country': 'CN',
      'name': 'Chinese (Simplified)',
      'icon': 'zh_CN',
    },
    {
      'code': 'zh',
      'country': 'TW',
      'name': 'Chinese (Traditional)',
      'icon': 'zh_HK',
    },
    {'code': 'fr', 'country': 'FR', 'name': 'French', 'icon': 'fr_FR'},
    {'code': 'de', 'country': 'DE', 'name': 'German', 'icon': 'ge_DE'},
    {'code': 'id', 'country': 'ID', 'name': 'Indonesian', 'icon': 'in_ID'},
    {'code': 'it', 'country': 'IT', 'name': 'Italian', 'icon': 'it_IT'},
    {'code': 'ja', 'country': 'JP', 'name': 'Japanese', 'icon': 'ja_JP'},
    {'code': 'ko', 'country': 'KR', 'name': 'Korean', 'icon': 'ko_KR'},
    {'code': 'la', 'country': 'LAT', 'name': 'Latin', 'icon': 'la_LAT'},
    {'code': 'pl', 'country': 'PL', 'name': 'Polish', 'icon': 'po_PL'},
    {'code': 'pt', 'country': 'PT', 'name': 'Portuguese', 'icon': 'po_PT'},
    {'code': 'ru', 'country': 'RU', 'name': 'Russian', 'icon': 'ru_RU'},
    {'code': 'es', 'country': 'ES', 'name': 'Spanish', 'icon': 'sp_ES'},
    {'code': 'th', 'country': 'TH', 'name': 'Thai', 'icon': 'th_TH'},
    {'code': 'tr', 'country': 'TR', 'name': 'Turkish', 'icon': 'tu_TR'},
    {'code': 'vi', 'country': 'VN', 'name': 'Vietnamese', 'icon': 'vi_VN'},
  ];

  @override
  void onInit() {
    super.onInit();
    // 从存储加载语言设置
    final savedLanguageCode = _storage.read<String>('languageCode');
    final savedCountryCode = _storage.read<String>('countryCode');

    if (savedLanguageCode != null && savedCountryCode != null) {
      final locale = _normalizeLocale(
        Locale(savedLanguageCode, savedCountryCode),
      );
      _currentLocale.value = locale;
      _storage.write('languageCode', locale.languageCode);
      _storage.write('countryCode', locale.countryCode);
    } else {
      // 没有用户显式选择时，应用默认使用英文。
      _currentLocale.value = _defaultLocale;
    }
  }

  void changeLanguage(String languageCode, String countryCode) {
    final locale = _normalizeLocale(Locale(languageCode, countryCode));
    _currentLocale.value = locale;

    // 更新应用语言
    Get.updateLocale(locale);

    // 保存设置
    _storage.write('languageCode', languageCode);
    _storage.write('countryCode', countryCode);

    update();
  }

  Locale _normalizeLocale(Locale locale) {
    final localeKey = '${locale.languageCode}_${locale.countryCode}';
    final normalized = _localeAliases[localeKey] ?? localeKey;
    final parts = normalized.split('_');
    if (parts.length != 2) {
      return locale;
    }
    return Locale(parts[0], parts[1]);
  }

  void toggleLanguage() {
    final current = _currentLocale.value;

    // 在支持的语言之间切换
    if (current.languageCode == 'en') {
      changeLanguage('zh', 'CN');
    } else if (current.languageCode == 'zh') {
      changeLanguage('en', 'US');
    } else {
      // 默认切换到英语
      changeLanguage('en', 'US');
    }
  }

  String getLanguageName(Locale locale) {
    // 使用翻译键获取语言自己的文字
    final localeKey = '${locale.languageCode}_${locale.countryCode}';
    final key = 'app.system.language.${_languageNameLookupKey(localeKey)}';
    final translated = key.tr;
    if (translated == key) {
      return localeKey;
    }
    return translated;
  }

  // 获取本地化的语言名称（用于显示在语言列表中）
  String getLocalizedLanguageName(Map<String, String> lang) {
    final code = lang['code'] ?? '';
    final country = lang['country'] ?? '';
    final localeKey = '${code}_$country';

    // 使用翻译键来显示语言自己的文字
    final key = 'app.system.language.${_languageNameLookupKey(localeKey)}';
    final translated = key.tr;
    if (translated == key) {
      return lang['name'] ?? localeKey;
    }
    return translated;
  }

  String _languageNameLookupKey(String localeKey) {
    return _languageNameKeyAliases[localeKey] ?? localeKey;
  }

  // 获取语言图标路径
  String getLanguageIcon(Map<String, String> lang) {
    final icon = lang['icon'] ?? '';
    return 'assets/images/lang/$icon.png';
  }

  // 获取当前语言的图标路径
  String getCurrentLanguageIcon() {
    final current = _normalizeLocale(_currentLocale.value);
    for (var lang in supportedLanguages) {
      if (lang['code'] == current.languageCode &&
          lang['country'] == current.countryCode) {
        return getLanguageIcon(lang);
      }
    }
    return 'assets/images/lang/en_US.png';
  }
}
