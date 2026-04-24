import 'package:get/get.dart';
import 'package:tronskins_app/controllers/shop/shop_shipping_notice_controller.dart';
import 'package:tronskins_app/controllers/user/user_controller.dart';

Future<void> syncLoginSuccessState() async {
  final userController = Get.isRegistered<UserController>()
      ? Get.find<UserController>()
      : Get.put(UserController());
  await userController.handleLoginSuccess();

  if (Get.isRegistered<ShopShippingNoticeController>()) {
    Get.find<ShopShippingNoticeController>().ensurePollingForCurrentLogin();
  }
}
