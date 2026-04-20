import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tronskins_app/components/market/market_search_view.dart';

class MarketSearchPage extends StatelessWidget {
  const MarketSearchPage({
    super.key,
    required this.appId,
    this.initialKeyword = '',
  });

  final int appId;
  final String initialKeyword;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FB),
      body: SafeArea(
        bottom: false,
        child: MarketSearchView(
          appId: appId,
          initialKeyword: initialKeyword,
          mode: MarketSearchViewMode.page,
          onCancel: Get.back,
          onSubmit: (keyword) => Get.back(result: keyword),
        ),
      ),
    );
  }
}
