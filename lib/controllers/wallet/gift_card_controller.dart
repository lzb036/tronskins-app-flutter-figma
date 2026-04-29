import 'package:get/get.dart';
import 'package:tronskins_app/api/model/wallet/wallet_models.dart';
import 'package:tronskins_app/api/wallet.dart';

enum GiftCardFilter { all, available, used }

extension GiftCardFilterApi on GiftCardFilter {
  String? get apiStatus {
    return switch (this) {
      GiftCardFilter.all => null,
      GiftCardFilter.available => '0',
      GiftCardFilter.used => '1',
    };
  }
}

class GiftCardController extends GetxController {
  GiftCardController({ApiWalletServer? api}) : _api = api ?? ApiWalletServer();

  static const int _pageSize = 20;

  final ApiWalletServer _api;

  final Rx<GiftCardFilter> selectedFilter = GiftCardFilter.all.obs;
  final RxList<WalletGiftCardItem> cards = <WalletGiftCardItem>[].obs;
  final RxList<WalletGiftCardAmountOption> amountOptions =
      <WalletGiftCardAmountOption>[].obs;

  final RxBool isLoadingCards = false.obs;
  final RxBool isLoadingMoreCards = false.obs;
  final RxBool isLoadingAmountOptions = false.obs;
  final RxBool isGenerating = false.obs;

  int _page = 1;
  bool _hasMoreCards = true;
  int _total = 0;

  bool get hasMoreCards => _hasMoreCards;
  int get total => _total;

  int get availableCount => cards.where((card) => card.isAvailable).length;

  int get usedCount => cards.where((card) => card.isUsed).length;

  double get totalBalance {
    return cards.fold<double>(0, (sum, card) => sum + card.value);
  }

  Future<void> setFilter(GiftCardFilter filter) async {
    if (selectedFilter.value == filter && cards.isNotEmpty) {
      return;
    }
    selectedFilter.value = filter;
    await loadCards(reset: true);
  }

  Future<void> loadCards({bool reset = false}) async {
    if (reset) {
      _page = 1;
      _hasMoreCards = true;
      _total = 0;
      cards.clear();
    }
    if (!_hasMoreCards && !reset) {
      return;
    }

    final loadingFlag = reset ? isLoadingCards : isLoadingMoreCards;
    if (loadingFlag.value) {
      return;
    }

    loadingFlag.value = true;
    try {
      final response = await _api.giftCardList(
        page: _page,
        pageSize: _pageSize,
        status: selectedFilter.value.apiStatus,
      );
      if (!response.success) {
        return;
      }

      final data = response.datas;
      final list = data?.list ?? <WalletGiftCardItem>[];
      _total = data?.pager?.total ?? (reset ? list.length : cards.length);
      if (reset) {
        cards.assignAll(list);
      } else {
        cards.addAll(list);
      }

      _hasMoreCards = _resolveHasMore(
        pager: data?.pager,
        fetchedCount: list.length,
        accumulatedCount: cards.length,
      );
      if (_hasMoreCards) {
        _page += 1;
      }
    } catch (_) {
      if (reset) {
        _hasMoreCards = false;
      }
    } finally {
      loadingFlag.value = false;
    }
  }

  Future<String?> loadPassword(WalletGiftCardItem item) async {
    try {
      final response = await _api.giftCardPassword(id: item.id);
      if (!response.success) {
        return null;
      }
      final password = response.datas?.password.trim() ?? '';
      return password.isEmpty ? null : password;
    } catch (_) {
      return null;
    }
  }

  Future<void> loadAmountOptions({bool force = false}) async {
    if (isLoadingAmountOptions.value) {
      return;
    }
    if (!force && amountOptions.isNotEmpty) {
      return;
    }

    isLoadingAmountOptions.value = true;
    try {
      final response = await _api.giftCardAmountOptions();
      if (response.success) {
        amountOptions.assignAll(
          response.datas ?? <WalletGiftCardAmountOption>[],
        );
      }
    } catch (_) {
      amountOptions.clear();
    } finally {
      isLoadingAmountOptions.value = false;
    }
  }

  Future<bool> generateCard({
    required WalletGiftCardAmountOption amount,
    required int quantity,
  }) async {
    if (isGenerating.value) {
      return false;
    }
    isGenerating.value = true;
    try {
      final response = await _api.addGiftCard(
        number: quantity,
        value: amount.submitValue,
      );
      if (!response.success) {
        return false;
      }
      selectedFilter.value = GiftCardFilter.all;
      await loadCards(reset: true);
      return true;
    } catch (_) {
      return false;
    } finally {
      isGenerating.value = false;
    }
  }

  bool _resolveHasMore({
    required WalletPager? pager,
    required int fetchedCount,
    required int accumulatedCount,
  }) {
    if (fetchedCount <= 0) {
      return false;
    }
    if (pager == null) {
      return fetchedCount >= _pageSize;
    }
    if (pager.total > 0) {
      return accumulatedCount < pager.total;
    }
    if (pager.pages != null && pager.pages! > 0) {
      return pager.page < pager.pages!;
    }
    return fetchedCount >= (pager.pageSize > 0 ? pager.pageSize : _pageSize);
  }
}
