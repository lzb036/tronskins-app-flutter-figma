import 'package:get/get.dart';
import 'package:tronskins_app/api/help.dart';
import 'package:tronskins_app/api/model/help/help_models.dart';

class HelpController extends GetxController {
  HelpController({ApiHelpServer? api}) : _api = api ?? ApiHelpServer();

  final ApiHelpServer _api;

  final RxList<HelpCategory> categories = <HelpCategory>[].obs;
  final RxList<HelpItem> helpItems = <HelpItem>[].obs;
  final RxMap<String, List<HelpItem>> categoryItemsByCode =
      <String, List<HelpItem>>{}.obs;

  final RxBool categoryLoading = false.obs;
  final RxBool listLoading = false.obs;
  final RxBool overviewLoading = false.obs;

  Future<void> loadCategories() async {
    if (categoryLoading.value) return;
    categoryLoading.value = true;
    try {
      final res = await _api.categoryList();
      if (res.success && res.datas != null) {
        categories.assignAll(res.datas!);
      }
    } finally {
      categoryLoading.value = false;
    }
  }

  Future<void> loadCenterOverview() async {
    if (overviewLoading.value) return;
    if (categories.isEmpty) {
      await loadCategories();
    }
    if (categories.isEmpty) {
      return;
    }

    overviewLoading.value = true;
    try {
      final results = await Future.wait(
        categories.map(_loadCategoryOverviewEntry),
      );
      categoryItemsByCode.assignAll({
        for (final entry in results)
          if (entry.key.isNotEmpty) entry.key: entry.value,
      });
    } finally {
      overviewLoading.value = false;
    }
  }

  Future<void> loadHelpList(String categoryCode) async {
    if (categoryItemsByCode.containsKey(categoryCode)) {
      helpItems.assignAll(categoryItemsByCode[categoryCode] ?? const []);
      return;
    }
    if (listLoading.value) return;
    listLoading.value = true;
    try {
      final res = await _api.helpList(categoryCode: categoryCode);
      if (res.success && res.datas != null) {
        final items = List<HelpItem>.unmodifiable(res.datas!);
        helpItems.assignAll(items);
        categoryItemsByCode[categoryCode] = items;
      } else {
        helpItems.clear();
        categoryItemsByCode[categoryCode] = const <HelpItem>[];
      }
    } finally {
      listLoading.value = false;
    }
  }

  bool hasOverviewForCategory(String? categoryCode) {
    if (categoryCode == null || categoryCode.isEmpty) {
      return false;
    }
    return categoryItemsByCode.containsKey(categoryCode);
  }

  int articleCountForCategory(String? categoryCode) {
    if (categoryCode == null || categoryCode.isEmpty) {
      return 0;
    }
    return categoryItemsByCode[categoryCode]?.length ?? 0;
  }

  List<HelpItem> popularItems({String? categoryCode, int limit = 5}) {
    if (limit <= 0) {
      return const <HelpItem>[];
    }

    if (categoryCode != null && categoryCode.isNotEmpty) {
      final scopedItems = categoryItemsByCode[categoryCode] ?? const [];
      return List<HelpItem>.unmodifiable(scopedItems.take(limit));
    }

    final buckets = categories
        .map((category) => category.categoryCode ?? '')
        .where((code) => code.isNotEmpty)
        .map((code) => categoryItemsByCode[code] ?? const <HelpItem>[])
        .where((items) => items.isNotEmpty)
        .map((items) => List<HelpItem>.from(items))
        .toList();

    if (buckets.isEmpty) {
      return const <HelpItem>[];
    }

    final merged = <HelpItem>[];
    var cursor = 0;
    while (merged.length < limit) {
      var inserted = false;
      for (final bucket in buckets) {
        if (cursor >= bucket.length) {
          continue;
        }
        merged.add(bucket[cursor]);
        inserted = true;
        if (merged.length >= limit) {
          break;
        }
      }
      if (!inserted) {
        break;
      }
      cursor += 1;
    }

    return List<HelpItem>.unmodifiable(merged);
  }

  Future<MapEntry<String, List<HelpItem>>> _loadCategoryOverviewEntry(
    HelpCategory category,
  ) async {
    final categoryCode = category.categoryCode ?? '';
    if (categoryCode.isEmpty) {
      return const MapEntry('', <HelpItem>[]);
    }
    try {
      final res = await _api.helpList(categoryCode: categoryCode);
      final items = res.success && res.datas != null
          ? List<HelpItem>.unmodifiable(res.datas!)
          : const <HelpItem>[];
      return MapEntry(categoryCode, items);
    } catch (_) {
      return const MapEntry('', <HelpItem>[]);
    }
  }
}
