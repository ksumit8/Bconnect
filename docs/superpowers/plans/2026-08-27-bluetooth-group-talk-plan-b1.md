# Bconnect Plan B1 — Real BLE Transport

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace `FakeTransport` with a real Bluetooth LE implementation, so two physical phones discover and join each other's groups.

**Architecture:** A single `BleTransport implements GroupTransport` backed by `bluetooth_low_energy` (MIT), which provides both the peripheral and central roles. Hosting uses `PeripheralManager` — advertise the group and run a GATT server. Joining uses `CentralManager` — scan, connect, subscribe. Everything above the `GroupTransport` seam is untouched: the sessions, providers and screens already work against this interface.

**Tech Stack:** Flutter 3.38.6 / Dart 3.10.7 · `bluetooth_low_energy` 6.2.1 (MIT) · `permission_handler` 11.4.0

**Spec:** `docs/superpowers/specs/2026-08-26-bluetooth-group-talk-design.md`

**Scope:** Control plane only. Voice is Plan B2 — the four audio methods on `GroupTransport` stay stubbed here, exactly as they are in `FakeTransport`.

---

## Global Constraints

Every task's requirements implicitly include this section.

- **Platform:** Android only. `minSdkVersion` 24.
- **Dart SDK is `^3.10.7`.** Use exactly these versions; newer ones do not resolve or do not build:
  - `bluetooth_low_energy: ^6.2.1`
  - `permission_handler: ^11.3.1` — **14.0.0 fails the Gradle build** (`srcDirs` deprecated in its Kotlin DSL)
- **`flutter_blue_plus` is forbidden** (spec §3.9) — it requires a paid commercial licence for for-profit use.
- **`BLUETOOTH_SCAN` MUST declare `android:usesPermissionFlags="neverForLocation"`** (spec §9.1). Without it Android returns **zero scan results while reporting success**. This is silent and looks exactly like broken hardware.
- **`bluetooth_low_energy`'s `authorize()` never completes** when permissions are already granted and the adapter is on. Always guard it with a timeout.
- **Protocol version `1`**, max **8** members, max **3** concurrent talkers, group names **29 UTF-8 bytes**, password proof **16 bytes** — all already in `ProtocolLimits`. Never hardcode.
- **Audio frames must never cross the Dart boundary** (spec §3.5). No audio method in this plan does real work.
- **The existing 219 tests must keep passing.** `FakeTransport` is not deleted — it remains the test double for every widget and session test.
- **Expected test counts are indicative, not contractual.** The gate is that every specified test passes and none are skipped.

## What "done" looks like

Two phones, both running the app:

1. Phone A creates "Team Alpha" with a password.
2. Phone B opens Join Group and **sees Team Alpha in the list**, with the lock icon and signal bars.
3. Phone B taps it, enters the password, and joins.
4. Phone A's roster **grows to 2 members, live**.
5. Either device ends the call and the other reacts correctly.

No audio. That is Plan B2.

## Testing strategy — read this before Task 1

BLE cannot be emulated, unit-tested, or driven from `flutter test`. This plan therefore has two kinds of verification, and **every task states which applies**:

- **Unit-testable** — pure logic with no radio: advertisement payload bridging, UUID mapping, permission-result mapping. These get real tests in `test/`.
- **Device-verified** — anything touching the radio. These get a written manual checklist with **exact expected output**, run on two phones. The implementer must paste the actual observed output into its report.

A task that claims device verification without pasting observed output has not been verified.

## Peer identity — the one design subtlety

`FakeTransport` gave both ends of a connection the *same* `peerId`. **BLE cannot do this**: the host sees a `Central` and the client sees a `Peripheral`, each with its own UUID.

This is fine, and no synthesis is needed. Check the consumers:

- `HostSession` receives `peerId` from its own `PeerConnectedEvent` and only ever passes it back to `sendControl`.
- `ClientSession` stores the `peerId` from its own `connect()` and filters its own events by it.

**Neither side ever compares its `peerId` to the other side's.** So a locally-stable identifier per side is sufficient. Use the `bluetooth_low_energy` peer UUID string on each side. Do not attempt to negotiate a shared id.

---

## File Structure

```
lib/transport/ble/
  ble_uuids.dart          service + characteristic UUIDs, one place
  ble_permissions.dart    runtime permission requests, Android-version aware
  ble_transport.dart      BleTransport implements GroupTransport
android/app/src/main/AndroidManifest.xml   permissions (neverForLocation!)
lib/main.dart                              wire BleTransport in production
test/transport/ble/
  ble_uuids_test.dart
  ble_advert_bridge_test.dart
docs/DEVICE_TESTING.md                     the two-phone checklist
```

`lib/transport/fake/` is untouched — it stays as the test double.

---

### Task 1: Dependencies, manifest, and permissions

**Files:**
- Modify: `pubspec.yaml`
- Modify: `android/app/src/main/AndroidManifest.xml`
- Modify: `android/app/build.gradle.kts` (minSdk)
- Create: `lib/transport/ble/ble_permissions.dart`
- Test: `test/transport/ble/ble_permissions_test.dart`

**Interfaces:**
- Consumes: nothing
- Produces: `BlePermissions.request()` → `Future<BlePermissionResult>`; `enum BlePermissionResult { granted, denied, permanentlyDenied }`

**Verification: unit-testable** (the mapping logic) **plus one device check** (the dialog appears).

- [ ] **Step 1: Add the dependencies**

In `pubspec.yaml`, under `dependencies:`, add:

```yaml
  bluetooth_low_energy: ^6.2.1
  permission_handler: ^11.3.1
```

Run: `flutter pub get`
Expected: `Got dependencies!`, resolving `permission_handler 11.4.0` and `permission_handler_android 12.1.0`.

**Do not** use `permission_handler` 12 or later — `permission_handler_android` 14.0.0 fails the Gradle build with `'srcDirs(vararg Any): Any' is deprecated`.

- [ ] **Step 2: Set minSdkVersion**

In `android/app/build.gradle.kts`, replace `minSdk = flutter.minSdkVersion` with:

```kotlin
        minSdk = 24
```

- [ ] **Step 3: Declare the permissions**

Replace the `<manifest>` opening and permission block in `android/app/src/main/AndroidManifest.xml` so it reads:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <!-- Android 12+. `neverForLocation` is REQUIRED: without it Android
         demands ACCESS_FINE_LOCATION before it will deliver ANY scan result,
         and returns zero results while reporting success. -->
    <uses-permission android:name="android.permission.BLUETOOTH_SCAN"
        android:usesPermissionFlags="neverForLocation" />
    <uses-permission android:name="android.permission.BLUETOOTH_ADVERTISE" />
    <uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />

    <!-- Android 11 and below -->
    <uses-permission android:name="android.permission.BLUETOOTH" android:maxSdkVersion="30" />
    <uses-permission android:name="android.permission.BLUETOOTH_ADMIN" android:maxSdkVersion="30" />
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" android:maxSdkVersion="30" />

    <uses-feature android:name="android.hardware.bluetooth_le" android:required="true" />
```

Leave the rest of the file (the `<application>` block) exactly as it is.

- [ ] **Step 4: Write the failing test**

Create `test/transport/ble/ble_permissions_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';

import 'package:bconnect/transport/ble/ble_permissions.dart';

void main() {
  group('BlePermissionResult mapping', () {
    test('all granted is granted', () {
      expect(
        BlePermissions.combine(const [
          BlePermissionResult.granted,
          BlePermissionResult.granted,
        ]),
        BlePermissionResult.granted,
      );
    });

    test('any denial makes the whole request denied', () {
      expect(
        BlePermissions.combine(const [
          BlePermissionResult.granted,
          BlePermissionResult.denied,
        ]),
        BlePermissionResult.denied,
      );
    });

    test('permanent denial outranks ordinary denial', () {
      // The UI must send the user to app settings, not re-prompt, so a
      // permanent denial anywhere has to win.
      expect(
        BlePermissions.combine(const [
          BlePermissionResult.denied,
          BlePermissionResult.permanentlyDenied,
        ]),
        BlePermissionResult.permanentlyDenied,
      );
    });

    test('an empty list is granted', () {
      expect(BlePermissions.combine(const []), BlePermissionResult.granted);
    });
  });
}
```

- [ ] **Step 5: Run test to verify it fails**

Run: `flutter test test/transport/ble/ble_permissions_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:bconnect/transport/ble/ble_permissions.dart'`

- [ ] **Step 6: Write the implementation**

Create `lib/transport/ble/ble_permissions.dart`:

```dart
import 'package:permission_handler/permission_handler.dart';

enum BlePermissionResult { granted, denied, permanentlyDenied }

/// Runtime permissions for BLE.
///
/// Android 12+ needs the three `BLUETOOTH_*` runtime permissions. Older
/// versions need location instead, which is why the request set differs by
/// version rather than asking for everything everywhere.
abstract final class BlePermissions {
  /// Worst-of: a permanent denial outranks an ordinary denial, because the UI
  /// must route the user to app settings rather than re-prompting.
  static BlePermissionResult combine(List<BlePermissionResult> results) {
    if (results.contains(BlePermissionResult.permanentlyDenied)) {
      return BlePermissionResult.permanentlyDenied;
    }
    if (results.contains(BlePermissionResult.denied)) {
      return BlePermissionResult.denied;
    }
    return BlePermissionResult.granted;
  }

  static BlePermissionResult _map(PermissionStatus s) {
    if (s.isGranted || s.isLimited) return BlePermissionResult.granted;
    if (s.isPermanentlyDenied) return BlePermissionResult.permanentlyDenied;
    return BlePermissionResult.denied;
  }

  static Future<BlePermissionResult> request() async {
    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.bluetoothAdvertise,
    ].request();

    return combine(statuses.values.map(_map).toList());
  }
}
```

- [ ] **Step 7: Run test to verify it passes**

Run: `flutter test test/transport/ble/ble_permissions_test.dart`
Expected: PASS (4 tests)

- [ ] **Step 8: Confirm nothing regressed**

Run: `flutter test && flutter analyze`
Expected: all tests PASS (223 total), `No issues found!`

- [ ] **Step 9: Device check — the build still installs**

Run: `flutter build apk --debug`
Expected: `✓ Built build/app/outputs/flutter-apk/app-debug.apk`

Then install and confirm it launches:

```bash
adb -s <device-id> install -r build/app/outputs/flutter-apk/app-debug.apk
adb -s <device-id> shell monkey -p com.example.bconnect -c android.intent.category.LAUNCHER 1
```

Expected: the home screen appears. **Paste the actual build and install output into your report.**

- [ ] **Step 10: Commit**

```bash
git add pubspec.yaml pubspec.lock android lib/transport/ble test/transport/ble
git commit -m "feat: add BLE dependencies, permissions and manifest

BLUETOOTH_SCAN declares neverForLocation: without it Android returns zero
scan results while reporting success (spec section 9.1)."
```

---

### Task 2: BLE UUIDs and advertisement bridging

**Files:**
- Create: `lib/transport/ble/ble_uuids.dart`
- Test: `test/transport/ble/ble_advert_bridge_test.dart`

**Interfaces:**
- Consumes: `AdvertPayload`, `ProtocolLimits` (`lib/domain/protocol/`), `DiscoveredGroup` (`lib/domain/models/`)
- Produces:
  - `BleUuids.service`, `BleUuids.control`, `BleUuids.audioUp`, `BleUuids.audioDown` — all `UUID`
  - `BleAdvert.encode({required String groupName, required int groupId, required int memberCount, required bool isLocked, required bool isFull})` → `Advertisement`
  - `BleAdvert.decode(Advertisement advertisement, {required String deviceId, required int rssi, required DateTime seenAt})` → `DiscoveredGroup?`

**Verification: unit-testable.** Both functions are pure.

`audioUp`/`audioDown` are declared here but unused until Plan B2. Declaring them now keeps every wire constant in one file.

- [ ] **Step 1: Write the failing test**

Create `test/transport/ble/ble_advert_bridge_test.dart`:

```dart
import 'package:bluetooth_low_energy/bluetooth_low_energy.dart';
import 'package:flutter_test/flutter_test.dart';

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

      final g = BleAdvert.decode(a,
          deviceId: 'dev-1', rssi: -55, seenAt: seenAt);

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

      final g = BleAdvert.decode(a,
          deviceId: 'd', rssi: -40, seenAt: seenAt)!;

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

      final g = BleAdvert.decode(nameless,
          deviceId: 'd', rssi: -50, seenAt: seenAt);

      expect(g, isNotNull);
      expect(g!.name, 'Unnamed group');
    });
  });
}
```

Add `import 'dart:typed_data';` at the top of the test file.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/transport/ble/ble_advert_bridge_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:bconnect/transport/ble/ble_uuids.dart'`

- [ ] **Step 3: Write the implementation**

Create `lib/transport/ble/ble_uuids.dart`:

```dart
import 'dart:typed_data';

import 'package:bluetooth_low_energy/bluetooth_low_energy.dart';

import '../../domain/models/discovered_group.dart';
import '../../domain/protocol/advert_payload.dart';

/// Every wire-level identifier in one place.
///
/// `audioUp` and `audioDown` are declared now but unused until Plan B2, so
/// that no future change has to touch two files to add a characteristic.
abstract final class BleUuids {
  static final service =
      UUID.fromString('0000b1c7-0000-1000-8000-00805f9b34fb');
  static final control =
      UUID.fromString('0000b1c8-0000-1000-8000-00805f9b34fb');
  static final audioUp =
      UUID.fromString('0000b1c9-0000-1000-8000-00805f9b34fb');
  static final audioDown =
      UUID.fromString('0000b1ca-0000-1000-8000-00805f9b34fb');
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/transport/ble/ble_advert_bridge_test.dart`
Expected: PASS (8 tests)

- [ ] **Step 5: Confirm nothing regressed**

Run: `flutter test && flutter analyze`
Expected: all PASS (231 total), `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add lib/transport/ble/ble_uuids.dart test/transport/ble/ble_advert_bridge_test.dart
git commit -m "feat: add BLE UUIDs and advertisement bridging"
```

---

### Task 3: BleTransport skeleton — lifecycle and events

**Files:**
- Create: `lib/transport/ble/ble_transport.dart`
- Test: `test/transport/ble/ble_transport_contract_test.dart`

**Interfaces:**
- Consumes: `GroupTransport`, `TransportEvent` and its subclasses, `TransportException` (`lib/transport/group_transport.dart`); `BleUuids`, `BleAdvert` (Task 2); `AudioRoute` (`lib/domain/models/audio.dart`)
- Produces: `class BleTransport implements GroupTransport` with `BleTransport()` and `Future<void> init()`

**Verification: unit-testable for the contract** (that it satisfies the interface and its audio stubs are inert) **— radio behaviour comes in Tasks 4-7.**

This task creates the class, its event plumbing, and the deliberately-inert audio methods. Advertising, scanning and connections are added by later tasks so each gets its own device check.

- [ ] **Step 1: Write the failing test**

Create `test/transport/ble/ble_transport_contract_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';

import 'package:bconnect/domain/models/audio.dart';
import 'package:bconnect/transport/ble/ble_transport.dart';
import 'package:bconnect/transport/group_transport.dart';

void main() {
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

  test('events is a broadcast stream so several listeners can attach',
      () async {
    // SessionController and the discovery provider both listen.
    final t = BleTransport();

    t.events.listen((_) {});
    t.events.listen((_) {});
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/transport/ble/ble_transport_contract_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:bconnect/transport/ble/ble_transport.dart'`

- [ ] **Step 3: Write the implementation**

Create `lib/transport/ble/ble_transport.dart`:

```dart
import 'dart:async';
import 'dart:typed_data';

import 'package:bluetooth_low_energy/bluetooth_low_energy.dart';

import '../../domain/models/audio.dart';
import '../group_transport.dart';
import 'ble_uuids.dart';

/// The real Bluetooth LE transport.
///
/// One device plays one role at a time: hosting uses [PeripheralManager]
/// (advertise + GATT server), joining uses [CentralManager] (scan + connect).
/// Both managers are created up front because the user can switch roles
/// without restarting the app.
///
/// Peer identity note: BLE gives each end its own view of a connection — the
/// host sees a Central, the client sees a Peripheral. That is fine. Neither
/// `HostSession` nor `ClientSession` ever compares its peerId to the other
/// side's; each only passes its own back to `sendControl`. Do not try to
/// negotiate a shared id.
class BleTransport implements GroupTransport {
  BleTransport({PeripheralManager? peripheral, CentralManager? central})
      : _peripheral = peripheral ?? PeripheralManager(),
        _central = central ?? CentralManager();

  final PeripheralManager _peripheral;
  final CentralManager _central;

  final StreamController<TransportEvent> _events =
      StreamController<TransportEvent>.broadcast();

  final List<StreamSubscription<dynamic>> _subs = [];

  bool _initialised = false;

  @override
  Stream<TransportEvent> get events => _events.stream;

  void _emit(TransportEvent e) {
    if (!_events.isClosed) _events.add(e);
  }

  /// Must be awaited once before any other method.
  ///
  /// `authorize()` is deliberately guarded: `bluetooth_low_energy`'s
  /// implementation never completes when permissions are already granted and
  /// the adapter is on, which hangs the app on a blank screen (spec 9.1).
  Future<void> init() async {
    if (_initialised) return;
    _initialised = true;

    if (_peripheral.state != BluetoothLowEnergyState.poweredOn) {
      try {
        await _peripheral.authorize().timeout(const Duration(seconds: 5));
      } on TimeoutException {
        // Permissions were already granted; carry on.
      }
    }
    if (_central.state != BluetoothLowEnergyState.poweredOn) {
      try {
        await _central.authorize().timeout(const Duration(seconds: 5));
      } on TimeoutException {
        // As above.
      }
    }
  }

  @override
  Future<bool> isPeripheralSupported() async {
    await init();
    return _peripheral.state == BluetoothLowEnergyState.poweredOn;
  }

  // --- Host role: Task 4 and 5 -------------------------------------------

  @override
  Future<void> startAdvertising({
    required String groupName,
    required int groupId,
    required int memberCount,
    required bool isLocked,
    required bool isFull,
    int rssi = -55,
  }) async {
    throw UnimplementedError('Task 4');
  }

  @override
  Future<void> updateAdvertisement({
    required int memberCount,
    required bool isFull,
  }) async {
    throw UnimplementedError('Task 4');
  }

  @override
  Future<void> stopAdvertising() async {
    throw UnimplementedError('Task 4');
  }

  // --- Client role: Task 6 and 7 -----------------------------------------

  @override
  Future<void> startScan() async => throw UnimplementedError('Task 6');

  @override
  Future<void> stopScan() async => throw UnimplementedError('Task 6');

  @override
  Future<String> connect(String deviceId) async =>
      throw UnimplementedError('Task 7');

  @override
  Future<void> disconnect(String peerId) async =>
      throw UnimplementedError('Task 7');

  @override
  Future<void> sendControl(String peerId, Uint8List bytes) async =>
      throw UnimplementedError('Task 5');

  // --- Audio: Plan B2 ----------------------------------------------------
  //
  // Inert on purpose. GroupScreen calls startTalking/stopTalking on every
  // press of the talk button, so these must not throw.

  @override
  Future<void> setMicEnabled(bool enabled) async {}

  @override
  Future<void> setAudioRoute(AudioRoute route) async {}

  @override
  Future<void> startTalking() async {}

  @override
  Future<void> stopTalking() async {}

  @override
  Future<void> dispose() async {
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
    await _events.close();
  }
}
```

- [ ] **Step 4: Reconcile the interface signature**

`FakeTransport.startAdvertising` takes an optional `rssi` (added so the discovery test could distinguish signal strengths). Check `lib/transport/group_transport.dart` and make `BleTransport.startAdvertising` match it **exactly** — same parameter names, same optionality, same default.

If the interface declares `rssi`, keep the parameter above and ignore its value: a real radio reports measured RSSI, it cannot advertise a chosen one. Add that as a comment.

Run: `flutter analyze`
Expected: `No issues found!` — if it reports a missing or mismatched override, fix the signature rather than the interface.

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/transport/ble/ble_transport_contract_test.dart`
Expected: PASS (3 tests)

- [ ] **Step 6: Confirm nothing regressed**

Run: `flutter test && flutter analyze`
Expected: all PASS (234 total), `No issues found!`

- [ ] **Step 7: Commit**

```bash
git add lib/transport/ble/ble_transport.dart test/transport/ble/ble_transport_contract_test.dart
git commit -m "feat: add BleTransport skeleton implementing GroupTransport"
```

---

### Task 4: Host role — advertising

**Files:**
- Modify: `lib/transport/ble/ble_transport.dart`
- Create: `docs/DEVICE_TESTING.md`

**Interfaces:**
- Consumes: `BleAdvert.encode` (Task 2), `BleTransport` (Task 3)
- Produces: working `startAdvertising`, `updateAdvertisement`, `stopAdvertising`

**Verification: device-verified.** There is no way to unit-test a radio advertising. The checklist below is the test, and its observed output must be pasted into the report.

- [ ] **Step 1: Implement advertising**

In `lib/transport/ble/ble_transport.dart`, add these fields next to the others:

```dart
  String? _advertisedName;
  int? _advertisedGroupId;
  bool _advertisedLocked = false;
```

Replace the three advertising stubs with:

```dart
  @override
  Future<void> startAdvertising({
    required String groupName,
    required int groupId,
    required int memberCount,
    required bool isLocked,
    required bool isFull,
    int rssi = -55,
  }) async {
    // `rssi` is ignored: a real radio reports measured signal strength, it
    // cannot advertise a chosen one. The parameter exists so FakeTransport
    // can vary it in tests.
    await init();

    _advertisedName = groupName;
    _advertisedGroupId = groupId;
    _advertisedLocked = isLocked;

    await _peripheral.stopAdvertising();
    await _peripheral.startAdvertising(
      BleAdvert.encode(
        groupName: groupName,
        groupId: groupId,
        memberCount: memberCount,
        isLocked: isLocked,
        isFull: isFull,
      ),
    );
  }

  @override
  Future<void> updateAdvertisement({
    required int memberCount,
    required bool isFull,
  }) async {
    final name = _advertisedName;
    final id = _advertisedGroupId;
    if (name == null || id == null) {
      throw const TransportException('not advertising');
    }

    // BLE has no "modify advert in place": stop and restart with new data.
    await _peripheral.stopAdvertising();
    await _peripheral.startAdvertising(
      BleAdvert.encode(
        groupName: name,
        groupId: id,
        memberCount: memberCount,
        isLocked: _advertisedLocked,
        isFull: isFull,
      ),
    );
  }

  @override
  Future<void> stopAdvertising() async {
    _advertisedName = null;
    _advertisedGroupId = null;
    await _peripheral.stopAdvertising();
  }
```

- [ ] **Step 2: Confirm the suite still passes**

Run: `flutter test && flutter analyze`
Expected: all PASS, `No issues found!` — nothing here touches `FakeTransport`.

- [ ] **Step 3: Write the device-test checklist**

Create `docs/DEVICE_TESTING.md`:

```markdown
# Device testing

BLE cannot be emulated. These checks run on two physical Android phones.

Find device ids with `adb devices -l`. Below, `$A` and `$B` are those ids.

## Build and install on both

    flutter build apk --debug
    adb -s $A install -r build/app/outputs/flutter-apk/app-debug.apk
    adb -s $B install -r build/app/outputs/flutter-apk/app-debug.apk

Bluetooth must be ON on both. Grant permissions when the app asks, or:

    adb -s $A shell pm grant com.example.bconnect android.permission.BLUETOOTH_SCAN
    adb -s $A shell pm grant com.example.bconnect android.permission.BLUETOOTH_CONNECT
    adb -s $A shell pm grant com.example.bconnect android.permission.BLUETOOTH_ADVERTISE

## Check 1 — the group is really on air (Task 4)

On phone A, create a password-protected group named "Team Alpha".

Verify with a third-party scanner rather than our own code, so the check is
independent: install nRF Connect on phone B, open it, tap SCAN with "No filter".

PASS when: an entry named `Team Alpha` appears, with a signal reading.

If nothing appears, check in this order — the first is by far the most common:
1. `BLUETOOTH_SCAN` is missing `neverForLocation` in the manifest. Android
   then returns zero results while reporting success.
2. Phone A's app lost foreground; advertising stops with it.
3. Bluetooth is off on either device.
```

- [ ] **Step 4: Run device Check 1**

Follow `docs/DEVICE_TESTING.md` Check 1 exactly.

Expected: nRF Connect on phone B lists `Team Alpha`.

**Paste the observed result into your report** — the device name, and the RSSI reading. If it does not appear, do not proceed: report BLOCKED with what you saw.

- [ ] **Step 5: Commit**

```bash
git add lib/transport/ble/ble_transport.dart docs/DEVICE_TESTING.md
git commit -m "feat: advertise real groups over BLE"
```

---

### Task 5: Host role — GATT server and control messages

**Files:**
- Modify: `lib/transport/ble/ble_transport.dart`
- Modify: `docs/DEVICE_TESTING.md`

**Interfaces:**
- Consumes: `BleUuids` (Task 2), advertising (Task 4)
- Produces: working `sendControl` on the host side; `PeerConnectedEvent`, `PeerDisconnectedEvent`, `ControlMessageEvent` emitted from the host

**Verification: device-verified.** A GATT server needs a real central to connect to it.

The host publishes one service with a `control` characteristic that is both **writable** (client → host) and **notifiable** (host → client). `audioUp`/`audioDown` are added in Plan B2.

- [ ] **Step 1: Add the GATT service and its listeners**

In `lib/transport/ble/ble_transport.dart`, add these fields:

```dart
  GATTCharacteristic? _controlCharacteristic;
  final Map<String, Central> _centrals = {};
  bool _serviceAdded = false;
```

Add this private method:

```dart
  /// Publishes the GATT service and wires the host-side listeners.
  ///
  /// Idempotent: `startAdvertising` may be called more than once (creating a
  /// group after ending a previous one), and re-adding a service throws.
  Future<void> _ensureHostService() async {
    if (_serviceAdded) return;
    _serviceAdded = true;

    final control = GATTCharacteristic.mutable(
      uuid: BleUuids.control,
      properties: [
        GATTCharacteristicProperty.read,
        GATTCharacteristicProperty.write,
        GATTCharacteristicProperty.writeWithoutResponse,
        GATTCharacteristicProperty.notify,
      ],
      permissions: [
        GATTCharacteristicPermission.read,
        GATTCharacteristicPermission.write,
      ],
      descriptors: [],
    );
    _controlCharacteristic = control;

    await _peripheral.removeAllServices();
    await _peripheral.addService(GATTService(
      uuid: BleUuids.service,
      isPrimary: true,
      includedServices: [],
      characteristics: [control],
    ));

    // Note: `bluetooth_low_energy` exports `ConnectionState`, and so does
    // `package:flutter/material.dart`. This file does not import material, so
    // the reference below is unambiguous. If you ever add a material import
    // here, alias one of them (`import '...' as ble show ConnectionState;`)
    // rather than renaming anything.
    _subs.add(_peripheral.connectionStateChanged.listen((e) {
      final id = e.central.uuid.toString();
      if (e.state == ConnectionState.connected) {
        _centrals[id] = e.central;
        _emit(PeerConnectedEvent(id));
      } else {
        _centrals.remove(id);
        _emit(PeerDisconnectedEvent(id));
      }
    }));

    // A client's control frame arrives as a write request. Respond first —
    // an unanswered request stalls that client's GATT queue — then surface it.
    _subs.add(_peripheral.characteristicWriteRequested.listen((e) async {
      final value = Uint8List.fromList(e.request.value);
      try {
        await _peripheral.respondWriteRequest(e.request);
      } catch (_) {
        // The central vanished mid-request; the disconnect event handles it.
      }
      _centrals[e.central.uuid.toString()] = e.central;
      _emit(ControlMessageEvent(e.central.uuid.toString(), value));
    }));
  }
```

Call it at the top of `startAdvertising`, immediately after `await init();`:

```dart
    await _ensureHostService();
```

- [ ] **Step 2: Implement host-side sendControl**

Replace the `sendControl` stub with:

```dart
  @override
  Future<void> sendControl(String peerId, Uint8List bytes) async {
    // Host path: notify the central on the control characteristic.
    final central = _centrals[peerId];
    final control = _controlCharacteristic;
    if (central != null && control != null) {
      try {
        await _peripheral.notifyCharacteristic(central, control, value: bytes);
      } catch (e) {
        throw TransportException('notify failed for $peerId: $e');
      }
      return;
    }

    // Client path is added in Task 7.
    throw TransportException('no connection $peerId');
  }
```

- [ ] **Step 3: Clear host state on stopAdvertising**

In `stopAdvertising`, before `await _peripheral.stopAdvertising();`, add:

```dart
    _centrals.clear();
```

Do **not** remove the GATT service here — `HostSession.stop()` calls `stopAdvertising` and a later `startAdvertising` must still work.

- [ ] **Step 4: Confirm the suite still passes**

Run: `flutter test && flutter analyze`
Expected: all PASS, `No issues found!`

- [ ] **Step 5: Add device Check 2 to the checklist**

Append to `docs/DEVICE_TESTING.md`:

```markdown
## Check 2 — a central can connect and exchange control frames (Task 5)

With phone A hosting "Team Alpha", on phone B open nRF Connect, find
`Team Alpha`, and tap CONNECT.

PASS when:
- nRF Connect shows CONNECTED
- a service `0000b1c7-...` is listed
- inside it, a characteristic `0000b1c8-...` shows properties
  READ, WRITE, WRITE NO RESPONSE, NOTIFY

Then, on phone A, watch logcat:

    adb -s $A logcat | grep -i flutter

PASS when a connection is registered (the roster does not change yet —
`HostSession` only adds a member after a valid JOIN_REQUEST, which nRF
Connect does not send).
```

- [ ] **Step 6: Run device Check 2**

Follow it exactly. **Paste the observed characteristic properties into your report.** If the characteristic is missing or lacks NOTIFY, report BLOCKED.

- [ ] **Step 7: Commit**

```bash
git add lib/transport/ble/ble_transport.dart docs/DEVICE_TESTING.md
git commit -m "feat: host GATT server and control-frame exchange"
```

---

### Task 6: Client role — scanning

**Files:**
- Modify: `lib/transport/ble/ble_transport.dart`
- Modify: `docs/DEVICE_TESTING.md`

**Interfaces:**
- Consumes: `BleAdvert.decode` (Task 2)
- Produces: working `startScan` / `stopScan`, emitting `ScanResultEvent`

**Verification: device-verified**, and this is the first check that uses **our own app on both phones** rather than nRF Connect.

- [ ] **Step 1: Implement scanning**

Add a field:

```dart
  final Map<String, Peripheral> _discovered = {};
```

Replace the scan stubs:

```dart
  @override
  Future<void> startScan() async {
    await init();

    // Attach the listener before starting, so no advert is missed.
    _subs.add(_central.discovered.listen((e) {
      final group = BleAdvert.decode(
        e.advertisement,
        deviceId: e.peripheral.uuid.toString(),
        rssi: e.rssi,
        seenAt: DateTime.now(),
      );
      // decode() returns null for anything that is not a current-version
      // Bconnect advert, including other apps on the same service UUID.
      if (group == null) return;

      _discovered[group.deviceId] = e.peripheral;
      _emit(ScanResultEvent(group));
    }));

    // Unfiltered: filtering by service UUID hides the difference between
    // "nothing on air" and "advertising without our UUID", which makes field
    // diagnosis much harder. decode() does the filtering instead.
    await _central.startDiscovery();
  }

  @override
  Future<void> stopScan() async {
    await _central.stopDiscovery();
  }
```

- [ ] **Step 2: Confirm the suite still passes**

Run: `flutter test && flutter analyze`
Expected: all PASS, `No issues found!`

- [ ] **Step 3: Wire BleTransport into main.dart so the app can be driven**

In `lib/main.dart`, replace the `FakeTransport(FakeHub())` override inside `buildProductionApp()` with a `BleTransport()`, importing it. Keep the function shape — `test/widget_test.dart` asserts on it.

Note: after this change `buildProductionApp`'s regression test still passes, because `peripheralSupportedProvider` calls `isPeripheralSupported()`, which returns a real answer instead of a hardcoded `true`. If that test now fails on a machine with no Bluetooth, report it rather than weakening the test — it is telling you the production wiring is real.

- [ ] **Step 4: Add device Check 3**

Append to `docs/DEVICE_TESTING.md`:

```markdown
## Check 3 — our own app discovers a real group (Task 6)

1. Phone A: create a password-protected group "Team Alpha".
2. Phone B: open the app, tap **Join Existing Group**.

PASS when phone B's list shows:
- the name `Team Alpha`
- a **closed padlock** (it is password-protected)
- `1 Member`
- signal bars

FAIL modes:
- List stays empty -> check `neverForLocation` in the manifest first.
- Name shows as `Unnamed group` -> the radio dropped the name to fit the
  packet; the group is still joinable, but shorten the group name.
- Padlock is open -> the `isLocked` flag is not surviving the advertisement;
  check `AdvertPayload` encode/decode.
```

- [ ] **Step 5: Run device Check 3**

**Paste exactly what phone B's list shows** — name, lock state, member count. If the list is empty, check the manifest before reporting.

- [ ] **Step 6: Commit**

```bash
git add lib/transport/ble/ble_transport.dart lib/main.dart docs/DEVICE_TESTING.md
git commit -m "feat: discover real nearby groups over BLE"
```

---

### Task 7: Client role — connect, subscribe, send

**Files:**
- Modify: `lib/transport/ble/ble_transport.dart`
- Modify: `docs/DEVICE_TESTING.md`

**Interfaces:**
- Consumes: scanning (Task 6)
- Produces: working `connect`, `disconnect`, and the client half of `sendControl`

**Verification: device-verified.** This task completes the join flow end to end.

- [ ] **Step 1: Implement connect and disconnect**

Add fields:

```dart
  final Map<String, Peripheral> _connected = {};
  final Map<String, GATTCharacteristic> _clientControl = {};
```

Replace the stubs:

```dart
  @override
  Future<String> connect(String deviceId) async {
    final peripheral = _discovered[deviceId];
    if (peripheral == null) {
      throw TransportException('no device with id $deviceId');
    }

    try {
      await _central.connect(peripheral);
    } catch (e) {
      throw TransportException('connect failed: $e');
    }

    final peerId = peripheral.uuid.toString();
    _connected[peerId] = peripheral;

    // A larger MTU is requested up front. It is not fatal if the peer
    // refuses; control frames are small. Plan B2's audio needs the headroom.
    try {
      await _central.requestMTU(peripheral, mtu: 517);
    } catch (_) {}

    final services = await _central.discoverGATT(peripheral);
    final service = services.firstWhere(
      (s) => s.uuid == BleUuids.service,
      orElse: () => throw const TransportException('peer is not a Bconnect host'),
    );
    final control = service.characteristics.firstWhere(
      (c) => c.uuid == BleUuids.control,
      orElse: () =>
          throw const TransportException('host has no control characteristic'),
    );
    _clientControl[peerId] = control;

    await _central.setCharacteristicNotifyState(peripheral, control,
        state: true);

    _emit(PeerConnectedEvent(peerId));
    return peerId;
  }

  @override
  Future<void> disconnect(String peerId) async {
    final peripheral = _connected.remove(peerId);
    _clientControl.remove(peerId);

    // Host path: the peer is a central we are serving.
    final central = _centrals.remove(peerId);
    if (central != null) {
      try {
        await _peripheral.disconnect(central);
      } catch (_) {}
      _emit(PeerDisconnectedEvent(peerId));
      return;
    }

    if (peripheral == null) {
      throw TransportException('no connection $peerId');
    }
    try {
      await _central.disconnect(peripheral);
    } catch (_) {}
    _emit(PeerDisconnectedEvent(peerId));
  }
```

- [ ] **Step 2: Wire the client's incoming notifications and disconnects**

Add to `init()`, after the authorize guards:

```dart
    // Notifications from a host arrive here.
    _subs.add(_central.characteristicNotified.listen((e) {
      if (e.characteristic.uuid != BleUuids.control) return;
      _emit(ControlMessageEvent(
        e.peripheral.uuid.toString(),
        Uint8List.fromList(e.value),
      ));
    }));

    // A host going away, or moving out of range.
    _subs.add(_central.connectionStateChanged.listen((e) {
      if (e.state == ConnectionState.disconnected) {
        final id = e.peripheral.uuid.toString();
        if (_connected.remove(id) != null) {
          _clientControl.remove(id);
          _emit(PeerDisconnectedEvent(id));
        }
      }
    }));
```

- [ ] **Step 3: Complete sendControl for the client path**

In `sendControl`, replace the final `throw` with:

```dart
    // Client path: write to the host's control characteristic.
    final peripheral = _connected[peerId];
    final clientControl = _clientControl[peerId];
    if (peripheral == null || clientControl == null) {
      throw TransportException('no connection $peerId');
    }
    try {
      await _central.writeCharacteristic(
        peripheral,
        clientControl,
        value: bytes,
        type: GATTCharacteristicWriteType.withResponse,
      );
    } catch (e) {
      throw TransportException('write failed for $peerId: $e');
    }
```

Use `withResponse`: control frames carry the join handshake, and a silently
dropped `JOIN_REQUEST` would strand the client on the password screen.

- [ ] **Step 4: Confirm the suite still passes**

Run: `flutter test && flutter analyze`
Expected: all PASS, `No issues found!`

- [ ] **Step 5: Add device Check 4 — the full journey**

Append to `docs/DEVICE_TESTING.md`:

```markdown
## Check 4 — two phones join a real group (Task 7)

1. Phone A: create a password-protected group "Team Alpha" with password
   `hunter2`.
2. Phone B: Join Existing Group -> tap `Team Alpha` -> enter `hunter2` ->
   tap Join Group.

PASS when ALL of these hold:
- Phone B lands on the group screen showing `Group is Active`
- Phone B's roster shows 2 members
- **Phone A's roster grows to 2 members without being touched**
- Phone A's member badge reads `2 Members`

3. Now test the wrong password: phone B leaves, rejoins, enters `wrong`.

PASS when phone B stays on the password screen showing `Incorrect password`,
and phone A's roster stays at 1.

4. Finally, phone A taps End Call.

PASS when phone B returns to its home screen showing `Group ended by host`.
```

- [ ] **Step 6: Run device Check 4**

This is the milestone the whole plan exists for. Run every sub-step.

**Paste the observed result of each of the four sub-steps into your report.** If any fails, report BLOCKED with which one and what you saw — do not proceed to Task 8.

- [ ] **Step 7: Commit**

```bash
git add lib/transport/ble/ble_transport.dart docs/DEVICE_TESTING.md
git commit -m "feat: join real groups over BLE

Completes the control plane: two phones now discover, connect, authenticate
and exchange roster updates over the radio."
```

---

### Task 8: Permission flow and Bluetooth-off handling

**Files:**
- Modify: `lib/main.dart`
- Modify: `lib/ui/home/home_screen.dart`
- Modify: `docs/DEVICE_TESTING.md`
- Test: `test/ui/home_screen_test.dart` (extend)

**Interfaces:**
- Consumes: `BlePermissions` (Task 1), `canHostProvider` (`lib/state/transport_provider.dart`)
- Produces: a permission request at startup, and a visible state when permissions are refused

**Verification: unit-testable for the UI branch; device-verified for the dialog.**

Until now permissions were granted out-of-band with `adb`. A real user must be asked.

- [ ] **Step 1: Request permissions at startup**

In `lib/main.dart`, make `main()` request permissions before running the app:

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Ask before the first screen renders, so Discover and Create are usable
  // immediately rather than failing silently on first tap.
  await BlePermissions.request();
  runApp(buildProductionApp());
}
```

Keep `buildProductionApp()` unchanged and synchronous — `test/widget_test.dart` pumps it directly.

- [ ] **Step 2: Write the failing test**

Add to `test/ui/home_screen_test.dart`:

```dart
  testWidgets('tells the user when Bluetooth is unavailable', (tester) async {
    // canHostProvider already fails closed on error (Task 14 of Plan A).
    // With a real transport, "adapter off" surfaces the same way, so the
    // user must see why hosting is unavailable rather than a dead button.
    await pumpApp(tester, peripheral: false);

    expect(find.text("This device can't host a group"), findsOneWidget);
  });
```

If a test of that name already exists from Plan A, leave it — it covers the same branch — and note that in your report instead of duplicating it.

- [ ] **Step 3: Run the tests**

Run: `flutter test test/ui/home_screen_test.dart`
Expected: PASS

- [ ] **Step 4: Confirm the suite still passes**

Run: `flutter test && flutter analyze`
Expected: all PASS, `No issues found!`

- [ ] **Step 5: Add device Check 5**

Append to `docs/DEVICE_TESTING.md`:

```markdown
## Check 5 — permissions and Bluetooth off (Task 8)

Uninstall and reinstall so permissions are fresh:

    adb -s $A uninstall com.example.bconnect
    adb -s $A install -r build/app/outputs/flutter-apk/app-debug.apk

Launch WITHOUT granting anything via adb.

PASS when the system permission dialog appears on first launch.

Then turn Bluetooth OFF on phone A and launch the app.

PASS when the home screen shows `This device can't host a group` and the
Create card does not navigate when tapped.
```

- [ ] **Step 6: Run device Check 5**

**Paste what you observed for both halves.**

- [ ] **Step 7: Commit**

```bash
git add lib/main.dart lib/ui test/ui docs/DEVICE_TESTING.md
git commit -m "feat: request BLE permissions at startup"
```

---

### Task 9: Reconnection and cleanup hardening

**Files:**
- Modify: `lib/transport/ble/ble_transport.dart`
- Modify: `docs/DEVICE_TESTING.md`

**Interfaces:**
- Consumes: everything above
- Produces: no new API — this task makes the existing one survive real-world conditions

**Verification: device-verified.**

Real radios drop. This task covers what the fake never could.

- [ ] **Step 1: Make dispose thorough**

Replace `dispose()`:

```dart
  @override
  Future<void> dispose() async {
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();

    // Stop the radio doing work after teardown: a live advertisement or scan
    // outlives the app's UI and drains battery.
    try {
      await _peripheral.stopAdvertising();
    } catch (_) {}
    try {
      await _central.stopDiscovery();
    } catch (_) {}

    for (final p in _connected.values) {
      try {
        await _central.disconnect(p);
      } catch (_) {}
    }
    _connected.clear();
    _clientControl.clear();
    _centrals.clear();
    _discovered.clear();

    await _events.close();
  }
```

- [ ] **Step 2: Stop scanning when a scan is restarted**

`startScan` may be called repeatedly — `discoveredGroupsProvider` is autoDispose and rebuilds on Refresh. Each call currently adds another listener to `_subs`, so adverts would be emitted twice, then three times.

At the top of `startScan`, after `await init();`, add:

```dart
    // The discovery provider is autoDispose and re-subscribes on Refresh.
    // Without this, each restart stacks another listener and every advert is
    // emitted once per previous scan.
    await _central.stopDiscovery();
```

and track the discovery subscription separately so it can be replaced rather than accumulated:

```dart
  StreamSubscription<DiscoveredEventArgs>? _discoverySub;
```

Assign to `_discoverySub` instead of adding to `_subs`, cancelling any previous one first. Remember to cancel it in `dispose()` too.

- [ ] **Step 3: Confirm the suite still passes**

Run: `flutter test && flutter analyze`
Expected: all PASS, `No issues found!`

- [ ] **Step 4: Add device Check 6**

Append to `docs/DEVICE_TESTING.md`:

```markdown
## Check 6 — real-world conditions (Task 9)

**Duplicate adverts.** Phone A hosts. On phone B, open Join Group, press
Refresh five times.

PASS when `Team Alpha` appears exactly ONCE in the list, not five times.

**Out of range.** With both phones in a group, walk phone B away until it
disconnects (or turn its Bluetooth off).

PASS when phone A's roster drops back to 1 member, and phone B shows
`Connection lost` and returns home.

**Rejoin.** Bring phone B back / turn Bluetooth on, and join again.

PASS when the join succeeds and phone A's roster returns to 2.

**Battery.** Leave phone A hosting for 5 minutes with the screen on.

PASS when the group is still discoverable from phone B afterwards.
```

- [ ] **Step 5: Run device Check 6**

**Paste the observed result of all four sub-checks.** The duplicate-advert one is the most likely to fail — if `Team Alpha` appears more than once, the fix is Step 2 of this task, not the UI.

- [ ] **Step 6: Commit**

```bash
git add lib/transport/ble/ble_transport.dart docs/DEVICE_TESTING.md
git commit -m "fix: harden BLE transport teardown and scan restarts"
```

---

### Task 10: Foreground service — surviving the screen lock

**Files:**
- Modify: `android/app/src/main/AndroidManifest.xml`
- Create: `android/app/src/main/kotlin/com/example/bconnect/GroupService.kt`
- Modify: `lib/transport/ble/ble_transport.dart`
- Modify: `docs/DEVICE_TESTING.md`

**Interfaces:**
- Consumes: `BleTransport` (Tasks 3-9)
- Produces: `BleTransport.startForegroundService()` / `stopForegroundService()`, called from `startAdvertising` / `stopAdvertising`

**Verification: device-verified.** This is the one behaviour a fake can never model.

Spec §8 requires it, and the Phase 0 spike demonstrated why: **advertising stopped the moment the app lost foreground.** Without this, a host that locks their screen silently drops the group and every member sees "connection lost".

- [ ] **Step 1: Declare the service and its permissions**

In `android/app/src/main/AndroidManifest.xml`, add above `<application>`:

```xml
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_CONNECTED_DEVICE" />
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
```

and inside `<application>`, alongside the activity:

```xml
        <service
            android:name=".GroupService"
            android:exported="false"
            android:foregroundServiceType="connectedDevice" />
```

`connectedDevice` is the correct type for a BLE session. Android 14+ rejects a
foreground service whose declared type does not match what it actually does.

- [ ] **Step 2: Write the service**

Create `android/app/src/main/kotlin/com/example/bconnect/GroupService.kt`:

```kotlin
package com.example.bconnect

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder

/**
 * Keeps the process alive while a group is active.
 *
 * Android stops BLE advertising when the hosting app leaves the foreground.
 * Without this service a host that locks their screen silently drops the
 * group, and every member sees a connection loss.
 */
class GroupService : Service() {
    companion object {
        private const val CHANNEL_ID = "bconnect_group"
        private const val NOTIFICATION_ID = 1
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        createChannel()

        val notification: Notification =
            Notification.Builder(this, CHANNEL_ID)
                .setContentTitle("Group active")
                .setContentText("Bconnect is keeping your group open")
                .setSmallIcon(android.R.drawable.stat_sys_data_bluetooth)
                .setOngoing(true)
                .build()

        startForeground(NOTIFICATION_ID, notification)
        // Do not restart with a null intent if the process is killed: the
        // group is gone by then and a notification with no group behind it
        // would be a lie.
        return START_NOT_STICKY
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Active group",
            NotificationManager.IMPORTANCE_LOW,
        )
        val manager = getSystemService(Context.NOTIFICATION_SERVICE)
                as NotificationManager
        manager.createNotificationChannel(channel)
    }
}
```

- [ ] **Step 3: Add the platform channel to start and stop it**

In `android/app/src/main/kotlin/com/example/bconnect/MainActivity.kt`, replace the class body with:

```kotlin
package com.example.bconnect

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channel = "bconnect/group_service"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel)
            .setMethodCallHandler { call, result ->
                val intent = Intent(this, GroupService::class.java)
                when (call.method) {
                    "start" -> {
                        startForegroundService(intent)
                        result.success(null)
                    }
                    "stop" -> {
                        stopService(intent)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
```

- [ ] **Step 4: Call it from the transport**

In `lib/transport/ble/ble_transport.dart`, add the import:

```dart
import 'package:flutter/services.dart';
```

add a field:

```dart
  static const _serviceChannel = MethodChannel('bconnect/group_service');
```

and these methods:

```dart
  /// Keeps the process alive while hosting. Android stops advertising when
  /// the app leaves the foreground (observed during the Phase 0 spike).
  Future<void> startForegroundService() async {
    try {
      await _serviceChannel.invokeMethod<void>('start');
    } on PlatformException {
      // Not fatal: the group still works while the app is in the foreground.
    }
  }

  Future<void> stopForegroundService() async {
    try {
      await _serviceChannel.invokeMethod<void>('stop');
    } on PlatformException {
      // Nothing to stop.
    }
  }
```

Call `await startForegroundService();` at the end of `startAdvertising`, and
`await stopForegroundService();` at the start of `stopAdvertising`.

- [ ] **Step 5: Confirm the suite still passes**

Run: `flutter test && flutter analyze`
Expected: all PASS, `No issues found!`

The method channel has no handler under `flutter test`, so `invokeMethod`
throws `MissingPluginException` — which is **not** caught by the
`PlatformException` handler above. If any test exercises `startAdvertising`
on a `BleTransport`, widen the catch to `catch (_)`. Note in your report
whether this was needed.

- [ ] **Step 6: Add device Check 7**

Append to `docs/DEVICE_TESTING.md`:

```markdown
## Check 7 — the group survives backgrounding (Task 10)

1. Phone A: create "Team Alpha".
2. PASS when a notification appears: `Group active`.
3. Press HOME on phone A, then lock the screen.
4. Phone B: open Join Group.

PASS when `Team Alpha` is STILL listed with phone A's screen off.

5. Phone B joins while phone A stays locked.

PASS when the join succeeds, and phone A shows 2 members when unlocked.

6. Phone A: End Call.

PASS when the `Group active` notification disappears.

This is the check that the in-memory fake could never model: the Phase 0
spike showed advertising stops when the app loses foreground.
```

- [ ] **Step 7: Run device Check 7**

**Paste the observed result of each sub-step.** Sub-step 4 is the point of the task — if the group vanishes when the screen locks, the service is not holding the process and the task is not done.

- [ ] **Step 8: Commit**

```bash
git add android lib/transport/ble/ble_transport.dart docs/DEVICE_TESTING.md
git commit -m "feat: foreground service keeps groups alive when backgrounded"
```

---

### Task 11: Gate 3 — aggregate connections (needs a third device)

**Files:**
- Modify: `docs/DEVICE_TESTING.md`
- Modify: `lib/domain/protocol/protocol_limits.dart` (only if the gate fails)

**Interfaces:**
- Consumes: everything above
- Produces: either a confirmation that the spec's limits hold, or corrected limits

**Verification: device-verified, and BLOCKED without a third Android phone.**

Spec §9.1 Gate 3 is the last unvalidated assumption in the transport design. Phase 0 could not test it with two devices.

**If no third device is available, mark this task BLOCKED and stop.** Do not guess, and do not lower the limits speculatively — the fallback is only applied against a measured failure.

- [ ] **Step 1: Add device Check 8**

Append to `docs/DEVICE_TESTING.md`:

```markdown
## Check 8 — Gate 3, several clients on one host (needs 3+ phones)

Phone A hosts. Phones B and C both join.

PASS when:
- phone A's roster shows 3 members
- B and C both show 3 members
- neither B nor C is dropped within 2 minutes

With more phones, repeat up to `ProtocolLimits.maxMembers` (8).

If the host drops clients beyond some count N, that N minus one is the real
maximum. Spec section 9.1 says the fallback is graduated: set
`ProtocolLimits.maxMembers` to the measured value and update spec section 5.5.
Do NOT lower it without a measurement.
```

- [ ] **Step 2: Run device Check 8 if hardware allows**

With three or more phones, run it and **paste the observed roster counts**.

Without a third phone, report this task BLOCKED, stating that Gate 3 remains unvalidated and that `maxMembers = 8` is still an assumption.

- [ ] **Step 3: Commit**

```bash
git add docs/DEVICE_TESTING.md
git commit -m "docs: add Gate 3 aggregate-connection device check"
```

---

## Done criteria for Plan B1

- `flutter test` passes (223+ tests) and `flutter analyze` is clean.
- Device Checks 1-7 all pass, with observed output recorded.
- Two phones can discover, join with a password, see a live roster, and react to the host ending the group.
- `FakeTransport` is untouched and still backs every automated test.
- Gate 3 (Check 8) is either passed or explicitly recorded as blocked.

**Not in scope, by design:** any audio. The mic button, speaker/earpiece and talk indicators remain inert until Plan B2.
