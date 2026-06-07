import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/app_database.dart';
import '../models/category.dart';
import 'database_providers.dart';

class CategoryState {
  final List<GearCategory> items;
  final bool loaded;

  const CategoryState({this.items = const [], this.loaded = false});

  CategoryState copyWith({List<GearCategory>? items, bool? loaded}) {
    return CategoryState(
      items: items ?? this.items,
      loaded: loaded ?? this.loaded,
    );
  }

  GearCategory? byId(int id) {
    for (final c in items) {
      if (c.id == id) return c;
    }
    return null;
  }

  GearCategory? get otherCategory {
    for (final c in items) {
      if (c.name == 'その他') return c;
    }
    return items.isEmpty ? null : items.first;
  }
}

class CategoryNotifier extends Notifier<CategoryState> {
  AppDatabase get _db => ref.read(appDatabaseProvider);

  @override
  CategoryState build() => const CategoryState();

  Future<void> load() async {
    final items = await _db.getCategories();
    state = CategoryState(items: items, loaded: true);
  }

  Future<void> add(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    await _db.insertCategory(trimmed);
    await load();
  }

  Future<void> rename(GearCategory category, String newName) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty || category.id == null) return;
    await _db.updateCategory(category.copyWith(name: trimmed));
    await load();
  }

  /// 削除。ギアがある場合は [reassignToId] へ移す。戻り値は成功可否。
  Future<bool> remove(GearCategory category, {int? reassignToId}) async {
    if (category.id == null) return false;
    final count = await _db.countGearInCategory(category.id!);
    if (count > 0 && reassignToId == null) return false;
    await _db.deleteCategory(
      category.id!,
      reassignToId: count > 0 ? reassignToId : null,
    );
    await load();
    return true;
  }

  Future<void> reorderItems(List<int> orderedIds) async {
    await _db.updateCategorySortOrder(orderedIds);
    final orderIndex = {
      for (var i = 0; i < orderedIds.length; i++) orderedIds[i]: i,
    };
    state = state.copyWith(
      items: [
        for (final c in state.items)
          c.copyWith(sortOrder: orderIndex[c.id] ?? c.sortOrder),
      ]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder)),
    );
  }
}

final categoryProvider =
    NotifierProvider<CategoryNotifier, CategoryState>(CategoryNotifier.new);
