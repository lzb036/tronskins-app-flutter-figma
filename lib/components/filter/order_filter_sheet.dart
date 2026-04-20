import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:tronskins_app/common/hooks/currency/CurrencyController.dart';
import 'package:tronskins_app/components/filter/filter_models.dart';
import 'package:tronskins_app/components/filter/filter_price_support.dart';
import 'package:tronskins_app/components/filter/market_filter_sheet.dart';
import 'package:tronskins_app/components/filter/filter_sheet_style.dart';

enum OrderFilterSectionCategory { attribute, price, status, date, sort }

class OrderFilterSheet extends StatefulWidget {
  const OrderFilterSheet({
    super.key,
    required this.initial,
    required this.statusOptions,
    this.sortOptions = const [],
    this.defaultSortField = '',
    this.defaultSortAsc = false,
    this.titleKey = 'app.market.filter.text',
    this.showSort = false,
    this.showStatus = true,
    this.showDateRange = true,
    this.enableAttributeFilter = false,
    this.appId,
    this.attributeSortOptions = const [],
    this.attributeShowSort = false,
    this.attributeShowPriceRange = false,
    this.attributeGroupOrder = const [],
    this.includeFallbackAttributeGroups = true,
    this.attributeUseFlatSections = false,
    this.isSideSheet = false,
    this.sectionOrder,
  });

  final OrderFilterResult initial;
  final List<StatusOption> statusOptions;
  final List<SortOption> sortOptions;
  final String defaultSortField;
  final bool defaultSortAsc;
  final String titleKey;
  final bool showSort;
  final bool showStatus;
  final bool showDateRange;
  final bool enableAttributeFilter;
  final int? appId;
  final List<SortOption> attributeSortOptions;
  final bool attributeShowSort;
  final bool attributeShowPriceRange;
  final List<String> attributeGroupOrder;
  final bool includeFallbackAttributeGroups;
  final bool attributeUseFlatSections;
  final bool isSideSheet;
  final List<OrderFilterSectionCategory>? sectionOrder;

  static Future<OrderFilterResult?> showFromRight({
    required BuildContext context,
    required OrderFilterResult initial,
    required List<StatusOption> statusOptions,
    List<SortOption> sortOptions = const [],
    String defaultSortField = '',
    bool defaultSortAsc = false,
    String titleKey = 'app.market.filter.text',
    bool showSort = false,
    bool showStatus = true,
    bool showDateRange = true,
    bool enableAttributeFilter = false,
    int? appId,
    List<SortOption> attributeSortOptions = const [],
    bool attributeShowSort = false,
    bool attributeShowPriceRange = false,
    List<String> attributeGroupOrder = const [],
    bool includeFallbackAttributeGroups = true,
    bool attributeUseFlatSections = false,
    List<OrderFilterSectionCategory>? sectionOrder,
  }) {
    final barrierLabel = MaterialLocalizations.of(
      context,
    ).modalBarrierDismissLabel;
    return showGeneralDialog<OrderFilterResult>(
      context: context,
      barrierDismissible: true,
      barrierLabel: barrierLabel,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        final width = MediaQuery.of(dialogContext).size.width;
        return Align(
          alignment: Alignment.centerRight,
          child: SizedBox(
            width: width,
            child: Material(
              color: Colors.transparent,
              child: OrderFilterSheet(
                initial: initial,
                statusOptions: statusOptions,
                sortOptions: sortOptions,
                defaultSortField: defaultSortField,
                defaultSortAsc: defaultSortAsc,
                titleKey: titleKey,
                showSort: showSort,
                showStatus: showStatus,
                showDateRange: showDateRange,
                enableAttributeFilter: enableAttributeFilter,
                appId: appId,
                attributeSortOptions: attributeSortOptions,
                attributeShowSort: attributeShowSort,
                attributeShowPriceRange: attributeShowPriceRange,
                attributeGroupOrder: attributeGroupOrder,
                includeFallbackAttributeGroups: includeFallbackAttributeGroups,
                attributeUseFlatSections: attributeUseFlatSections,
                isSideSheet: true,
                sectionOrder: sectionOrder,
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
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        );
      },
    );
  }

  @override
  State<OrderFilterSheet> createState() => _OrderFilterSheetState();
}

class _OrderFilterSheetState extends State<OrderFilterSheet> {
  DateTime? _startDate;
  DateTime? _endDate;
  double? _attributeWearMin;
  double? _attributeWearMax;
  int _selectedStatusIndex = -1;
  int _currentSectionIndex = 0;
  bool _sortAsc = false;
  late String _sortField;
  late final TextEditingController _minController;
  late final TextEditingController _maxController;
  late String _attributeSortField;
  late bool _attributeSortAsc;
  late Map<String, dynamic> _attributeTags;
  final Map<String, List<String>> _attributeMultiTags = {};
  String? _attributeItemName;
  List<MarketFilterGroupMeta> _attributeGroups = const [];
  bool _attributeGroupsLoading = false;
  bool _hasScheduledAttributeLoad = false;
  bool _isFetchingAttributeGroups = false;
  final Map<String, GlobalKey> _selectionAnchorKeys = {};
  CurrencyController get _currency => Get.find<CurrencyController>();

  @override
  void initState() {
    super.initState();
    _startDate = widget.initial.startDate;
    _endDate = widget.initial.endDate;
    _sortAsc = widget.initial.sortAsc ?? false;
    _sortField = widget.initial.sortField ?? _defaultSortField();
    _minController = TextEditingController(
      text: _initialPriceText(widget.initial.priceMin),
    );
    _maxController = TextEditingController(
      text: _initialPriceText(widget.initial.priceMax),
    );
    _attributeSortField =
        widget.initial.sortField ?? _defaultAttributeSortField();
    _attributeSortAsc = widget.initial.sortAsc ?? false;
    _attributeTags = <String, dynamic>{};
    for (final entry
        in (widget.initial.tags ?? const <String, dynamic>{}).entries) {
      if (entry.key == 'paintWearMin') {
        _attributeWearMin = _parseOptionalDouble(entry.value);
        continue;
      }
      if (entry.key == 'paintWearMax') {
        _attributeWearMax = _parseOptionalDouble(entry.value);
        continue;
      }
      if (entry.value is Iterable) {
        final values = (entry.value as Iterable)
            .map((item) => item?.toString() ?? '')
            .where((item) => item.isNotEmpty)
            .toList(growable: false);
        if (values.isNotEmpty) {
          _attributeMultiTags[entry.key] = values;
        }
        continue;
      }
      _attributeTags[entry.key] = entry.value;
    }
    _attributeItemName = widget.initial.itemName;
    final initialExterior = _attributeTags['exterior']?.toString();
    if (!widget.attributeUseFlatSections &&
        (_attributeWearMin == null || _attributeWearMax == null) &&
        initialExterior != null &&
        initialExterior.isNotEmpty) {
      final range = _attributeWearRangeForKey(initialExterior);
      if (range != null) {
        _attributeWearMin ??= range.start;
        _attributeWearMax ??= range.end;
      }
    }
    if (widget.enableAttributeFilter && widget.appId != null) {
      _primeAttributeGroups();
      if (_attributeGroups.isEmpty) {
        _attributeGroupsLoading = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scheduleAttributeGroupLoad();
        });
      }
    }
    if (widget.initial.statusList != null) {
      final index = widget.statusOptions.indexWhere(
        (option) => _listEquals(option.values, widget.initial.statusList!),
      );
      _selectedStatusIndex = index;
    }
  }

  @override
  void dispose() {
    _minController.dispose();
    _maxController.dispose();
    super.dispose();
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

  String _formatDate(DateTime? date) {
    if (date == null) {
      return '-';
    }
    return DateFormat('yyyy-MM-dd').format(date);
  }

  int get _selectedFilterCount {
    var count = 0;
    final min = _parseDisplayPriceOrNull(_minController.text);
    final max = _parseDisplayPriceOrNull(_maxController.text);
    final hasSortFilter = widget.showSort
        ? _sortField.isNotEmpty &&
              !(_sortField == _defaultSortField() &&
                  _sortAsc == _defaultSortAsc())
        : (widget.attributeShowSort && _attributeSortField.isNotEmpty);

    if (hasSortFilter) {
      count += 1;
    }
    if (widget.showStatus &&
        _selectedStatusIndex >= 0 &&
        widget.statusOptions[_selectedStatusIndex].values.isNotEmpty) {
      count += 1;
    }
    if (widget.showDateRange && (_startDate != null || _endDate != null)) {
      count += 1;
    }
    if (widget.attributeShowPriceRange && (min != null || max != null)) {
      count += 1;
    }
    if (!widget.enableAttributeFilter) {
      return count;
    }

    final selectedTagValues = <String>{};
    for (final entry in _attributeTags.entries) {
      final normalized = entry.value?.toString().trim() ?? '';
      if (normalized.isEmpty || normalized == 'unlimited') {
        continue;
      }
      selectedTagValues.add(normalized);
      count += 1;
    }

    for (final values in _attributeMultiTags.values) {
      count += values
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty && value != 'unlimited')
          .toSet()
          .length;
    }

    final selectedItemName = (_attributeItemName ?? '').trim();
    if (selectedItemName.isNotEmpty &&
        !selectedTagValues.contains(selectedItemName)) {
      count += 1;
    }

    final hasExteriorTag = ((_attributeTags['exterior']?.toString() ?? '')
        .trim()
        .isNotEmpty);
    if (!hasExteriorTag &&
        (_attributeWearMin != null || _attributeWearMax != null)) {
      count += 1;
    }

    return count;
  }

  Future<void> _pickStartDate() async {
    final now = DateTime.now();
    final result = await _showDatePickerPanel(
      title: 'app.market.filter.date_start'.tr,
      initialDate: _startDate ?? now,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 1),
    );
    if (result != null) {
      setState(() {
        _startDate = result;
        if (_endDate != null && _endDate!.isBefore(result)) {
          _endDate = null;
        }
      });
    }
  }

  Future<void> _pickEndDate() async {
    final now = DateTime.now();
    final result = await _showDatePickerPanel(
      title: 'app.market.filter.date_end'.tr,
      initialDate: _endDate ?? _startDate ?? now,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 1),
    );
    if (result != null) {
      setState(() {
        _endDate = result;
        if (_startDate != null && _startDate!.isAfter(result)) {
          _startDate = null;
        }
      });
    }
  }

  Future<DateTime?> _showDatePickerPanel({
    required String title,
    required DateTime initialDate,
    required DateTime firstDate,
    required DateTime lastDate,
  }) {
    final safeInitialDate = _clampDate(initialDate, firstDate, lastDate);
    return showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (context) {
        return _OrderDatePickerPanel(
          title: title,
          initialDate: safeInitialDate,
          firstDate: firstDate,
          lastDate: lastDate,
        );
      },
    );
  }

  DateTime _clampDate(DateTime date, DateTime firstDate, DateTime lastDate) {
    final normalized = DateUtils.dateOnly(date);
    final first = DateUtils.dateOnly(firstDate);
    final last = DateUtils.dateOnly(lastDate);
    if (normalized.isBefore(first)) {
      return first;
    }
    if (normalized.isAfter(last)) {
      return last;
    }
    return normalized;
  }

  void _reset() {
    setState(() {
      _sortAsc = _defaultSortAsc();
      _sortField = _defaultSortField();
      _selectedStatusIndex = -1;
      _startDate = null;
      _endDate = null;
      _minController.clear();
      _maxController.clear();
      _attributeSortField = _defaultAttributeSortField();
      _attributeSortAsc = _defaultAttributeSortAsc();
      _attributeTags = <String, dynamic>{};
      _attributeItemName = null;
    });
  }

  void _resetAndApply() {
    _reset();
    Navigator.of(context).pop(
      const OrderFilterResult(
        sortAsc: false,
        sortField: null,
        priceMin: null,
        priceMax: null,
        tags: <String, dynamic>{},
        itemName: '',
        reset: true,
      ),
    );
  }

  void _primeAttributeGroups() {
    final appId = widget.appId;
    if (appId == null) {
      return;
    }
    _attributeGroups = MarketFilterSheet.cachedGroupMetas(appId: appId);
  }

  Future<void> _scheduleAttributeGroupLoad() async {
    if (_hasScheduledAttributeLoad || _attributeGroups.isNotEmpty) {
      return;
    }
    _hasScheduledAttributeLoad = true;
    await Future<void>.delayed(const Duration(milliseconds: 200));
    if (!mounted) {
      return;
    }
    await _loadAttributeGroups();
  }

  Future<void> _loadAttributeGroups() async {
    final appId = widget.appId;
    if (appId == null || _isFetchingAttributeGroups) {
      return;
    }
    _isFetchingAttributeGroups = true;
    if (mounted) {
      setState(() => _attributeGroupsLoading = true);
    } else {
      _attributeGroupsLoading = true;
    }
    try {
      final groups = await MarketFilterSheet.loadGroupMetas(appId: appId);
      if (!mounted) {
        _attributeGroups = groups;
        return;
      }
      setState(() {
        _attributeGroups = groups;
      });
    } finally {
      _isFetchingAttributeGroups = false;
      if (mounted) {
        setState(() => _attributeGroupsLoading = false);
      } else {
        _attributeGroupsLoading = false;
      }
    }
  }

  GlobalKey _selectionAnchorKey(String sectionKey, String optionName) {
    final key = '$sectionKey::$optionName';
    return _selectionAnchorKeys.putIfAbsent(key, GlobalKey.new);
  }

  void _apply() {
    final min = _parseDisplayPriceOrNull(_minController.text);
    final max = _parseDisplayPriceOrNull(_maxController.text);
    final mergedAttributeTags = <String, dynamic>{}
      ..addAll(_attributeTags)
      ..removeWhere((key, value) => value == null || value.toString().isEmpty);
    for (final entry in _attributeMultiTags.entries) {
      if (entry.value.isNotEmpty) {
        mergedAttributeTags[entry.key] = List<String>.from(entry.value);
      }
    }
    if (!widget.attributeUseFlatSections && _attributeWearMin != null) {
      mergedAttributeTags['paintWearMin'] = _attributeWearMin;
    }
    if (!widget.attributeUseFlatSections && _attributeWearMax != null) {
      mergedAttributeTags['paintWearMax'] = _attributeWearMax;
    }
    Navigator.of(context).pop(
      OrderFilterResult(
        sortAsc: widget.showSort
            ? _sortAsc
            : (widget.attributeShowSort ? _attributeSortAsc : null),
        sortField: widget.showSort
            ? _sortField
            : (widget.attributeShowSort ? _attributeSortField : null),
        priceMin: widget.attributeShowPriceRange ? min : null,
        priceMax: widget.attributeShowPriceRange ? max : null,
        statusList: _selectedStatusIndex >= 0
            ? widget.statusOptions[_selectedStatusIndex].values
            : null,
        startDate: _startDate,
        endDate: _endDate,
        tags: widget.enableAttributeFilter ? mergedAttributeTags : null,
        itemName: widget.enableAttributeFilter ? _attributeItemName : null,
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

  List<_OrderFilterSection> get _sections {
    final sections = <_OrderFilterSection>[];
    const defaultOrder = [
      OrderFilterSectionCategory.attribute,
      OrderFilterSectionCategory.price,
      OrderFilterSectionCategory.status,
      OrderFilterSectionCategory.date,
      OrderFilterSectionCategory.sort,
    ];
    final orderedCategories = <OrderFilterSectionCategory>[
      ...?widget.sectionOrder,
      ...defaultOrder.where(
        (category) => !(widget.sectionOrder?.contains(category) ?? false),
      ),
    ];
    for (final category in orderedCategories) {
      _appendSectionsByCategory(sections, category);
    }
    return sections;
  }

  void _appendSectionsByCategory(
    List<_OrderFilterSection> sections,
    OrderFilterSectionCategory category,
  ) {
    switch (category) {
      case OrderFilterSectionCategory.attribute:
        if (!widget.enableAttributeFilter) {
          return;
        }
        sections.add(
          const _OrderFilterSection(
            type: _OrderFilterSectionType.attribute,
            labelKey: 'app.market.filter.text',
          ),
        );
        return;
      case OrderFilterSectionCategory.price:
        if (!widget.attributeShowPriceRange) {
          return;
        }
        sections.add(
          const _OrderFilterSection(
            type: _OrderFilterSectionType.price,
            labelKey: 'app.market.filter.price_range',
          ),
        );
        return;
      case OrderFilterSectionCategory.status:
        if (!widget.showStatus) {
          return;
        }
        sections.add(
          const _OrderFilterSection(
            type: _OrderFilterSectionType.status,
            labelKey: 'app.trade.order.status',
          ),
        );
        return;
      case OrderFilterSectionCategory.date:
        if (!widget.showDateRange) {
          return;
        }
        sections.add(
          const _OrderFilterSection(
            type: _OrderFilterSectionType.date,
            labelKey: 'app.trade.order.date',
          ),
        );
        return;
      case OrderFilterSectionCategory.sort:
        if (!widget.showSort) {
          return;
        }
        sections.add(
          const _OrderFilterSection(
            type: _OrderFilterSectionType.sort,
            labelKey: 'app.market.filter.sort',
          ),
        );
        return;
    }
  }

  Widget _buildAttributeSection() {
    if (_attributeGroupsLoading) {
      return const _OrderFilterLoadingBlock();
    }
    if (_attributeGroups.isEmpty) {
      return Text(
        'app.common.no_data'.tr,
        style: Theme.of(context).textTheme.bodySmall,
      );
    }
    final sections = _buildAttributeBodySections();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < sections.length; i++) ...[
          sections[i],
          if (i != sections.length - 1) const SizedBox(height: 39),
        ],
      ],
    );
  }

  List<Widget> _buildAttributeBodySections() {
    if (widget.attributeGroupOrder.isNotEmpty ||
        widget.attributeUseFlatSections) {
      return _buildOrderedAttributeBodySections();
    }

    final sections = <Widget>[];
    final handledKeys = <String>{};

    MarketFilterGroupMeta? findGroup(String key) {
      for (final group in _attributeGroups) {
        if (group.key == key) {
          return group;
        }
      }
      return null;
    }

    final typeGroup = findGroup('type');
    if (typeGroup != null) {
      handledKeys.add(typeGroup.key);
      sections.add(_buildAttributeTypeSection(typeGroup));
    }

    final rarityGroup = findGroup('rarity');
    if (rarityGroup != null) {
      handledKeys.add(rarityGroup.key);
      sections.add(_buildAttributeRaritySection(rarityGroup));
    }

    final wearGroup = findGroup('exterior');
    if (wearGroup != null) {
      handledKeys.add(wearGroup.key);
      sections.add(_buildAttributeWearSection(wearGroup));
    }

    final categoryGroups = _attributeGroups
        .where((group) => group.key == 'quality' || group.key == 'itemSet')
        .toList(growable: false);
    if (categoryGroups.isNotEmpty) {
      handledKeys.addAll(categoryGroups.map((group) => group.key));
      sections.add(_buildAttributeCategorySection(categoryGroups));
    }

    for (final group in _attributeGroups) {
      if (handledKeys.contains(group.key)) {
        continue;
      }
      sections.add(_buildAttributeFallbackSection(group));
    }

    return sections;
  }

  List<Widget> _buildOrderedAttributeBodySections() {
    final sections = <Widget>[];
    final handledKeys = <String>{};

    MarketFilterGroupMeta? findGroup(String key) {
      for (final group in _attributeGroups) {
        if (group.key == key) {
          return group;
        }
      }
      return null;
    }

    for (final key in widget.attributeGroupOrder) {
      final group = findGroup(key);
      if (group == null || handledKeys.contains(group.key)) {
        continue;
      }
      handledKeys.add(group.key);
      sections.add(_buildOrderedAttributeGroupSection(group));
    }

    if (widget.includeFallbackAttributeGroups) {
      for (final group in _attributeGroups) {
        if (handledKeys.contains(group.key)) {
          continue;
        }
        sections.add(_buildOrderedAttributeGroupSection(group));
      }
    }

    return sections;
  }

  Widget _buildOrderedAttributeGroupSection(MarketFilterGroupMeta group) {
    if (!widget.attributeUseFlatSections) {
      switch (group.key) {
        case 'type':
          return _buildAttributeTypeSection(group);
        case 'rarity':
          return _buildAttributeRaritySection(group);
        case 'exterior':
          return _buildAttributeWearSection(group);
        default:
          return _buildAttributeFallbackSection(group);
      }
    }
    return group.key == 'type'
        ? _buildAttributeTypeSection(group)
        : _buildAttributeFallbackSection(group);
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

  List<MapEntry<String, String>> _attributeVisibleOptions(
    MarketFilterGroupMeta group,
  ) {
    return group.optionLabels.entries
        .where(
          (entry) =>
              entry.key.isNotEmpty &&
              entry.value.isNotEmpty &&
              entry.key.toLowerCase() != 'unlimited',
        )
        .toList(growable: false);
  }

  Set<String> _selectedAttributeValues(String key) {
    final multiValues = _attributeMultiTags[key];
    if (multiValues != null && multiValues.isNotEmpty) {
      return multiValues.toSet();
    }
    final raw = _attributeTags[key];
    if (raw == null) {
      return <String>{};
    }
    final value = raw.toString();
    if (value.isEmpty) {
      return <String>{};
    }
    return <String>{value};
  }

  Widget _buildAttributePlainChipWrap({
    required List<MapEntry<String, String>> options,
    required bool Function(String key) isSelected,
    required void Function(String key) onTap,
    FilterChipSelectedStyle selectedStyle = FilterChipSelectedStyle.solid,
    Color? selectedColor,
    Color? selectedBorderColor,
    Color? selectedTextColor,
    Color? unselectedColor,
    Color? unselectedBorderColor,
    Color? unselectedTextColor,
    double fontSize = 14,
    double minHeight = 38,
    BorderRadius borderRadius = const BorderRadius.all(Radius.circular(4)),
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
            label: option.value,
            selected: isSelected(option.key),
            selectedStyle: selectedStyle,
            selectedColor: selectedColor,
            selectedBorderColor: selectedBorderColor,
            selectedTextColor: selectedTextColor,
            unselectedColor: unselectedColor,
            unselectedBorderColor: unselectedBorderColor,
            unselectedTextColor: unselectedTextColor,
            borderRadius: borderRadius,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            minHeight: minHeight,
            fontSize: fontSize,
            height: 21 / fontSize,
            selectedBoxShadow: selectedBoxShadow,
            unselectedBoxShadow: unselectedBoxShadow,
            selectedFontWeight: selectedFontWeight,
            unselectedFontWeight: unselectedFontWeight,
            onTap: () => onTap(option.key),
          ),
      ],
    );
  }

  Widget _buildAttributeTypeSection(MarketFilterGroupMeta group) {
    return FilterSheetSection(
      title: group.labelKey.tr,
      carded: false,
      child: _buildAttributePlainChipWrap(
        options: _attributeVisibleOptions(group),
        isSelected: (value) =>
            (_attributeTags[group.key]?.toString() ?? '') == value,
        onTap: (value) {
          setState(() {
            if ((_attributeTags[group.key]?.toString() ?? '') == value) {
              _attributeTags.remove(group.key);
            } else {
              _attributeTags[group.key] = value;
            }
          });
        },
        unselectedColor: FilterSheetStyle.subtleBackground,
        unselectedBorderColor: Colors.transparent,
        minHeight: 37,
        selectedFontWeight: FontWeight.w500,
        unselectedFontWeight: FontWeight.w400,
        selectedBoxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
        unselectedBoxShadow: const <BoxShadow>[],
      ),
    );
  }

  Widget _buildAttributeRaritySection(MarketFilterGroupMeta group) {
    final options = _attributeVisibleOptions(group);
    final selected = _selectedAttributeValues(group.key);
    return FilterSheetSection(
      title: group.labelKey.tr,
      child: LayoutBuilder(
        builder: (context, constraints) {
          const spacing = 12.0;
          final itemWidth = (constraints.maxWidth - spacing) / 2;
          return Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: [
              for (final option in options)
                SizedBox(
                  width: itemWidth,
                  child: FilterSheetCheckboxTile(
                    label: option.value,
                    selected: selected.contains(option.key),
                    onTap: () {
                      setState(() {
                        final values = List<String>.from(
                          _attributeMultiTags[group.key] ?? const <String>[],
                        );
                        if (values.contains(option.key)) {
                          values.remove(option.key);
                        } else {
                          values.add(option.key);
                        }
                        if (values.isEmpty) {
                          _attributeMultiTags.remove(group.key);
                        } else {
                          _attributeMultiTags[group.key] = values;
                        }
                      });
                    },
                    labelColor: selected.contains(option.key)
                        ? FilterSheetStyle.primary
                        : FilterSheetStyle.body,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAttributeWearSection(MarketFilterGroupMeta group) {
    final range = _currentAttributeWearRange();
    final options = _buildOrderWearOptions(group);
    return FilterSheetSection(
      title: group.labelKey.tr,
      trailing: Text(
        '${_formatOrderWearValue(range.start)} - ${_formatOrderWearValue(range.end)}',
        style: const TextStyle(
          color: FilterSheetStyle.primary,
          fontSize: 14,
          height: 20 / 14,
          fontWeight: FontWeight.w700,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAttributeWearScale(range, group),
          const SizedBox(height: 24),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final option in options)
                FilterSheetOptionChip(
                  label: option.label,
                  selected: _isOrderWearOptionActive(option, range),
                  selectedStyle: FilterChipSelectedStyle.soft,
                  selectedColor: FilterSheetStyle.selectedSoft,
                  selectedBorderColor: FilterSheetStyle.selectedSoftBorder,
                  selectedTextColor: FilterSheetStyle.primary,
                  unselectedColor: const Color(0xFFECEEF0),
                  unselectedBorderColor: Colors.transparent,
                  unselectedTextColor: FilterSheetStyle.body,
                  borderRadius: FilterSheetStyle.chipRadius,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 9,
                  ),
                  minHeight: 36,
                  fontSize: 12,
                  height: 18 / 12,
                  onTap: () => _applyOrderWearOption(group, option),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAttributeCategorySection(List<MarketFilterGroupMeta> groups) {
    final options = <_OrderGroupedOption>[];
    final seen = <String>{};
    for (final group in groups) {
      for (final option in _attributeVisibleOptions(group)) {
        final id = '${group.key}:${option.key}';
        if (seen.add(id)) {
          options.add(_OrderGroupedOption(group.key, option.key, option.value));
        }
      }
    }
    return FilterSheetSection(
      title: 'app.market.csgo.category'.tr,
      carded: false,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final option in options)
            FilterSheetOptionChip(
              label: option.label,
              selected:
                  (_attributeTags[option.groupKey]?.toString() ?? '') ==
                  option.optionKey,
              selectedStyle: FilterChipSelectedStyle.soft,
              selectedColor: Colors.transparent,
              selectedBorderColor: const Color(0xFFFF9500),
              selectedTextColor: const Color(0xFFFF9500),
              unselectedColor: Colors.transparent,
              unselectedBorderColor: FilterSheetStyle.border,
              unselectedTextColor: FilterSheetStyle.body,
              borderRadius: const BorderRadius.all(Radius.circular(4)),
              padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 9),
              minHeight: 40,
              fontSize: 14,
              height: 21 / 14,
              onTap: () {
                setState(() {
                  if ((_attributeTags[option.groupKey]?.toString() ?? '') ==
                      option.optionKey) {
                    _attributeTags.remove(option.groupKey);
                  } else {
                    _attributeTags[option.groupKey] = option.optionKey;
                  }
                });
              },
            ),
        ],
      ),
    );
  }

  Widget _buildAttributeFallbackSection(MarketFilterGroupMeta group) {
    return FilterSheetSection(
      title: group.labelKey.tr,
      carded: false,
      child: _buildAttributePlainChipWrap(
        options: _attributeVisibleOptions(group),
        isSelected: (value) =>
            (_attributeTags[group.key]?.toString() ?? '') == value,
        onTap: (value) {
          setState(() {
            if ((_attributeTags[group.key]?.toString() ?? '') == value) {
              _attributeTags.remove(group.key);
            } else {
              _attributeTags[group.key] = value;
            }
          });
        },
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
      ),
    );
  }

  RangeValues? _attributeWearRangeForKey(String key) {
    switch (key) {
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

  RangeValues _currentAttributeWearRange() {
    final start = (_attributeWearMin ?? 0).clamp(0.0, 1.0);
    final end = (_attributeWearMax ?? 1).clamp(0.0, 1.0);
    return RangeValues(start < end ? start : end, end > start ? end : start);
  }

  List<_OrderWearOption> _buildOrderWearOptions(MarketFilterGroupMeta group) {
    return _attributeVisibleOptions(group)
        .map((option) {
          final range = _attributeWearRangeForKey(option.key);
          if (range == null) {
            return null;
          }
          return _OrderWearOption(
            key: option.key,
            label: option.value,
            min: range.start,
            max: range.end,
          );
        })
        .whereType<_OrderWearOption>()
        .toList(growable: false);
  }

  bool _isOrderWearOptionActive(_OrderWearOption option, RangeValues range) {
    return range.end > option.min && range.start < option.max;
  }

  void _applyOrderWearOption(
    MarketFilterGroupMeta group,
    _OrderWearOption option,
  ) {
    setState(() {
      _attributeTags[group.key] = option.key;
      _attributeWearMin = option.min;
      _attributeWearMax = option.max;
    });
  }

  void _updateAttributeWearRange(
    MarketFilterGroupMeta group,
    RangeValues values,
  ) {
    final normalized = RangeValues(
      _roundOrderWear(values.start.clamp(0.0, 1.0)),
      _roundOrderWear(values.end.clamp(0.0, 1.0)),
    );
    String? matchedKey;
    for (final option in _buildOrderWearOptions(group)) {
      if ((option.min - normalized.start).abs() < 0.001 &&
          (option.max - normalized.end).abs() < 0.001) {
        matchedKey = option.key;
        break;
      }
    }
    setState(() {
      _attributeWearMin = normalized.start <= 0.001 ? null : normalized.start;
      _attributeWearMax = normalized.end >= 0.999 ? null : normalized.end;
      if (matchedKey == null) {
        _attributeTags.remove(group.key);
      } else {
        _attributeTags[group.key] = matchedKey;
      }
    });
  }

  double _roundOrderWear(double value) {
    return (value * 100).roundToDouble() / 100;
  }

  String _formatOrderWearValue(double value) {
    return value.toStringAsFixed(2);
  }

  Widget _buildAttributeWearScale(
    RangeValues range,
    MarketFilterGroupMeta group,
  ) {
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
                    _formatOrderWearValue(marker),
                    style: const TextStyle(
                      color: FilterSheetStyle.body,
                      fontSize: 10,
                      height: 15 / 10,
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
              ),
              child: RangeSlider(
                values: range,
                min: 0,
                max: 1,
                divisions: 100,
                onChanged: (values) => _updateAttributeWearRange(group, values),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<_OrderSortChoice> _buildSortChoices() {
    final choices = <_OrderSortChoice>[];
    final seenStates = <String>{};

    void push(_OrderSortChoice choice) {
      final stateKey = '${choice.field}:${choice.asc}';
      if (seenStates.add(stateKey)) {
        choices.add(choice);
      }
    }

    final defaultSortField = _defaultSortField();
    final hasDefaultSortOption = widget.sortOptions.any(
      (option) => option.field == defaultSortField,
    );
    if (defaultSortField.isEmpty || !hasDefaultSortOption) {
      push(
        _OrderSortChoice(
          field: defaultSortField,
          asc: _defaultSortAsc(),
          label: 'app.market.filter.default'.tr,
        ),
      );
    }

    for (final option in widget.sortOptions) {
      switch (option.field) {
        case 'price':
          push(
            _OrderSortChoice(
              field: 'price',
              asc: false,
              label: _localizedPriceSortLabel(asc: false),
            ),
          );
          push(
            _OrderSortChoice(
              field: 'price',
              asc: true,
              label: _localizedPriceSortLabel(asc: true),
            ),
          );
          continue;
        case 'hot':
          push(
            _OrderSortChoice(
              field: option.field,
              asc: false,
              label: _localizedHotSortLabel(option),
            ),
          );
          continue;
        case 'time':
        case 'upTime':
          push(
            _OrderSortChoice(
              field: option.field,
              asc: false,
              label: _localizedTimeSortLabel(option: option, asc: false),
            ),
          );
          push(
            _OrderSortChoice(
              field: option.field,
              asc: true,
              label: _localizedTimeSortLabel(option: option, asc: true),
            ),
          );
          continue;
        default:
          push(
            _OrderSortChoice(
              field: option.field,
              asc: false,
              label: option.labelKey.tr,
            ),
          );
      }
    }
    if (choices.isEmpty) {
      choices.add(
        _OrderSortChoice(
          field: _sortField,
          asc: _sortAsc,
          label: 'app.market.filter.default'.tr,
        ),
      );
    }
    return choices;
  }

  String _defaultSortField() => widget.defaultSortField;

  bool _defaultSortAsc() => widget.defaultSortAsc;

  String _defaultAttributeSortField() {
    return '';
  }

  bool _defaultAttributeSortAsc() => false;

  double _priceUpperBound() {
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
    return RangeValues(
      parsedMin < parsedMax ? parsedMin : parsedMax,
      parsedMax > parsedMin ? parsedMax : parsedMin,
    );
  }

  void _updatePriceRange(RangeValues values, double maxBound) {
    final start = values.start.clamp(0.0, maxBound);
    final end = values.end.clamp(0.0, maxBound);
    setState(() {
      _minController.text = start <= 0 ? '' : _initialPriceText(start);
      _maxController.text = end >= maxBound ? '' : _initialPriceText(end);
    });
  }

  Widget _buildPriceSlider(double maxBound, RangeValues range) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = (constraints.maxWidth - 28).clamp(
          0.0,
          double.infinity,
        );
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
    final maxLeft = width - labelWidth;
    return raw.clamp(0.0, maxLeft < 0 ? 0 : maxLeft);
  }

  String _localizedPriceSortLabel({required bool asc}) {
    if (Get.locale?.languageCode == 'en') {
      return asc ? 'Price Low to High' : 'Price High to Low';
    }
    return '${'app.market.filter.price'.tr} ${asc ? '↑' : '↓'}';
  }

  String _localizedTimeSortLabel({
    required SortOption option,
    required bool asc,
  }) {
    final arrow = asc ? '↑' : '↓';
    final template = 'app.market.filter.time_sorting'.tr;
    if (template.contains('{0}')) {
      return template.replaceAll('{0}', arrow);
    }
    return '${option.labelKey.tr} $arrow';
  }

  String _localizedHotSortLabel(SortOption option) {
    if (Get.locale?.languageCode == 'en') {
      return 'Most Popular';
    }
    return option.labelKey.tr;
  }

  Widget _buildStatusSection(_OrderFilterSection section) {
    return FilterSheetSection(
      title: 'app.trade.order.status'.tr,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: List.generate(widget.statusOptions.length, (index) {
          final option = widget.statusOptions[index];
          final selected = _selectedStatusIndex == index;
          return KeyedSubtree(
            key: _selectionAnchorKey(section.key, 'status:$index'),
            child: FilterSheetOptionChip(
              label: option.labelKey.tr,
              selected: selected,
              onTap: () {
                setState(() {
                  _selectedStatusIndex = selected ? -1 : index;
                });
              },
            ),
          );
        }),
      ),
    );
  }

  Widget _buildDateField({
    required String title,
    required String value,
    required VoidCallback onTap,
  }) {
    return FilterSheetDateField(title: title, value: value, onTap: onTap);
  }

  Widget _buildDateClearButton() {
    final hasDate = _startDate != null || _endDate != null;
    final foregroundColor = hasDate
        ? FilterSheetStyle.primary
        : FilterSheetStyle.hint;
    return Align(
      alignment: Alignment.centerLeft,
      child: InkWell(
        borderRadius: FilterSheetStyle.chipRadius,
        onTap: hasDate
            ? () => setState(() {
                _startDate = null;
                _endDate = null;
              })
            : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: hasDate
                ? FilterSheetStyle.selectedSoft
                : FilterSheetStyle.mutedBackground,
            borderRadius: FilterSheetStyle.chipRadius,
            border: Border.all(
              color: hasDate
                  ? FilterSheetStyle.selectedSoftBorder
                  : FilterSheetStyle.surfaceStroke,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.close_rounded, size: 16, color: foregroundColor),
              const SizedBox(width: 6),
              Text(
                'app.market.filter.clear'.tr,
                style: TextStyle(
                  color: foregroundColor,
                  fontSize: 13,
                  height: 19.5 / 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateSection() {
    return FilterSheetSection(
      title: 'app.trade.order.date'.tr,
      child: Column(
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
          _buildDateClearButton(),
        ],
      ),
    );
  }

  Widget _buildPriceSection() {
    final maxBound = _priceUpperBound();
    final range = _currentPriceRangeValues(maxBound);
    return FilterSheetSection(
      title: 'app.market.filter.price_range'.tr,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPriceSlider(maxBound, range),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _minController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: (_) => setState(() {}),
                  decoration: FilterSheetStyle.inputDecoration(
                    hintText: 'Min',
                    prefixText: _currency.symbol,
                  ),
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
                child: TextField(
                  controller: _maxController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: (_) => setState(() {}),
                  decoration: FilterSheetStyle.inputDecoration(
                    hintText: 'Max',
                    prefixText: _currency.symbol,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSortSection(_OrderFilterSection section) {
    final choices = _buildSortChoices();
    return FilterSheetSection(
      title: 'app.market.filter.sort'.tr,
      child: Column(
        children: [
          for (var i = 0; i < choices.length; i++)
            KeyedSubtree(
              key: _selectionAnchorKey(
                section.key,
                '${choices[i].field}:${choices[i].asc}',
              ),
              child: FilterSheetRadioTile(
                label: choices[i].label,
                selected:
                    _sortField == choices[i].field &&
                    _sortAsc == choices[i].asc,
                onTap: () {
                  setState(() {
                    _sortField = choices[i].field;
                    _sortAsc = choices[i].asc;
                  });
                },
                showDivider: i != choices.length - 1,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionContent(_OrderFilterSection section) {
    switch (section.type) {
      case _OrderFilterSectionType.attribute:
        return _buildAttributeSection();
      case _OrderFilterSectionType.price:
        return _buildPriceSection();
      case _OrderFilterSectionType.status:
        return _buildStatusSection(section);
      case _OrderFilterSectionType.date:
        return _buildDateSection();
      case _OrderFilterSectionType.sort:
        return _buildSortSection(section);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sections = _sections;
    if (sections.isNotEmpty && _currentSectionIndex >= sections.length) {
      _currentSectionIndex = 0;
    }
    return FilterSheetFrame(
      title: widget.titleKey.tr,
      resetLabel: 'app.market.filter.reset'.tr,
      onReset: _resetAndApply,
      onClose: () {
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      },
      confirmLabel: 'app.market.filter.finish'.tr,
      confirmCount: _selectedFilterCount,
      onConfirm: _apply,
      body: sections.isEmpty
          ? Center(
              child: Text(
                'app.common.no_data'.tr,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            )
          : SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 23, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < sections.length; i++) ...[
                    _buildSectionContent(sections[i]),
                    if (i != sections.length - 1) const SizedBox(height: 39),
                  ],
                ],
              ),
            ),
    );
  }
}

class _OrderDatePickerPanel extends StatefulWidget {
  const _OrderDatePickerPanel({
    required this.title,
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
  });

  final String title;
  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;

  @override
  State<_OrderDatePickerPanel> createState() => _OrderDatePickerPanelState();
}

class _OrderDatePickerPanelState extends State<_OrderDatePickerPanel> {
  late DateTime _selectedDate;
  late DateTime _visibleMonth;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateUtils.dateOnly(widget.initialDate);
    _visibleMonth = DateTime(_selectedDate.year, _selectedDate.month);
  }

  bool _isSameDay(DateTime a, DateTime b) => DateUtils.isSameDay(a, b);

  bool _isBeforeMonth(DateTime month, DateTime target) {
    return month.year < target.year ||
        (month.year == target.year && month.month < target.month);
  }

  bool _isAfterMonth(DateTime month, DateTime target) {
    return month.year > target.year ||
        (month.year == target.year && month.month > target.month);
  }

  bool get _canGoPrevious {
    final firstMonth = DateTime(widget.firstDate.year, widget.firstDate.month);
    return _isAfterMonth(_visibleMonth, firstMonth);
  }

  bool get _canGoNext {
    final lastMonth = DateTime(widget.lastDate.year, widget.lastDate.month);
    return _isBeforeMonth(_visibleMonth, lastMonth);
  }

  void _changeMonth(int offset) {
    setState(() {
      _visibleMonth = DateTime(
        _visibleMonth.year,
        _visibleMonth.month + offset,
      );
    });
  }

  List<String> _weekdayLabels(MaterialLocalizations localizations) {
    final labels = localizations.narrowWeekdays;
    final start = localizations.firstDayOfWeekIndex;
    return List<String>.generate(
      DateTime.daysPerWeek,
      (index) => labels[(start + index) % DateTime.daysPerWeek],
    );
  }

  List<DateTime?> _monthCells(MaterialLocalizations localizations) {
    final firstOfMonth = DateTime(_visibleMonth.year, _visibleMonth.month);
    final daysInMonth = DateUtils.getDaysInMonth(
      _visibleMonth.year,
      _visibleMonth.month,
    );
    final firstWeekday = firstOfMonth.weekday % DateTime.daysPerWeek;
    final offset =
        (firstWeekday - localizations.firstDayOfWeekIndex) %
        DateTime.daysPerWeek;
    final cellCount =
        ((offset + daysInMonth + DateTime.daysPerWeek - 1) ~/
            DateTime.daysPerWeek) *
        DateTime.daysPerWeek;

    return List<DateTime?>.generate(cellCount, (index) {
      final day = index - offset + 1;
      if (day < 1 || day > daysInMonth) {
        return null;
      }
      return DateTime(_visibleMonth.year, _visibleMonth.month, day);
    });
  }

  bool _isDisabled(DateTime date) {
    final day = DateUtils.dateOnly(date);
    return day.isBefore(DateUtils.dateOnly(widget.firstDate)) ||
        day.isAfter(DateUtils.dateOnly(widget.lastDate));
  }

  Widget _buildMonthButton({
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: 38,
      height: 38,
      child: IconButton(
        onPressed: enabled ? onTap : null,
        icon: Icon(icon, size: 20),
        style: IconButton.styleFrom(
          foregroundColor: enabled
              ? FilterSheetStyle.body
              : FilterSheetStyle.border,
          backgroundColor: FilterSheetStyle.mutedBackground,
          disabledBackgroundColor: FilterSheetStyle.mutedBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: EdgeInsets.zero,
        ),
      ),
    );
  }

  Widget _buildDayCell(DateTime? date) {
    if (date == null) {
      return const SizedBox(height: 40);
    }

    final disabled = _isDisabled(date);
    final selected = _isSameDay(date, _selectedDate);
    final today = _isSameDay(date, DateTime.now());
    final textColor = disabled
        ? FilterSheetStyle.border
        : selected
        ? Colors.white
        : FilterSheetStyle.title;

    return Center(
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: disabled
            ? null
            : () => setState(() => _selectedDate = DateUtils.dateOnly(date)),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: selected ? FilterSheetStyle.primary : Colors.transparent,
            border: today && !selected
                ? Border.all(color: FilterSheetStyle.selectedSoftBorder)
                : null,
          ),
          child: Text(
            '${date.day}',
            style: TextStyle(
              color: textColor,
              fontSize: 14,
              height: 20 / 14,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 48,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  foregroundColor: FilterSheetStyle.body,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 15,
                    height: 22 / 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: Text('app.common.cancel'.tr),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                borderRadius: FilterSheetStyle.buttonRadius,
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: <Color>[
                    FilterSheetStyle.primary,
                    FilterSheetStyle.primaryBright,
                  ],
                ),
              ),
              child: SizedBox(
                height: 48,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(_selectedDate),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    shape: const RoundedRectangleBorder(
                      borderRadius: FilterSheetStyle.buttonRadius,
                    ),
                    textStyle: const TextStyle(
                      fontSize: 15,
                      height: 22 / 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: Text('app.common.confirm'.tr),
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
    final localizations = MaterialLocalizations.of(context);
    final weekDays = _weekdayLabels(localizations);
    final cells = _monthCells(localizations);
    final maxHeight = MediaQuery.of(context).size.height * 0.82;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: FilterSheetStyle.pageBackground,
          borderRadius: FilterSheetStyle.panelRadius,
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Color(0x24000000),
              blurRadius: 28,
              offset: Offset(0, -8),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: FilterSheetStyle.border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 12, 14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.title,
                          style: const TextStyle(
                            color: FilterSheetStyle.title,
                            fontSize: 18,
                            height: 27 / 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                        color: FilterSheetStyle.body,
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: FilterSheetStyle.cardRadius,
                      boxShadow: FilterSheetStyle.cardShadow,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.calendar_month_outlined,
                          size: 20,
                          color: FilterSheetStyle.primary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            localizations.formatFullDate(_selectedDate),
                            style: const TextStyle(
                              color: FilterSheetStyle.title,
                              fontSize: 15,
                              height: 22.5 / 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          localizations.formatMonthYear(_visibleMonth),
                          style: const TextStyle(
                            color: FilterSheetStyle.body,
                            fontSize: 15,
                            height: 22.5 / 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      _buildMonthButton(
                        icon: Icons.chevron_left_rounded,
                        enabled: _canGoPrevious,
                        onTap: () => _changeMonth(-1),
                      ),
                      const SizedBox(width: 8),
                      _buildMonthButton(
                        icon: Icons.chevron_right_rounded,
                        enabled: _canGoNext,
                        onTap: () => _changeMonth(1),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      for (final day in weekDays)
                        Expanded(
                          child: Center(
                            child: Text(
                              day,
                              style: const TextStyle(
                                color: FilterSheetStyle.hint,
                                fontSize: 12,
                                height: 18 / 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
                  child: GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: DateTime.daysPerWeek,
                    mainAxisSpacing: 6,
                    crossAxisSpacing: 4,
                    childAspectRatio: 1.1,
                    children: [for (final date in cells) _buildDayCell(date)],
                  ),
                ),
                const Divider(
                  height: 1,
                  thickness: 1,
                  color: FilterSheetStyle.divider,
                ),
                _buildFooter(context),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OrderGroupedOption {
  const _OrderGroupedOption(this.groupKey, this.optionKey, this.label);

  final String groupKey;
  final String optionKey;
  final String label;
}

class _OrderWearOption {
  const _OrderWearOption({
    required this.key,
    required this.label,
    required this.min,
    required this.max,
  });

  final String key;
  final String label;
  final double min;
  final double max;
}

class _OrderSortChoice {
  const _OrderSortChoice({
    required this.field,
    required this.asc,
    required this.label,
  });

  final String field;
  final bool asc;
  final String label;
}

class _OrderFilterLoadingBlock extends StatelessWidget {
  const _OrderFilterLoadingBlock();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        _OrderLoadingSection(carded: false, height: 118),
        SizedBox(height: 24),
        _OrderLoadingSection(carded: true, height: 142),
        SizedBox(height: 24),
        _OrderLoadingSection(carded: true, height: 168),
      ],
    );
  }
}

class _OrderLoadingSection extends StatelessWidget {
  const _OrderLoadingSection({required this.carded, required this.height});

  final bool carded;
  final double height;

  @override
  Widget build(BuildContext context) {
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
          child: Container(
            width: 112,
            height: 14,
            decoration: BoxDecoration(
              color: const Color(0xFFE8EDF3),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
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

enum _OrderFilterSectionType { attribute, price, status, date, sort }

class _OrderFilterSection {
  const _OrderFilterSection({required this.type, required this.labelKey});

  final _OrderFilterSectionType type;
  final String labelKey;

  String get key => labelKey;
}
