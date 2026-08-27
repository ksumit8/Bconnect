import 'package:flutter_test/flutter_test.dart';

import 'package:bconnect/domain/models/audio.dart';
import 'package:bconnect/transport/ble/ble_transport.dart';
import 'package:bconnect/transport/group_transport.dart';

void main() {
  // Constructing PeripheralManager/CentralManager touches platform channels.
  TestWidgetsFlutterBinding.ensureInitialized();

  test('BleTransport satisfies the GroupTransport interface', () {
    // Compile-time proof the seam is honoured. If a method is missing or has
    // the wrong signature, this file will not compile.
    final GroupTransport t = BleTransport();

    expect(t, isA<GroupTransport>());
  });

  test('the audio methods are inert in Plan B1', () async {
    // Plan B2 implements these. Until then they must be safe no-ops rather
    // than throwing, because GroupScreen calls startTalking/stopTalking on
    // every press of the talk button.
    final t = BleTransport();

    await t.setMicEnabled(false);
    await t.setAudioRoute(AudioRoute.earpiece);
    await t.startTalking();
    await t.stopTalking();
  });

  test('events is a broadcast stream so several listeners can attach', () async {
    // SessionController and the discovery provider both listen.
    final t = BleTransport();

    t.events.listen((_) {});
    t.events.listen((_) {});
  });

  test('dispose closes the event stream', () async {
    // Providers dispose the transport when the session ends; a controller left
    // open leaks its listeners for the life of the process.
    final t = BleTransport();
    var closed = false;
    t.events.listen((_) {}, onDone: () => closed = true);

    await t.dispose();
    await pumpEventQueue();

    expect(closed, isTrue);
  });

  test('dispose is safe to call twice', () async {
    // Riverpod can dispose a provider that already tore itself down.
    final t = BleTransport();

    await t.dispose();
    await expectLater(t.dispose(), completes);
  });
}
