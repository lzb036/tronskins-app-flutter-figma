import 'package:get/get.dart';
import 'package:tronskins_app/api/model/notify/notify_models.dart';
import 'package:tronskins_app/api/notify.dart';
import 'package:tronskins_app/common/events/app_events.dart';
import 'package:tronskins_app/common/storage/game_storage.dart';
import 'package:tronskins_app/common/storage/server_storage.dart';

class NotifyController extends GetxController {
  NotifyController({ApiNotifyServer? api}) : _api = api ?? ApiNotifyServer();

  final ApiNotifyServer _api;
  Worker? _logoutWorker;
  Worker? _serverWorker;

  final RxList<TradeNotifyItem> tradeList = <TradeNotifyItem>[].obs;
  final RxList<NoticeMessageItem> noticeList = <NoticeMessageItem>[].obs;
  final RxnString tradeMark = RxnString();

  final RxBool tradeLoading = false.obs;
  final RxBool noticeLoading = false.obs;
  final RxBool tradeRefreshing = false.obs;
  final RxBool noticeRefreshing = false.obs;
  final RxBool tradeLoadingMore = false.obs;
  final RxBool noticeLoadingMore = false.obs;
  final RxBool badgeLoading = false.obs;

  final RxInt tradeTotal = 0.obs;
  final RxInt noticeTotal = 0.obs;

  int _tradePage = 1;
  int _noticePage = 1;
  final int _pageSize = 20;
  bool _tradeReachedEnd = false;
  bool _noticeReachedEnd = false;
  int? _badgeAppId;
  int _badgeRequestVersion = 0;
  Future<void>? _badgeRequest;

  bool get tradeHasMore => !_tradeReachedEnd;
  bool get noticeHasMore => !_noticeReachedEnd;
  int get unreadTradeCount => tradeList.where((item) => !item.read).length;
  int get unreadNoticeCount => noticeList.where((item) => !item.isRead).length;
  int get unreadCount => unreadTradeCount + unreadNoticeCount;
  bool get hasUnreadMessages => unreadCount > 0;
  String? get unreadBadgeLabel {
    final label = tradeMark.value?.trim();
    if (label == null || label.isEmpty || label == '0') {
      return null;
    }
    return label;
  }

  @override
  void onInit() {
    super.onInit();
    _logoutWorker = ever(AppEvents.userLogoutEvent, (_) => _resetState());
    _serverWorker = ever<int>(ServerStorage.changeToken, (_) => _resetState());
  }

  @override
  void onClose() {
    _logoutWorker?.dispose();
    _serverWorker?.dispose();
    super.onClose();
  }

  void _resetState() {
    tradeList.clear();
    noticeList.clear();
    tradeMark.value = null;
    tradeTotal.value = 0;
    noticeTotal.value = 0;
    tradeLoading.value = false;
    noticeLoading.value = false;
    tradeRefreshing.value = false;
    noticeRefreshing.value = false;
    tradeLoadingMore.value = false;
    noticeLoadingMore.value = false;
    badgeLoading.value = false;
    _tradePage = 1;
    _noticePage = 1;
    _tradeReachedEnd = false;
    _noticeReachedEnd = false;
    _badgeAppId = null;
    _badgeRequest = null;
    _badgeRequestVersion++;
  }

  void ensureBadgeLoaded() {
    final appId = GameStorage.getGameType();
    if (_badgeAppId == appId && tradeMark.value != null) {
      return;
    }
    if (badgeLoading.value && _badgeAppId == appId) {
      return;
    }
    loadTradeBadge(appId: appId);
  }

  Future<void> loadTradeBadge({int? appId, bool force = false}) async {
    final resolvedAppId = appId ?? GameStorage.getGameType();
    if (!force && _badgeAppId == resolvedAppId && tradeMark.value != null) {
      return;
    }
    if (!force && badgeLoading.value && _badgeAppId == resolvedAppId) {
      return _badgeRequest ?? Future.value();
    }

    _badgeAppId = resolvedAppId;
    final requestVersion = ++_badgeRequestVersion;
    badgeLoading.value = true;
    final request = () async {
      try {
        final res = await _api.markInfo(appId: resolvedAppId);
        if (res.success && requestVersion == _badgeRequestVersion) {
          tradeMark.value = res.datas?.tradeMark?.trim();
        }
      } finally {
        if (requestVersion == _badgeRequestVersion) {
          badgeLoading.value = false;
          _badgeRequest = null;
        }
      }
    }();
    _badgeRequest = request;
    return request;
  }

  Future<void> loadTradeList({bool refresh = false}) async {
    if (tradeLoading.value) return;
    if (!refresh && !tradeHasMore) return;

    final showRefreshSkeleton = refresh && tradeList.isNotEmpty;
    final showLoadMoreSkeleton = !refresh && tradeList.isNotEmpty;
    tradeLoading.value = true;
    tradeRefreshing.value = showRefreshSkeleton;
    tradeLoadingMore.value = showLoadMoreSkeleton;
    try {
      if (refresh) {
        _tradePage = 1;
        _tradeReachedEnd = false;
      }
      final res = await _api.tradeList(page: _tradePage, pageSize: _pageSize);
      if (res.success && res.datas != null) {
        final data = res.datas!;
        if (refresh) {
          tradeList.assignAll(data.list);
        } else {
          tradeList.addAll(data.list);
        }
        if (data.pager != null) {
          tradeTotal.value = data.pager!.total;
          _tradeReachedEnd = tradeList.length >= tradeTotal.value;
        } else if (data.list.isEmpty) {
          _tradeReachedEnd = true;
        }
        if (data.list.isNotEmpty) {
          _tradePage += 1;
        }
      }
    } finally {
      tradeLoading.value = false;
      tradeRefreshing.value = false;
      tradeLoadingMore.value = false;
    }
  }

  Future<void> loadNoticeList({bool refresh = false}) async {
    if (noticeLoading.value) return;
    if (!refresh && !noticeHasMore) return;

    final showRefreshSkeleton = refresh && noticeList.isNotEmpty;
    final showLoadMoreSkeleton = !refresh && noticeList.isNotEmpty;
    noticeLoading.value = true;
    noticeRefreshing.value = showRefreshSkeleton;
    noticeLoadingMore.value = showLoadMoreSkeleton;
    try {
      if (refresh) {
        _noticePage = 1;
        _noticeReachedEnd = false;
      }
      final res = await _api.noticeList(page: _noticePage, pageSize: _pageSize);
      if (res.success && res.datas != null) {
        final data = res.datas!;
        if (refresh) {
          noticeList.assignAll(data.list);
        } else {
          noticeList.addAll(data.list);
        }
        if (data.pager != null) {
          noticeTotal.value = data.pager!.total;
          _noticeReachedEnd = noticeList.length >= noticeTotal.value;
        } else if (data.list.isEmpty) {
          _noticeReachedEnd = true;
        }
        if (data.list.isNotEmpty) {
          _noticePage += 1;
        }
      }
    } finally {
      noticeLoading.value = false;
      noticeRefreshing.value = false;
      noticeLoadingMore.value = false;
    }
  }

  Future<String?> readTrade(TradeNotifyItem item) async {
    if (item.read || item.id == null) return null;
    final res = await _api.readTrade(id: item.id!);
    if (res.success) {
      item.read = true;
      tradeList.refresh();
      await loadTradeBadge(force: true);
      final message = res.datas?.toString();
      if (message != null && message.isNotEmpty) {
        return message;
      }
      if (res.message.isNotEmpty) {
        return res.message;
      }
      return '';
    }
    return null;
  }

  Future<bool> readNotice(NoticeMessageItem item) async {
    if (item.isRead || item.id == null) return false;
    final res = await _api.readNotice(id: item.id!);
    if (res.success) {
      item.isRead = true;
      noticeList.refresh();
      return true;
    }
    return false;
  }

  Future<bool> readAllTrade() async {
    final res = await _api.readAllTrade();
    if (res.success) {
      for (final item in tradeList) {
        item.read = true;
      }
      tradeList.refresh();
      await loadTradeBadge(force: true);
      return true;
    }
    return false;
  }

  Future<String?> clearTrade() async {
    final res = await _api.clearTrade();
    if (res.success) {
      tradeList.clear();
      tradeTotal.value = 0;
      _tradePage = 1;
      _tradeReachedEnd = false;
      await loadTradeBadge(force: true);
      final message = res.datas?.toString();
      if (message != null && message.isNotEmpty) {
        return message;
      }
      if (res.message.isNotEmpty) {
        return res.message;
      }
      return '';
    }
    return null;
  }

  Future<String?> deleteTrade(String id) async {
    final res = await _api.deleteTrade(id: id);
    if (res.success) {
      await loadTradeBadge(force: true);
      final message = res.datas?.toString();
      if (message != null && message.isNotEmpty) {
        return message;
      }
      if (res.message.isNotEmpty) {
        return res.message;
      }
      return '';
    }
    return null;
  }

  Future<bool> readAllNotice() async {
    final res = await _api.readAllNotice();
    if (res.success) {
      for (final item in noticeList) {
        item.isRead = true;
      }
      noticeList.refresh();
      return true;
    }
    return false;
  }
}
