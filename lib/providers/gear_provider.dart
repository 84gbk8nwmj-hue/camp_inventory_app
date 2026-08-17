import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/app_database.dart';
import '../models/gear.dart';
import '../utils/string_utils.dart';
import 'category_provider.dart';
import 'database_providers.dart';
import 'packing_provider.dart';

enum GearSortOption {
  manual('標準'),
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

    // 常に階層構造を構築し、指定されたソートオプションを適用
    return _buildHierarchy(list, sortOption, categories);
  }

  List<Gear> _buildHierarchy(
    List<Gear> flatList,
    GearSortOption sortOption,
    CategoryState categories,
  ) {
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
        children.sort(_getComparator(sortOption, categories));
        for (final child in children) {
          addWithChildren(child);
        }
      }
    }

    roots.sort(_getComparator(sortOption, categories));
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
  Comparator<Gear> _getComparator(GearSortOption option, CategoryState categories) {
    return (a, b) {
      switch (option) {
        case GearSortOption.manual:
          return a.sortOrder.compareTo(b.sortOrder);
        case GearSortOption.nameAsc:
          return a.name.compareTo(b.name);
        case GearSortOption.nameDesc:
          return b.name.compareTo(a.name);
        case GearSortOption.weightDesc:
          return gearLineWeight(b).compareTo(gearLineWeight(a));
        case GearSortOption.weightAsc:
          return gearLineWeight(a).compareTo(gearLineWeight(b));
        case GearSortOption.categoryAsc:
          // categoryName は CategoryState から取得する必要があるため、categories を引数として渡す
          final categoryNameA = categories.byId(a.categoryId!)?.name ?? '';
          final categoryNameB = categories.byId(b.categoryId!)?.name ?? '';
          final c = categoryNameA.compareTo(categoryNameB);
          return c != 0 ? c : a.name.compareTo(b.name);
      }
    };
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
    
    // 積載場所の同期
    if (parentId != null) {
      await ref.read(packingProvider.notifier).syncPlacementWithParent(childId, parentId);
    }
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

  Future<void> unnestItem(int childId) async {
    // このアイテム自体の親子関係を解除する
    await updateParent(childId, null);
  }

  List<Gear> getParentCandidates(int gearId) {
    // 自分自身とその子孫を除外したリストを返す
    final descendants = _getDescendantIds(gearId);
    return state.items
        .where((g) => g.id != gearId && !descendants.contains(g.id))
        .toList();
  }

  Set<int> _getDescendantIds(int parentId) {
    final ids = <int>{};
    final children = state.items.where((g) => g.parentId == parentId).toList();
    for (final child in children) {
      if (child.id != null) {
        ids.add(child.id!);
        ids.addAll(_getDescendantIds(child.id!));
      }
    }
    return ids;
  }

  Future<void> reorderWithSubtree(int oldIndex, int newIndex, CategoryState categories) async {
    final list = state.displayItems(categories);
    if (oldIndex == newIndex) return;

    // ReorderableListViewの一般的な挙動に合わせて、newIndexがoldIndexより大きい場合は調整
    // アイテムが削除されてから挿入されるため、newIndexが1つずれる
    if (oldIndex < newIndex) {
      newIndex--;
    }

    final movingItem = list[oldIndex];

    if (movingItem.parentId == null) {
      // ケース A: 親ギアの並び替え（サブツリー全体を移動）
      final subtree = <Gear>[movingItem];
      final subtreeIds = {movingItem.id};

      int j = oldIndex + 1;
      while (j < list.length) {
        final item = list[j];
        if (item.parentId != null && subtreeIds.contains(item.parentId)) {
          subtree.add(item);
          subtreeIds.add(item.id);
          j++;
        } else {
          break;
        }
      }

      final newList = List<Gear>.from(list);
      newList.removeRange(oldIndex, oldIndex + subtree.length);
      newList.insertAll(newIndex, subtree);

      // parentId の更新は行わないため、関連ロジックを削除

      final orderedIds = newList.map((g) => g.id!).toList();
      await reorderItems(orderedIds);
    } else {
      // ケース B: 子ギアの並び替え（同じ親を持つ子ギア内でのみ移動）
      final currentParentId = movingItem.parentId!;

      // 移動先インデックスがリストの範囲外の場合、または移動元の親がリストに存在しない場合
      if (newIndex < 0 || newIndex >= list.length || !list.any((g) => g.id == currentParentId)) {
        return; // 不正な移動
      }

      final targetItem = list[newIndex];

      // 制約チェック:
      // 1. 移動先が親ギアの場合、その親ギアがmovingItemの現在の親でなければならない
      // 2. 移動先が子ギアの場合、その子ギアの親がmovingItemの現在の親でなければならない
      // 3. ルートレベルへの移動を阻止 (movingItemが子ギアの場合)
      if (targetItem.id != currentParentId && targetItem.parentId != currentParentId) {
        return; // 別の親の配下やルートへの不正な移動
      }
      
      // 移動先が、現在移動しようとしている子ギアの親ギアである場合（親ギアの直上への移動）
      // このケースは、targetItem.id == currentParentId の場合に該当する。
      // この場合、その親の直下の位置に移動することになるが、
      // ReorderableListViewの挙動上、親ギアのすぐ下に子ギアが来ることは自然なため、許容する。
      // ただし、子ギアは自分の親ギアの配下から出ない、という制約を優先する。
      // すでに上記で targetItem.id != currentParentId のチェックがあるため、
      // targetItemが親ギアである場合は、currentParentIdと一致しなければ不正となる。

      final newList = List<Gear>.from(list);
      final movedGear = newList.removeAt(oldIndex);
      newList.insert(newIndex, movedGear);

      // parentId の変更は行わないため、関連ロジックを削除

      final orderedIds = newList.map((g) => g.id!).toList();
      await reorderItems(orderedIds);
    }
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
