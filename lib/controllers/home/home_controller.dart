import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'package:tronskins_app/api/market.dart';
import 'package:tronskins_app/api/system.dart';
import 'package:tronskins_app/api/model/market/market_models.dart';
import 'package:tronskins_app/api/model/systemModel.dart';
import 'package:tronskins_app/common/http/http_helper.dart';
import 'package:tronskins_app/common/hooks/game/global_game_controller.dart';
import 'package:tronskins_app/common/logging/app_logger.dart';
import 'package:tronskins_app/common/storage/server_storage.dart';

class HomeController extends GetxController {
  final ApiMarketServer _api = ApiMarketServer();
  final ApiSystemServer _systemApi = ApiSystemServer();
  final GlobalGameController _globalGameController =
      GlobalGameController.ensureInstance();
  static const int _latestPageSize = 10;
  static const int _hotPageSize = 20;

  final RxInt appId = 730.obs;
  final RxList<MarketItemEntity> latestItems = <MarketItemEntity>[].obs;
  final RxList<MarketItemEntity> hotItems = <MarketItemEntity>[].obs;
  final Rxn<SystemNoticeEntity> systemNotice = Rxn<SystemNoticeEntity>();
  final RxBool isLoadingLatest = false.obs;
  final RxBool isLoadingHot = false.obs;
  final RxBool systemNoticeVisible = false.obs;
  Worker? _gameWorker;
  Worker? _serverWorker;
  bool _systemNoticeDismissedForLifecycle = false;

  int _latestPage = 1;
  int _hotPage = 1;
  bool _latestHasMore = true;
  bool _hotHasMore = true;

  bool get latestHasMore => _latestHasMore;
  bool get hotHasMore => _hotHasMore;

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
    _serverWorker = ever<int>(ServerStorage.changeToken, (_) {
      fetchSystemNotice();
    });
    fetchSystemNotice();
    refreshAll();
  }

  @override
  void onClose() {
    _gameWorker?.dispose();
    _serverWorker?.dispose();
    super.onClose();
  }

  Future<void> refreshAll() async {
    await Future.wait([fetchLatest(reset: true), fetchHot(reset: true)]);
  }

  Future<void> changeGame(int newAppId) async {
    await _globalGameController.switchGame(newAppId);
  }

  Future<void> fetchSystemNotice() async {
    try {
      final res = await _systemApi.getSystemNotice();
      final notice = res.datas;
      if (!res.success || notice == null || !_hasNoticeText(notice)) {
        systemNotice.value = null;
        systemNoticeVisible.value = false;
        return;
      }
      systemNotice.value = notice;
      systemNoticeVisible.value = !_systemNoticeDismissedForLifecycle;
    } catch (error, stackTrace) {
      AppLogger.errorLog(
        'HOME',
        'Failed to fetch system notice.',
        scope: 'NOTICE',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  void dismissSystemNotice() {
    _systemNoticeDismissedForLifecycle = true;
    systemNoticeVisible.value = false;
  }

  Future<void> fetchLatest({bool reset = false}) async {
    if (isLoadingLatest.value || (!_latestHasMore && !reset)) {
      return;
    }
    if (reset) {
      _latestPage = 1;
      _latestHasMore = true;
      latestItems.clear();
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
        'HOME',
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
    if (reset) {
      _hotPage = 1;
      _hotHasMore = true;
      hotItems.clear();
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
        'HOME',
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
        'HOME',
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

  bool _hasNoticeText(SystemNoticeEntity notice) {
    return notice.content?.trim().isNotEmpty ?? false;
  }
}
