import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:tronskins_app/api/market.dart';
import 'package:tronskins_app/common/hooks/currency/CurrencyController.dart';
import 'package:tronskins_app/common/logging/app_logger.dart';
import 'package:tronskins_app/components/filter/filter_models.dart';
import 'package:tronskins_app/components/filter/filter_price_support.dart';
import 'package:tronskins_app/components/filter/filter_sheet_style.dart';
import 'dart:math' as math;

class MarketFilterSheet extends StatefulWidget {
  const MarketFilterSheet({
    super.key,
    required this.appId,
    required this.sortOptions,
    required this.initial,
    this.titleKey = 'app.market.filter.text',
    this.showPriceRange = true,
    this.showSort = true,
    this.showStatus = false,
    this.showDateRange = false,
    this.showAttributeFilters = true,
    this.statusOptions = const [],
    this.isSideSheet = false,
    this.initialGroupKey,
    this.attributeGroupOrder = const [],
    this.includeFallbackAttributeGroups = true,
    this.includeDefaultSortOption = true,
    this.useCompactSortLabels = false,
  });

  final int appId;
  final List<SortOption> sortOptions;
  final MarketFilterResult initial;
  final String titleKey;
  final bool showPriceRange;
  final bool showSort;
  final bool showStatus;
  final bool showDateRange;
  final bool showAttributeFilters;
  final List<StatusOption> statusOptions;
  final bool isSideSheet;
  final String? initialGroupKey;
  final List<String> attributeGroupOrder;
  final bool includeFallbackAttributeGroups;
  final bool includeDefaultSortOption;
  final bool useCompactSortLabels;

  static final GetStorage _box = GetStorage();
  static final Map<int, Map<String, List<_AttributeGroup>>> _memoryCache = {};
  static final Map<String, Future<List<_AttributeGroup>>> _inflight = {};
  static final Map<int, Map<String, int>> _memoryTs = {};
  static const Duration _cacheTtl = Duration(minutes: 10);
  static const String _cacheDataKey = '__data';
  static const String _cacheTsKey = '__ts';

  static Future<MarketFilterResult?> showFromRight({
    required BuildContext context,
    required int appId,
    required List<SortOption> sortOptions,
    required MarketFilterResult initial,
    String titleKey = 'app.market.filter.text',
    bool showPriceRange = true,
    bool showSort = true,
    bool showStatus = false,
    bool showDateRange = false,
    bool showAttributeFilters = true,
    List<StatusOption> statusOptions = const [],
    String? initialGroupKey,
    List<String> attributeGroupOrder = const [],
    bool includeFallbackAttributeGroups = true,
    bool includeDefaultSortOption = true,
    bool useCompactSortLabels = false,
  }) {
    return _showSideSheet(
      context: context,
      appId: appId,
      sortOptions: sortOptions,
      initial: initial,
      titleKey: titleKey,
      showPriceRange: showPriceRange,
      showSort: showSort,
      showStatus: showStatus,
      showDateRange: showDateRange,
      showAttributeFilters: showAttributeFilters,
      statusOptions: statusOptions,
      initialGroupKey: initialGroupKey,
      attributeGroupOrder: attributeGroupOrder,
      includeFallbackAttributeGroups: includeFallbackAttributeGroups,
      includeDefaultSortOption: includeDefaultSortOption,
      useCompactSortLabels: useCompactSortLabels,
      alignment: Alignment.centerRight,
      beginOffset: const Offset(1, 0),
    );
  }

  static Future<MarketFilterResult?> showFromLeft({
    required BuildContext context,
    required int appId,
    required List<SortOption> sortOptions,
    required MarketFilterResult initial,
    String titleKey = 'app.market.filter.text',
    bool showPriceRange = true,
    bool showSort = true,
    bool showStatus = false,
    bool showDateRange = false,
    bool showAttributeFilters = true,
    List<StatusOption> statusOptions = const [],
    String? initialGroupKey,
    List<String> attributeGroupOrder = const [],
    bool includeFallbackAttributeGroups = true,
    bool includeDefaultSortOption = true,
    bool useCompactSortLabels = false,
  }) {
    return _showSideSheet(
      context: context,
      appId: appId,
      sortOptions: sortOptions,
      initial: initial,
      titleKey: titleKey,
      showPriceRange: showPriceRange,
      showSort: showSort,
      showStatus: showStatus,
      showDateRange: showDateRange,
      showAttributeFilters: showAttributeFilters,
      statusOptions: statusOptions,
      initialGroupKey: initialGroupKey,
      attributeGroupOrder: attributeGroupOrder,
      includeFallbackAttributeGroups: includeFallbackAttributeGroups,
      includeDefaultSortOption: includeDefaultSortOption,
      useCompactSortLabels: useCompactSortLabels,
      alignment: Alignment.centerLeft,
      beginOffset: const Offset(-1, 0),
    );
  }

  static Future<MarketFilterResult?> _showSideSheet({
    required BuildContext context,
    required int appId,
    required List<SortOption> sortOptions,
    required MarketFilterResult initial,
    required Alignment alignment,
    required Offset beginOffset,
    String titleKey = 'app.market.filter.text',
    bool showPriceRange = true,
    bool showSort = true,
    bool showStatus = false,
    bool showDateRange = false,
    bool showAttributeFilters = true,
    List<StatusOption> statusOptions = const [],
    String? initialGroupKey,
    List<String> attributeGroupOrder = const [],
    bool includeFallbackAttributeGroups = true,
    bool includeDefaultSortOption = true,
    bool useCompactSortLabels = false,
  }) {
    final barrierLabel = MaterialLocalizations.of(
      context,
    ).modalBarrierDismissLabel;
    return showGeneralDialog<MarketFilterResult>(
      context: context,
      barrierDismissible: true,
      barrierLabel: barrierLabel,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        final width = MediaQuery.of(dialogContext).size.width;
        return Align(
          alignment: alignment,
          child: SizedBox(
            width: width,
            child: Material(
              color: Colors.transparent,
              child: MarketFilterSheet(
                appId: appId,
                sortOptions: sortOptions,
                initial: initial,
                titleKey: titleKey,
                showPriceRange: showPriceRange,
                showSort: showSort,
                showStatus: showStatus,
                showDateRange: showDateRange,
                showAttributeFilters: showAttributeFilters,
                statusOptions: statusOptions,
                isSideSheet: true,
                initialGroupKey: initialGroupKey,
                attributeGroupOrder: attributeGroupOrder,
                includeFallbackAttributeGroups: includeFallbackAttributeGroups,
                includeDefaultSortOption: includeDefaultSortOption,
                useCompactSortLabels: useCompactSortLabels,
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return SlideTransition(
          position: Tween<Offset>(
            begin: beginOffset,
            end: Offset.zero,
          ).animate(curved),
          child: child,
        );
      },
    );
  }

  static Future<void> preload({required int appId}) async {
    await Future<void>.delayed(Duration.zero);
    await _loadGroups(appId);
  }

  static Future<List<MarketFilterGroupMeta>> loadGroupMetas({
    required int appId,
  }) async {
    final groups = await _loadGroups(appId);
    return _buildGroupMetas(groups);
  }

  static List<MarketFilterGroupMeta> cachedGroupMetas({required int appId}) {
    final localeKey = _localeKeyStatic();
    final memoryGroups = _memoryCache[appId]?[localeKey];
    if (memoryGroups != null) {
      return _buildGroupMetas(memoryGroups);
    }

    final payload = _readCachePayload(appId, localeKey);
    if (payload == null) {
      return const <MarketFilterGroupMeta>[];
    }

    final groups = _buildGroupsStatic(appId, payload.raw);
    _memoryCache.putIfAbsent(appId, () => {})[localeKey] = groups;
    _memoryTs.putIfAbsent(appId, () => {})[localeKey] = payload.ts;
    return _buildGroupMetas(groups);
  }

  static List<MarketFilterGroupMeta> _buildGroupMetas(
    List<_AttributeGroup> groups,
  ) {
    return groups
        .map(
          (group) => MarketFilterGroupMeta(
            key: group.key,
            labelKey: group.label,
            optionLabels: _buildOptionLabelMap(group),
          ),
        )
        .toList(growable: false);
  }

  static Map<String, String> _buildOptionLabelMap(_AttributeGroup group) {
    final labels = <String, String>{};
    for (final option in group.options) {
      if (!option.isUnlimited && option.name.isNotEmpty) {
        labels[option.name] = option.label;
      }
      for (final sub in option.subOptions) {
        if (!sub.isUnlimited && sub.name.isNotEmpty) {
          labels[sub.name] = sub.label;
        }
      }
    }
    for (final heroSection in group.heroSections) {
      for (final hero in heroSection.heroes) {
        if (!hero.isUnlimited && hero.name.isNotEmpty) {
          labels[hero.name] = hero.label;
        }
      }
    }
    return labels;
  }

  static String _localeKeyStatic() {
    final locale = Get.locale;
    if (locale == null) return 'en_US';
    final country = locale.countryCode;
    return country == null
        ? locale.languageCode
        : '${locale.languageCode}_$country';
  }

  static bool _isExpired(int ts, int now) {
    if (ts <= 0) return true;
    return (now - ts) > _cacheTtl.inMilliseconds;
  }

  static _CachePayload? _readCachePayload(int appId, String localeKey) {
    final cacheKey = 'schema_tags_$appId';
    final cached = _box.read<Map<String, dynamic>>(cacheKey);
    final cachedData = cached?[localeKey];
    if (cachedData is Map<String, dynamic>) {
      if (cachedData.containsKey(_cacheDataKey)) {
        final raw = cachedData[_cacheDataKey];
        final tsValue = cachedData[_cacheTsKey];
        final ts = tsValue is int
            ? tsValue
            : int.tryParse(tsValue?.toString() ?? '') ?? 0;
        if (raw is Map<String, dynamic>) {
          return _CachePayload(raw, ts);
        }
      }
      return _CachePayload(cachedData, 0);
    }
    return null;
  }

  static Future<void> _writeCache(
    int appId,
    String localeKey,
    Map<String, dynamic> raw,
  ) async {
    final cacheKey = 'schema_tags_$appId';
    final cached =
        _box.read<Map<String, dynamic>>(cacheKey) ?? <String, dynamic>{};
    cached[localeKey] = <String, dynamic>{
      _cacheTsKey: DateTime.now().millisecondsSinceEpoch,
      _cacheDataKey: raw,
    };
    await _box.write(cacheKey, cached);
  }

  static Future<List<_AttributeGroup>> _fetchAndCache(
    int appId,
    String localeKey,
  ) async {
    try {
      final api = ApiMarketServer();
      final res = await api.marketAttributeList(appId: appId);
      final data = res.datas?.data;
      if (data != null && data.isNotEmpty) {
        await _writeCache(appId, localeKey, data);
        final groups = _buildGroupsStatic(appId, data);
        _memoryCache.putIfAbsent(appId, () => {})[localeKey] = groups;
        _memoryTs.putIfAbsent(appId, () => {})[localeKey] =
            DateTime.now().millisecondsSinceEpoch;
        return groups;
      }
      return <_AttributeGroup>[];
    } catch (_) {
      return <_AttributeGroup>[];
    }
  }

  static Future<List<_AttributeGroup>> _awaitFetch(
    int appId,
    String localeKey,
  ) async {
    final inflightKey = '$appId:$localeKey';
    final existing = _inflight[inflightKey];
    if (existing != null) {
      return existing;
    }
    final task = _fetchAndCache(appId, localeKey);
    _inflight[inflightKey] = task;
    try {
      return await task;
    } finally {
      _inflight.remove(inflightKey);
    }
  }

  static void _refreshInBackground(int appId, String localeKey) {
    final inflightKey = '$appId:$localeKey';
    if (_inflight.containsKey(inflightKey)) {
      return;
    }
    _awaitFetch(appId, localeKey);
  }

  static Future<List<_AttributeGroup>> _loadGroups(int appId) async {
    final localeKey = _localeKeyStatic();
    final now = DateTime.now().millisecondsSinceEpoch;
    final cachedByLocale = _memoryCache[appId];
    final memoryGroups = cachedByLocale?[localeKey];
    if (memoryGroups != null) {
      final ts = _memoryTs[appId]?[localeKey] ?? 0;
      if (_isExpired(ts, now)) {
        _refreshInBackground(appId, localeKey);
      }
      return memoryGroups;
    }

    final payload = _readCachePayload(appId, localeKey);
    if (payload != null) {
      final groups = _buildGroupsStatic(appId, payload.raw);
      _memoryCache.putIfAbsent(appId, () => {})[localeKey] = groups;
      _memoryTs.putIfAbsent(appId, () => {})[localeKey] = payload.ts;
      if (_isExpired(payload.ts, now)) {
        _refreshInBackground(appId, localeKey);
      }
      return groups;
    }

    return _awaitFetch(appId, localeKey);
  }

  @override
  State<MarketFilterSheet> createState() => _MarketFilterSheetState();
}

class _MarketFilterSheetState extends State<MarketFilterSheet> {
  late String _sortField;
  late bool _sortAsc;
  late final TextEditingController _minController;
  late final TextEditingController _maxController;
  DateTime? _startDate;
  DateTime? _endDate;
  double? _wearMin;
  double? _wearMax;
  int _selectedStatusIndex = -1;

  final Map<String, String?> _selectedTags = {};
  final Map<String, List<String>> _selectedMultiTags = {};
  final ScrollController _scrollController = ScrollController();
  String? _selectedItemName;
  List<_AttributeGroup> _groups = [];
  bool _isLoading = true;
  bool _hasLoadScheduled = false;
  List<_FilterSection> _sections = [];
  int _currentSectionIndex = 0;
  bool _hasAppliedInitialGroupKey = false;
  bool _showAllDotaHeroes = false;
  final Map<String, GlobalKey> _selectionAnchorKeys = {};
  final GlobalKey _dotaHeroToggleKey = GlobalKey();
  final Set<String> _loggedDotaHeroImageIssues = <String>{};
  final Set<String> _expandedAccordionSections = <String>{};
  final Set<String> _knownAccordionSections = <String>{};

  bool get _isDota => widget.appId == 570;
  bool get _isLegacyTfPriceOnly =>
      widget.appId == 440 &&
      widget.showPriceRange &&
      !widget.showSort &&
      !widget.showStatus &&
      !widget.showDateRange &&
      !widget.showAttributeFilters;

  EdgeInsets get _bodyPadding => const EdgeInsets.fromLTRB(16, 16, 16, 24);

  double get _sectionGap => 16;

  CurrencyController get _currency => Get.find<CurrencyController>();

  @override
  void initState() {
    super.initState();
    _sortField = widget.showSort
        ? widget.initial.sortField
        : _defaultSortField();
    _sortAsc = widget.showSort ? widget.initial.sortAsc : _defaultSortAsc();
    _minController = TextEditingController(
      text: widget.showPriceRange
          ? _initialPriceText(widget.initial.priceMin)
          : '',
    );
    _maxController = TextEditingController(
      text: widget.showPriceRange
          ? _initialPriceText(widget.initial.priceMax)
          : '',
    );
    if (widget.showAttributeFilters && widget.initial.tags != null) {
      widget.initial.tags!.forEach((key, value) {
        if (key == 'paintWearMin') {
          _wearMin = _parseOptionalDouble(value);
          return;
        }
        if (key == 'paintWearMax') {
          _wearMax = _parseOptionalDouble(value);
          return;
        }
        if (value is Iterable) {
          final values = value
              .map((item) => item?.toString() ?? '')
              .where((item) => item.isNotEmpty)
              .toList(growable: false);
          if (values.isNotEmpty) {
            _selectedMultiTags[key] = values;
          }
          return;
        }
        _selectedTags[key] = value?.toString();
      });
    }
    final initialExterior = _selectedTags['exterior'];
    if ((_wearMin == null || _wearMax == null) &&
        initialExterior != null &&
        initialExterior.isNotEmpty) {
      final range = _wearRangeForName(initialExterior);
      if (range != null) {
        _wearMin ??= range.start;
        _wearMax ??= range.end;
      }
    }
    _selectedItemName = widget.showAttributeFilters
        ? widget.initial.itemName
        : null;
    _startDate = widget.initial.startDate;
    _endDate = widget.initial.endDate;
    _selectedStatusIndex = _resolveInitialStatusIndex();
    if (widget.showAttributeFilters) {
      _primeCache();
    } else {
      _isLoading = false;
    }
    _rebuildSections();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.showAttributeFilters && _groups.isEmpty) {
        _scheduleLoad();
      }
    });
  }

  int _resolveInitialStatusIndex() {
    if (!widget.showStatus || widget.statusOptions.isEmpty) {
      return -1;
    }
    final initialStatusList = widget.initial.statusList;
    if (initialStatusList == null || initialStatusList.isEmpty) {
      return -1;
    }
    return widget.statusOptions.indexWhere(
      (option) => _listEquals(option.values, initialStatusList),
    );
  }

  bool _listEquals(List<int> a, List<int> b) {
    if (a.length != b.length) {
      return false;
    }
    for (var i = 0; i < a.length; i += 1) {
      if (a[i] != b[i]) {
        return false;
      }
    }
    return true;
  }

  void _primeCache() {
    final localeKey = _localeKey();
    final memory = MarketFilterSheet._memoryCache[widget.appId];
    final memoryGroups = memory?[localeKey];
    if (memoryGroups != null) {
      _groups = memoryGroups;
      _isLoading = false;
      _rebuildSections();
      final ts = MarketFilterSheet._memoryTs[widget.appId]?[localeKey] ?? 0;
      if (MarketFilterSheet._isExpired(
        ts,
        DateTime.now().millisecondsSinceEpoch,
      )) {
        MarketFilterSheet._refreshInBackground(widget.appId, localeKey);
      }
      return;
    }
    final payload = MarketFilterSheet._readCachePayload(
      widget.appId,
      localeKey,
    );
    if (payload != null) {
      _groups = _buildGroups(payload.raw);
      MarketFilterSheet._memoryCache.putIfAbsent(
        widget.appId,
        () => {},
      )[localeKey] = _groups;
      MarketFilterSheet._memoryTs.putIfAbsent(
        widget.appId,
        () => {},
      )[localeKey] = payload.ts;
      _isLoading = false;
      _rebuildSections();
      if (MarketFilterSheet._isExpired(
        payload.ts,
        DateTime.now().millisecondsSinceEpoch,
      )) {
        MarketFilterSheet._refreshInBackground(widget.appId, localeKey);
      }
    }
  }

  Future<void> _scheduleLoad() async {
    if (_groups.isNotEmpty || _hasLoadScheduled) {
      return;
    }
    _hasLoadScheduled = true;
    final disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final delay = disableAnimations
        ? Duration.zero
        : widget.isSideSheet
        ? const Duration(milliseconds: 280)
        : Duration.zero;
    await Future<void>.delayed(delay);
    if (mounted) {
      await _loadAttributes();
    }
  }

  void _rebuildSections() {
    final sections = <_FilterSection>[];
    if (widget.showSort) {
      sections.add(
        const _FilterSection(
          type: _SectionType.sort,
          labelKey: 'app.market.filter.sort',
        ),
      );
    }
    if (widget.showPriceRange) {
      sections.add(
        const _FilterSection(
          type: _SectionType.price,
          labelKey: 'app.market.filter.price',
        ),
      );
    }
    if (widget.showAttributeFilters) {
      for (final group in _groups) {
        sections.add(
          _FilterSection(
            type: _SectionType.group,
            labelKey: group.label,
            group: group,
          ),
        );
      }
    }
    if (widget.showStatus) {
      sections.add(
        const _FilterSection(
          type: _SectionType.status,
          labelKey: 'app.trade.order.status',
        ),
      );
    }
    if (widget.showDateRange) {
      sections.add(
        const _FilterSection(
          type: _SectionType.date,
          labelKey: 'app.trade.order.date',
        ),
      );
    }
    _sections = sections;
    if (_currentSectionIndex >= _sections.length) {
      _currentSectionIndex = 0;
    }
    _applyInitialGroupSection();
  }

  void _applyInitialGroupSection() {
    if (_hasAppliedInitialGroupKey) {
      return;
    }
    final targetKey = widget.initialGroupKey;
    if (targetKey == null || targetKey.isEmpty) {
      _hasAppliedInitialGroupKey = true;
      return;
    }
    final index = _sections.indexWhere(
      (section) =>
          section.type == _SectionType.group && section.group?.key == targetKey,
    );
    if (index < 0) {
      return;
    }
    _currentSectionIndex = index;
    _hasAppliedInitialGroupKey = true;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _minController.dispose();
    _maxController.dispose();
    super.dispose();
  }

  GlobalKey _selectionAnchorKey(String sectionKey, String optionName) {
    final key = '$sectionKey::$optionName';
    return _selectionAnchorKeys.putIfAbsent(key, GlobalKey.new);
  }

  void _toggleDotaHeroSections() {
    final collapsing = _showAllDotaHeroes;
    setState(() {
      _showAllDotaHeroes = !_showAllDotaHeroes;
    });
    if (!collapsing) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        return;
      }
      final toggleContext = _dotaHeroToggleKey.currentContext;
      if (toggleContext == null) {
        return;
      }
      final renderObject = toggleContext.findRenderObject();
      final viewport = renderObject == null
          ? null
          : RenderAbstractViewport.of(renderObject);
      final position = _scrollController.hasClients
          ? _scrollController.position
          : null;
      if (renderObject == null || viewport == null || position == null) {
        return;
      }
      final revealedOffset = viewport.getOffsetToReveal(renderObject, 1).offset;
      final targetOffset = (revealedOffset - 12).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      );
      if ((position.pixels - targetOffset).abs() < 1) {
        return;
      }
      await _scrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _loadAttributes() async {
    if (_groups.isNotEmpty) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      return;
    }
    if (mounted) {
      setState(() => _isLoading = true);
    }
    final groups = await MarketFilterSheet._loadGroups(widget.appId);
    if (!mounted) {
      _groups = groups;
      return;
    }
    setState(() {
      _groups = groups;
      _rebuildSections();
      _isLoading = false;
    });
  }

  String _localeKey() {
    return MarketFilterSheet._localeKeyStatic();
  }

  List<_AttributeGroup> _buildGroups(Map<String, dynamic> raw) {
    return _buildGroupsStatic(widget.appId, raw);
  }

  void _reset() {
    final resetField = _defaultSortField();
    Navigator.of(context).pop(
      MarketFilterResult(
        sortField: resetField,
        sortAsc: _defaultSortAsc(),
        priceMin: null,
        priceMax: null,
        tags: <String, dynamic>{},
        itemName: '',
        statusList: null,
        startDate: null,
        endDate: null,
        clearKeyword: true,
      ),
    );
  }

  void _apply() {
    final min = _parseDisplayPriceOrNull(_minController.text);
    final max = _parseDisplayPriceOrNull(_maxController.text);
    final tags = <String, dynamic>{}
      ..addEntries(
        _selectedTags.entries.where(
          (entry) =>
              entry.value != null &&
              entry.value != '' &&
              entry.value != 'unlimited',
        ),
      );
    for (final entry in _selectedMultiTags.entries) {
      final values = entry.value
          .where((value) => value.isNotEmpty && value != 'unlimited')
          .toList(growable: false);
      if (values.isNotEmpty) {
        tags[entry.key] = values;
      }
    }
    if (_wearMin != null) {
      tags['paintWearMin'] = _wearMin;
    }
    if (_wearMax != null) {
      tags['paintWearMax'] = _wearMax;
    }
    final effectiveSortField = widget.showSort
        ? _sortField
        : _defaultSortField();
    final effectiveSortAsc = widget.showSort ? _sortAsc : _defaultSortAsc();
    final effectivePriceMin = widget.showPriceRange ? min : null;
    final effectivePriceMax = widget.showPriceRange ? max : null;
    final effectiveTags = widget.showAttributeFilters
        ? tags
        : <String, dynamic>{};
    final effectiveItemName = widget.showAttributeFilters
        ? (_selectedItemName ?? '')
        : '';

    Navigator.of(context).pop(
      MarketFilterResult(
        sortField: effectiveSortField,
        sortAsc: effectiveSortAsc,
        priceMin: effectivePriceMin,
        priceMax: effectivePriceMax,
        tags: effectiveTags,
        itemName: effectiveItemName,
        statusList: widget.showStatus && _selectedStatusIndex >= 0
            ? widget.statusOptions[_selectedStatusIndex].values
            : null,
        startDate: widget.showDateRange ? _startDate : null,
        endDate: widget.showDateRange ? _endDate : null,
      ),
    );
  }

  String _initialPriceText(double? usdValue) {
    if (usdValue == null || usdValue <= 0) {
      return '';
    }
    return FilterPriceSupport.formatEditableNumber(_currency, usdValue);
  }

  double _parseDisplayPriceOrZero(String rawValue) {
    return FilterPriceSupport.displayToUsd(_currency, rawValue);
  }

  double? _parseDisplayPriceOrNull(String rawValue) {
    if (rawValue.trim().isEmpty) {
      return null;
    }
    final parsed = _parseDisplayPriceOrZero(rawValue);
    return parsed <= 0 ? null : parsed;
  }

  String _formatDisplayPrice(double usdValue) {
    return FilterPriceSupport.formatAmount(_currency, usdValue);
  }

  double _measurePriceLabelWidth(String text) {
    const style = TextStyle(
      fontSize: 10,
      height: 15 / 10,
      fontWeight: FontWeight.w500,
    );
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: Directionality.of(context),
      maxLines: 1,
    )..layout();
    return painter.width + 12;
  }

  bool _isGroupSelected(String key, _AttributeOption option) {
    final multiSelected = _selectedMultiTags[key];
    if (multiSelected != null) {
      if (option.isUnlimited) {
        return multiSelected.isEmpty;
      }
      return multiSelected.contains(option.name);
    }
    final selected = _selectedTags[key];
    if (option.isUnlimited) {
      return selected == null;
    }
    return selected == option.name;
  }

  void _selectOption(String key, _AttributeOption option) {
    setState(() {
      if (_isMultiSelectGroupKey(key)) {
        final values = List<String>.from(_selectedMultiTags[key] ?? const []);
        if (option.isUnlimited) {
          values.clear();
        } else if (values.contains(option.name)) {
          values.remove(option.name);
        } else {
          values.add(option.name);
        }
        if (values.isEmpty) {
          _selectedMultiTags.remove(key);
        } else {
          _selectedMultiTags[key] = values;
        }
        return;
      }
      if (option.isUnlimited) {
        _selectedTags.remove(key);
        if (key == 'type') {
          _selectedItemName = null;
        }
        return;
      }
      _selectedTags[key] = option.name;
    });
  }

  void _selectSubOption(_AttributeGroup group, _AttributeOption option) {
    setState(() {
      if (option.isUnlimited) {
        _selectedItemName = null;
        _selectedTags.remove(group.key);
        return;
      }
      _selectedItemName = option.name;
      if (option.parentName != null && option.parentName!.isNotEmpty) {
        _selectedTags[group.key] = option.parentName;
      } else {
        _selectedTags[group.key] = option.name;
      }
    });
  }

  double? _parseOptionalDouble(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value.toString());
  }

  int get _selectedFilterCount {
    var count = 0;
    final min = _parseDisplayPriceOrNull(_minController.text);
    final max = _parseDisplayPriceOrNull(_maxController.text);
    if (widget.showSort && _sortField.isNotEmpty) {
      count += 1;
    }
    if (widget.showPriceRange && (min != null || max != null)) {
      count += 1;
    }
    if (widget.showStatus && _selectedStatusIndex >= 0) {
      count += 1;
    }
    if (widget.showDateRange && (_startDate != null || _endDate != null)) {
      count += 1;
    }

    if (widget.showAttributeFilters) {
      final selectedTagValues = <String>{};
      for (final value in _selectedTags.values) {
        final normalized = (value ?? '').trim();
        if (normalized.isEmpty || normalized == 'unlimited') {
          continue;
        }
        selectedTagValues.add(normalized);
        count += 1;
      }

      for (final values in _selectedMultiTags.values) {
        count += values
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty && value != 'unlimited')
            .toSet()
            .length;
      }

      final selectedItemName = (_selectedItemName ?? '').trim();
      if (selectedItemName.isNotEmpty &&
          !selectedTagValues.contains(selectedItemName)) {
        count += 1;
      }

      final hasExteriorTag = ((_selectedTags['exterior'] ?? '')
          .trim()
          .isNotEmpty);
      if (!hasExteriorTag && (_wearMin != null || _wearMax != null)) {
        count += 1;
      }
    }

    return count;
  }

  bool _isMultiSelectGroupKey(String key) {
    return key == 'rarity';
  }

  @override
  Widget build(BuildContext context) {
    final body = FilterSheetFrame(
      title: widget.titleKey.tr,
      resetLabel: 'app.market.filter.reset'.tr,
      onReset: _reset,
      onClose: () {
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      },
      confirmLabel: _isLegacyTfPriceOnly
          ? 'app.common.confirm'.tr
          : 'app.market.filter.finish'.tr,
      confirmCount: _selectedFilterCount,
      onConfirm: _apply,
      body: _buildSectionList(),
    );
    if (!widget.isSideSheet) {
      return body;
    }
    return Dismissible(
      key: const ValueKey('market_filter_sheet'),
      direction: DismissDirection.startToEnd,
      dismissThresholds: const {DismissDirection.startToEnd: 0.2},
      background: const SizedBox.shrink(),
      onDismissed: (_) {
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      },
      child: body,
    );
  }

  Widget _buildSectionList() {
    final bodySections = _buildBodySections();
    if (bodySections.isEmpty) {
      if (_isLoading) {
        return _buildFilterLoadingState();
      }
      return Center(
        child: Text(
          'app.common.no_data'.tr,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }
    return SingleChildScrollView(
      controller: _scrollController,
      physics: const ClampingScrollPhysics(),
      padding: _bodyPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < bodySections.length; i++) ...[
            bodySections[i],
            if (i != bodySections.length - 1) SizedBox(height: _sectionGap),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildBodySections() {
    if (_isDota) {
      return _buildDotaBodySections();
    }
    final sections = <Widget>[];
    if (widget.showPriceRange) {
      sections.add(
        _buildAccordionSection(
          sectionKey: 'price',
          title: 'app.market.filter.price_range'.tr,
          contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: _buildPriceSectionContent(),
        ),
      );
    }

    if (!widget.showAttributeFilters) {
      if (widget.showStatus) {
        sections.add(
          _buildAccordionSection(
            sectionKey: 'status',
            title: 'app.trade.order.status'.tr,
            contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: _buildStatusSectionContent(),
          ),
        );
      }
      if (widget.showDateRange) {
        sections.add(
          _buildAccordionSection(
            sectionKey: 'date',
            title: 'app.trade.order.date'.tr,
            contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: _buildDateSectionContent(),
          ),
        );
      }
      if (widget.showSort) {
        sections.add(
          _buildAccordionSection(
            sectionKey: 'sort',
            title: 'app.market.filter.sort'.tr,
            contentPadding: EdgeInsets.zero,
            child: _buildSortSectionContent(),
          ),
        );
      }
      return sections;
    }

    for (final group in _orderedMarketGroups()) {
      sections.add(_buildMarketGroupSection(group));
    }

    if (widget.showStatus) {
      sections.add(
        _buildAccordionSection(
          sectionKey: 'status',
          title: 'app.trade.order.status'.tr,
          contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: _buildStatusSectionContent(),
        ),
      );
    }
    if (widget.showDateRange) {
      sections.add(
        _buildAccordionSection(
          sectionKey: 'date',
          title: 'app.trade.order.date'.tr,
          contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: _buildDateSectionContent(),
        ),
      );
    }
    if (widget.showSort) {
      sections.add(
        _buildAccordionSection(
          sectionKey: 'sort',
          title: 'app.market.filter.sort'.tr,
          contentPadding: EdgeInsets.zero,
          child: _buildSortSectionContent(),
        ),
      );
    }
    return sections;
  }

  List<Widget> _buildDotaBodySections() {
    final sections = <Widget>[];
    final renderedKeys = <String>{};

    final heroGroup = _findGroup('hero');
    if (heroGroup != null) {
      renderedKeys.add(heroGroup.key);
      sections.add(
        _buildAccordionSection(
          sectionKey: 'hero',
          title: heroGroup.label.tr,
          showDivider: true,
          contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: _buildDotaHeroGroupSection(heroGroup),
        ),
      );
    }

    for (final key in const ['slot', 'type']) {
      final group = _findGroup(key);
      if (group == null) {
        continue;
      }
      renderedKeys.add(group.key);
      sections.add(
        _buildAccordionSection(
          sectionKey: group.key,
          title: _formatDotaSectionTitle(group.key, group.label.tr),
          contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: _buildDotaTagSection([group], matchWeaponTypeStyle: true),
        ),
      );
    }

    final qualityGroup = _findGroup('quality');
    if (qualityGroup != null) {
      renderedKeys.add(qualityGroup.key);
      sections.add(
        _buildAccordionSection(
          sectionKey: 'quality',
          title: _formatDotaSectionTitle(
            qualityGroup.key,
            qualityGroup.label.tr,
          ),
          contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: _buildDotaQualitySection(qualityGroup),
        ),
      );
    }

    final rarityGroup = _findGroup('rarity');
    if (rarityGroup != null) {
      renderedKeys.add(rarityGroup.key);
      sections.add(
        _buildAccordionSection(
          sectionKey: 'rarity',
          title: _formatDotaSectionTitle(rarityGroup.key, rarityGroup.label.tr),
          contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: _buildDotaRaritySection(rarityGroup),
        ),
      );
    }

    for (final group in _groups) {
      if (renderedKeys.contains(group.key)) {
        continue;
      }
      sections.add(
        _buildAccordionSection(
          sectionKey: group.key,
          title: _formatDotaSectionTitle(group.key, group.label.tr),
          contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: _buildDotaFallbackSection(group),
        ),
      );
    }

    if (widget.showPriceRange) {
      sections.add(
        _buildAccordionSection(
          sectionKey: 'price',
          title: 'app.market.filter.price_range'.tr,
          contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          child: _buildDotaPriceSection(),
        ),
      );
    }
    if (widget.showSort) {
      sections.add(
        _buildAccordionSection(
          sectionKey: 'sort',
          title: 'app.market.filter.sort'.tr,
          contentPadding: EdgeInsets.zero,
          child: _buildDotaSortSection(),
        ),
      );
    }
    if (widget.showStatus) {
      sections.add(
        _buildAccordionSection(
          sectionKey: 'status',
          title: 'app.trade.order.status'.tr,
          contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: _buildStatusSectionContent(),
        ),
      );
    }
    if (widget.showDateRange) {
      sections.add(
        _buildAccordionSection(
          sectionKey: 'date',
          title: 'app.trade.order.date'.tr,
          contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: _buildDateSectionContent(),
        ),
      );
    }
    return sections;
  }

  _AttributeGroup? _findGroup(String key) {
    for (final group in _groups) {
      if (group.key == key) {
        return group;
      }
    }
    return null;
  }

  Widget _buildFilterLoadingState() {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 23, 16, 24),
      children: const [
        _FilterLoadingBlock(height: 188, carded: true),
        SizedBox(height: 24),
        _FilterLoadingBlock(height: 124, carded: false),
        SizedBox(height: 24),
        _FilterLoadingBlock(height: 146, carded: true),
        SizedBox(height: 24),
        _FilterLoadingBlock(height: 178, carded: true),
      ],
    );
  }

  Set<String> _selectedValuesForGroup(String key) {
    final multiValues = _selectedMultiTags[key];
    if (multiValues != null && multiValues.isNotEmpty) {
      return multiValues.toSet();
    }
    final selected = _selectedTags[key];
    if (selected == null || selected.isEmpty) {
      return <String>{};
    }
    return <String>{selected};
  }

  List<_AttributeOption> _visibleOptions(_AttributeGroup group) {
    return group.options
        .where((option) => !option.isUnlimited)
        .toList(growable: false);
  }

  Widget _buildPlainChipWrap({
    required List<_AttributeOption> options,
    required bool Function(_AttributeOption option) isSelected,
    required void Function(_AttributeOption option) onTap,
    FilterChipSelectedStyle selectedStyle = FilterChipSelectedStyle.solid,
    Color? selectedColor,
    Color? selectedBorderColor,
    Color? selectedTextColor,
    Color? unselectedColor,
    Color? unselectedBorderColor,
    Color? unselectedTextColor,
    double fontSize = 14,
    double minHeight = 38,
    EdgeInsetsGeometry padding = const EdgeInsets.symmetric(
      horizontal: 16,
      vertical: 8,
    ),
    BorderRadius borderRadius = const BorderRadius.all(Radius.circular(4)),
    List<BoxShadow> boxShadow = const <BoxShadow>[],
    List<BoxShadow>? selectedBoxShadow,
    List<BoxShadow>? unselectedBoxShadow,
    FontWeight selectedFontWeight = FontWeight.w600,
    FontWeight unselectedFontWeight = FontWeight.w500,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final option in options)
          FilterSheetOptionChip(
            label: option.label.tr,
            selected: isSelected(option),
            selectedStyle: selectedStyle,
            selectedColor: selectedColor,
            selectedBorderColor: selectedBorderColor,
            selectedTextColor: selectedTextColor,
            unselectedColor: unselectedColor,
            unselectedBorderColor: unselectedBorderColor,
            unselectedTextColor: unselectedTextColor,
            borderRadius: borderRadius,
            padding: padding,
            minHeight: minHeight,
            fontSize: fontSize,
            height: 21 / fontSize,
            boxShadow: boxShadow,
            selectedBoxShadow: selectedBoxShadow,
            unselectedBoxShadow: unselectedBoxShadow,
            selectedFontWeight: selectedFontWeight,
            unselectedFontWeight: unselectedFontWeight,
            onTap: () => onTap(option),
          ),
      ],
    );
  }

  Widget _buildFigmaWeaponTypeChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    bool alignLeft = false,
    bool fullWidth = false,
  }) {
    return FilterSheetOptionChip(
      label: label,
      selected: selected,
      fullWidth: fullWidth,
      selectedStyle: FilterChipSelectedStyle.solid,
      selectedColor: FilterSheetStyle.primary,
      selectedBorderColor: Colors.transparent,
      selectedTextColor: Colors.white,
      unselectedColor: FilterSheetStyle.subtleBackground,
      unselectedBorderColor: Colors.transparent,
      unselectedTextColor: FilterSheetStyle.body,
      borderRadius: const BorderRadius.all(Radius.circular(4)),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      minHeight: 37,
      fontSize: 14,
      height: 21 / 14,
      selectedFontWeight: FontWeight.w500,
      unselectedFontWeight: FontWeight.w400,
      contentAlignment: alignLeft ? Alignment.centerLeft : Alignment.center,
      textAlign: alignLeft ? TextAlign.left : TextAlign.center,
      selectedBoxShadow: const <BoxShadow>[
        BoxShadow(
          color: Color(0x0D000000),
          blurRadius: 2,
          offset: Offset(0, 1),
        ),
      ],
      unselectedBoxShadow: const <BoxShadow>[],
      onTap: onTap,
    );
  }

  Widget _buildWeaponTypeSectionContent(_AttributeGroup group) {
    final options = _visibleOptions(group);
    return _buildLeftAlignedChipWrap([
      _buildFigmaWeaponTypeChip(
        label: _defaultFilterLabel,
        selected: _isDefaultSelectedForGroup(group.key),
        onTap: () => _selectDefaultForGroup(group.key),
      ),
      for (final option in options)
        _buildFigmaWeaponTypeChip(
          label: option.label.tr,
          selected: _isGroupSelected(group.key, option),
          onTap: () => _selectOption(group.key, option),
        ),
    ]);
  }

  String _formatDotaSectionTitle(String key, String title) {
    const capitalizedKeys = <String>{'slot', 'type', 'rarity', 'quality'};
    if (!capitalizedKeys.contains(key) || title.isEmpty) {
      return title;
    }
    final first = title[0];
    return '${first.toUpperCase()}${title.substring(1)}';
  }

  bool _isAccordionExpanded(String sectionKey) {
    if (_knownAccordionSections.add(sectionKey)) {
      _expandedAccordionSections.add(sectionKey);
    }
    return _expandedAccordionSections.contains(sectionKey);
  }

  void _toggleAccordionSection(String sectionKey) {
    setState(() {
      _knownAccordionSections.add(sectionKey);
      if (_expandedAccordionSections.contains(sectionKey)) {
        _expandedAccordionSections.remove(sectionKey);
      } else {
        _expandedAccordionSections.add(sectionKey);
      }
    });
  }

  Widget _buildAccordionSection({
    required String sectionKey,
    required String title,
    required Widget child,
    EdgeInsetsGeometry contentPadding = const EdgeInsets.fromLTRB(
      20,
      0,
      20,
      20,
    ),
    bool showDivider = false,
  }) {
    final expanded = _isAccordionExpanded(sectionKey);
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: FilterSheetStyle.cardBackground,
        borderRadius: FilterSheetStyle.cardRadius,
        boxShadow: FilterSheetStyle.cardShadow,
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: FilterSheetStyle.cardRadius,
            onTap: () => _toggleAccordionSection(sectionKey),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: FilterSheetStyle.title,
                        fontSize: 18,
                        height: 28 / 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.45,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 18,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (expanded) ...[
            if (showDivider)
              const Divider(
                height: 1,
                thickness: 1,
                color: FilterSheetStyle.surfaceStroke,
              ),
            Padding(padding: contentPadding, child: child),
          ],
        ],
      ),
    );
  }

  Widget _buildDotaHeroGroupSection(_AttributeGroup group) {
    final selectedHero = _selectedTags['hero'];
    final visibleSections = _showAllDotaHeroes
        ? group.heroSections
        : group.heroSections.take(2).toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < visibleSections.length; i++) ...[
          _buildDotaHeroSection(
            visibleSections[i],
            selectedHero,
            sectionKey: 'group:${group.key}',
          ),
          if (i != visibleSections.length - 1) const SizedBox(height: 24),
        ],
        if (group.heroSections.length > 2) ...[
          const SizedBox(height: 8),
          Center(
            child: InkWell(
              key: _dotaHeroToggleKey,
              onTap: _toggleDotaHeroSections,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _showAllDotaHeroes ? 'View Less' : 'VIEW ALL HEROES',
                      style: const TextStyle(
                        color: Color(0xFF0058BE),
                        fontSize: 12,
                        height: 16 / 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(width: 4),
                    AnimatedRotation(
                      turns: _showAllDotaHeroes ? 0.5 : 0,
                      duration: const Duration(milliseconds: 180),
                      child: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 14,
                        color: Color(0xFF0058BE),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDotaHeroSection(
    _HeroSection section,
    String? selectedHero, {
    required String sectionKey,
  }) {
    final title = _dotaHeroSectionTitle(section.labelKey);
    final accent = _dotaHeroSectionAccent(section.labelKey);
    final visibleHeroes = _showAllDotaHeroes
        ? section.heroes
        : section.heroes.take(4).toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(accent.icon, size: 14, color: accent.color),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 14,
                height: 20 / 14,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.7,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            const spacing = 12.0;
            final itemWidth = (constraints.maxWidth - (spacing * 3)) / 4;
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                for (final hero in visibleHeroes)
                  SizedBox(
                    width: itemWidth,
                    child: KeyedSubtree(
                      key: _selectionAnchorKey(sectionKey, hero.name),
                      child: _buildDotaHeroTile(
                        hero,
                        selected: selectedHero == hero.name,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildDotaHeroTile(_AttributeOption hero, {required bool selected}) {
    final imageUrl = hero.imageUrl;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => _selectOption('hero', hero),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
              boxShadow: selected
                  ? const [
                      BoxShadow(color: Colors.white, spreadRadius: 2),
                      BoxShadow(
                        color: FilterSheetStyle.primaryBright,
                        spreadRadius: 4,
                      ),
                    ]
                  : const <BoxShadow>[],
            ),
            clipBehavior: Clip.antiAlias,
            child: imageUrl == null || imageUrl.isEmpty
                ? Builder(
                    builder: (context) {
                      _logDotaHeroImageIssue(
                        heroName: hero.name,
                        imageUrl: imageUrl,
                        reason: 'missing_url',
                      );
                      return _buildDotaHeroPlaceholder();
                    },
                  )
                : _buildDotaHeroImage(imageUrl: imageUrl, heroName: hero.name),
          ),
          const SizedBox(height: 4),
          Text(
            hero.label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected
                  ? FilterSheetStyle.primaryBright
                  : FilterSheetStyle.title,
              fontSize: 10,
              height: 12.5 / 10,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDotaHeroImage({
    required String imageUrl,
    required String heroName,
  }) {
    final devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
    const displaySize = 56.0;
    final cacheSize = (displaySize * devicePixelRatio).round();
    return Image.network(
      imageUrl,
      width: displaySize,
      height: displaySize,
      fit: BoxFit.cover,
      cacheWidth: cacheSize,
      cacheHeight: cacheSize,
      filterQuality: FilterQuality.medium,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded) {
          return child;
        }
        if (frame == null) {
          return const _DotaHeroLoadingPlaceholder();
        }
        return TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: 1),
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          child: child,
          builder: (context, opacity, loadedChild) {
            return Opacity(opacity: opacity, child: loadedChild);
          },
        );
      },
      errorBuilder: (context, error, stackTrace) {
        _logDotaHeroImageIssue(
          heroName: heroName,
          imageUrl: imageUrl,
          reason: error,
        );
        return _buildDotaHeroPlaceholder();
      },
    );
  }

  Widget _buildDotaHeroPlaceholder() {
    return const Icon(Icons.person, size: 26, color: Color(0xFF94A3B8));
  }

  void _logDotaHeroImageIssue({
    required String heroName,
    required String? imageUrl,
    required Object reason,
  }) {
    assert(() {
      final logKey =
          'hero=$heroName url=${imageUrl ?? '<empty>'} reason=$reason';
      if (_loggedDotaHeroImageIssues.add(logKey)) {
        AppLogger.debug('DOTA', logKey, scope: 'HERO_IMAGE');
      }
      return true;
    }());
  }

  Widget _buildDotaTagSection(
    List<_AttributeGroup> groups, {
    bool matchWeaponTypeStyle = false,
  }) {
    final options = <_GroupedOption>[];
    final seen = <String>{};
    for (final group in groups) {
      for (final option in _visibleOptions(group)) {
        final id = '${group.key}:${option.name}';
        if (seen.add(id)) {
          options.add(_GroupedOption(group.key, option));
        }
      }
    }
    final chips = [
      for (final item in options)
        matchWeaponTypeStyle
            ? _buildFigmaWeaponTypeChip(
                label: item.option.label.tr,
                selected: _selectedTags[item.groupKey] == item.option.name,
                onTap: () {
                  setState(() {
                    if (_selectedTags[item.groupKey] == item.option.name) {
                      _selectedTags.remove(item.groupKey);
                    } else {
                      _selectedTags[item.groupKey] = item.option.name;
                    }
                  });
                },
              )
            : FilterSheetOptionChip(
                label: item.option.label.tr,
                selected: _selectedTags[item.groupKey] == item.option.name,
                selectedStyle: FilterChipSelectedStyle.soft,
                selectedColor: const Color(0xFFD8E2FF),
                selectedBorderColor: Colors.transparent,
                selectedTextColor: const Color(0xFF001A42),
                unselectedColor: FilterSheetStyle.subtleBackground,
                unselectedBorderColor: Colors.transparent,
                unselectedTextColor: FilterSheetStyle.body,
                borderRadius: const BorderRadius.all(Radius.circular(12)),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                minHeight: 36,
                fontSize: 14,
                height: 20 / 14,
                selectedFontWeight: FontWeight.w500,
                unselectedFontWeight: FontWeight.w500,
                onTap: () {
                  setState(() {
                    if (_selectedTags[item.groupKey] == item.option.name) {
                      _selectedTags.remove(item.groupKey);
                    } else {
                      _selectedTags[item.groupKey] = item.option.name;
                    }
                  });
                },
              ),
    ];
    if (matchWeaponTypeStyle) {
      return _buildLeftAlignedChipWrap(chips);
    }
    return Wrap(spacing: 8, runSpacing: 8, children: chips);
  }

  Widget _buildDotaRaritySection(_AttributeGroup group) {
    return _buildDotaColorTileSection(group);
  }

  Widget _buildDotaQualitySection(_AttributeGroup group) {
    return _buildDotaColorTileSection(group);
  }

  Widget _buildDotaColorTileSection(_AttributeGroup group) {
    final options = _visibleOptions(group);
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 12.0;
        final itemWidth = (constraints.maxWidth - spacing) / 2;
        final selectedValues = _selectedValuesForGroup(group.key);
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final option in options)
              SizedBox(
                width: itemWidth,
                child: _buildDotaRarityTile(
                  groupKey: group.key,
                  option: option,
                  selected: selectedValues.contains(option.name),
                  onTap: () => _selectOption(group.key, option),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildDotaRarityTile({
    required String groupKey,
    required _AttributeOption option,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final accent = _dotaOptionColor(groupKey, option);
    return InkWell(
      borderRadius: BorderRadius.circular(4),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 13),
        decoration: BoxDecoration(
          color: selected ? const Color(0x80EFF6FF) : Colors.white,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: selected ? const Color(0xFFD8E2FF) : const Color(0xFFF1F5F9),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                option.label.tr,
                style: TextStyle(
                  color: selected
                      ? FilterSheetStyle.primaryBright
                      : FilterSheetStyle.title,
                  fontSize: 14,
                  height: 20 / 14,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDotaFallbackSection(_AttributeGroup group) {
    if (group.hasSubOptions) {
      return _buildSubOptionGroup(group);
    }
    return _buildDotaTagSection([
      group,
    ], matchWeaponTypeStyle: group.key == 'slot' || group.key == 'type');
  }

  Widget _buildDotaPriceSection() {
    final maxBound = _priceUpperBound();
    final range = _currentPriceRangeValues(maxBound);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPriceSlider(maxBound, range),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildPriceRangeTextField(
                controller: _minController,
                hintText: 'Min',
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: SizedBox(
                width: 16,
                child: Divider(
                  thickness: 1,
                  height: 1,
                  color: FilterSheetStyle.border,
                ),
              ),
            ),
            Expanded(
              child: _buildPriceRangeTextField(
                controller: _maxController,
                hintText: 'Max',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDotaSortSection() {
    final choices = _buildSortChoices();
    return Column(
      children: [
        for (var i = 0; i < choices.length; i++)
          FilterSheetRadioTile(
            label: choices[i].label,
            selected:
                _sortField == choices[i].field && _sortAsc == choices[i].asc,
            onTap: () {
              setState(() {
                _sortField = choices[i].field;
                _sortAsc = choices[i].asc;
              });
            },
            showDivider: i != choices.length - 1,
          ),
      ],
    );
  }

  String _dotaHeroSectionTitle(String labelKey) {
    switch (labelKey) {
      case 'app.market.dota2.hero_strength':
        return 'STRENGTH';
      case 'app.market.dota2.hero_agility':
        return 'AGILITY';
      case 'app.market.dota2.hero_intellect':
        return 'INTELLECT';
      case 'app.market.dota2.hero_all':
        return 'UNIVERSAL';
      default:
        return labelKey.tr.toUpperCase();
    }
  }

  _DotaSectionAccent _dotaHeroSectionAccent(String labelKey) {
    switch (labelKey) {
      case 'app.market.dota2.hero_strength':
        return const _DotaSectionAccent(
          icon: Icons.trip_origin_rounded,
          color: Color(0xFFEF4444),
        );
      case 'app.market.dota2.hero_agility':
        return const _DotaSectionAccent(
          icon: Icons.bolt_rounded,
          color: Color(0xFF10B981),
        );
      case 'app.market.dota2.hero_intellect':
        return const _DotaSectionAccent(
          icon: Icons.auto_awesome_rounded,
          color: Color(0xFF3B82F6),
        );
      default:
        return const _DotaSectionAccent(
          icon: Icons.change_history_rounded,
          color: Color(0xFF8B5CF6),
        );
    }
  }

  Color _dotaRarityColor(String name, String label) {
    final id = '${name.toLowerCase()} ${label.toLowerCase()}';
    if (id.contains('common')) {
      return const Color(0xFF8FB7D0);
    }
    if (id.contains('rare')) {
      return const Color(0xFF3F5BEB);
    }
    if (id.contains('uncommon')) {
      return const Color(0xFF5491CF);
    }
    if (id.contains('myth')) {
      return const Color(0xFF7644F0);
    }
    if (id.contains('immortal')) {
      return const Color(0xFFDBA833);
    }
    if (id.contains('legend')) {
      return const Color(0xFFCA2BDA);
    }
    if (id.contains('arcana')) {
      return const Color(0xFFA2DA4D);
    }
    if (id.contains('ancient')) {
      return const Color(0xFFE04740);
    }
    return FilterSheetStyle.primaryBright;
  }

  Color _dotaQualityColor(String name, String label) {
    final id = '${name.toLowerCase()} ${label.toLowerCase()}';
    if (id.contains('standard')) {
      return const Color(0xFFAAB6AE);
    }
    if (id.contains('genuine')) {
      return const Color(0xFF40664E);
    }
    if (id.contains('unusual')) {
      return const Color(0xFF744C97);
    }
    if (id.contains('inscribed')) {
      return const Color(0xFFC75C2D);
    }
    if (id.contains('corrupted')) {
      return const Color(0xFF9D2929);
    }
    if (id.contains('frozen')) {
      return const Color(0xFF3D769B);
    }
    if (id.contains('exalted')) {
      return const Color(0xFFA8B1A6);
    }
    if (id.contains('heroic')) {
      return const Color(0xFF704A97);
    }
    if (id.contains('autographed')) {
      return const Color(0xFFA3DE51);
    }
    if (id.contains('favored')) {
      return const Color(0xFFF4E213);
    }
    if (id.contains('auspicious')) {
      return const Color(0xFF30C42F);
    }
    if (id.contains('base')) {
      return const Color(0xFF7F827A);
    }
    if (id.contains('cursed')) {
      return const Color(0xFF6E479E);
    }
    if (id.contains('infused')) {
      return const Color(0xFF6F42F1);
    }
    if (id.contains('elder')) {
      return const Color(0xFF395380);
    }
    if (id.contains('glitter')) {
      return const Color(0xFF6FED77);
    }
    if (id.contains('gold')) {
      return const Color(0xFFE3B711);
    }
    if (id.contains('holo')) {
      return const Color(0xFF663EDD);
    }
    if (id.contains('legacy')) {
      return const Color(0xFFCED6C8);
    }
    if (id.contains('vintage')) {
      return const Color(0xFF476291);
    }
    if (id.contains('unique')) {
      return const Color(0xFFD2D23B);
    }
    if (id.contains('community')) {
      return const Color(0xFF70B04A);
    }
    if (id.contains('developer') || id.contains('valve')) {
      return const Color(0xFFA50F79);
    }
    if (id.contains('self-made') || id.contains('self made')) {
      return const Color(0xFF70B04A);
    }
    if (id.contains('haunted')) {
      return const Color(0xFF38A169);
    }
    return const Color(0xFFAAB6AE);
  }

  Color _dotaOptionColor(String groupKey, _AttributeOption option) {
    final apiColor = _parseOptionColor(option.color);
    if (apiColor != null) {
      return apiColor;
    }
    switch (groupKey) {
      case 'quality':
        return _dotaQualityColor(option.name, option.label);
      case 'rarity':
        return _dotaRarityColor(option.name, option.label);
      default:
        return FilterSheetStyle.primaryBright;
    }
  }

  Color? _parseOptionColor(String? color) {
    if (color == null) {
      return null;
    }
    final normalized = color.trim().replaceFirst('#', '');
    if (normalized.isEmpty) {
      return null;
    }
    final hex = normalized.length == 6 ? 'FF$normalized' : normalized;
    if (hex.length != 8) {
      return null;
    }
    final value = int.tryParse(hex, radix: 16);
    if (value == null) {
      return null;
    }
    return Color(value);
  }

  String _marketFilterOptionId(String name, String label) {
    return '${name.toLowerCase()} ${label.toLowerCase()}';
  }

  String _marketFilterOptionToken(String name, String label) {
    return _marketFilterOptionId(
      name,
      label,
    ).replaceAll(RegExp(r'[^a-z0-9★]+'), '');
  }

  String get _defaultFilterLabel => 'app.market.filter.default'.tr;

  bool _isDefaultSelectedForGroup(String key) {
    if (_isMultiSelectGroupKey(key)) {
      return (_selectedMultiTags[key] ?? const <String>[]).isEmpty;
    }
    return (_selectedTags[key] ?? '').trim().isEmpty;
  }

  bool _isDefaultExteriorSelected() {
    final hasExteriorTag = ((_selectedTags['exterior'] ?? '')
        .trim()
        .isNotEmpty);
    return !hasExteriorTag && _wearMin == null && _wearMax == null;
  }

  void _selectDefaultForGroup(String key) {
    setState(() {
      _selectedTags.remove(key);
      _selectedMultiTags.remove(key);
      if (key == 'type') {
        _selectedItemName = null;
      }
      if (key == 'exterior') {
        _wearMin = null;
        _wearMax = null;
      }
    });
  }

  Color _marketRarityLabelColor(String name, String label) {
    final id = _marketFilterOptionId(name, label);
    final token = _marketFilterOptionToken(name, label);
    if (id.contains('souvenir')) {
      return const Color(0xFFFFD700);
    }
    if (id.contains('★') || id.contains(' star')) {
      return const Color(0xFF8650AC);
    }
    if (id.contains('stattrak')) {
      return const Color(0xFFCF6A32);
    }
    if (id.contains('normal')) {
      return const Color(0xFF8A8D94);
    }
    if (id.contains('distinguished') ||
        id.contains('characterrarity') ||
        id.contains('character rarity')) {
      return const Color(0xFF4B69FF);
    }
    if (id.contains('superior')) {
      return const Color(0xFFD32CE6);
    }
    if (id.contains('exceptional')) {
      return const Color(0xFF8847FF);
    }
    if (id.contains('master')) {
      return const Color(0xFFEB4B4B);
    }
    if (id.contains('extraordinary') || token.contains('extraordinary')) {
      return const Color(0xFFEB4B4B);
    }
    if (id.contains('exotic') || token.contains('exotic')) {
      return const Color(0xFFD32CE6);
    }
    if (id.contains('remarkable') || token.contains('remarkable')) {
      return const Color(0xFF8847FF);
    }
    if (id.contains('high grade') || token.contains('highgrade')) {
      return const Color(0xFF4B69FF);
    }
    if (id.contains('covert')) {
      return const Color(0xFFEB4B4B);
    }
    if (id.contains('classified')) {
      return const Color(0xFFD32CE6);
    }
    if (id.contains('restricted')) {
      return const Color(0xFF8847FF);
    }
    if (id.contains('mil-spec') || id.contains('milspec')) {
      return const Color(0xFF4B69FF);
    }
    if (id.contains('industrial')) {
      return const Color(0xFF5E98D9);
    }
    if (id.contains('consumer') || id.contains('base grade')) {
      return const Color(0xFFB0C3D9);
    }
    if (id.contains('contraband')) {
      return const Color(0xFFE4AE39);
    }
    return FilterSheetStyle.body;
  }

  Color _marketCs2QualityColor(_AttributeOption option) {
    const colorsByName = <String, Color>{
      'normal': Color(0xFF6E6E6E),
      'tournament': Color(0xFFFFD700),
      'strange': Color(0xFFCF6A32),
      'unusual': Color(0xFF8650AC),
      'unusual_strange': Color(0xFF8650AC),
    };
    final exactColor = colorsByName[option.name.toLowerCase()];
    if (exactColor != null) {
      return exactColor;
    }
    final id = _marketFilterOptionId(option.name, option.label);
    if (id.contains('souvenir')) {
      return const Color(0xFFFFD700);
    }
    if (id.contains('★') || id.contains(' star')) {
      return const Color(0xFF8650AC);
    }
    if (id.contains('stattrak')) {
      return const Color(0xFFCF6A32);
    }
    if (id.contains('normal')) {
      return const Color(0xFF8A8C8D);
    }
    if (id.contains('distinguished')) {
      return const Color(0xFF4B69FF);
    }
    if (id.contains('exceptional')) {
      return const Color(0xFF8847FF);
    }
    if (id.contains('superior')) {
      return const Color(0xFFD32CE6);
    }
    if (id.contains('master')) {
      return const Color(0xFFEB4B4B);
    }
    return FilterSheetStyle.body;
  }

  Color _marketCs2CategoryColor(_AttributeOption option) {
    const colorsByName = <String, Color>{
      'rarity_common_weapon': Color(0xFFB0C3D9),
      'rarity_uncommon_weapon': Color(0xFF5E98D9),
      'rarity_rare_weapon': Color(0xFF4B69FF),
      'rarity_mythical_weapon': Color(0xFF8847FF),
      'rarity_legendary_weapon': Color(0xFFD32CE6),
      'rarity_ancient_weapon': Color(0xFFEB4B4B),
      'rarity_common': Color(0xFFB0C3D9),
      'rarity_rare': Color(0xFF4B69FF),
      'rarity_mythical': Color(0xFF8847FF),
      'rarity_legendary': Color(0xFFD32CE6),
      'rarity_ancient': Color(0xFFEB4B4B),
      'rarity_rare_character': Color(0xFF4B69FF),
      'rarity_mythical_character': Color(0xFF8847FF),
      'rarity_legendary_character': Color(0xFFD32CE6),
      'rarity_ancient_character': Color(0xFFEB4B4B),
      'rarity_contraband': Color(0xFFE4AE39),
    };
    final exactColor = colorsByName[option.name.toLowerCase()];
    if (exactColor != null) {
      return exactColor;
    }
    final id = _marketFilterOptionId(option.name, option.label);
    final token = _marketFilterOptionToken(option.name, option.label);
    if (id.contains('consumer') || id.contains('base grade')) {
      return const Color(0xFFB0C3D9);
    }
    if (id.contains('industrial')) {
      return const Color(0xFF5E98D9);
    }
    if (id.contains('mil-spec') ||
        id.contains('milspec') ||
        id.contains('high grade') ||
        token.contains('highgrade') ||
        id.contains('characterrarity') ||
        id.contains('character rarity')) {
      return const Color(0xFF4B69FF);
    }
    if (id.contains('restricted') ||
        id.contains('remarkable') ||
        token.contains('remarkable')) {
      return const Color(0xFF8847FF);
    }
    if (id.contains('classified') ||
        id.contains('exotic') ||
        token.contains('exotic')) {
      return const Color(0xFFD32CE6);
    }
    if (id.contains('covert') ||
        id.contains('extraordinary') ||
        token.contains('extraordinary')) {
      return const Color(0xFFEB4B4B);
    }
    if (id.contains('contraband')) {
      return const Color(0xFFE4AE39);
    }
    return FilterSheetStyle.body;
  }

  Color _marketExteriorLabelColor(_AttributeOption option) {
    final id = _marketFilterOptionId(option.name, option.label);
    if (id.contains('factory new')) {
      return const Color(0xFF2A6839);
    }
    if (id.contains('minimal wear')) {
      return const Color(0xFF18A618);
    }
    if (id.contains('field-tested') || id.contains('field tested')) {
      return const Color(0xFF99CC50);
    }
    if (id.contains('well-worn') || id.contains('well worn')) {
      return const Color(0xFFCD5D5D);
    }
    if (id.contains('battle-scarred') || id.contains('battle scarred')) {
      return const Color(0xFFF22E2E);
    }
    if (id.contains('not painted')) {
      return const Color(0xFF8A8C8D);
    }
    return FilterSheetStyle.body;
  }

  Widget _buildRaritySectionContent(_AttributeGroup group) {
    final options = _visibleOptions(group);
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 12.0;
        final itemWidth = (constraints.maxWidth - spacing) / 2;
        final selectedValues = _selectedValuesForGroup(group.key);
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            SizedBox(
              width: itemWidth,
              child: FilterSheetCheckboxTile(
                label: _defaultFilterLabel,
                selected: selectedValues.isEmpty,
                onTap: () => _selectDefaultForGroup(group.key),
              ),
            ),
            for (final option in options)
              () {
                final isCs2Category =
                    widget.appId == 730 && group.key == 'rarity';
                final accent = isCs2Category
                    ? _marketCs2CategoryColor(option)
                    : _marketRarityLabelColor(option.name, option.label);
                return SizedBox(
                  width: itemWidth,
                  child: FilterSheetCheckboxTile(
                    label: option.label.tr,
                    selected: selectedValues.contains(option.name),
                    onTap: () => _selectOption(group.key, option),
                    labelColor: accent,
                    selectedLabelColor: accent,
                    unselectedLabelColor: accent,
                  ),
                );
              }(),
          ],
        );
      },
    );
  }

  Widget _buildWearConditionSectionContent(_AttributeGroup group) {
    final range = _currentWearRange();
    final presets = _buildWearPresets(group);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            '${_formatWearValue(range.start)} - '
            '${_formatWearValue(range.end)}',
            style: const TextStyle(
              color: FilterSheetStyle.primary,
              fontSize: 14,
              height: 20 / 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 12),
        _buildWearScale(range, group),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilterSheetOptionChip(
              label: _defaultFilterLabel,
              selected: _isDefaultExteriorSelected(),
              selectedStyle: FilterChipSelectedStyle.soft,
              unselectedColor: const Color(0xFFECEEF0),
              unselectedBorderColor: Colors.transparent,
              selectedColor: FilterSheetStyle.selectedSoft,
              selectedBorderColor: FilterSheetStyle.selectedSoftBorder,
              selectedTextColor: FilterSheetStyle.primary,
              unselectedTextColor: FilterSheetStyle.body,
              borderRadius: FilterSheetStyle.chipRadius,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              minHeight: 36,
              fontSize: 12,
              height: 18 / 12,
              onTap: () => _selectDefaultForGroup(group.key),
            ),
            for (final preset in presets)
              () {
                final labelColor = _marketExteriorLabelColor(preset.option);
                return FilterSheetOptionChip(
                  label: preset.option.label.tr,
                  selected: _isWearPresetActive(preset, range),
                  selectedStyle: FilterChipSelectedStyle.soft,
                  unselectedColor: labelColor.withValues(alpha: 0.04),
                  unselectedBorderColor: labelColor.withValues(alpha: 0.14),
                  selectedColor: labelColor.withValues(alpha: 0.10),
                  selectedBorderColor: labelColor.withValues(alpha: 0.30),
                  selectedTextColor: labelColor,
                  unselectedTextColor: labelColor,
                  borderRadius: FilterSheetStyle.chipRadius,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 9,
                  ),
                  minHeight: 36,
                  fontSize: 12,
                  height: 18 / 12,
                  onTap: () => _applyWearPreset(group, preset),
                );
              }(),
          ],
        ),
      ],
    );
  }

  Widget _buildCategorySectionContent(
    _AttributeGroup group, {
    bool useQualityColors = false,
  }) {
    final options = _visibleOptions(group);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FilterSheetOptionChip(
          label: _defaultFilterLabel,
          selected: _isDefaultSelectedForGroup(group.key),
          selectedStyle: FilterChipSelectedStyle.soft,
          selectedColor: useQualityColors
              ? FilterSheetStyle.selectedSoft
              : Colors.transparent,
          selectedBorderColor: useQualityColors
              ? FilterSheetStyle.selectedSoftBorder
              : const Color(0xFFFF9500),
          selectedTextColor: useQualityColors
              ? FilterSheetStyle.primary
              : const Color(0xFFFF9500),
          unselectedColor: useQualityColors
              ? const Color(0xFFF5F6F7)
              : Colors.transparent,
          unselectedBorderColor: useQualityColors
              ? const Color(0xFFD8DDE3)
              : FilterSheetStyle.border,
          unselectedTextColor: FilterSheetStyle.body,
          borderRadius: const BorderRadius.all(Radius.circular(4)),
          padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 9),
          minHeight: 40,
          fontSize: 14,
          height: 21 / 14,
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x0D000000),
              blurRadius: 2,
              offset: Offset(0, 1),
            ),
          ],
          onTap: () => _selectDefaultForGroup(group.key),
        ),
        for (final option in options)
          () {
            final qualityColor = useQualityColors
                ? (widget.appId == 730 && group.key == 'quality'
                      ? _marketCs2QualityColor(option)
                      : _marketCs2CategoryColor(option))
                : null;
            final selectedColor = qualityColor?.withValues(alpha: 0.08);
            final selectedBorderColor = qualityColor?.withValues(alpha: 0.28);
            final unselectedColor = qualityColor?.withValues(alpha: 0.03);
            final unselectedBorderColor = qualityColor?.withValues(alpha: 0.12);
            return FilterSheetOptionChip(
              label: option.label.tr,
              selected: _selectedTags[group.key] == option.name,
              selectedStyle: FilterChipSelectedStyle.soft,
              selectedColor: useQualityColors
                  ? selectedColor
                  : Colors.transparent,
              selectedBorderColor: useQualityColors
                  ? selectedBorderColor
                  : const Color(0xFFFF9500),
              selectedTextColor: useQualityColors
                  ? qualityColor
                  : const Color(0xFFFF9500),
              unselectedColor: useQualityColors
                  ? unselectedColor
                  : Colors.transparent,
              unselectedBorderColor: useQualityColors
                  ? unselectedBorderColor
                  : FilterSheetStyle.border,
              unselectedTextColor: useQualityColors
                  ? qualityColor
                  : FilterSheetStyle.body,
              borderRadius: const BorderRadius.all(Radius.circular(4)),
              padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 9),
              minHeight: 40,
              fontSize: 14,
              height: 21 / 14,
              boxShadow: const <BoxShadow>[
                BoxShadow(
                  color: Color(0x0D000000),
                  blurRadius: 2,
                  offset: Offset(0, 1),
                ),
              ],
              onTap: () {
                setState(() {
                  if (_selectedTags[group.key] == option.name) {
                    _selectedTags.remove(group.key);
                  } else {
                    _selectedTags[group.key] = option.name;
                  }
                });
              },
            );
          }(),
      ],
    );
  }

  Widget _buildFallbackGroupSectionContent(_AttributeGroup group) {
    if (group.isHeroGroup) {
      return _buildHeroGroupSectionContent(group);
    }
    if (group.hasSubOptions) {
      return _buildSubOptionGroup(group);
    }
    return _buildPlainChipWrap(
      options: _visibleOptions(group),
      isSelected: (option) => _isGroupSelected(group.key, option),
      onTap: (option) => _selectOption(group.key, option),
      selectedStyle: FilterChipSelectedStyle.soft,
      selectedColor: FilterSheetStyle.selectedSoft,
      selectedBorderColor: FilterSheetStyle.selectedSoftBorder,
      selectedTextColor: FilterSheetStyle.primary,
      unselectedColor: const Color(0xFFECEEF0),
      unselectedBorderColor: Colors.transparent,
      unselectedTextColor: FilterSheetStyle.body,
      fontSize: 13,
      minHeight: 36,
      borderRadius: FilterSheetStyle.chipRadius,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
    );
  }

  Widget _buildLeftAlignedChipWrap(List<Widget> children) {
    return SizedBox(
      width: double.infinity,
      child: Wrap(
        alignment: WrapAlignment.start,
        spacing: 8,
        runSpacing: 8,
        children: children,
      ),
    );
  }

  Widget _buildChip(
    String label, {
    required bool selected,
    required ValueChanged<bool> onSelected,
    bool fullWidth = false,
    Key? chipKey,
  }) {
    final chip = KeyedSubtree(
      key: chipKey,
      child: FilterSheetOptionChip(
        label: label,
        selected: selected,
        fullWidth: fullWidth,
        onTap: () => onSelected(!selected),
      ),
    );
    if (!fullWidth) {
      return chip;
    }
    return chip;
  }

  Widget _buildCompactGrid({
    required int itemCount,
    required Widget Function(int index) itemBuilder,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 6.0;
        const crossAxisCount = 2;
        final totalSpacing = spacing * (crossAxisCount - 1);
        final rawItemWidth =
            (constraints.maxWidth - totalSpacing) / crossAxisCount;
        // Use floor width to avoid sub-pixel rounding clipping on some devices.
        final itemWidth = math.max(0.0, rawItemWidth.floorToDouble());
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: List.generate(
            itemCount,
            (index) => SizedBox(width: itemWidth, child: itemBuilder(index)),
          ),
        );
      },
    );
  }

  Widget _buildOptionGrid({
    required String sectionKey,
    required List<_AttributeOption> options,
    required bool Function(_AttributeOption option) isSelected,
    required ValueChanged<_AttributeOption> onSelected,
  }) {
    return _buildCompactGrid(
      itemCount: options.length,
      itemBuilder: (index) {
        final option = options[index];
        return _buildChip(
          option.label.tr,
          selected: isSelected(option),
          onSelected: (_) => onSelected(option),
          fullWidth: true,
          chipKey: _selectionAnchorKey(sectionKey, option.name),
        );
      },
    );
  }

  Widget _buildSortSectionContent() {
    final choices = _buildSortChoices();
    return Column(
      children: [
        for (var i = 0; i < choices.length; i++)
          FilterSheetRadioTile(
            label: choices[i].label,
            selected:
                _sortField == choices[i].field && _sortAsc == choices[i].asc,
            onTap: () {
              setState(() {
                _sortField = choices[i].field;
                _sortAsc = choices[i].asc;
              });
            },
            showDivider: i != choices.length - 1,
          ),
      ],
    );
  }

  List<_SortChoice> _buildSortChoices() {
    if (_isDota) {
      return _buildDotaSortChoices();
    }
    final choices = <_SortChoice>[];
    final seenStates = <String>{};

    void push(_SortChoice choice) {
      final stateKey = '${choice.field}:${choice.asc}';
      if (seenStates.add(stateKey)) {
        choices.add(choice);
      }
    }

    if (widget.includeDefaultSortOption) {
      push(
        _SortChoice(
          field: _defaultSortField(),
          asc: _defaultSortAsc(),
          label: 'app.market.filter.default'.tr,
        ),
      );
    }

    final hasPrice = widget.sortOptions.any(
      (option) => option.field == 'price',
    );
    if (hasPrice) {
      push(
        _SortChoice(
          field: 'price',
          asc: true,
          label: _localizedPriceSortLabel(asc: true),
        ),
      );
      push(
        _SortChoice(
          field: 'price',
          asc: false,
          label: _localizedPriceSortLabel(asc: false),
        ),
      );
    }

    for (final option in widget.sortOptions) {
      switch (option.field) {
        case 'price':
          continue;
        case 'hot':
          push(
            _SortChoice(
              field: option.field,
              asc: false,
              label: _localizedHotSortLabel(option),
            ),
          );
          continue;
        case 'time':
        case 'upTime':
          push(
            _SortChoice(
              field: option.field,
              asc: false,
              label: _localizedTimeSortLabel(option, asc: false),
            ),
          );
          push(
            _SortChoice(
              field: option.field,
              asc: true,
              label: _localizedTimeSortLabel(option, asc: true),
            ),
          );
          continue;
        case 'paintWear':
        case 'float':
          push(
            _SortChoice(
              field: option.field,
              asc: true,
              label: _localizedWearSortLabel(option, asc: true),
            ),
          );
          push(
            _SortChoice(
              field: option.field,
              asc: false,
              label: _localizedWearSortLabel(option, asc: false),
            ),
          );
          continue;
        default:
          push(
            _SortChoice(
              field: option.field,
              asc: false,
              label: option.labelKey.tr,
            ),
          );
      }
    }

    if (choices.isEmpty) {
      choices.add(
        _SortChoice(
          field: _sortField,
          asc: _sortAsc,
          label: 'app.market.filter.default'.tr,
        ),
      );
    }
    return choices;
  }

  List<_SortChoice> _buildDotaSortChoices() {
    final choices = <_SortChoice>[];
    final fields = <String>{
      for (final option in widget.sortOptions) option.field,
    };
    final seenStates = <String>{};

    void push(_SortChoice choice) {
      final stateKey = '${choice.field}:${choice.asc}';
      if (seenStates.add(stateKey)) {
        choices.add(choice);
      }
    }

    void addDirectionalChoice({
      required String field,
      required String labelKey,
    }) {
      if (!fields.contains(field)) {
        return;
      }
      for (final asc in <bool>[false, true]) {
        push(
          _SortChoice(
            field: field,
            asc: asc,
            label: _localizedDirectionalSortLabel(labelKey, asc: asc),
          ),
        );
      }
    }

    push(
      _SortChoice(
        field: _defaultSortField(),
        asc: _defaultSortAsc(),
        label: 'app.market.filter.default'.tr,
      ),
    );

    if (fields.contains('time')) {
      addDirectionalChoice(field: 'time', labelKey: 'app.market.filter.time');
    } else if (fields.contains('upTime')) {
      addDirectionalChoice(field: 'upTime', labelKey: 'app.market.filter.time');
    }
    addDirectionalChoice(field: 'hot', labelKey: 'app.market.filter.hot');
    addDirectionalChoice(field: 'price', labelKey: 'app.market.filter.price');

    if (choices.isEmpty) {
      choices.add(
        _SortChoice(
          field: _sortField,
          asc: _sortAsc,
          label: 'app.market.filter.default'.tr,
        ),
      );
    }

    return choices;
  }

  String _defaultSortField() {
    return '';
  }

  bool _defaultSortAsc() => false;

  Widget _buildPriceSectionContent() {
    if (_isLegacyTfPriceOnly) {
      return _buildLegacyTfPriceSectionContent();
    }
    final maxBound = _priceUpperBound();
    final range = _currentPriceRangeValues(maxBound);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPriceSlider(maxBound, range),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildPriceRangeTextField(
                controller: _minController,
                hintText: 'Min',
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: SizedBox(
                width: 16,
                child: Divider(
                  thickness: 1,
                  height: 1,
                  color: FilterSheetStyle.border,
                ),
              ),
            ),
            Expanded(
              child: _buildPriceRangeTextField(
                controller: _maxController,
                hintText: 'Max',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLegacyTfPriceSectionContent() {
    final maxBound = _priceUpperBound();
    final range = _currentPriceRangeValues(maxBound);
    final presets = _buildTfPricePresets();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPriceSlider(maxBound, range),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: _buildLegacyTfPriceField(
                controller: _minController,
                hintText: 'Min',
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: SizedBox(
                width: 16,
                child: Divider(
                  thickness: 1,
                  height: 1,
                  color: FilterSheetStyle.border,
                ),
              ),
            ),
            Expanded(
              child: _buildLegacyTfPriceField(
                controller: _maxController,
                hintText: 'Max',
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        LayoutBuilder(
          builder: (context, constraints) {
            const spacing = 8.0;
            final itemWidth = (constraints.maxWidth - (spacing * 2)) / 3;
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                for (final preset in presets)
                  SizedBox(
                    width: itemWidth,
                    child: _buildLegacyTfPricePresetChip(
                      label: preset.label,
                      selected: _matchesLegacyTfPreset(
                        maxBound,
                        minUsd: preset.minUsd,
                        maxUsd: preset.maxUsd,
                      ),
                      onTap: () => _applyLegacyTfPricePreset(
                        maxBound,
                        minUsd: preset.minUsd,
                        maxUsd: preset.maxUsd,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildLegacyTfPriceField({
    required TextEditingController controller,
    required String hintText,
  }) {
    return _buildPriceRangeTextField(
      controller: controller,
      hintText: hintText,
    );
  }

  Widget _buildPriceRangeTextField({
    required TextEditingController controller,
    required String hintText,
  }) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textAlignVertical: TextAlignVertical.center,
      onChanged: (_) => setState(() {}),
      decoration: FilterSheetStyle.inputDecoration(hintText: hintText).copyWith(
        prefixText: null,
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        prefixIcon: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 8, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            widthFactor: 1,
            child: Text(
              _currency.symbol,
              style: const TextStyle(
                color: FilterSheetStyle.body,
                fontSize: 14,
                height: 20 / 14,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ),
      ),
      style: const TextStyle(
        color: FilterSheetStyle.title,
        fontSize: 14,
        height: 20 / 14,
        fontWeight: FontWeight.w400,
      ),
    );
  }

  Widget _buildLegacyTfPricePresetChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return FilterSheetOptionChip(
      label: label,
      selected: selected,
      selectedStyle: FilterChipSelectedStyle.solid,
      selectedColor: FilterSheetStyle.priceAccent,
      selectedBorderColor: FilterSheetStyle.priceAccent,
      selectedTextColor: Colors.white,
      unselectedColor: Colors.white,
      unselectedBorderColor: FilterSheetStyle.border,
      unselectedTextColor: FilterSheetStyle.title,
      borderRadius: FilterSheetStyle.chipRadius,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 11),
      minHeight: 42,
      fontSize: 12,
      height: 18 / 12,
      selectedFontWeight: FontWeight.w500,
      unselectedFontWeight: FontWeight.w500,
      fullWidth: true,
      maxLines: 1,
      onTap: onTap,
    );
  }

  bool _matchesLegacyTfPreset(
    double maxBound, {
    required double? minUsd,
    required double? maxUsd,
  }) {
    final currentMin = _parseDisplayPriceOrNull(_minController.text);
    final currentMax = _parseDisplayPriceOrNull(_maxController.text);
    final normalizedMinUsd = (minUsd == null || minUsd <= 0) ? null : minUsd;
    final minMatches = normalizedMinUsd == null
        ? currentMin == null || currentMin <= 0
        : currentMin != null && (currentMin - normalizedMinUsd).abs() < 0.01;
    final expectedOpenMax = maxUsd == null || maxUsd >= maxBound;
    final maxMatches = expectedOpenMax
        ? currentMax == null || currentMax >= maxBound
        : currentMax != null && (currentMax - maxUsd).abs() < 0.01;
    return minMatches && maxMatches;
  }

  void _applyLegacyTfPricePreset(
    double maxBound, {
    required double? minUsd,
    required double? maxUsd,
  }) {
    setState(() {
      _minController.text = minUsd == null || minUsd <= 0
          ? ''
          : _initialPriceText(minUsd);
      _maxController.text = maxUsd == null || maxUsd >= maxBound
          ? ''
          : _initialPriceText(maxUsd);
    });
  }

  List<_TfPricePreset> _buildTfPricePresets() {
    return <_TfPricePreset>[
      _TfPricePreset(
        minUsd: null,
        maxUsd: 500,
        label: _buildCompactTfPresetLabel(maxUsd: 500),
      ),
      _TfPricePreset(
        minUsd: 501,
        maxUsd: 5000,
        label: _buildCompactTfPresetLabel(minUsd: 501, maxUsd: 5000),
      ),
      _TfPricePreset(
        minUsd: 5000,
        maxUsd: null,
        label: _buildCompactTfPresetLabel(minUsd: 5000),
      ),
    ];
  }

  String _buildCompactTfPresetLabel({double? minUsd, double? maxUsd}) {
    int toDisplay(double usdValue) =>
        FilterPriceSupport.usdToDisplay(_currency, usdValue).round();
    final symbol = _currency.symbol;
    if (minUsd == null && maxUsd != null) {
      return '<$symbol${toDisplay(maxUsd)}';
    }
    if (minUsd != null && maxUsd == null) {
      return '$symbol${toDisplay(minUsd)}+';
    }
    if (minUsd != null && maxUsd != null) {
      return '$symbol${toDisplay(minUsd)}-$symbol${toDisplay(maxUsd)}';
    }
    return symbol;
  }

  Widget _buildPriceSlider(double maxBound, RangeValues range) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = math.max(0.0, constraints.maxWidth - 28);
        final startLabel = _formatDisplayPrice(range.start);
        final endLabel = _formatDisplayPrice(range.end);
        final startLeft = _sliderLabelOffset(
          value: range.start,
          maxValue: maxBound,
          width: availableWidth,
          labelWidth: _measurePriceLabelWidth(startLabel),
        );
        final endLeft = _sliderLabelOffset(
          value: range.end,
          maxValue: maxBound,
          width: availableWidth,
          labelWidth: _measurePriceLabelWidth(endLabel),
        );
        return SizedBox(
          height: 62,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: startLeft,
                top: 0,
                child: _buildSliderValuePill(startLabel),
              ),
              Positioned(
                left: endLeft,
                top: 0,
                child: _buildSliderValuePill(endLabel),
              ),
              Positioned.fill(
                top: 18,
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 4,
                    activeTrackColor: FilterSheetStyle.priceAccent,
                    inactiveTrackColor: const Color(0xFFE0E3E5),
                    overlayShape: SliderComponentShape.noOverlay,
                    rangeThumbShape: const RoundRangeSliderThumbShape(
                      enabledThumbRadius: 8,
                    ),
                    thumbColor: Colors.white,
                    activeTickMarkColor: Colors.transparent,
                    inactiveTickMarkColor: Colors.transparent,
                  ),
                  child: RangeSlider(
                    values: range,
                    min: 0,
                    max: maxBound,
                    divisions: 100,
                    onChanged: (values) => _updatePriceRange(values, maxBound),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSliderValuePill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: FilterSheetStyle.priceAccent,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          height: 15 / 10,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  double _sliderLabelOffset({
    required double value,
    required double maxValue,
    required double width,
    required double labelWidth,
  }) {
    if (maxValue <= 0) {
      return 0;
    }
    final ratio = (value / maxValue).clamp(0.0, 1.0);
    final raw = ratio * width;
    final maxLeft = math.max(0.0, width - labelWidth);
    return raw.clamp(0.0, maxLeft);
  }

  double _priceUpperBound() {
    if (_isLegacyTfPriceOnly) {
      final values = <double>[
        widget.initial.priceMin ?? 0,
        widget.initial.priceMax ?? 0,
        _parseDisplayPriceOrZero(_minController.text),
        _parseDisplayPriceOrZero(_maxController.text),
        5000,
      ]..sort();
      final currentMax = values.isEmpty ? 5000 : values.last;
      if (currentMax <= 5000) {
        return 5000;
      }
      if (currentMax <= 10000) {
        return 10000;
      }
      return (currentMax / 1000).ceil() * 1000;
    }
    final values = <double>[
      widget.initial.priceMin ?? 0,
      widget.initial.priceMax ?? 0,
      _parseDisplayPriceOrZero(_minController.text),
      _parseDisplayPriceOrZero(_maxController.text),
    ]..sort();
    final currentMax = values.isEmpty ? 0 : values.last;
    if (currentMax <= 1000) {
      return 1000;
    }
    if (currentMax <= 5000) {
      return 5000;
    }
    if (currentMax <= 10000) {
      return 10000;
    }
    return (currentMax / 1000).ceil() * 1000;
  }

  RangeValues _currentPriceRangeValues(double maxBound) {
    final parsedMin = _parseDisplayPriceOrZero(
      _minController.text,
    ).clamp(0.0, maxBound);
    final parsedMax =
        (_maxController.text.trim().isEmpty
                ? maxBound
                : _parseDisplayPriceOrZero(_maxController.text))
            .clamp(0.0, maxBound);
    final start = math.min(parsedMin, parsedMax);
    final end = math.max(parsedMin, parsedMax);
    return RangeValues(start, end);
  }

  void _updatePriceRange(RangeValues values, double maxBound) {
    final start = values.start.clamp(0.0, maxBound);
    final end = values.end.clamp(0.0, maxBound);
    setState(() {
      _minController.text = start <= 0 ? '' : _initialPriceText(start);
      _maxController.text = end >= maxBound ? '' : _initialPriceText(end);
    });
  }

  String _localizedPriceSortLabel({required bool asc}) {
    if (widget.useCompactSortLabels) {
      return '${'app.market.filter.price'.tr} ${asc ? '↑' : '↓'}';
    }
    if (Get.locale?.languageCode == 'en') {
      return asc ? 'Price Low to High' : 'Price High to Low';
    }
    return '${'app.market.filter.price'.tr} ${asc ? '↑' : '↓'}';
  }

  String _localizedDirectionalSortLabel(String labelKey, {required bool asc}) {
    if (widget.useCompactSortLabels) {
      return '${labelKey.tr} ${asc ? '↑' : '↓'}';
    }
    if (Get.locale?.languageCode == 'en') {
      final base = labelKey.tr;
      return asc ? '$base Low to High' : '$base High to Low';
    }
    return '${labelKey.tr} ${asc ? '低到高' : '高到低'}';
  }

  String _localizedTimeSortLabel(SortOption option, {required bool asc}) {
    if (widget.useCompactSortLabels) {
      return '${option.labelKey.tr} ${asc ? '↑' : '↓'}';
    }
    if (Get.locale?.languageCode == 'en') {
      return asc ? 'Oldest Listed' : 'Newest Listed';
    }
    return '${option.labelKey.tr} ${asc ? '↑' : '↓'}';
  }

  String _localizedHotSortLabel(SortOption option) {
    if (Get.locale?.languageCode == 'en') {
      return 'Most Popular';
    }
    return option.labelKey.tr;
  }

  String _localizedWearSortLabel(SortOption option, {required bool asc}) {
    if (widget.useCompactSortLabels) {
      return '${option.labelKey.tr} ${asc ? '↑' : '↓'}';
    }
    if (Get.locale?.languageCode == 'en') {
      return asc ? 'Float Low to High' : 'Float High to Low';
    }
    return '${option.labelKey.tr} ${asc ? '↑' : '↓'}';
  }

  List<_AttributeGroup> _orderedMarketGroups() {
    final preferredOrder = widget.attributeGroupOrder.isNotEmpty
        ? widget.attributeGroupOrder
        : const ['type', 'exterior', 'rarity', 'quality', 'itemSet'];
    final renderedKeys = <String>{};
    final ordered = <_AttributeGroup>[];

    for (final key in preferredOrder) {
      final group = _findGroup(key);
      if (group == null || !renderedKeys.add(group.key)) {
        continue;
      }
      ordered.add(group);
    }

    if (widget.includeFallbackAttributeGroups) {
      for (final group in _groups) {
        if (renderedKeys.add(group.key)) {
          ordered.add(group);
        }
      }
    }

    return ordered;
  }

  Widget _buildMarketGroupSection(_AttributeGroup group) {
    switch (group.key) {
      case 'type':
        return _buildAccordionSection(
          sectionKey: group.key,
          title: group.label.tr,
          contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: _buildWeaponTypeSectionContent(group),
        );
      case 'exterior':
        return _buildAccordionSection(
          sectionKey: group.key,
          title: group.label.tr,
          contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: _buildWearConditionSectionContent(group),
        );
      case 'quality':
        return _buildAccordionSection(
          sectionKey: group.key,
          title: group.label.tr,
          contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: _buildCategorySectionContent(group, useQualityColors: true),
        );
      case 'rarity':
        return _buildAccordionSection(
          sectionKey: group.key,
          title: group.label.tr,
          contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: _buildRaritySectionContent(group),
        );
      case 'itemSet':
        return _buildAccordionSection(
          sectionKey: group.key,
          title: group.label.tr,
          contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: _buildCategorySectionContent(group),
        );
      default:
        return _buildAccordionSection(
          sectionKey: group.key,
          title: group.label.tr,
          contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: _buildFallbackGroupSectionContent(group),
        );
    }
  }

  RangeValues? _wearRangeForName(String name) {
    switch (name) {
      case 'WearCategory0':
        return const RangeValues(0.00, 0.07);
      case 'WearCategory1':
        return const RangeValues(0.07, 0.15);
      case 'WearCategory2':
        return const RangeValues(0.15, 0.38);
      case 'WearCategory3':
        return const RangeValues(0.38, 0.45);
      case 'WearCategory4':
        return const RangeValues(0.45, 1.00);
      default:
        return null;
    }
  }

  RangeValues _currentWearRange() {
    final start = (_wearMin ?? 0).clamp(0.0, 1.0);
    final end = (_wearMax ?? 1).clamp(0.0, 1.0);
    return RangeValues(math.min(start, end), math.max(start, end));
  }

  List<_WearPreset> _buildWearPresets(_AttributeGroup group) {
    return _visibleOptions(group)
        .map((option) {
          final range = _wearRangeForName(option.name);
          if (range == null) {
            return null;
          }
          return _WearPreset(option: option, min: range.start, max: range.end);
        })
        .whereType<_WearPreset>()
        .toList(growable: false);
  }

  bool _isWearPresetActive(_WearPreset preset, RangeValues range) {
    if (_isDefaultExteriorSelected()) {
      return false;
    }
    if (_selectedTags['exterior'] == preset.option.name) {
      return true;
    }
    return range.end > preset.min && range.start < preset.max;
  }

  void _applyWearPreset(_AttributeGroup group, _WearPreset preset) {
    setState(() {
      _selectedTags[group.key] = preset.option.name;
      _wearMin = preset.min;
      _wearMax = preset.max;
    });
  }

  void _updateWearRange(_AttributeGroup group, RangeValues values) {
    final normalized = RangeValues(
      _roundWear(values.start.clamp(0.0, 1.0)),
      _roundWear(values.end.clamp(0.0, 1.0)),
    );
    final isFullRange =
        normalized.start <= 0.0 + 0.001 && normalized.end >= 1.0 - 0.001;
    String? exactMatch;
    for (final preset in _buildWearPresets(group)) {
      if ((preset.min - normalized.start).abs() < 0.001 &&
          (preset.max - normalized.end).abs() < 0.001) {
        exactMatch = preset.option.name;
        break;
      }
    }
    setState(() {
      _wearMin = isFullRange ? null : normalized.start;
      _wearMax = isFullRange ? null : normalized.end;
      if (exactMatch == null) {
        _selectedTags.remove(group.key);
      } else {
        _selectedTags[group.key] = exactMatch;
      }
    });
  }

  double _roundWear(double value) {
    return (value * 100).roundToDouble() / 100;
  }

  String _formatWearValue(double value) {
    return value.toStringAsFixed(2);
  }

  Widget _buildWearScale(RangeValues range, _AttributeGroup group) {
    const markers = <double>[0.00, 0.07, 0.15, 0.38, 0.45, 1.00];
    const segmentColors = <Color>[
      Color(0xFFDBEAFE),
      Color(0xFF93C5FD),
      Color(0xFF3B82F6),
      Color(0xFF1D4ED8),
      Color(0xFF1E3A8A),
    ];
    return SizedBox(
      height: 58,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final marker in markers)
                  Text(
                    _formatWearValue(marker),
                    style: const TextStyle(
                      color: FilterSheetStyle.body,
                      fontSize: 10,
                      height: 15 / 10,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 24,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: Row(
                children: [
                  for (var i = 0; i < segmentColors.length; i++)
                    Expanded(
                      flex: ((markers[i + 1] - markers[i]) * 1000).round(),
                      child: Container(height: 6, color: segmentColors[i]),
                    ),
                ],
              ),
            ),
          ),
          Positioned(
            left: -6,
            right: -6,
            top: 15,
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 6,
                activeTrackColor: Colors.transparent,
                inactiveTrackColor: Colors.transparent,
                overlayShape: SliderComponentShape.noOverlay,
                rangeThumbShape: const RoundRangeSliderThumbShape(
                  enabledThumbRadius: 8,
                ),
                thumbColor: Colors.white,
                overlappingShapeStrokeColor: FilterSheetStyle.priceAccent,
                activeTickMarkColor: Colors.transparent,
                inactiveTickMarkColor: Colors.transparent,
              ),
              child: RangeSlider(
                values: range,
                min: 0,
                max: 1,
                divisions: 100,
                onChanged: (values) => _updateWearRange(group, values),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusSectionContent() {
    return _buildCompactGrid(
      itemCount: widget.statusOptions.length,
      itemBuilder: (index) {
        final option = widget.statusOptions[index];
        final selected = _selectedStatusIndex == index;
        return _buildChip(
          option.labelKey.tr,
          selected: selected,
          fullWidth: true,
          onSelected: (value) {
            setState(() {
              _selectedStatusIndex = value ? index : -1;
            });
          },
        );
      },
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) {
      return '-';
    }
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _pickStartDate() async {
    final now = DateTime.now();
    final result = await showDatePicker(
      context: context,
      initialDate: _startDate ?? now,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 1),
    );
    if (result != null) {
      setState(() => _startDate = result);
    }
  }

  Future<void> _pickEndDate() async {
    final now = DateTime.now();
    final result = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate ?? now,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 1),
    );
    if (result != null) {
      setState(() => _endDate = result);
    }
  }

  Widget _buildDateField({
    required String title,
    required String value,
    required VoidCallback onTap,
  }) {
    return FilterSheetDateField(title: title, value: value, onTap: onTap);
  }

  Widget _buildDateSectionContent() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildDateField(
                title: 'app.market.filter.date_start'.tr,
                value: _formatDate(_startDate),
                onTap: _pickStartDate,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildDateField(
                title: 'app.market.filter.date_end'.tr,
                value: _formatDate(_endDate),
                onTap: _pickEndDate,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () => setState(() {
              _startDate = null;
              _endDate = null;
            }),
            child: Text('app.market.filter.clear'.tr),
          ),
        ),
      ],
    );
  }

  Widget _buildHeroGroupSectionContent(_AttributeGroup group) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final selectedHero = _selectedTags['hero'];
    final isUnlimited = selectedHero == null;
    final headerTint = isDark
        ? colors.surfaceContainerHighest.withValues(alpha: 0.22)
        : colors.surfaceContainerHighest.withValues(alpha: 0.55);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => setState(() {
              _selectedTags.remove('hero');
            }),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isUnlimited
                    ? colors.primary.withValues(alpha: 0.12)
                    : headerTint,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isUnlimited
                      ? colors.primary.withValues(alpha: 0.5)
                      : colors.outline.withValues(alpha: 0.12),
                ),
              ),
              child: Text(
                'app.common.unlimited'.tr,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isUnlimited ? colors.primary : colors.onSurfaceVariant,
                  fontWeight: isUnlimited ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        ...group.heroSections.map(
          (section) => _buildHeroSection(
            section,
            selectedHero,
            sectionKey: 'group:${group.key}',
          ),
        ),
      ],
    );
  }

  Widget _buildHeroSection(
    _HeroSection section,
    String? selectedHero, {
    required String sectionKey,
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            section.labelKey.tr,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final minTileWidth = 78.0;
              final count = (width / minTileWidth).floor().clamp(3, 5).toInt();
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: section.heroes.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: count,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 0.78,
                ),
                itemBuilder: (context, index) {
                  final hero = section.heroes[index];
                  final selected = selectedHero == hero.name;
                  return KeyedSubtree(
                    key: _selectionAnchorKey(sectionKey, hero.name),
                    child: _buildHeroTile(hero, selected: selected),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHeroTile(_AttributeOption hero, {required bool selected}) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final name = hero.label;
    final imageUrl = hero.imageUrl;
    final placeholder = isDark
        ? colors.surfaceContainerHighest
        : colors.surface;
    return Semantics(
      button: true,
      selected: selected,
      label: name,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _selectOption('hero', hero),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: selected
                ? colors.primary.withValues(alpha: 0.12)
                : colors.surfaceContainerHighest.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? colors.primary.withValues(alpha: 0.55)
                  : colors.outline.withValues(alpha: 0.12),
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: colors.primary.withValues(alpha: 0.16),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [],
          ),
          child: Column(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    color: placeholder,
                    alignment: Alignment.center,
                    child: imageUrl == null || imageUrl.isEmpty
                        ? Icon(
                            Icons.person,
                            size: 26,
                            color: colors.onSurfaceVariant,
                          )
                        : _buildHeroImage(imageUrl),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected ? colors.primary : colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroImage(String url) {
    final devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
    const displaySize = 52.0;
    final cacheSize = (displaySize * devicePixelRatio).round();
    return Image.network(
      url,
      width: displaySize,
      height: displaySize,
      fit: BoxFit.cover,
      cacheWidth: cacheSize,
      cacheHeight: cacheSize,
      filterQuality: FilterQuality.medium,
      errorBuilder: (context, error, stackTrace) {
        return Icon(
          Icons.person,
          size: 26,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        );
      },
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        final overlayColor = Theme.of(
          context,
        ).colorScheme.surface.withValues(alpha: 0.35);
        return Stack(
          fit: StackFit.expand,
          children: [
            child,
            ColoredBox(color: overlayColor),
            const Center(
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSubOptionGroup(_AttributeGroup group) {
    final sectionKey = 'group:${group.key}';
    final unlimitedLabel = 'app.common.unlimited'.tr;
    final selected = _selectedItemName;
    final directOptions = group.options
        .where((option) => option.subOptions.isEmpty)
        .toList();
    final groupedOptions = group.options
        .where((option) => option.subOptions.isNotEmpty)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildChip(
          unlimitedLabel,
          selected: selected == null,
          chipKey: _selectionAnchorKey(sectionKey, 'unlimited'),
          onSelected: (_) => _selectSubOption(
            group,
            _AttributeOption(
              name: 'unlimited',
              label: unlimitedLabel,
              isUnlimited: true,
            ),
          ),
        ),
        if (directOptions.isNotEmpty) ...[
          const SizedBox(height: 5),
          _buildOptionGrid(
            sectionKey: sectionKey,
            options: directOptions,
            isSelected: (option) => selected == option.name,
            onSelected: (option) => _selectSubOption(group, option),
          ),
        ],
        if (groupedOptions.isNotEmpty) ...[
          const SizedBox(height: 6),
          ...groupedOptions.map((option) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    option.label.tr,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 5),
                  _buildOptionGrid(
                    sectionKey: sectionKey,
                    options: option.subOptions,
                    isSelected: (sub) => selected == sub.name,
                    onSelected: (sub) => _selectSubOption(group, sub),
                  ),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }
}

List<_AttributeGroup> _buildGroupsStatic(int appId, Map<String, dynamic> raw) {
  final unlimitedLabel = 'app.common.unlimited'.tr;
  final groups = <_AttributeGroup>[];

  if (appId == 570) {
    final heroSections = <_HeroSection>[];
    final heroOptions = <_AttributeOption>[];
    const heroKeys = [
      'heroStrength',
      'heroAgility',
      'heroIntellect',
      'heroAll',
    ];
    const heroLabelMap = {
      'heroStrength': 'app.market.dota2.hero_strength',
      'heroAgility': 'app.market.dota2.hero_agility',
      'heroIntellect': 'app.market.dota2.hero_intellect',
      'heroAll': 'app.market.dota2.hero_all',
    };
    for (final key in heroKeys) {
      final group = raw[key];
      if (group is Map<String, dynamic>) {
        final list = group['list'];
        final base = group['base']?.toString() ?? '';
        if (list is List) {
          final heroes = _parseHeroOptionsStatic(list, base);
          if (heroes.isNotEmpty) {
            heroOptions.addAll(heroes);
            heroSections.add(
              _HeroSection(
                labelKey: heroLabelMap[key] ?? 'app.market.dota2.hero',
                heroes: heroes,
              ),
            );
          }
        }
      }
    }
    if (heroSections.isNotEmpty) {
      groups.add(
        _AttributeGroup(
          key: 'hero',
          label: 'app.market.dota2.hero',
          options: heroOptions,
          heroSections: heroSections,
        ),
      );
    }
    for (final key in ['slot', 'type', 'quality', 'rarity']) {
      final group = raw[key];
      if (group is Map<String, dynamic>) {
        groups.add(_buildGroupStatic(key, group, unlimitedLabel));
      }
    }
  } else {
    final preferred = ['type', 'exterior', 'quality', 'rarity', 'itemSet'];
    final used = <String>{};
    const skipKeys = {'weapon'};
    for (final key in preferred) {
      final group = raw[key];
      if (group is Map<String, dynamic>) {
        groups.add(_buildGroupStatic(key, group, unlimitedLabel));
        used.add(key);
      }
    }
    raw.forEach((key, value) {
      if (used.contains(key) || skipKeys.contains(key)) return;
      if (value is Map<String, dynamic>) {
        groups.add(_buildGroupStatic(key, value, unlimitedLabel));
      }
    });
  }
  return groups
      .where((group) => group.options.isNotEmpty || group.isHeroGroup)
      .toList();
}

_AttributeGroup _buildGroupStatic(
  String key,
  Map<String, dynamic> group,
  String unlimitedLabel,
) {
  final label = group['label']?.toString() ?? key;
  final list = group['list'];
  final options = list is List
      ? _parseOptionsStatic(list)
      : <_AttributeOption>[];
  final hasSubOptions = options.any((option) => option.subOptions.isNotEmpty);
  final normalized = hasSubOptions
      ? options
      : _withUnlimitedStatic(options, unlimitedLabel);
  return _AttributeGroup(
    key: key,
    label: label,
    options: normalized,
    hasSubOptions: hasSubOptions,
  );
}

List<_AttributeOption> _parseOptionsStatic(List list) {
  return list.whereType<Map<String, dynamic>>().map((item) {
    final name = item['name']?.toString() ?? '';
    final label = item['localized_name']?.toString() ?? name;
    final subTypes = item['subTypes'];
    final subOptions = <_AttributeOption>[];
    if (subTypes is List) {
      for (final sub in subTypes) {
        if (sub is Map<String, dynamic>) {
          final subKey = sub['key']?.toString() ?? '';
          final subLabel =
              sub['value']?.toString() ??
              sub['localized_name']?.toString() ??
              subKey;
          subOptions.add(
            _AttributeOption(name: subKey, label: subLabel, parentName: name),
          );
        }
      }
    }
    return _AttributeOption(
      name: name,
      label: label,
      isUnlimited: name.toLowerCase() == 'unlimited',
      subOptions: subOptions,
      color: item['color']?.toString(),
    );
  }).toList();
}

List<_AttributeOption> _parseHeroOptionsStatic(List list, String base) {
  return list.whereType<Map<String, dynamic>>().map((item) {
    final name = item['name']?.toString() ?? '';
    final label = item['localized_name']?.toString() ?? name;
    final imageUrl = base.isEmpty ? null : '$base$name.jpg';
    return _AttributeOption(name: name, label: label, imageUrl: imageUrl);
  }).toList();
}

List<_AttributeOption> _withUnlimitedStatic(
  List<_AttributeOption> options,
  String unlimitedLabel,
) {
  final exists = options.any((option) => option.isUnlimited);
  if (exists) return options;
  return [
    _AttributeOption(
      name: 'unlimited',
      label: unlimitedLabel,
      isUnlimited: true,
    ),
    ...options,
  ];
}

class MarketFilterGroupMeta {
  const MarketFilterGroupMeta({
    required this.key,
    required this.labelKey,
    required this.optionLabels,
  });

  final String key;
  final String labelKey;
  final Map<String, String> optionLabels;

  String? labelForValue(dynamic value) {
    if (value == null) {
      return null;
    }
    return optionLabels[value.toString()];
  }
}

class _AttributeGroup {
  const _AttributeGroup({
    required this.key,
    required this.label,
    required this.options,
    this.hasSubOptions = false,
    this.heroSections = const [],
  });

  final String key;
  final String label;
  final List<_AttributeOption> options;
  final bool hasSubOptions;
  final List<_HeroSection> heroSections;

  bool get isHeroGroup => heroSections.isNotEmpty;
}

class _AttributeOption {
  const _AttributeOption({
    required this.name,
    required this.label,
    this.subOptions = const [],
    this.parentName,
    this.isUnlimited = false,
    this.imageUrl,
    this.color,
  });

  final String name;
  final String label;
  final List<_AttributeOption> subOptions;
  final String? parentName;
  final bool isUnlimited;
  final String? imageUrl;
  final String? color;
}

class _HeroSection {
  const _HeroSection({required this.labelKey, required this.heroes});

  final String labelKey;
  final List<_AttributeOption> heroes;
}

class _DotaHeroLoadingPlaceholder extends StatefulWidget {
  const _DotaHeroLoadingPlaceholder();

  @override
  State<_DotaHeroLoadingPlaceholder> createState() =>
      _DotaHeroLoadingPlaceholderState();
}

class _DotaHeroLoadingPlaceholderState
    extends State<_DotaHeroLoadingPlaceholder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final shimmerWidth = constraints.maxWidth * 0.58;
            final travel = constraints.maxWidth + shimmerWidth * 2;
            final left = -shimmerWidth + (travel * _controller.value);
            return Stack(
              fit: StackFit.expand,
              children: [
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFFF8FAFC), Color(0xFFEAF1F7)],
                    ),
                  ),
                ),
                const Center(
                  child: Icon(
                    Icons.person_rounded,
                    size: 22,
                    color: Color(0x6694A3B8),
                  ),
                ),
                Positioned(
                  left: left,
                  top: 0,
                  bottom: 0,
                  child: IgnorePointer(
                    child: Container(
                      width: shimmerWidth,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            Color(0x00FFFFFF),
                            Color(0x70FFFFFF),
                            Color(0x00FFFFFF),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _DotaSectionAccent {
  const _DotaSectionAccent({required this.icon, required this.color});

  final IconData icon;
  final Color color;
}

class _CachePayload {
  const _CachePayload(this.raw, this.ts);

  final Map<String, dynamic> raw;
  final int ts;
}

class _SortChoice {
  const _SortChoice({
    required this.field,
    required this.asc,
    required this.label,
  });

  final String field;
  final bool asc;
  final String label;
}

class _TfPricePreset {
  const _TfPricePreset({
    required this.minUsd,
    required this.maxUsd,
    required this.label,
  });

  final double? minUsd;
  final double? maxUsd;
  final String label;
}

class _WearPreset {
  const _WearPreset({
    required this.option,
    required this.min,
    required this.max,
  });

  final _AttributeOption option;
  final double min;
  final double max;
}

class _GroupedOption {
  const _GroupedOption(this.groupKey, this.option);

  final String groupKey;
  final _AttributeOption option;
}

class _FilterLoadingBlock extends StatelessWidget {
  const _FilterLoadingBlock({required this.height, required this.carded});

  final double height;
  final bool carded;

  @override
  Widget build(BuildContext context) {
    final title = Container(
      width: 108,
      height: 14,
      decoration: BoxDecoration(
        color: const Color(0xFFE8EDF3),
        borderRadius: BorderRadius.circular(999),
      ),
    );
    final content = Container(
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFEFF3F7),
        borderRadius: FilterSheetStyle.cardRadius,
        boxShadow: carded ? FilterSheetStyle.cardShadow : const <BoxShadow>[],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: title,
        ),
        const SizedBox(height: 16),
        if (carded)
          content
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: content,
          ),
      ],
    );
  }
}

enum _SectionType { sort, price, group, status, date }

class _FilterSection {
  const _FilterSection({
    required this.type,
    required this.labelKey,
    this.group,
  });

  final _SectionType type;
  final String labelKey;
  final _AttributeGroup? group;

  String get key {
    if (type == _SectionType.group && group != null) {
      return 'group:${group!.key}';
    }
    return labelKey;
  }
}
