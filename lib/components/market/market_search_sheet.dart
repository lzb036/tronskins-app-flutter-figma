import 'package:flutter/material.dart';
import 'package:tronskins_app/components/market/market_search_view.dart';

class MarketSearchSheet extends StatelessWidget {
  const MarketSearchSheet({
    super.key,
    required this.appId,
    this.initialKeyword = '',
  });

  final int appId;
  final String initialKeyword;

  @override
  Widget build(BuildContext context) {
    return MarketSearchView(
      appId: appId,
      initialKeyword: initialKeyword,
      onCancel: () => Navigator.of(context).pop(),
      onSubmit: (keyword) => Navigator.of(context).pop(keyword),
    );
  }
}
