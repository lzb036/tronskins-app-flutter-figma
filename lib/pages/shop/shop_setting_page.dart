import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tronskins_app/api/model/entity/user/user_shop_entity.dart';
import 'package:tronskins_app/common/http/http_helper.dart';
import 'package:tronskins_app/common/utils/app_snackbar.dart';
import 'package:tronskins_app/common/widgets/figma_confirmation_dialog.dart';
import 'package:tronskins_app/common/widgets/login_required_prompt.dart';
import 'package:tronskins_app/common/widgets/settings_style_app_bar.dart';
import 'package:tronskins_app/controllers/shop/shop_controller.dart';
import 'package:tronskins_app/controllers/user/user_controller.dart';

class ShopSettingPage extends StatefulWidget {
  const ShopSettingPage({super.key});

  @override
  State<ShopSettingPage> createState() => _ShopSettingPageState();
}

class _ShopSettingPageState extends State<ShopSettingPage> {
  static const _pageBg = Color(0xFFF7F9FB);
  static const _sectionBg = Colors.white;
  static const _fieldBg = Color(0xFFE0E3E5);
  static const _chipBg = Color(0xFFE6E8EA);
  static const _pillBg = Color(0xFFECEEF0);
  static const _titleColor = Color(0xFF191C1E);
  static const _textColor = Color(0xFF0F172A);
  static const _mutedColor = Color(0xFF444653);
  static const _subtleColor = Color(0xFF94A3B8);
  static const _brandColor = Color(0xFF00288E);
  static const _brandColorEnd = Color(0xFF0058BE);
  static const _successColor = Color(0xFF10B981);
  static const _offlineColor = Color(0xFF94A3B8);
  static const _warningBg = Color(0xFFFFFBEB);
  static const _warningText = Color(0xFF92400E);
  static const _warningBodyText = Color.fromRGBO(146, 64, 14, 0.8);
  static const _warningBorder = Color.fromRGBO(245, 158, 11, 0.2);
  static const _lineColor = Color(0xFFECEEF0);
  static const _footerBg = Color.fromRGBO(255, 255, 255, 0.7);

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
  final TextEditingController _shopNameController = TextEditingController();
  final FocusNode _shopNameFocusNode = FocusNode();

  bool _draftInitialized = false;
  String? _draftShopIdentity;
  String _draftShopName = '';
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

  @override
  void dispose() {
    _shopNameController.dispose();
    _shopNameFocusNode.dispose();
    super.dispose();
  }

  String _text(String zh, String en) => _isZh ? zh : en;

  String _shopIdentity(UserShopEntity shop) =>
      '${shop.id ?? ''}|${shop.uuid ?? ''}';

  String _resolvedUserAvatarUrl() {
    final avatar =
        (userController.user.value?.avatar ??
                userController.user.value?.config?.avatar ??
                '')
            .trim();
    if (avatar.isEmpty) {
      return '';
    }
    if (avatar.startsWith('//')) {
      return 'https:$avatar';
    }
    if (avatar.startsWith('http://') || avatar.startsWith('https://')) {
      return avatar;
    }
    return 'https://www.tronskins.com/fms/image$avatar';
  }

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
    final shopName = _shopName(shop);

    _draftInitialized = true;
    _draftShopIdentity = _shopIdentity(shop);
    _draftShopName = shopName;
    _draftOnline = shop.isOnline ?? false;
    _draftAutoOffline = shop.openAutoClose ?? false;
    _draftHour = draftDelay?.inHours ?? 0;
    _draftMinute = draftDelay?.inMinutes.remainder(60) ?? 0;
    _syncedDelayHour = _draftHour;
    _syncedDelayMinute = _draftMinute;
    _lastSyncedAt = DateTime.now();
    if (_shopNameController.text != shopName) {
      _shopNameController.value = TextEditingValue(
        text: shopName,
        selection: TextSelection.collapsed(offset: shopName.length),
      );
    }
  }

  Future<bool> _confirmSwitch(String messageKey) async {
    final confirmed = await showFigmaModal<bool>(
      context: context,
      child: FigmaConfirmationDialog(
        title: 'app.system.tips.title'.tr,
        message: messageKey.tr,
        primaryLabel: 'app.common.confirm'.tr,
        secondaryLabel: 'app.common.cancel'.tr,
        onPrimary: () => popModalRoute(context, true),
        onSecondary: () => popModalRoute(context, false),
        icon: Icons.storefront_outlined,
        accentColor: _brandColor,
        iconColor: _brandColor,
        iconBackgroundColor: _brandColor.withValues(alpha: 0.10),
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
    final nameChanged = _draftShopName != _shopName(shop);
    final statusChanged = _draftOnline != (shop.isOnline ?? false);
    final autoOfflineChanged =
        _draftAutoOffline != (shop.openAutoClose ?? false);
    final scheduleChanged =
        _draftHour != _syncedDelayHour || _draftMinute != _syncedDelayMinute;
    final canPersistSchedule =
        _draftAutoOffline || (shop.openAutoClose ?? false);

    return nameChanged ||
        statusChanged ||
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

  Future<bool> _submitShopName(String name) async {
    try {
      await controller.changeShopName(name);
      return true;
    } catch (error) {
      AppSnackbar.error(
        _resolveExceptionError(
          error,
          _text('保存店铺名称失败', 'Failed to save shop name'),
        ),
      );
    }

    await controller.loadShop();
    return false;
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

    FocusScope.of(context).unfocus();

    final currentShopName = _shopName(shop);
    final saveShopName = _draftShopName.trim();
    final nameChanged = saveShopName != currentShopName;
    final currentOnline = shop.isOnline ?? false;
    final currentAutoOffline = shop.openAutoClose ?? false;
    final statusChanged = _draftOnline != currentOnline;
    final autoOfflineChanged = _draftAutoOffline != currentAutoOffline;

    if (nameChanged && saveShopName.isEmpty) {
      _shopNameFocusNode.requestFocus();
      AppSnackbar.error('app.user.shop.name.change_placeholder'.tr);
      return;
    }

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
      if (nameChanged) {
        final saved = await _submitShopName(saveShopName);
        if (!saved) {
          _restoreDraftFromController();
          return;
        }
      }

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

  void _handleCancel(UserShopEntity shop) {
    if (_isSaving) {
      return;
    }

    FocusScope.of(context).unfocus();

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

    final selectedDuration = await Navigator.of(context).push<Duration>(
      MaterialPageRoute(
        builder: (context) => _CustomDurationPickerPage(
          initialHour: _hasDurationSet() ? _draftHour : 0,
          initialMinute: _hasDurationSet() ? _draftMinute : 30,
          isZh: _isZh,
        ),
      ),
    );

    if (!mounted || selectedDuration == null) {
      return;
    }

    setState(() {
      _draftHour = selectedDuration.inHours;
      _draftMinute = selectedDuration.inMinutes.remainder(60);
    });
  }

  String _shopName(UserShopEntity shop) =>
      (shop.shopName ?? shop.name ?? '').trim();

  String _shopDisplayName(UserShopEntity shop) {
    final displayName = _draftInitialized ? _draftShopName : _shopName(shop);
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

  String _formatDurationSummary(Duration duration) {
    final hour = duration.inHours;
    final minute = duration.inMinutes.remainder(60);
    final parts = <String>[];

    if (hour > 0) {
      parts.add(_text('$hour 小时', '$hour h'));
    }
    if (minute > 0) {
      parts.add(_text('$minute 分钟', '$minute min'));
    }

    if (parts.isEmpty) {
      return _text('0 分钟', '0 min');
    }

    return parts.join(' ');
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

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SettingsStyleInlineTopBar(
        title: 'app.user.shop.setting'.tr,
        includeTopInset: true,
        actions: [
          TextButton(
            onPressed: canSave ? () => _handleSave(shop) : null,
            style: TextButton.styleFrom(
              minimumSize: const Size(44, 44),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              foregroundColor: _brandColor,
            ),
            child: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(_brandColor),
                    ),
                  )
                : Text(
                    'app.common.save'.tr,
                    style: TextStyle(
                      color: canSave ? _brandColor : _subtleColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      height: 24 / 16,
                    ),
                  ),
          ),
        ],
      ),
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
            if (loggedIn && shop != null) _buildBottomActionBar(shop),
          ],
        ),
      );
    });
  }

  Widget _buildLoggedInBody(UserShopEntity shop) {
    final viewPadding = MediaQuery.of(context).padding;
    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        16,
        viewPadding.top + 80,
        16,
        164 + viewPadding.bottom,
      ),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 390),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildShopIdentityCard(shop),
              const SizedBox(height: 24),
              _buildStatusSection(),
              const SizedBox(height: 24),
              _buildAutoOfflineSection(),
              const SizedBox(height: 20),
              _buildNoticeBanner(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomActionBar(UserShopEntity shop) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            color: _footerBg,
            padding: EdgeInsets.fromLTRB(24, 20, 24, 20 + bottomInset),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 390),
                child: _buildFooterActions(shop),
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
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _sectionBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _ShopAvatar(imageUrl: _resolvedUserAvatarUrl()),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'OFFICIAL VENDOR',
                      style: TextStyle(
                        color: _brandColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        height: 16 / 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _shopDisplayName(shop),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _titleColor,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                        height: 28 / 20,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            _shopMeta(shop),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _mutedColor,
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              height: 20 / 14,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.copy_rounded,
                          size: 14,
                          color: _mutedColor,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'app.user.shop.name.label'.tr,
            style: const TextStyle(
              color: _mutedColor,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              height: 20 / 14,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: _fieldBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: TextField(
              controller: _shopNameController,
              focusNode: _shopNameFocusNode,
              enabled: !_isSaving,
              textInputAction: TextInputAction.done,
              maxLines: 1,
              cursorColor: _brandColor,
              onChanged: (value) {
                final normalized = value.trim();
                if (normalized == _draftShopName) {
                  return;
                }
                setState(() => _draftShopName = normalized);
              },
              onTapOutside: (_) => _shopNameFocusNode.unfocus(),
              onSubmitted: (_) => _shopNameFocusNode.unfocus(),
              decoration: InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                hintText: 'app.user.shop.name.change_placeholder'.tr,
                hintStyle: const TextStyle(
                  color: _subtleColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  height: 24 / 16,
                ),
              ),
              style: const TextStyle(
                color: _titleColor,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                height: 24 / 16,
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
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _sectionBg,
        borderRadius: BorderRadius.circular(12),
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
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        letterSpacing: -0.45,
                        height: 28 / 18,
                      ),
                    ),
                    const SizedBox(height: 6),
                    RichText(
                      text: TextSpan(
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          height: 20 / 14,
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
                      fontSize: 10,
                      fontWeight: FontWeight.w400,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatClock(_lastSyncedAt),
                    style: const TextStyle(
                      color: _textColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      height: 20 / 14,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          Align(
            alignment: Alignment.center,
            child: _FigmaStatusToggle(
              isOnline: _draftOnline,
              onChanged: (value) => setState(() => _draftOnline = value),
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
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _sectionBg,
        borderRadius: BorderRadius.circular(12),
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
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        letterSpacing: -0.45,
                        height: 28 / 18,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _text('无操作后自动停止营业', 'Stop selling after inactivity'),
                      style: const TextStyle(
                        color: _mutedColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        height: 20 / 14,
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
                final chipWidth = (constraints.maxWidth - 24) / 3;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: _presets.map((preset) {
                    return SizedBox(
                      width: chipWidth,
                      child: _DurationChip(
                        label: _presetLabel(preset),
                        selected: _isPresetSelected(preset),
                        dashed: preset.isCustom,
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
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.only(top: 9),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: _lineColor)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _MetaValueBlock(
                    label: _text('EXPECTED OFFLINE', 'EXPECTED OFFLINE'),
                    value: _expectedOfflineValue(),
                    highlight: _draftAutoOffline,
                    alignEnd: false,
                    accentBlue: true,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _MetaValueBlock(
                    label: _text('IDLE TIME', 'IDLE TIME'),
                    value: idleLimit,
                    highlight: _hasDurationSet(),
                    alignEnd: true,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoticeBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(21),
      decoration: BoxDecoration(
        color: _warningBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _warningBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(
              Icons.warning_amber_rounded,
              size: 22,
              color: _warningText,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _text('重要通知', 'Important notice'),
                  style: const TextStyle(
                    color: _warningText,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    height: 20 / 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _text(
                    '当您的店铺处于离线状态时，所有已上架的商品将自动在市场中隐藏。建议开启自动离线功能以保护您的交易活跃度。',
                    'When your shop is offline, all listed items will be hidden from the market automatically. Enable auto offline to protect your trading activity.',
                  ),
                  style: const TextStyle(
                    color: _warningBodyText,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    height: 19.5 / 12,
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
        const SizedBox(width: 16),
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
        child: Icon(Icons.person_rounded, size: 36, color: Color(0xFF24409E)),
      );
    } else {
      child = Image.network(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return const Center(
            child: Icon(
              Icons.person_rounded,
              size: 36,
              color: Color(0xFF24409E),
            ),
          );
        },
      );
    }

    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFECEEF0),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

class _FigmaStatusToggle extends StatelessWidget {
  const _FigmaStatusToggle({required this.isOnline, required this.onChanged});

  final bool isOnline;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 240,
      height: 64,
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: _ShopSettingPageState._pillBg,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onChanged(true),
                    child: Center(
                      child: Text(
                        '在线',
                        style: TextStyle(
                          color: isOnline
                              ? Colors.transparent
                              : _ShopSettingPageState._subtleColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          height: 24 / 16,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onChanged(false),
                    child: Center(
                      child: Text(
                        '离线',
                        style: TextStyle(
                          color: isOnline
                              ? _ShopSettingPageState._subtleColor
                              : Colors.transparent,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          height: 24 / 16,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          AnimatedAlign(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: isOnline ? Alignment.centerLeft : Alignment.centerRight,
            child: Container(
              width: 114,
              height: 52,
              margin: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(999),
                boxShadow: const [
                  BoxShadow(
                    color: Color.fromRGBO(0, 0, 0, 0.1),
                    blurRadius: 15,
                    offset: Offset(0, 10),
                    spreadRadius: -3,
                  ),
                  BoxShadow(
                    color: Color.fromRGBO(0, 0, 0, 0.1),
                    blurRadius: 6,
                    offset: Offset(0, 4),
                    spreadRadius: -4,
                  ),
                ],
              ),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: isOnline
                            ? _ShopSettingPageState._successColor
                            : _ShopSettingPageState._offlineColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isOnline ? '在线' : '离线',
                      style: const TextStyle(
                        color: _ShopSettingPageState._textColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        height: 24 / 16,
                      ),
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
        width: 48,
        height: 24,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: value
              ? _ShopSettingPageState._brandColor
              : _ShopSettingPageState._chipBg,
          borderRadius: BorderRadius.circular(999),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 180),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 16,
            height: 16,
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
    this.dashed = false,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool dashed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final decoration = BoxDecoration(
      color: selected
          ? _ShopSettingPageState._brandColor
          : dashed
          ? _ShopSettingPageState._pillBg
          : _ShopSettingPageState._chipBg,
      borderRadius: BorderRadius.circular(8),
      border: dashed
          ? Border.all(
              color: const Color(0xFFC4C5D5),
              width: 1,
              strokeAlign: BorderSide.strokeAlignInside,
            )
          : null,
      boxShadow: selected
          ? const [
              BoxShadow(
                color: Color.fromRGBO(30, 58, 138, 0.1),
                blurRadius: 15,
                offset: Offset(0, 10),
                spreadRadius: -3,
              ),
              BoxShadow(
                color: Color.fromRGBO(30, 58, 138, 0.1),
                blurRadius: 6,
                offset: Offset(0, 4),
                spreadRadius: -4,
              ),
            ]
          : const [],
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Ink(
          height: 44,
          decoration: decoration,
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: selected
                    ? Colors.white
                    : _ShopSettingPageState._mutedColor,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                height: 20 / 14,
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
    this.alignEnd = false,
    this.accentBlue = false,
  });

  final String label;
  final String value;
  final bool highlight;
  final bool alignEnd;
  final bool accentBlue;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: _ShopSettingPageState._mutedColor,
            fontSize: 10,
            fontWeight: FontWeight.w400,
            letterSpacing: -0.5,
            height: 15 / 10,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: accentBlue
                ? _ShopSettingPageState._brandColor
                : highlight
                ? _ShopSettingPageState._titleColor
                : _ShopSettingPageState._mutedColor,
            fontSize: 16,
            fontWeight: FontWeight.w800,
            height: 24 / 16,
          ),
        ),
      ],
    );
  }
}

class _CustomDurationMetricCard extends StatelessWidget {
  const _CustomDurationMetricCard({
    required this.label,
    required this.value,
    this.accent = false,
  });

  final String label;
  final String value;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: accent ? const Color.fromRGBO(30, 64, 175, 0.08) : Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: accent
                  ? const Color.fromRGBO(30, 64, 175, 0.72)
                  : _ShopSettingPageState._mutedColor,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              height: 15 / 10,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: accent
                  ? _ShopSettingPageState._brandColor
                  : _ShopSettingPageState._titleColor,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
              height: 24 / 18,
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomDurationPickerColumn extends StatelessWidget {
  const _CustomDurationPickerColumn({
    required this.label,
    required this.unitLabel,
    required this.selectedValue,
    required this.itemCount,
    required this.controller,
    required this.onSelectedItemChanged,
  });

  final String label;
  final String unitLabel;
  final int selectedValue;
  final int itemCount;
  final FixedExtentScrollController controller;
  final ValueChanged<int> onSelectedItemChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: _ShopSettingPageState._mutedColor,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              height: 16 / 11,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 176,
            child: CupertinoPicker.builder(
              scrollController: controller,
              itemExtent: 44,
              backgroundColor: Colors.transparent,
              diameterRatio: 1.28,
              squeeze: 1.12,
              useMagnifier: true,
              magnification: 1.04,
              selectionOverlay: Container(
                margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color.fromRGBO(248, 250, 252, 0.98),
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onSelectedItemChanged: onSelectedItemChanged,
              childCount: itemCount,
              itemBuilder: (context, index) {
                final selected = index == selectedValue;
                return Center(
                  child: RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: index.toString().padLeft(2, '0'),
                          style: TextStyle(
                            color: selected
                                ? _ShopSettingPageState._titleColor
                                : const Color.fromRGBO(148, 163, 184, 0.72),
                            fontSize: selected ? 28 : 22,
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            height: 1,
                          ),
                        ),
                        TextSpan(
                          text: ' $unitLabel',
                          style: TextStyle(
                            color: selected
                                ? _ShopSettingPageState._titleColor
                                : const Color.fromRGBO(148, 163, 184, 0.72),
                            fontSize: selected ? 15 : 13,
                            fontWeight: FontWeight.w600,
                            height: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
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
          borderRadius: BorderRadius.circular(8),
          child: Ink(
            height: 52,
            decoration: BoxDecoration(
              color: _ShopSettingPageState._chipBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                label,
                style: const TextStyle(
                  color: _ShopSettingPageState._titleColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  height: 20 / 14,
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
          borderRadius: BorderRadius.circular(8),
          boxShadow: const [
            BoxShadow(
              color: Color.fromRGBO(59, 130, 246, 0.2),
              blurRadius: 25,
              offset: Offset(0, 20),
              spreadRadius: -5,
            ),
            BoxShadow(
              color: Color.fromRGBO(59, 130, 246, 0.2),
              blurRadius: 10,
              offset: Offset(0, 8),
              spreadRadius: -6,
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: enabled ? onPressed : null,
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 52,
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
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          height: 20 / 14,
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
