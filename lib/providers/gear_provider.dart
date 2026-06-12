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

    // 標準（格納順）かつフィルタリングなしの場合のみ親子階層を表示
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

  /// 親子構造を維持した格納の実行
  Future<void> reorderItemsWithHierarchy({
    required int movedId,
    required int targetId,
    required int mode, // 1: 上, 2: 内, 3: 下
  }) async {
    final allItems = List<Gear>.from(state.items);
    
    // 1. 移動対象とその全子孫を特定（連続したブロックとして抽出）
    final movedIdx = allItems.indexWhere((g) => g.id == movedId);
    if (movedIdx == -1) return;

    final List<Gear> movingBlock = [allItems[movedIdx]];
    
    // 子孫を抽出する（現在のソート順で連続していることを前提とする）
    int i = movedIdx + 1;
    while (i < allItems.length) {
      if (_isDescendantOf(allItems[i], movedId, allItems)) {
        movingBlock.add(allItems[i]);
        i++;
      } else {
        break;
      }
    }

    // 元の位置からブロックを削除
    allItems.removeRange(movedIdx, movedIdx + movingBlock.length);

    // 2. 挿入位置と新しい親の決定
    final targetGear = allItems.firstWhere((g) => g.id == targetId);
    final targetIdx = allItems.indexWhere((g) => g.id == targetId);
    
    int insertIdx;
    int? newParentId;

    if (mode == 2) {
      // 格納: ターゲットの直後に挿入、親はターゲット自身
      insertIdx = targetIdx + 1;
      newParentId = targetId;
    } else if (mode == 1) {
      // 上に挿入: ターゲットの位置に挿入、親はターゲットと同じ
      insertIdx = targetIdx;
      newParentId = targetGear.parentId;
    } else {
      // 下に挿入: ターゲットとその子孫の後に挿入、親はターゲットと同じ
      insertIdx = targetIdx + 1;
      while (insertIdx < allItems.length &&
          _isDescendantOf(allItems[insertIdx], targetId, allItems)) {
        insertIdx++;
      }
      newParentId = targetGear.parentId;
    }

    // 指定位置にブロックを挿入
    allItems.insertAll(insertIdx, movingBlock);

    // 3. 移動主体の親 ID を更新
    final updatedMovingBlock = movingBlock.map((g) {
      if (g.id == movedId) {
        return g.copyWith(parentId: newParentId, clearParentId: newParentId == null);
      }
      return g;
    }).toList();
    
    // リスト内の該当箇所を差し替え
    allItems.replaceRange(insertIdx, insertIdx + movingBlock.length, updatedMovingBlock);

    // 4. 全アイテムの sort_order をリストの順序に従って 0 から振り直し
    final finalItems = <Gear>[];
    for (int j = 0; j < allItems.length; j++) {
      finalItems.add(allItems[j].copyWith(sortOrder: j));
    }

    // 5. DB の更新 (トランザクション的に一括更新)
    // まず移動主体の親を更新
    await _db.updateGear(finalItems.firstWhere((g) => g.id == movedId));
    // 全体の sort_order を更新
    await _db.updateGearSortOrder(finalItems.map((g) => g.id!).toList());

    // 5.5 積載場所の同期 (現在アクティブなパッキングセットがあれば)
    if (newParentId != null) {
      await ref.read(packingProvider.notifier).syncPlacementWithParent(movedId, newParentId);
    }

    // 6. 状態の反映
    state = state.copyWith(items: finalItems);
    print('DEBUG: Reorder Complete. New Order: ${finalItems.map((g) => "${g.name}(P:${g.parentId}, S:${g.sortOrder})").join(", ")}');
  }

  bool _isDescendantOf(Gear gear, int potentialParentId, List<Gear> allItems) {
    int? currentParentId = gear.parentId;
    while (currentParentId != null) {
      if (currentParentId == potentialParentId) return true;
      final parent = allItems.firstWhere(
        (g) => g.id == currentParentId,
        orElse: () => gear,
      );
      if (parent.id == gear.id) break;
      currentParentId = parent.parentId;
    }
    return false;
  }

  Future<void> reorderItems(List<int> orderedIds, {int? movedId, int? newParentId, bool clearParent = false}) async {
    // 既存の reorderItems は下位互換のために残すが、今後は reorderItemsWithHierarchy を推奨
    if (movedId != null) {
      await reorderItemsWithHierarchy(
        movedId: movedId,
        targetId: orderedIds.firstWhere((id) => id != movedId), // 暫定
        mode: 1, 
      );
      return;
    }
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
