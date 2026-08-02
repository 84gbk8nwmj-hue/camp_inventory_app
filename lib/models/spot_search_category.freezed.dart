// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'spot_search_category.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SpotSearchCategory {
  int? get id;
  String get name;
  String get searchWord;
  int get iconCodePoint;
  bool get isDefault;
  bool get enabled;
  int get sortOrder;

  /// Create a copy of SpotSearchCategory
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $SpotSearchCategoryCopyWith<SpotSearchCategory> get copyWith =>
      _$SpotSearchCategoryCopyWithImpl<SpotSearchCategory>(
          this as SpotSearchCategory, _$identity);

  /// Serializes this SpotSearchCategory to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is SpotSearchCategory &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.searchWord, searchWord) ||
                other.searchWord == searchWord) &&
            (identical(other.iconCodePoint, iconCodePoint) ||
                other.iconCodePoint == iconCodePoint) &&
            (identical(other.isDefault, isDefault) ||
                other.isDefault == isDefault) &&
            (identical(other.enabled, enabled) || other.enabled == enabled) &&
            (identical(other.sortOrder, sortOrder) ||
                other.sortOrder == sortOrder));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, name, searchWord,
      iconCodePoint, isDefault, enabled, sortOrder);

  @override
  String toString() {
    return 'SpotSearchCategory(id: $id, name: $name, searchWord: $searchWord, iconCodePoint: $iconCodePoint, isDefault: $isDefault, enabled: $enabled, sortOrder: $sortOrder)';
  }
}

/// @nodoc
abstract mixin class $SpotSearchCategoryCopyWith<$Res> {
  factory $SpotSearchCategoryCopyWith(
          SpotSearchCategory value, $Res Function(SpotSearchCategory) _then) =
      _$SpotSearchCategoryCopyWithImpl;
  @useResult
  $Res call(
      {int? id,
      String name,
      String searchWord,
      int iconCodePoint,
      bool isDefault,
      bool enabled,
      int sortOrder});
}

/// @nodoc
class _$SpotSearchCategoryCopyWithImpl<$Res>
    implements $SpotSearchCategoryCopyWith<$Res> {
  _$SpotSearchCategoryCopyWithImpl(this._self, this._then);

  final SpotSearchCategory _self;
  final $Res Function(SpotSearchCategory) _then;

  /// Create a copy of SpotSearchCategory
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = freezed,
    Object? name = null,
    Object? searchWord = null,
    Object? iconCodePoint = null,
    Object? isDefault = null,
    Object? enabled = null,
    Object? sortOrder = null,
  }) {
    return _then(_self.copyWith(
      id: freezed == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as int?,
      name: null == name
          ? _self.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      searchWord: null == searchWord
          ? _self.searchWord
          : searchWord // ignore: cast_nullable_to_non_nullable
              as String,
      iconCodePoint: null == iconCodePoint
          ? _self.iconCodePoint
          : iconCodePoint // ignore: cast_nullable_to_non_nullable
              as int,
      isDefault: null == isDefault
          ? _self.isDefault
          : isDefault // ignore: cast_nullable_to_non_nullable
              as bool,
      enabled: null == enabled
          ? _self.enabled
          : enabled // ignore: cast_nullable_to_non_nullable
              as bool,
      sortOrder: null == sortOrder
          ? _self.sortOrder
          : sortOrder // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// Adds pattern-matching-related methods to [SpotSearchCategory].
extension SpotSearchCategoryPatterns on SpotSearchCategory {
  /// A variant of `map` that fallback to returning `orElse`.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case _:
  ///     return orElse();
  /// }
  /// ```

  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>(
    TResult Function(_SpotSearchCategory value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _SpotSearchCategory() when $default != null:
        return $default(_that);
      case _:
        return orElse();
    }
  }

  /// A `switch`-like method, using callbacks.
  ///
  /// Callbacks receives the raw object, upcasted.
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case final Subclass2 value:
  ///     return ...;
  /// }
  /// ```

  @optionalTypeArgs
  TResult map<TResult extends Object?>(
    TResult Function(_SpotSearchCategory value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SpotSearchCategory():
        return $default(_that);
      case _:
        throw StateError('Unexpected subclass');
    }
  }

  /// A variant of `map` that fallback to returning `null`.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case _:
  ///     return null;
  /// }
  /// ```

  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>(
    TResult? Function(_SpotSearchCategory value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SpotSearchCategory() when $default != null:
        return $default(_that);
      case _:
        return null;
    }
  }

  /// A variant of `when` that fallback to an `orElse` callback.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case _:
  ///     return orElse();
  /// }
  /// ```

  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>(
    TResult Function(int? id, String name, String searchWord, int iconCodePoint,
            bool isDefault, bool enabled, int sortOrder)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _SpotSearchCategory() when $default != null:
        return $default(
            _that.id,
            _that.name,
            _that.searchWord,
            _that.iconCodePoint,
            _that.isDefault,
            _that.enabled,
            _that.sortOrder);
      case _:
        return orElse();
    }
  }

  /// A `switch`-like method, using callbacks.
  ///
  /// As opposed to `map`, this offers destructuring.
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case Subclass2(:final field2):
  ///     return ...;
  /// }
  /// ```

  @optionalTypeArgs
  TResult when<TResult extends Object?>(
    TResult Function(int? id, String name, String searchWord, int iconCodePoint,
            bool isDefault, bool enabled, int sortOrder)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SpotSearchCategory():
        return $default(
            _that.id,
            _that.name,
            _that.searchWord,
            _that.iconCodePoint,
            _that.isDefault,
            _that.enabled,
            _that.sortOrder);
      case _:
        throw StateError('Unexpected subclass');
    }
  }

  /// A variant of `when` that fallback to returning `null`
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case _:
  ///     return null;
  /// }
  /// ```

  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>(
    TResult? Function(int? id, String name, String searchWord,
            int iconCodePoint, bool isDefault, bool enabled, int sortOrder)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SpotSearchCategory() when $default != null:
        return $default(
            _that.id,
            _that.name,
            _that.searchWord,
            _that.iconCodePoint,
            _that.isDefault,
            _that.enabled,
            _that.sortOrder);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _SpotSearchCategory extends SpotSearchCategory {
  const _SpotSearchCategory(
      {this.id,
      required this.name,
      required this.searchWord,
      required this.iconCodePoint,
      this.isDefault = false,
      this.enabled = true,
      this.sortOrder = 0})
      : super._();
  factory _SpotSearchCategory.fromJson(Map<String, dynamic> json) =>
      _$SpotSearchCategoryFromJson(json);

  @override
  final int? id;
  @override
  final String name;
  @override
  final String searchWord;
  @override
  final int iconCodePoint;
  @override
  @JsonKey()
  final bool isDefault;
  @override
  @JsonKey()
  final bool enabled;
  @override
  @JsonKey()
  final int sortOrder;

  /// Create a copy of SpotSearchCategory
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$SpotSearchCategoryCopyWith<_SpotSearchCategory> get copyWith =>
      __$SpotSearchCategoryCopyWithImpl<_SpotSearchCategory>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$SpotSearchCategoryToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _SpotSearchCategory &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.searchWord, searchWord) ||
                other.searchWord == searchWord) &&
            (identical(other.iconCodePoint, iconCodePoint) ||
                other.iconCodePoint == iconCodePoint) &&
            (identical(other.isDefault, isDefault) ||
                other.isDefault == isDefault) &&
            (identical(other.enabled, enabled) || other.enabled == enabled) &&
            (identical(other.sortOrder, sortOrder) ||
                other.sortOrder == sortOrder));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, name, searchWord,
      iconCodePoint, isDefault, enabled, sortOrder);

  @override
  String toString() {
    return 'SpotSearchCategory(id: $id, name: $name, searchWord: $searchWord, iconCodePoint: $iconCodePoint, isDefault: $isDefault, enabled: $enabled, sortOrder: $sortOrder)';
  }
}

/// @nodoc
abstract mixin class _$SpotSearchCategoryCopyWith<$Res>
    implements $SpotSearchCategoryCopyWith<$Res> {
  factory _$SpotSearchCategoryCopyWith(
          _SpotSearchCategory value, $Res Function(_SpotSearchCategory) _then) =
      __$SpotSearchCategoryCopyWithImpl;
  @override
  @useResult
  $Res call(
      {int? id,
      String name,
      String searchWord,
      int iconCodePoint,
      bool isDefault,
      bool enabled,
      int sortOrder});
}

/// @nodoc
class __$SpotSearchCategoryCopyWithImpl<$Res>
    implements _$SpotSearchCategoryCopyWith<$Res> {
  __$SpotSearchCategoryCopyWithImpl(this._self, this._then);

  final _SpotSearchCategory _self;
  final $Res Function(_SpotSearchCategory) _then;

  /// Create a copy of SpotSearchCategory
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = freezed,
    Object? name = null,
    Object? searchWord = null,
    Object? iconCodePoint = null,
    Object? isDefault = null,
    Object? enabled = null,
    Object? sortOrder = null,
  }) {
    return _then(_SpotSearchCategory(
      id: freezed == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as int?,
      name: null == name
          ? _self.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      searchWord: null == searchWord
          ? _self.searchWord
          : searchWord // ignore: cast_nullable_to_non_nullable
              as String,
      iconCodePoint: null == iconCodePoint
          ? _self.iconCodePoint
          : iconCodePoint // ignore: cast_nullable_to_non_nullable
              as int,
      isDefault: null == isDefault
          ? _self.isDefault
          : isDefault // ignore: cast_nullable_to_non_nullable
              as bool,
      enabled: null == enabled
          ? _self.enabled
          : enabled // ignore: cast_nullable_to_non_nullable
              as bool,
      sortOrder: null == sortOrder
          ? _self.sortOrder
          : sortOrder // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

// dart format on
