import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models/audio.dart';
import 'transport_provider.dart';

class MicController extends Notifier<MicState> {
  @override
  MicState build() => const MicState();

  Future<void> setMuted(bool muted) async {
    // Muting always ends any transmission in progress, so the UI cannot show
    // a muted mic that is still sending.
    state = state.copyWith(
      muted: muted,
      transmitting: muted ? false : state.transmitting,
    );

    await ref.read(transportProvider).setMicEnabled(!muted);
  }

  Future<void> toggleMute() => setMuted(!state.muted);

  void setTransmitting(bool transmitting) =>
      state = state.copyWith(transmitting: transmitting);
}

final micProvider =
    NotifierProvider<MicController, MicState>(MicController.new);
