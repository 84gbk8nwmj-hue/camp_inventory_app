import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/category.dart';
import '../models/gear.dart';
import '../models/packing_set.dart';

class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  Database? _db;

  Future<Database> get database async {
    _db ??= await _initDB('gear.db');
    return _db!;
  }

  static const defaultCategories = [
    '収納',
    'クーラーBOX',
    'テント',
    'ファニチャー',
    '寝具',
    '焚き火',
    'ランタン・照明',
    '調理',
    'カトラリー',
    'TOOL',
    'ペグ',
    '電源',
    'その他',
  ];

  Future<Database> _initDB(String fileName) async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, fileName);

    return openDatabase(
      path,
      version: 11, // 10 -> 11
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await _createV11Schema(db);
    await _seedCategories(db);
    await db.insert('app_setting', {
      'key': 'active_packing_set_id',
      'value': '',
    });
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE gear ADD COLUMN weight REAL');
    }
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS packing_item (
          gear_id INTEGER PRIMARY KEY,
          is_packed INTEGER NOT NULL DEFAULT 0
        )
      ''');
    }
    if (oldVersion < 4) {
      await _migrateToV4(db);
    }
    if (oldVersion < 5) {
      await db.execute(
        'ALTER TABLE gear ADD COLUMN sort_order INTEGER NOT NULL DEFAULT 0',
      );
      await db.execute(
        'ALTER TABLE packing_set_item ADD COLUMN sort_order INTEGER NOT NULL DEFAULT 0',
      );
      await _initGearSortOrder(db);
      await _initPackingItemSortOrder(db);
    }
    if (oldVersion < 6) {
      await _repairPackingSetItemForeignKeys(db);
    }
    if (oldVersion < 7) {
      await db.execute('ALTER TABLE gear ADD COLUMN manufacturer TEXT');
    }
    if (oldVersion < 8) {
      await db.execute(
        'ALTER TABLE gear ADD COLUMN weight_verified INTEGER NOT NULL DEFAULT 0',
      );
    }
    if (oldVersion < 9) {
      await _upgradeToV9(db);
    }
    if (oldVersion < 10) {
      // Version 10: PackingPlacement に背景画像カラムを追加
      await db.execute('ALTER TABLE packing_placement ADD COLUMN image_file TEXT');
    }
    if (oldVersion < 11) {
      // Version 11: Gear に親子構造用の parent_id カラムを追加
      await db.execute('ALTER TABLE gear ADD COLUMN parent_id INTEGER');
    }
  }

  Future<void> _upgradeToV9(Database db) async {
    // packing_placement テーブル追加
    await db.execute('''
      CREATE TABLE IF NOT EXISTS packing_placement (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        set_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        sort_order INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (set_id) REFERENCES packing_set(id) ON DELETE CASCADE
      )
    ''');

    // packing_set_item テーブルに placement_id を追加して再構築
    await db.execute('''
      CREATE TABLE IF NOT EXISTS packing_set_item_v9 (
        set_id INTEGER NOT NULL,
        gear_id INTEGER NOT NULL,
        placement_id INTEGER,
        is_packed INTEGER NOT NULL DEFAULT 0,
        sort_order INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY (set_id, gear_id),
        FOREIGN KEY (set_id) REFERENCES packing_set(id) ON DELETE CASCADE,
        FOREIGN KEY (gear_id) REFERENCES gear(id) ON DELETE CASCADE,
        FOREIGN KEY (placement_id) REFERENCES packing_placement(id) ON DELETE SET NULL
      )
    ''');

    await db.execute('''
      INSERT OR IGNORE INTO packing_set_item_v9 (set_id, gear_id, is_packed, sort_order)
      SELECT set_id, gear_id, is_packed, sort_order FROM packing_set_item
    ''');

    await db.execute('DROP TABLE packing_set_item');
    await db.execute(
      'ALTER TABLE packing_set_item_v9 RENAME TO packing_set_item',
    );
  }

  /// v4 マイグレで gear→gear_legacy リネーム後に FK が壊れる問題を修復
  Future<void> _repairPackingSetItemForeignKeys(Database db) async {
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='packing_set_item'",
    );
    if (tables.isEmpty) return;

    await db.execute('''
      CREATE TABLE IF NOT EXISTS packing_set_item_fixed (
        set_id INTEGER NOT NULL,
        gear_id INTEGER NOT NULL,
        placement_id INTEGER,
        is_packed INTEGER NOT NULL DEFAULT 0,
        sort_order INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY (set_id, gear_id),
        FOREIGN KEY (set_id) REFERENCES packing_set(id) ON DELETE CASCADE,
        FOREIGN KEY (gear_id) REFERENCES gear(id) ON DELETE CASCADE,
        FOREIGN KEY (placement_id) REFERENCES packing_placement(id) ON DELETE SET NULL
      )
    ''');
    await db.execute('''
      INSERT OR IGNORE INTO packing_set_item_fixed (set_id, gear_id, is_packed, sort_order)
      SELECT set_id, gear_id, is_packed, COALESCE(sort_order, 0) FROM packing_set_item
    ''');
    await db.execute('DROP TABLE packing_set_item');
    await db.execute(
      'ALTER TABLE packing_set_item_fixed RENAME TO packing_set_item',
    );
  }

  Future<void> _initGearSortOrder(Database db) async {
    final rows = await db.query('gear', orderBy: 'id ASC');
    for (var i = 0; i < rows.length; i++) {
      await db.update('gear', {'sort_order': i},
          where: 'id = ?', whereArgs: [rows[i]['id']]);
    }
  }

  Future<void> _initPackingItemSortOrder(Database db) async {
    final sets = await db.query('packing_set');
    for (final set in sets) {
      final items = await db.query(
        'packing_set_item',
        where: 'set_id = ?',
        whereArgs: [set['id']],
        orderBy: 'gear_id ASC',
      );
      for (var i = 0; i < items.length; i++) {
        await db.update(
          'packing_set_item',
          {'sort_order': i},
          where: 'set_id = ? AND gear_id = ?',
          whereArgs: [set['id'], items[i]['gear_id']],
        );
      }
    }
  }

  Future<void> _createV11Schema(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS category (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        sort_order INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS gear (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        category_id INTEGER NOT NULL,
        quantity INTEGER NOT NULL,
        weight REAL,
        image_file TEXT,
        note TEXT,
        manufacturer TEXT,
        weight_verified INTEGER NOT NULL DEFAULT 0,
        sort_order INTEGER NOT NULL DEFAULT 0,
        parent_id INTEGER,
        FOREIGN KEY (category_id) REFERENCES category(id)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS packing_set (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS packing_placement (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        set_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        image_file TEXT,
        sort_order INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (set_id) REFERENCES packing_set(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS packing_set_item (
        set_id INTEGER NOT NULL,
        gear_id INTEGER NOT NULL,
        placement_id INTEGER,
        is_packed INTEGER NOT NULL DEFAULT 0,
        sort_order INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY (set_id, gear_id),
        FOREIGN KEY (set_id) REFERENCES packing_set(id) ON DELETE CASCADE,
        FOREIGN KEY (gear_id) REFERENCES gear(id) ON DELETE CASCADE,
        FOREIGN KEY (placement_id) REFERENCES packing_placement(id) ON DELETE SET NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS app_setting (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }

  Future<void> _seedCategories(Database db) async {
    for (var i = 0; i < defaultCategories.length; i++) {
      await db.insert(
          'category',
          {
            'name': defaultCategories[i],
            'sort_order': i,
          },
          conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  Future<void> _migrateToV4(Database db) async {
    await _createV11Schema(db);
    await _seedCategories(db);

    final categoryRows = await db.query('category');
    final categoryByName = {
      for (final row in categoryRows) row['name'] as String: row['id'] as int,
    };

    Future<int> ensureCategory(String name) async {
      if (categoryByName.containsKey(name)) return categoryByName[name]!;
      final id = await db.insert('category', {
        'name': name,
        'sort_order': categoryByName.length,
      });
      categoryByName[name] = id;
      return id;
    }

    await db.execute('ALTER TABLE gear RENAME TO gear_legacy');

    await db.execute('''
      CREATE TABLE gear (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        category_id INTEGER NOT NULL,
        quantity INTEGER NOT NULL,
        weight REAL,
        image_file TEXT,
        note TEXT,
        manufacturer TEXT,
        weight_verified INTEGER NOT NULL DEFAULT 0,
        sort_order INTEGER NOT NULL DEFAULT 0,
        parent_id INTEGER,
        FOREIGN KEY (category_id) REFERENCES category(id)
      )
    ''');

    final legacyGear = await db.query('gear_legacy');
    for (var i = 0; i < legacyGear.length; i++) {
      final row = legacyGear[i];
      final catName = row['category'] as String? ?? 'その他';
      final catId = await ensureCategory(catName);
      final legacyImage = row['imagePath'] as String?;
      await db.insert('gear', {
        'id': row['id'],
        'name': row['name'],
        'category_id': catId,
        'quantity': row['quantity'],
        'weight': row['weight'],
        'image_file': legacyImage == null ? null : p.basename(legacyImage),
        'note': row['note'],
        'sort_order': i,
      });
    }
    await db.execute('DROP TABLE gear_legacy');

    final now = DateTime.now().toIso8601String();
    final setId = await db.insert('packing_set', {
      'name': 'マイセット',
      'created_at': now,
      'updated_at': now,
    });

    final legacyPacking = await db.query('packing_item');
    for (var i = 0; i < legacyPacking.length; i++) {
      final row = legacyPacking[i];
      await db.insert(
          'packing_set_item',
          {
            'set_id': setId,
            'gear_id': row['gear_id'],
            'is_packed': row['is_packed'],
            'sort_order': i,
          },
          conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    await db.execute('DROP TABLE IF EXISTS packing_item');

    await db.insert(
        'app_setting',
        {
          'key': 'active_packing_set_id',
          'value': setId.toString(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // --- Category ---

  Future<List<GearCategory>> getCategories() async {
    final db = await database;
    final maps =
        await db.query('category', orderBy: 'sort_order ASC, name ASC');
    return maps.map(GearCategory.fromMap).toList();
  }

  Future<int> insertCategory(String name) async {
    final db = await database;
    final maxOrder = Sqflite.firstIntValue(await db.rawQuery(
          'SELECT MAX(sort_order) FROM category',
        )) ??
        0;
    return db.insert('category', {
      'name': name,
      'sort_order': maxOrder + 1,
    });
  }

  Future<void> updateCategory(GearCategory category) async {
    final db = await database;
    await db.update(
      'category',
      category.toMap(),
      where: 'id = ?',
      whereArgs: [category.id],
    );
  }

  Future<void> updateCategorySortOrder(List<int> categoryIds) async {
    final db = await database;
    await db.transaction((txn) async {
      for (var i = 0; i < categoryIds.length; i++) {
        await txn.update(
          'category',
          {'sort_order': i},
          where: 'id = ?',
          whereArgs: [categoryIds[i]],
        );
      }
    });
  }

  Future<int> countGearInCategory(int categoryId) async {
    final db = await database;
    return Sqflite.firstIntValue(await db.rawQuery(
          'SELECT COUNT(*) FROM gear WHERE category_id = ?',
          [categoryId],
        )) ??
        0;
  }

  Future<void> deleteCategory(int id, {int? reassignToId}) async {
    final db = await database;
    if (reassignToId != null) {
      await db.transaction((txn) async {
        await txn.update(
          'gear',
          {'category_id': reassignToId},
          where: 'category_id = ?',
          whereArgs: [id],
        );
        await txn.delete('category', where: 'id = ?', whereArgs: [id]);
      });
    } else {
      await db.delete('category', where: 'id = ?', whereArgs: [id]);
    }
  }

  // --- Gear ---

  static const _gearSelect = '''
    SELECT g.*, c.name AS category_name
    FROM gear g
    INNER JOIN category c ON g.category_id = c.id
  ''';

  Future<List<Gear>> getAllGear() async {
    final db = await database;
    final maps =
        await db.rawQuery('$_gearSelect ORDER BY g.sort_order ASC, g.id ASC');
    return maps.map(Gear.fromMap).toList();
  }

  Future<int> _nextGearSortOrder(Database db) async {
    final max = Sqflite.firstIntValue(
          await db.rawQuery('SELECT MAX(sort_order) FROM gear'),
        ) ??
        -1;
    return max + 1;
  }

  Future<int> insertGear(Gear gear) async {
    final db = await database;
    final map = gear.toMap();
    map['sort_order'] ??= await _nextGearSortOrder(db);
    return db.insert('gear', map);
  }

  Future<void> updateGearSortOrder(List<int> gearIds) async {
    final db = await database;
    await db.transaction((txn) async {
      for (var i = 0; i < gearIds.length; i++) {
        await txn.update(
          'gear',
          {'sort_order': i},
          where: 'id = ?',
          whereArgs: [gearIds[i]],
        );
      }
    });
  }

  Future<void> updateGear(Gear gear) async {
    final db = await database;
    await db.update(
      'gear',
      gear.toMap(),
      where: 'id = ?',
      whereArgs: [gear.id],
    );
  }

  Future<void> deleteGear(int id) async {
    final db = await database;
    await db.delete('gear', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> countGearByManufacturer(String manufacturer) async {
    final db = await database;
    return Sqflite.firstIntValue(await db.rawQuery(
          'SELECT COUNT(*) FROM gear WHERE manufacturer = ?',
          [manufacturer],
        )) ??
        0;
  }

  Future<void> renameGearManufacturer(String from, String to) async {
    final db = await database;
    await db.update(
      'gear',
      {'manufacturer': to},
      where: 'manufacturer = ?',
      whereArgs: [from],
    );
  }

  Future<void> clearGearManufacturer(String manufacturer) async {
    final db = await database;
    await db.update(
      'gear',
      {'manufacturer': null},
      where: 'manufacturer = ?',
      whereArgs: [manufacturer],
    );
  }

  // --- Packing sets ---

  Future<List<PackingSet>> getPackingSets() async {
    final db = await database;
    final maps =
        await db.query('packing_set', orderBy: 'updated_at DESC, name ASC');
    return maps.map(PackingSet.fromMap).toList();
  }

  Future<int> insertPackingSet(String name) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    return db.insert('packing_set', {
      'name': name,
      'created_at': now,
      'updated_at': now,
    });
  }

  Future<void> renamePackingSet(int id, String name) async {
    final db = await database;
    await db.update(
      'packing_set',
      {
        'name': name,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deletePackingSet(int id) async {
    final db = await database;
    await db.delete('packing_set', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> touchPackingSet(int id) async {
    final db = await database;
    await db.update(
      'packing_set',
      {'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> countItemsInSet(int setId) async {
    final db = await database;
    return Sqflite.firstIntValue(await db.rawQuery(
          'SELECT COUNT(*) FROM packing_set_item WHERE set_id = ?',
          [setId],
        )) ??
        0;
  }

  Future<List<PackingSetItem>> getPackingSetItems(int setId) async {
    final db = await database;
    final gearRows = await db.rawQuery('''
      SELECT psi.*, g.name, g.category_id, g.quantity, g.weight, g.image_file, g.note, g.manufacturer, g.weight_verified, c.name AS category_name
      FROM packing_set_item psi
      JOIN gear g ON psi.gear_id = g.id
      JOIN category c ON g.category_id = c.id
      WHERE psi.set_id = ?
      ORDER BY psi.sort_order ASC, psi.gear_id ASC
    ''', [setId]);

    return gearRows.map((row) {
      final gear = Gear.fromMap(row);
      return PackingSetItem.fromMap(row).copyWith(gear: gear);
    }).toList();
  }

  Future<int> _nextPackingItemSortOrder(Database db, int setId) async {
    final max = Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT MAX(sort_order) FROM packing_set_item WHERE set_id = ?',
            [setId],
          ),
        ) ??
        -1;
    return max + 1;
  }

  Future<void> setPackingItemIncluded(
    int setId,
    int gearId,
    bool included,
  ) async {
    final db = await database;
    if (included) {
      final order = await _nextPackingItemSortOrder(db, setId);
      await db.insert(
        'packing_set_item',
        {
          'set_id': setId,
          'gear_id': gearId,
          'is_packed': 0,
          'sort_order': order,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    } else {
      await db.delete(
        'packing_set_item',
        where: 'set_id = ? AND gear_id = ?',
        whereArgs: [setId, gearId],
      );
    }
    await touchPackingSet(setId);
  }

  Future<void> setPackingItemPacked(
    int setId,
    int gearId,
    bool isPacked,
  ) async {
    final db = await database;
    await db.update(
      'packing_set_item',
      {'is_packed': isPacked ? 1 : 0},
      where: 'set_id = ? AND gear_id = ?',
      whereArgs: [setId, gearId],
    );
    await touchPackingSet(setId);
  }

  Future<void> setPackingItemPlacement(
    int setId,
    int gearId,
    int? placementId,
  ) async {
    final db = await database;
    await db.update(
      'packing_set_item',
      {'placement_id': placementId},
      where: 'set_id = ? AND gear_id = ?',
      whereArgs: [setId, gearId],
    );
    await touchPackingSet(setId);
  }

  Future<void> resetPackingSetPacked(int setId) async {
    final db = await database;
    await db.update(
      'packing_set_item',
      {'is_packed': 0},
      where: 'set_id = ?',
      whereArgs: [setId],
    );
    await touchPackingSet(setId);
  }

  Future<void> clearPackingSetItems(int setId) async {
    final db = await database;
    await db.delete(
      'packing_set_item',
      where: 'set_id = ?',
      whereArgs: [setId],
    );
    await touchPackingSet(setId);
  }

  Future<void> updatePackingItemSortOrder(int setId, List<int> gearIds) async {
    final db = await database;
    await db.transaction((txn) async {
      for (var i = 0; i < gearIds.length; i++) {
        await txn.update(
          'packing_set_item',
          {'sort_order': i},
          where: 'set_id = ? AND gear_id = ?',
          whereArgs: [setId, gearIds[i]],
        );
      }
    });
    await touchPackingSet(setId);
  }

  Future<void> duplicatePackingSet(int sourceId, String newName) async {
    final db = await database;
    await db.transaction((txn) async {
      final now = DateTime.now().toIso8601String();
      final newId = await txn.insert('packing_set', {
        'name': newName,
        'created_at': now,
        'updated_at': now,
      });

      // Placement の複製
      final placements = await txn.query(
        'packing_placement',
        where: 'set_id = ?',
        whereArgs: [sourceId],
      );
      final placementIdMap = <int, int>{};
      for (final pRow in placements) {
        final oldPId = pRow['id'] as int;
        final newPId = await txn.insert('packing_placement', {
          'set_id': newId,
          'name': pRow['name'],
          'image_file': pRow['image_file'],
          'sort_order': pRow['sort_order'],
        });
        placementIdMap[oldPId] = newPId;
      }

      // Item の複製
      final items = await txn.query(
        'packing_set_item',
        where: 'set_id = ?',
        whereArgs: [sourceId],
      );
      for (final row in items) {
        final oldPId = row['placement_id'] as int?;
        await txn.insert('packing_set_item', {
          'set_id': newId,
          'gear_id': row['gear_id'],
          'placement_id': oldPId != null ? placementIdMap[oldPId] : null,
          'is_packed': 0,
          'sort_order': row['sort_order'] ?? 0,
        });
      }
    });
  }

  Future<void> importPackingSetItems(int setId, List<int> gearIds) async {
    final db = await database;
    var order = await _nextPackingItemSortOrder(db, setId);
    await db.transaction((txn) async {
      for (final gearId in gearIds) {
        await txn.insert(
          'packing_set_item',
          {
            'set_id': setId,
            'gear_id': gearId,
            'is_packed': 0,
            'sort_order': order++,
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    });
    await touchPackingSet(setId);
  }

  // --- Placement ---

  Future<List<PackingPlacement>> getPlacements(int setId) async {
    final db = await database;
    final maps = await db.query(
      'packing_placement',
      where: 'set_id = ?',
      orderBy: 'sort_order ASC',
      whereArgs: [setId],
    );
    return maps.map(PackingPlacement.fromMap).toList();
  }

  Future<int> insertPlacement(int setId, String name, {String? imageFile}) async {
    final db = await database;
    final maxOrder = Sqflite.firstIntValue(await db.rawQuery(
          'SELECT MAX(sort_order) FROM packing_placement WHERE set_id = ?',
          [setId],
        )) ??
        -1;
    final id = await db.insert('packing_placement', {
      'set_id': setId,
      'name': name,
      'image_file': imageFile,
      'sort_order': maxOrder + 1,
    });
    await touchPackingSet(setId);
    return id;
  }

  Future<void> updatePlacement(PackingPlacement placement) async {
    final db = await database;
    await db.update(
      'packing_placement',
      placement.toMap(),
      where: 'id = ?',
      whereArgs: [placement.id],
    );
    await touchPackingSet(placement.setId);
  }

  Future<void> deletePlacement(int id) async {
    final db = await database;
    final row = await db.query('packing_placement',
        columns: ['set_id'], where: 'id = ?', whereArgs: [id]);
    if (row.isEmpty) return;
    final setId = row.first['set_id'] as int;

    await db.delete('packing_placement', where: 'id = ?', whereArgs: [id]);
    await touchPackingSet(setId);
  }

  Future<void> updatePlacementSortOrder(int setId, List<int> ids) async {
    final db = await database;
    await db.transaction((txn) async {
      for (var i = 0; i < ids.length; i++) {
        await txn.update(
          'packing_placement',
          {'sort_order': i},
          where: 'id = ?',
          whereArgs: [ids[i]],
        );
      }
    });
    await touchPackingSet(setId);
  }

  Future<void> clearAllData() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('packing_set_item');
      await txn.delete('packing_set');
      await txn.delete('gear');
      await txn.delete('category');
      await txn.insert(
        'app_setting',
        {'key': 'active_packing_set_id', 'value': ''},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  // --- Settings ---

  Future<int?> getActivePackingSetId() async {
    final db = await database;
    final rows = await db.query(
      'app_setting',
      where: 'key = ?',
      whereArgs: ['active_packing_set_id'],
    );
    if (rows.isEmpty) return null;
    final value = rows.first['value'] as String;
    if (value.isEmpty) return null;
    return int.tryParse(value);
  }

  Future<void> setActivePackingSetId(int? setId) async {
    await setAppSetting('active_packing_set_id', setId?.toString() ?? '');
  }

  Future<String?> getAppSetting(String key) async {
    final db = await database;
    final rows = await db.query(
      'app_setting',
      where: 'key = ?',
      whereArgs: [key],
    );
    if (rows.isEmpty) return null;
    final value = rows.first['value'] as String?;
    if (value == null || value.isEmpty) return null;
    return value;
  }

  Future<void> setAppSetting(String key, String value) async {
    final db = await database;
    await db.insert(
      'app_setting',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
