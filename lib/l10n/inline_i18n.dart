import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:tronskins_app/l10n/app_translations.dart';

class InlineI18n {
  InlineI18n._();

  static final Map<String, Map<String, String>> _translations =
      AppTranslations().keys;
  static final Map<String, String> _keyByText = _buildKeyIndex();

  static String text({required String zh, required String en}) {
    final fallback = _isChineseLocale ? zh : en;
    final key = _keyByText[_normalize(en)] ?? _keyByText[_normalize(zh)];
    if (key == null) {
      return fallback;
    }

    final localeKey = _currentLocaleKey();
    final translated = _translations[localeKey]?[key];
    if (translated == null || translated.isEmpty || translated == key) {
      return fallback;
    }
    return translated;
  }

  static Map<String, String> _buildKeyIndex() {
    final index = <String, String>{};
    void addMessages(Map<String, String>? messages) {
      if (messages == null) {
        return;
      }
      for (final entry in messages.entries) {
        final normalized = _normalize(entry.value);
        if (normalized.isNotEmpty) {
          index.putIfAbsent(normalized, () => entry.key);
        }
      }
    }

    addMessages(_translations['en_US']);
    addMessages(_translations['zh_CN']);
    return index;
  }

  static String _currentLocaleKey() {
    final locale = Get.locale ?? Get.deviceLocale ?? const Locale('en', 'US');
    final raw = '${locale.languageCode}_${locale.countryCode}';
    return switch (raw) {
      'zh_HK' => 'zh_TW',
      'ge_DE' => 'de_DE',
      'in_ID' => 'id_ID',
      'po_PL' => 'pl_PL',
      'po_PT' => 'pt_PT',
      'sp_ES' => 'es_ES',
      'tu_TR' => 'tr_TR',
      _ => raw,
    };
  }

  static bool get _isChineseLocale {
    final locale = Get.locale ?? Get.deviceLocale;
    return (locale?.languageCode ?? '').toLowerCase().startsWith('zh');
  }

  static String _normalize(String value) {
    return value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
  }
}
