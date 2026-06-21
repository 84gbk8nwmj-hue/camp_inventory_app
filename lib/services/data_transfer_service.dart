import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../db/app_database.dart';
import '../models/category.dart';
import '../models/gear.dart';
import '../models/packing_set.dart';
import 'image_storage_service.dart';

enum ImportMode { replace, merge }

class ImportResult {
  final int categoriesAdded;
  final int gearAdded;
  final int gearUpdated;
  final int setsAdded;
  final int imagesImported;
  final int templateItemsMatched;
  final int templateItemsSkipped;
  final List<String> skippedGearNames;

  const ImportResult({
    this.categoriesAdded = 0,
    this.gearAdded = 0,
    this.gearUpdated = 0,
    this.setsAdded = 0,
    this.imagesImported = 0,
    this.templateItemsMatched = 0,
    this.templateItemsSkipped = 0,
    this.skippedGearNames = const [],
  });

  ImportResult copyWith({int? imagesImported}) {
    return ImportResult(
      categoriesAdded: categoriesAdded,
      gearAdded: gearAdded,
      gearUpdated: gearUpdated,
      setsAdded: setsAdded,
      imagesImported: imagesImported ?? this.imagesImported,
      templateItemsMatched: templateItemsMatched,
      templateItemsSkipped: templateItemsSkipped,
      skippedGearNames: skippedGearNames,
    );
  }

  String get summary {
    if (templateItemsMatched > 0 || templateItemsSkipped > 0) {
      return 'セットに ${templateItemsMatched} 点を追加'
          '${templateItemsSkipped > 0 ? '（${templateItemsSkipped} 点は在庫に未登録）' : ''}';
    }
    final imagePart = imagesImported > 0 ? '、画像 $imagesImported 枚' : '';
    return 'カテゴリ +$categoriesAdded、'
        'ギア +$gearAdded / 更新 $gearUpdated、'
        'セット +$setsAdded$imagePart';
  }
}

class PackingSetTemplateItem {
  final String gearName;
  final String? categoryName;

  const PackingSetTemplateItem({
    required this.gearName,
    this.categoryName,
  });

  Map<String, dynamic> toJson() => {
        'gearName': gearName,
        if (categoryName != null) 'categoryName': categoryName,
      };

  factory PackingSetTemplateItem.fromJson(Map<String, dynamic> json) {
    return PackingSetTemplateItem(
      gearName: json['gearName'] as String,
      categoryName: json['categoryName'] as String?,
    );
  }
}

class DataTransferService {
  final AppDatabase _db;
  final ImageStorageService _images;

  DataTransferService({
    AppDatabase? db,
    ImageStorageService? images,
  })  : _db = db ?? AppDatabase.instance,
        _images = images ?? ImageStorageService();

  static const backupJsonName = 'backup.json';

  Future<
      ({
        List<Gear> gear,
        List<GearCategory> categories,
        List<PackingSet> packingSets,
        Map<int, List<PackingSetItem>> packingItemsBySet
      })> _loadBackupDataFromDatabase() async {
    final gear = await _db.getAllGear();
    final categories = await _db.getCategories();
    final packingSets = await _db.getPackingSets();
    final packingItemsBySet = <int, List<PackingSetItem>>{};

    for (final set in packingSets) {
      final id = set.id;
      if (id != null) {
        packingItemsBySet[id] = await _db.getPackingSetItems(id);
      }
    }

    return (
      gear: gear,
      categories: categories,
      packingSets: packingSets,
      packingItemsBySet: packingItemsBySet,
    );
  }

  Map<String, dynamic> _buildBackupPayload({
    required List<Gear> gear,
    required List<GearCategory> categories,
    required List<PackingSet> packingSets,
    required Map<int, List<PackingSetItem>> packingItemsBySet,
  }) {
    return {
      'app': 'camp_inventory_app',
      'type': 'full_backup',
      'version': 2,
      'exportedAt': DateTime.now().toIso8601String(),
      'categories': categories.map((c) => c.toJson()).toList(),
      'gear': gear.map((g) => g.toJson()).toList(),
      'packingSets': packingSets.map((s) => s.toJson()).toList(),
      'packingItems': packingItemsBySet.entries
          .map(
            (e) => {
              'setId': e.key,
              'items': e.value.map((i) => i.toMap()).toList(),
            },
          )
          .toList(),
    };
  }

  Future<void> shareBackupJsonFromDatabase() async {
    final data = await _loadBackupDataFromDatabase();
    await shareBackupJson(
      gear: data.gear,
      categories: data.categories,
      packingSets: data.packingSets,
      packingItemsBySet: data.packingItemsBySet,
    );
  }

  Future<void> shareBackupJson({
    required List<Gear> gear,
    required List<GearCategory> categories,
    required List<PackingSet> packingSets,
    required Map<int, List<PackingSetItem>> packingItemsBySet,
  }) async {
    final payload = _buildBackupPayload(
      gear: gear,
      categories: categories,
      packingSets: packingSets,
      packingItemsBySet: packingItemsBySet,
    );
    await _shareJsonFile(payload, 'camp_gear_backup');
  }

  /// JSON + gear_images/ を ZIP にまとめて共有
  Future<void> shareBackupZipFromDatabase() async {
    final data = await _loadBackupDataFromDatabase();
    await shareBackupZip(
      gear: data.gear,
      categories: data.categories,
      packingSets: data.packingSets,
      packingItemsBySet: data.packingItemsBySet,
    );
  }

  /// JSON + gear_images/ を ZIP にまとめて共有
  Future<void> shareBackupZip({
    required List<Gear> gear,
    required List<GearCategory> categories,
    required List<PackingSet> packingSets,
    required Map<int, List<PackingSetItem>> packingItemsBySet,
  }) async {
    await _images.init();
    final payload = _buildBackupPayload(
      gear: gear,
      categories: categories,
      packingSets: packingSets,
      packingItemsBySet: packingItemsBySet,
    );

    final temp = await getTemporaryDirectory();
    final stamp = _timestamp();
    final workDir = Directory(p.join(temp.path, 'camp_export_$stamp'));
    final imagesOut =
        Directory(p.join(workDir.path, ImageStorageService.imagesSubDir));

    try {
      await workDir.create(recursive: true);
      await imagesOut.create(recursive: true);

      await File(p.join(workDir.path, backupJsonName)).writeAsString(
        const JsonEncoder.withIndent('  ').convert(payload),
      );

      for (final g in gear) {
        if (g.imageFile == null || g.imageFile!.isEmpty) continue;
        final source = _images.fileForExport(g.imageFile);
        if (source != null) {
          await source.copy(p.join(imagesOut.path, g.imageFile!));
        }
      }

      final zipPath = p.join(temp.path, 'camp_gear_backup_$stamp.zip');
      final encoder = ZipFileEncoder();
      encoder.create(zipPath);

      await encoder.addFile(
        File(p.join(workDir.path, backupJsonName)),
        backupJsonName,
      );

      await for (final entity in imagesOut.list()) {
        if (entity is! File) continue;
        await encoder.addFile(
          entity,
          p.posix
              .join(ImageStorageService.imagesSubDir, p.basename(entity.path)),
        );
      }
      await encoder.close();

      await Share.shareXFiles(
        [XFile(zipPath, mimeType: 'application/zip')],
        subject: 'キャンプギアバックアップ（画像付き）',
      );
    } finally {
      if (await workDir.exists()) {
        await workDir.delete(recursive: true);
      }
    }
  }

  Future<ImportResult?> pickAndImportBackup({required ImportMode mode}) async {
    final json = await _pickJsonFile();
    if (json == null) return null;

    if (json['type'] == 'packing_set_template') {
      throw FormatException('持ち出しセット用テンプレートです。セット画面から読み込んでください。');
    }

    return importBackupJson(json, mode: mode);
  }

  Future<ImportResult?> pickAndImportBackupZip({
    required ImportMode mode,
  }) async {
    final zipPath = await _pickZipFile();
    if (zipPath == null) return null;

    final extractDir = await _extractZipToTemp(zipPath);
    try {
      final jsonFile = await _findBackupJson(extractDir);
      if (jsonFile == null) {
        throw FormatException('ZIP内に $backupJsonName が見つかりません。');
      }

      // JSONファイルがあるディレクトリを基準にする
      final baseDir = jsonFile.parent.path;

      final json =
          jsonDecode(await jsonFile.readAsString()) as Map<String, dynamic>;
      if (json['type'] == 'packing_set_template') {
        throw FormatException('持ち出しセット用テンプレートです。セット画面から読み込んでください。');
      }

      if (mode == ImportMode.replace) {
        await _db.clearAllData();
        await _images.clearAllImages();
      }

      final imagesImported = await _images.importFromDirectory(baseDir);
      final result = await importBackupJson(
        json,
        mode: mode,
        skipClear: true,
      );
      return result.copyWith(imagesImported: imagesImported);
    } finally {
      await Directory(extractDir).delete(recursive: true);
    }
  }

  Future<ImportResult> importBackupJson(
    Map<String, dynamic> json, {
    required ImportMode mode,
    bool skipClear = false,
  }) async {
    final version = json['version'] as int? ?? 1;

    if (mode == ImportMode.replace && !skipClear) {
      await _db.clearAllData();
    }

    var categoriesAdded = 0;
    var gearAdded = 0;
    var gearUpdated = 0;
    var setsAdded = 0;

    final categoryIdByName = <String, int>{};
    for (final row in await _db.getCategories()) {
      if (row.id != null) categoryIdByName[row.name] = row.id!;
    }

    Future<int> ensureCategory(String name) async {
      if (categoryIdByName.containsKey(name)) {
        return categoryIdByName[name]!;
      }
      final id = await _db.insertCategory(name);
      categoryIdByName[name] = id;
      categoriesAdded++;
      return id;
    }

    final categoriesJson = json['categories'] as List<dynamic>?;
    if (categoriesJson != null) {
      for (final raw in categoriesJson) {
        final map = raw as Map<String, dynamic>;
        await ensureCategory(map['name'] as String);
      }
    }

    final gearJson = json['gear'] as List<dynamic>? ?? [];
    final exportGearByOldId = <int, String>{};
    for (final raw in gearJson) {
      final map = raw as Map<String, dynamic>;
      final id = map['id'] as int?;
      if (id != null) exportGearByOldId[id] = map['name'] as String;
    }

    final gearIdByName = <String, int>{};
    for (final g in await _db.getAllGear()) {
      if (g.id != null) gearIdByName[g.name] = g.id!;
    }

    for (final raw in gearJson) {
      final map = raw as Map<String, dynamic>;
      final name = map['name'] as String;

      final catName = version >= 2
          ? (map['categoryName'] as String? ?? 'その他')
          : (map['category'] as String? ?? 'その他');
      final categoryId = await ensureCategory(catName);

      final gear = Gear(
        name: name,
        categoryId: categoryId,
        categoryName: catName,
        quantity: map['quantity'] as int? ?? 1,
        weight: (map['weight'] as num?)?.toDouble(),
        imageFile: map['imageFile'] as String? ??
            (map['imagePath'] != null
                ? p.basename(map['imagePath'] as String)
                : null),
        note: map['note'] as String?,
        manufacturer: map['manufacturer'] as String?,
        weightVerified: map['weightVerified'] as bool? ?? false,
      );

      if (gearIdByName.containsKey(name)) {
        if (mode == ImportMode.merge) {
          await _db.updateGear(gear.copyWith(id: gearIdByName[name]));
          gearUpdated++;
        }
      } else {
        final id = await _db.insertGear(gear);
        gearIdByName[name] = id;
        gearAdded++;
      }
    }

    gearIdByName.clear();
    for (final g in await _db.getAllGear()) {
      if (g.id != null) gearIdByName[g.name] = g.id!;
    }

    final setsJson = json['packingSets'] as List<dynamic>?;
    final itemsJson = json['packingItems'] as List<dynamic>?;

    if (setsJson != null && itemsJson != null) {
      final oldToNewSetId = <int, int>{};
      for (final raw in setsJson) {
        final map = raw as Map<String, dynamic>;
        final oldId = map['id'] as int;
        var setName = map['name'] as String;
        if (mode == ImportMode.merge) {
          final exists =
              (await _db.getPackingSets()).any((s) => s.name == setName);
          if (exists) setName = '$setName (インポート)';
        }
        oldToNewSetId[oldId] = await _db.insertPackingSet(setName);
        setsAdded++;
      }

      for (final raw in itemsJson) {
        final block = raw as Map<String, dynamic>;
        final newSetId = oldToNewSetId[block['setId'] as int];
        if (newSetId == null) continue;

        final gearIds = <int>[];
        for (final itemRaw in block['items'] as List<dynamic>) {
          final oldGearId = (itemRaw as Map<String, dynamic>)['gear_id'] as int;
          final gearName = exportGearByOldId[oldGearId];
          final newGearId = gearName == null ? null : gearIdByName[gearName];
          if (newGearId != null) gearIds.add(newGearId);
        }
        if (gearIds.isNotEmpty) {
          await _db.importPackingSetItems(newSetId, gearIds);
        }
      }
    } else {
      final packing = json['packing'] as List<dynamic>?;
      if (packing != null && packing.isNotEmpty) {
        final setId = await _db.insertPackingSet('インポートセット');
        setsAdded++;
        final gearIds = <int>[];
        for (final raw in packing) {
          final oldGearId = (raw as Map<String, dynamic>)['gear_id'] as int;
          final gearName = exportGearByOldId[oldGearId];
          final newGearId = gearName == null ? null : gearIdByName[gearName];
          if (newGearId != null) gearIds.add(newGearId);
        }
        if (gearIds.isNotEmpty) {
          await _db.importPackingSetItems(setId, gearIds);
        }
      }
    }

    return ImportResult(
      categoriesAdded: categoriesAdded,
      gearAdded: gearAdded,
      gearUpdated: gearUpdated,
      setsAdded: setsAdded,
    );
  }

  Future<void> sharePackingSetTemplate({
    required PackingSet set,
    required List<Gear> gearInSet,
  }) async {
    final payload = {
      'app': 'camp_inventory_app',
      'type': 'packing_set_template',
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'setName': set.name,
      'items': gearInSet
          .map(
            (g) => PackingSetTemplateItem(
              gearName: g.name,
              categoryName: g.categoryName,
            ).toJson(),
          )
          .toList(),
    };
    final safeName =
        set.name.replaceAll(RegExp(r'[^\w\u3040-\u30FF\u4E00-\u9FFF]'), '_');
    await _shareJsonFile(payload, 'camp_set_$safeName');
  }

  Future<ImportResult?> pickAndImportPackingTemplate() async {
    final json = await _pickJsonFile();
    if (json == null) return null;

    if (json['type'] != 'packing_set_template') {
      throw FormatException('持ち出しセット用テンプレートではありません。');
    }

    return importPackingTemplateJson(json);
  }

  Future<ImportResult> importPackingTemplateJson(
    Map<String, dynamic> json, {
    String? setNameOverride,
  }) async {
    var setName = setNameOverride ?? json['setName'] as String? ?? 'インポートセット';
    if ((await _db.getPackingSets()).any((s) => s.name == setName)) {
      setName = '$setName (インポート)';
    }

    final setId = await _db.insertPackingSet(setName);
    final allGear = await _db.getAllGear();
    final items = (json['items'] as List<dynamic>)
        .map((e) => PackingSetTemplateItem.fromJson(e as Map<String, dynamic>))
        .toList();

    final matchedIds = <int>[];
    final skipped = <String>[];

    for (final item in items) {
      final gearId = _matchGear(allGear, item);
      if (gearId != null) {
        matchedIds.add(gearId);
      } else {
        skipped.add(item.gearName);
      }
    }

    if (matchedIds.isNotEmpty) {
      await _db.importPackingSetItems(setId, matchedIds);
    }
    await _db.setActivePackingSetId(setId);

    return ImportResult(
      setsAdded: 1,
      templateItemsMatched: matchedIds.length,
      templateItemsSkipped: skipped.length,
      skippedGearNames: skipped,
    );
  }

  int? _matchGear(List<Gear> allGear, PackingSetTemplateItem item) {
    final name = item.gearName.trim();
    final matches = allGear.where((g) => g.name == name).toList();
    if (matches.isEmpty) return null;
    if (matches.length == 1) return matches.first.id;

    if (item.categoryName != null) {
      for (final g in matches) {
        if (g.categoryName == item.categoryName) return g.id;
      }
    }
    return matches.first.id;
  }

  Future<Map<String, dynamic>?> _pickJsonFile() async {
    final result = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result == null || result.path == null) return null;
    final content = await File(result.path!).readAsString();
    return jsonDecode(content) as Map<String, dynamic>;
  }

  Future<String?> _pickZipFile() async {
    final result = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );
    if (result == null || result.path == null) return null;
    return result.path;
  }

  Future<String> _extractZipToTemp(String zipPath) async {
    final temp = await getTemporaryDirectory();
    final dest = p.join(
        temp.path, 'camp_import_${DateTime.now().millisecondsSinceEpoch}');
    await Directory(dest).create(recursive: true);
    await extractFileToDisk(zipPath, dest);
    return dest;
  }

  Future<File?> _findBackupJson(String rootDir) async {
    final dir = Directory(rootDir);
    if (!await dir.exists()) return null;

    await for (final entity in dir.list(recursive: true)) {
      if (entity is File &&
          p.basename(entity.path).toLowerCase() == backupJsonName) {
        return entity;
      }
    }
    return null;
  }

  String _timestamp() {
    return DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .split('.')
        .first;
  }

  Future<void> _shareJsonFile(
    Map<String, dynamic> payload,
    String baseName,
  ) async {
    final json = const JsonEncoder.withIndent('  ').convert(payload);
    final dir = await getTemporaryDirectory();
    final path = p.join(dir.path, '${baseName}_${_timestamp()}.json');
    await File(path).writeAsString(json);

    await Share.shareXFiles(
      [XFile(path, mimeType: 'application/json')],
      subject: 'キャンプギアデータ',
    );
  }
}
