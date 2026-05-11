import 'package:get/get.dart';
import 'package:tronskins_app/api/model/entity/user/user_info_entity.dart';
import 'package:tronskins_app/common/storage/user_storage.dart';
import 'package:tronskins_app/controllers/user/user_controller.dart';

const String tradeBuyBalanceInsufficientKey =
    'app.trade.buy.message.balance_insufficient';
const String tradeFailedKey = 'app.trade.filter.failed';

double resolvePurchaseAvailableBalance({UserInfoEntity? fallbackUser}) {
  final currentUser = Get.isRegistered<UserController>()
      ? Get.find<UserController>().user.value
      : null;
  final fund =
      currentUser?.fund ??
      fallbackUser?.fund ??
      UserStorage.getUserInfo()?.fund;
  return (fund?.available ?? fund?.balance ?? 0) + (fund?.gift ?? 0);
}

bool isPurchaseBalanceInsufficient(
  double totalAmount, {
  UserInfoEntity? fallbackUser,
}) {
  return resolvePurchaseAvailableBalance(fallbackUser: fallbackUser) +
          0.000001 <
      totalAmount;
}

String resolvePurchaseFailureMessage({
  String? message,
  dynamic datas,
  double? totalAmount,
  UserInfoEntity? fallbackUser,
}) {
  if (totalAmount != null &&
      isPurchaseBalanceInsufficient(totalAmount, fallbackUser: fallbackUser)) {
    return tradeBuyBalanceInsufficientKey.tr;
  }

  final messageText = message?.trim() ?? '';
  final dataText = datas is String ? datas.trim() : '';
  final combined = '$messageText $dataText'.trim();
  if (_looksLikeBalanceInsufficient(combined)) {
    return tradeBuyBalanceInsufficientKey.tr;
  }

  if (messageText.isNotEmpty && !_isGenericFailure(messageText)) {
    return messageText;
  }
  if (dataText.isNotEmpty && !_isGenericFailure(dataText)) {
    return dataText;
  }
  return tradeFailedKey.tr;
}

bool _looksLikeBalanceInsufficient(String value) {
  final text = value.trim().toLowerCase();
  if (text.isEmpty) {
    return false;
  }
  return (text.contains('balance') &&
          (text.contains('insufficient') ||
              text.contains('not enough') ||
              text.contains('lack'))) ||
      (text.contains('余额') && text.contains('不足')) ||
      (text.contains('餘額') && text.contains('不足'));
}

bool _isGenericFailure(String value) {
  final text = value.trim().toLowerCase();
  return text == 'failed' ||
      text == 'fail' ||
      text == 'failure' ||
      text == '失败' ||
      text == '失敗' ||
      text == '交易失败' ||
      text == '交易失敗';
}
