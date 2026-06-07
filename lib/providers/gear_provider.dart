import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/app_database.dart';
import '../models/gear.dart';
import '../utils/string_utils.dart';
import 'category_provider.dart';
import 'database_providers.dart';
import 'packing_provider.dart';

enum GearSortOption {
  manual('手動並び替え'),
  nameAsc('名前（昇順）'),
  nameDesc('名前（降順）'),
  weightDesc('重量（重い順）'),
  weightAsc('重量（軽い順）'),
  categoryAsc('カテゴリ');

  final String label;
  const GearSortOption(this.label);
}

double gearLineWeight(Gear g) => (g.weight ?? 0) * g.quantity;

class GearState {
  final List<Gear> items;
  final int? filterCategoryId;
  final String searchQuery;
  final GearSortOption sortOption;
  final bool loaded;

  const GearState({
    this.items = const [],
    this.filterCategoryId,
    this.searchQuery = '',
    this.sortOption = GearSortOption.manual,
    this.loaded = false,
  });

  GearState copyWith({
    List<Gear>? items,
    int? filterCategoryId,
    bool clearFilter = false,
    String? searchQuery,
    GearSortOption? sortOption,
    bool? loaded,
  }) {
    return GearState(
      items: items ?? this.items,
      filterCategoryId:
          clearFilter ? null : (filterCategoryId ?? this.filterCategoryId),
      searchQuery: searchQuery ?? this.searchQuery,
      sortOption: sortOption ?? this.sortOption,
      loaded: loaded ?? this.loaded,
    );
  }

  List<Gear> displayItems(CategoryState categories) {
    // フィルタリング
    var list = filterCategoryId == null
        ? List<Gear>.of(items)
        : items.where((g) => g.categoryId == filterCategoryId).toList();

    final q = StringUtils.normalizeForSearch(searchQuery);
    if (q.isNotEmpty) {
      list = list.where((g) {
        final name = StringUtils.normalizeForSearch(g.name);
        final note = StringUtils.normalizeForSearch(g.note ?? '');
        final mfr = StringUtils.normalizeForSearch(g.manufacturer ?? '');
        return name.contains(q) || note.contains(q) || mfr.contains(q);
      }).toList();
    }

    // ソート
    switch (sortOption) {
      case GearSortOption.manual:
        list.sort((a, b) {
          final o = a.sortOrder.compareTo(b.sortOrder);
          return o != 0 ? o : a.name.compareTo(b.name);
        });
      case GearSortOption.nameAsc:
        list.sort((a, b) => a.name.compareTo(b.name));
      case GearSortOption.nameDesc:
        list.sort((a, b) => b.name.compareTo(a.name));
      case GearSortOption.weightDesc:
        list.sort(
          (a, b) => gearLineWeight(b).compareTo(gearLineWeight(a)),
        );
      case GearSortOption.weightAsc:
        list.sort(
          (a, b) => gearLineWeight(a).compareTo(gearLineWeight(b)),
        );
      case GearSortOption.categoryAsc:
        list.sort((a, b) {
          final c = a.categoryName.compareTo(b.categoryName);
          return c != 0 ? c : a.name.compareTo(b.name);
        });
    }

    // 手動並び替えかつフィルタリングなしの場合のみ親子階層を表示
    if (sortOption == GearSortOption.manual &&
        filterCategoryId == null &&
        q.isEmpty) {
      return _buildHierarchy(list);
    }

    return list;
  }

  List<Gear> _buildHierarchy(List<Gear> flatList) {
    final result = <Gear>[];
    final childrenOf = <int, List<Gear>>{};
    final roots = <Gear>[];

    for (final g in flatList) {
      if (g.parentId == null) {
        roots.add(g);
      } else {
        childrenOf.putIfAbsent(g.parentId!, () => []).add(g);
      }
    }

    void addWithChildren(Gear parent) {
      result.add(parent);
      final children = childrenOf[parent.id];
      if (children != null) {
        // 子要素も sortOrder 順に並べる
        children.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
        for (final child in children) {
          addWithChildren(child);
        }
      }
    }

    for (final root in roots) {
      addWithChildren(root);
    }

    // 万が一親が見つからない浮いた子がいる場合は末尾に追加
    final addedIds = result.map((g) => g.id).toSet();
    for (final g in flatList) {
      if (!addedIds.contains(g.id)) {
        result.add(g);
      }
    }

    return result;
  }

  double filteredTotalWeight(List<Gear> displayed) {
    // 親子構造の場合、親の重さに子の重さが含まれるべきかどうかは運用次第だが、
    // ここでは単純に表示されている全アイテムの合計を出す（親子で重複カウントしないよう注意が必要かもしれないが、
    // 現状は全アイテムがリストに1回ずつ登場するのでこれでOK）
    return displayed.fold(0.0, (sum, g) => sum + gearLineWeight(g));
  }

  bool get hasActiveFilters =>
      filterCategoryId != null ||
      searchQuery.trim().isNotEmpty ||
      sortOption != GearSortOption.manual;

  String? filterCategoryName(CategoryState categories) {
    if (filterCategoryId == null) return null;
    return categories.byId(filterCategoryId!)?.name;
  }
}

class GearNotifier extends Notifier<GearState> {
  AppDatabase get _db => ref.read(appDatabaseProvider);

  @override
  GearState build() => const GearState();

  Future<void> load() async {
    final items = await _db.getAllGear();
    state = state.copyWith(items: items, loaded: true);
  }

  Future<void> reloadCategoryNames() async {
    await load();
  }

  Future<void> add(Gear gear) async {
    final id = await _db.insertGear(gear);
    final saved = gear.copyWith(id: id);
    state = state.copyWith(items: [...state.items, saved]);
  }

  Future<void> update(Gear gear) async {
    await _db.updateGear(gear);
    state = state.copyWith(
      items: [
        for (final g in state.items) if (g.id == gear.id) gear else g,
      ],
    );
  }

  Future<void> remove(int id) async {
    await _db.deleteGear(id);
    state = state.copyWith(
      items: state.items.where((g) => g.id != id).toList(),
    );
    await ref.read(packingProvider.notifier).onGearRemoved(id);
  }

  Future<void> updateParent(int childId, int? parentId) async {
    final gear = state.items.firstWhere((g) => g.id == childId);
    final updated = gear.copyWith(parentId: parentId, clearParentId: parentId == null);
    await _db.updateGear(updated);
    state = state.copyWith(
      items: [
        for (final g in state.items) if (g.id == childId) updated else g,
      ],
    );
  }

  void setFilterCategoryId(int? categoryId) {
    state = state.copyWith(
      filterCategoryId: categoryId,
      clearFilter: categoryId == null,
    );
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void setSortOption(GearSortOption option) {
    state = state.copyWith(sortOption: option);
  }

  Future<void> reorderItems(List<int> orderedIds) async {
    await _db.updateGearSortOrder(orderedIds);
    final orderIndex = {for (var i = 0; i < orderedIds.length; i++) orderedIds[i]: i};
    state = state.copyWith(
      items: [
        for (final g in state.items)
          g.copyWith(sortOrder: orderIndex[g.id] ?? g.sortOrder),
      ]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder)),
      sortOption: GearSortOption.manual,
    );
  }
}

final gearProvider = NotifierProvider<GearNotifier, GearState>(GearNotifier.new);
