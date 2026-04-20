import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tronskins_app/api/model/help/help_models.dart';
import 'package:tronskins_app/common/widgets/back_to_top_overlay.dart';
import 'package:tronskins_app/common/widgets/settings_style_app_bar.dart';
import 'package:tronskins_app/controllers/help/help_controller.dart';
import 'package:tronskins_app/routes/app_routes.dart';

class HelpCenterPage extends StatefulWidget {
  const HelpCenterPage({super.key});

  @override
  State<HelpCenterPage> createState() => _HelpCenterPageState();
}

class _HelpCenterPageState extends State<HelpCenterPage> {
  final HelpController controller = Get.isRegistered<HelpController>()
      ? Get.find<HelpController>()
      : Get.put(HelpController());

  static const _pageBg = Color(0xFFF8FAFC);
  static const _surface = Colors.white;
  static const _sectionBg = Color(0xFFF1F5F9);
  static const _titleColor = Color(0xFF191C1E);
  static const _bodyColor = Color(0xFF444653);
  static const _mutedColor = Color(0xFF757684);
  static const _brandColor = Color(0xFF1E40AF);
  static const _brandLight = Color(0xFFA8B8FF);

  String? _selectedCategoryCode;

  @override
  void initState() {
    super.initState();
    controller.loadCenterOverview();
  }

  @override
  Widget build(BuildContext context) {
    return BackToTopScope(
      enabled: false,
      child: Scaffold(
        backgroundColor: _pageBg,
        body: Stack(
          children: [
            Positioned.fill(
              child: Obx(() {
                final categoryLoading = controller.categoryLoading.value;
                final overviewLoading = controller.overviewLoading.value;
                final categories = controller.categories.toList(
                  growable: false,
                );
                final hasOverviewData =
                    controller.categoryItemsByCode.isNotEmpty;
                final selectedCode =
                    categories.any(
                      (item) => item.categoryCode == _selectedCategoryCode,
                    )
                    ? _selectedCategoryCode
                    : null;
                final showInitialSkeleton =
                    (categoryLoading || overviewLoading) &&
                    (categories.isEmpty || !hasOverviewData);

                if (showInitialSkeleton) {
                  return _buildLoadingSkeleton();
                }

                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 96, 16, 40),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 672),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildCategoryChips(categories, selectedCode),
                          const SizedBox(height: 24),
                          _buildPopularQuestionsSection(selectedCode),
                          const SizedBox(height: 20),
                          _buildCategoryGrid(categories),
                          const SizedBox(height: 28),
                          _buildSupportCard(),
                          const SizedBox(height: 20),
                          _buildFooter(),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
            _buildTopNavigation(context),
          ],
        ),
      ),
    );
  }

  Widget _buildTopNavigation(BuildContext context) {
    return SettingsStyleTopNavigation(
      title: 'app.user.server.help'.tr,
      actions: [
        InkWell(
          customBorder: const CircleBorder(),
          onTap: () => Get.toNamed(Routers.FEEDBACK_LIST),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF2FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.support_agent_rounded,
              size: 20,
              color: _brandColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingSkeleton() {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 96, 16, 40),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 672),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildChipLoadingRow(),
              const SizedBox(height: 24),
              _buildPopularQuestionsLoadingSection(),
              const SizedBox(height: 20),
              _buildCategoryGridLoading(),
              const SizedBox(height: 28),
              _buildSupportCardLoading(),
              const SizedBox(height: 20),
              _buildFooterLoading(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChipLoadingRow() {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 5,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final widths = [72.0, 96.0, 84.0, 102.0, 88.0];
          return _buildLoadingBox(width: widths[index], height: 36, radius: 12);
        },
      ),
    );
  }

  Widget _buildPopularQuestionsLoadingSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _sectionBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildLoadingBox(width: 168, height: 22, radius: 999),
              const Spacer(),
              _buildLoadingCircle(size: 18),
            ],
          ),
          const SizedBox(height: 16),
          for (var index = 0; index < 4; index++) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildLoadingBox(
                      width: double.infinity,
                      height: 16,
                      radius: 999,
                    ),
                  ),
                  const SizedBox(width: 12),
                  _buildLoadingCircle(size: 18),
                ],
              ),
            ),
            if (index != 3) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  Widget _buildCategoryGridLoading() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = (constraints.maxWidth - 16) / 2;
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            for (var index = 0; index < 4; index++)
              SizedBox(width: itemWidth, child: _buildCategoryCardLoading()),
          ],
        );
      },
    );
  }

  Widget _buildCategoryCardLoading() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.05),
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLoadingBox(width: 40, height: 40, radius: 8),
          const SizedBox(height: 16),
          _buildLoadingBox(width: 110, height: 14, radius: 999),
          const SizedBox(height: 8),
          _buildLoadingBox(width: 76, height: 12, radius: 999),
        ],
      ),
    );
  }

  Widget _buildSupportCardLoading() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.05),
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildLoadingBox(width: 54, height: 54, radius: 16),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLoadingBox(width: 210, height: 18, radius: 999),
                    const SizedBox(height: 10),
                    _buildLoadingBox(width: 176, height: 14, radius: 999),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildLoadingBox(width: 176, height: 52, radius: 10),
        ],
      ),
    );
  }

  Widget _buildFooterLoading() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Column(
          children: [
            _buildLoadingBox(width: 168, height: 12, radius: 999),
            const SizedBox(height: 10),
            _buildLoadingBox(width: 132, height: 10, radius: 999),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingBox({
    required double width,
    required double height,
    double radius = 999,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFE6EDF4),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }

  Widget _buildLoadingCircle({required double size}) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Color(0xFFE6EDF4),
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildCategoryChips(
    List<HelpCategory> categories,
    String? selectedCode,
  ) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (index == 0) {
            return _buildChip(
              label: _allLabel(),
              selected: selectedCode == null,
              onTap: () => setState(() => _selectedCategoryCode = null),
            );
          }

          final category = categories[index - 1];
          final code = category.categoryCode ?? '';
          return _buildChip(
            label: category.label ?? code,
            selected: selectedCode == code,
            onTap: () => setState(() => _selectedCategoryCode = code),
          );
        },
      ),
    );
  }

  Widget _buildChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? _brandColor : const Color(0xFFE6E8EA),
            borderRadius: BorderRadius.circular(12),
            boxShadow: selected
                ? const [
                    BoxShadow(
                      color: Color.fromRGBO(0, 0, 0, 0.05),
                      blurRadius: 2,
                      offset: Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: selected ? _brandLight : _bodyColor,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              height: 20 / 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPopularQuestionsSection(String? selectedCode) {
    final items = controller.popularItems(categoryCode: selectedCode, limit: 5);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _sectionBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _popularQuestionsLabel(),
                  style: const TextStyle(
                    color: _titleColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    height: 28 / 18,
                  ),
                ),
              ),
              const Icon(
                Icons.north_east_rounded,
                size: 18,
                color: Color(0xFF0058BE),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (items.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'app.common.no_data'.tr,
                style: const TextStyle(
                  color: _mutedColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  height: 20 / 14,
                ),
              ),
            )
          else
            Column(
              children: [
                for (var index = 0; index < items.length; index++) ...[
                  _buildQuestionTile(items[index]),
                  if (index != items.length - 1) const SizedBox(height: 8),
                ],
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildQuestionTile(HelpItem item) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.zero,
        onTap: () => Get.toNamed(Routers.HELP_DETAIL, arguments: item),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.zero,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  item.title ?? '--',
                  style: const TextStyle(
                    color: _bodyColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    height: 24 / 16,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF6B7280),
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryGrid(List<HelpCategory> categories) {
    if (categories.isEmpty) {
      return const SizedBox.shrink();
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = (constraints.maxWidth - 16) / 2;
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            for (var index = 0; index < categories.length; index++)
              SizedBox(
                width: itemWidth,
                child: _buildCategoryCard(categories[index], index),
              ),
          ],
        );
      },
    );
  }

  Widget _buildCategoryCard(HelpCategory category, int index) {
    final visual = _resolveCategoryVisuals(category, index);
    final code = category.categoryCode ?? '';
    final articleCount = controller.articleCountForCategory(code);
    final articleText = controller.hasOverviewForCategory(code)
        ? _articlesLabel(articleCount)
        : '--';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.zero,
        onTap: () => Get.toNamed(Routers.HELP_CATEGORY, arguments: category),
        child: Ink(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.zero,
            border: Border.all(color: const Color(0xFFF1F5F9)),
            boxShadow: const [
              BoxShadow(
                color: Color.fromRGBO(0, 0, 0, 0.05),
                blurRadius: 2,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: visual.background,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(visual.icon, color: visual.accent, size: 20),
              ),
              const SizedBox(height: 16),
              Text(
                category.label ?? code,
                style: const TextStyle(
                  color: _titleColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  height: 17.5 / 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                articleText,
                style: TextStyle(
                  color: visual.accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  height: 16 / 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSupportCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.05),
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF00288E), Color(0xFF0058BE)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                      color: Color.fromRGBO(0, 0, 0, 0.12),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.support_agent_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: 28,
                      child: FittedBox(
                        alignment: Alignment.centerLeft,
                        fit: BoxFit.scaleDown,
                        child: Text(
                          _supportCardTitle(),
                          maxLines: 1,
                          softWrap: false,
                          style: const TextStyle(
                            color: _titleColor,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            height: 28 / 18,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 20,
                      child: FittedBox(
                        alignment: Alignment.centerLeft,
                        fit: BoxFit.scaleDown,
                        child: Text(
                          _supportCardSubtitle(),
                          maxLines: 1,
                          softWrap: false,
                          style: const TextStyle(
                            color: _mutedColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            height: 20 / 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF0058BE),
              minimumSize: const Size(176, 52),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              textStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                height: 20 / 14,
              ),
            ),
            onPressed: () => Get.toNamed(Routers.FEEDBACK_LIST),
            child: Text(
              _contactSupportLabel(),
              maxLines: 1,
              softWrap: false,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          Center(
            child: Text(
              _serviceHoursLabel(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _mutedColor,
                fontSize: 12,
                fontWeight: FontWeight.w400,
                letterSpacing: 1.2,
                height: 16 / 12,
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Center(
            child: Text(
              '© 2024 TronSkins Help Portal',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color.fromRGBO(117, 118, 132, 0.5),
                fontSize: 10,
                fontWeight: FontWeight.w400,
                height: 15 / 10,
              ),
            ),
          ),
        ],
      ),
    );
  }

  _CategoryVisuals _resolveCategoryVisuals(HelpCategory category, int index) {
    final label = (category.label ?? category.categoryCode ?? '').toLowerCase();

    if (_containsAny(label, const ['account', '账户', '账号', 'user'])) {
      return const _CategoryVisuals(
        icon: Icons.manage_accounts_outlined,
        background: Color(0xFFEFF6FF),
        accent: Color(0xFF0058BE),
      );
    }
    if (_containsAny(label, const ['trade', 'trading', '交易', '买卖'])) {
      return const _CategoryVisuals(
        icon: Icons.swap_horiz_rounded,
        background: Color(0xFFFAF5FF),
        accent: Color(0xFF9333EA),
      );
    }
    if (_containsAny(label, const [
      'wallet',
      'withdraw',
      'recharge',
      '支付',
      '钱包',
      '提现',
      '充值',
    ])) {
      return const _CategoryVisuals(
        icon: Icons.account_balance_wallet_outlined,
        background: Color(0xFFECFDF5),
        accent: Color(0xFF059669),
      );
    }
    if (_containsAny(label, const ['security', 'guard', 'safe', '安全'])) {
      return const _CategoryVisuals(
        icon: Icons.shield_outlined,
        background: Color(0xFFFFF1F2),
        accent: Color(0xFFE11D48),
      );
    }
    if (_containsAny(label, const ['steam', 'game', 'link', '绑定'])) {
      return const _CategoryVisuals(
        icon: Icons.link_rounded,
        background: Color(0xFFFFF7ED),
        accent: Color(0xFFEA580C),
      );
    }

    const fallback = [
      _CategoryVisuals(
        icon: Icons.help_outline_rounded,
        background: Color(0xFFEFF6FF),
        accent: Color(0xFF0058BE),
      ),
      _CategoryVisuals(
        icon: Icons.info_outline_rounded,
        background: Color(0xFFFAF5FF),
        accent: Color(0xFF9333EA),
      ),
      _CategoryVisuals(
        icon: Icons.support_agent_outlined,
        background: Color(0xFFECFDF5),
        accent: Color(0xFF059669),
      ),
      _CategoryVisuals(
        icon: Icons.verified_user_outlined,
        background: Color(0xFFFFF1F2),
        accent: Color(0xFFE11D48),
      ),
    ];

    return fallback[index % fallback.length];
  }

  bool _containsAny(String source, List<String> candidates) {
    for (final item in candidates) {
      if (source.contains(item)) {
        return true;
      }
    }
    return false;
  }

  bool get _isChineseLocale =>
      (Get.locale?.languageCode.toLowerCase() ?? '').startsWith('zh');

  String _allLabel() => _isChineseLocale ? '全部' : 'All';

  String _popularQuestionsLabel() =>
      _isChineseLocale ? '热门问题' : 'Popular Questions';

  String _articlesLabel(int count) {
    if (_isChineseLocale) {
      return '$count 篇文章';
    }
    return '$count ${count == 1 ? 'Article' : 'Articles'}';
  }

  String _supportCardTitle() =>
      _isChineseLocale ? '没有找到答案？' : 'Didn\'t find an answer?';

  String _supportCardSubtitle() => _isChineseLocale
      ? '我们的团队将为你提供 1 对 1 帮助'
      : 'Our team is ready to help 1-on-1';

  String _contactSupportLabel() =>
      _isChineseLocale ? '联系客服' : 'Contact Support';

  String _serviceHoursLabel() => _isChineseLocale
      ? '服务时间: 周一至周日 9:00-21:00'
      : 'SERVICE HOURS: MON-SUN 9:00-21:00';
}

class _CategoryVisuals {
  const _CategoryVisuals({
    required this.icon,
    required this.background,
    required this.accent,
  });

  final IconData icon;
  final Color background;
  final Color accent;
}
