import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'package:tronskins_app/api/market.dart';
import 'package:tronskins_app/api/model/market/market_models.dart';
import 'package:tronskins_app/common/http/http_helper.dart';
import 'package:tronskins_app/common/hooks/game/global_game_controller.dart';
import 'package:tronskins_app/common/logging/app_logger.dart';

class MarketController extends GetxController {
  final ApiMarketServer _api = ApiMarketServer();
  final GlobalGameController _globalGameController =
      GlobalGameController.ensureInstance();
  static const int _latestPageSize = 10;
  static const int _hotPageSize = 20;

  final RxInt appId = 730.obs;
  final RxList<MarketItemEntity> latestItems = <MarketItemEntity>[].obs;
  final RxList<MarketItemEntity> hotItems = <MarketItemEntity>[].obs;
  final RxBool isLoadingLatest = false.obs;
  final RxBool isLoadingHot = false.obs;
  Worker? _gameWorker;

  int _latestPage = 1;
  int _hotPage = 1;
  bool _latestHasMore = true;
  bool _hotHasMore = true;

  @override
  void onInit() {
    super.onInit();
    appId.value = _globalGameController.currentAppId.value;
    _gameWorker = ever<int>(_globalGameController.currentAppId, (nextAppId) {
      if (nextAppId == appId.value) {
        return;
      }
      appId.value = nextAppId;
      refreshAll();
    });
    refreshAll();
  }

  @override
  void onClose() {
    _gameWorker?.dispose();
    super.onClose();
  }

  Future<void> refreshAll() async {
    await Future.wait([fetchLatest(reset: true), fetchHot(reset: true)]);
  }

  Future<void> changeGame(int newAppId) async {
    await _globalGameController.switchGame(newAppId);
  }

  Future<void> fetchLatest({bool reset = false}) async {
    if (isLoadingLatest.value || (!_latestHasMore && !reset)) {
      return;
    }
    isLoadingLatest.value = true;
    try {
      final requestPage = reset ? 1 : _latestPage;
      final res = await _runFeedRequestWithRetry(
        () => _api.marketNews(
          appId: appId.value,
          page: requestPage,
          pageSize: _latestPageSize,
        ),
        requestLabel: 'latest',
      );
      final items = res.datas ?? <MarketItemEntity>[];
      final fetchedCount = items.length;
      if (reset) {
        latestItems.assignAll(items);
      } else {
        latestItems.addAll(items);
      }
      _latestHasMore = fetchedCount >= _latestPageSize;
      _latestPage = _latestHasMore ? requestPage + 1 : requestPage;
    } catch (error, stackTrace) {
      AppLogger.errorLog(
        'MARKET',
        'Failed to fetch latest feed.',
        scope: 'LATEST',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      isLoadingLatest.value = false;
    }
  }

  Future<void> fetchHot({bool reset = false}) async {
    if (isLoadingHot.value || (!_hotHasMore && !reset)) {
      return;
    }
    isLoadingHot.value = true;
    try {
      final requestPage = reset ? 1 : _hotPage;
      final res = await _runFeedRequestWithRetry(
        () => _api.marketHotItems(
          appId: appId.value,
          page: requestPage,
          pageSize: _hotPageSize,
        ),
        requestLabel: 'hot',
      );
      final items = res.datas ?? <MarketItemEntity>[];
      final fetchedCount = items.length;
      if (reset) {
        hotItems.assignAll(items);
      } else {
        hotItems.addAll(items);
      }
      _hotHasMore = fetchedCount >= _hotPageSize;
      _hotPage = _hotHasMore ? requestPage + 1 : requestPage;
    } catch (error, stackTrace) {
      AppLogger.errorLog(
        'MARKET',
        'Failed to fetch hot feed.',
        scope: 'HOT',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      isLoadingHot.value = false;
    }
  }

  Future<T> _runFeedRequestWithRetry<T>(
    Future<T> Function() request, {
    required String requestLabel,
  }) async {
    try {
      return await request();
    } catch (error) {
      if (!_isRetriableNetworkError(error)) {
        rethrow;
      }
      AppLogger.warn(
        'MARKET',
        'Retrying feed request after transient network failure.',
        scope: requestLabel,
        error: error,
      );
      await Future<void>.delayed(const Duration(milliseconds: 350));
      return request();
    }
  }

  bool _isRetriableNetworkError(Object error) {
    if (error is! HttpException) {
      return false;
    }
    final type = error.dioError?.type;
    return type == DioExceptionType.connectionError ||
        type == DioExceptionType.connectionTimeout ||
        type == DioExceptionType.receiveTimeout;
  }
}
