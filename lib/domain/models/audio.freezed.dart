// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'audio.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$MicState {

 bool get muted; bool get transmitting;
/// Create a copy of MicState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MicStateCopyWith<MicState> get copyWith => _$MicStateCopyWithImpl<MicState>(this as MicState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MicState&&(identical(other.muted, muted) || other.muted == muted)&&(identical(other.transmitting, transmitting) || other.transmitting == transmitting));
}


@override
int get hashCode => Object.hash(runtimeType,muted,transmitting);

@override
String toString() {
  return 'MicState(muted: $muted, transmitting: $transmitting)';
}


}

/// @nodoc
abstract mixin class $MicStateCopyWith<$Res>  {
  factory $MicStateCopyWith(MicState value, $Res Function(MicState) _then) = _$MicStateCopyWithImpl;
@useResult
$Res call({
 bool muted, bool transmitting
});




}
/// @nodoc
class _$MicStateCopyWithImpl<$Res>
    implements $MicStateCopyWith<$Res> {
  _$MicStateCopyWithImpl(this._self, this._then);

  final MicState _self;
  final $Res Function(MicState) _then;

/// Create a copy of MicState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? muted = null,Object? transmitting = null,}) {
  return _then(_self.copyWith(
muted: null == muted ? _self.muted : muted // ignore: cast_nullable_to_non_nullable
as bool,transmitting: null == transmitting ? _self.transmitting : transmitting // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [MicState].
extension MicStatePatterns on MicState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MicState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MicState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MicState value)  $default,){
final _that = this;
switch (_that) {
case _MicState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MicState value)?  $default,){
final _that = this;
switch (_that) {
case _MicState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool muted,  bool transmitting)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MicState() when $default != null:
return $default(_that.muted,_that.transmitting);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool muted,  bool transmitting)  $default,) {final _that = this;
switch (_that) {
case _MicState():
return $default(_that.muted,_that.transmitting);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool muted,  bool transmitting)?  $default,) {final _that = this;
switch (_that) {
case _MicState() when $default != null:
return $default(_that.muted,_that.transmitting);case _:
  return null;

}
}

}

/// @nodoc


class _MicState implements MicState {
  const _MicState({this.muted = false, this.transmitting = false});
  

@override@JsonKey() final  bool muted;
@override@JsonKey() final  bool transmitting;

/// Create a copy of MicState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MicStateCopyWith<_MicState> get copyWith => __$MicStateCopyWithImpl<_MicState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MicState&&(identical(other.muted, muted) || other.muted == muted)&&(identical(other.transmitting, transmitting) || other.transmitting == transmitting));
}


@override
int get hashCode => Object.hash(runtimeType,muted,transmitting);

@override
String toString() {
  return 'MicState(muted: $muted, transmitting: $transmitting)';
}


}

/// @nodoc
abstract mixin class _$MicStateCopyWith<$Res> implements $MicStateCopyWith<$Res> {
  factory _$MicStateCopyWith(_MicState value, $Res Function(_MicState) _then) = __$MicStateCopyWithImpl;
@override @useResult
$Res call({
 bool muted, bool transmitting
});




}
/// @nodoc
class __$MicStateCopyWithImpl<$Res>
    implements _$MicStateCopyWith<$Res> {
  __$MicStateCopyWithImpl(this._self, this._then);

  final _MicState _self;
  final $Res Function(_MicState) _then;

/// Create a copy of MicState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? muted = null,Object? transmitting = null,}) {
  return _then(_MicState(
muted: null == muted ? _self.muted : muted // ignore: cast_nullable_to_non_nullable
as bool,transmitting: null == transmitting ? _self.transmitting : transmitting // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
