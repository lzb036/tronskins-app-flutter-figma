import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:tronskins_app/common/utils/app_snackbar.dart';
import 'package:tronskins_app/common/widgets/back_to_top_overlay.dart';
import 'package:tronskins_app/common/widgets/figma_confirmation_dialog.dart';
import 'package:tronskins_app/common/widgets/glass_notice_dialog.dart';
import 'package:tronskins_app/common/widgets/login_required_prompt.dart';
import 'package:tronskins_app/common/widgets/settings_style_app_bar.dart';
import 'package:tronskins_app/controllers/auth/steam_controller.dart';
import 'package:tronskins_app/controllers/user/user_controller.dart';
import 'package:tronskins_app/routes/app_routes.dart';

class SteamSettingPage extends StatefulWidget {
  const SteamSettingPage({super.key});

  @override
  State<SteamSettingPage> createState() => _SteamSettingPageState();
}

class _SteamSettingPageState extends State<SteamSettingPage> {
  static const Color _pageBackground = Color(0xFFF7F9FB);
  static const Color _cardBackground = Colors.white;
  static const Color _cardShadowColor = Color.fromRGBO(25, 28, 30, 0.04);
  static const Color _titleColor = Color(0xFF191C1E);
  static const Color _mutedColor = Color(0xFF757684);
  static const Color _fieldBackground = Color(0xFFECEEF0);
  static const Color _linkColor = Color(0xFF0058BE);
  static const Color _brandBlue = Color(0xFF1E40AF);
  static const String _imageBaseUrl = 'https://www.tronskins.com/fms/image';

  final SteamController controller = Get.put(SteamController());
  final UserController userController = Get.find<UserController>();
  final TextEditingController tradeUrlController = TextEditingController();
  final TextEditingController apiKeyController = TextEditingController();
  late final Worker _configWorker;
  Worker? _loginWorker;
  bool _sessionPromptVisible = false;
  bool _didResolveInitialUnboundDialog = false;
  bool _isShowingInitialUnboundDialog = false;
  bool _obscureApiKey = true;
  bool _isRefreshingStatus = false;
  bool? _lastVisibleTradeStatus;

  bool get _returnToInventoryAfterUnbind {
    final args = Get.arguments;
    return args is Map && args['fromInventorySessionExpired'] == true;
  }

  @override
  void initState() {
    super.initState();
    tradeUrlController.text = controller.tradeUrl.value;
    apiKeyController.text = controller.apiKey.value;
    _configWorker = ever(controller.config, (_) {
      final nextTradeUrl = controller.tradeUrl.value;
      final nextApiKey = controller.apiKey.value;
      if (tradeUrlController.text != nextTradeUrl) {
        tradeUrlController.text = nextTradeUrl;
      }
      if (apiKeyController.text != nextApiKey) {
        apiKeyController.text = nextApiKey;
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!userController.isLoggedIn.value) {
        return;
      }
      await _loadPageState();
      final args = Get.arguments;
      if (args is Map<String, dynamic> && args['showSteamIdNotMatch'] == true) {
        _showSteamIdMismatchDialog();
      }
    });
    _loginWorker = ever<bool>(userController.isLoggedIn, (loggedIn) async {
      if (!loggedIn) {
        _sessionPromptVisible = false;
        _didResolveInitialUnboundDialog = false;
        _isShowingInitialUnboundDialog = false;
        return;
      }
      await _loadPageState();
    });
  }

  @override
  void dispose() {
    _loginWorker?.dispose();
    _configWorker.dispose();
    tradeUrlController.dispose();
    apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _bindSteam() async {
    final token = await controller.getTemporaryToken();
    if (token == null) {
      _showSnack('app.user.login.message.error'.tr);
      return;
    }
    Get.toNamed(Routers.STEAM_BIND, arguments: token);
  }

  Future<void> _toSteamSession() async {
    final result = await Get.toNamed(
      Routers.STEAM_SESSION,
      arguments: {'steamId': controller.config.value?.steamId ?? ''},
    );

    if (result is Map) {
      final resultMap = Map<String, dynamic>.from(result);
      if (resultMap['verified'] == true) {
        controller.sessionValid.value = true;
        await _loadPageState(promptSessionExpired: false);
        return;
      }

      if (resultMap['showSteamIdNotMatch'] == true) {
        await controller.loadSteamConfig();
        if (!mounted) {
          return;
        }
        _showSteamIdMismatchDialog();
        return;
      }
    }

    if (result == true) {
      controller.sessionValid.value = true;
      await _loadPageState(promptSessionExpired: false);
    }
  }

  Future<void> _loadPageState({bool promptSessionExpired = true}) async {
    await controller.loadSteamConfig();
    if (!mounted) {
      return;
    }

    await _maybeShowInitialUnboundDialog();
    if (!mounted || !promptSessionExpired) {
      return;
    }

    await _maybeShowSessionExpiredDialog();
  }

  Future<void> _maybeShowInitialUnboundDialog() async {
    if (!mounted ||
        _didResolveInitialUnboundDialog ||
        _isShowingInitialUnboundDialog) {
      return;
    }

    if (controller.hasSteamBound) {
      _didResolveInitialUnboundDialog = true;
      return;
    }

    _isShowingInitialUnboundDialog = true;
    await _showInitialUnboundDialog();
    _isShowingInitialUnboundDialog = false;
    _didResolveInitialUnboundDialog = true;
  }

  Future<void> _showInitialUnboundDialog() async {
    await showFigmaModal<void>(
      context: context,
      barrierDismissible: false,
      child: _SteamUnboundDialog(
        message: _steamUnboundDialogMessage,
        onConfirm: () => popModalRoute(context),
      ),
    );

    if (!mounted) {
      return;
    }

    Navigator.of(context).maybePop();
  }

  String get _steamUnboundDialogMessage {
    final language = (Get.locale?.languageCode ?? '').toLowerCase();
    final country = (Get.locale?.countryCode ?? '').toUpperCase();
    if (language == 'zh' && country == 'TW') {
      return '當前尚未綁定 Steam，請先前往 TronSkins 官方網站完成綁定。';
    }
    if (language == 'zh') {
      return '当前尚未绑定 Steam，请先前往 TronSkins 官网完成绑定。';
    }
    return 'Steam is not bound yet. Please go to the TronSkins official '
        'website and bind it first.';
  }

  Future<void> _maybeShowSessionExpiredDialog() async {
    if (_sessionPromptVisible ||
        !controller.hasSteamBound ||
        controller.sessionValid.value) {
      return;
    }

    _sessionPromptVisible = true;
    await showFigmaModal<void>(
      context: context,
      child: FigmaConfirmationDialog(
        icon: Icons.warning_amber_rounded,
        title: 'app.steam.verification'.tr,
        message: 'app.steam.session.expired'.tr,
        primaryLabel: 'app.common.confirm'.tr,
        onPrimary: () {
          popModalRoute(context);
          _toSteamSession();
        },
        secondaryLabel: 'app.common.cancel'.tr,
        onSecondary: () => popModalRoute(context),
      ),
    );
    _sessionPromptVisible = false;
  }

  Future<void> _openTradeUrlPage(String steamId) async {
    await Get.toNamed(Routers.STEAM_TRADE_URL, arguments: steamId);
    await controller.loadSteamConfig();
  }

  Future<void> _openApiKeyPage() async {
    await Get.toNamed(Routers.STEAM_API_KEY);
    await controller.loadSteamConfig();
  }

  Future<void> _refreshStatus() async {
    if (_isRefreshingStatus) {
      return;
    }
    setState(() => _isRefreshingStatus = true);
    try {
      await controller.refreshTradeStatus();
      await controller.checkSession();
    } finally {
      if (mounted) {
        setState(() => _isRefreshingStatus = false);
      }
    }
  }

  void _showSteamIdMismatchDialog() {
    final config = controller.config.value;
    final nickname = (config?.nickname ?? '').trim().isNotEmpty
        ? (config?.nickname ?? '').trim()
        : controller.userNickname.value;
    showFigmaModal<void>(
      context: context,
      child: FigmaConfirmationDialog(
        icon: Icons.manage_accounts_rounded,
        iconColor: const Color(0xFF1E40AF),
        iconBackgroundColor: const Color.fromRGBO(30, 64, 175, 0.10),
        title: 'app.system.tips.warm'.tr,
        message: 'app.steam.message.account_not_match'.tr,
        primaryLabel: 'app.common.confirm'.tr,
        onPrimary: () => popModalRoute(context),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (config?.avatar != null)
              CircleAvatar(
                backgroundImage: CachedNetworkImageProvider(config!.avatar!),
                radius: 30,
              ),
            const SizedBox(height: 12),
            if (nickname.isNotEmpty)
              Text(
                nickname,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  height: 1.4,
                ),
              ),
            const SizedBox(height: 8),
            Text(
              'Steam ID: ${config?.steamId ?? ''}',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _unbindSteam() async {
    final res = await controller.canUnbind();
    if (!res.success) {
      final dataText = res.datas?.trim() ?? '';
      final message = dataText.isNotEmpty
          ? dataText
          : (res.message.trim().isNotEmpty
                ? res.message
                : 'app.user.login.message.error'.tr);
      AppSnackbar.error(message);
      return;
    }
    if (!mounted) {
      return;
    }
    showFigmaModal<void>(
      context: context,
      child: FigmaConfirmationDialog(
        icon: Icons.link_off_rounded,
        title: 'app.system.tips.title'.tr,
        message: 'app.steam.account.unbind_tips'.tr,
        primaryLabel: 'app.common.confirm'.tr,
        onPrimary: () {
          popModalRoute(context);
          Get.toNamed(
            Routers.STEAM_UNBIND,
            arguments: {'returnToInventory': _returnToInventoryAfterUnbind},
          );
        },
        secondaryLabel: 'app.common.cancel'.tr,
        onSecondary: () => popModalRoute(context),
      ),
    );
  }

  void _showSnack(String message) {
    AppSnackbar.info(message);
  }

  Future<void> _copySteamId(String steamId) async {
    if (steamId.isEmpty) {
      return;
    }
    await Clipboard.setData(ClipboardData(text: steamId));
    if (!mounted) {
      return;
    }
    await showCopySuccessNoticeDialog(
      context,
      duration: const Duration(milliseconds: 1200),
    );
  }

  String _tradeStatusChipLabel(bool isTradable) {
    final language = (Get.locale?.languageCode ?? '').toLowerCase();
    if (language == 'zh') {
      return isTradable ? '正常' : '异常';
    }
    return isTradable ? 'Ready' : 'Issue';
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final loggedIn = userController.isLoggedIn.value;

      return Scaffold(
        backgroundColor: _pageBackground,
        appBar: SettingsStyleAppBar(
          title: Text(
            'app.steam.account.management'.tr,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          actions: loggedIn
              ? [
                  Padding(
                    padding: const EdgeInsets.only(right: 24),
                    child: Center(
                      child: _SteamVerificationEntryButton(
                        enabled: controller.hasSteamBound,
                        onTap: _toSteamSession,
                      ),
                    ),
                  ),
                ]
              : const [],
        ),
        body: loggedIn
            ? BackToTopScope(enabled: false, child: _buildLoggedInBody())
            : const LoginRequiredPrompt(),
      );
    });
  }

  Widget _buildLoggedInBody() {
    return Obx(() {
      final config = controller.config.value;
      final steamId = config?.steamId ?? '';
      final avatar = config?.avatar ?? '';
      final isInitialSteamLoading =
          controller.isLoading.value && config == null;
      final steamNickname = (config?.nickname ?? '').trim();
      final fallbackNickname = controller.userNickname.value.trim();
      final nickname = steamNickname.isNotEmpty
          ? steamNickname
          : fallbackNickname;
      final hasNickname = nickname.isNotEmpty && nickname != '-';
      final tradeStatus = controller.tradeStatus.value;
      if (tradeStatus != null) {
        _lastVisibleTradeStatus = tradeStatus;
      }
      final visibleTradeStatus = tradeStatus ?? _lastVisibleTradeStatus;
      final showSteamIdLoading = controller.isLoading.value && steamId.isEmpty;
      final isTradeStatusLoading =
          visibleTradeStatus == null &&
          (controller.isLoading.value || _isRefreshingStatus);
      final isBound = steamId.isNotEmpty;

      return Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 672),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
            children: [
              _buildProfileCard(
                avatarUrl: avatar,
                nickname: hasNickname ? nickname : 'Steam',
                steamId: steamId,
                showSteamIdLoading: showSteamIdLoading,
                isBound: isBound,
                isLoading: isInitialSteamLoading,
              ),
              const SizedBox(height: 24),
              _buildStatusCard(
                tradeStatus: visibleTradeStatus,
                isTradeStatusLoading: isTradeStatusLoading,
                isRefreshing: _isRefreshingStatus,
                isBound: isBound,
                isLoading: isInitialSteamLoading,
              ),
              const SizedBox(height: 24),
              _buildTradeLinkCard(
                steamId: steamId,
                isBound: isBound,
                isLoading: isInitialSteamLoading,
              ),
              const SizedBox(height: 24),
              _buildApiKeyCard(
                isBound: isBound,
                isLoading: isInitialSteamLoading,
              ),
              if (controller.hasChanges || controller.isSaving.value) ...[
                const SizedBox(height: 20),
                _buildSaveButton(),
              ],
              const SizedBox(height: 24),
              _buildFooter(steamId: steamId, isBound: isBound),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildProfileCard({
    required String avatarUrl,
    required String nickname,
    required String steamId,
    required bool showSteamIdLoading,
    required bool isBound,
    required bool isLoading,
  }) {
    if (isLoading) {
      return const _SteamSectionCard(child: _SteamProfileSkeleton());
    }

    return _SteamSectionCard(
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SteamProfileAvatar(
                imageUrl: _resolveSteamAvatarUrl(avatarUrl),
                label: nickname,
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 8.5),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              nickname,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _titleColor,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                height: 22.5 / 18,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          _TopActionButton(
                            label: isBound
                                ? 'app.steam.account.unbind'.tr
                                : 'app.steam.account.bind'.tr,
                            onTap: isBound ? _unbindSteam : _bindSteam,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (showSteamIdLoading)
                        const _SteamSkeletonBox(
                          width: 170,
                          height: 18,
                          radius: 4,
                        )
                      else if (!isBound)
                        Text(
                          'app.steam.message.unbind'.tr,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _mutedColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            height: 20 / 14,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (isBound && !showSteamIdLoading) ...[
            const SizedBox(height: 10),
            _SteamIdRow(steamId: steamId, onCopy: () => _copySteamId(steamId)),
          ],
        ],
      ),
    );
  }

  String _resolveSteamAvatarUrl(String value) {
    final raw = value.trim();
    if (raw.isEmpty) {
      return '';
    }
    if (raw.startsWith('//')) {
      return 'https:$raw';
    }
    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      return raw;
    }
    final path = raw.startsWith('/') ? raw : '/$raw';
    return '$_imageBaseUrl$path';
  }

  Widget _buildStatusCard({
    required bool? tradeStatus,
    required bool isTradeStatusLoading,
    required bool isRefreshing,
    required bool isBound,
    required bool isLoading,
  }) {
    final sessionExpired = !controller.sessionValid.value && isBound;
    final chipBackground = tradeStatus == true
        ? const Color(0xFFECFDF5)
        : const Color(0xFFFEF2F2);
    final chipDotColor = tradeStatus == true
        ? const Color(0xFF10B981)
        : const Color(0xFFEF4444);
    final chipTextColor = tradeStatus == true
        ? const Color(0xFF047857)
        : const Color(0xFFB91C1C);

    return _SteamSectionCard(
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
                      'app.steam.account.status_label'.tr.toUpperCase(),
                      style: const TextStyle(
                        color: _mutedColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        height: 16 / 12,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (isLoading)
                      const Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _SteamSkeletonBox(width: 190, height: 24, radius: 4),
                          _SteamSkeletonBox(width: 76, height: 24, radius: 12),
                        ],
                      )
                    else if (isTradeStatusLoading)
                      const _SteamSkeletonBox(width: 120, height: 24, radius: 4)
                    else if (tradeStatus == null)
                      const Text(
                        '--',
                        style: TextStyle(
                          color: _titleColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          height: 24 / 16,
                        ),
                      )
                    else
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          Text(
                            tradeStatus == true
                                ? 'app.steam.account.status_success'.tr
                                : 'app.steam.account.status_error'.tr,
                            style: const TextStyle(
                              color: _titleColor,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              height: 24 / 16,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: chipBackground,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: chipDotColor,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _tradeStatusChipLabel(tradeStatus == true),
                                  style: TextStyle(
                                    color: chipTextColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    height: 16 / 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Material(
                color: const Color(0xFFF2F4F6),
                borderRadius: BorderRadius.circular(4),
                child: InkWell(
                  borderRadius: BorderRadius.circular(4),
                  onTap: isRefreshing ? null : _refreshStatus,
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child: Center(
                      child: _RefreshActionIcon(
                        color: _linkColor,
                        active: isRefreshing,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (sessionExpired) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    size: 18,
                    color: Color(0xFFB91C1C),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'app.steam.session.expired'.tr,
                      style: const TextStyle(
                        color: Color(0xFFB91C1C),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        height: 18 / 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTradeLinkCard({
    required String steamId,
    required bool isBound,
    required bool isLoading,
  }) {
    return _SteamSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'app.steam.tradeLink_text'.tr.toUpperCase(),
            style: const TextStyle(
              color: _mutedColor,
              fontSize: 12,
              fontWeight: FontWeight.w400,
              height: 16 / 12,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          if (isLoading)
            const _SteamSkeletonBox(height: 118, radius: 4)
          else
            TextField(
              controller: tradeUrlController,
              minLines: 3,
              maxLines: 3,
              onChanged: (value) => controller.tradeUrl.value = value,
              style: const TextStyle(
                color: Color(0xFF444653),
                fontSize: 14,
                fontWeight: FontWeight.w400,
                height: 22.75 / 14,
              ),
              decoration: InputDecoration(
                hintText: isBound
                    ? 'app.steam.tradeLink_text'.tr
                    : 'app.steam.message.unbind'.tr,
                filled: true,
                fillColor: _fieldBackground,
                contentPadding: const EdgeInsets.fromLTRB(16, 15, 16, 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: const BorderSide(color: _brandBlue, width: 1.2),
                ),
              ),
            ),
          const SizedBox(height: 16),
          if (isLoading)
            const _SteamSkeletonBox(height: 48, radius: 4)
          else
            _WideActionButton(
              label: isBound
                  ? 'app.steam.tradeLink_get'.tr
                  : 'app.steam.account.bind_title'.tr,
              icon: Icons.open_in_new_rounded,
              onTap: isBound ? () => _openTradeUrlPage(steamId) : _bindSteam,
              gradient: const LinearGradient(
                colors: [Color(0xFF1E40AF), Color(0xFF2170E4)],
              ),
              foregroundColor: Colors.white,
            ),
        ],
      ),
    );
  }

  Widget _buildApiKeyCard({required bool isBound, required bool isLoading}) {
    return _SteamSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'app.steam.api_key.setting'.tr.toUpperCase(),
            style: const TextStyle(
              color: _mutedColor,
              fontSize: 12,
              fontWeight: FontWeight.w400,
              height: 16 / 12,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          if (isLoading)
            const _SteamSkeletonBox(height: 54, radius: 4)
          else
            TextField(
              controller: apiKeyController,
              obscureText: _obscureApiKey,
              onChanged: (value) => controller.apiKey.value = value,
              style: const TextStyle(
                color: Color(0xFF444653),
                fontSize: 14,
                fontWeight: FontWeight.w400,
                height: 20 / 14,
                letterSpacing: 4.2,
              ),
              decoration: InputDecoration(
                hintText: isBound
                    ? 'app.steam.api_key.setting'.tr
                    : 'app.steam.message.unbind'.tr,
                filled: true,
                fillColor: _fieldBackground,
                contentPadding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: const BorderSide(color: _brandBlue, width: 1.2),
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureApiKey
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 18,
                    color: _mutedColor,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscureApiKey = !_obscureApiKey;
                    });
                  },
                ),
              ),
            ),
          const SizedBox(height: 16),
          if (isLoading)
            const _SteamSkeletonBox(height: 48, radius: 4)
          else
            _WideActionButton(
              label: isBound
                  ? 'app.steam.settings.go_get'.tr
                  : 'app.steam.account.bind_title'.tr,
              icon: Icons.vpn_key_rounded,
              onTap: isBound ? _openApiKeyPage : _bindSteam,
              backgroundColor: const Color(0xFFE6E8EA),
              foregroundColor: _titleColor,
            ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return _WideActionButton(
      label: 'app.common.save'.tr,
      icon: controller.isSaving.value ? null : Icons.save_outlined,
      onTap: controller.isSaving.value
          ? null
          : () async {
              await controller.saveChanges();
              _showSnack('app.system.message.success'.tr);
            },
      gradient: const LinearGradient(
        colors: [Color(0xFF1E40AF), Color(0xFF2170E4)],
      ),
      foregroundColor: Colors.white,
      trailing: controller.isSaving.value
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : null,
    );
  }

  Widget _buildFooter({required String steamId, required bool isBound}) {
    final footerLabel = isBound
        ? 'app.steam.settings.inventory'.tr
        : 'app.steam.account.bind_title'.tr;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 48),
      child: Column(
        children: [
          Text(
            'app.steam.session.tips_1'.tr,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _mutedColor,
              fontSize: 14,
              fontWeight: FontWeight.w400,
              height: 22.75 / 14,
            ),
          ),
          const SizedBox(height: 12),
          InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: isBound
                ? () => Get.toNamed(
                    Routers.STEAM_INVENTORY_SETTING,
                    arguments: steamId,
                  )
                : _bindSteam,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    footerLabel,
                    style: const TextStyle(
                      color: _linkColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      height: 20 / 14,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.help_outline_rounded,
                    size: 14,
                    color: _linkColor,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SteamSectionCard extends StatelessWidget {
  const _SteamSectionCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _SteamSettingPageState._cardBackground,
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(
            color: _SteamSettingPageState._cardShadowColor,
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SteamSkeletonBox extends StatelessWidget {
  const _SteamSkeletonBox({required this.height, this.width, this.radius = 8});

  final double height;
  final double? width;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        width: width ?? double.infinity,
        height: height,
        decoration: BoxDecoration(
          color: _SteamSettingPageState._fieldBackground,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

class _SteamProfileSkeleton extends StatelessWidget {
  const _SteamProfileSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SteamSkeletonBox(width: 64, height: 64, radius: 12),
        SizedBox(width: 20),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(top: 8.5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _SteamSkeletonBox(height: 22, radius: 4)),
                    SizedBox(width: 12),
                    _SteamSkeletonBox(width: 101, height: 36, radius: 4),
                  ],
                ),
                SizedBox(height: 12),
                _SteamSkeletonBox(width: 180, height: 18, radius: 4),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _WideActionButton extends StatelessWidget {
  const _WideActionButton({
    required this.label,
    required this.foregroundColor,
    this.onTap,
    this.icon,
    this.gradient,
    this.backgroundColor,
    this.trailing,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final Gradient? gradient;
  final Color? backgroundColor;
  final Color foregroundColor;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(4),
          onTap: onTap,
          child: Ink(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              gradient: gradient,
              color: gradient == null
                  ? backgroundColor ?? const Color(0xFFE6E8EA)
                  : null,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: foregroundColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      height: 24 / 16,
                    ),
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 8),
                  trailing!,
                ] else if (icon != null) ...[
                  const SizedBox(width: 8),
                  Icon(icon, size: 16, color: foregroundColor),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TopActionButton extends StatelessWidget {
  const _TopActionButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: onTap,
        child: Ink(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: _SteamSettingPageState._brandBlue,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                height: 24 / 16,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RefreshActionIcon extends StatefulWidget {
  const _RefreshActionIcon({required this.color, required this.active});

  final Color color;
  final bool active;

  @override
  State<_RefreshActionIcon> createState() => _RefreshActionIconState();
}

class _RefreshActionIconState extends State<_RefreshActionIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant _RefreshActionIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active) {
      _syncAnimation();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _syncAnimation() {
    if (widget.active) {
      _controller.repeat();
    } else {
      _controller
        ..stop()
        ..reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: Icon(Icons.refresh_rounded, size: 18, color: widget.color),
    );
  }
}

class _SteamProfileAvatar extends StatelessWidget {
  const _SteamProfileAvatar({required this.imageUrl, required this.label});

  final String imageUrl;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF00288E), Color(0xFF0058BE)],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: imageUrl.isEmpty
              ? _SteamAvatarFallback(label: label)
              : CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => _SteamAvatarFallback(label: label),
                  errorWidget: (_, __, ___) =>
                      _SteamAvatarFallback(label: label),
                ),
        ),
      ),
    );
  }
}

class _SteamAvatarFallback extends StatelessWidget {
  const _SteamAvatarFallback({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final initial = label.trim().isEmpty ? 'S' : label.trim()[0].toUpperCase();
    return Container(
      color: const Color(0xFFECEEF0),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: const TextStyle(
          color: _SteamSettingPageState._brandBlue,
          fontSize: 26,
          fontWeight: FontWeight.w800,
          height: 1,
        ),
      ),
    );
  }
}

class _SteamIdRow extends StatelessWidget {
  const _SteamIdRow({required this.steamId, required this.onCopy});

  final String steamId;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                steamId,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.visible,
                style: const TextStyle(
                  color: _SteamSettingPageState._mutedColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  height: 18 / 13,
                  letterSpacing: 0,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onCopy,
          child: const Padding(
            padding: EdgeInsets.all(2),
            child: Icon(
              Icons.copy_rounded,
              size: 16,
              color: _SteamSettingPageState._linkColor,
            ),
          ),
        ),
      ],
    );
  }
}

class _SteamVerificationEntryButton extends StatelessWidget {
  const _SteamVerificationEntryButton({
    required this.enabled,
    required this.onTap,
  });

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final child = Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: enabled
            ? const Color.fromRGBO(30, 64, 175, 0.10)
            : const Color(0xFFECEEF0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: enabled
              ? const Color.fromRGBO(30, 64, 175, 0.18)
              : const Color(0xFFD9DEE8),
        ),
      ),
      child: Icon(
        Icons.verified_user_rounded,
        size: 19,
        color: enabled
            ? _SteamSettingPageState._brandBlue
            : const Color(0xFF94A3B8),
      ),
    );

    if (!enabled) {
      return child;
    }

    return Tooltip(
      message: 'app.steam.verification'.tr,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: child,
        ),
      ),
    );
  }
}

class _SteamUnboundDialog extends StatelessWidget {
  const _SteamUnboundDialog({required this.message, required this.onConfirm});

  final String message;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return FigmaConfirmationDialog(
      icon: Icons.public_rounded,
      iconColor: const Color(0xFF1E40AF),
      iconBackgroundColor: const Color.fromRGBO(30, 64, 175, 0.10),
      title: 'app.system.tips.warm'.tr,
      message: message,
      primaryLabel: 'app.common.confirm'.tr,
      onPrimary: onConfirm,
    );
  }
}
