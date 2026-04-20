import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tronskins_app/api/model/market/market_models.dart';
import 'package:tronskins_app/components/game_item/game_item_models.dart';
import 'package:tronskins_app/components/market/market_showcase_card.dart';

class HomeMarketItemCard extends StatelessWidget {
  const HomeMarketItemCard({super.key, required this.item, this.onTap});

  final MarketItemEntity item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final rarity = TagInfo.fromMarketTag(item.tags?.rarity);
    final quality = TagInfo.fromMarketTag(item.tags?.quality);
    final exterior = TagInfo.fromMarketTag(item.tags?.exterior);

    return MarketShowcaseCard(
      appId: item.appId,
      imageUrl: item.imageUrl ?? '',
      title: (item.marketName ?? item.marketHashName ?? '-').trim(),
      price: item.marketPrice ?? 0,
      trailingInfo: '${item.sellNum ?? 0} ${'app.trade.onSale.nums'.tr}',
      rarity: rarity,
      quality: quality,
      exterior: exterior,
      showAccessoryDetails: false,
      onTap: onTap,
    );
  }
}
