import 'package:get/get.dart';
import 'package:tronskins_app/api/market.dart';
import 'package:tronskins_app/api/model/market/market_models.dart';
import 'package:tronskins_app/api/model/shop/shop_models.dart';
import 'package:tronskins_app/common/storage/user_storage.dart';

class MarketDetailController extends GetxController {
  MarketDetailController({ApiMarketServer? api})
    : _api = api ?? ApiMarketServer();

  final ApiMarketServer _api;
  static const int _onSalePageSize = 20;
  static const int _transactionPageSize = 10;
  static const int _buyRequestPageSize = 20;

  late MarketItemEntity item;

  final RxList<MarketListItem> onSaleItems = <MarketListItem>[].obs;
  final RxList<MarketListItem> transactionItems = <MarketListItem>[].obs;
  final RxList<MarketPricePoint> pricePoints = <MarketPricePoint>[].obs;
  final RxMap<String, MarketUserInfo> users = <String, MarketUserInfo>{}.obs;
  final RxMap<String, MarketSchemaInfo> schemas =
      <String, MarketSchemaInfo>{}.obs;
  final RxMap<String, dynamic> stickers = <String, dynamic>{}.obs;
  final RxList<BuyRequestItem> buyRequests = <BuyRequestItem>[].obs;
  final RxMap<String, ShopUserInfo> buyUsers = <String, ShopUserInfo>{}.obs;
  final RxMap<String, ShopSchemaInfo> buySchemas =
      <String, ShopSchemaInfo>{}.obs;

  final RxBool isLoadingOnSale = false.obs;
  final RxBool isLoadingTransactions = false.obs;
  final RxBool isLoadingTrend = false.obs;
  final RxBool isLoadingBuyRequests = false.obs;
  final RxBool isRefreshingOnSale = false.obs;
  final RxBool isRefreshingTransactions = false.obs;
  final RxBool isRefreshingBuyRequests = false.obs;

  int _onSalePage = 1;
  int _transactionPage = 1;
  bool _onSaleHasMore = true;
  bool _transactionHasMore = true;
  int _buyRequestPage = 1;
  bool _buyRequestHasMore = true;
  double? _onSaleMinPrice;
  double? _onSaleMaxPrice;
  String? _onSalePaintSeed;
  int? _onSalePaintIndex;
  double? _onSalePaintWearMin;
  double? _onSalePaintWearMax;
  String? _onSaleSortField;
  bool? _onSaleSortAsc;
  bool _pendingOnSaleReset = false;
  bool _pendingOnSalePreserveVisibleItems = true;
  bool get onSaleHasMore => _onSaleHasMore;
  bool get transactionHasMore => _transactionHasMore;
  bool get buyRequestHasMore => _buyRequestHasMore;

  int get appId => item.appId ?? 730;
  int? get schemaId => item.schemaId ?? item.id;
  String get marketHashName => item.marketHashName ?? item.marketName ?? '';

  bool _resolveHasMore({
    required int accumulatedCount,
    required int fetchedCount,
    required int pageSize,
    int? totalCount,
  }) {
    if (totalCount != null && totalCount > 0) {
      return accumulatedCount < totalCount;
    }
    return fetchedCount >= pageSize;
  }

  @override
  void onInit() {
    super.onInit();
    item = Get.arguments as MarketItemEntity;
    refreshAll();
  }

  void updateItem(MarketItemEntity next, {bool preserveVisibleItems = false}) {
    item = next;
    _onSalePage = 1;
    _transactionPage = 1;
    _buyRequestPage = 1;
    _onSaleHasMore = true;
    _transactionHasMore = true;
    _buyRequestHasMore = true;
    refreshAll(preserveVisibleItems: preserveVisibleItems);
  }

  Future<void> refreshAll({bool preserveVisibleItems = false}) async {
    if (!preserveVisibleItems) {
      stickers.clear();
    }
    await Future.wait([
      loadTrend(reset: true),
      loadOnSale(reset: true, preserveVisibleItems: preserveVisibleItems),
      loadTransactions(reset: true, preserveVisibleItems: preserveVisibleItems),
      loadBuyRequests(reset: true, preserveVisibleItems: preserveVisibleItems),
    ]);
  }

  Future<void> loadTrend({bool reset = false, int days = 30}) async {
    if (isLoadingTrend.value) {
      return;
    }
    isLoadingTrend.value = true;
    try {
      if (marketHashName.isEmpty) {
        pricePoints.clear();
        return;
      }
      final useAuth = UserStorage.getUserInfo() != null;
      final res = await _api.priceTrend(
        appId: appId,
        marketHashName: marketHashName,
        days: days,
        useAuth: useAuth,
        fallbackToPublicOnFail: true,
      );
      pricePoints
        ..clear()
        ..addAll(res.datas?.priceInfos ?? <MarketPricePoint>[]);
    } finally {
      isLoadingTrend.value = false;
    }
  }

  Future<void> loadOnSale({
    bool reset = false,
    bool preserveVisibleItems = false,
  }) async {
    if (schemaId == null) {
      return;
    }
    if (isLoadingOnSale.value) {
      if (reset) {
        if (_pendingOnSaleReset) {
          _pendingOnSalePreserveVisibleItems =
              _pendingOnSalePreserveVisibleItems && preserveVisibleItems;
        } else {
          _pendingOnSaleReset = true;
          _pendingOnSalePreserveVisibleItems = preserveVisibleItems;
        }
      }
      return;
    }
    if (!_onSaleHasMore && !reset) {
      return;
    }
    isLoadingOnSale.value = true;
    isRefreshingOnSale.value = reset && preserveVisibleItems;
    try {
      if (reset) {
        _onSalePage = 1;
        _onSaleHasMore = true;
        if (!preserveVisibleItems) {
          onSaleItems.clear();
        }
      }
      final useAuth = UserStorage.getUserInfo() != null;
      final res = await _api.onSaleList(
        appId: appId,
        schemaId: schemaId!,
        page: _onSalePage,
        pageSize: _onSalePageSize,
        field: (_onSaleSortField?.isNotEmpty ?? false)
            ? _onSaleSortField
            : null,
        asc: (_onSaleSortField?.isNotEmpty ?? false) ? _onSaleSortAsc : null,
        minPrice: _onSaleMinPrice,
        maxPrice: _onSaleMaxPrice,
        paintSeed: _onSalePaintSeed,
        paintIndex: _onSalePaintIndex,
        paintWearMin: _onSalePaintWearMin,
        paintWearMax: _onSalePaintWearMax,
        useAuth: useAuth,
        fallbackToPublicOnFail: true,
      );
      final data = res.datas;
      final fetchedCount = data?.items.length ?? 0;
      if (data == null || fetchedCount == 0) {
        if (reset) {
          onSaleItems.clear();
        }
        _onSaleHasMore = false;
      } else {
        if (reset) {
          onSaleItems.assignAll(data.items);
        } else {
          onSaleItems.addAll(data.items);
        }
        _onSaleHasMore = _resolveHasMore(
          accumulatedCount: onSaleItems.length,
          fetchedCount: fetchedCount,
          pageSize: _onSalePageSize,
          totalCount: data.pager?.total,
        );
        if (_onSaleHasMore) {
          _onSalePage += 1;
        }
      }
      users.addAll(data?.users ?? const {});
      schemas.addAll(data?.schemas ?? const {});
      stickers.addAll(data?.stickers ?? const {});
    } finally {
      isRefreshingOnSale.value = false;
      isLoadingOnSale.value = false;
      if (_pendingOnSaleReset && schemaId != null) {
        final preserveQueuedVisibleItems = _pendingOnSalePreserveVisibleItems;
        _pendingOnSaleReset = false;
        _pendingOnSalePreserveVisibleItems = true;
        Future<void>.microtask(
          () => loadOnSale(
            reset: true,
            preserveVisibleItems: preserveQueuedVisibleItems,
          ),
        );
      }
    }
  }

  Future<void> applyOnSaleFilter({
    String? sortField,
    bool? sortAsc,
    double? minPrice,
    double? maxPrice,
    String? paintSeed,
    int? paintIndex,
    double? paintWearMin,
    double? paintWearMax,
    bool preserveVisibleItems = false,
  }) async {
    final normalizedSortField = sortField?.trim();
    _onSaleSortField =
        (normalizedSortField == null || normalizedSortField.isEmpty)
        ? null
        : normalizedSortField;
    _onSaleSortAsc = _onSaleSortField == null ? null : sortAsc;
    _onSaleMinPrice = minPrice;
    _onSaleMaxPrice = maxPrice;
    _onSalePaintSeed = paintSeed;
    _onSalePaintIndex = paintIndex;
    _onSalePaintWearMin = paintWearMin;
    _onSalePaintWearMax = paintWearMax;
    await loadOnSale(reset: true, preserveVisibleItems: preserveVisibleItems);
  }

  Future<void> loadTransactions({
    bool reset = false,
    bool preserveVisibleItems = false,
  }) async {
    if (isLoadingTransactions.value || schemaId == null) {
      return;
    }
    if (!_transactionHasMore && !reset) {
      return;
    }
    isLoadingTransactions.value = true;
    isRefreshingTransactions.value = reset && preserveVisibleItems;
    try {
      if (reset) {
        _transactionPage = 1;
        _transactionHasMore = true;
        if (!preserveVisibleItems) {
          transactionItems.clear();
        }
      }
      final res = await _api.transactionList(
        appId: appId,
        schemaId: schemaId!,
        page: _transactionPage,
        pageSize: _transactionPageSize,
      );
      final data = res.datas;
      final fetchedCount = data?.items.length ?? 0;
      if (data == null || fetchedCount == 0) {
        if (reset) {
          transactionItems.clear();
        }
        _transactionHasMore = false;
      } else {
        if (reset) {
          transactionItems.assignAll(data.items);
        } else {
          transactionItems.addAll(data.items);
        }
        _transactionHasMore = _resolveHasMore(
          accumulatedCount: transactionItems.length,
          fetchedCount: fetchedCount,
          pageSize: _transactionPageSize,
          totalCount: data.pager?.total,
        );
        if (_transactionHasMore) {
          _transactionPage += 1;
        }
      }
      users.addAll(data?.users ?? const {});
      schemas.addAll(data?.schemas ?? const {});
      stickers.addAll(data?.stickers ?? const {});
    } finally {
      isRefreshingTransactions.value = false;
      isLoadingTransactions.value = false;
    }
  }

  Future<void> loadBuyRequests({
    bool reset = false,
    bool preserveVisibleItems = false,
  }) async {
    if (isLoadingBuyRequests.value || schemaId == null) {
      return;
    }
    if (!_buyRequestHasMore && !reset) {
      return;
    }
    isLoadingBuyRequests.value = true;
    isRefreshingBuyRequests.value = reset && preserveVisibleItems;
    try {
      if (reset) {
        _buyRequestPage = 1;
        _buyRequestHasMore = true;
        if (!preserveVisibleItems) {
          buyRequests.clear();
        }
      }
      final useAuth = UserStorage.getUserInfo() != null;
      final res = await _api.buyRequestList(
        appId: appId,
        schemaId: schemaId!,
        page: _buyRequestPage,
        pageSize: _buyRequestPageSize,
        useAuth: useAuth,
        fallbackToPublicOnFail: true,
      );
      final data = res.datas;
      final fetchedCount = data?.items.length ?? 0;
      if (data == null || fetchedCount == 0) {
        if (reset) {
          buyRequests.clear();
        }
        _buyRequestHasMore = false;
      } else {
        if (reset) {
          buyRequests.assignAll(data.items);
        } else {
          buyRequests.addAll(data.items);
        }
        _buyRequestHasMore = _resolveHasMore(
          accumulatedCount: buyRequests.length,
          fetchedCount: fetchedCount,
          pageSize: _buyRequestPageSize,
          totalCount: data.total ?? data.pager?.total,
        );
        if (_buyRequestHasMore) {
          _buyRequestPage += 1;
        }
      }
      buyUsers.addAll(data?.users ?? const {});
      buySchemas.addAll(data?.schemas ?? const {});
    } finally {
      isRefreshingBuyRequests.value = false;
      isLoadingBuyRequests.value = false;
    }
  }
}
