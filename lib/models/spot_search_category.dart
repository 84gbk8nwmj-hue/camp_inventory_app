import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:flutter/material.dart';

part 'spot_search_category.freezed.dart';
part 'spot_search_category.g.dart';

@freezed
abstract class SpotSearchCategory with _$SpotSearchCategory {
  const SpotSearchCategory._();

  const factory SpotSearchCategory({
    int? id,
    required String name,
    required String searchWord,
    required int iconCodePoint,
    @Default(false) bool isDefault,
    @Default(true) bool enabled,
    @Default(0) int sortOrder,
  }) = _SpotSearchCategory;

  factory SpotSearchCategory.fromJson(Map<String, dynamic> json) =>
      _$SpotSearchCategoryFromJson(json);

  IconData get icon {
    return IconData(
      // ignore: non_const_argument_for_const_parameter
      iconCodePoint,
      fontFamily: 'MaterialIcons',
    );
  }
}