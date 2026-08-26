// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'member.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$Member {

 String get id; String get displayName; bool get isHost; bool get isSelf; MemberPresence get presence; bool get isTalking;
/// Create a copy of Member
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MemberCopyWith<Member> get copyWith => _$MemberCopyWithImpl<Member>(this as Member, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Member&&(identical(other.id, id) || other.id == id)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.isHost, isHost) || other.isHost == isHost)&&(identical(other.isSelf, isSelf) || other.isSelf == isSelf)&&(identical(other.presence, presence) || other.presence == presence)&&(identical(other.isTalking, isTalking) || other.isTalking == isTalking));
}


@override
int get hashCode => Object.hash(runtimeType,id,displayName,isHost,isSelf,presence,isTalking);

@override
String toString() {
  return 'Member(id: $id, displayName: $displayName, isHost: $isHost, isSelf: $isSelf, presence: $presence, isTalking: $isTalking)';
}


}

/// @nodoc
abstract mixin class $MemberCopyWith<$Res>  {
  factory $MemberCopyWith(Member value, $Res Function(Member) _then) = _$MemberCopyWithImpl;
@useResult
$Res call({
 String id, String displayName, bool isHost, bool isSelf, MemberPresence presence, bool isTalking
});




}
/// @nodoc
class _$MemberCopyWithImpl<$Res>
    implements $MemberCopyWith<$Res> {
  _$MemberCopyWithImpl(this._self, this._then);

  final Member _self;
  final $Res Function(Member) _then;

/// Create a copy of Member
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? displayName = null,Object? isHost = null,Object? isSelf = null,Object? presence = null,Object? isTalking = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,isHost: null == isHost ? _self.isHost : isHost // ignore: cast_nullable_to_non_nullable
as bool,isSelf: null == isSelf ? _self.isSelf : isSelf // ignore: cast_nullable_to_non_nullable
as bool,presence: null == presence ? _self.presence : presence // ignore: cast_nullable_to_non_nullable
as MemberPresence,isTalking: null == isTalking ? _self.isTalking : isTalking // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [Member].
extension MemberPatterns on Member {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Member value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Member() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Member value)  $default,){
final _that = this;
switch (_that) {
case _Member():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Member value)?  $default,){
final _that = this;
switch (_that) {
case _Member() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String displayName,  bool isHost,  bool isSelf,  MemberPresence presence,  bool isTalking)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Member() when $default != null:
return $default(_that.id,_that.displayName,_that.isHost,_that.isSelf,_that.presence,_that.isTalking);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String displayName,  bool isHost,  bool isSelf,  MemberPresence presence,  bool isTalking)  $default,) {final _that = this;
switch (_that) {
case _Member():
return $default(_that.id,_that.displayName,_that.isHost,_that.isSelf,_that.presence,_that.isTalking);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String displayName,  bool isHost,  bool isSelf,  MemberPresence presence,  bool isTalking)?  $default,) {final _that = this;
switch (_that) {
case _Member() when $default != null:
return $default(_that.id,_that.displayName,_that.isHost,_that.isSelf,_that.presence,_that.isTalking);case _:
  return null;

}
}

}

/// @nodoc


class _Member implements Member {
  const _Member({required this.id, required this.displayName, this.isHost = false, this.isSelf = false, this.presence = MemberPresence.online, this.isTalking = false});
  

@override final  String id;
@override final  String displayName;
@override@JsonKey() final  bool isHost;
@override@JsonKey() final  bool isSelf;
@override@JsonKey() final  MemberPresence presence;
@override@JsonKey() final  bool isTalking;

/// Create a copy of Member
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MemberCopyWith<_Member> get copyWith => __$MemberCopyWithImpl<_Member>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Member&&(identical(other.id, id) || other.id == id)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.isHost, isHost) || other.isHost == isHost)&&(identical(other.isSelf, isSelf) || other.isSelf == isSelf)&&(identical(other.presence, presence) || other.presence == presence)&&(identical(other.isTalking, isTalking) || other.isTalking == isTalking));
}


@override
int get hashCode => Object.hash(runtimeType,id,displayName,isHost,isSelf,presence,isTalking);

@override
String toString() {
  return 'Member(id: $id, displayName: $displayName, isHost: $isHost, isSelf: $isSelf, presence: $presence, isTalking: $isTalking)';
}


}

/// @nodoc
abstract mixin class _$MemberCopyWith<$Res> implements $MemberCopyWith<$Res> {
  factory _$MemberCopyWith(_Member value, $Res Function(_Member) _then) = __$MemberCopyWithImpl;
@override @useResult
$Res call({
 String id, String displayName, bool isHost, bool isSelf, MemberPresence presence, bool isTalking
});




}
/// @nodoc
class __$MemberCopyWithImpl<$Res>
    implements _$MemberCopyWith<$Res> {
  __$MemberCopyWithImpl(this._self, this._then);

  final _Member _self;
  final $Res Function(_Member) _then;

/// Create a copy of Member
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? displayName = null,Object? isHost = null,Object? isSelf = null,Object? presence = null,Object? isTalking = null,}) {
  return _then(_Member(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,isHost: null == isHost ? _self.isHost : isHost // ignore: cast_nullable_to_non_nullable
as bool,isSelf: null == isSelf ? _self.isSelf : isSelf // ignore: cast_nullable_to_non_nullable
as bool,presence: null == presence ? _self.presence : presence // ignore: cast_nullable_to_non_nullable
as MemberPresence,isTalking: null == isTalking ? _self.isTalking : isTalking // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
