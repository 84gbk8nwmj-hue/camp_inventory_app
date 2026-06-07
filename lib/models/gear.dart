class Gear {
  final int? id;
  final String name;
  final int categoryId;
  final String categoryName;
  final int quantity;
  final double? weight;
  /// 相対ファイル名（gear_images/ 内）。絶対パスは保存しない。
  final String? imageFile;
  final String? note;
  final String? manufacturer;
  final bool weightVerified;
  final int sortOrder;
  final int? parentId;

  const Gear({
    this.id,
    required this.name,
    required this.categoryId,
    required this.categoryName,
    required this.quantity,
    this.weight,
    this.imageFile,
    this.note,
    this.manufacturer,
    this.weightVerified = false,
    this.sortOrder = 0,
    this.parentId,
  });

  Gear copyWith({
    int? id,
    String? name,
    int? categoryId,
    String? categoryName,
    int? quantity,
    double? weight,
    String? imageFile,
    String? note,
    String? manufacturer,
    bool? weightVerified,
    int? sortOrder,
    int? parentId,
    bool clearImageFile = false,
    bool clearManufacturer = false,
    bool clearParentId = false,
  }) {
    return Gear(
      id: id ?? this.id,
      name: name ?? this.name,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      quantity: quantity ?? this.quantity,
      weight: weight ?? this.weight,
      imageFile: clearImageFile ? null : (imageFile ?? this.imageFile),
      note: note ?? this.note,
      manufacturer:
          clearManufacturer ? null : (manufacturer ?? this.manufacturer),
      weightVerified: weightVerified ?? this.weightVerified,
      sortOrder: sortOrder ?? this.sortOrder,
      parentId: clearParentId ? null : (parentId ?? this.parentId),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'category_id': categoryId,
      'quantity': quantity,
      'weight': weight,
      'image_file': imageFile,
      'note': note,
      'manufacturer': manufacturer,
      'weight_verified': weightVerified ? 1 : 0,
      'sort_order': sortOrder,
      'parent_id': parentId,
    };
  }

  factory Gear.fromMap(Map<String, dynamic> map) {
    return Gear(
      id: map['id'] as int?,
      name: map['name'] as String,
      categoryId: map['category_id'] as int,
      categoryName: map['category_name'] as String? ?? '',
      quantity: map['quantity'] as int,
      weight: map['weight'] as double?,
      imageFile: map['image_file'] as String?,
      note: map['note'] as String?,
      manufacturer: map['manufacturer'] as String?,
      weightVerified: (map['weight_verified'] as int? ?? 0) == 1,
      sortOrder: map['sort_order'] as int? ?? 0,
      parentId: map['parent_id'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'categoryId': categoryId,
      'categoryName': categoryName,
      'quantity': quantity,
      'weight': weight,
      'imageFile': imageFile,
      'note': note,
      'manufacturer': manufacturer,
      'weightVerified': weightVerified,
      'sortOrder': sortOrder,
      'parentId': parentId,
    };
  }
}
