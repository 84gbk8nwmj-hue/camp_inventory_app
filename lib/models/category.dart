class GearCategory {
  final int? id;
  final String name;
  final int sortOrder;

  const GearCategory({
    this.id,
    required this.name,
    this.sortOrder = 0,
  });

  GearCategory copyWith({int? id, String? name, int? sortOrder}) {
    return GearCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'sort_order': sortOrder,
    };
  }

  factory GearCategory.fromMap(Map<String, dynamic> map) {
    return GearCategory(
      id: map['id'] as int?,
      name: map['name'] as String,
      sortOrder: map['sort_order'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'sortOrder': sortOrder,
      };
}
