import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/app_database.dart';
import '../models/gear.dart';
import '../models/packing_set.dart';
import 'database_providers.dart';
import 'gear_provider.dart';

class PackingGearView {
  final Gear gear;
  final bool isPacked;
  final int sortOrder;
  final int? placementId;

  const PackingGearView({
    required this.gear,
    required this.isPacked,
    required this.sortOrder,
    this.placementId,
  });

  double get lineWeight => gearLineWeight(gear);
}

class PackingState {
  final List<PackingSet> sets;
  final int? activeSetId;
  final Map<int, PackingSetItem> activeItems;
  final List<PackingPlacement> activePlacements; // アクティブなセットの配置場所
  final bool loaded;

  const PackingState({
    this.sets = const [],
    this.activeSetId,
    this.activeItems = const {},
    this.activePlacements = const [],
    this.loaded = false,
  });

  PackingState copyWith({
    List<PackingSet>? sets,
    int? activeSetId,
    bool clearActiveSet = false,
    Map<int, PackingSetItem>? activeItems,
    List<PackingPlacement>? activePlacements,
    bool? loaded,
  }) {
    return PackingState(
      sets: sets ?? this.sets,
      activeSetId: clearActiveSet ? null : (activeSetId ?? this.activeSetId),
      activeItems: activeItems ?? this.activeItems,
      activePlacements: activePlacements ?? this.activePlacements,
      loaded: loaded ?? this.loaded,
    );
  }

  PackingSet? get activeSet {
    if (activeSetId == null) return null;
    for (final s in sets) {
      if (s.id == activeSetId) return s;
    }
    return null;
  }

  List<PackingGearView> viewsFor(List<Gear> allGear) {
    final gearById = {for (final g in allGear) g.id!: g};
    final views = <PackingGearView>[];
    for (final entry in activeItems.values) {
      final gear = gearById[entry.gearId];
      if (gear != null) {
        views.add(PackingGearView(
          gear: gear,
          isPacked: entry.isPacked,
          sortOrder: entry.sortOrder,
          placementId: entry.placementId,
        ));
      }
    }

    // 配置場所の順序マップを作成 (id -> index)
    final placementOrder = {
      for (int i = 0; i < activePlacements.length; i++)
        activePlacements[i].id!: i
    };

    // 基本的なソート（配置場所 > sortOrder）
    views.sort((a, b) {
      final orderA = a.placementId == null ? -1 : (placementOrder[a.placementId] ?? 999);
      final orderB = b.placementId == null ? -1 : (placementOrder[b.placementId] ?? 999);
      if (orderA != orderB) return orderA.compareTo(orderB);
      
      final so = a.sortOrder.compareTo(b.sortOrder);
      if (so != 0) return so;
      return a.gear.name.compareTo(b.gear.name);
    });

    // 親子階層の構築
    return _buildHierarchicalViews(views);
  }

  List<PackingGearView> _buildHierarchicalViews(List<PackingGearView> flatList) {
    final result = <PackingGearView>[];
    final childrenOf = <int, List<PackingGearView>>{};
    final roots = <PackingGearView>[];

    for (final v in flatList) {
      if (v.gear.parentId == null) {
        roots.add(v);
      } else {
        childrenOf.putIfAbsent(v.gear.parentId!, () => []).add(v);
      }
    }

    void addWithChildren(PackingGearView parent) {
      result.add(parent);
      final children = childrenOf[parent.gear.id];
      if (children != null) {
        // 子要素も元の順序（配置場所 > sortOrder）を維持
        for (final child in children) {
          addWithChildren(child);
        }
      }
    }

    for (final root in roots) {
      addWithChildren(root);
    }

    // 親が含まれていない孤立した子がいる場合（親がこのセットに含まれていない場合など）を末尾に追加
    final addedIds = result.map((v) => v.gear.id).toSet();
    for (final v in flatList) {
      if (!addedIds.contains(v.gear.id)) {
        result.add(v);
      }
    }

    return result;
  }

  /// 特定の配置場所に属するギアのリストを取得
  List<PackingGearView> viewsInPlacement(int? placementId, List<Gear> allGear) {
    return viewsFor(allGear).where((v) => v.placementId == placementId).toList();
  }

  /// 特定の配置場所の合計重量を計算（g）
  double placementWeight(int? placementId, List<Gear> allGear) {
    return viewsInPlacement(placementId, allGear)
        .fold(0.0, (sum, v) => sum + v.lineWeight);
  }

  int get packedCount => activeItems.values.where((e) => e.isPacked).length;
  int get totalCount => activeItems.length;

  double totalWeight(List<Gear> allGear) {
    return viewsFor(allGear).fold(0.0, (sum, v) => sum + v.lineWeight);
  }
}

class PackingNotifier extends Notifier<PackingState> {
  AppDatabase get _db => ref.read(appDatabaseProvider);

  @override
  PackingState build() => const PackingState();

  Future<void> load() async {
    final sets = await _db.getPackingSets();
    var activeId = await _db.getActivePackingSetId();
    if (activeId == null && sets.isNotEmpty) {
      activeId = sets.first.id;
      await _db.setActivePackingSetId(activeId);
    }
    Map<int, PackingSetItem> items = {};
    List<PackingPlacement> placements = [];
    if (activeId != null) {
      final list = await _db.getPackingSetItems(activeId);
      items = {for (final i in list) i.gearId: i};
      placements = await _db.getPlacements(activeId);
    }
    state = PackingState(
      sets: sets,
      activeSetId: activeId,
      activeItems: items,
      activePlacements: placements,
      loaded: true,
    );
  }

  Future<void> _applySetItems(int? setId) async {
    if (setId == null) {
      state = state.copyWith(
        clearActiveSet: true,
        activeItems: {},
        activePlacements: [],
      );
      return;
    }
    final list = await _db.getPackingSetItems(setId);
    final placements = await _db.getPlacements(setId);
    state = state.copyWith(
      activeSetId: setId,
      activeItems: {for (final i in list) i.gearId: i},
      activePlacements: placements,
    );
  }

  Future<void> selectSet(int setId) async {
    await _db.setActivePackingSetId(setId);
    await _applySetItems(setId);
  }

  Future<Set<int>> loadIncludedIds(int setId) async {
    final list = await _db.getPackingSetItems(setId);
    return list.map((i) => i.gearId).toSet();
  }

  Future<int> createSet(String name) async {
    final id = await _db.insertPackingSet(name.trim());
    await load();
    await selectSet(id);
    return id;
  }

  Future<void> renameSet(int id, String name) async {
    await _db.renamePackingSet(id, name.trim());
    await load();
  }

  Future<void> deleteSet(int id) async {
    await _db.deletePackingSet(id);
    final wasActive = state.activeSetId == id;
    await load();
    if (wasActive && state.sets.isNotEmpty) {
      await selectSet(state.sets.first.id!);
    }
  }

  Future<void> duplicateSet(int sourceId, String newName) async {
    await _db.duplicatePackingSet(sourceId, newName.trim());
    await load();
  }

  // --- Items ---

  Future<void> setIncludedForSet(int setId, int gearId, bool included) async {
    final gearItems = ref.read(gearProvider).items;

    Future<void> updateRecursive(int currentId, bool targetValue) async {
      await _db.setPackingItemIncluded(setId, currentId, targetValue);
      
      // 子ギアを探して再帰的に更新
      final children = gearItems.where((g) => g.parentId == currentId);
      for (final child in children) {
        if (child.id != null) {
          await updateRecursive(child.id!, targetValue);
        }
      }
    }

    await updateRecursive(gearId, included);

    if (state.activeSetId == setId) {
      await _applySetItems(setId);
    }
    await _refreshSetsMeta();
  }

  Future<void> setPackedForSet(int setId, int gearId, bool isPacked) async {
    final gearItems = ref.read(gearProvider).items;

    Future<void> updateRecursive(int currentId, bool targetValue) async {
      await _db.setPackingItemPacked(setId, currentId, targetValue);
      
      // 子ギアを探して再帰的に更新（ただし、そのセットに含まれている場合のみ）
      final children = gearItems.where((g) => g.parentId == currentId);
      for (final child in children) {
        if (child.id != null && state.activeItems.containsKey(child.id)) {
          await updateRecursive(child.id!, targetValue);
        }
      }
    }

    await updateRecursive(gearId, isPacked);

    if (state.activeSetId == setId) {
      await _applySetItems(setId);
    }
  }

  Future<void> setPlacementForGear(int setId, int gearId, int? placementId) async {
    // 親子関係の解消チェック
    final gear = ref.read(gearProvider).items.where((g) => g.id == gearId).firstOrNull;
    if (gear != null && gear.parentId != null) {
      final parentItem = state.activeItems[gear.parentId];
      // 親がこのセットに含まれており、かつ移動先の配置場所が親の配置場所と異なる場合、親子関係を解消する
      if (parentItem != null && parentItem.placementId != placementId) {
        await ref.read(gearProvider.notifier).updateParent(gearId, null);
      }
    }

    // 再帰的に子ギアを更新するためのヘルパー
    Future<void> updateRecursive(int currentGearId, int? targetPlacementId, Set<int> visited) async {
      if (visited.contains(currentGearId)) return;
      visited.add(currentGearId);

      // DBを更新
      await _db.setPackingItemPlacement(setId, currentGearId, targetPlacementId);

      // 現在のギアを親に持つ子ギアをすべて探して更新
      final gearItems = ref.read(gearProvider).items;
      final children = gearItems.where((g) => g.parentId == currentGearId);
      for (final child in children) {
        if (child.id != null && state.activeItems.containsKey(child.id)) {
          await updateRecursive(child.id!, targetPlacementId, visited);
        }
      }
    }

    await updateRecursive(gearId, placementId, {});

    // stateを最新の状態に更新
    if (state.activeSetId == setId) {
      await _applySetItems(setId);
    }
  }

  /// ギアの親子関係が変更された際に、積載場所を親に合わせる
  Future<void> syncPlacementWithParent(int gearId, int parentId) async {
    if (state.activeSetId == null) return;
    
    final parentItem = state.activeItems[parentId];
    if (parentItem != null) {
      // 親の配置場所に合わせる（再帰的に子孫も更新される）
      await setPlacementForGear(state.activeSetId!, gearId, parentItem.placementId);
    }
  }

  Future<void> reorderSetItems(int setId, List<int> gearIds) async {
    await _db.updatePackingItemSortOrder(setId, gearIds);
    if (state.activeSetId == setId) {
      await _applySetItems(setId);
    }
  }

  Future<void> resetPackedForSet(int setId) async {
    await _db.resetPackingSetPacked(setId);
    if (state.activeSetId == setId) {
      await _applySetItems(setId);
    }
  }

  Future<void> clearSetItems(int setId) async {
    await _db.clearPackingSetItems(setId);
    if (state.activeSetId == setId) {
      state = state.copyWith(activeItems: {});
    }
    await _refreshSetsMeta();
  }

  // --- Placements ---

  Future<void> addPlacement(String name) async {
    if (state.activeSetId == null) return;
    await _db.insertPlacement(state.activeSetId!, name.trim());
    await _applySetItems(state.activeSetId);
  }

  Future<void> updatePlacement(PackingPlacement placement) async {
    await _db.updatePlacement(placement);
    if (state.activeSetId == placement.setId) {
      await _applySetItems(state.activeSetId);
    }
  }

  Future<void> deletePlacement(int id) async {
    await _db.deletePlacement(id);
    if (state.activeSetId != null) {
      await _applySetItems(state.activeSetId);
    }
  }

  Future<void> reorderPlacements(List<int> ids) async {
    if (state.activeSetId == null) return;
    await _db.updatePlacementSortOrder(state.activeSetId!, ids);
    await _applySetItems(state.activeSetId);
  }

  // --- Meta ---

  Future<void> onGearRemoved(int gearId) async {
    if (!state.activeItems.containsKey(gearId)) return;
    final items = Map<int, PackingSetItem>.from(state.activeItems);
    items.remove(gearId);
    state = state.copyWith(activeItems: items);
  }

  Future<void> _refreshSetsMeta() async {
    final sets = await _db.getPackingSets();
    state = state.copyWith(sets: sets);
  }

  Future<List<Gear>> gearForSet(int setId, List<Gear> allGear) async {
    final items = await _db.getPackingSetItems(setId);
    final ids = items.map((i) => i.gearId).toSet();
    return allGear.where((g) => g.id != null && ids.contains(g.id)).toList();
  }

  Future<int> itemCountForSet(int setId) => _db.countItemsInSet(setId);

  Future<Map<int, List<PackingSetItem>>> allSetItems() async {
    final map = <int, List<PackingSetItem>>{};
    for (final set in state.sets) {
      if (set.id != null) {
        map[set.id!] = await _db.getPackingSetItems(set.id!);
      }
    }
    return map;
  }
}

final packingProvider =
    NotifierProvider<PackingNotifier, PackingState>(PackingNotifier.new);
