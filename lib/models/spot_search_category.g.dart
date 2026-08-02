// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'spot_search_category.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_SpotSearchCategory _$SpotSearchCategoryFromJson(Map<String, dynamic> json) =>
    _SpotSearchCategory(
      id: (json['id'] as num?)?.toInt(),
      name: json['name'] as String,
      searchWord: json['searchWord'] as String,
      iconCodePoint: (json['iconCodePoint'] as num).toInt(),
      isDefault: json['isDefault'] as bool? ?? false,
      enabled: json['enabled'] as bool? ?? true,
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$SpotSearchCategoryToJson(_SpotSearchCategory instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'searchWord': instance.searchWord,
      'iconCodePoint': instance.iconCodePoint,
      'isDefault': instance.isDefault,
      'enabled': instance.enabled,
      'sortOrder': instance.sortOrder,
    };
