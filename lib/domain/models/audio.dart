import 'package:freezed_annotation/freezed_annotation.dart';

part 'audio.freezed.dart';

enum AudioRoute { speaker, earpiece }

@freezed
abstract class MicState with _$MicState {
  const factory MicState({
    @Default(false) bool muted,
    @Default(false) bool transmitting,
  }) = _MicState;
}
