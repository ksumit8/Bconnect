// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'group_config.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$GroupConfig {

 String get name; String? get password;
/// Create a copy of GroupConfig
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GroupConfigCopyWith<GroupConfig> get copyWith => _$GroupConfigCopyWithImpl<GroupConfig>(this as GroupConfig, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GroupConfig&&(identical(other.name, name) || other.name == name)&&(identical(other.password, password) || other.password == password));
}


@override
int get hashCode => Object.hash(runtimeType,name,password);

@override
String toString() {
  return 'GroupConfig(name: $name, password: $password)';
}


}

/// @nodoc
abstract mixin class $GroupConfigCopyWith<$Res>  {
  factory $GroupConfigCopyWith(GroupConfig value, $Res Function(GroupConfig) _then) = _$GroupConfigCopyWithImpl;
@useResult
$Res call({
 String name, String? password
});




}
/// @nodoc
class _$GroupConfigCopyWithImpl<$Res>
    implements $GroupConfigCopyWith<$Res> {
  _$GroupConfigCopyWithImpl(this._self, this._then);

  final GroupConfig _self;
  final $Res Function(GroupConfig) _then;

/// Create a copy of GroupConfig
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? password = freezed,}) {
  return _then(_self.copyWith(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,password: freezed == password ? _self.password : password // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [GroupConfig].
extension GroupConfigPatterns on GroupConfig {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _GroupConfig value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _GroupConfig() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _GroupConfig value)  $default,){
final _that = this;
switch (_that) {
case _GroupConfig():
return $default(_that);case _:
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _GroupConfig value)?  $default,){
final _that = this;
switch (_that) {
case _GroupConfig() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  String? password)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _GroupConfig() when $default != null:
return $default(_that.name,_that.password);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  String? password)  $default,) {final _that = this;
switch (_that) {
case _GroupConfig():
return $default(_that.name,_that.password);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  String? password)?  $default,) {final _that = this;
switch (_that) {
case _GroupConfig() when $default != null:
return $default(_that.name,_that.password);case _:
  return null;

}
}

}

/// @nodoc


class _GroupConfig extends GroupConfig {
  const _GroupConfig({required this.name, this.password}): super._();
  

@override final  String name;
@override final  String? password;

/// Create a copy of GroupConfig
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GroupConfigCopyWith<_GroupConfig> get copyWith => __$GroupConfigCopyWithImpl<_GroupConfig>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _GroupConfig&&(identical(other.name, name) || other.name == name)&&(identical(other.password, password) || other.password == password));
}


@override
int get hashCode => Object.hash(runtimeType,name,password);

@override
String toString() {
  return 'GroupConfig(name: $name, password: $password)';
}


}

/// @nodoc
abstract mixin class _$GroupConfigCopyWith<$Res> implements $GroupConfigCopyWith<$Res> {
  factory _$GroupConfigCopyWith(_GroupConfig value, $Res Function(_GroupConfig) _then) = __$GroupConfigCopyWithImpl;
@override @useResult
$Res call({
 String name, String? password
});




}
/// @nodoc
class __$GroupConfigCopyWithImpl<$Res>
    implements _$GroupConfigCopyWith<$Res> {
  __$GroupConfigCopyWithImpl(this._self, this._then);

  final _GroupConfig _self;
  final $Res Function(_GroupConfig) _then;

/// Create a copy of GroupConfig
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? password = freezed,}) {
  return _then(_GroupConfig(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,password: freezed == password ? _self.password : password // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
