import 'gear.dart';

class PackingSet {
  final int? id;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<PackingPlacement>? placements; // 積載場所のリスト

  const PackingSet({
    this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    this.placements,
  });

  PackingSet copyWith({
    int? id,
    String? name,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<PackingPlacement>? placements,
  }) {
    return PackingSet(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      placements: placements ?? this.placements,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory PackingSet.fromMap(Map<String, dynamic> map) {
    return PackingSet(
      id: map['id'] as int?,
      name: map['name'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'placements': placements?.map((p) => p.toJson()).toList(),
      };
}

class PackingPlacement {
  final int? id;
  final int setId;
  final String name;
  final String? imageFile; // 背景画像用
  final int sortOrder;
  final List<PackingSetItem>? items;

  const PackingPlacement({
    this.id,
    required this.setId,
    required this.name,
    this.imageFile,
    this.sortOrder = 0,
    this.items,
  });

  /// 配置場所ごとの合計重量を計算（g）
  double get totalWeight {
    if (items == null) return 0;
    return items!.fold(0.0, (sum, item) {
      final gear = item.gear;
      if (gear == null) return sum;
      return sum + (gear.weight ?? 0) * gear.quantity;
    });
  }

  PackingPlacement copyWith({
    int? id,
    int? setId,
    String? name,
    String? imageFile,
    bool clearImage = false,
    int? sortOrder,
    List<PackingSetItem>? items,
  }) {
    return PackingPlacement(
      id: id ?? this.id,
      setId: setId ?? this.setId,
      name: name ?? this.name,
      imageFile: clearImage ? null : (imageFile ?? this.imageFile),
      sortOrder: sortOrder ?? this.sortOrder,
      items: items ?? this.items,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'set_id': setId,
      'name': name,
      'image_file': imageFile,
      'sort_order': sortOrder,
    };
  }

  factory PackingPlacement.fromMap(Map<String, dynamic> map) {
    return PackingPlacement(
      id: map['id'] as int?,
      setId: map['set_id'] as int,
      name: map['name'] as String,
      imageFile: map['image_file'] as String?,
      sortOrder: map['sort_order'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'setId': setId,
        'name': name,
        'imageFile': imageFile,
        'sortOrder': sortOrder,
        'items': items?.map((i) => i.toJson()).toList(),
      };
}

class PackingSetItem {
  final int setId;
  final int gearId;
  final int? placementId; // どの積載場所に紐付いているか
  final bool isPacked;
  final int sortOrder;
  final Gear? gear; // 表示用にGear情報を持てるように拡張

  const PackingSetItem({
    required this.setId,
    required this.gearId,
    this.placementId,
    this.isPacked = false,
    this.sortOrder = 0,
    this.gear,
  });

  PackingSetItem copyWith({
    bool? isPacked,
    int? sortOrder,
    int? placementId,
    bool clearPlacement = false,
    Gear? gear,
  }) {
    return PackingSetItem(
      setId: setId,
      gearId: gearId,
      placementId: clearPlacement ? null : (placementId ?? this.placementId),
      isPacked: isPacked ?? this.isPacked,
      sortOrder: sortOrder ?? this.sortOrder,
      gear: gear ?? this.gear,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'set_id': setId,
      'gear_id': gearId,
      'placement_id': placementId,
      'is_packed': isPacked ? 1 : 0,
      'sort_order': sortOrder,
    };
  }

  factory PackingSetItem.fromMap(Map<String, dynamic> map) {
    return PackingSetItem(
      setId: map['set_id'] as int,
      gearId: map['gear_id'] as int,
      placementId: map['placement_id'] as int?,
      isPacked: (map['is_packed'] as int) == 1,
      sortOrder: map['sort_order'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'setId': setId,
        'gearId': gearId,
        'placementId': placementId,
        'isPacked': isPacked,
        'sortOrder': sortOrder,
        'gear': gear?.toJson(),
      };
}
