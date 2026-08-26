import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:bconnect/transport/fake/fake_hub.dart';
import 'package:bconnect/transport/fake/fake_transport.dart';
import 'package:bconnect/transport/group_transport.dart';

void main() {
  late FakeHub hub;
  late FakeTransport host;
  late FakeTransport client;

  setUp(() {
    hub = FakeHub();
    host = FakeTransport(hub, deviceId: 'host');
    client = FakeTransport(hub, deviceId: 'client');
  });

  tearDown(() async {
    await host.dispose();
    await client.dispose();
  });

  Future<void> advertise() => host.startAdvertising(
    groupName: 'Team Alpha',
    groupId: 0x1A2B,
    memberCount: 1,
    isLocked: true,
    isFull: false,
  );

  test('reports peripheral support', () async {
    expect(await host.isPeripheralSupported(), isTrue);
  });

  test('a scan surfaces an advertising group', () async {
    await advertise();

    final results = client.events.whereType<ScanResultEvent>();
    await client.startScan();

    final event = await results.first;

    expect(event.group.name, 'Team Alpha');
    expect(event.group.groupId, '1a2b');
    expect(event.group.memberCount, 1);
    expect(event.group.isLocked, isTrue);
    expect(event.group.isFull, isFalse);
    expect(event.group.deviceId, 'host');
  });

  test('a scan surfaces nothing when no one is advertising', () async {
    final seen = <ScanResultEvent>[];
    client.events.whereType<ScanResultEvent>().listen(seen.add);

    await client.startScan();
    await Future<void>.delayed(Duration.zero);

    expect(seen, isEmpty);
  });

  test('a group that stops advertising is no longer discoverable', () async {
    await advertise();
    await host.stopAdvertising();

    final seen = <ScanResultEvent>[];
    client.events.whereType<ScanResultEvent>().listen(seen.add);

    await client.startScan();
    await Future<void>.delayed(Duration.zero);

    expect(seen, isEmpty);
  });

  test('updateAdvertisement re-emits with the new member count', () async {
    await advertise();
    await client.startScan();

    final next = client.events.whereType<ScanResultEvent>().skip(1).first;
    await host.updateAdvertisement(memberCount: 3, isFull: false);

    expect((await next).group.memberCount, 3);
  });

  test('connecting notifies both ends with the same peer id', () async {
    await advertise();

    final hostSide = host.events.whereType<PeerConnectedEvent>().first;
    final clientSide = client.events.whereType<PeerConnectedEvent>().first;

    final peerId = await client.connect('host');

    expect((await hostSide).peerId, peerId);
    expect((await clientSide).peerId, peerId);
  });

  test('control messages travel from client to host', () async {
    await advertise();
    final received = host.events.whereType<ControlMessageEvent>().first;

    final peerId = await client.connect('host');
    await client.sendControl(peerId, Uint8List.fromList([1, 2, 3]));

    final event = await received;

    expect(event.peerId, peerId);
    expect(event.bytes, Uint8List.fromList([1, 2, 3]));
  });

  test('control messages travel from host to client', () async {
    await advertise();
    final received = client.events.whereType<ControlMessageEvent>().first;

    final peerId = await client.connect('host');
    await host.sendControl(peerId, Uint8List.fromList([9]));

    expect((await received).bytes, Uint8List.fromList([9]));
  });

  test('a sender never receives its own control message', () async {
    await advertise();
    final peerId = await client.connect('host');

    final echoed = <ControlMessageEvent>[];
    client.events.whereType<ControlMessageEvent>().listen(echoed.add);

    await client.sendControl(peerId, Uint8List.fromList([1]));
    await Future<void>.delayed(Duration.zero);

    expect(echoed, isEmpty);
  });

  test('disconnecting notifies both ends', () async {
    await advertise();
    final peerId = await client.connect('host');

    final hostSide = host.events.whereType<PeerDisconnectedEvent>().first;
    final clientSide = client.events.whereType<PeerDisconnectedEvent>().first;

    await client.disconnect(peerId);

    expect((await hostSide).peerId, peerId);
    expect((await clientSide).peerId, peerId);
  });

  test('disposing a peer disconnects everyone attached to it', () async {
    await advertise();
    await client.connect('host');

    final clientSide = client.events.whereType<PeerDisconnectedEvent>().first;
    await host.dispose();

    expect(await clientSide, isA<PeerDisconnectedEvent>());
  });

  test('connecting to an unknown device raises a transport error', () async {
    expect(() => client.connect('nobody'), throwsA(isA<TransportException>()));
  });

  test('sending to an unknown peer raises a transport error', () async {
    expect(
      () => client.sendControl('nope', Uint8List(1)),
      throwsA(isA<TransportException>()),
    );
  });

  test('a host supports several simultaneous clients', () async {
    await advertise();
    final second = FakeTransport(hub, deviceId: 'client2');
    addTearDown(second.dispose);

    final a = await client.connect('host');
    final b = await second.connect('host');

    expect(a, isNot(b));

    final toA = client.events.whereType<ControlMessageEvent>().first;
    final toB = second.events.whereType<ControlMessageEvent>().first;

    await host.sendControl(a, Uint8List.fromList([10]));
    await host.sendControl(b, Uint8List.fromList([20]));

    expect((await toA).bytes, Uint8List.fromList([10]));
    expect((await toB).bytes, Uint8List.fromList([20]));
  });
}
