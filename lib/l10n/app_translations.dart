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

  return _missingMessages[normalized] ?? const <String, String>{};
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
