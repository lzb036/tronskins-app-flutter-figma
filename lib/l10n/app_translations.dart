import 'package:get/get.dart';
import 'package:tronskins_app/l10n/gift_card_i18n.dart';
import 'package:tronskins_app/l10n/locale/en_US/app_i18n.dart';
import 'package:tronskins_app/l10n/locale/fr_FR/app_i18n.dart';
import 'package:tronskins_app/l10n/locale/ge_DE/app_i18n.dart';
import 'package:tronskins_app/l10n/locale/in_ID/app_i18n.dart';
import 'package:tronskins_app/l10n/locale/it_IT/app_i18n.dart';
import 'package:tronskins_app/l10n/locale/ja_JP/app_i18n.dart';
import 'package:tronskins_app/l10n/locale/ko_KR/app_i18n.dart';
import 'package:tronskins_app/l10n/locale/la_LAT/app_i18n.dart';
import 'package:tronskins_app/l10n/locale/po_PL/app_i18n.dart';
import 'package:tronskins_app/l10n/locale/po_PT/app_i18n.dart';
import 'package:tronskins_app/l10n/locale/ru_RU/app_i18n.dart';
import 'package:tronskins_app/l10n/locale/sp_ES/app_i18n.dart';
import 'package:tronskins_app/l10n/locale/th_TH/app_i18n.dart';
import 'package:tronskins_app/l10n/locale/tu_TR/app_i18n.dart';
import 'package:tronskins_app/l10n/locale/vi_VN/app_i18n.dart';
import 'package:tronskins_app/l10n/locale/zh_CN/app_i18n.dart';
import 'package:tronskins_app/l10n/locale/zh_TW/app_i18n.dart';

class AppTranslations extends Translations {
  @override
  Map<String, Map<String, String>> get keys {
    final base = <String, Map<String, String>>{
      'en_US': en_US,
      'fr_FR': fr_FR,
      'ge_DE': ge_DE,
      'de_DE': ge_DE,
      'in_ID': in_ID,
      'id_ID': in_ID,
      'it_IT': it_IT,
      'ja_JP': ja_JP,
      'ko_KR': ko_KR,
      'la_LAT': la_LAT,
      'po_PL': po_PL,
      'pl_PL': po_PL,
      'po_PT': po_PT,
      'pt_PT': po_PT,
      'ru_RU': ru_RU,
      'sp_ES': sp_ES,
      'es_ES': sp_ES,
      'th_TH': th_TH,
      'tu_TR': tu_TR,
      'tr_TR': tu_TR,
      'vi_VN': vi_VN,
      'zh_CN': zh_CN,
      'zh_TW': zh_TW,
      'zh_HK': zh_TW,
    };

    return base.map((locale, messages) {
      return MapEntry(locale, {
        ...messages,
        ..._missingMessagesFor(locale),
        ...giftCardMessagesFor(locale),
      });
    });
  }
}

Map<String, String> _missingMessagesFor(String locale) {
  final normalized = switch (locale) {
    'de_DE' => 'ge_DE',
    'id_ID' => 'in_ID',
    'pl_PL' => 'po_PL',
    'pt_PT' => 'po_PT',
    'es_ES' => 'sp_ES',
    'tr_TR' => 'tu_TR',
    'zh_HK' => 'zh_TW',
    _ => locale,
  };

  return {
    ...?_missingMessages[normalized],
    ...?_settingsOverviewMessages[normalized],
    ...?_priceChangeConfirmMessages[normalized],
    ..._messagesWithEnglishFallback(
      _inventoryUpShopConfirmMessages,
      normalized,
    ),
    ..._messagesWithEnglishFallback(_themeSettingsMessages, normalized),
    ..._messagesWithEnglishFallback(_exchangeRateMessages, normalized),
    ..._messagesWithEnglishFallback(_marketBacklogMessages, normalized),
    ..._messagesWithEnglishFallback(_twoFaTokenMessages, normalized),
    ..._messagesWithEnglishFallback(_shopBacklogMessages, normalized),
    ..._messagesWithEnglishFallback(_deliverBacklogMessages, normalized),
    ..._messagesWithEnglishFallback(_purchaseFailureMessages, normalized),
    ..._messagesWithEnglishFallback(_feedbackActionMessages, normalized),
    ..._messagesWithEnglishFallback(_inlineBacklogMessages, normalized),
    ..._messagesWithEnglishFallback(_noticeActionMessages, normalized),
    ..._messagesWithEnglishFallback(_excelBacklogMessages, normalized),
    ...?_rechargeSecurityMessages[normalized],
  };
}

Map<String, String> _messagesWithEnglishFallback(
  Map<String, Map<String, String>> messages,
  String locale,
) {
  return {...?messages['en_US'], ...?messages[locale]};
}

const Map<String, Map<String, String>> _missingMessages = {
  'en_US': {
    'app.user.setting.language.description':
        'Select your preferred language for the gallery experience',
    'app.user.setting.language.apply_notice':
        'Changes will take effect immediately.',
  },
  'zh_CN': {
    'app.user.setting.language.description': '选择您偏好的画廊体验语言',
    'app.user.setting.language.apply_notice': '更改会立即生效。',
  },
  'fr_FR': {
    'app.market.seller_shop.title': 'Boutique du vendeur',
    'app.user.setting.language.description':
        'Choisissez la langue de votre expérience de galerie',
    'app.user.setting.language.apply_notice':
        'Les modifications prennent effet immédiatement.',
    'app.trade.purchase.message.confirm_online_on':
        'Confirmer la mise en ligne de la demande d’achat ?',
    'app.trade.purchase.message.confirm_online_off':
        'Confirmer la mise hors ligne de la demande d’achat ?',
    'app.trade.purchase.message.online_on_success':
        'Demande d’achat mise en ligne avec succès.',
    'app.trade.purchase.message.online_off_success':
        'Demande d’achat mise hors ligne avec succès.',
    'app.trade.purchase.message.online_on_failed':
        'Échec de la mise en ligne de la demande d’achat.',
    'app.trade.purchase.message.online_off_failed':
        'Échec de la mise hors ligne de la demande d’achat.',
  },
  'ge_DE': {
    'app.market.seller_shop.title': 'Verkäufer-Shop',
    'app.user.setting.language.description':
        'Wähle deine bevorzugte Sprache für das Galerie-Erlebnis',
    'app.user.setting.language.apply_notice':
        'Änderungen werden sofort wirksam.',
    'app.trade.purchase.message.confirm_online_on':
        'Kaufgesuch online stellen?',
    'app.trade.purchase.message.confirm_online_off':
        'Kaufgesuch offline nehmen?',
    'app.trade.purchase.message.online_on_success':
        'Kaufgesuch wurde online gestellt.',
    'app.trade.purchase.message.online_off_success':
        'Kaufgesuch wurde offline genommen.',
    'app.trade.purchase.message.online_on_failed':
        'Kaufgesuch konnte nicht online gestellt werden.',
    'app.trade.purchase.message.online_off_failed':
        'Kaufgesuch konnte nicht offline genommen werden.',
  },
  'in_ID': {
    'app.market.seller_shop.title': 'Toko Penjual',
    'app.user.setting.language.description':
        'Pilih bahasa pilihan untuk pengalaman galeri',
    'app.user.setting.language.apply_notice':
        'Perubahan akan langsung diterapkan.',
    'app.trade.purchase.message.confirm_online_on': 'Aktifkan permintaan beli?',
    'app.trade.purchase.message.confirm_online_off':
        'Nonaktifkan permintaan beli?',
    'app.trade.purchase.message.online_on_success':
        'Permintaan beli berhasil diaktifkan.',
    'app.trade.purchase.message.online_off_success':
        'Permintaan beli berhasil dinonaktifkan.',
    'app.trade.purchase.message.online_on_failed':
        'Gagal mengaktifkan permintaan beli.',
    'app.trade.purchase.message.online_off_failed':
        'Gagal menonaktifkan permintaan beli.',
  },
  'it_IT': {
    'app.market.seller_shop.title': 'Negozio venditore',
    'app.user.setting.language.description':
        'Seleziona la lingua preferita per l’esperienza galleria',
    'app.user.setting.language.apply_notice':
        'Le modifiche avranno effetto immediato.',
    'app.trade.purchase.message.confirm_online_on':
        'Confermare la pubblicazione della richiesta di acquisto?',
    'app.trade.purchase.message.confirm_online_off':
        'Confermare la rimozione della richiesta di acquisto?',
    'app.trade.purchase.message.online_on_success':
        'Richiesta di acquisto pubblicata.',
    'app.trade.purchase.message.online_off_success':
        'Richiesta di acquisto rimossa.',
    'app.trade.purchase.message.online_on_failed':
        'Pubblicazione della richiesta di acquisto non riuscita.',
    'app.trade.purchase.message.online_off_failed':
        'Rimozione della richiesta di acquisto non riuscita.',
  },
  'ja_JP': {
    'app.market.seller_shop.title': '出品者ショップ',
    'app.user.setting.language.description': 'ギャラリー体験で使用する言語を選択してください',
    'app.user.setting.language.apply_notice': '変更はすぐに反映されます。',
    'app.trade.purchase.message.confirm_online_on': '買取リクエストを公開しますか？',
    'app.trade.purchase.message.confirm_online_off': '買取リクエストを非公開にしますか？',
    'app.trade.purchase.message.online_on_success': '買取リクエストを公開しました。',
    'app.trade.purchase.message.online_off_success': '買取リクエストを非公開にしました。',
    'app.trade.purchase.message.online_on_failed': '買取リクエストの公開に失敗しました。',
    'app.trade.purchase.message.online_off_failed': '買取リクエストの非公開に失敗しました。',
  },
  'ko_KR': {
    'app.market.seller_shop.title': '판매자 상점',
    'app.user.setting.language.description': '갤러리 경험에 사용할 언어를 선택하세요',
    'app.user.setting.language.apply_notice': '변경 사항은 즉시 적용됩니다.',
    'app.trade.purchase.message.confirm_online_on': '구매 요청을 온라인으로 전환할까요?',
    'app.trade.purchase.message.confirm_online_off': '구매 요청을 오프라인으로 전환할까요?',
    'app.trade.purchase.message.online_on_success': '구매 요청이 온라인으로 전환되었습니다.',
    'app.trade.purchase.message.online_off_success': '구매 요청이 오프라인으로 전환되었습니다.',
    'app.trade.purchase.message.online_on_failed': '구매 요청 온라인 전환에 실패했습니다.',
    'app.trade.purchase.message.online_off_failed': '구매 요청 오프라인 전환에 실패했습니다.',
  },
  'la_LAT': {
    'app.market.seller_shop.title': 'Taberna venditoris',
    'app.user.setting.language.description':
        'Elige linguam malitam ad experientiam porticus',
    'app.user.setting.language.apply_notice': 'Mutationes statim valent.',
    'app.trade.purchase.message.confirm_online_on':
        'Postulationem emendi publicare?',
    'app.trade.purchase.message.confirm_online_off':
        'Postulationem emendi occultare?',
    'app.trade.purchase.message.online_on_success':
        'Postulatio emendi publicata est.',
    'app.trade.purchase.message.online_off_success':
        'Postulatio emendi occultata est.',
    'app.trade.purchase.message.online_on_failed':
        'Postulatio emendi publicari non potuit.',
    'app.trade.purchase.message.online_off_failed':
        'Postulatio emendi occultari non potuit.',
  },
  'po_PL': {
    'app.market.seller_shop.title': 'Sklep sprzedawcy',
    'app.user.setting.language.description':
        'Wybierz preferowany język galerii',
    'app.user.setting.language.apply_notice':
        'Zmiany zostaną zastosowane natychmiast.',
    'app.trade.purchase.message.confirm_online_on': 'Włączyć ofertę kupna?',
    'app.trade.purchase.message.confirm_online_off': 'Wyłączyć ofertę kupna?',
    'app.trade.purchase.message.online_on_success':
        'Oferta kupna została włączona.',
    'app.trade.purchase.message.online_off_success':
        'Oferta kupna została wyłączona.',
    'app.trade.purchase.message.online_on_failed':
        'Nie udało się włączyć oferty kupna.',
    'app.trade.purchase.message.online_off_failed':
        'Nie udało się wyłączyć oferty kupna.',
  },
  'po_PT': {
    'app.market.seller_shop.title': 'Loja do vendedor',
    'app.user.setting.language.description':
        'Selecione o idioma preferido para a experiência de galeria',
    'app.user.setting.language.apply_notice':
        'As alterações entram em vigor imediatamente.',
    'app.trade.purchase.message.confirm_online_on':
        'Confirmar ativação da ordem de compra?',
    'app.trade.purchase.message.confirm_online_off':
        'Confirmar desativação da ordem de compra?',
    'app.trade.purchase.message.online_on_success':
        'Ordem de compra ativada com sucesso.',
    'app.trade.purchase.message.online_off_success':
        'Ordem de compra desativada com sucesso.',
    'app.trade.purchase.message.online_on_failed':
        'Falha ao ativar a ordem de compra.',
    'app.trade.purchase.message.online_off_failed':
        'Falha ao desativar a ordem de compra.',
  },
  'ru_RU': {
    'app.market.seller_shop.title': 'Магазин продавца',
    'app.user.setting.language.description':
        'Выберите предпочитаемый язык для галереи',
    'app.user.setting.language.apply_notice': 'Изменения вступят в силу сразу.',
    'app.trade.purchase.message.confirm_online_on':
        'Включить заявку на покупку?',
    'app.trade.purchase.message.confirm_online_off':
        'Отключить заявку на покупку?',
    'app.trade.purchase.message.online_on_success':
        'Заявка на покупку включена.',
    'app.trade.purchase.message.online_off_success':
        'Заявка на покупку отключена.',
    'app.trade.purchase.message.online_on_failed':
        'Не удалось включить заявку на покупку.',
    'app.trade.purchase.message.online_off_failed':
        'Не удалось отключить заявку на покупку.',
  },
  'sp_ES': {
    'app.market.seller_shop.title': 'Tienda del vendedor',
    'app.user.setting.language.description':
        'Elige tu idioma preferido para la experiencia de galería',
    'app.user.setting.language.apply_notice':
        'Los cambios se aplicarán inmediatamente.',
    'app.trade.purchase.message.confirm_online_on':
        '¿Activar la solicitud de compra?',
    'app.trade.purchase.message.confirm_online_off':
        '¿Desactivar la solicitud de compra?',
    'app.trade.purchase.message.online_on_success':
        'Solicitud de compra activada.',
    'app.trade.purchase.message.online_off_success':
        'Solicitud de compra desactivada.',
    'app.trade.purchase.message.online_on_failed':
        'No se pudo activar la solicitud de compra.',
    'app.trade.purchase.message.online_off_failed':
        'No se pudo desactivar la solicitud de compra.',
  },
  'th_TH': {
    'app.market.seller_shop.title': 'ร้านค้าผู้ขาย',
    'app.user.setting.language.description':
        'เลือกภาษาที่ต้องการสำหรับประสบการณ์แกลเลอรี',
    'app.user.setting.language.apply_notice': 'การเปลี่ยนแปลงจะมีผลทันที',
    'app.trade.purchase.message.confirm_online_on': 'ยืนยันเปิดคำขอซื้อ?',
    'app.trade.purchase.message.confirm_online_off': 'ยืนยันปิดคำขอซื้อ?',
    'app.trade.purchase.message.online_on_success': 'เปิดคำขอซื้อสำเร็จ',
    'app.trade.purchase.message.online_off_success': 'ปิดคำขอซื้อสำเร็จ',
    'app.trade.purchase.message.online_on_failed': 'เปิดคำขอซื้อไม่สำเร็จ',
    'app.trade.purchase.message.online_off_failed': 'ปิดคำขอซื้อไม่สำเร็จ',
  },
  'tu_TR': {
    'app.market.seller_shop.title': 'Satıcı Mağazası',
    'app.user.setting.language.description':
        'Galeri deneyimi için tercih ettiğiniz dili seçin',
    'app.user.setting.language.apply_notice':
        'Değişiklikler hemen geçerli olur.',
    'app.trade.purchase.message.confirm_online_on':
        'Satın alma isteği yayına alınsın mı?',
    'app.trade.purchase.message.confirm_online_off':
        'Satın alma isteği yayından kaldırılsın mı?',
    'app.trade.purchase.message.online_on_success':
        'Satın alma isteği yayına alındı.',
    'app.trade.purchase.message.online_off_success':
        'Satın alma isteği yayından kaldırıldı.',
    'app.trade.purchase.message.online_on_failed':
        'Satın alma isteği yayına alınamadı.',
    'app.trade.purchase.message.online_off_failed':
        'Satın alma isteği yayından kaldırılamadı.',
  },
  'vi_VN': {
    'app.market.seller_shop.title': 'Cửa hàng người bán',
    'app.user.setting.language.description':
        'Chọn ngôn ngữ bạn muốn dùng cho trải nghiệm bộ sưu tập',
    'app.user.setting.language.apply_notice':
        'Thay đổi sẽ có hiệu lực ngay lập tức.',
    'app.trade.purchase.message.confirm_online_on': 'Bật yêu cầu mua?',
    'app.trade.purchase.message.confirm_online_off': 'Tắt yêu cầu mua?',
    'app.trade.purchase.message.online_on_success': 'Đã bật yêu cầu mua.',
    'app.trade.purchase.message.online_off_success': 'Đã tắt yêu cầu mua.',
    'app.trade.purchase.message.online_on_failed': 'Không thể bật yêu cầu mua.',
    'app.trade.purchase.message.online_off_failed':
        'Không thể tắt yêu cầu mua.',
  },
  'zh_TW': {
    'app.market.seller_shop.title': '賣家店鋪',
    'app.user.setting.language.description': '選擇您偏好的畫廊體驗語言',
    'app.user.setting.language.apply_notice': '變更會立即生效。',
  },
};

const Map<String, Map<String, String>> _purchaseFailureMessages = {
  'en_US': {
    'app.trade.buy.message.balance_insufficient':
        'Insufficient balance. Please recharge before buying.',
  },
  'zh_CN': {'app.trade.buy.message.balance_insufficient': '账户余额不足，请先充值后再购买。'},
  'fr_FR': {
    'app.trade.buy.message.balance_insufficient':
        'Solde insuffisant. Veuillez recharger avant d’acheter.',
  },
  'ge_DE': {
    'app.trade.buy.message.balance_insufficient':
        'Unzureichendes Guthaben. Bitte lade vor dem Kauf auf.',
  },
  'in_ID': {
    'app.trade.buy.message.balance_insufficient':
        'Saldo tidak mencukupi. Silakan isi ulang sebelum membeli.',
  },
  'it_IT': {
    'app.trade.buy.message.balance_insufficient':
        'Saldo insufficiente. Ricarica prima di acquistare.',
  },
  'ja_JP': {
    'app.trade.buy.message.balance_insufficient': '残高が不足しています。購入前にチャージしてください。',
  },
  'ko_KR': {
    'app.trade.buy.message.balance_insufficient': '잔액이 부족합니다. 구매 전에 충전해 주세요.',
  },
  'la_LAT': {
    'app.trade.buy.message.balance_insufficient':
        'Saldo insufficiens. Quaeso ante emptionem reple.',
  },
  'po_PL': {
    'app.trade.buy.message.balance_insufficient':
        'Niewystarczające saldo. Doładuj konto przed zakupem.',
  },
  'po_PT': {
    'app.trade.buy.message.balance_insufficient':
        'Saldo insuficiente. Recarregue antes de comprar.',
  },
  'ru_RU': {
    'app.trade.buy.message.balance_insufficient':
        'Недостаточно средств. Пополните баланс перед покупкой.',
  },
  'sp_ES': {
    'app.trade.buy.message.balance_insufficient':
        'Saldo insuficiente. Recarga antes de comprar.',
  },
  'th_TH': {
    'app.trade.buy.message.balance_insufficient':
        'ยอดเงินไม่เพียงพอ กรุณาเติมเงินก่อนซื้อ',
  },
  'tu_TR': {
    'app.trade.buy.message.balance_insufficient':
        'Bakiye yetersiz. Satın almadan önce bakiye yükleyin.',
  },
  'vi_VN': {
    'app.trade.buy.message.balance_insufficient':
        'Số dư không đủ. Vui lòng nạp tiền trước khi mua.',
  },
  'zh_TW': {'app.trade.buy.message.balance_insufficient': '帳戶餘額不足，請先充值後再購買。'},
};

const Map<String, Map<String, String>> _feedbackActionMessages = {
  'en_US': {'app.user.feedback.mark_resolved': 'Mark Resolved'},
  'zh_CN': {'app.user.feedback.mark_resolved': '标记已解决'},
  'fr_FR': {'app.user.feedback.mark_resolved': 'Marquer comme résolu'},
  'ge_DE': {'app.user.feedback.mark_resolved': 'Als gelöst markieren'},
  'in_ID': {'app.user.feedback.mark_resolved': 'Tandai selesai'},
  'it_IT': {'app.user.feedback.mark_resolved': 'Segna come risolto'},
  'ja_JP': {'app.user.feedback.mark_resolved': '解決済みにする'},
  'ko_KR': {'app.user.feedback.mark_resolved': '해결됨으로 표시'},
  'la_LAT': {'app.user.feedback.mark_resolved': 'Marca ut solutum'},
  'po_PL': {'app.user.feedback.mark_resolved': 'Oznacz jako rozwiązane'},
  'po_PT': {'app.user.feedback.mark_resolved': 'Marcar como resolvido'},
  'ru_RU': {'app.user.feedback.mark_resolved': 'Отметить как решено'},
  'sp_ES': {'app.user.feedback.mark_resolved': 'Marcar como resuelto'},
  'th_TH': {'app.user.feedback.mark_resolved': 'ทำเครื่องหมายว่าแก้ไขแล้ว'},
  'tu_TR': {'app.user.feedback.mark_resolved': 'Çözüldü olarak işaretle'},
  'vi_VN': {'app.user.feedback.mark_resolved': 'Đánh dấu đã giải quyết'},
  'zh_TW': {'app.user.feedback.mark_resolved': '標記為已解決'},
};

const Map<String, Map<String, String>> _settingsOverviewMessages = {
  'en_US': {
    'app.user.setting.section.security_account': 'Security & Account',
    'app.user.setting.section.preferences': 'Preferences',
    'app.user.setting.section.support': 'Support',
    'app.user.setting.twofa.active': 'Active',
    'app.user.setting.twofa.inactive': 'Inactive',
    'app.user.setting.auth_test_center': 'Auth Test Center',
  },
  'zh_CN': {
    'app.user.setting.section.security_account': '安全与账户',
    'app.user.setting.section.preferences': '偏好设置',
    'app.user.setting.section.support': '支持',
    'app.user.setting.twofa.active': '已绑定',
    'app.user.setting.twofa.inactive': '未绑定',
    'app.user.setting.auth_test_center': '认证测试中心',
  },
  'fr_FR': {
    'app.user.setting.section.security_account': 'Sécurité et compte',
    'app.user.setting.section.preferences': 'Préférences',
    'app.user.setting.section.support': 'Assistance',
    'app.user.setting.twofa.active': 'Actif',
    'app.user.setting.twofa.inactive': 'Inactif',
    'app.user.setting.auth_test_center': 'Centre de test d’authentification',
  },
  'ge_DE': {
    'app.user.setting.section.security_account': 'Sicherheit & Konto',
    'app.user.setting.section.preferences': 'Präferenzen',
    'app.user.setting.section.support': 'Support',
    'app.user.setting.twofa.active': 'Aktiv',
    'app.user.setting.twofa.inactive': 'Inaktiv',
    'app.user.setting.auth_test_center': 'Authentifizierungstest',
  },
  'in_ID': {
    'app.user.setting.section.security_account': 'Keamanan & Akun',
    'app.user.setting.section.preferences': 'Preferensi',
    'app.user.setting.section.support': 'Dukungan',
    'app.user.setting.twofa.active': 'Aktif',
    'app.user.setting.twofa.inactive': 'Tidak aktif',
    'app.user.setting.auth_test_center': 'Pusat Tes Autentikasi',
  },
  'it_IT': {
    'app.user.setting.section.security_account': 'Sicurezza e account',
    'app.user.setting.section.preferences': 'Preferenze',
    'app.user.setting.section.support': 'Supporto',
    'app.user.setting.twofa.active': 'Attivo',
    'app.user.setting.twofa.inactive': 'Non attivo',
    'app.user.setting.auth_test_center': 'Centro test autenticazione',
  },
  'ja_JP': {
    'app.user.setting.section.security_account': 'セキュリティとアカウント',
    'app.user.setting.section.preferences': '設定',
    'app.user.setting.section.support': 'サポート',
    'app.user.setting.twofa.active': '連携済み',
    'app.user.setting.twofa.inactive': '未連携',
    'app.user.setting.auth_test_center': '認証テストセンター',
  },
  'ko_KR': {
    'app.user.setting.section.security_account': '보안 및 계정',
    'app.user.setting.section.preferences': '환경설정',
    'app.user.setting.section.support': '지원',
    'app.user.setting.twofa.active': '연동됨',
    'app.user.setting.twofa.inactive': '미연동',
    'app.user.setting.auth_test_center': '인증 테스트 센터',
  },
  'la_LAT': {
    'app.user.setting.section.security_account': 'Seguridad y cuenta',
    'app.user.setting.section.preferences': 'Preferencias',
    'app.user.setting.section.support': 'Soporte',
    'app.user.setting.twofa.active': 'Activo',
    'app.user.setting.twofa.inactive': 'Inactivo',
    'app.user.setting.auth_test_center': 'Centro de prueba de autenticación',
  },
  'po_PL': {
    'app.user.setting.section.security_account': 'Bezpieczeństwo i konto',
    'app.user.setting.section.preferences': 'Preferencje',
    'app.user.setting.section.support': 'Wsparcie',
    'app.user.setting.twofa.active': 'Aktywne',
    'app.user.setting.twofa.inactive': 'Nieaktywne',
    'app.user.setting.auth_test_center': 'Centrum testów autoryzacji',
  },
  'po_PT': {
    'app.user.setting.section.security_account': 'Segurança e conta',
    'app.user.setting.section.preferences': 'Preferências',
    'app.user.setting.section.support': 'Suporte',
    'app.user.setting.twofa.active': 'Ativo',
    'app.user.setting.twofa.inactive': 'Inativo',
    'app.user.setting.auth_test_center': 'Centro de teste de autenticação',
  },
  'ru_RU': {
    'app.user.setting.section.security_account': 'Безопасность и аккаунт',
    'app.user.setting.section.preferences': 'Настройки',
    'app.user.setting.section.support': 'Поддержка',
    'app.user.setting.twofa.active': 'Активно',
    'app.user.setting.twofa.inactive': 'Неактивно',
    'app.user.setting.auth_test_center': 'Центр тестирования авторизации',
  },
  'sp_ES': {
    'app.user.setting.section.security_account': 'Seguridad y cuenta',
    'app.user.setting.section.preferences': 'Preferencias',
    'app.user.setting.section.support': 'Soporte',
    'app.user.setting.twofa.active': 'Activo',
    'app.user.setting.twofa.inactive': 'Inactivo',
    'app.user.setting.auth_test_center': 'Centro de prueba de autenticación',
  },
  'th_TH': {
    'app.user.setting.section.security_account': 'ความปลอดภัยและบัญชี',
    'app.user.setting.section.preferences': 'การตั้งค่า',
    'app.user.setting.section.support': 'ความช่วยเหลือ',
    'app.user.setting.twofa.active': 'ผูกแล้ว',
    'app.user.setting.twofa.inactive': 'ยังไม่ผูก',
    'app.user.setting.auth_test_center': 'ศูนย์ทดสอบการยืนยันตัวตน',
  },
  'tu_TR': {
    'app.user.setting.section.security_account': 'Güvenlik ve hesap',
    'app.user.setting.section.preferences': 'Tercihler',
    'app.user.setting.section.support': 'Destek',
    'app.user.setting.twofa.active': 'Aktif',
    'app.user.setting.twofa.inactive': 'Pasif',
    'app.user.setting.auth_test_center': 'Kimlik doğrulama test merkezi',
  },
  'vi_VN': {
    'app.user.setting.section.security_account': 'Bảo mật & tài khoản',
    'app.user.setting.section.preferences': 'Tùy chọn',
    'app.user.setting.section.support': 'Hỗ trợ',
    'app.user.setting.twofa.active': 'Đã liên kết',
    'app.user.setting.twofa.inactive': 'Chưa liên kết',
    'app.user.setting.auth_test_center': 'Trung tâm kiểm thử xác thực',
  },
  'zh_TW': {
    'app.user.setting.section.security_account': '安全與帳戶',
    'app.user.setting.section.preferences': '偏好設定',
    'app.user.setting.section.support': '支援',
    'app.user.setting.twofa.active': '已綁定',
    'app.user.setting.twofa.inactive': '未綁定',
    'app.user.setting.auth_test_center': '認證測試中心',
  },
};

const Map<String, Map<String, String>> _priceChangeConfirmMessages = {
  'en_US': {
    'app.shop.price_change.confirm.title': 'Confirm Price Change',
    'app.shop.price_change.confirm.list_title': 'Price Change List',
    'app.shop.price_change.confirm.item_unit.one': 'item',
    'app.shop.price_change.confirm.item_unit.other': 'items',
    'app.shop.price_change.confirm.action': 'Confirm Change',
  },
  'zh_CN': {
    'app.shop.price_change.confirm.title': '确认改价',
    'app.shop.price_change.confirm.list_title': '改价清单',
    'app.shop.price_change.confirm.item_unit.one': '件',
    'app.shop.price_change.confirm.item_unit.other': '件',
    'app.shop.price_change.confirm.action': '确认改价',
  },
  'fr_FR': {
    'app.shop.price_change.confirm.title': 'Confirmer le changement de prix',
    'app.shop.price_change.confirm.list_title': 'Liste des changements de prix',
    'app.shop.price_change.confirm.item_unit.one': 'article',
    'app.shop.price_change.confirm.item_unit.other': 'articles',
    'app.shop.price_change.confirm.action': 'Confirmer',
  },
  'ge_DE': {
    'app.shop.price_change.confirm.title': 'Preisänderung bestätigen',
    'app.shop.price_change.confirm.list_title': 'Preisänderungsliste',
    'app.shop.price_change.confirm.item_unit.one': 'Artikel',
    'app.shop.price_change.confirm.item_unit.other': 'Artikel',
    'app.shop.price_change.confirm.action': 'Änderung bestätigen',
  },
  'in_ID': {
    'app.shop.price_change.confirm.title': 'Konfirmasi Perubahan Harga',
    'app.shop.price_change.confirm.list_title': 'Daftar Perubahan Harga',
    'app.shop.price_change.confirm.item_unit.one': 'item',
    'app.shop.price_change.confirm.item_unit.other': 'item',
    'app.shop.price_change.confirm.action': 'Konfirmasi Perubahan',
  },
  'it_IT': {
    'app.shop.price_change.confirm.title': 'Conferma modifica prezzo',
    'app.shop.price_change.confirm.list_title': 'Elenco modifiche prezzo',
    'app.shop.price_change.confirm.item_unit.one': 'articolo',
    'app.shop.price_change.confirm.item_unit.other': 'articoli',
    'app.shop.price_change.confirm.action': 'Conferma modifica',
  },
  'ja_JP': {
    'app.shop.price_change.confirm.title': '価格変更を確認',
    'app.shop.price_change.confirm.list_title': '価格変更リスト',
    'app.shop.price_change.confirm.item_unit.one': '点',
    'app.shop.price_change.confirm.item_unit.other': '点',
    'app.shop.price_change.confirm.action': '変更を確認',
  },
  'ko_KR': {
    'app.shop.price_change.confirm.title': '가격 변경 확인',
    'app.shop.price_change.confirm.list_title': '가격 변경 목록',
    'app.shop.price_change.confirm.item_unit.one': '개',
    'app.shop.price_change.confirm.item_unit.other': '개',
    'app.shop.price_change.confirm.action': '변경 확인',
  },
  'la_LAT': {
    'app.shop.price_change.confirm.title': 'Confirmar cambio de precio',
    'app.shop.price_change.confirm.list_title': 'Lista de cambios de precio',
    'app.shop.price_change.confirm.item_unit.one': 'artículo',
    'app.shop.price_change.confirm.item_unit.other': 'artículos',
    'app.shop.price_change.confirm.action': 'Confirmar cambio',
  },
  'po_PL': {
    'app.shop.price_change.confirm.title': 'Potwierdź zmianę ceny',
    'app.shop.price_change.confirm.list_title': 'Lista zmian cen',
    'app.shop.price_change.confirm.item_unit.one': 'przedmiot',
    'app.shop.price_change.confirm.item_unit.other': 'przedmioty',
    'app.shop.price_change.confirm.action': 'Potwierdź zmianę',
  },
  'po_PT': {
    'app.shop.price_change.confirm.title': 'Confirmar alteração de preço',
    'app.shop.price_change.confirm.list_title': 'Lista de alterações de preço',
    'app.shop.price_change.confirm.item_unit.one': 'item',
    'app.shop.price_change.confirm.item_unit.other': 'itens',
    'app.shop.price_change.confirm.action': 'Confirmar alteração',
  },
  'ru_RU': {
    'app.shop.price_change.confirm.title': 'Подтвердить изменение цены',
    'app.shop.price_change.confirm.list_title': 'Список изменений цены',
    'app.shop.price_change.confirm.item_unit.one': 'предмет',
    'app.shop.price_change.confirm.item_unit.other': 'предметов',
    'app.shop.price_change.confirm.action': 'Подтвердить изменение',
  },
  'sp_ES': {
    'app.shop.price_change.confirm.title': 'Confirmar cambio de precio',
    'app.shop.price_change.confirm.list_title': 'Lista de cambios de precio',
    'app.shop.price_change.confirm.item_unit.one': 'artículo',
    'app.shop.price_change.confirm.item_unit.other': 'artículos',
    'app.shop.price_change.confirm.action': 'Confirmar cambio',
  },
  'th_TH': {
    'app.shop.price_change.confirm.title': 'ยืนยันการเปลี่ยนราคา',
    'app.shop.price_change.confirm.list_title': 'รายการเปลี่ยนราคา',
    'app.shop.price_change.confirm.item_unit.one': 'รายการ',
    'app.shop.price_change.confirm.item_unit.other': 'รายการ',
    'app.shop.price_change.confirm.action': 'ยืนยันการเปลี่ยน',
  },
  'tu_TR': {
    'app.shop.price_change.confirm.title': 'Fiyat değişikliğini onayla',
    'app.shop.price_change.confirm.list_title': 'Fiyat değişikliği listesi',
    'app.shop.price_change.confirm.item_unit.one': 'öğe',
    'app.shop.price_change.confirm.item_unit.other': 'öğe',
    'app.shop.price_change.confirm.action': 'Değişikliği onayla',
  },
  'vi_VN': {
    'app.shop.price_change.confirm.title': 'Xác nhận đổi giá',
    'app.shop.price_change.confirm.list_title': 'Danh sách đổi giá',
    'app.shop.price_change.confirm.item_unit.one': 'mặt hàng',
    'app.shop.price_change.confirm.item_unit.other': 'mặt hàng',
    'app.shop.price_change.confirm.action': 'Xác nhận đổi',
  },
  'zh_TW': {
    'app.shop.price_change.confirm.title': '確認改價',
    'app.shop.price_change.confirm.list_title': '改價清單',
    'app.shop.price_change.confirm.item_unit.one': '件',
    'app.shop.price_change.confirm.item_unit.other': '件',
    'app.shop.price_change.confirm.action': '確認改價',
  },
};

const Map<String, Map<String, String>> _inventoryUpShopConfirmMessages = {
  'en_US': {
    'app.inventory.upshop.confirm.title': 'Confirmation Listing',
    'app.inventory.upshop.confirm.list_title': 'Sell Listings',
    'app.inventory.upshop.confirm.item_unit.one': 'item',
    'app.inventory.upshop.confirm.item_unit.other': 'items',
  },
  'zh_CN': {
    'app.inventory.upshop.confirm.title': '确认上架',
    'app.inventory.upshop.confirm.list_title': '销售清单',
    'app.inventory.upshop.confirm.item_unit.one': '件',
    'app.inventory.upshop.confirm.item_unit.other': '件',
  },
  'zh_TW': {
    'app.inventory.upshop.confirm.title': '確認上架',
    'app.inventory.upshop.confirm.list_title': '銷售清單',
    'app.inventory.upshop.confirm.item_unit.one': '件',
    'app.inventory.upshop.confirm.item_unit.other': '件',
  },
};

const Map<String, Map<String, String>> _themeSettingsMessages = {
  'en_US': {
    'app.user.setting.theme.eye_comfort.title': 'Eye Comfort',
    'app.user.setting.theme.eye_comfort.desc':
        'System-wide dark mode can reduce eye strain in low-light environments and save battery on OLED displays.',
    'app.user.setting.theme.custom_schedule.title': 'Custom Scheduling',
    'app.user.setting.theme.custom_schedule.desc':
        'Enable automatic scheduling in System Settings to transition between themes based on local sunrise and sunset.',
    'app.user.setting.theme.apply_notice':
        'Theme changes will take effect immediately',
  },
  'zh_CN': {
    'app.user.setting.theme.eye_comfort.title': '护眼优势',
    'app.user.setting.theme.eye_comfort.desc':
        '系统级深色模式可在低光环境下缓解视疲劳，并为 OLED 设备节省电量。',
    'app.user.setting.theme.custom_schedule.title': '定时切换',
    'app.user.setting.theme.custom_schedule.desc':
        '可在系统设置中开启自动定时，根据当地日出日落时间自动切换主题。',
    'app.user.setting.theme.apply_notice': '主题修改将立即生效',
  },
  'zh_TW': {
    'app.user.setting.theme.eye_comfort.title': '護眼優勢',
    'app.user.setting.theme.eye_comfort.desc':
        '系統級深色模式可在低光環境下緩解視疲勞，並為 OLED 裝置節省電量。',
    'app.user.setting.theme.custom_schedule.title': '定時切換',
    'app.user.setting.theme.custom_schedule.desc':
        '可在系統設定中開啟自動定時，根據當地日出日落時間自動切換主題。',
    'app.user.setting.theme.apply_notice': '主題修改將立即生效',
  },
};

const Map<String, Map<String, String>> _exchangeRateMessages = {
  'en_US': {
    'app.user.setting.exchange_rate.supported_currencies':
        'SUPPORTED CURRENCIES',
    'app.user.setting.exchange_rate.default_currency': 'Default Currency',
    'app.user.setting.exchange_rate.selected_currency': 'Selected Currency',
    'app.user.setting.exchange_rate.selected': 'Selected',
    'app.user.setting.exchange_rate.update_hint':
        'Rates are updated hourly for reference only',
    'app.user.setting.exchange_rate.last_updated': 'Last updated',
  },
  'zh_CN': {
    'app.user.setting.exchange_rate.supported_currencies': '支持币种',
    'app.user.setting.exchange_rate.default_currency': '默认货币',
    'app.user.setting.exchange_rate.selected_currency': '已选择货币',
    'app.user.setting.exchange_rate.selected': '已选择',
    'app.user.setting.exchange_rate.update_hint': '汇率每小时更新，仅供参考',
    'app.user.setting.exchange_rate.last_updated': '最后更新',
  },
  'zh_TW': {
    'app.user.setting.exchange_rate.supported_currencies': '支援幣種',
    'app.user.setting.exchange_rate.default_currency': '預設貨幣',
    'app.user.setting.exchange_rate.selected_currency': '已選擇貨幣',
    'app.user.setting.exchange_rate.selected': '已選擇',
    'app.user.setting.exchange_rate.update_hint': '匯率每小時更新，僅供參考',
    'app.user.setting.exchange_rate.last_updated': '最後更新',
  },
};

const Map<String, Map<String, String>> _twoFaTokenMessages = {
  'en_US': {
    'app.common.done': 'Done',
    'app.common.manage': 'Manage',
    'app.common.send': 'Send',
    'app.user.guard.other_tokens': 'Other User Tokens',
    'app.user.guard.token_refresh_tip':
        'Tokens refresh every 30 seconds. Please ensure device time is synced for accurate generation.',
    'app.user.guard.delete_token_title': 'Delete 2FA Token',
    'app.user.guard.delete_token_message':
        'After deletion, this device can no longer generate codes for this token.',
    'app.user.guard.email_address': 'EMAIL ADDRESS',
    'app.user.guard.verification_code': 'Verification Code',
    'app.user.guard.enter_verification_code': 'Enter verification code',
    'app.user.guard.sync_now': 'Sync Now',
  },
  'zh_CN': {
    'app.common.done': '完成',
    'app.common.manage': '管理',
    'app.common.send': '发送',
    'app.user.guard.other_tokens': '其他用户令牌',
    'app.user.guard.token_refresh_tip': '令牌每30秒刷新一次。请确保设备时间已同步，以便准确生成。',
    'app.user.guard.delete_token_title': '删除 2FA 条目',
    'app.user.guard.delete_token_message': '删除后，此设备将无法继续生成该条目的验证码。',
    'app.user.guard.email_address': '邮箱地址',
    'app.user.guard.verification_code': '验证码',
    'app.user.guard.enter_verification_code': '请输入验证码',
    'app.user.guard.sync_now': '立即同步',
  },
  'zh_TW': {
    'app.common.done': '完成',
    'app.common.manage': '管理',
    'app.common.send': '傳送',
    'app.user.guard.other_tokens': '其他使用者權杖',
    'app.user.guard.token_refresh_tip': '權杖每30秒刷新一次。請確保裝置時間已同步，以便準確生成。',
    'app.user.guard.delete_token_title': '刪除 2FA 條目',
    'app.user.guard.delete_token_message': '刪除後，此裝置將無法繼續生成該條目的驗證碼。',
    'app.user.guard.email_address': '電子郵件地址',
    'app.user.guard.verification_code': '驗證碼',
    'app.user.guard.enter_verification_code': '請輸入驗證碼',
    'app.user.guard.sync_now': '立即同步',
  },
};

const Map<String, Map<String, String>> _marketBacklogMessages = {
  'en_US': {
    'app.market.detail.listed': 'LISTED',
    'app.market.detail.buy_orders_caps': 'BUY ORDERS',
    'app.market.detail.buy_order': 'Buy Order',
    'app.market.detail.listings': 'Listings',
    'app.market.detail.buy_orders': 'Buy Orders',
    'app.market.item.current_price': 'Current',
    'app.market.item.attributes': 'Item Attributes',
    'app.market.item.float_value': 'Wear',
    'app.market.item.rarity': 'Rarity',
    'app.market.item.exterior': 'Exterior',
    'app.market.item.quality': 'Quality',
    'app.market.item.collection': 'Collection',
    'app.market.item.wishlist': 'Wishlist',
    'app.market.item.buy_now': 'Buy Now',
    'app.market.item.pattern_template': 'Pattern Template',
    'app.market.item.skin_number': 'Skin Number',
    'app.market.item.avg_delivery': 'Avg. Delivery',
    'app.market.item.fill_rate': 'Fill Rate',
    'app.market.csgo.wear_unlimited': 'Wear Unlimited',
  },
  'zh_CN': {
    'app.market.detail.listed': '在售',
    'app.market.detail.buy_orders_caps': '求购',
    'app.market.detail.buy_order': '求购',
    'app.market.detail.listings': '在售',
    'app.market.detail.buy_orders': '求购',
    'app.market.item.current_price': '现价',
    'app.market.item.attributes': '物品属性',
    'app.market.item.float_value': '磨损值',
    'app.market.item.rarity': '稀有度',
    'app.market.item.exterior': '外观',
    'app.market.item.quality': '品质',
    'app.market.item.collection': '收藏系列',
    'app.market.item.wishlist': '收藏',
    'app.market.item.buy_now': '立即购买',
    'app.market.item.pattern_template': '图案模板',
    'app.market.item.skin_number': '皮肤编号',
    'app.market.item.avg_delivery': '平均发货',
    'app.market.item.fill_rate': '发货率',
    'app.market.csgo.wear_unlimited': '不限磨损度',
  },
  'zh_TW': {
    'app.market.detail.listed': '在售',
    'app.market.detail.buy_orders_caps': '求購',
    'app.market.detail.buy_order': '求購',
    'app.market.detail.listings': '在售',
    'app.market.detail.buy_orders': '求購',
    'app.market.item.current_price': '現價',
    'app.market.item.attributes': '物品屬性',
    'app.market.item.float_value': '磨損值',
    'app.market.item.rarity': '稀有度',
    'app.market.item.exterior': '外觀',
    'app.market.item.quality': '品質',
    'app.market.item.collection': '收藏系列',
    'app.market.item.wishlist': '收藏',
    'app.market.item.buy_now': '立即購買',
    'app.market.item.pattern_template': '圖案模板',
    'app.market.item.skin_number': '皮膚編號',
    'app.market.item.avg_delivery': '平均發貨',
    'app.market.item.fill_rate': '發貨率',
    'app.market.csgo.wear_unlimited': '不限磨損度',
  },
};

const Map<String, Map<String, String>> _shopBacklogMessages = {
  'en_US': {
    'app.trade.sale.failed': 'Sale Failed',
    'app.shop.tab.on_sale': 'On Sale',
    'app.shop.tab.awaiting_delivery': 'Awaiting Delivery',
    'app.shop.tab.sold': 'My Sales',
    'app.shop.empty.subtitle':
        'Adjust your search or filters, then check back again.',
    'app.shop.empty.on_sale': 'No items on sale',
    'app.shop.empty.pending': 'No pending deliveries',
    'app.shop.empty.sale_record': 'No sales records',
    'app.shop.delist.title': 'Confirm Delisting',
    'app.shop.delist.confirm_action': 'Confirm Delisting',
    'app.shop.setting.official_vendor': 'Official Vendor',
  },
  'zh_CN': {
    'app.trade.sale.failed': '出售失败',
    'app.shop.tab.on_sale': '在售',
    'app.shop.tab.awaiting_delivery': '待发货',
    'app.shop.tab.sold': '出售记录',
    'app.shop.empty.subtitle': '调整搜索或筛选条件后，再回来看看。',
    'app.shop.empty.on_sale': '暂无在售饰品',
    'app.shop.empty.pending': '暂无待发货订单',
    'app.shop.empty.sale_record': '暂无出售记录',
    'app.shop.delist.title': '确认下架',
    'app.shop.delist.confirm_action': '确认下架',
    'app.shop.setting.official_vendor': '官方认证卖家',
  },
  'zh_TW': {
    'app.trade.sale.failed': '出售失敗',
    'app.shop.tab.on_sale': '在售',
    'app.shop.tab.awaiting_delivery': '待發貨',
    'app.shop.tab.sold': '出售記錄',
    'app.shop.empty.subtitle': '調整搜尋或篩選條件後，再回來看看。',
    'app.shop.empty.on_sale': '暫無在售飾品',
    'app.shop.empty.pending': '暫無待發貨訂單',
    'app.shop.empty.sale_record': '暫無出售記錄',
    'app.shop.delist.title': '確認下架',
    'app.shop.delist.confirm_action': '確認下架',
    'app.shop.setting.official_vendor': '官方認證賣家',
  },
};

const Map<String, Map<String, String>> _deliverBacklogMessages = {
  'en_US': {
    'app.trade.deliver.drawer_title': 'Delivery Goods',
    'app.trade.deliver.steam_guard_tip':
        'When confirming in Steam Guard, carefully verify the buyer Steam account and item information.',
    'app.trade.deliver.steam_buyer': 'Steam Buyer',
    'app.trade.deliver.list_summary': 'LIST SUMMARY',
    'app.trade.deliver.mobile_confirm_notice':
        'STEAM MOBILE CONFIRMATION REQUIRED\nAPI KEY VERIFIED SECURE',
    'app.market.item.wear': 'Wear',
    'app.trade.supply.message.confirm':
        'After confirming the supply, you must initiate a quotation within 30 minutes. Do you want to proceed to dispatch?',
  },
  'zh_CN': {
    'app.trade.deliver.drawer_title': '发货详情',
    'app.trade.deliver.steam_guard_tip':
        '在 Steam 令牌确认时，请仔细核对买家的 Steam 账号与商品信息。',
    'app.trade.deliver.steam_buyer': 'Steam 买家',
    'app.trade.deliver.list_summary': '清单摘要',
    'app.trade.deliver.mobile_confirm_notice':
        '需要前往 STEAM 手机端确认\nAPI KEY 已安全验证',
    'app.market.item.wear': '磨损度',
    'app.trade.supply.message.confirm': '确认供应后，需在30分钟内发起报价，是否前往发货？',
  },
  'zh_TW': {
    'app.trade.deliver.drawer_title': '發貨詳情',
    'app.trade.deliver.steam_guard_tip':
        '在 Steam 權杖確認時，請仔細核對買家的 Steam 帳號與商品資訊。',
    'app.trade.deliver.steam_buyer': 'Steam 買家',
    'app.trade.deliver.list_summary': '清單摘要',
    'app.trade.deliver.mobile_confirm_notice':
        '需要前往 STEAM 手機端確認\nAPI KEY 已安全驗證',
    'app.market.item.wear': '磨損度',
    'app.trade.supply.message.confirm': '確認供應後，需在30分鐘內發起報價，是否前往發貨？',
  },
};

const Map<String, Map<String, String>> _inlineBacklogMessages = {
  'en_US': {
    'app.inline.shop_setting.saved': 'Shop settings saved',
    'app.inline.shop_setting.synced': 'Shop information synced',
    'app.inline.shop_setting.online': 'Online',
    'app.inline.shop_setting.offline': 'Offline',
    'app.inline.shop_setting.current': 'Current: ',
    'app.inline.shop_setting.custom': 'Custom',
    'app.inline.shop_setting.business_status': 'Business status',
    'app.inline.shop_setting.last_update': 'LAST UPDATE',
    'app.inline.shop_setting.unset': 'Unset',
    'app.inline.shop_setting.stop_after_inactivity':
        'Stop selling after inactivity',
    'app.inline.shop_setting.expected_offline': 'EXPECTED OFFLINE',
    'app.inline.shop_setting.idle_time': 'IDLE TIME',
    'app.inline.shop_setting.important_notice': 'Important notice',
    'app.inline.shop_setting.offline_notice':
        'When your shop is offline, all listed items will be hidden from the market automatically. Enable auto offline to protect your trading activity.',
    'app.inline.shop_setting.save_settings': 'Save Settings',
    'app.inline.shop_setting.auto_offline': 'Auto offline',
    'app.inline.shop_setting.custom_idle_duration': 'Custom idle duration',
    'app.inline.shop_setting.hours': 'Hours',
    'app.inline.shop_setting.hour_unit': 'h',
    'app.inline.shop_setting.minutes': 'Minutes',
    'app.inline.shop_setting.minute_unit': 'min',
    'app.inline.shop_setting.duration_hint':
        'Used to stop selling after inactivity. After applying, we return to shop settings and keep this duration in the current draft.',
    'app.inline.shop_setting.apply_duration': 'Apply duration',
    'app.inline.buying.terminate_title': 'Terminate Buy Request',
    'app.inline.buying.terminate_action': 'Confirm Termination',
    'app.inline.buying.terminate_prefix':
        'Are you sure you want to terminate the buy request for ',
    'app.inline.buying.terminate_suffix':
        '? The funds will be unfrozen upon termination.',
    'app.inline.order.deliver_now': 'Deliver Now',
    'app.inline.order.order_type': 'Order Type',
    'app.inline.wallet.highest_buy_order': 'Highest Buy Order',
    'app.inline.collection.default': 'Default',
  },
  'zh_CN': {
    'app.inline.shop_setting.saved': '店铺设置已保存',
    'app.inline.shop_setting.synced': '店铺信息已同步',
    'app.inline.shop_setting.online': '在线',
    'app.inline.shop_setting.offline': '离线',
    'app.inline.shop_setting.current': '目前状态: ',
    'app.inline.shop_setting.custom': '自定义',
    'app.inline.shop_setting.business_status': '营业状态',
    'app.inline.shop_setting.last_update': '同步时间',
    'app.inline.shop_setting.unset': '未设置',
    'app.inline.shop_setting.stop_after_inactivity': '无操作后自动停止营业',
    'app.inline.shop_setting.expected_offline': '预计离线',
    'app.inline.shop_setting.idle_time': '无操作时长',
    'app.inline.shop_setting.important_notice': '重要通知',
    'app.inline.shop_setting.offline_notice':
        '当您的店铺处于离线状态时，所有已上架的商品将自动在市场中隐藏。建议开启自动离线功能以保护您的交易活跃度。',
    'app.inline.shop_setting.save_settings': '保存设置',
    'app.inline.shop_setting.auto_offline': '自动离线',
    'app.inline.shop_setting.custom_idle_duration': '自定义离线时长',
    'app.inline.shop_setting.hours': '小时',
    'app.inline.shop_setting.hour_unit': '时',
    'app.inline.shop_setting.minutes': '分钟',
    'app.inline.shop_setting.minute_unit': '分',
    'app.inline.shop_setting.duration_hint':
        '用于无操作后自动停止营业。确认后会回到店铺设置页，并把这里选中的时长写入当前草稿。',
    'app.inline.shop_setting.apply_duration': '确认选择',
    'app.inline.buying.terminate_title': '终止求购',
    'app.inline.buying.terminate_action': '确认终止',
    'app.inline.buying.terminate_prefix': '你确定要终止对 ',
    'app.inline.buying.terminate_suffix': ' 吗？终止后资金将解除冻结。',
    'app.inline.order.deliver_now': '立即发货',
    'app.inline.order.order_type': '订单类型',
    'app.inline.wallet.highest_buy_order': '求购最高价',
    'app.inline.collection.default': '默认排序',
  },
  'zh_TW': {
    'app.inline.shop_setting.saved': '店鋪設定已保存',
    'app.inline.shop_setting.synced': '店鋪資訊已同步',
    'app.inline.shop_setting.online': '在線',
    'app.inline.shop_setting.offline': '離線',
    'app.inline.shop_setting.current': '目前狀態: ',
    'app.inline.shop_setting.custom': '自訂',
    'app.inline.shop_setting.business_status': '營業狀態',
    'app.inline.shop_setting.last_update': '同步時間',
    'app.inline.shop_setting.unset': '未設定',
    'app.inline.shop_setting.stop_after_inactivity': '無操作後自動停止營業',
    'app.inline.shop_setting.expected_offline': '預計離線',
    'app.inline.shop_setting.idle_time': '無操作時長',
    'app.inline.shop_setting.important_notice': '重要通知',
    'app.inline.shop_setting.offline_notice':
        '當您的店鋪處於離線狀態時，所有已上架的商品將自動在市場中隱藏。建議開啟自動離線功能以保護您的交易活躍度。',
    'app.inline.shop_setting.save_settings': '保存設定',
    'app.inline.shop_setting.auto_offline': '自動離線',
    'app.inline.shop_setting.custom_idle_duration': '自訂離線時長',
    'app.inline.shop_setting.hours': '小時',
    'app.inline.shop_setting.hour_unit': '時',
    'app.inline.shop_setting.minutes': '分鐘',
    'app.inline.shop_setting.minute_unit': '分',
    'app.inline.shop_setting.duration_hint':
        '用於無操作後自動停止營業。確認後會回到店鋪設定頁，並把這裡選中的時長寫入目前草稿。',
    'app.inline.shop_setting.apply_duration': '確認選擇',
    'app.inline.buying.terminate_title': '終止求購',
    'app.inline.buying.terminate_action': '確認終止',
    'app.inline.buying.terminate_prefix': '你確定要終止對 ',
    'app.inline.buying.terminate_suffix': ' 嗎？終止後資金將解除凍結。',
    'app.inline.order.deliver_now': '立即發貨',
    'app.inline.order.order_type': '訂單類型',
    'app.inline.wallet.highest_buy_order': '求購最高價',
    'app.inline.collection.default': '預設排序',
  },
};

const Map<String, Map<String, String>> _noticeActionMessages = {
  'en_US': {
    'app.system.notice.delete_tips':
        'Are you sure you want to delete this notification?',
  },
  'zh_CN': {'app.system.notice.delete_tips': '确认删除这条通知吗？'},
  'zh_TW': {'app.system.notice.delete_tips': '確認刪除這條通知嗎？'},
};

const Map<String, Map<String, String>> _excelBacklogMessages = {
  'en_US': {
    'app.tabbar.market': 'Market',
    'app.market.empty.title': 'No items found',
    'app.market.empty.subtitle':
        'Try pulling down to refresh or adjust your search and filters.',
    'app.trade.filter.failed': 'Failed',
    'app.user.setting.language.description':
        'Select your preferred language for the market experience',
    'app.market.product.cooling': 'On Cooldown',
    'app.user.collection.message.success': 'Added to Favorites',
    'app.user.collection.uncollect_success': 'Removed from Favorites',
    'app.user.shop.setting': 'Shop Settings',
    'app.shop.title': 'My Sales',
    'app.shop.tab.awaiting_delivery': 'Pending',
    'app.shop.tab.sold': 'My Sales',
    'app.trade.sale.success': 'Sale Successful',
    'app.trade.sale.failed': 'Sale Failed',
    'app.shop.empty.pending': 'No pending deliveries',
    'app.shop.empty.sale_record': 'No sales records',
    'app.shop.delist.title': 'Confirm Delisting',
    'app.shop.delist.message': 'Are you sure you want to delist these items?',
    'app.shop.delist.confirm_action': 'Confirm Delisting',
    'app.shop.status.delisted': 'Delisted',
    'app.shop.status.online': 'Online',
    'app.shop.status.offline': 'Offline',
    'app.shop.status.current_prefix': 'Current: ',
    'app.market.detail.page_title': 'Listing Details',
    'app.market.product.details': 'Item Details',
    'app.market.detail.accepted_patterns': 'Style',
    'app.market.detail.no_requirement': 'No requirement',
    'app.market.buyer': 'Buyer',
    'app.market.item.stickers': 'Containing Stickers',
    'app.market.item.sticker': 'Sticker',
    'app.market.item.gem': 'Gem',
    'app.market.item.keychains': 'Keychains',
    'app.market.item.keychains_contains': 'Includes keychains',
    'app.market.item.minutes.zero': '0 mins',
    'app.market.item.minutes.less_than_two': '< 2 mins',
    'app.market.item.minutes.suffix': ' mins',
    'app.inventory.pricing_preset.min': 'Min',
    'app.inventory.pricing_preset.pricing': 'Pricing',
    'app.inventory.pricing_preset.max': 'Max',
    'app.inventory.upshop.text': 'List',
    'app.inventory.message.confirm_delist':
        'Are you sure you want to delist these items?',
    'app.market.detail.sale_lowest': 'Lowest Listed Price',
    'app.market.detail.purchase_highest': 'Highest Buy Order',
    'app.market.filter.csgo.wear_interval': 'Wear Range',
    'app.market.detail.bulk_buying.match.one': 'match',
    'app.market.detail.bulk_buying.match.other': 'matches',
    'app.trade.purchase.num': 'Purchase Quantity',
    'app.trade.order.total_price': 'Total Price',
    'app.inventory.upshop.handling_charge': 'Service Fee',
    'app.inline.shop_setting.business_status': 'Shop Status',
    'app.inline.shop_setting.expected_offline': 'EXPECTED OFFLINE',
    'app.inline.shop_setting.idle_time': 'RESIDUAL TIME',
    'app.inline.shop_setting.offline_notice':
        'When your store goes offline, your listed items will be hidden and unavailable for purchase. Paid items will not be affected.',
    'app.inline.buying.terminate_title': 'Terminate Purchase Request',
    'app.inline.buying.terminate_action': 'Confirm Termination',
    'app.inline.buying.terminate_prefix':
        'Are you sure you want to terminate this purchase request for ',
    'app.inline.buying.terminate_suffix': '?',
    'app.trade.purchase.terminate': 'Terminate',
    'app.inline.order.deliver_now': 'Deliver Now',
    'app.trade.notice.ready_to_deliver': 'Ready to Deliver',
    'app.trade.notice.deliver_now': 'Deliver Now',
    'app.common.yes': 'Yes',
    'app.common.no': 'No',
  },
  'fr_FR': {
    'app.market.detail.accepted_patterns': 'Style',
    'app.market.detail.no_requirement': 'Aucune exigence',
    'app.trade.purchase.terminate': 'Terminer',
  },
  'ge_DE': {
    'app.market.detail.accepted_patterns': 'Stil',
    'app.market.detail.no_requirement': 'Keine Anforderung',
    'app.trade.purchase.terminate': 'Beenden',
  },
  'in_ID': {
    'app.market.detail.accepted_patterns': 'Gaya',
    'app.market.detail.no_requirement': 'Tidak ada persyaratan',
    'app.trade.purchase.terminate': 'Hentikan',
  },
  'it_IT': {
    'app.market.detail.accepted_patterns': 'Stile',
    'app.market.detail.no_requirement': 'Nessun requisito',
    'app.trade.purchase.terminate': 'Termina',
  },
  'ja_JP': {
    'app.market.detail.accepted_patterns': 'スタイル',
    'app.market.detail.no_requirement': '条件なし',
    'app.trade.purchase.terminate': '終了',
  },
  'ko_KR': {
    'app.market.detail.accepted_patterns': '스타일',
    'app.market.detail.no_requirement': '요구 사항 없음',
    'app.trade.purchase.terminate': '종료',
  },
  'la_LAT': {
    'app.market.detail.accepted_patterns': 'Estilo',
    'app.market.detail.no_requirement': 'Sin requisitos',
    'app.trade.purchase.terminate': 'Terminar',
  },
  'po_PL': {
    'app.market.detail.accepted_patterns': 'Styl',
    'app.market.detail.no_requirement': 'Brak wymagań',
    'app.trade.purchase.terminate': 'Zakończ',
  },
  'po_PT': {
    'app.market.detail.accepted_patterns': 'Estilo',
    'app.market.detail.no_requirement': 'Sem requisito',
    'app.trade.purchase.terminate': 'Terminar',
  },
  'ru_RU': {
    'app.market.detail.accepted_patterns': 'Стиль',
    'app.market.detail.no_requirement': 'Без требований',
    'app.trade.purchase.terminate': 'Прекратить',
  },
  'sp_ES': {
    'app.market.detail.accepted_patterns': 'Estilo',
    'app.market.detail.no_requirement': 'Sin requisitos',
    'app.trade.purchase.terminate': 'Terminar',
  },
  'th_TH': {
    'app.market.detail.accepted_patterns': 'รูปแบบ',
    'app.market.detail.no_requirement': 'ไม่มีข้อกำหนด',
    'app.trade.purchase.terminate': 'ยุติ',
  },
  'tu_TR': {
    'app.market.detail.accepted_patterns': 'Stil',
    'app.market.detail.no_requirement': 'Gereksinim yok',
    'app.trade.purchase.terminate': 'Sonlandır',
  },
  'vi_VN': {
    'app.market.detail.accepted_patterns': 'Kiểu',
    'app.market.detail.no_requirement': 'Không yêu cầu',
    'app.trade.purchase.terminate': 'Chấm dứt',
  },
  'zh_CN': {
    'app.tabbar.market': '饰品市场',
    'app.market.empty.title': '暂无饰品数据',
    'app.market.empty.subtitle': '可以尝试下拉刷新，或调整搜索与筛选条件。',
    'app.trade.filter.failed': '失败',
    'app.user.setting.language.description': '选择偏好语言，优化浏览体验',
    'app.market.product.cooling': '冷却中',
    'app.user.collection.message.success': '已添加到收藏',
    'app.user.collection.uncollect_success': '已从收藏中移除',
    'app.user.shop.setting': '店铺设置',
    'app.shop.title': '我的店铺',
    'app.shop.tab.awaiting_delivery': '待发货',
    'app.shop.tab.sold': '出售记录',
    'app.trade.sale.success': '出售成功',
    'app.trade.sale.failed': '出售失败',
    'app.shop.empty.pending': '暂无待发货订单',
    'app.shop.empty.sale_record': '暂无出售记录',
    'app.shop.delist.title': '确认下架',
    'app.shop.delist.message': '确定要下架这些饰品吗？',
    'app.shop.delist.confirm_action': '确认下架',
    'app.shop.status.delisted': '已下架',
    'app.shop.status.online': '在线',
    'app.shop.status.offline': '离线',
    'app.shop.status.current_prefix': '目前状态: ',
    'app.market.detail.page_title': '饰品详情',
    'app.market.product.details': '饰品详情',
    'app.market.detail.accepted_patterns': '款式',
    'app.market.detail.no_requirement': '无要求',
    'app.market.buyer': '买家',
    'app.market.item.stickers': '包含印花',
    'app.market.item.sticker': '印花',
    'app.market.item.gem': '宝石',
    'app.market.item.keychains': '挂件',
    'app.market.item.keychains_contains': '包含挂件',
    'app.market.item.minutes.zero': '0 分钟',
    'app.market.item.minutes.less_than_two': '< 2 分钟',
    'app.market.item.minutes.suffix': ' 分钟',
    'app.inventory.pricing_preset.min': '最低',
    'app.inventory.pricing_preset.pricing': '定价',
    'app.inventory.pricing_preset.max': '最高',
    'app.inventory.upshop.text': '上架',
    'app.inventory.message.confirm_delist': '确定要下架这些饰品吗？',
    'app.market.detail.sale_lowest': '在售最低价',
    'app.market.detail.purchase_highest': '求购最高价',
    'app.market.filter.csgo.wear_interval': '磨损范围',
    'app.market.detail.bulk_buying.match.one': '件符合',
    'app.market.detail.bulk_buying.match.other': '件符合',
    'app.trade.purchase.num': '购买数量',
    'app.trade.order.total_price': '商品总价',
    'app.inventory.upshop.handling_charge': '服务费',
    'app.inline.shop_setting.business_status': '店铺状态',
    'app.inline.shop_setting.expected_offline': '预计离线',
    'app.inline.shop_setting.idle_time': '剩余时间',
    'app.inline.shop_setting.offline_notice':
        '店铺离线后，你上架中的饰品将被隐藏且无法被购买，已付款的饰品不受影响。',
    'app.inline.buying.terminate_title': '终止求购',
    'app.inline.buying.terminate_action': '确认终止',
    'app.inline.buying.terminate_prefix': '你确定要终止 ',
    'app.inline.buying.terminate_suffix': ' 的本次求购吗？',
    'app.trade.purchase.terminate': '终止求购',
    'app.inline.order.deliver_now': '立即发货',
    'app.trade.notice.ready_to_deliver': '准备发货',
    'app.trade.notice.deliver_now': '立即发货',
    'app.common.yes': '是',
    'app.common.no': '否',
  },
  'zh_TW': {
    'app.tabbar.market': '飾品市場',
    'app.market.empty.title': '暫無飾品資料',
    'app.market.empty.subtitle': '可以嘗試下拉重新整理，或調整搜尋與篩選條件。',
    'app.trade.filter.failed': '失敗',
    'app.user.setting.language.description': '選擇偏好語言，優化瀏覽體驗',
    'app.market.product.cooling': '冷卻中',
    'app.user.collection.message.success': '已加入收藏',
    'app.user.collection.uncollect_success': '已從收藏中移除',
    'app.user.shop.setting': '店鋪設定',
    'app.shop.title': '我的店鋪',
    'app.shop.tab.awaiting_delivery': '待發貨',
    'app.shop.tab.sold': '出售記錄',
    'app.trade.sale.success': '出售成功',
    'app.trade.sale.failed': '出售失敗',
    'app.shop.empty.pending': '暫無待發貨訂單',
    'app.shop.empty.sale_record': '暫無出售記錄',
    'app.shop.delist.title': '確認下架',
    'app.shop.delist.message': '確定要下架這些飾品嗎？',
    'app.shop.delist.confirm_action': '確認下架',
    'app.shop.status.delisted': '已下架',
    'app.shop.status.online': '在線',
    'app.shop.status.offline': '離線',
    'app.shop.status.current_prefix': '目前狀態: ',
    'app.market.detail.page_title': '飾品詳情',
    'app.market.product.details': '飾品詳情',
    'app.market.detail.accepted_patterns': '款式',
    'app.market.detail.no_requirement': '無要求',
    'app.market.buyer': '買家',
    'app.market.item.stickers': '包含印花',
    'app.market.item.sticker': '印花',
    'app.market.item.gem': '寶石',
    'app.market.item.keychains': '掛件',
    'app.market.item.keychains_contains': '包含掛件',
    'app.market.item.minutes.zero': '0 分鐘',
    'app.market.item.minutes.less_than_two': '< 2 分鐘',
    'app.market.item.minutes.suffix': ' 分鐘',
    'app.inventory.pricing_preset.min': '最低',
    'app.inventory.pricing_preset.pricing': '定價',
    'app.inventory.pricing_preset.max': '最高',
    'app.inventory.upshop.text': '上架',
    'app.inventory.message.confirm_delist': '確定要下架這些飾品嗎？',
    'app.market.detail.sale_lowest': '在售最低價',
    'app.market.detail.purchase_highest': '求購最高價',
    'app.market.filter.csgo.wear_interval': '磨損範圍',
    'app.market.detail.bulk_buying.match.one': '件符合',
    'app.market.detail.bulk_buying.match.other': '件符合',
    'app.trade.purchase.num': '購買數量',
    'app.trade.order.total_price': '商品總價',
    'app.inventory.upshop.handling_charge': '服務費',
    'app.inline.shop_setting.business_status': '店鋪狀態',
    'app.inline.shop_setting.expected_offline': '預計離線',
    'app.inline.shop_setting.idle_time': '剩餘時間',
    'app.inline.shop_setting.offline_notice':
        '店鋪離線後，你上架中的飾品將被隱藏且無法被購買，已付款的飾品不受影響。',
    'app.inline.buying.terminate_title': '終止求購',
    'app.inline.buying.terminate_action': '確認終止',
    'app.inline.buying.terminate_prefix': '你確定要終止 ',
    'app.inline.buying.terminate_suffix': ' 的本次求購嗎？',
    'app.trade.purchase.terminate': '終止求購',
    'app.inline.order.deliver_now': '立即發貨',
    'app.trade.notice.ready_to_deliver': '準備發貨',
    'app.trade.notice.deliver_now': '立即發貨',
    'app.common.yes': '是',
    'app.common.no': '否',
  },
};

const Map<String, Map<String, String>> _rechargeSecurityMessages = {
  'en_US': {
    'app.user.recharge.security.payment': 'Secure Payment',
    'app.user.recharge.security.encrypted.title': 'Encrypted',
    'app.user.recharge.security.encrypted.desc': 'SSL 256-bit encryption',
    'app.user.recharge.security.fast_arrival.title': 'Fast arrival',
    'app.user.recharge.security.fast_arrival.desc':
        'Arrives after confirmation',
  },
  'zh_CN': {
    'app.user.recharge.security.payment': '安全支付',
    'app.user.recharge.security.encrypted.title': '加密',
    'app.user.recharge.security.encrypted.desc': 'SSL 256 位加密',
    'app.user.recharge.security.fast_arrival.title': '快速到账',
    'app.user.recharge.security.fast_arrival.desc': '确认后到账',
  },
  'fr_FR': {
    'app.user.recharge.security.payment': 'Paiement sécurisé',
    'app.user.recharge.security.encrypted.title': 'Chiffré',
    'app.user.recharge.security.encrypted.desc': 'Chiffrement SSL 256 bits',
    'app.user.recharge.security.fast_arrival.title': 'Arrivée rapide',
    'app.user.recharge.security.fast_arrival.desc':
        'Crédité après confirmation',
  },
  'ge_DE': {
    'app.user.recharge.security.payment': 'Sichere Zahlung',
    'app.user.recharge.security.encrypted.title': 'Verschlüsselt',
    'app.user.recharge.security.encrypted.desc': 'SSL-256-Bit-Verschlüsselung',
    'app.user.recharge.security.fast_arrival.title': 'Schnelle Gutschrift',
    'app.user.recharge.security.fast_arrival.desc':
        'Nach Bestätigung gutgeschrieben',
  },
  'in_ID': {
    'app.user.recharge.security.payment': 'Pembayaran aman',
    'app.user.recharge.security.encrypted.title': 'Terenkripsi',
    'app.user.recharge.security.encrypted.desc': 'Enkripsi SSL 256-bit',
    'app.user.recharge.security.fast_arrival.title': 'Cepat masuk',
    'app.user.recharge.security.fast_arrival.desc': 'Masuk setelah konfirmasi',
  },
  'it_IT': {
    'app.user.recharge.security.payment': 'Pagamento sicuro',
    'app.user.recharge.security.encrypted.title': 'Crittografato',
    'app.user.recharge.security.encrypted.desc': 'Crittografia SSL a 256 bit',
    'app.user.recharge.security.fast_arrival.title': 'Accredito rapido',
    'app.user.recharge.security.fast_arrival.desc':
        'Accredito dopo la conferma',
  },
  'ja_JP': {
    'app.user.recharge.security.payment': '安全な決済',
    'app.user.recharge.security.encrypted.title': '暗号化',
    'app.user.recharge.security.encrypted.desc': 'SSL 256ビット暗号化',
    'app.user.recharge.security.fast_arrival.title': 'すばやく反映',
    'app.user.recharge.security.fast_arrival.desc': '確認後に反映',
  },
  'ko_KR': {
    'app.user.recharge.security.payment': '안전 결제',
    'app.user.recharge.security.encrypted.title': '암호화됨',
    'app.user.recharge.security.encrypted.desc': 'SSL 256비트 암호화',
    'app.user.recharge.security.fast_arrival.title': '빠른 입금',
    'app.user.recharge.security.fast_arrival.desc': '확인 후 입금',
  },
  'la_LAT': {
    'app.user.recharge.security.payment': 'Solutio tuta',
    'app.user.recharge.security.encrypted.title': 'Encryptum',
    'app.user.recharge.security.encrypted.desc': 'SSL 256-bit encryptio',
    'app.user.recharge.security.fast_arrival.title': 'Adventus celer',
    'app.user.recharge.security.fast_arrival.desc':
        'Post confirmationem pervenit',
  },
  'po_PL': {
    'app.user.recharge.security.payment': 'Bezpieczna płatność',
    'app.user.recharge.security.encrypted.title': 'Szyfrowane',
    'app.user.recharge.security.encrypted.desc': 'Szyfrowanie SSL 256-bit',
    'app.user.recharge.security.fast_arrival.title': 'Szybkie księgowanie',
    'app.user.recharge.security.fast_arrival.desc':
        'Księgowane po potwierdzeniu',
  },
  'po_PT': {
    'app.user.recharge.security.payment': 'Pagamento seguro',
    'app.user.recharge.security.encrypted.title': 'Encriptado',
    'app.user.recharge.security.encrypted.desc': 'Encriptação SSL de 256 bits',
    'app.user.recharge.security.fast_arrival.title': 'Chegada rápida',
    'app.user.recharge.security.fast_arrival.desc': 'Entra após confirmação',
  },
  'ru_RU': {
    'app.user.recharge.security.payment': 'Безопасный платеж',
    'app.user.recharge.security.encrypted.title': 'Зашифровано',
    'app.user.recharge.security.encrypted.desc': 'SSL-шифрование 256 бит',
    'app.user.recharge.security.fast_arrival.title': 'Быстрое зачисление',
    'app.user.recharge.security.fast_arrival.desc': 'После подтверждения',
  },
  'sp_ES': {
    'app.user.recharge.security.payment': 'Pago seguro',
    'app.user.recharge.security.encrypted.title': 'Cifrado',
    'app.user.recharge.security.encrypted.desc': 'Cifrado SSL de 256 bits',
    'app.user.recharge.security.fast_arrival.title': 'Llegada rápida',
    'app.user.recharge.security.fast_arrival.desc':
        'Llega tras la confirmación',
  },
  'th_TH': {
    'app.user.recharge.security.payment': 'ชำระเงินปลอดภัย',
    'app.user.recharge.security.encrypted.title': 'เข้ารหัส',
    'app.user.recharge.security.encrypted.desc': 'การเข้ารหัส SSL 256 บิต',
    'app.user.recharge.security.fast_arrival.title': 'เข้าบัญชีเร็ว',
    'app.user.recharge.security.fast_arrival.desc': 'เข้าหลังยืนยัน',
  },
  'tu_TR': {
    'app.user.recharge.security.payment': 'Güvenli ödeme',
    'app.user.recharge.security.encrypted.title': 'Şifreli',
    'app.user.recharge.security.encrypted.desc': 'SSL 256 bit şifreleme',
    'app.user.recharge.security.fast_arrival.title': 'Hızlı aktarım',
    'app.user.recharge.security.fast_arrival.desc': 'Onaydan sonra aktarılır',
  },
  'vi_VN': {
    'app.user.recharge.security.payment': 'Thanh toán an toàn',
    'app.user.recharge.security.encrypted.title': 'Đã mã hóa',
    'app.user.recharge.security.encrypted.desc': 'Mã hóa SSL 256 bit',
    'app.user.recharge.security.fast_arrival.title': 'Nhận nhanh',
    'app.user.recharge.security.fast_arrival.desc': 'Nhận sau khi xác nhận',
  },
  'zh_TW': {
    'app.user.recharge.security.payment': '安全支付',
    'app.user.recharge.security.encrypted.title': '加密',
    'app.user.recharge.security.encrypted.desc': 'SSL 256 位加密',
    'app.user.recharge.security.fast_arrival.title': '快速到帳',
    'app.user.recharge.security.fast_arrival.desc': '確認後到帳',
  },
};
