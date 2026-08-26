// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'session_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$SessionState {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionState);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'SessionState()';
}


}

/// @nodoc
class $SessionStateCopyWith<$Res>  {
$SessionStateCopyWith(SessionState _, $Res Function(SessionState) __);
}


/// Adds pattern-matching-related methods to [SessionState].
extension SessionStatePatterns on SessionState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( SessionIdle value)?  idle,TResult Function( SessionDiscovering value)?  discovering,TResult Function( SessionJoining value)?  joining,TResult Function( SessionConnected value)?  connected,TResult Function( SessionFailed value)?  failed,required TResult orElse(),}){
final _that = this;
switch (_that) {
case SessionIdle() when idle != null:
return idle(_that);case SessionDiscovering() when discovering != null:
return discovering(_that);case SessionJoining() when joining != null:
return joining(_that);case SessionConnected() when connected != null:
return connected(_that);case SessionFailed() when failed != null:
return failed(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( SessionIdle value)  idle,required TResult Function( SessionDiscovering value)  discovering,required TResult Function( SessionJoining value)  joining,required TResult Function( SessionConnected value)  connected,required TResult Function( SessionFailed value)  failed,}){
final _that = this;
switch (_that) {
case SessionIdle():
return idle(_that);case SessionDiscovering():
return discovering(_that);case SessionJoining():
return joining(_that);case SessionConnected():
return connected(_that);case SessionFailed():
return failed(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( SessionIdle value)?  idle,TResult? Function( SessionDiscovering value)?  discovering,TResult? Function( SessionJoining value)?  joining,TResult? Function( SessionConnected value)?  connected,TResult? Function( SessionFailed value)?  failed,}){
final _that = this;
switch (_that) {
case SessionIdle() when idle != null:
return idle(_that);case SessionDiscovering() when discovering != null:
return discovering(_that);case SessionJoining() when joining != null:
return joining(_that);case SessionConnected() when connected != null:
return connected(_that);case SessionFailed() when failed != null:
return failed(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  idle,TResult Function()?  discovering,TResult Function( DiscoveredGroup group,  JoinStep step)?  joining,TResult Function( String groupId,  String groupName,  String myMemberId,  bool isHost,  List<Member> roster)?  connected,TResult Function( SessionError error)?  failed,required TResult orElse(),}) {final _that = this;
switch (_that) {
case SessionIdle() when idle != null:
return idle();case SessionDiscovering() when discovering != null:
return discovering();case SessionJoining() when joining != null:
return joining(_that.group,_that.step);case SessionConnected() when connected != null:
return connected(_that.groupId,_that.groupName,_that.myMemberId,_that.isHost,_that.roster);case SessionFailed() when failed != null:
return failed(_that.error);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  idle,required TResult Function()  discovering,required TResult Function( DiscoveredGroup group,  JoinStep step)  joining,required TResult Function( String groupId,  String groupName,  String myMemberId,  bool isHost,  List<Member> roster)  connected,required TResult Function( SessionError error)  failed,}) {final _that = this;
switch (_that) {
case SessionIdle():
return idle();case SessionDiscovering():
return discovering();case SessionJoining():
return joining(_that.group,_that.step);case SessionConnected():
return connected(_that.groupId,_that.groupName,_that.myMemberId,_that.isHost,_that.roster);case SessionFailed():
return failed(_that.error);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  idle,TResult? Function()?  discovering,TResult? Function( DiscoveredGroup group,  JoinStep step)?  joining,TResult? Function( String groupId,  String groupName,  String myMemberId,  bool isHost,  List<Member> roster)?  connected,TResult? Function( SessionError error)?  failed,}) {final _that = this;
switch (_that) {
case SessionIdle() when idle != null:
return idle();case SessionDiscovering() when discovering != null:
return discovering();case SessionJoining() when joining != null:
return joining(_that.group,_that.step);case SessionConnected() when connected != null:
return connected(_that.groupId,_that.groupName,_that.myMemberId,_that.isHost,_that.roster);case SessionFailed() when failed != null:
return failed(_that.error);case _:
  return null;

}
}

}

/// @nodoc


class SessionIdle implements SessionState {
  const SessionIdle();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionIdle);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'SessionState.idle()';
}


}




/// @nodoc


class SessionDiscovering implements SessionState {
  const SessionDiscovering();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionDiscovering);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'SessionState.discovering()';
}


}




/// @nodoc


class SessionJoining implements SessionState {
  const SessionJoining({required this.group, required this.step});
  

 final  DiscoveredGroup group;
 final  JoinStep step;

/// Create a copy of SessionState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SessionJoiningCopyWith<SessionJoining> get copyWith => _$SessionJoiningCopyWithImpl<SessionJoining>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionJoining&&(identical(other.group, group) || other.group == group)&&(identical(other.step, step) || other.step == step));
}


@override
int get hashCode => Object.hash(runtimeType,group,step);

@override
String toString() {
  return 'SessionState.joining(group: $group, step: $step)';
}


}

/// @nodoc
abstract mixin class $SessionJoiningCopyWith<$Res> implements $SessionStateCopyWith<$Res> {
  factory $SessionJoiningCopyWith(SessionJoining value, $Res Function(SessionJoining) _then) = _$SessionJoiningCopyWithImpl;
@useResult
$Res call({
 DiscoveredGroup group, JoinStep step
});


$DiscoveredGroupCopyWith<$Res> get group;

}
/// @nodoc
class _$SessionJoiningCopyWithImpl<$Res>
    implements $SessionJoiningCopyWith<$Res> {
  _$SessionJoiningCopyWithImpl(this._self, this._then);

  final SessionJoining _self;
  final $Res Function(SessionJoining) _then;

/// Create a copy of SessionState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? group = null,Object? step = null,}) {
  return _then(SessionJoining(
group: null == group ? _self.group : group // ignore: cast_nullable_to_non_nullable
as DiscoveredGroup,step: null == step ? _self.step : step // ignore: cast_nullable_to_non_nullable
as JoinStep,
  ));
}

/// Create a copy of SessionState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DiscoveredGroupCopyWith<$Res> get group {
  
  return $DiscoveredGroupCopyWith<$Res>(_self.group, (value) {
    return _then(_self.copyWith(group: value));
  });
}
}

/// @nodoc


class SessionConnected implements SessionState {
  const SessionConnected({required this.groupId, required this.groupName, required this.myMemberId, required this.isHost, required final  List<Member> roster}): _roster = roster;
  

 final  String groupId;
 final  String groupName;
 final  String myMemberId;
 final  bool isHost;
 final  List<Member> _roster;
 List<Member> get roster {
  if (_roster is EqualUnmodifiableListView) return _roster;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_roster);
}


/// Create a copy of SessionState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SessionConnectedCopyWith<SessionConnected> get copyWith => _$SessionConnectedCopyWithImpl<SessionConnected>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionConnected&&(identical(other.groupId, groupId) || other.groupId == groupId)&&(identical(other.groupName, groupName) || other.groupName == groupName)&&(identical(other.myMemberId, myMemberId) || other.myMemberId == myMemberId)&&(identical(other.isHost, isHost) || other.isHost == isHost)&&const DeepCollectionEquality().equals(other._roster, _roster));
}


@override
int get hashCode => Object.hash(runtimeType,groupId,groupName,myMemberId,isHost,const DeepCollectionEquality().hash(_roster));

@override
String toString() {
  return 'SessionState.connected(groupId: $groupId, groupName: $groupName, myMemberId: $myMemberId, isHost: $isHost, roster: $roster)';
}


}

/// @nodoc
abstract mixin class $SessionConnectedCopyWith<$Res> implements $SessionStateCopyWith<$Res> {
  factory $SessionConnectedCopyWith(SessionConnected value, $Res Function(SessionConnected) _then) = _$SessionConnectedCopyWithImpl;
@useResult
$Res call({
 String groupId, String groupName, String myMemberId, bool isHost, List<Member> roster
});




}
/// @nodoc
class _$SessionConnectedCopyWithImpl<$Res>
    implements $SessionConnectedCopyWith<$Res> {
  _$SessionConnectedCopyWithImpl(this._self, this._then);

  final SessionConnected _self;
  final $Res Function(SessionConnected) _then;

/// Create a copy of SessionState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? groupId = null,Object? groupName = null,Object? myMemberId = null,Object? isHost = null,Object? roster = null,}) {
  return _then(SessionConnected(
groupId: null == groupId ? _self.groupId : groupId // ignore: cast_nullable_to_non_nullable
as String,groupName: null == groupName ? _self.groupName : groupName // ignore: cast_nullable_to_non_nullable
as String,myMemberId: null == myMemberId ? _self.myMemberId : myMemberId // ignore: cast_nullable_to_non_nullable
as String,isHost: null == isHost ? _self.isHost : isHost // ignore: cast_nullable_to_non_nullable
as bool,roster: null == roster ? _self._roster : roster // ignore: cast_nullable_to_non_nullable
as List<Member>,
  ));
}


}

/// @nodoc


class SessionFailed implements SessionState {
  const SessionFailed({required this.error});
  

 final  SessionError error;

/// Create a copy of SessionState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SessionFailedCopyWith<SessionFailed> get copyWith => _$SessionFailedCopyWithImpl<SessionFailed>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionFailed&&(identical(other.error, error) || other.error == error));
}


@override
int get hashCode => Object.hash(runtimeType,error);

@override
String toString() {
  return 'SessionState.failed(error: $error)';
}


}

/// @nodoc
abstract mixin class $SessionFailedCopyWith<$Res> implements $SessionStateCopyWith<$Res> {
  factory $SessionFailedCopyWith(SessionFailed value, $Res Function(SessionFailed) _then) = _$SessionFailedCopyWithImpl;
@useResult
$Res call({
 SessionError error
});




}
/// @nodoc
class _$SessionFailedCopyWithImpl<$Res>
    implements $SessionFailedCopyWith<$Res> {
  _$SessionFailedCopyWithImpl(this._self, this._then);

  final SessionFailed _self;
  final $Res Function(SessionFailed) _then;

/// Create a copy of SessionState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? error = null,}) {
  return _then(SessionFailed(
error: null == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as SessionError,
  ));
}


}

// dart format on
