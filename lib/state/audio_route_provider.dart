import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models/audio.dart';
import 'transport_provider.dart';

class AudioRouteController extends Notifier<AudioRoute> {
  @override
  AudioRoute build() => AudioRoute.speaker;

  Future<void> setRoute(AudioRoute route) async {
    state = route;
    await ref.read(transportProvider).setAudioRoute(route);
  }
}

final audioRouteProvider =
    NotifierProvider<AudioRouteController, AudioRoute>(
  AudioRouteController.new,
);
