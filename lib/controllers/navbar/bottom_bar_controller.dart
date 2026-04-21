import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

class BottomBarController extends GetxController {
  final RxInt revision = 0.obs;
  final Map<int, WidgetBuilder> _overlayBuilders = <int, WidgetBuilder>{};

  WidgetBuilder? builderFor(int tabIndex) => _overlayBuilders[tabIndex];

  void showForTab({required int tabIndex, required WidgetBuilder builder}) {
    _overlayBuilders[tabIndex] = builder;
    revision.value++;
  }

  void hideForTab(int tabIndex) {
    if (_overlayBuilders.remove(tabIndex) != null) {
      revision.value++;
    }
  }

  void clearAll() {
    if (_overlayBuilders.isEmpty) {
      return;
    }
    _overlayBuilders.clear();
    revision.value++;
  }
}
