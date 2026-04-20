import 'dart:io';
import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:get/get.dart';
import 'package:tronskins_app/common/http/http_helper.dart';
import 'package:tronskins_app/common/storage/game_storage.dart';
import 'package:tronskins_app/common/storage/server_storage.dart';
import 'package:tronskins_app/common/utils/app_snackbar.dart';
import 'package:tronskins_app/common/widgets/settings_style_app_bar.dart';
import 'package:tronskins_app/routes/app_routes.dart';

class ServerListPage extends StatefulWidget {
  const ServerListPage({super.key});

  @override
  State<ServerListPage> createState() => _ServerListPageState();
}

class _ServerListPageState extends State<ServerListPage> {
  static const int _connectivityMaxAttempts = 3;
  static const List<Duration> _connectivityRetryDelays = <Duration>[
    Duration(milliseconds: 600),
    Duration(milliseconds: 1400),
  ];

  List<ServerStorageItem> servers = <ServerStorageItem>[];
  String current = '';
  BuildContext? _connectivityDialogContext;
  bool _connectivityDialogVisible = false;

  static const Color _pageBg = Color(0xFFF8F8FC);
  static const Color _lineColor = Color(0xFFF1F5F9);
  static const Color _brandBlue = Color(0xFF3B82F6);
  static const Color _titleColor = Color(0xFF191C1E);
  static const Color _subtitleColor = Color(0xFF94A3B8);

  @override
  void initState() {
    super.initState();
    servers = ServerStorage.getServerItems();
    current = ServerStorage.getServer();
  }

  Future<void> _addServer() async {
    final result = await _showServerDialog();

    if (!mounted || result == null) {
      return;
    }

    if (servers.any((server) => server.url == result.url)) {
      AppSnackbar.error('app.user.setting.server_exists'.tr);
      return;
    }

    setState(() {
      servers.add(result);
    });
    ServerStorage.setServerItems(servers);
    AppSnackbar.success('app.user.setting.server_add_success'.tr);
  }

  Future<void> _editServer(ServerStorageItem server) async {
    final result = await _showServerDialog(initialServer: server);

    if (!mounted || result == null) {
      return;
    }

    final hasDuplicate = servers.any(
      (item) => item.url == result.url && item.url != server.url,
    );
    if (hasDuplicate) {
      AppSnackbar.error('app.user.setting.server_exists'.tr);
      return;
    }

    final index = servers.indexWhere((item) => item.url == server.url);
    if (index == -1) {
      return;
    }

    final wasCurrent = current == server.url;

    setState(() {
      servers[index] = result;
      if (wasCurrent) {
        current = result.url;
      }
    });

    ServerStorage.setServerItems(servers);
    if (wasCurrent) {
      HttpHelper.setBaseUrl(result.url);
      ServerStorage.setServer(result.url);
    }
  }

  Future<ServerStorageItem?> _showServerDialog({
    ServerStorageItem? initialServer,
  }) {
    return showGeneralDialog<ServerStorageItem>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black.withValues(alpha: 0.22),
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (dialogContext, _, __) {
        return _AddServerDialog(
          isValidServer: _isValidServer,
          normalizeServer: _normalize,
          initialServer: initialServer,
          onDocumentationTap: () {
            Navigator.of(dialogContext).pop();
            Future.microtask(() => Get.toNamed(Routers.HELP_CENTER));
          },
        );
      },
      transitionBuilder: (context, animation, _, child) {
        final curve = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curve,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.04),
              end: Offset.zero,
            ).animate(curve),
            child: child,
          ),
        );
      },
    );
  }

  Future<void> _deleteServer(ServerStorageItem server) async {
    final confirm = await _showServerConfirmDialog(
      message: 'app.user.server.message.confirm_delete'.tr,
      detail: server.url,
    );

    if (confirm == true) {
      setState(() {
        servers.remove(server);
      });
      ServerStorage.setServerItems(servers);
    }
  }

  Future<void> _switchServer(ServerStorageItem server) async {
    final confirm = await _showSwitchDialog(server);
    if (confirm != true) {
      return;
    }

    final progress = ValueNotifier<_ConnectivityCheckProgress>(
      const _ConnectivityCheckProgress(
        attempt: 1,
        maxAttempts: _connectivityMaxAttempts,
      ),
    );
    await _showConnectivityLoading(server, progress);
    final reachable = await _checkServerConnectivity(
      server.url,
      progress: progress,
    );
    progress.dispose();
    await _closeConnectivityLoading();
    if (!mounted) {
      return;
    }
    if (!reachable) {
      AppSnackbar.error('app.user.setting.server_connectivity_failed'.tr);
      return;
    }

    setState(() => current = server.url);
    HttpHelper.setBaseUrl(server.url);
    ServerStorage.setServer(server.url);
    AppSnackbar.success('app.user.setting.server_connectivity_success'.tr);
    Navigator.of(context).maybePop(true);
  }

  Future<void> _showConnectivityLoading(
    ServerStorageItem server,
    ValueNotifier<_ConnectivityCheckProgress> progress,
  ) async {
    _connectivityDialogVisible = true;
    _connectivityDialogContext = null;
    Get.dialog(
      PopScope(
        canPop: false,
        child: Builder(
          builder: (dialogContext) {
            _connectivityDialogContext = dialogContext;
            return _ConnectivityCheckingDialog(
              server: server,
              progress: progress,
            );
          },
        ),
      ),
      barrierDismissible: false,
    ).whenComplete(() {
      _connectivityDialogVisible = false;
      _connectivityDialogContext = null;
    });
    await WidgetsBinding.instance.endOfFrame;
  }

  Future<void> _closeConnectivityLoading() async {
    final dialogContext = _connectivityDialogContext;
    if (!_connectivityDialogVisible || dialogContext == null) {
      return;
    }
    Navigator.of(dialogContext).pop();
    await Future<void>.delayed(Duration.zero);
  }

  Future<bool> _checkServerConnectivity(
    String server, {
    ValueNotifier<_ConnectivityCheckProgress>? progress,
  }) async {
    for (var attempt = 1; attempt <= _connectivityMaxAttempts; attempt++) {
      progress?.value = _ConnectivityCheckProgress(
        attempt: attempt,
        maxAttempts: _connectivityMaxAttempts,
        isRetrying: attempt > 1,
      );
      final reachable = await _probeServerConnectivity(server);
      if (reachable) {
        return true;
      }
      if (attempt < _connectivityMaxAttempts) {
        await Future<void>.delayed(_connectivityRetryDelays[attempt - 1]);
      }
    }
    return false;
  }

  Future<bool> _probeServerConnectivity(String server) async {
    final dio = Dio(
      BaseOptions(
        baseUrl: server,
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 8),
        responseType: ResponseType.json,
        validateStatus: (_) => true,
      ),
    );
    (dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
      final client = HttpClient();
      if (!kReleaseMode) {
        client.badCertificateCallback =
            (X509Certificate cert, String host, int port) => true;
      }
      return client;
    };
    try {
      final appId = GameStorage.getGameType();
      final response = await dio.post(
        'api/public/mall/sell/$appId/news',
        data: {'appId': appId, 'page': 1, 'pageSize': 1},
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    } finally {
      dio.close(force: true);
    }
  }

  bool _isValidServer(String value) {
    final uri = Uri.tryParse(value);
    return uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        (uri.host.isNotEmpty);
  }

  String _normalize(String value) => value.endsWith('/') ? value : '$value/';

  Future<bool?> _showSwitchDialog(ServerStorageItem server) {
    return _showServerConfirmDialog(
      message: 'app.user.setting.server_relogin_hint'.tr,
      detail: server.url,
    );
  }

  Future<bool?> _showServerConfirmDialog({
    required String message,
    String? detail,
  }) {
    return showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, _, __) {
        return Material(
          color: Colors.transparent,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
            child: Center(
              child: Container(
                width: 300,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: const [
                    BoxShadow(
                      color: Color.fromRGBO(0, 0, 0, 0.25),
                      blurRadius: 50,
                      offset: Offset(0, 25),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      size: 40,
                      color: _brandBlue,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'app.system.tips.title'.tr,
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        height: 1.6,
                      ),
                    ),
                    if (detail != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        detail,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: _brandBlue,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: _brandBlue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () => Navigator.pop(context, true),
                        child: Text(
                          'app.common.confirm'.tr,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF1C1C1E),
                          side: const BorderSide(color: Color(0xFFE5E5EA)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () => Navigator.pop(context, false),
                        child: Text(
                          'app.common.cancel'.tr,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, _, child) {
        final curve = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curve,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.95, end: 1).animate(curve),
            child: child,
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    return SettingsStyleTopNavigation(
      title: 'app.user.setting.server'.tr,
      actions: [
        InkWell(
          onTap: _addServer,
          borderRadius: BorderRadius.circular(12),
          child: const Padding(
            padding: EdgeInsets.all(6),
            child: Icon(
              Icons.add_circle_outline_rounded,
              size: 20,
              color: _brandBlue,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildServerTile({
    required ServerStorageItem server,
    required bool isCurrent,
    required bool showDivider,
  }) {
    final tile = Material(
      color: Colors.white,
      child: InkWell(
        onTap: isCurrent ? null : () => _switchServer(server),
        child: Container(
          constraints: const BoxConstraints(minHeight: 72),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            border: showDivider
                ? const Border(bottom: BorderSide(color: _lineColor, width: 1))
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isCurrent
                      ? const Color(0xFFEFF6FF)
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isCurrent ? Icons.storage_rounded : Icons.cloud_outlined,
                  size: 20,
                  color: isCurrent ? _brandBlue : const Color(0xFF94A3B8),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            server.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _titleColor,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              height: 24 / 16,
                            ),
                          ),
                        ),
                        if (isCurrent) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'app.user.setting.server_in_use'.tr.toUpperCase(),
                              style: const TextStyle(
                                color: _brandBlue,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                height: 15 / 10,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      server.url,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _subtitleColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        height: 21 / 14,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isCurrent) ...[
                const SizedBox(width: 8),
                Tooltip(
                  message: 'app.user.setting.server_edit'.tr,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _editServer(server),
                      borderRadius: BorderRadius.circular(10),
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(
                          Icons.edit_outlined,
                          size: 18,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: isCurrent ? _brandBlue : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isCurrent ? _brandBlue : const Color(0xFFD1D5DB),
                    width: 2,
                  ),
                ),
                child: isCurrent
                    ? const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 14,
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );

    return Slidable(
      key: ValueKey(server.url),
      enabled: !isCurrent,
      endActionPane: !isCurrent
          ? ActionPane(
              motion: const StretchMotion(),
              extentRatio: 0.32,
              children: [
                SlidableAction(
                  onPressed: (_) => _deleteServer(server),
                  backgroundColor: const Color(0xFFDC2626),
                  foregroundColor: Colors.white,
                  icon: Icons.delete_outline_rounded,
                  label: 'app.common.delete'.tr,
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(16),
                    right: Radius.circular(16),
                  ),
                ),
              ],
            )
          : null,
      child: tile,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageBg,
      body: Stack(
        children: [
          Positioned.fill(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 96, 16, 160),
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 672),
                  child: Column(
                    children: [
                      if (servers.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: const [
                              BoxShadow(
                                color: Color.fromRGBO(0, 0, 0, 0.03),
                                blurRadius: 20,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Text(
                            'app.common.no_data'.tr,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: _subtitleColor,
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        )
                      else
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: const [
                              BoxShadow(
                                color: Color.fromRGBO(0, 0, 0, 0.03),
                                blurRadius: 20,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: SlidableAutoCloseBehavior(
                            child: Column(
                              children: [
                                for (var i = 0; i < servers.length; i++)
                                  _buildServerTile(
                                    server: servers[i],
                                    isCurrent: servers[i].url == current,
                                    showDivider: i != servers.length - 1,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 56),
                      SizedBox(
                        width: 320,
                        child: Text(
                          'app.user.setting.server_relogin_hint'.tr,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFF8E8E93),
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            height: 18 / 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          _buildHeader(context),
        ],
      ),
    );
  }
}

class _AddServerDialog extends StatefulWidget {
  const _AddServerDialog({
    required this.isValidServer,
    required this.normalizeServer,
    this.initialServer,
    required this.onDocumentationTap,
  });

  final bool Function(String value) isValidServer;
  final String Function(String value) normalizeServer;
  final ServerStorageItem? initialServer;
  final VoidCallback onDocumentationTap;

  @override
  State<_AddServerDialog> createState() => _AddServerDialogState();
}

class _AddServerDialogState extends State<_AddServerDialog> {
  static const Color _surfaceBg = Color(0xFFF7F9FB);
  static const Color _inputBg = Color(0xFFE0E3E5);
  static const Color _inputHint = Color(0x80757684);
  static const Color _labelColor = Color(0xFF757684);
  static const Color _textPrimary = Color(0xFF191C1E);
  static const Color _textSecondary = Color(0xFF444653);
  static const Color _brandBlue = Color(0xFF1E40AF);
  static const Color _brandBlueEnd = Color(0xFF2170E4);

  late final TextEditingController _nameController;
  late final TextEditingController _urlController;
  String? _nameErrorText;
  String? _urlErrorText;

  bool get _canSubmit =>
      _nameController.text.trim().isNotEmpty &&
      _urlController.text.trim().isNotEmpty;

  bool get _isEditing => widget.initialServer != null;

  String get _serverNameLabel => 'app.user.setting.server_name_label'.tr;

  String get _serverAddressLabel => 'app.user.setting.server_url_label'.tr;

  String get _dialogTitle => _isEditing
      ? 'app.user.setting.server_edit'.tr
      : 'app.user.setting.server_add'.tr;

  String get _submitLabel =>
      _isEditing ? 'app.common.save'.tr : 'app.user.setting.server_add'.tr;

  String get _securityTitle => 'app.user.setting.server_security_title'.tr;

  String get _securityDescription => 'app.user.setting.server_security_desc'.tr;

  String get _httpsTip => 'app.user.setting.server_https_tip'.tr;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.initialServer?.name ?? '',
    );
    _urlController = TextEditingController(
      text: widget.initialServer?.url ?? '',
    );
    _nameController.addListener(_handleTextChanged);
    _urlController.addListener(_handleTextChanged);
  }

  @override
  void dispose() {
    _nameController
      ..removeListener(_handleTextChanged)
      ..dispose();
    _urlController
      ..removeListener(_handleTextChanged)
      ..dispose();
    super.dispose();
  }

  void _handleTextChanged() {
    if ((_nameErrorText != null || _urlErrorText != null) && mounted) {
      setState(() {
        _nameErrorText = null;
        _urlErrorText = null;
      });
    } else if (mounted) {
      setState(() {});
    }
  }

  void _submit() {
    final name = _nameController.text.trim();
    final address = _urlController.text.trim();

    String? nameErrorText;
    String? urlErrorText;

    if (name.isEmpty) {
      nameErrorText = 'app.user.setting.server_name_required'.tr;
    }
    if (address.isEmpty) {
      urlErrorText = 'app.user.setting.server_url_required'.tr;
    } else if (!widget.isValidServer(address)) {
      urlErrorText = 'app.user.server.message.address_invalid'.tr;
    }

    if (nameErrorText != null || urlErrorText != null) {
      setState(() {
        _nameErrorText = nameErrorText;
        _urlErrorText = urlErrorText;
      });
      return;
    }

    final normalized = widget.normalizeServer(address);
    Navigator.of(context).pop(ServerStorageItem(name: name, url: normalized));
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.22),
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 390,
                  maxHeight: constraints.maxHeight,
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: constraints.maxHeight,
                  child: ColoredBox(
                    color: _surfaceBg,
                    child: Stack(
                      children: [
                        Positioned(
                          right: -48,
                          top: -24,
                          child: _DialogBlurBlob(
                            size: 136,
                            color: const Color(0x143B82F6),
                          ),
                        ),
                        Positioned(
                          left: -64,
                          bottom: -72,
                          child: _DialogBlurBlob(
                            size: 164,
                            color: const Color(0x141E40AF),
                          ),
                        ),
                        Positioned.fill(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(24, 96, 24, 72),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildInputSection(),
                                const SizedBox(height: 32),
                                _buildSecurityCard(),
                                const SizedBox(height: 32),
                                _buildPrimaryButton(),
                                const SizedBox(height: 48),
                                Center(
                                  child: TextButton(
                                    onPressed: widget.onDocumentationTap,
                                    style: TextButton.styleFrom(
                                      foregroundColor: const Color(0xFF00288E),
                                      textStyle: const TextStyle(
                                        fontSize: 14,
                                        height: 20 / 14,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    child: Text('app.user.server.help'.tr),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SettingsStyleInlineTopBar(
                          title: _dialogTitle,
                          onBack: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildInputSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabeledTextField(
          controller: _nameController,
          label: _serverNameLabel,
          hintText: 'app.user.setting.server_name_placeholder'.tr,
          errorText: _nameErrorText,
          autofocus: true,
          textInputAction: TextInputAction.next,
          onSubmitted: (_) => FocusScope.of(context).nextFocus(),
        ),
        const SizedBox(height: 24),
        _buildLabeledTextField(
          controller: _urlController,
          label: _serverAddressLabel,
          hintText: 'https://example.com',
          errorText: _urlErrorText,
          helperText: _httpsTip,
          keyboardType: TextInputType.url,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
        ),
      ],
    );
  }

  Widget _buildLabeledTextField({
    required TextEditingController controller,
    required String label,
    required String hintText,
    String? errorText,
    String? helperText,
    bool autofocus = false,
    TextInputType? keyboardType,
    TextInputAction textInputAction = TextInputAction.done,
    ValueChanged<String>? onSubmitted,
  }) {
    final supportingText = errorText ?? helperText;
    final supportingColor = errorText == null
        ? const Color(0xFF757684)
        : const Color(0xFFBA1A1A);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            label,
            style: const TextStyle(
              color: _labelColor,
              fontSize: 14,
              height: 20 / 14,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.7,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: _inputBg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: errorText == null
                  ? Colors.transparent
                  : const Color(0xFFBA1A1A),
            ),
          ),
          child: Center(
            child: TextField(
              controller: controller,
              autofocus: autofocus,
              keyboardType: keyboardType,
              textInputAction: textInputAction,
              onSubmitted: onSubmitted,
              style: const TextStyle(
                color: _textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: hintText,
                hintStyle: const TextStyle(
                  color: _inputHint,
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ),
        ),
        if (supportingText != null) ...[
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  errorText == null
                      ? Icons.info_outline_rounded
                      : Icons.error_outline_rounded,
                  size: 14,
                  color: supportingColor,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    supportingText,
                    style: TextStyle(
                      color: supportingColor,
                      fontSize: 10,
                      height: 15 / 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSecurityCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFECEEF0),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Icon(
              Icons.shield_outlined,
              size: 20,
              color: Color(0xFF005DE5),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _securityTitle,
                  style: const TextStyle(
                    color: _textPrimary,
                    fontSize: 14,
                    height: 20 / 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _securityDescription,
                  style: const TextStyle(
                    color: _textSecondary,
                    fontSize: 12,
                    height: 16.5 / 12,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryButton() {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: _canSubmit ? 1 : 0.68,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [_brandBlue, _brandBlueEnd]),
          borderRadius: BorderRadius.circular(8),
          boxShadow: const [
            BoxShadow(
              color: Color.fromRGBO(30, 64, 175, 0.20),
              blurRadius: 15,
              offset: Offset(0, 10),
            ),
            BoxShadow(
              color: Color.fromRGBO(30, 64, 175, 0.20),
              blurRadius: 6,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: _canSubmit ? _submit : null,
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _submitLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      height: 24 / 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Icon(
                      _isEditing ? Icons.check_rounded : Icons.add_rounded,
                      size: 12,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ConnectivityCheckProgress {
  const _ConnectivityCheckProgress({
    required this.attempt,
    required this.maxAttempts,
    this.isRetrying = false,
  });

  final int attempt;
  final int maxAttempts;
  final bool isRetrying;
}

class _ConnectivityCheckingDialog extends StatelessWidget {
  const _ConnectivityCheckingDialog({
    required this.server,
    required this.progress,
  });

  final ServerStorageItem server;
  final ValueListenable<_ConnectivityCheckProgress> progress;

  String _statusTitle(_ConnectivityCheckProgress value) {
    if (value.isRetrying) {
      return 'app.user.setting.server_connectivity_retrying'.tr;
    }
    return 'app.user.setting.server_connectivity_testing'.tr;
  }

  String _attemptLabel(_ConnectivityCheckProgress value) {
    return 'app.user.setting.server_connectivity_attempt'.trParams({
      'attempt': value.attempt.toString(),
      'maxAttempts': value.maxAttempts.toString(),
    });
  }

  String _hintText(_ConnectivityCheckProgress value) {
    if (value.isRetrying) {
      return 'app.user.setting.server_connectivity_retry_hint'.tr;
    }
    return 'app.user.setting.server_connectivity_first_hint'.tr;
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Center(
          child: Container(
            width: 320,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFDDE7FF)),
              boxShadow: const [
                BoxShadow(
                  color: Color.fromRGBO(15, 23, 42, 0.08),
                  blurRadius: 24,
                  offset: Offset(0, 14),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F6FB),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Color(0xFF1E40AF),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ValueListenableBuilder<_ConnectivityCheckProgress>(
                  valueListenable: progress,
                  builder: (_, value, __) {
                    return Text(
                      _statusTitle(value),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 18,
                        height: 24 / 18,
                        fontWeight: FontWeight.w700,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 10),
                Text(
                  server.name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF191C1E),
                    fontSize: 14,
                    height: 20 / 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  server.url,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12,
                    height: 18 / 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: const LinearProgressIndicator(
                    minHeight: 6,
                    color: Color(0xFF2170E4),
                    backgroundColor: Color(0xFFE5EEFf),
                  ),
                ),
                const SizedBox(height: 14),
                ValueListenableBuilder<_ConnectivityCheckProgress>(
                  valueListenable: progress,
                  builder: (_, value, __) {
                    return Column(
                      children: [
                        Text(
                          _attemptLabel(value),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFF1E40AF),
                            fontSize: 12,
                            height: 18 / 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _hintText(value),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFF757684),
                            fontSize: 12,
                            height: 18 / 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DialogBlurBlob extends StatelessWidget {
  const _DialogBlurBlob({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}
