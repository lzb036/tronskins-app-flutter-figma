import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tronskins_app/common/hooks/currency/CurrencyController.dart';
import 'package:tronskins_app/components/filter/filter_models.dart';
import 'package:tronskins_app/components/filter/filter_price_support.dart';
import 'package:tronskins_app/components/filter/filter_sheet_style.dart';

class PriceSortFilterSheet extends StatefulWidget {
  const PriceSortFilterSheet({
    super.key,
    required this.sortOptions,
    required this.initial,
    this.titleKey = 'app.market.filter.text',
    this.showPriceRange = true,
    this.showSort = true,
    this.showInventoryStateFilters = false,
  });

  final List<SortOption> sortOptions;
  final PriceSortFilterResult initial;
  final String titleKey;
  final bool showPriceRange;
  final bool showSort;
  final bool showInventoryStateFilters;

  @override
  State<PriceSortFilterSheet> createState() => _PriceSortFilterSheetState();
}

class _PriceSortFilterSheetState extends State<PriceSortFilterSheet> {
  late String _sortField;
  late bool _sortAsc;
  late bool _sellableOnly;
  late bool _coolingOnly;
  late final TextEditingController _minController;
  late final TextEditingController _maxController;
  final Map<String, GlobalKey> _selectionAnchorKeys = {};
  CurrencyController get _currency => Get.find<CurrencyController>();

  @override
  void initState() {
    super.initState();
    _sortField = widget.initial.sortField;
    _sortAsc = widget.initial.sortAsc;
    _sellableOnly = widget.initial.sellableOnly;
    _coolingOnly = widget.initial.coolingOnly;
    _minController = TextEditingController(
      text: _initialPriceText(widget.initial.priceMin),
    );
    _maxController = TextEditingController(
      text: _initialPriceText(widget.initial.priceMax),
    );
  }

  @override
  void dispose() {
    _minController.dispose();
    _maxController.dispose();
    super.dispose();
  }

  void _reset() {
    setState(() {
      _sortField = _defaultSortField();
      _sortAsc = _defaultSortAsc();
      _sellableOnly = false;
      _coolingOnly = false;
      _minController.text = '';
      _maxController.text = '';
    });
  }

  void _apply() {
    final min = _parseDisplayPriceOrNull(_minController.text);
    final max = _parseDisplayPriceOrNull(_maxController.text);
    Navigator.of(context).pop(
      PriceSortFilterResult(
        sortField: _sortField,
        sortAsc: _sortAsc,
        priceMin: min,
        priceMax: max,
        sellableOnly: _sellableOnly,
        coolingOnly: _coolingOnly,
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
    if (widget.showInventoryStateFilters && _sellableOnly) {
      count += 1;
    }
    if (widget.showInventoryStateFilters && _coolingOnly) {
      count += 1;
    }
    return count;
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

  List<_PriceSortSection> get _sections {
    final sections = <_PriceSortSection>[];
    if (widget.showSort) {
      sections.add(
        const _PriceSortSection(
          type: _PriceSortSectionType.sort,
          labelKey: 'app.market.filter.sort',
        ),
      );
    }
    if (widget.showPriceRange) {
      sections.add(
        const _PriceSortSection(
          type: _PriceSortSectionType.price,
          labelKey: 'app.market.filter.price_range',
        ),
      );
    }
    if (widget.showInventoryStateFilters) {
      sections.add(
        const _PriceSortSection(
          type: _PriceSortSectionType.state,
          labelKey: 'app.trade.order.status',
        ),
      );
    }
    return sections;
  }

  GlobalKey _selectionAnchorKey(String sectionKey, String optionName) {
    final key = '$sectionKey::$optionName';
    return _selectionAnchorKeys.putIfAbsent(key, GlobalKey.new);
  }

  Widget _buildSortSection(_PriceSortSection section) {
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

  Widget _buildInventoryStateSection(_PriceSortSection section) {
    Widget buildStateChip({
      required String key,
      required String label,
      required bool selected,
      required VoidCallback onTap,
    }) {
      return KeyedSubtree(
        key: _selectionAnchorKey(section.key, key),
        child: FilterSheetOptionChip(
          label: label,
          selected: selected,
          onTap: onTap,
        ),
      );
    }

    return FilterSheetSection(
      title: 'app.trade.order.status'.tr,
      carded: false,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          buildStateChip(
            key: 'all',
            label: 'app.market.filter.all'.tr,
            selected: !_sellableOnly && !_coolingOnly,
            onTap: () => setState(() {
              _sellableOnly = false;
              _coolingOnly = false;
            }),
          ),
          buildStateChip(
            key: 'sellable',
            label: 'app.market.product.sellable'.tr,
            selected: _sellableOnly,
            onTap: () => setState(() {
              final next = !_sellableOnly;
              _sellableOnly = next;
              _coolingOnly = false;
            }),
          ),
          buildStateChip(
            key: 'cooling',
            label: 'app.market.product.cooling'.tr,
            selected: _coolingOnly,
            onTap: () => setState(() {
              final next = !_coolingOnly;
              _coolingOnly = next;
              _sellableOnly = false;
            }),
          ),
        ],
      ),
    );
  }

  List<_PriceSortChoice> _buildSortChoices() {
    final choices = <_PriceSortChoice>[];
    final seenStates = <String>{};

    void push(_PriceSortChoice choice) {
      final stateKey = '${choice.field}:${choice.asc}';
      if (seenStates.add(stateKey)) {
        choices.add(choice);
      }
    }

    push(
      _PriceSortChoice(
        field: _defaultSortField(),
        asc: _defaultSortAsc(),
        label: 'app.market.filter.default'.tr,
      ),
    );

    final hasPrice = widget.sortOptions.any(
      (option) => option.field == 'price',
    );
    if (hasPrice) {
      push(
        _PriceSortChoice(
          field: 'price',
          asc: true,
          label: _localizedPriceSortLabel(asc: true),
        ),
      );
      push(
        _PriceSortChoice(
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
            _PriceSortChoice(
              field: option.field,
              asc: false,
              label: _localizedHotSortLabel(option),
            ),
          );
          continue;
        case 'time':
        case 'upTime':
          push(
            _PriceSortChoice(
              field: option.field,
              asc: false,
              label: _localizedNewestSortLabel(option),
            ),
          );
          continue;
        default:
          push(
            _PriceSortChoice(
              field: option.field,
              asc: false,
              label: option.labelKey.tr,
            ),
          );
      }
    }
    if (choices.isEmpty) {
      choices.add(
        _PriceSortChoice(
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
    return raw.clamp(0.0, math.max(0.0, maxLeft));
  }

  String _localizedPriceSortLabel({required bool asc}) {
    if (Get.locale?.languageCode == 'en') {
      return asc ? 'Price Low to High' : 'Price High to Low';
    }
    return '${'app.market.filter.price'.tr} ${asc ? '↑' : '↓'}';
  }

  String _localizedNewestSortLabel(SortOption option) {
    if (Get.locale?.languageCode == 'en') {
      return 'Newest Listed';
    }
    return option.labelKey.tr;
  }

  String _localizedHotSortLabel(SortOption option) {
    if (Get.locale?.languageCode == 'en') {
      return 'Most Popular';
    }
    return option.labelKey.tr;
  }

  Widget _buildSectionContent(_PriceSortSection section) {
    switch (section.type) {
      case _PriceSortSectionType.sort:
        return _buildSortSection(section);
      case _PriceSortSectionType.price:
        return _buildPriceSection();
      case _PriceSortSectionType.state:
        return _buildInventoryStateSection(section);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sections = _sections;
    return FilterSheetFrame(
      title: widget.titleKey.tr,
      resetLabel: 'app.market.filter.reset'.tr,
      onReset: _reset,
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

enum _PriceSortSectionType { sort, price, state }

class _PriceSortSection {
  const _PriceSortSection({required this.type, required this.labelKey});

  final _PriceSortSectionType type;
  final String labelKey;

  String get key => labelKey;
}

class _PriceSortChoice {
  const _PriceSortChoice({
    required this.field,
    required this.asc,
    required this.label,
  });

  final String field;
  final bool asc;
  final String label;
}
