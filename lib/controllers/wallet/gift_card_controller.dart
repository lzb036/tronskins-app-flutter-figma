import 'package:get/get.dart';

enum GiftCardFilter { all, available, used, expired }

enum GiftCardStatus { available, used, expired }

class GiftCardItem {
  const GiftCardItem({
    required this.id,
    required this.ownerName,
    required this.code,
    required this.amount,
    required this.status,
    this.statusNote,
  });

  final String id;
  final String ownerName;
  final String code;
  final double amount;
  final GiftCardStatus status;
  final String? statusNote;

  String get maskedCode {
    final clean = code.replaceAll(RegExp(r'\s+'), '');
    final last = clean.length <= 4 ? clean : clean.substring(clean.length - 4);
    return '.... .... .... $last';
  }
}

class GiftCardController extends GetxController {
  final Rx<GiftCardFilter> selectedFilter = GiftCardFilter.all.obs;
  final RxList<GiftCardItem> cards = <GiftCardItem>[
    const GiftCardItem(
      id: 'gc-8821',
      ownerName: 'LinNorth',
      code: 'TRON-GIFT-0000-8821',
      amount: 100,
      status: GiftCardStatus.available,
    ),
    const GiftCardItem(
      id: 'gc-4490',
      ownerName: 'LinNorth',
      code: 'TRON-GIFT-0000-4490',
      amount: 50,
      status: GiftCardStatus.used,
      statusNote: 'Redeemed Oct 12',
    ),
    const GiftCardItem(
      id: 'gc-3012',
      ownerName: 'LinNorth',
      code: 'TRON-GIFT-0000-3012',
      amount: 25,
      status: GiftCardStatus.available,
    ),
    const GiftCardItem(
      id: 'gc-0019',
      ownerName: 'LinNorth',
      code: 'TRON-GIFT-0000-0019',
      amount: 20,
      status: GiftCardStatus.expired,
    ),
  ].obs;

  List<GiftCardItem> get filteredCards {
    final filter = selectedFilter.value;
    if (filter == GiftCardFilter.all) {
      return cards;
    }
    return cards.where((card) {
      return switch (filter) {
        GiftCardFilter.available => card.status == GiftCardStatus.available,
        GiftCardFilter.used => card.status == GiftCardStatus.used,
        GiftCardFilter.expired => card.status == GiftCardStatus.expired,
        GiftCardFilter.all => true,
      };
    }).toList();
  }

  int get availableCount =>
      cards.where((card) => card.status == GiftCardStatus.available).length;

  int get usedCount =>
      cards.where((card) => card.status == GiftCardStatus.used).length;

  double get totalBalance =>
      cards.fold<double>(0, (sum, card) => sum + card.amount);

  void setFilter(GiftCardFilter filter) {
    selectedFilter.value = filter;
  }

  void createCards({required double amount, required int quantity}) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final createdCards = <GiftCardItem>[];
    for (var index = 0; index < quantity; index += 1) {
      final suffix = ((now + index) % 10000).toString().padLeft(4, '0');
      final id = 'gc-$now-$index';
      createdCards.add(
        GiftCardItem(
          id: id,
          ownerName: 'LinNorth',
          code: 'TRON-GIFT-${now % 100000000}-$suffix',
          amount: amount,
          status: GiftCardStatus.available,
        ),
      );
    }
    cards.insertAll(0, createdCards);
    selectedFilter.value = GiftCardFilter.all;
  }

  void removeCard(GiftCardItem item) {
    cards.removeWhere((card) => card.id == item.id);
  }
}
