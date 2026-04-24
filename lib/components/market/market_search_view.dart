import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tronskins_app/api/market.dart';
import 'package:tronskins_app/api/model/market/market_filter_models.dart';
import 'package:tronskins_app/common/storage/market_search_history_storage.dart';

enum MarketSearchViewMode { sheet, page }

class MarketSearchView extends StatefulWidget {
  const MarketSearchView({
    super.key,
    required this.appId,
    required this.onCancel,
    required this.onSubmit,
    this.initialKeyword = '',
    this.mode = MarketSearchViewMode.sheet,
    this.submitEmptyOnCancel = false,
  });

  final int appId;
  final String initialKeyword;
  final VoidCallback onCancel;
  final ValueChanged<String> onSubmit;
  final MarketSearchViewMode mode;
  final bool submitEmptyOnCancel;

  @override
  State<MarketSearchView> createState() => _MarketSearchViewState();
}

class _MarketSearchViewState extends State<MarketSearchView> {
  final ApiMarketServer _api = ApiMarketServer();
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  Timer? _debounce;
  int _requestId = 0;
  String _lastKeyword = '';

  List<MarketNameSuggestion> _suggestions = [];
  List<String> _history = [];
  bool _isLoading = false;
  bool _hasQueried = false;

  bool get _showHistory => _controller.text.trim().isEmpty;

  bool get _isEnglishLocale =>
      Get.locale?.languageCode.toLowerCase().startsWith('en') ?? false;

  @override
  void initState() {
    super.initState();
    final initialKeyword = widget.initialKeyword.trim();
    _controller.text = widget.initialKeyword;
    _lastKeyword = _controller.text;
    _history = MarketSearchHistoryStorage.getHistory();
    _controller.addListener(_onKeywordChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _focusNode.requestFocus();
      if (initialKeyword.isNotEmpty) {
        _queueFetch(initialKeyword, immediate: true);
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.removeListener(_onKeywordChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onKeywordChanged() {
    final rawKeyword = _controller.text;
    if (rawKeyword == _lastKeyword) {
      return;
    }
    _lastKeyword = rawKeyword;
    final keyword = rawKeyword.trim();
    _debounce?.cancel();
    if (keyword.isEmpty) {
      setState(() {
        _requestId++;
        _isLoading = false;
        _hasQueried = false;
        _suggestions = [];
      });
      return;
    }
    setState(() {});
    _queueFetch(keyword);
  }

  void _queueFetch(String keyword, {bool immediate = false}) {
    _debounce?.cancel();
    if (immediate) {
      _fetchSuggestions(keyword);
      return;
    }
    _debounce = Timer(
      const Duration(milliseconds: 350),
      () => _fetchSuggestions(keyword),
    );
  }

  Future<void> _fetchSuggestions(String keyword) async {
    final requestId = ++_requestId;
    setState(() {
      _hasQueried = true;
      _isLoading = true;
    });
    try {
      final res = await _api.marketQueryItemName(
        appId: widget.appId,
        keywords: keyword,
      );
      if (!mounted ||
          requestId != _requestId ||
          _controller.text.trim() != keyword) {
        return;
      }
      setState(() => _suggestions = res.datas ?? []);
    } catch (_) {
      if (mounted && requestId == _requestId) {
        setState(() => _suggestions = []);
      }
    } finally {
      if (mounted && requestId == _requestId) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _submit(String keyword) async {
    final trimmed = keyword.trim();
    if (trimmed.isEmpty) {
      return;
    }
    await MarketSearchHistoryStorage.addHistory(trimmed);
    if (!mounted) {
      return;
    }
    widget.onSubmit(trimmed);
  }

  void _cancel() {
    if (widget.submitEmptyOnCancel && _controller.text.trim().isEmpty) {
      widget.onSubmit('');
      return;
    }
    widget.onCancel();
  }

  Future<void> _clearHistory() async {
    await MarketSearchHistoryStorage.clearHistory();
    if (mounted) {
      setState(() => _history = []);
    }
  }

  @override
  Widget build(BuildContext context) {
    return switch (widget.mode) {
      MarketSearchViewMode.sheet => _buildSheet(context),
      MarketSearchViewMode.page => _buildPage(context),
    };
  }

  Widget _buildSheet(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 12,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSheetSearchField(),
            const SizedBox(height: 12),
            if (_showHistory)
              _buildSheetHistorySection()
            else
              _buildSheetSuggestionSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(BuildContext context) {
    final shouldSubmitEmptyOnPop =
        widget.submitEmptyOnCancel && _controller.text.trim().isEmpty;
    return PopScope(
      canPop: !shouldSubmitEmptyOnPop,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _cancel();
        }
      },
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: ColoredBox(
          color: const Color(0xFFF7F9FB),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  children: [
                    _buildPageIconButton(
                      icon: Icons.arrow_back_rounded,
                      onTap: _cancel,
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: _buildPageSearchField()),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  child: KeyedSubtree(
                    key: ValueKey<bool>(_showHistory),
                    child: _showHistory
                        ? _buildPageHistorySection()
                        : _buildPageSuggestionSection(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSheetSearchField() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,
            textInputAction: TextInputAction.search,
            onSubmitted: _submit,
            decoration: InputDecoration(
              hintText: 'app.market.filter.search'.tr,
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _controller.text.trim().isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => _controller.clear(),
                    ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        TextButton(
          onPressed: widget.onCancel,
          child: Text('app.common.cancel'.tr),
        ),
      ],
    );
  }

  Widget _buildPageSearchField() {
    final hasKeyword = _controller.text.trim().isNotEmpty;
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0x14000000)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        textInputAction: TextInputAction.search,
        onSubmitted: _submit,
        style: const TextStyle(
          color: Color(0xFF191C1E),
          fontSize: 14,
          height: 20 / 14,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: 'app.market.filter.search'.tr,
          hintStyle: const TextStyle(
            color: Color(0xFF757684),
            fontSize: 14,
            height: 20 / 14,
            fontWeight: FontWeight.w400,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            size: 19,
            color: Color(0xFF757684),
          ),
          suffixIcon: hasKeyword
              ? IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: Color(0xFF757684),
                  ),
                  onPressed: () => _controller.clear(),
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Widget _buildPageIconButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: 34,
      height: 34,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: Icon(icon, size: 20, color: const Color(0xFF1E40AF)),
        ),
      ),
    );
  }

  Widget _buildSheetHistorySection() {
    if (_history.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          'app.common.no_data'.tr,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'app.market.filter.selection_quick'.tr,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            TextButton(
              onPressed: _clearHistory,
              child: Text('app.market.filter.clear'.tr),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _history
              .map(
                (keyword) => ActionChip(
                  label: Text(keyword),
                  onPressed: () => _submit(keyword),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _buildPageHistorySection() {
    return CustomScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      physics: const ClampingScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          sliver: SliverList.list(
            children: [
              _buildPageSectionHeader(
                title: 'app.market.filter.selection_quick'.tr,
                trailing: _history.isEmpty
                    ? null
                    : TextButton(
                        onPressed: _clearHistory,
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF00288E),
                          textStyle: const TextStyle(
                            fontSize: 13,
                            height: 20 / 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        child: Text('app.market.filter.clear'.tr),
                      ),
              ),
              const SizedBox(height: 12),
              if (_history.isEmpty)
                _buildPageEmptyCard(icon: Icons.history_rounded)
              else
                _buildPageSurface(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: _history
                        .map((keyword) => _buildHistoryChip(keyword))
                        .toList(),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSheetSuggestionSection() {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: CircularProgressIndicator(),
      );
    }
    if (!_hasQueried && _suggestions.isEmpty) {
      return const SizedBox.shrink();
    }
    if (_suggestions.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          'app.common.no_data'.tr,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }
    return SizedBox(
      height: 280,
      child: ListView.separated(
        itemCount: _suggestions.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final item = _suggestions[index];
          final name = item.displayName;
          return ListTile(title: Text(name), onTap: () => _submit(name));
        },
      ),
    );
  }

  Widget _buildPageSuggestionSection() {
    final keyword = _controller.text.trim();
    return ListView(
      key: const ValueKey<String>('page-suggestions'),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      physics: const ClampingScrollPhysics(),
      children: [
        _buildDirectSearchCard(keyword),
        const SizedBox(height: 12),
        if (_isLoading && _suggestions.isEmpty)
          _buildSuggestionLoadingCard()
        else if (_suggestions.isEmpty)
          _buildPageEmptyCard(icon: Icons.search_off_rounded)
        else
          _buildPageSurface(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                for (var index = 0; index < _suggestions.length; index++) ...[
                  _buildSuggestionTile(_suggestions[index]),
                  if (index != _suggestions.length - 1)
                    const Divider(height: 1, indent: 54, endIndent: 14),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildPageSectionHeader({required String title, Widget? trailing}) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: Color(0xFF191C1E),
              fontSize: 18,
              height: 24 / 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        if (trailing != null) trailing,
      ],
    );
  }

  Widget _buildPageSurface({
    required Widget child,
    EdgeInsets padding = EdgeInsets.zero,
  }) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x14000000)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildPageEmptyCard({required IconData icon}) {
    return _buildPageSurface(
      padding: const EdgeInsets.fromLTRB(18, 24, 18, 24),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F4F8),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: const Color(0xFF7A808A), size: 22),
          ),
          const SizedBox(height: 14),
          Text(
            'app.common.no_data'.tr,
            style: const TextStyle(
              color: Color(0xFF191C1E),
              fontSize: 15,
              height: 22 / 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _isEnglishLocale ? 'Try another keyword.' : '换个关键词再试试。',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF757684),
              fontSize: 13,
              height: 20 / 13,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryChip(String keyword) {
    return Material(
      color: const Color(0xFFF7F9FB),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () => _submit(keyword),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.history_rounded,
                size: 15,
                color: Color(0xFF757684),
              ),
              const SizedBox(width: 8),
              Text(
                keyword,
                style: const TextStyle(
                  color: Color(0xFF191C1E),
                  fontSize: 13,
                  height: 18 / 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDirectSearchCard(String keyword) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.zero,
        onTap: () => _submit(keyword),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.zero,
            gradient: const LinearGradient(
              colors: [Color(0xFFEEF3FF), Color(0xFFF6F8FF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: const Color(0x2200288E)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 14, 16),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFF00288E),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00288E).withValues(alpha: 0.22),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.search_rounded,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        keyword,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF191C1E),
                          fontSize: 15,
                          height: 22 / 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _isEnglishLocale
                            ? 'Search with the exact keyword'
                            : '按当前关键词直接搜索',
                        style: const TextStyle(
                          color: Color(0xFF757684),
                          fontSize: 12,
                          height: 18 / 12,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                const Icon(
                  Icons.north_west_rounded,
                  size: 18,
                  color: Color(0xFF00288E),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSuggestionTile(MarketNameSuggestion item) {
    final title = item.displayName;
    final subtitle =
        item.marketName != null &&
            item.marketHashName != null &&
            item.marketName != item.marketHashName
        ? item.marketHashName
        : null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _submit(title),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F4F8),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.search_rounded,
                  size: 16,
                  color: Color(0xFF757684),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF191C1E),
                        fontSize: 14,
                        height: 20 / 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF757684),
                          fontSize: 12,
                          height: 18 / 12,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              const Icon(
                Icons.north_west_rounded,
                size: 17,
                color: Color(0xFF757684),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuggestionLoadingCard() {
    return _buildPageSurface(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: List.generate(
          4,
          (index) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F4F8),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 12,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F4F8),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            height: 10,
                            width: 140,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5F6F8),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (index != 3)
                const Divider(height: 1, indent: 54, endIndent: 14),
            ],
          ),
        ),
      ),
    );
  }
}
