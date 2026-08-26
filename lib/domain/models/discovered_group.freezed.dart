// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'discovered_group.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$DiscoveredGroup {

/// Four lowercase hex digits, from the 2-byte advertised group id.
 String get groupId;/// Transport-specific address used to open a connection.
 String get deviceId; String get name; int get memberCount; bool get isLocked; bool get isFull; int get rssi; DateTime get lastSeen;
/// Create a copy of DiscoveredGroup
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DiscoveredGroupCopyWith<DiscoveredGroup> get copyWith => _$DiscoveredGroupCopyWithImpl<DiscoveredGroup>(this as DiscoveredGroup, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DiscoveredGroup&&(identical(other.groupId, groupId) || other.groupId == groupId)&&(identical(other.deviceId, deviceId) || other.deviceId == deviceId)&&(identical(other.name, name) || other.name == name)&&(identical(other.memberCount, memberCount) || other.memberCount == memberCount)&&(identical(other.isLocked, isLocked) || other.isLocked == isLocked)&&(identical(other.isFull, isFull) || other.isFull == isFull)&&(identical(other.rssi, rssi) || other.rssi == rssi)&&(identical(other.lastSeen, lastSeen) || other.lastSeen == lastSeen));
}


@override
int get hashCode => Object.hash(runtimeType,groupId,deviceId,name,memberCount,isLocked,isFull,rssi,lastSeen);

@override
String toString() {
  return 'DiscoveredGroup(groupId: $groupId, deviceId: $deviceId, name: $name, memberCount: $memberCount, isLocked: $isLocked, isFull: $isFull, rssi: $rssi, lastSeen: $lastSeen)';
}


}

/// @nodoc
abstract mixin class $DiscoveredGroupCopyWith<$Res>  {
  factory $DiscoveredGroupCopyWith(DiscoveredGroup value, $Res Function(DiscoveredGroup) _then) = _$DiscoveredGroupCopyWithImpl;
@useResult
$Res call({
 String groupId, String deviceId, String name, int memberCount, bool isLocked, bool isFull, int rssi, DateTime lastSeen
});




}
/// @nodoc
class _$DiscoveredGroupCopyWithImpl<$Res>
    implements $DiscoveredGroupCopyWith<$Res> {
  _$DiscoveredGroupCopyWithImpl(this._self, this._then);

  final DiscoveredGroup _self;
  final $Res Function(DiscoveredGroup) _then;

/// Create a copy of DiscoveredGroup
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? groupId = null,Object? deviceId = null,Object? name = null,Object? memberCount = null,Object? isLocked = null,Object? isFull = null,Object? rssi = null,Object? lastSeen = null,}) {
  return _then(_self.copyWith(
groupId: null == groupId ? _self.groupId : groupId // ignore: cast_nullable_to_non_nullable
as String,deviceId: null == deviceId ? _self.deviceId : deviceId // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,memberCount: null == memberCount ? _self.memberCount : memberCount // ignore: cast_nullable_to_non_nullable
as int,isLocked: null == isLocked ? _self.isLocked : isLocked // ignore: cast_nullable_to_non_nullable
as bool,isFull: null == isFull ? _self.isFull : isFull // ignore: cast_nullable_to_non_nullable
as bool,rssi: null == rssi ? _self.rssi : rssi // ignore: cast_nullable_to_non_nullable
as int,lastSeen: null == lastSeen ? _self.lastSeen : lastSeen // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [DiscoveredGroup].
extension DiscoveredGroupPatterns on DiscoveredGroup {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DiscoveredGroup value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DiscoveredGroup() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DiscoveredGroup value)  $default,){
final _that = this;
switch (_that) {
case _DiscoveredGroup():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DiscoveredGroup value)?  $default,){
final _that = this;
switch (_that) {
case _DiscoveredGroup() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String groupId,  String deviceId,  String name,  int memberCount,  bool isLocked,  bool isFull,  int rssi,  DateTime lastSeen)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DiscoveredGroup() when $default != null:
return $default(_that.groupId,_that.deviceId,_that.name,_that.memberCount,_that.isLocked,_that.isFull,_that.rssi,_that.lastSeen);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String groupId,  String deviceId,  String name,  int memberCount,  bool isLocked,  bool isFull,  int rssi,  DateTime lastSeen)  $default,) {final _that = this;
switch (_that) {
case _DiscoveredGroup():
return $default(_that.groupId,_that.deviceId,_that.name,_that.memberCount,_that.isLocked,_that.isFull,_that.rssi,_that.lastSeen);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String groupId,  String deviceId,  String name,  int memberCount,  bool isLocked,  bool isFull,  int rssi,  DateTime lastSeen)?  $default,) {final _that = this;
switch (_that) {
case _DiscoveredGroup() when $default != null:
return $default(_that.groupId,_that.deviceId,_that.name,_that.memberCount,_that.isLocked,_that.isFull,_that.rssi,_that.lastSeen);case _:
  return null;

}
}

}

/// @nodoc


class _DiscoveredGroup implements DiscoveredGroup {
  const _DiscoveredGroup({required this.groupId, required this.deviceId, required this.name, required this.memberCount, required this.isLocked, required this.isFull, required this.rssi, required this.lastSeen});
  

/// Four lowercase hex digits, from the 2-byte advertised group id.
@override final  String groupId;
/// Transport-specific address used to open a connection.
@override final  String deviceId;
@override final  String name;
@override final  int memberCount;
@override final  bool isLocked;
@override final  bool isFull;
@override final  int rssi;
@override final  DateTime lastSeen;

/// Create a copy of DiscoveredGroup
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DiscoveredGroupCopyWith<_DiscoveredGroup> get copyWith => __$DiscoveredGroupCopyWithImpl<_DiscoveredGroup>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DiscoveredGroup&&(identical(other.groupId, groupId) || other.groupId == groupId)&&(identical(other.deviceId, deviceId) || other.deviceId == deviceId)&&(identical(other.name, name) || other.name == name)&&(identical(other.memberCount, memberCount) || other.memberCount == memberCount)&&(identical(other.isLocked, isLocked) || other.isLocked == isLocked)&&(identical(other.isFull, isFull) || other.isFull == isFull)&&(identical(other.rssi, rssi) || other.rssi == rssi)&&(identical(other.lastSeen, lastSeen) || other.lastSeen == lastSeen));
}


@override
int get hashCode => Object.hash(runtimeType,groupId,deviceId,name,memberCount,isLocked,isFull,rssi,lastSeen);

@override
String toString() {
  return 'DiscoveredGroup(groupId: $groupId, deviceId: $deviceId, name: $name, memberCount: $memberCount, isLocked: $isLocked, isFull: $isFull, rssi: $rssi, lastSeen: $lastSeen)';
}


}

/// @nodoc
abstract mixin class _$DiscoveredGroupCopyWith<$Res> implements $DiscoveredGroupCopyWith<$Res> {
  factory _$DiscoveredGroupCopyWith(_DiscoveredGroup value, $Res Function(_DiscoveredGroup) _then) = __$DiscoveredGroupCopyWithImpl;
@override @useResult
$Res call({
 String groupId, String deviceId, String name, int memberCount, bool isLocked, bool isFull, int rssi, DateTime lastSeen
});




}
/// @nodoc
class __$DiscoveredGroupCopyWithImpl<$Res>
    implements _$DiscoveredGroupCopyWith<$Res> {
  __$DiscoveredGroupCopyWithImpl(this._self, this._then);

  final _DiscoveredGroup _self;
  final $Res Function(_DiscoveredGroup) _then;

/// Create a copy of DiscoveredGroup
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? groupId = null,Object? deviceId = null,Object? name = null,Object? memberCount = null,Object? isLocked = null,Object? isFull = null,Object? rssi = null,Object? lastSeen = null,}) {
  return _then(_DiscoveredGroup(
groupId: null == groupId ? _self.groupId : groupId // ignore: cast_nullable_to_non_nullable
as String,deviceId: null == deviceId ? _self.deviceId : deviceId // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,memberCount: null == memberCount ? _self.memberCount : memberCount // ignore: cast_nullable_to_non_nullable
as int,isLocked: null == isLocked ? _self.isLocked : isLocked // ignore: cast_nullable_to_non_nullable
as bool,isFull: null == isFull ? _self.isFull : isFull // ignore: cast_nullable_to_non_nullable
as bool,rssi: null == rssi ? _self.rssi : rssi // ignore: cast_nullable_to_non_nullable
as int,lastSeen: null == lastSeen ? _self.lastSeen : lastSeen // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

// dart format on
