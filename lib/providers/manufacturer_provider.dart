import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/camp_manufacturers.dart';
import '../db/app_database.dart';
import '../utils/string_utils.dart';
import 'database_providers.dart';

const _customManufacturersKey = 'custom_manufacturers';
const _managedManufacturersKey = 'managed_manufacturers_v1';

class ManufacturerNotifier extends Notifier<List<String>> {
  AppDatabase get _db => ref.read(appDatabaseProvider);

  @override
  List<String> build() => [];

  Future<void> load() async {
    state = await _loadMerged();
  }

  Future<List<String>> _loadMerged() async {
    final managed = await _loadManaged();
    if (managed.isNotEmpty) return managed;

    final custom = await _loadLegacyCustom();
    final merged = CampManufacturers.mergeLists(custom);
    await _saveManaged(merged);
    return merged;
  }

  Future<List<String>> _loadManaged() async {
    final raw = await _db.getAppSetting(_managedManufacturersKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return _uniqueNames(list.map((e) => e.toString()));
    } catch (_) {
      return [];
    }
  }

  Future<List<String>> _loadLegacyCustom() async {
    final raw = await _db.getAppSetting(_customManufacturersKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return _uniqueNames(list.map((e) => e.toString()));
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveManaged(List<String> manufacturers) async {
    await _db.setAppSetting(
      _managedManufacturersKey,
      jsonEncode(_uniqueNames(manufacturers)),
    );
  }

  Future<void> addCustom(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final managed = await _loadMerged();
    if (managed.any((c) => StringUtils.normalizeForSearch(c) == StringUtils.normalizeForSearch(trimmed))) {
      state = await _loadMerged();
      return;
    }

    await _saveManaged([...managed, trimmed]);
    state = await _loadMerged();
  }

  Future<List<String>> managedManufacturers() => _loadMerged();

  Future<bool> rename(String oldName, String newName) async {
    final oldTrimmed = oldName.trim();
    final newTrimmed = newName.trim();
    if (oldTrimmed.isEmpty || newTrimmed.isEmpty) return false;

    final duplicate = state.any(
      (m) =>
          StringUtils.normalizeForSearch(m) == StringUtils.normalizeForSearch(newTrimmed) &&
          StringUtils.normalizeForSearch(m) != StringUtils.normalizeForSearch(oldTrimmed),
    );
    if (duplicate) return false;

    final managed = await _loadMerged();
    final index = managed.indexWhere(
      (m) => StringUtils.normalizeForSearch(m) == StringUtils.normalizeForSearch(oldTrimmed),
    );
    if (index < 0) return false;

    managed[index] = newTrimmed;
    await _saveManaged(managed);
    await _db.renameGearManufacturer(oldTrimmed, newTrimmed);
    state = await _loadMerged();
    return true;
  }

  Future<bool> remove(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return false;

    final managed = await _loadMerged();
    final next =
        managed.where((m) => StringUtils.normalizeForSearch(m) != StringUtils.normalizeForSearch(trimmed)).toList();
    if (next.length == managed.length) return false;

    await _saveManaged(next);
    await _db.clearGearManufacturer(trimmed);
    state = await _loadMerged();
    return true;
  }

  Future<void> reorder(List<String> ordered) async {
    await _saveManaged(ordered);
    state = await _loadMerged();
  }

  Future<int> countGear(String manufacturer) {
    return _db.countGearByManufacturer(manufacturer.trim());
  }

  List<String> search(String query) => CampManufacturers.search(query, state);

  List<String> _uniqueNames(Iterable<String> names) {
    final cleaned = <String>[];
    for (final name in names) {
      final trimmed = name.trim();
      if (trimmed.isEmpty) continue;
      if (!cleaned.any((m) => StringUtils.normalizeForSearch(m) == StringUtils.normalizeForSearch(trimmed))) {
        cleaned.add(trimmed);
      }
    }
    return cleaned;
  }
}

final manufacturerProvider =
    NotifierProvider<ManufacturerNotifier, List<String>>(
  ManufacturerNotifier.new,
);
