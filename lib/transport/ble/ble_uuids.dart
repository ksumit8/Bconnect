import 'dart:typed_data';

import 'package:bluetooth_low_energy/bluetooth_low_energy.dart';

import '../../domain/models/discovered_group.dart';
import '../../domain/protocol/advert_payload.dart';

/// Every wire-level identifier in one place.
///
/// `audioUp` and `audioDown` are declared now but unused until Plan B2, so
/// that no future change has to touch two files to add a characteristic.
abstract final class BleUuids {
  static final service = UUID.fromString('0000b1c7-0000-1000-8000-00805f9b34fb');
  static final control = UUID.fromString('0000b1c8-0000-1000-8000-00805f9b34fb');
  static final audioUp = UUID.fromString('0000b1c9-0000-1000-8000-00805f9b34fb');
  static final audioDown = UUID.fromString(
    '0000b1ca-0000-1000-8000-00805f9b34fb',
  );
}

/// Bridges [AdvertPayload] (pure protocol) to the radio's [Advertisement].
abstract final class BleAdvert {
  /// Shown when the radio dropped the name to fit the packet. The group is
  /// still joinable, so it must still be listed.
  static const placeholderName = 'Unnamed group';

  static Advertisement encode({
    required String groupName,
    required int groupId,
    required int memberCount,
    required bool isLocked,
    required bool isFull,
  }) {
    // Validates the 29-byte scan-response budget (spec section 5.1) and
    // throws GroupNameTooLongException if exceeded.
    AdvertPayload.encodeName(groupName);

    final payload = AdvertPayload(
      groupId: groupId,
      memberCount: memberCount,
      isLocked: isLocked,
      isFull: isFull,
    );

    return Advertisement(
      name: groupName,
      serviceUUIDs: [BleUuids.service],
      serviceData: {BleUuids.service: payload.encode()},
    );
  }

  /// Returns null for anything that is not a current-version Bconnect group —
  /// including another app that happens to use the same service UUID.
  static DiscoveredGroup? decode(
    Advertisement advertisement, {
    required String deviceId,
    required int rssi,
    required DateTime seenAt,
  }) {
    final Uint8List? data = advertisement.serviceData[BleUuids.service];
    if (data == null) return null;

    final payload = AdvertPayload.decode(data);
    if (payload == null) return null;

    final name = advertisement.name;

    return DiscoveredGroup(
      groupId: payload.groupIdHex,
      deviceId: deviceId,
      name: (name == null || name.isEmpty) ? placeholderName : name,
      memberCount: payload.memberCount,
      isLocked: payload.isLocked,
      isFull: payload.isFull,
      rssi: rssi,
      lastSeen: seenAt,
    );
  }
}
