import 'dart:typed_data';

import 'package:bluetooth_low_energy/bluetooth_low_energy.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bconnect/domain/protocol/advert_payload.dart';
import 'package:bconnect/domain/protocol/protocol_limits.dart';
import 'package:bconnect/transport/ble/ble_uuids.dart';

void main() {
  final seenAt = DateTime(2026, 8, 27, 12);

  group('BleAdvert.encode', () {
    test('puts the group name in the advertisement name', () {
      final a = BleAdvert.encode(
        groupName: 'Team Alpha',
        groupId: 0x1A2B,
        memberCount: 3,
        isLocked: true,
        isFull: false,
      );

      expect(a.name, 'Team Alpha');
    });

    test('advertises the service UUID so scanners can filter on it', () {
      final a = BleAdvert.encode(
        groupName: 'Team Alpha',
        groupId: 0x1A2B,
        memberCount: 3,
        isLocked: true,
        isFull: false,
      );

      expect(a.serviceUUIDs, contains(BleUuids.service));
    });

    test('carries the 7-byte payload as service data', () {
      final a = BleAdvert.encode(
        groupName: 'Team Alpha',
        groupId: 0x1A2B,
        memberCount: 3,
        isLocked: true,
        isFull: false,
      );

      final data = a.serviceData[BleUuids.service];

      expect(data, isNotNull);
      expect(data!.length, 7);
    });

    test('rejects a name that overflows the scan-response budget', () {
      // 30 ASCII bytes against a 29-byte limit. Better to fail here than to
      // let the radio silently truncate the name it broadcasts.
      expect(
        () => BleAdvert.encode(
          groupName: 'x' * (ProtocolLimits.maxGroupNameBytes + 1),
          groupId: 0x1A2B,
          memberCount: 1,
          isLocked: false,
          isFull: false,
        ),
        throwsA(isA<GroupNameTooLongException>()),
      );
    });
  });

  group('BleAdvert.decode', () {
    test('round-trips every field through a real Advertisement', () {
      final a = BleAdvert.encode(
        groupName: 'Team Alpha',
        groupId: 0x1A2B,
        memberCount: 3,
        isLocked: true,
        isFull: false,
      );

      final g = BleAdvert.decode(a, deviceId: 'dev-1', rssi: -55, seenAt: seenAt);

      expect(g, isNotNull);
      expect(g!.name, 'Team Alpha');
      expect(g.groupId, '1a2b');
      expect(g.memberCount, 3);
      expect(g.isLocked, isTrue);
      expect(g.isFull, isFalse);
      expect(g.deviceId, 'dev-1');
      expect(g.rssi, -55);
      expect(g.lastSeen, seenAt);
    });

    test('round-trips the full flag independently of locked', () {
      final a = BleAdvert.encode(
        groupName: 'Open',
        groupId: 0x0001,
        memberCount: 8,
        isLocked: false,
        isFull: true,
      );

      final g = BleAdvert.decode(a, deviceId: 'd', rssi: -40, seenAt: seenAt)!;

      expect(g.isLocked, isFalse);
      expect(g.isFull, isTrue);
    });

    test('returns null for an advert carrying no service data', () {
      final a = Advertisement(name: 'Something', serviceUUIDs: const []);

      expect(
        BleAdvert.decode(a, deviceId: 'd', rssi: -50, seenAt: seenAt),
        isNull,
      );
    });

    test('returns null for another app using the same service UUID', () {
      // Foreign service data of the wrong shape must not produce a group.
      final a = Advertisement(
        name: 'Impostor',
        serviceUUIDs: [BleUuids.service],
        serviceData: {
          BleUuids.service: Uint8List.fromList([1, 2, 3]),
        },
      );

      expect(
        BleAdvert.decode(a, deviceId: 'd', rssi: -50, seenAt: seenAt),
        isNull,
      );
    });

    test('falls back to a placeholder when the name is missing', () {
      // Android may omit the name if the advert is full; the group is still
      // joinable, so it must still appear in the list.
      final encoded = BleAdvert.encode(
        groupName: 'Team Alpha',
        groupId: 0x1A2B,
        memberCount: 1,
        isLocked: false,
        isFull: false,
      );
      final nameless = Advertisement(
        name: null,
        serviceUUIDs: encoded.serviceUUIDs,
        serviceData: encoded.serviceData,
      );

      final g = BleAdvert.decode(
        nameless,
        deviceId: 'd',
        rssi: -50,
        seenAt: seenAt,
      );

      expect(g, isNotNull);
      expect(g!.name, 'Unnamed group');
    });

    test('a UUID rebuilt from its string still keys the service data', () {
      // Scan results arrive with UUID instances the platform constructed, not
      // our static ones. If UUID equality or hashCode were identity-based the
      // map lookup would miss and every scan would silently find nothing.
      final a = BleAdvert.encode(
        groupName: 'Team Alpha',
        groupId: 0x1A2B,
        memberCount: 2,
        isLocked: false,
        isFull: false,
      );
      final rebuilt = Advertisement(
        name: a.name,
        serviceUUIDs: [UUID.fromString(BleUuids.service.toString())],
        serviceData: {
          UUID.fromString(BleUuids.service.toString()):
              a.serviceData[BleUuids.service]!,
        },
      );

      final g = BleAdvert.decode(
        rebuilt,
        deviceId: 'd',
        rssi: -50,
        seenAt: seenAt,
      );

      expect(g, isNotNull);
      expect(g!.groupId, '1a2b');
    });
  });
}
