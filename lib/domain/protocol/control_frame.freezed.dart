// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'control_frame.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ControlFrame {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ControlFrame);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'ControlFrame()';
}


}

/// @nodoc
class $ControlFrameCopyWith<$Res>  {
$ControlFrameCopyWith(ControlFrame _, $Res Function(ControlFrame) __);
}


/// Adds pattern-matching-related methods to [ControlFrame].
extension ControlFramePatterns on ControlFrame {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( ChallengeFrame value)?  challenge,TResult Function( JoinRequestFrame value)?  joinRequest,TResult Function( JoinAcceptedFrame value)?  joinAccepted,TResult Function( JoinRejectedFrame value)?  joinRejected,TResult Function( RosterUpdateFrame value)?  rosterUpdate,TResult Function( TalkStartFrame value)?  talkStart,TResult Function( TalkStopFrame value)?  talkStop,TResult Function( LeaveFrame value)?  leave,TResult Function( PingFrame value)?  ping,TResult Function( PongFrame value)?  pong,required TResult orElse(),}){
final _that = this;
switch (_that) {
case ChallengeFrame() when challenge != null:
return challenge(_that);case JoinRequestFrame() when joinRequest != null:
return joinRequest(_that);case JoinAcceptedFrame() when joinAccepted != null:
return joinAccepted(_that);case JoinRejectedFrame() when joinRejected != null:
return joinRejected(_that);case RosterUpdateFrame() when rosterUpdate != null:
return rosterUpdate(_that);case TalkStartFrame() when talkStart != null:
return talkStart(_that);case TalkStopFrame() when talkStop != null:
return talkStop(_that);case LeaveFrame() when leave != null:
return leave(_that);case PingFrame() when ping != null:
return ping(_that);case PongFrame() when pong != null:
return pong(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( ChallengeFrame value)  challenge,required TResult Function( JoinRequestFrame value)  joinRequest,required TResult Function( JoinAcceptedFrame value)  joinAccepted,required TResult Function( JoinRejectedFrame value)  joinRejected,required TResult Function( RosterUpdateFrame value)  rosterUpdate,required TResult Function( TalkStartFrame value)  talkStart,required TResult Function( TalkStopFrame value)  talkStop,required TResult Function( LeaveFrame value)  leave,required TResult Function( PingFrame value)  ping,required TResult Function( PongFrame value)  pong,}){
final _that = this;
switch (_that) {
case ChallengeFrame():
return challenge(_that);case JoinRequestFrame():
return joinRequest(_that);case JoinAcceptedFrame():
return joinAccepted(_that);case JoinRejectedFrame():
return joinRejected(_that);case RosterUpdateFrame():
return rosterUpdate(_that);case TalkStartFrame():
return talkStart(_that);case TalkStopFrame():
return talkStop(_that);case LeaveFrame():
return leave(_that);case PingFrame():
return ping(_that);case PongFrame():
return pong(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( ChallengeFrame value)?  challenge,TResult? Function( JoinRequestFrame value)?  joinRequest,TResult? Function( JoinAcceptedFrame value)?  joinAccepted,TResult? Function( JoinRejectedFrame value)?  joinRejected,TResult? Function( RosterUpdateFrame value)?  rosterUpdate,TResult? Function( TalkStartFrame value)?  talkStart,TResult? Function( TalkStopFrame value)?  talkStop,TResult? Function( LeaveFrame value)?  leave,TResult? Function( PingFrame value)?  ping,TResult? Function( PongFrame value)?  pong,}){
final _that = this;
switch (_that) {
case ChallengeFrame() when challenge != null:
return challenge(_that);case JoinRequestFrame() when joinRequest != null:
return joinRequest(_that);case JoinAcceptedFrame() when joinAccepted != null:
return joinAccepted(_that);case JoinRejectedFrame() when joinRejected != null:
return joinRejected(_that);case RosterUpdateFrame() when rosterUpdate != null:
return rosterUpdate(_that);case TalkStartFrame() when talkStart != null:
return talkStart(_that);case TalkStopFrame() when talkStop != null:
return talkStop(_that);case LeaveFrame() when leave != null:
return leave(_that);case PingFrame() when ping != null:
return ping(_that);case PongFrame() when pong != null:
return pong(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( Uint8List nonce)?  challenge,TResult Function( int version,  String displayName,  Uint8List passwordProof)?  joinRequest,TResult Function( String memberId,  List<Member> roster)?  joinAccepted,TResult Function( JoinRejectReason reason)?  joinRejected,TResult Function( List<Member> members)?  rosterUpdate,TResult Function( String memberId)?  talkStart,TResult Function( String memberId)?  talkStop,TResult Function()?  leave,TResult Function()?  ping,TResult Function()?  pong,required TResult orElse(),}) {final _that = this;
switch (_that) {
case ChallengeFrame() when challenge != null:
return challenge(_that.nonce);case JoinRequestFrame() when joinRequest != null:
return joinRequest(_that.version,_that.displayName,_that.passwordProof);case JoinAcceptedFrame() when joinAccepted != null:
return joinAccepted(_that.memberId,_that.roster);case JoinRejectedFrame() when joinRejected != null:
return joinRejected(_that.reason);case RosterUpdateFrame() when rosterUpdate != null:
return rosterUpdate(_that.members);case TalkStartFrame() when talkStart != null:
return talkStart(_that.memberId);case TalkStopFrame() when talkStop != null:
return talkStop(_that.memberId);case LeaveFrame() when leave != null:
return leave();case PingFrame() when ping != null:
return ping();case PongFrame() when pong != null:
return pong();case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( Uint8List nonce)  challenge,required TResult Function( int version,  String displayName,  Uint8List passwordProof)  joinRequest,required TResult Function( String memberId,  List<Member> roster)  joinAccepted,required TResult Function( JoinRejectReason reason)  joinRejected,required TResult Function( List<Member> members)  rosterUpdate,required TResult Function( String memberId)  talkStart,required TResult Function( String memberId)  talkStop,required TResult Function()  leave,required TResult Function()  ping,required TResult Function()  pong,}) {final _that = this;
switch (_that) {
case ChallengeFrame():
return challenge(_that.nonce);case JoinRequestFrame():
return joinRequest(_that.version,_that.displayName,_that.passwordProof);case JoinAcceptedFrame():
return joinAccepted(_that.memberId,_that.roster);case JoinRejectedFrame():
return joinRejected(_that.reason);case RosterUpdateFrame():
return rosterUpdate(_that.members);case TalkStartFrame():
return talkStart(_that.memberId);case TalkStopFrame():
return talkStop(_that.memberId);case LeaveFrame():
return leave();case PingFrame():
return ping();case PongFrame():
return pong();}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( Uint8List nonce)?  challenge,TResult? Function( int version,  String displayName,  Uint8List passwordProof)?  joinRequest,TResult? Function( String memberId,  List<Member> roster)?  joinAccepted,TResult? Function( JoinRejectReason reason)?  joinRejected,TResult? Function( List<Member> members)?  rosterUpdate,TResult? Function( String memberId)?  talkStart,TResult? Function( String memberId)?  talkStop,TResult? Function()?  leave,TResult? Function()?  ping,TResult? Function()?  pong,}) {final _that = this;
switch (_that) {
case ChallengeFrame() when challenge != null:
return challenge(_that.nonce);case JoinRequestFrame() when joinRequest != null:
return joinRequest(_that.version,_that.displayName,_that.passwordProof);case JoinAcceptedFrame() when joinAccepted != null:
return joinAccepted(_that.memberId,_that.roster);case JoinRejectedFrame() when joinRejected != null:
return joinRejected(_that.reason);case RosterUpdateFrame() when rosterUpdate != null:
return rosterUpdate(_that.members);case TalkStartFrame() when talkStart != null:
return talkStart(_that.memberId);case TalkStopFrame() when talkStop != null:
return talkStop(_that.memberId);case LeaveFrame() when leave != null:
return leave();case PingFrame() when ping != null:
return ping();case PongFrame() when pong != null:
return pong();case _:
  return null;

}
}

}

/// @nodoc


class ChallengeFrame implements ControlFrame {
  const ChallengeFrame({required this.nonce});
  

 final  Uint8List nonce;

/// Create a copy of ControlFrame
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ChallengeFrameCopyWith<ChallengeFrame> get copyWith => _$ChallengeFrameCopyWithImpl<ChallengeFrame>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ChallengeFrame&&const DeepCollectionEquality().equals(other.nonce, nonce));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(nonce));

@override
String toString() {
  return 'ControlFrame.challenge(nonce: $nonce)';
}


}

/// @nodoc
abstract mixin class $ChallengeFrameCopyWith<$Res> implements $ControlFrameCopyWith<$Res> {
  factory $ChallengeFrameCopyWith(ChallengeFrame value, $Res Function(ChallengeFrame) _then) = _$ChallengeFrameCopyWithImpl;
@useResult
$Res call({
 Uint8List nonce
});




}
/// @nodoc
class _$ChallengeFrameCopyWithImpl<$Res>
    implements $ChallengeFrameCopyWith<$Res> {
  _$ChallengeFrameCopyWithImpl(this._self, this._then);

  final ChallengeFrame _self;
  final $Res Function(ChallengeFrame) _then;

/// Create a copy of ControlFrame
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? nonce = null,}) {
  return _then(ChallengeFrame(
nonce: null == nonce ? _self.nonce : nonce // ignore: cast_nullable_to_non_nullable
as Uint8List,
  ));
}


}

/// @nodoc


class JoinRequestFrame implements ControlFrame {
  const JoinRequestFrame({required this.version, required this.displayName, required this.passwordProof});
  

 final  int version;
 final  String displayName;
 final  Uint8List passwordProof;

/// Create a copy of ControlFrame
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$JoinRequestFrameCopyWith<JoinRequestFrame> get copyWith => _$JoinRequestFrameCopyWithImpl<JoinRequestFrame>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is JoinRequestFrame&&(identical(other.version, version) || other.version == version)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&const DeepCollectionEquality().equals(other.passwordProof, passwordProof));
}


@override
int get hashCode => Object.hash(runtimeType,version,displayName,const DeepCollectionEquality().hash(passwordProof));

@override
String toString() {
  return 'ControlFrame.joinRequest(version: $version, displayName: $displayName, passwordProof: $passwordProof)';
}


}

/// @nodoc
abstract mixin class $JoinRequestFrameCopyWith<$Res> implements $ControlFrameCopyWith<$Res> {
  factory $JoinRequestFrameCopyWith(JoinRequestFrame value, $Res Function(JoinRequestFrame) _then) = _$JoinRequestFrameCopyWithImpl;
@useResult
$Res call({
 int version, String displayName, Uint8List passwordProof
});




}
/// @nodoc
class _$JoinRequestFrameCopyWithImpl<$Res>
    implements $JoinRequestFrameCopyWith<$Res> {
  _$JoinRequestFrameCopyWithImpl(this._self, this._then);

  final JoinRequestFrame _self;
  final $Res Function(JoinRequestFrame) _then;

/// Create a copy of ControlFrame
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? version = null,Object? displayName = null,Object? passwordProof = null,}) {
  return _then(JoinRequestFrame(
version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as int,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,passwordProof: null == passwordProof ? _self.passwordProof : passwordProof // ignore: cast_nullable_to_non_nullable
as Uint8List,
  ));
}


}

/// @nodoc


class JoinAcceptedFrame implements ControlFrame {
  const JoinAcceptedFrame({required this.memberId, required final  List<Member> roster}): _roster = roster;
  

 final  String memberId;
 final  List<Member> _roster;
 List<Member> get roster {
  if (_roster is EqualUnmodifiableListView) return _roster;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_roster);
}


/// Create a copy of ControlFrame
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$JoinAcceptedFrameCopyWith<JoinAcceptedFrame> get copyWith => _$JoinAcceptedFrameCopyWithImpl<JoinAcceptedFrame>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is JoinAcceptedFrame&&(identical(other.memberId, memberId) || other.memberId == memberId)&&const DeepCollectionEquality().equals(other._roster, _roster));
}


@override
int get hashCode => Object.hash(runtimeType,memberId,const DeepCollectionEquality().hash(_roster));

@override
String toString() {
  return 'ControlFrame.joinAccepted(memberId: $memberId, roster: $roster)';
}


}

/// @nodoc
abstract mixin class $JoinAcceptedFrameCopyWith<$Res> implements $ControlFrameCopyWith<$Res> {
  factory $JoinAcceptedFrameCopyWith(JoinAcceptedFrame value, $Res Function(JoinAcceptedFrame) _then) = _$JoinAcceptedFrameCopyWithImpl;
@useResult
$Res call({
 String memberId, List<Member> roster
});




}
/// @nodoc
class _$JoinAcceptedFrameCopyWithImpl<$Res>
    implements $JoinAcceptedFrameCopyWith<$Res> {
  _$JoinAcceptedFrameCopyWithImpl(this._self, this._then);

  final JoinAcceptedFrame _self;
  final $Res Function(JoinAcceptedFrame) _then;

/// Create a copy of ControlFrame
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? memberId = null,Object? roster = null,}) {
  return _then(JoinAcceptedFrame(
memberId: null == memberId ? _self.memberId : memberId // ignore: cast_nullable_to_non_nullable
as String,roster: null == roster ? _self._roster : roster // ignore: cast_nullable_to_non_nullable
as List<Member>,
  ));
}


}

/// @nodoc


class JoinRejectedFrame implements ControlFrame {
  const JoinRejectedFrame({required this.reason});
  

 final  JoinRejectReason reason;

/// Create a copy of ControlFrame
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$JoinRejectedFrameCopyWith<JoinRejectedFrame> get copyWith => _$JoinRejectedFrameCopyWithImpl<JoinRejectedFrame>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is JoinRejectedFrame&&(identical(other.reason, reason) || other.reason == reason));
}


@override
int get hashCode => Object.hash(runtimeType,reason);

@override
String toString() {
  return 'ControlFrame.joinRejected(reason: $reason)';
}


}

/// @nodoc
abstract mixin class $JoinRejectedFrameCopyWith<$Res> implements $ControlFrameCopyWith<$Res> {
  factory $JoinRejectedFrameCopyWith(JoinRejectedFrame value, $Res Function(JoinRejectedFrame) _then) = _$JoinRejectedFrameCopyWithImpl;
@useResult
$Res call({
 JoinRejectReason reason
});




}
/// @nodoc
class _$JoinRejectedFrameCopyWithImpl<$Res>
    implements $JoinRejectedFrameCopyWith<$Res> {
  _$JoinRejectedFrameCopyWithImpl(this._self, this._then);

  final JoinRejectedFrame _self;
  final $Res Function(JoinRejectedFrame) _then;

/// Create a copy of ControlFrame
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? reason = null,}) {
  return _then(JoinRejectedFrame(
reason: null == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as JoinRejectReason,
  ));
}


}

/// @nodoc


class RosterUpdateFrame implements ControlFrame {
  const RosterUpdateFrame({required final  List<Member> members}): _members = members;
  

 final  List<Member> _members;
 List<Member> get members {
  if (_members is EqualUnmodifiableListView) return _members;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_members);
}


/// Create a copy of ControlFrame
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RosterUpdateFrameCopyWith<RosterUpdateFrame> get copyWith => _$RosterUpdateFrameCopyWithImpl<RosterUpdateFrame>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RosterUpdateFrame&&const DeepCollectionEquality().equals(other._members, _members));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_members));

@override
String toString() {
  return 'ControlFrame.rosterUpdate(members: $members)';
}


}

/// @nodoc
abstract mixin class $RosterUpdateFrameCopyWith<$Res> implements $ControlFrameCopyWith<$Res> {
  factory $RosterUpdateFrameCopyWith(RosterUpdateFrame value, $Res Function(RosterUpdateFrame) _then) = _$RosterUpdateFrameCopyWithImpl;
@useResult
$Res call({
 List<Member> members
});




}
/// @nodoc
class _$RosterUpdateFrameCopyWithImpl<$Res>
    implements $RosterUpdateFrameCopyWith<$Res> {
  _$RosterUpdateFrameCopyWithImpl(this._self, this._then);

  final RosterUpdateFrame _self;
  final $Res Function(RosterUpdateFrame) _then;

/// Create a copy of ControlFrame
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? members = null,}) {
  return _then(RosterUpdateFrame(
members: null == members ? _self._members : members // ignore: cast_nullable_to_non_nullable
as List<Member>,
  ));
}


}

/// @nodoc


class TalkStartFrame implements ControlFrame {
  const TalkStartFrame({required this.memberId});
  

 final  String memberId;

/// Create a copy of ControlFrame
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TalkStartFrameCopyWith<TalkStartFrame> get copyWith => _$TalkStartFrameCopyWithImpl<TalkStartFrame>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TalkStartFrame&&(identical(other.memberId, memberId) || other.memberId == memberId));
}


@override
int get hashCode => Object.hash(runtimeType,memberId);

@override
String toString() {
  return 'ControlFrame.talkStart(memberId: $memberId)';
}


}

/// @nodoc
abstract mixin class $TalkStartFrameCopyWith<$Res> implements $ControlFrameCopyWith<$Res> {
  factory $TalkStartFrameCopyWith(TalkStartFrame value, $Res Function(TalkStartFrame) _then) = _$TalkStartFrameCopyWithImpl;
@useResult
$Res call({
 String memberId
});




}
/// @nodoc
class _$TalkStartFrameCopyWithImpl<$Res>
    implements $TalkStartFrameCopyWith<$Res> {
  _$TalkStartFrameCopyWithImpl(this._self, this._then);

  final TalkStartFrame _self;
  final $Res Function(TalkStartFrame) _then;

/// Create a copy of ControlFrame
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? memberId = null,}) {
  return _then(TalkStartFrame(
memberId: null == memberId ? _self.memberId : memberId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class TalkStopFrame implements ControlFrame {
  const TalkStopFrame({required this.memberId});
  

 final  String memberId;

/// Create a copy of ControlFrame
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TalkStopFrameCopyWith<TalkStopFrame> get copyWith => _$TalkStopFrameCopyWithImpl<TalkStopFrame>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TalkStopFrame&&(identical(other.memberId, memberId) || other.memberId == memberId));
}


@override
int get hashCode => Object.hash(runtimeType,memberId);

@override
String toString() {
  return 'ControlFrame.talkStop(memberId: $memberId)';
}


}

/// @nodoc
abstract mixin class $TalkStopFrameCopyWith<$Res> implements $ControlFrameCopyWith<$Res> {
  factory $TalkStopFrameCopyWith(TalkStopFrame value, $Res Function(TalkStopFrame) _then) = _$TalkStopFrameCopyWithImpl;
@useResult
$Res call({
 String memberId
});




}
/// @nodoc
class _$TalkStopFrameCopyWithImpl<$Res>
    implements $TalkStopFrameCopyWith<$Res> {
  _$TalkStopFrameCopyWithImpl(this._self, this._then);

  final TalkStopFrame _self;
  final $Res Function(TalkStopFrame) _then;

/// Create a copy of ControlFrame
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? memberId = null,}) {
  return _then(TalkStopFrame(
memberId: null == memberId ? _self.memberId : memberId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class LeaveFrame implements ControlFrame {
  const LeaveFrame();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LeaveFrame);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'ControlFrame.leave()';
}


}




/// @nodoc


class PingFrame implements ControlFrame {
  const PingFrame();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PingFrame);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'ControlFrame.ping()';
}


}




/// @nodoc


class PongFrame implements ControlFrame {
  const PongFrame();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PongFrame);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'ControlFrame.pong()';
}


}




// dart format on
