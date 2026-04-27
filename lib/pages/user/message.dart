import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tronskins_app/common/utils/app_snackbar.dart';
import 'package:tronskins_app/common/widgets/figma_confirmation_dialog.dart';
import 'package:tronskins_app/common/widgets/settings_style_app_bar.dart';
import 'package:tronskins_app/components/notify/notify_bulletin_list.dart';
import 'package:tronskins_app/components/notify/notify_trade_list.dart';
import 'package:tronskins_app/controllers/user/notify_controller.dart';

class UserMessage extends StatefulWidget {
  const UserMessage({super.key});

  @override
  State<UserMessage> createState() => _UserMessageState();
}

class _UserMessageState extends State<UserMessage>
    with SingleTickerProviderStateMixin {
  static const Color _pageBg = Color(0xFFF7F9FB);
  static const Color _brandColor = Color(0xFF1E40AF);
  static const Color _brandAccent = Color(0xFF00288E);
  static const Color _textSecondary = Color(0xFF444653);
  static const Color _tabDivider = Color.fromRGBO(196, 197, 213, 0.10);

  final NotifyController _controller = Get.isRegistered<NotifyController>()
      ? Get.find<NotifyController>()
      : Get.put(NotifyController());

  late final TabController _tabController;
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabChange);
    _controller.ensureBadgeLoaded();
    _controller.loadTradeList(refresh: true);
    _controller.loadNoticeList(refresh: true);
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    final nextIndex = _tabController.index;
    if (!mounted || _selectedTab == nextIndex) {
      return;
    }
    setState(() => _selectedTab = nextIndex);
  }

  Future<void> _showActionConfirm({
    required String message,
    required IconData icon,
    required Color accentColor,
    required Future<void> Function(BuildContext dialogContext) onConfirm,
  }) async {
    await showFigmaModal<void>(
      context: context,
      barrierDismissible: false,
      child: FigmaAsyncConfirmationDialog(
        title: 'app.system.tips.title'.tr,
        message: message,
        primaryLabel: 'app.common.confirm'.tr,
        secondaryLabel: 'app.common.cancel'.tr,
        onSecondary: () => popModalRoute(context),
        onConfirm: onConfirm,
        icon: icon,
        accentColor: accentColor,
        iconColor: accentColor,
        iconBackgroundColor: accentColor.withValues(alpha: 0.10),
      ),
    );
  }

  Future<void> _readAll() async {
    await _showActionConfirm(
      message: '${'app.system.notice.readall'.tr}?',
      icon: Icons.mark_email_read_rounded,
      accentColor: _brandColor,
      onConfirm: (dialogContext) async {
        final ok = _selectedTab == 0
            ? await _controller.readAllTrade()
            : await _controller.readAllNotice();
        if (ok) {
          AppSnackbar.success('app.system.notice.readall'.tr);
        }
        if (dialogContext.mounted) {
          popModalRoute(dialogContext);
        }
      },
    );
  }

  Future<void> _clearTrade() async {
    if (_selectedTab != 0) {
      return;
    }

    await _showActionConfirm(
      message: 'app.system.notice.clear_tips'.tr,
      icon: Icons.delete_outline_rounded,
      accentColor: const Color(0xFFDC2626),
      onConfirm: (dialogContext) async {
        final message = await _controller.clearTrade();
        if (message != null) {
          AppSnackbar.success(
            message.isNotEmpty ? message : 'app.system.message.success'.tr,
          );
        }
        if (dialogContext.mounted) {
          popModalRoute(dialogContext);
        }
      },
    );
  }

  Widget _buildTopNavigation() {
    return SettingsStyleTopNavigation(
      title: 'app.system.notice.title'.tr,
      actions: [
        _TopActionButton(
          icon: Icons.mark_email_read_rounded,
          onTap: _readAll,
          tooltip: 'app.system.notice.readall'.tr,
        ),
        if (_selectedTab == 0) ...[
          const SizedBox(width: 8),
          _TopActionButton(
            icon: Icons.delete_outline_rounded,
            onTap: _clearTrade,
            tooltip: 'app.system.notice.clear_tips'.tr,
          ),
        ],
      ],
    );
  }

  Widget _buildPageHeader() {
    final topOffset = MediaQuery.paddingOf(context).top + 64;
    return Padding(
      padding: EdgeInsets.only(top: topOffset),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: _pageBg,
          border: Border(bottom: BorderSide(color: _tabDivider)),
        ),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 672),
            child: Align(
              alignment: Alignment.centerLeft,
              child: _buildMessageTabBar(context),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessageTabBar(BuildContext context) {
    final theme = Theme.of(context);

    return TabBar(
      controller: _tabController,
      isScrollable: true,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      tabAlignment: TabAlignment.start,
      indicatorSize: TabBarIndicatorSize.label,
      indicatorColor: _brandAccent,
      indicatorWeight: 2,
      dividerColor: Colors.transparent,
      labelPadding: const EdgeInsets.only(right: 32),
      splashFactory: NoSplash.splashFactory,
      labelColor: _brandAccent,
      unselectedLabelColor: _textSecondary,
      labelStyle: theme.textTheme.titleSmall?.copyWith(
        fontSize: 14,
        height: 20 / 14,
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelStyle: theme.textTheme.titleSmall?.copyWith(
        fontSize: 14,
        height: 20 / 14,
        fontWeight: FontWeight.w500,
      ),
      tabs: [
        Tab(height: 52, text: 'app.system.notice.trade_tab'.tr),
        Tab(height: 52, text: 'app.system.notice.announcement'.tr),
      ],
    );
  }

  Widget _buildAtmosphericBackground() {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -108,
            right: -76,
            child: Container(
              width: 236,
              height: 236,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Color.fromRGBO(30, 64, 175, 0.12),
                    Color.fromRGBO(30, 64, 175, 0.00),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 190,
            left: -68,
            child: Container(
              width: 180,
              height: 180,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Color.fromRGBO(255, 255, 255, 0.92),
                    Color.fromRGBO(255, 255, 255, 0.00),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageBg,
      body: Stack(
        children: [
          const Positioned.fill(child: ColoredBox(color: _pageBg)),
          Positioned.fill(child: _buildAtmosphericBackground()),
          Positioned.fill(
            child: Column(
              children: [
                _buildPageHeader(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      NotifyTradeList(controller: _controller),
                      NotifyBulletinList(controller: _controller),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _buildTopNavigation(),
        ],
      ),
    );
  }
}

class _TopActionButton extends StatelessWidget {
  const _TopActionButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkResponse(
          onTap: onTap,
          radius: 18,
          highlightShape: BoxShape.circle,
          splashColor: _UserMessageState._brandColor.withValues(alpha: 0.10),
          highlightColor: Colors.transparent,
          child: SizedBox(
            width: 32,
            height: 32,
            child: Icon(icon, size: 20, color: Color(0xFF64748B)),
          ),
        ),
      ),
    );
  }
}
