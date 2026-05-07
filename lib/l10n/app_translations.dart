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
    ...?_rechargeSecurityMessages[normalized],
  };
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
