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
  static const _pageBg = Color(0xFFF7F9FB);
  static const _brandColor = Color(0xFF1E40AF);

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

  Future<bool> _showActionConfirm({
    required String message,
    required IconData icon,
    required Color accentColor,
  }) async {
    final confirmed = await showFigmaModal<bool>(
      context: context,
      child: FigmaConfirmationDialog(
        title: 'app.system.tips.title'.tr,
        message: message,
        primaryLabel: 'app.common.confirm'.tr,
        onPrimary: () => Navigator.of(context).pop(true),
        secondaryLabel: 'app.common.cancel'.tr,
        onSecondary: () => Navigator.of(context).pop(false),
        icon: icon,
        accentColor: accentColor,
        iconColor: accentColor,
        iconBackgroundColor: accentColor.withValues(alpha: 0.10),
      ),
    );
    return confirmed == true;
  }

  Future<void> _readAll() async {
    final confirm = await _showActionConfirm(
      message: '${'app.system.notice.readall'.tr}?',
      icon: Icons.mark_email_read_rounded,
      accentColor: _brandColor,
    );
    if (!confirm) {
      return;
    }

    final ok = _selectedTab == 0
        ? await _controller.readAllTrade()
        : await _controller.readAllNotice();
    if (ok) {
      AppSnackbar.success('app.system.notice.readall'.tr);
    }
  }

  Future<void> _clearTrade() async {
    if (_selectedTab != 0) {
      return;
    }

    final confirm = await _showActionConfirm(
      message: 'app.system.notice.clear_tips'.tr,
      icon: Icons.delete_outline_rounded,
      accentColor: const Color(0xFFDC2626),
    );
    if (!confirm) {
      return;
    }

    final message = await _controller.clearTrade();
    if (message != null) {
      AppSnackbar.success(
        message.isNotEmpty ? message : 'app.system.message.success'.tr,
      );
    }
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
          const SizedBox(width: 10),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 96, 0, 10),
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
      indicatorColor: const Color(0xFF00288E),
      indicatorWeight: 2,
      dividerColor: Colors.transparent,
      labelPadding: const EdgeInsets.only(right: 28, bottom: 2),
      splashFactory: NoSplash.splashFactory,
      labelColor: const Color(0xFF00288E),
      unselectedLabelColor: const Color(0xFF444653),
      labelStyle: theme.textTheme.titleSmall?.copyWith(
        fontSize: 16,
        height: 24 / 16,
        fontWeight: FontWeight.w700,
      ),
      unselectedLabelStyle: theme.textTheme.titleSmall?.copyWith(
        fontSize: 16,
        height: 24 / 16,
        fontWeight: FontWeight.w500,
      ),
      tabs: [
        Tab(height: 30, text: 'app.system.notice.trade_tab'.tr),
        Tab(height: 30, text: 'app.system.notice.announcement'.tr),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageBg,
      body: Stack(
        children: [
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
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Ink(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: const Color.fromRGBO(30, 64, 175, 0.08),
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color.fromRGBO(15, 23, 42, 0.05),
                  blurRadius: 12,
                  spreadRadius: -8,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Icon(icon, size: 18, color: _UserMessageState._brandColor),
          ),
        ),
      ),
    );
  }
}
