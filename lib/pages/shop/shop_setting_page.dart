import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tronskins_app/api/model/entity/user/user_shop_entity.dart';
import 'package:tronskins_app/common/http/http_helper.dart';
import 'package:tronskins_app/common/utils/app_snackbar.dart';
import 'package:tronskins_app/common/widgets/login_required_prompt.dart';
import 'package:tronskins_app/common/widgets/settings_style_app_bar.dart';
import 'package:tronskins_app/controllers/shop/shop_controller.dart';
import 'package:tronskins_app/controllers/user/user_controller.dart';
import 'package:tronskins_app/routes/app_routes.dart';

class ShopSettingPage extends StatefulWidget {
  const ShopSettingPage({super.key});

  @override
  State<ShopSettingPage> createState() => _ShopSettingPageState();
}

class _ShopSettingPageState extends State<ShopSettingPage> {
  static const _pageBg = Color(0xFFF4F6F9);
  static const _panelBg = Colors.white;
  static const _sectionBg = Color(0xFFF7F8FB);
  static const _fieldBg = Color(0xFFECEFF4);
  static const _titleColor = Color(0xFF191C1E);
  static const _textColor = Color(0xFF23262F);
  static const _mutedColor = Color(0xFF8E95A3);
  static const _brandColor = Color(0xFF1E40AF);
  static const _brandColorEnd = Color(0xFF3B82F6);
  static const _brandSoftColor = Color(0xFFEAF1FF);
  static const _successColor = Color(0xFF16A34A);
  static const _offlineColor = Color(0xFFB93815);
  static const _warningBg = Color(0xFFFFF4D7);
  static const _warningText = Color(0xFF9A6805);
  static const _panelShadow = Color.fromRGBO(15, 23, 42, 0.06);

  static const List<_AutoOfflinePreset> _presets = [
    _AutoOfflinePreset(id: '15m', hour: 0, minute: 15),
    _AutoOfflinePreset(id: '30m', hour: 0, minute: 30),
    _AutoOfflinePreset(id: '1h', hour: 1, minute: 0),
    _AutoOfflinePreset(id: '2h', hour: 2, minute: 0),
    _AutoOfflinePreset(id: '4h', hour: 4, minute: 0),
    _AutoOfflinePreset.custom(id: 'custom'),
  ];

  final ShopController controller = Get.isRegistered<ShopController>()
      ? Get.find<ShopController>()
      : Get.put(ShopController());
  final UserController userController = Get.find<UserController>();

  bool _draftInitialized = false;
  String? _draftShopIdentity;
  bool _draftOnline = false;
  bool _draftAutoOffline = false;
  int _draftHour = 0;
  int _draftMinute = 0;
  int _syncedDelayHour = 0;
  int _syncedDelayMinute = 0;
  bool _isSaving = false;
  DateTime _lastSyncedAt = DateTime.now();

  bool get _isZh =>
      Get.locale?.languageCode.toLowerCase().startsWith('zh') ?? true;

  @override
  void initState() {
    super.initState();
    if (userController.isLoggedIn.value) {
      controller.loadShop();
    }
  }

  String _text(String zh, String en) => _isZh ? zh : en;

  String _shopIdentity(UserShopEntity shop) =>
      '${shop.id ?? ''}|${shop.uuid ?? ''}';

  Duration? _resolveDelayFromBackendTime({
    required int? hour,
    required int? minute,
  }) {
    if (hour == null || minute == null) {
      return null;
    }

    final now = DateTime.now();
    var scheduled = DateTime(
      now.year,
      now.month,
      now.day,
      hour,
      0,
    ).add(Duration(minutes: minute));

    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    return scheduled.difference(now);
  }

  DateTime? _resolveBackendScheduleFromDraft() {
    if (!_hasDurationSet()) {
      return null;
    }

    return DateTime.now().add(
      Duration(hours: _draftHour, minutes: _draftMinute),
    );
  }

  void _syncDraftFromShop(UserShopEntity shop) {
    final draftDelay = _resolveDelayFromBackendTime(
      hour: shop.hour,
      minute: shop.minute,
    );

    _draftInitialized = true;
    _draftShopIdentity = _shopIdentity(shop);
    _draftOnline = shop.isOnline ?? false;
    _draftAutoOffline = shop.openAutoClose ?? false;
    _draftHour = draftDelay?.inHours ?? 0;
    _draftMinute = draftDelay?.inMinutes.remainder(60) ?? 0;
    _syncedDelayHour = _draftHour;
    _syncedDelayMinute = _draftMinute;
    _lastSyncedAt = DateTime.now();
  }

  Future<bool> _confirmSwitch(String messageKey) async {
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: Text('app.system.tips.title'.tr),
        content: Text(messageKey.tr),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: Text('app.common.cancel'.tr),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            child: Text('app.common.confirm'.tr),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  String _shopOnlineConfirmKey(bool value) => value
      ? 'app.user.shop.message.confirm_online_on'
      : 'app.user.shop.message.confirm_online_off';

  String _shopOnlineFailedMessage(bool value) => value
      ? 'app.user.shop.message.online_on_failed'.tr
      : 'app.user.shop.message.online_off_failed'.tr;

  String _autoOfflineConfirmKey(bool value) => value
      ? 'app.user.shop.message.confirm_auto_offline_on'
      : 'app.user.shop.message.confirm_auto_offline_off';

  String _autoOfflineFailedMessage(bool value) => value
      ? 'app.user.shop.message.auto_offline_on_failed'.tr
      : 'app.user.shop.message.auto_offline_off_failed'.tr;

  String _resolveShopActionError({
    String? responseMessage,
    dynamic responseData,
    required String fallbackMessage,
  }) {
    final dataText = responseData?.toString().trim() ?? '';
    if (dataText.isNotEmpty) {
      return dataText;
    }

    final messageText = responseMessage?.trim() ?? '';
    if (messageText.isNotEmpty) {
      return messageText;
    }

    return fallbackMessage;
  }

  String _resolveExceptionError(Object error, String fallbackMessage) {
    if (error is HttpException && error.message.trim().isNotEmpty) {
      return error.message.trim();
    }
    return fallbackMessage;
  }

  bool _hasDurationSet() => _draftHour > 0 || _draftMinute > 0;

  bool _hasChanges(UserShopEntity shop) {
    final statusChanged = _draftOnline != (shop.isOnline ?? false);
    final autoOfflineChanged =
        _draftAutoOffline != (shop.openAutoClose ?? false);
    final scheduleChanged =
        _draftHour != _syncedDelayHour || _draftMinute != _syncedDelayMinute;
    final canPersistSchedule =
        _draftAutoOffline || (shop.openAutoClose ?? false);

    return statusChanged ||
        autoOfflineChanged ||
        (canPersistSchedule && scheduleChanged);
  }

  Future<bool> _submitShopStatusChange(bool targetValue) async {
    try {
      final res = await controller.toggleShopStatus();
      if (res.success) {
        return true;
      }
      AppSnackbar.error(
        _resolveShopActionError(
          responseMessage: res.message,
          responseData: res.datas,
          fallbackMessage: _shopOnlineFailedMessage(targetValue),
        ),
      );
    } catch (error) {
      AppSnackbar.error(
        _resolveExceptionError(error, _shopOnlineFailedMessage(targetValue)),
      );
    }

    await controller.loadShop();
    return false;
  }

  Future<bool> _submitAutoOfflineChange(bool targetValue) async {
    try {
      final res = await controller.toggleAutoOffline(targetValue);
      if (res.success) {
        return true;
      }
      AppSnackbar.error(
        _resolveShopActionError(
          responseMessage: res.message,
          responseData: res.datas,
          fallbackMessage: _autoOfflineFailedMessage(targetValue),
        ),
      );
    } catch (error) {
      AppSnackbar.error(
        _resolveExceptionError(error, _autoOfflineFailedMessage(targetValue)),
      );
    }

    await controller.loadShop();
    return false;
  }

  Future<bool> _submitAutoCloseTime(int hour, int minute) async {
    try {
      await controller.setAutoCloseTime(hour, minute);
      return true;
    } catch (error) {
      AppSnackbar.error(
        _resolveExceptionError(
          error,
          _text('保存自动离线设置失败', 'Failed to save auto-offline setting'),
        ),
      );
      await controller.loadShop();
      return false;
    }
  }

  void _restoreDraftFromController() {
    final refreshedShop = controller.shop.value;
    if (!mounted || refreshedShop == null) {
      return;
    }
    setState(() => _syncDraftFromShop(refreshedShop));
  }

  Future<void> _handleSave(UserShopEntity shop) async {
    if (_isSaving || !_hasChanges(shop)) {
      return;
    }

    final currentOnline = shop.isOnline ?? false;
    final currentAutoOffline = shop.openAutoClose ?? false;
    final statusChanged = _draftOnline != currentOnline;
    final autoOfflineChanged = _draftAutoOffline != currentAutoOffline;

    var saveHour = _draftHour;
    var saveMinute = _draftMinute;
    if (_draftAutoOffline && saveHour == 0 && saveMinute == 0) {
      saveMinute = 30;
    }

    final durationChanged =
        saveHour != _syncedDelayHour || saveMinute != _syncedDelayMinute;
    final shouldSubmitAutoCloseTime = _draftAutoOffline && durationChanged;

    if (statusChanged) {
      final confirmed = await _confirmSwitch(
        _shopOnlineConfirmKey(_draftOnline),
      );
      if (!confirmed) {
        return;
      }
    }

    if (autoOfflineChanged) {
      final confirmed = await _confirmSwitch(
        _autoOfflineConfirmKey(_draftAutoOffline),
      );
      if (!confirmed) {
        return;
      }
    }

    if (!mounted) {
      return;
    }

    if (_draftAutoOffline &&
        saveHour == 0 &&
        saveMinute == 30 &&
        (_draftHour != saveHour || _draftMinute != saveMinute)) {
      setState(() {
        _draftHour = saveHour;
        _draftMinute = saveMinute;
      });
    }

    setState(() => _isSaving = true);

    try {
      if (statusChanged) {
        final saved = await _submitShopStatusChange(_draftOnline);
        if (!saved) {
          _restoreDraftFromController();
          return;
        }
      }

      if (autoOfflineChanged) {
        final saved = await _submitAutoOfflineChange(_draftAutoOffline);
        if (!saved) {
          _restoreDraftFromController();
          return;
        }
      }

      if (shouldSubmitAutoCloseTime) {
        final backendTargetTime = DateTime.now().add(
          Duration(hours: saveHour, minutes: saveMinute),
        );
        final saved = await _submitAutoCloseTime(
          backendTargetTime.hour,
          backendTargetTime.minute,
        );
        if (!saved) {
          _restoreDraftFromController();
          return;
        }
      }

      await controller.loadShop();
      final refreshedShop = controller.shop.value;

      if (mounted && refreshedShop != null) {
        setState(() => _syncDraftFromShop(refreshedShop));
      }

      AppSnackbar.success(_text('店铺设置已保存', 'Shop settings saved'));
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _handleRename() async {
    await Get.toNamed(Routers.SHOP_RENAME);
    await controller.loadShop();
    final refreshedShop = controller.shop.value;
    if (!mounted || refreshedShop == null) {
      return;
    }
    setState(() => _syncDraftFromShop(refreshedShop));
  }

  void _handleCancel(UserShopEntity shop) {
    if (_isSaving) {
      return;
    }

    if (_hasChanges(shop)) {
      setState(() => _syncDraftFromShop(shop));
      return;
    }

    Navigator.maybeOf(context)?.maybePop();
  }

  Future<void> _openCustomDurationPicker() async {
    if (_isSaving) {
      return;
    }

    Duration currentDuration = _hasDurationSet()
        ? Duration(hours: _draftHour, minutes: _draftMinute)
        : const Duration(minutes: 30);

    final selectedDuration = await showModalBottomSheet<Duration>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SafeArea(
          top: false,
          child: StatefulBuilder(
            builder: (context, setModalState) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text('app.common.cancel'.tr),
                        ),
                        Expanded(
                          child: Text(
                            _text('自定义离线时长', 'Custom idle duration'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: _titleColor,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            final safeDuration = currentDuration.inMinutes == 0
                                ? const Duration(minutes: 5)
                                : currentDuration;
                            Navigator.of(context).pop(safeDuration);
                          },
                          child: Text('app.common.confirm'.tr),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 180,
                      child: CupertinoTimerPicker(
                        mode: CupertinoTimerPickerMode.hm,
                        initialTimerDuration: currentDuration,
                        onTimerDurationChanged: (value) {
                          setModalState(() {
                            currentDuration = value;
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _text(
                        '用于无操作后自动停止营业',
                        'Used to stop selling after inactivity',
                      ),
                      style: const TextStyle(
                        color: _mutedColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );

    if (!mounted || selectedDuration == null) {
      return;
    }

    setState(() {
      _draftHour = selectedDuration.inHours;
      _draftMinute = selectedDuration.inMinutes.remainder(60);
    });
  }

  String _shopDisplayName(UserShopEntity shop) {
    final displayName = (shop.shopName ?? shop.name ?? '').trim();
    return displayName.isEmpty ? '-' : displayName;
  }

  String _shopMeta(UserShopEntity shop) {
    final parts = <String>[];
    final nickname = (shop.nickname ?? '').trim();
    if (nickname.isNotEmpty) {
      parts.add(nickname);
    }

    final uuid = (shop.uuid ?? shop.id ?? '').trim();
    if (uuid.isNotEmpty) {
      final shortened = uuid.length > 8 ? uuid.substring(0, 8) : uuid;
      parts.add('#$shortened');
    }

    if (parts.isEmpty) {
      return _text('店铺信息已同步', 'Shop information synced');
    }
    return parts.join('  |  ');
  }

  String _statusLabel(bool value) =>
      _text(value ? '在线' : '离线', value ? 'Online' : 'Offline');

  String _statusPrefix() => _text('目前状态: ', 'Current: ');

  String _formatClock(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    final second = time.second.toString().padLeft(2, '0');
    return '$hour:$minute:$second';
  }

  String _formatDurationClock(int hour, int minute) {
    final h = hour.toString().padLeft(2, '0');
    final m = minute.toString().padLeft(2, '0');
    return '$h:$m:00';
  }

  String _formattedBackendClock() {
    final target = _resolveBackendScheduleFromDraft();
    if (target == null) {
      return '--:--';
    }
    final hour = target.hour.toString().padLeft(2, '0');
    final minute = target.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _presetLabel(_AutoOfflinePreset preset) {
    switch (preset.id) {
      case '15m':
        return '15 min';
      case '30m':
        return '30 min';
      case '1h':
        return '1 h';
      case '2h':
        return '2 h';
      case '4h':
        return '4 h';
      case 'custom':
        return _text('自定义', 'Custom');
      default:
        return '';
    }
  }

  bool _isPresetSelected(_AutoOfflinePreset preset) {
    if (preset.isCustom) {
      if (!_hasDurationSet()) {
        return false;
      }
      for (final candidate in _presets) {
        if (!candidate.isCustom &&
            candidate.hour == _draftHour &&
            candidate.minute == _draftMinute) {
          return false;
        }
      }
      return true;
    }

    return preset.hour == _draftHour && preset.minute == _draftMinute;
  }

  String _expectedOfflineValue() {
    final target = _resolveBackendScheduleFromDraft();
    if (!_draftAutoOffline || target == null) {
      return '--:--:--';
    }
    return _formatClock(target);
  }

  Widget _buildTopNavigation(UserShopEntity? shop) {
    final canSave = shop != null && _hasChanges(shop) && !_isSaving;

    return SettingsStyleTopNavigation(
      title: 'app.user.shop.setting'.tr,
      horizontalPadding: 16,
      actions: [
        TextButton(
          onPressed: canSave ? () => _handleSave(shop) : null,
          style: TextButton.styleFrom(
            minimumSize: const Size(44, 36),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            foregroundColor: _brandColor,
          ),
          child: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(
                  'app.common.save'.tr,
                  style: TextStyle(
                    color: canSave ? _brandColor : _mutedColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final loggedIn = userController.isLoggedIn.value;
      final shop = loggedIn ? controller.shop.value : null;

      if (shop != null &&
          (!_draftInitialized || _draftShopIdentity != _shopIdentity(shop))) {
        _syncDraftFromShop(shop);
      }

      return Scaffold(
        backgroundColor: _pageBg,
        body: Stack(
          children: [
            Positioned.fill(
              child: !loggedIn
                  ? const LoginRequiredPrompt()
                  : shop == null
                  ? const _ShopSettingLoadingState()
                  : _buildLoggedInBody(shop),
            ),
            _buildTopNavigation(shop),
          ],
        ),
      );
    });
  }

  Widget _buildLoggedInBody(UserShopEntity shop) {
    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(14, 92, 14, 28),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: AbsorbPointer(
            absorbing: _isSaving,
            child: Container(
              decoration: BoxDecoration(
                color: _panelBg,
                borderRadius: BorderRadius.circular(28),
                boxShadow: const [
                  BoxShadow(
                    color: _panelShadow,
                    blurRadius: 28,
                    offset: Offset(0, 16),
                    spreadRadius: -18,
                  ),
                ],
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildShopIdentityCard(shop),
                  const SizedBox(height: 14),
                  _buildStatusSection(),
                  const SizedBox(height: 14),
                  _buildAutoOfflineSection(),
                  const SizedBox(height: 14),
                  _buildNoticeBanner(),
                  const SizedBox(height: 18),
                  _buildFooterActions(shop),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildShopIdentityCard(UserShopEntity shop) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _sectionBg,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _ShopAvatar(imageUrl: (shop.avatar ?? '').trim()),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _brandSoftColor,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'OFFICIAL VENDOR',
                        style: TextStyle(
                          color: _brandColor,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _shopDisplayName(shop),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _titleColor,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _shopMeta(shop),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _mutedColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'app.user.shop.name.label'.tr,
            style: const TextStyle(
              color: _mutedColor,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _handleRename,
              borderRadius: BorderRadius.circular(16),
              child: Ink(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 15,
                ),
                decoration: BoxDecoration(
                  color: _fieldBg,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _shopDisplayName(shop),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _textColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Icon(
                      Icons.edit_outlined,
                      size: 16,
                      color: _mutedColor,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusSection() {
    final activeColor = _draftOnline ? _successColor : _offlineColor;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _sectionBg,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _text('营业状态', 'Business status'),
                      style: const TextStyle(
                        color: _titleColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    RichText(
                      text: TextSpan(
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                        ),
                        children: [
                          TextSpan(
                            text: _statusPrefix(),
                            style: const TextStyle(color: _mutedColor),
                          ),
                          TextSpan(
                            text: _statusLabel(_draftOnline),
                            style: TextStyle(color: activeColor),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _text('同步时间', 'LAST UPDATE'),
                    style: const TextStyle(
                      color: _mutedColor,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatClock(_lastSyncedAt),
                    style: const TextStyle(
                      color: _textColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: _fieldBg,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _StatusSegment(
                    label: _text('在线', 'Online'),
                    selected: _draftOnline,
                    onTap: () => setState(() => _draftOnline = true),
                  ),
                ),
                Expanded(
                  child: _StatusSegment(
                    label: _text('离线', 'Offline'),
                    selected: !_draftOnline,
                    onTap: () => setState(() => _draftOnline = false),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAutoOfflineSection() {
    final idleLimit = _hasDurationSet()
        ? _formatDurationClock(_draftHour, _draftMinute)
        : _text('未设置', 'Unset');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _sectionBg,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'app.user.shop.automatic_offline'.tr,
                      style: const TextStyle(
                        color: _titleColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _text('无操作后自动停止营业', 'Stop selling after inactivity'),
                      style: const TextStyle(
                        color: _mutedColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _text(
                        '保存时会换算成具体离线时刻提交给后端',
                        'Will be converted to a clock time when saving',
                      ),
                      style: const TextStyle(
                        color: _mutedColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _InlineToggle(
                value: _draftAutoOffline,
                onChanged: (value) {
                  setState(() {
                    _draftAutoOffline = value;
                    if (value && !_hasDurationSet()) {
                      _draftMinute = 30;
                    }
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 14),
          AnimatedOpacity(
            duration: const Duration(milliseconds: 180),
            opacity: _draftAutoOffline ? 1 : 0.68,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final chipWidth = (constraints.maxWidth - 16) / 3;
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _presets.map((preset) {
                    return SizedBox(
                      width: chipWidth,
                      child: _DurationChip(
                        label: _presetLabel(preset),
                        selected: _isPresetSelected(preset),
                        onTap: () {
                          if (preset.isCustom) {
                            _openCustomDurationPicker();
                            return;
                          }
                          setState(() {
                            _draftHour = preset.hour;
                            _draftMinute = preset.minute;
                          });
                        },
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _MetaValueBlock(
                  label: _text('预计离线', 'EXPECTED OFFLINE'),
                  value: _expectedOfflineValue(),
                  highlight: _draftAutoOffline,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _MetaValueBlock(
                  label: _text('提交时间', 'BACKEND TIME'),
                  value: _draftAutoOffline
                      ? _formattedBackendClock()
                      : idleLimit,
                  highlight: _hasDurationSet(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNoticeBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _warningBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(
              Icons.warning_amber_rounded,
              size: 18,
              color: _warningText,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _text('重要提示', 'Important note'),
                  style: const TextStyle(
                    color: _warningText,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'app.user.shop.notice'.tr,
                  style: const TextStyle(
                    color: _warningText,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooterActions(UserShopEntity shop) {
    final hasChanges = _hasChanges(shop);

    return Row(
      children: [
        Expanded(
          child: _SecondaryFooterButton(
            label: 'app.common.cancel'.tr,
            onPressed: () => _handleCancel(shop),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: _PrimaryFooterButton(
            label: _text('保存设置', 'Save Settings'),
            loading: _isSaving,
            onPressed: hasChanges ? () => _handleSave(shop) : null,
          ),
        ),
      ],
    );
  }
}

class _ShopSettingLoadingState extends StatelessWidget {
  const _ShopSettingLoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.only(top: 56),
        child: CircularProgressIndicator(),
      ),
    );
  }
}

class _ShopAvatar extends StatelessWidget {
  const _ShopAvatar({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    Widget child;
    if (imageUrl.isEmpty) {
      child = const Center(
        child: Icon(
          Icons.storefront_rounded,
          size: 24,
          color: Color(0xFF24409E),
        ),
      );
    } else {
      child = Image.network(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return const Center(
            child: Icon(
              Icons.storefront_rounded,
              size: 24,
              color: Color(0xFF24409E),
            ),
          );
        },
      );
    }

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFDDE7FF),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(37, 99, 235, 0.12),
            blurRadius: 16,
            offset: Offset(0, 8),
            spreadRadius: -10,
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

class _StatusSegment extends StatelessWidget {
  const _StatusSegment({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: selected ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        boxShadow: selected
            ? const [
                BoxShadow(
                  color: Color.fromRGBO(15, 23, 42, 0.08),
                  blurRadius: 16,
                  offset: Offset(0, 8),
                  spreadRadius: -12,
                ),
              ]
            : const [],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 11),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: selected
                    ? const Color(0xFF1A1F36)
                    : const Color(0xFF8E95A3),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InlineToggle extends StatelessWidget {
  const _InlineToggle({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 38,
        height: 22,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: value ? const Color(0xFF2F63F2) : const Color(0xFFD6DBE5),
          borderRadius: BorderRadius.circular(999),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 180),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 18,
            height: 18,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}

class _DurationChip extends StatelessWidget {
  const _DurationChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Ink(
          height: 40,
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF214FDF) : Colors.white,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : const Color(0xFF475467),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MetaValueBlock extends StatelessWidget {
  const _MetaValueBlock({
    required this.label,
    required this.value,
    required this.highlight,
  });

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF9AA1AF),
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          value,
          style: TextStyle(
            color: highlight
                ? const Color(0xFF214FDF)
                : const Color(0xFF475467),
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _SecondaryFooterButton extends StatelessWidget {
  const _SecondaryFooterButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onPressed == null ? 0.55 : 1,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Ink(
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F3F6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF475467),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PrimaryFooterButton extends StatelessWidget {
  const _PrimaryFooterButton({
    required this.label,
    required this.loading,
    required this.onPressed,
  });

  final String label;
  final bool loading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    return Opacity(
      opacity: enabled ? 1 : 0.65,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              _ShopSettingPageState._brandColor,
              _ShopSettingPageState._brandColorEnd,
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(
              color: Color.fromRGBO(59, 130, 246, 0.22),
              blurRadius: 20,
              offset: Offset(0, 12),
              spreadRadius: -12,
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: enabled ? onPressed : null,
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: 48,
              child: Center(
                child: loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : Text(
                        label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AutoOfflinePreset {
  const _AutoOfflinePreset({
    required this.id,
    required this.hour,
    required this.minute,
  }) : isCustom = false;

  const _AutoOfflinePreset.custom({required this.id})
    : hour = 0,
      minute = 0,
      isCustom = true;

  final String id;
  final int hour;
  final int minute;
  final bool isCustom;
}
