# Bconnect Plan A (Phases 1–3) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the complete Bconnect UI, domain layer, and protocol against an in-memory fake transport, so the entire app is clickable end-to-end with zero Bluetooth hardware.

**Architecture:** Pure Dart domain and protocol layers sit behind an abstract `GroupTransport` interface. `FakeTransport` implements it as an in-memory hub, letting a host and several clients run inside one test process. Riverpod providers expose session, roster, mic, and audio-route state to seven screens. No native code is written in this plan.

**Tech Stack:** Flutter 3.38.6 / Dart 3.10.7, flutter_riverpod 3.3.2 (non-codegen API), freezed 3.2.3, go_router 17.5.0, shared_preferences 2.5.5, crypto 3.0.7, build_runner 2.15.1, mocktail 1.0.5.

**Spec:** `docs/superpowers/specs/2026-08-26-bluetooth-group-talk-design.md`

---

## Global Constraints

Every task's requirements implicitly include this section.

- **Platform:** Android only. Do not add iOS-specific code or configuration.
- **`minSdkVersion` 24** (spec §8.1). Not configured in this plan; Plan B owns it.
- **Dart SDK is `^3.10.7`.** Many current package versions require Dart ≥3.12 or ≥3.13 and **will not resolve**. Use exactly the versions in Task 1. Do not run `flutter pub upgrade --major-versions`.
- **`build_runner` 2.15.1 removed `--delete-conflicting-outputs`.** The correct command is `dart run build_runner build`. Passing the old flag prints a warning and is ignored.
- **Protocol version is `1`** (spec §5.3).
- **Maximum group size is 8** — host + 7 (spec §5.5).
- **Maximum concurrent talkers is 3** (spec §5.4). A fourth talk request is refused.
- **Group names are capped at 29 UTF-8 bytes** (spec §5.1), enforced at input time.
- **Password proof is `HMAC-SHA256(password, nonce)` truncated to 16 bytes** (spec §5.3). The password is never transmitted.
- **Audio frames never cross the Dart boundary** (spec §3.5). No task in this plan may add an audio-frame type to `GroupTransport`.
- **No `freezed` for protocol wire types that need byte-exact layout** — `AdvertPayload` is a plain class. Freezed is for domain models only.
- **Theme is dark-only.** No light theme, no theme switching.

### Relationship to Phase 0

Spec §9 lists Phase 0 (the BLE throughput spike) before this work. **Phase 0 is not part of this plan and does not block it.** Everything here runs on `FakeTransport` and is transport-agnostic. Phase 0's measurements gate *Plan B* (the native BLE and audio implementation).

If Phase 0's aggregate test fails (spec §9.1), the only change required in this plan's output is the value of two constants in `lib/domain/protocol/protocol_limits.dart` — `maxMembers` and `maxConcurrentTalkers`. That isolation is deliberate.

### Deliberately deferred to Plan B

These spec items have **no task in this plan**, because they cannot be
implemented or meaningfully tested without the native layer. Listing them
explicitly so the gap is a decision rather than an oversight:

| Spec item | Why deferred |
|---|---|
| §6.2 `permissionsProvider` | Needs `permission_handler` and real Android runtime permissions. Not in Task 1's dependencies |
| §6.2 `adapterStateProvider` | Needs a real Bluetooth adapter state stream |
| §5.2 GATT service and characteristics | Native BLE; `GroupTransport` (Task 7) is the seam it plugs into |
| §5.4 audio frames, codec, relay, mixing | Entirely native by design (§3.5) |
| §8 Bluetooth-off banner, permission rationale, client reconnect backoff, phone-call interruption | All depend on platform signals that `FakeTransport` does not produce |

Two §8 items *are* covered here, because they are UI decisions rather than
platform ones: peripheral-unsupported disables hosting (Task 14), and
wrong-password / group-full handling (Tasks 16, 17).

---

## File Structure

```
lib/
  main.dart                                  app entry, ProviderScope
  app.dart                                   MaterialApp.router, theme wiring
  core/
    theme/app_colors.dart                    palette tokens
    theme/app_theme.dart                     dark Material 3 ThemeData
    router/app_router.dart                   go_router configuration
  domain/
    models/member.dart                       Member, MemberPresence
    models/group_config.dart                 GroupConfig
    models/discovered_group.dart             DiscoveredGroup
    models/audio.dart                        AudioRoute, MicState
    models/session_state.dart                SessionState union, JoinStep, SessionError
    protocol/protocol_limits.dart            all wire constants
    protocol/advert_payload.dart             advertisement + scan-response codec
    protocol/password_proof.dart             HMAC challenge/response
    protocol/control_frame.dart              ControlFrame union, JoinRejectReason
    protocol/frame_codec.dart                binary encode/decode + ByteReader/ByteWriter
    session/roster.dart                      pure roster reducer
    session/host_session.dart                host-role state machine
    session/client_session.dart              client-role state machine
  transport/
    group_transport.dart                     GroupTransport interface, TransportEvent union
    fake/fake_hub.dart                       in-memory broker shared by fake peers
    fake/fake_transport.dart                 GroupTransport implementation
  state/
    transport_provider.dart                  transportProvider (overridden in tests)
    session_provider.dart                    SessionController
    discovered_groups_provider.dart          scan results with TTL expiry
    mic_provider.dart                        MicController
    audio_route_provider.dart                AudioRouteController
    recent_groups_provider.dart              persisted recent groups
    display_name_provider.dart               persisted display name
  ui/
    home/home_screen.dart
    create/create_group_screen.dart
    discover/discover_screen.dart
    discover/widgets/group_tile.dart
    join/join_password_screen.dart
    group/group_screen.dart
    group/widgets/member_tile.dart
    group/widgets/call_controls.dart
    audio/audio_output_screen.dart
    settings/settings_screen.dart
    common/status_banner.dart
test/
  domain/protocol/advert_payload_test.dart
  domain/protocol/password_proof_test.dart
  domain/protocol/frame_codec_test.dart
  domain/session/roster_test.dart
  transport/fake_transport_test.dart
  session/host_session_test.dart
  session/client_session_test.dart
  integration/group_flow_test.dart
  state/*_test.dart
  ui/*_test.dart
```

Files are split by responsibility rather than technical layer: the protocol codec lives with the frames it encodes, and each screen's private widgets sit beside it.

---

### Task 1: Project scaffolding, theme, and dependencies

**Files:**
- Modify: `pubspec.yaml`
- Modify: `analysis_options.yaml`
- Create: `lib/core/theme/app_colors.dart`
- Create: `lib/core/theme/app_theme.dart`
- Create: `lib/app.dart`
- Rewrite: `lib/main.dart`
- Rewrite: `test/widget_test.dart`

**Interfaces:**
- Consumes: nothing (first task)
- Produces: `AppColors` (static const `Color` fields listed below), `AppTheme.dark` → `ThemeData`, `BconnectApp` (a `StatelessWidget`)

- [ ] **Step 1: Initialise git**

This directory is not yet a git repository, and every task ends in a commit.

```bash
cd /Users/user/StudioProjects/Bconnect
git init
git add -A
git commit -m "chore: initial Flutter scaffold"
```

- [ ] **Step 2: Set exact dependency versions**

Replace the `dependencies` and `dev_dependencies` blocks in `pubspec.yaml`. These versions are verified to resolve on Dart 3.10.7 — newer ones do not.

```yaml
dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.8
  flutter_riverpod: ^3.3.2
  freezed_annotation: ^3.1.0
  go_router: ^17.5.0
  shared_preferences: ^2.5.5
  crypto: ^3.0.7

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0
  build_runner: ^2.15.1
  freezed: ^3.2.3
  mocktail: ^1.0.5
```

Run: `flutter pub get`
Expected: `Changed N dependencies!` with no version-solving error.

- [ ] **Step 3: Write the failing test**

Replace `test/widget_test.dart` entirely:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bconnect/app.dart';

void main() {
  testWidgets('app builds with a dark theme', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: BconnectApp()));

    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(materialApp.themeMode, ThemeMode.dark);
    expect(materialApp.darkTheme, isNotNull);
    expect(materialApp.darkTheme!.brightness, Brightness.dark);
  });
}
```

- [ ] **Step 4: Run test to verify it fails**

Run: `flutter test test/widget_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:bconnect/app.dart'`

- [ ] **Step 5: Create the colour tokens**

Create `lib/core/theme/app_colors.dart`. Values are taken from the mockups in spec §6.3.

```dart
import 'package:flutter/material.dart';

/// Palette tokens for the dark-only Bconnect theme (spec section 6.3).
abstract final class AppColors {
  static const Color background = Color(0xFF0B1020);
  static const Color surface = Color(0xFF121826);
  static const Color surfaceRaised = Color(0xFF1B2437);

  static const Color primary = Color(0xFF2563EB);
  static const Color onPrimary = Color(0xFFFFFFFF);

  /// Active-group state: the member badge and "Group is Active" dot.
  static const Color active = Color(0xFF22C55E);

  /// End Call.
  static const Color danger = Color(0xFFDC2626);

  /// The create-group avatar.
  static const Color accent = Color(0xFF7C3AED);

  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color divider = Color(0xFF1F2937);
}
```

- [ ] **Step 6: Create the theme**

Create `lib/core/theme/app_theme.dart`:

```dart
import 'package:flutter/material.dart';

import 'app_colors.dart';

abstract final class AppTheme {
  static ThemeData get dark {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.dark,
    ).copyWith(
      surface: AppColors.surface,
      primary: AppColors.primary,
      onPrimary: AppColors.onPrimary,
      error: AppColors.danger,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      dividerColor: AppColors.divider,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: const CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
      ),
      listTileTheme: const ListTileThemeData(
        textColor: AppColors.textPrimary,
        iconColor: AppColors.textSecondary,
      ),
    );
  }
}
```

- [ ] **Step 7: Create the app shell**

Create `lib/app.dart`. The router arrives in Task 14; until then this is a plain `MaterialApp` with a placeholder home so the test can assert on theme.

```dart
import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';

class BconnectApp extends StatelessWidget {
  const BconnectApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Group Talk',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: AppTheme.dark,
      home: const Scaffold(body: SizedBox.shrink()),
    );
  }
}
```

- [ ] **Step 8: Rewrite main.dart**

Replace `lib/main.dart` entirely, deleting the default counter app:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';

void main() {
  runApp(const ProviderScope(child: BconnectApp()));
}
```

- [ ] **Step 9: Run test to verify it passes**

Run: `flutter test test/widget_test.dart`
Expected: PASS (1 test)

- [ ] **Step 10: Verify analysis is clean**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 11: Commit**

```bash
git add pubspec.yaml pubspec.lock analysis_options.yaml lib test
git commit -m "feat: scaffold app shell with dark theme and pinned deps"
```

---

### Task 2: Domain models

**Files:**
- Create: `lib/domain/models/member.dart`
- Create: `lib/domain/models/group_config.dart`
- Create: `lib/domain/models/discovered_group.dart`
- Create: `lib/domain/models/audio.dart`
- Test: `test/domain/models/models_test.dart`

**Interfaces:**
- Consumes: nothing
- Produces:
  - `enum MemberPresence { online, reconnecting, offline }`
  - `Member({required String id, required String displayName, bool isHost, bool isSelf, MemberPresence presence, bool isTalking})` — all optional fields default as shown below
  - `GroupConfig({required String name, String? password})` with `bool get isLocked`
  - `DiscoveredGroup({required String groupId, required String deviceId, required String name, required int memberCount, required bool isLocked, required bool isFull, required int rssi, required DateTime lastSeen})`
  - `enum AudioRoute { speaker, earpiece }`
  - `MicState({bool muted, bool transmitting})`

Freezed 3.x requires `abstract class X with _$X` for product types. A private constructor (`const X._();`) is required on any class that declares a custom getter.

- [ ] **Step 1: Write the failing test**

Create `test/domain/models/models_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';

import 'package:bconnect/domain/models/audio.dart';
import 'package:bconnect/domain/models/group_config.dart';
import 'package:bconnect/domain/models/member.dart';

void main() {
  group('Member', () {
    test('defaults to a non-host, non-self, online, silent member', () {
      const m = Member(id: '1', displayName: 'Device 1');

      expect(m.isHost, isFalse);
      expect(m.isSelf, isFalse);
      expect(m.presence, MemberPresence.online);
      expect(m.isTalking, isFalse);
    });

    test('has value equality', () {
      const a = Member(id: '1', displayName: 'You', isHost: true);
      const b = Member(id: '1', displayName: 'You', isHost: true);

      expect(a, equals(b));
    });

    test('copyWith replaces only the named field', () {
      const m = Member(id: '1', displayName: 'You');

      expect(m.copyWith(isTalking: true).isTalking, isTrue);
      expect(m.copyWith(isTalking: true).displayName, 'You');
    });
  });

  group('GroupConfig', () {
    test('is unlocked when the password is null or empty', () {
      expect(const GroupConfig(name: 'Team Alpha').isLocked, isFalse);
      expect(const GroupConfig(name: 'A', password: '').isLocked, isFalse);
    });

    test('is locked when a password is set', () {
      expect(const GroupConfig(name: 'A', password: 'hunter2').isLocked, isTrue);
    });
  });

  group('MicState', () {
    test('defaults to unmuted and not transmitting', () {
      const s = MicState();

      expect(s.muted, isFalse);
      expect(s.transmitting, isFalse);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/domain/models/models_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:bconnect/domain/models/member.dart'`

- [ ] **Step 3: Create Member**

Create `lib/domain/models/member.dart`:

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'member.freezed.dart';

enum MemberPresence { online, reconnecting, offline }

@freezed
abstract class Member with _$Member {
  const factory Member({
    required String id,
    required String displayName,
    @Default(false) bool isHost,
    @Default(false) bool isSelf,
    @Default(MemberPresence.online) MemberPresence presence,
    @Default(false) bool isTalking,
  }) = _Member;
}
```

- [ ] **Step 4: Create GroupConfig**

Create `lib/domain/models/group_config.dart`:

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'group_config.freezed.dart';

@freezed
abstract class GroupConfig with _$GroupConfig {
  const factory GroupConfig({
    required String name,
    String? password,
  }) = _GroupConfig;

  const GroupConfig._();

  /// A group is password-protected only when a non-empty password is set.
  bool get isLocked => password != null && password!.isNotEmpty;
}
```

- [ ] **Step 5: Create DiscoveredGroup**

Create `lib/domain/models/discovered_group.dart`:

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'discovered_group.freezed.dart';

@freezed
abstract class DiscoveredGroup with _$DiscoveredGroup {
  const factory DiscoveredGroup({
    /// Four lowercase hex digits, from the 2-byte advertised group id.
    required String groupId,

    /// Transport-specific address used to open a connection.
    required String deviceId,
    required String name,
    required int memberCount,
    required bool isLocked,
    required bool isFull,
    required int rssi,
    required DateTime lastSeen,
  }) = _DiscoveredGroup;
}
```

- [ ] **Step 6: Create the audio models**

Create `lib/domain/models/audio.dart`:

```dart
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
```

- [ ] **Step 7: Generate the freezed code**

Run: `dart run build_runner build`
Expected: `Built with build_runner ...; wrote 4 outputs.`

Do not pass `--delete-conflicting-outputs`; build_runner 2.15.1 removed it.

- [ ] **Step 8: Run test to verify it passes**

Run: `flutter test test/domain/models/models_test.dart`
Expected: PASS (5 tests)

- [ ] **Step 9: Commit**

```bash
git add lib/domain/models test/domain/models
git commit -m "feat: add core domain models"
```

---

### Task 3: Protocol limits and advertisement codec

**Files:**
- Create: `lib/domain/protocol/protocol_limits.dart`
- Create: `lib/domain/protocol/advert_payload.dart`
- Test: `test/domain/protocol/advert_payload_test.dart`

**Interfaces:**
- Consumes: nothing
- Produces:
  - `ProtocolLimits` with static const: `protocolVersion` (1), `magic` (0xB1C7), `maxMembers` (8), `maxConcurrentTalkers` (3), `maxGroupNameBytes` (29), `passwordProofLength` (16), `nonceLength` (16), `advertTtl` (`Duration(seconds: 10)`), `serviceDataLength` (7)
  - `AdvertPayload({required int groupId, required int memberCount, required bool isLocked, required bool isFull})` with `Uint8List encode()`, `static AdvertPayload? decode(Uint8List)`, `String get groupIdHex`
  - `static Uint8List AdvertPayload.encodeName(String)`, `static String AdvertPayload.decodeName(Uint8List)`
  - `class GroupNameTooLongException implements Exception`

Service data layout (spec §5.1), 7 bytes: `magic(2, big-endian) | version(1) | flags(1) | memberCount(1) | groupId(2, big-endian)`. `flags` bit 0 = locked, bit 1 = full.

- [ ] **Step 1: Write the failing test**

Create `test/domain/protocol/advert_payload_test.dart`:

```dart
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:bconnect/domain/protocol/advert_payload.dart';
import 'package:bconnect/domain/protocol/protocol_limits.dart';

void main() {
  group('AdvertPayload service data', () {
    test('encodes to exactly the advertised service-data length', () {
      const p = AdvertPayload(
        groupId: 0x1A2B,
        memberCount: 3,
        isLocked: true,
        isFull: false,
      );

      expect(p.encode().length, ProtocolLimits.serviceDataLength);
    });

    test('round-trips every field', () {
      const p = AdvertPayload(
        groupId: 0x1A2B,
        memberCount: 3,
        isLocked: true,
        isFull: false,
      );

      expect(AdvertPayload.decode(p.encode()), equals(p));
    });

    test('round-trips the full flag independently of the locked flag', () {
      const p = AdvertPayload(
        groupId: 0xFFFF,
        memberCount: ProtocolLimits.maxMembers,
        isLocked: false,
        isFull: true,
      );

      final decoded = AdvertPayload.decode(p.encode())!;

      expect(decoded.isFull, isTrue);
      expect(decoded.isLocked, isFalse);
    });

    test('exposes the group id as four lowercase hex digits', () {
      const p = AdvertPayload(
        groupId: 0x0A2B,
        memberCount: 1,
        isLocked: false,
        isFull: false,
      );

      expect(p.groupIdHex, '0a2b');
    });

    test('rejects data of the wrong length', () {
      expect(AdvertPayload.decode(Uint8List(6)), isNull);
      expect(AdvertPayload.decode(Uint8List(8)), isNull);
    });

    test('rejects data whose magic does not match', () {
      const p = AdvertPayload(
        groupId: 1,
        memberCount: 1,
        isLocked: false,
        isFull: false,
      );
      final bytes = p.encode();
      bytes[0] = 0x00;

      expect(AdvertPayload.decode(bytes), isNull);
    });

    test('rejects data from an unknown protocol version', () {
      const p = AdvertPayload(
        groupId: 1,
        memberCount: 1,
        isLocked: false,
        isFull: false,
      );
      final bytes = p.encode();
      bytes[2] = 99;

      expect(AdvertPayload.decode(bytes), isNull);
    });
  });

  group('AdvertPayload scan-response name', () {
    test('round-trips an ASCII name', () {
      expect(
        AdvertPayload.decodeName(AdvertPayload.encodeName('Team Alpha')),
        'Team Alpha',
      );
    });

    test('round-trips a multi-byte UTF-8 name', () {
      expect(
        AdvertPayload.decodeName(AdvertPayload.encodeName('Grüße 🎧')),
        'Grüße 🎧',
      );
    });

    test('accepts a name of exactly the byte limit', () {
      final name = 'a' * ProtocolLimits.maxGroupNameBytes;

      expect(AdvertPayload.encodeName(name).length,
          ProtocolLimits.maxGroupNameBytes);
    });

    test('rejects a name one byte over the limit', () {
      final name = 'a' * (ProtocolLimits.maxGroupNameBytes + 1);

      expect(
        () => AdvertPayload.encodeName(name),
        throwsA(isA<GroupNameTooLongException>()),
      );
    });

    test('measures the limit in UTF-8 bytes, not characters', () {
      // 15 two-byte characters is 30 bytes: over the 29-byte limit even
      // though it is only 15 characters.
      final name = 'ü' * 15;

      expect(
        () => AdvertPayload.encodeName(name),
        throwsA(isA<GroupNameTooLongException>()),
      );
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/domain/protocol/advert_payload_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:bconnect/domain/protocol/advert_payload.dart'`

- [ ] **Step 3: Create the protocol constants**

Create `lib/domain/protocol/protocol_limits.dart`:

```dart
/// Wire-level constants shared by every peer (spec sections 5.1, 5.4, 5.5).
///
/// If the Phase 0 aggregate throughput test fails (spec section 9.1),
/// [maxMembers] and [maxConcurrentTalkers] are the only values that change.
abstract final class ProtocolLimits {
  static const int protocolVersion = 1;

  /// Distinguishes Bconnect adverts from other apps sharing the 16-bit
  /// service UUID.
  static const int magic = 0xB1C7;

  /// Host plus seven clients.
  static const int maxMembers = 8;

  static const int maxConcurrentTalkers = 3;

  /// Scan-response capacity for the group name.
  static const int maxGroupNameBytes = 29;

  static const int nonceLength = 16;

  /// Truncated HMAC-SHA256.
  static const int passwordProofLength = 16;

  /// magic(2) + version(1) + flags(1) + memberCount(1) + groupId(2)
  static const int serviceDataLength = 7;

  /// A scan result older than this is dropped from the discovery list.
  static const Duration advertTtl = Duration(seconds: 10);

  static const int flagLocked = 0x01;
  static const int flagFull = 0x02;
}
```

- [ ] **Step 4: Create the advertisement codec**

Create `lib/domain/protocol/advert_payload.dart`:

```dart
import 'dart:convert';
import 'dart:typed_data';

import 'protocol_limits.dart';

class GroupNameTooLongException implements Exception {
  const GroupNameTooLongException(this.byteLength);

  final int byteLength;

  @override
  String toString() =>
      'Group name is $byteLength UTF-8 bytes; the limit is '
      '${ProtocolLimits.maxGroupNameBytes}.';
}

/// The BLE advertisement service data (spec section 5.1).
///
/// This is a plain class rather than a freezed model because its byte layout
/// is part of the wire protocol.
class AdvertPayload {
  const AdvertPayload({
    required this.groupId,
    required this.memberCount,
    required this.isLocked,
    required this.isFull,
  });

  final int groupId;
  final int memberCount;
  final bool isLocked;
  final bool isFull;

  String get groupIdHex => groupId.toRadixString(16).padLeft(4, '0');

  Uint8List encode() {
    final bytes = Uint8List(ProtocolLimits.serviceDataLength);
    final view = ByteData.view(bytes.buffer);

    view.setUint16(0, ProtocolLimits.magic);
    view.setUint8(2, ProtocolLimits.protocolVersion);
    view.setUint8(
      3,
      (isLocked ? ProtocolLimits.flagLocked : 0) |
          (isFull ? ProtocolLimits.flagFull : 0),
    );
    view.setUint8(4, memberCount);
    view.setUint16(5, groupId);

    return bytes;
  }

  /// Returns null for anything that is not a current-version Bconnect advert.
  static AdvertPayload? decode(Uint8List bytes) {
    if (bytes.length != ProtocolLimits.serviceDataLength) return null;

    final view = ByteData.view(bytes.buffer, bytes.offsetInBytes, bytes.length);

    if (view.getUint16(0) != ProtocolLimits.magic) return null;
    if (view.getUint8(2) != ProtocolLimits.protocolVersion) return null;

    final flags = view.getUint8(3);

    return AdvertPayload(
      groupId: view.getUint16(5),
      memberCount: view.getUint8(4),
      isLocked: flags & ProtocolLimits.flagLocked != 0,
      isFull: flags & ProtocolLimits.flagFull != 0,
    );
  }

  /// The group name travels in the scan response, not the advertisement,
  /// which is what buys 29 bytes instead of roughly 15 (spec section 5.1).
  static Uint8List encodeName(String name) {
    final bytes = utf8.encode(name);
    if (bytes.length > ProtocolLimits.maxGroupNameBytes) {
      throw GroupNameTooLongException(bytes.length);
    }
    return Uint8List.fromList(bytes);
  }

  static String decodeName(Uint8List bytes) => utf8.decode(bytes);

  @override
  bool operator ==(Object other) =>
      other is AdvertPayload &&
      other.groupId == groupId &&
      other.memberCount == memberCount &&
      other.isLocked == isLocked &&
      other.isFull == isFull;

  @override
  int get hashCode => Object.hash(groupId, memberCount, isLocked, isFull);

  @override
  String toString() =>
      'AdvertPayload(groupId: $groupIdHex, memberCount: $memberCount, '
      'isLocked: $isLocked, isFull: $isFull)';
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/domain/protocol/advert_payload_test.dart`
Expected: PASS (11 tests)

- [ ] **Step 6: Commit**

```bash
git add lib/domain/protocol test/domain/protocol
git commit -m "feat: add advertisement payload codec and protocol limits"
```

---

### Task 4: Password challenge/response

**Files:**
- Create: `lib/domain/protocol/password_proof.dart`
- Test: `test/domain/protocol/password_proof_test.dart`

**Interfaces:**
- Consumes: `ProtocolLimits` (Task 3)
- Produces: `PasswordProof.generateNonce([Random?])` → `Uint8List` of `nonceLength`; `PasswordProof.compute({required String password, required Uint8List nonce})` → `Uint8List` of `passwordProofLength`; `PasswordProof.verify({required String password, required Uint8List nonce, required Uint8List proof})` → `bool`

The password is never transmitted (spec §5.3). `verify` compares in constant time so a timing side channel cannot leak the expected proof.

- [ ] **Step 1: Write the failing test**

Create `test/domain/protocol/password_proof_test.dart`:

```dart
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:bconnect/domain/protocol/password_proof.dart';
import 'package:bconnect/domain/protocol/protocol_limits.dart';

void main() {
  final nonce = PasswordProof.generateNonce(Random(1));

  group('generateNonce', () {
    test('returns the advertised nonce length', () {
      expect(nonce.length, ProtocolLimits.nonceLength);
    });

    test('returns different values across calls', () {
      final a = PasswordProof.generateNonce();
      final b = PasswordProof.generateNonce();

      expect(a, isNot(equals(b)));
    });
  });

  group('compute', () {
    test('returns the truncated proof length', () {
      expect(
        PasswordProof.compute(password: 'hunter2', nonce: nonce).length,
        ProtocolLimits.passwordProofLength,
      );
    });

    test('is deterministic for the same password and nonce', () {
      expect(
        PasswordProof.compute(password: 'hunter2', nonce: nonce),
        equals(PasswordProof.compute(password: 'hunter2', nonce: nonce)),
      );
    });

    test('differs for a different password', () {
      expect(
        PasswordProof.compute(password: 'hunter2', nonce: nonce),
        isNot(equals(PasswordProof.compute(password: 'hunter3', nonce: nonce))),
      );
    });

    test('differs for a different nonce, which is what defeats replay', () {
      final other = PasswordProof.generateNonce(Random(2));

      expect(
        PasswordProof.compute(password: 'hunter2', nonce: nonce),
        isNot(equals(PasswordProof.compute(password: 'hunter2', nonce: other))),
      );
    });
  });

  group('verify', () {
    test('accepts a proof computed from the same password', () {
      final proof = PasswordProof.compute(password: 'hunter2', nonce: nonce);

      expect(
        PasswordProof.verify(
            password: 'hunter2', nonce: nonce, proof: proof),
        isTrue,
      );
    });

    test('rejects a proof computed from a different password', () {
      final proof = PasswordProof.compute(password: 'wrong', nonce: nonce);

      expect(
        PasswordProof.verify(
            password: 'hunter2', nonce: nonce, proof: proof),
        isFalse,
      );
    });

    test('rejects a proof replayed against a different nonce', () {
      final proof = PasswordProof.compute(password: 'hunter2', nonce: nonce);
      final later = PasswordProof.generateNonce(Random(3));

      expect(
        PasswordProof.verify(
            password: 'hunter2', nonce: later, proof: proof),
        isFalse,
      );
    });

    test('rejects a proof of the wrong length', () {
      expect(
        PasswordProof.verify(
            password: 'hunter2', nonce: nonce, proof: Uint8List(4)),
        isFalse,
      );
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/domain/protocol/password_proof_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:bconnect/domain/protocol/password_proof.dart'`

- [ ] **Step 3: Write the implementation**

Create `lib/domain/protocol/password_proof.dart`:

```dart
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'protocol_limits.dart';

/// The join challenge (spec section 5.3).
///
/// The host issues a nonce; the client returns
/// `HMAC-SHA256(password, nonce)` truncated to 16 bytes. The password itself
/// never crosses the wire, and a captured proof cannot be replayed against a
/// later nonce.
abstract final class PasswordProof {
  static final Random _defaultRandom = Random.secure();

  static Uint8List generateNonce([Random? random]) {
    final source = random ?? _defaultRandom;
    final nonce = Uint8List(ProtocolLimits.nonceLength);
    for (var i = 0; i < nonce.length; i++) {
      nonce[i] = source.nextInt(256);
    }
    return nonce;
  }

  static Uint8List compute({
    required String password,
    required Uint8List nonce,
  }) {
    final mac = Hmac(sha256, utf8.encode(password)).convert(nonce);
    return Uint8List.fromList(
      mac.bytes.sublist(0, ProtocolLimits.passwordProofLength),
    );
  }

  static bool verify({
    required String password,
    required Uint8List nonce,
    required Uint8List proof,
  }) {
    final expected = compute(password: password, nonce: nonce);
    if (proof.length != expected.length) return false;

    // Constant-time comparison: always inspect every byte so that the time
    // taken does not reveal how much of the proof was correct.
    var diff = 0;
    for (var i = 0; i < expected.length; i++) {
      diff |= expected[i] ^ proof[i];
    }
    return diff == 0;
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/domain/protocol/password_proof_test.dart`
Expected: PASS (10 tests)

- [ ] **Step 5: Commit**

```bash
git add lib/domain/protocol/password_proof.dart test/domain/protocol/password_proof_test.dart
git commit -m "feat: add HMAC password challenge and response"
```

---

### Task 5: Control frames and binary codec

**Files:**
- Create: `lib/domain/protocol/control_frame.dart`
- Create: `lib/domain/protocol/frame_codec.dart`
- Test: `test/domain/protocol/frame_codec_test.dart`

**Interfaces:**
- Consumes: `Member`, `MemberPresence` (Task 2); `ProtocolLimits` (Task 3)
- Produces:
  - `enum JoinRejectReason { wrongPassword, full, incompatibleVersion }`
  - Sealed union `ControlFrame` with constructors `challenge`, `joinRequest`, `joinAccepted`, `joinRejected`, `rosterUpdate`, `talkStart`, `talkStop`, `leave`, `ping`, `pong` and concrete subclasses `ChallengeFrame`, `JoinRequestFrame`, `JoinAcceptedFrame`, `JoinRejectedFrame`, `RosterUpdateFrame`, `TalkStartFrame`, `TalkStopFrame`, `LeaveFrame`, `PingFrame`, `PongFrame`
  - `FrameCodec.encode(ControlFrame)` → `Uint8List`; `FrameCodec.decode(Uint8List)` → `ControlFrame`
  - `class FrameDecodeException implements Exception`

`ControlFrame.challenge` implements the sentence in spec §5.3, "On connect the host issues a nonce". The spec lists the nonce as part of the handshake without naming a frame; this is that frame.

- [ ] **Step 1: Write the failing test**

Create `test/domain/protocol/frame_codec_test.dart`:

```dart
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:bconnect/domain/models/member.dart';
import 'package:bconnect/domain/protocol/control_frame.dart';
import 'package:bconnect/domain/protocol/frame_codec.dart';

void main() {
  void expectRoundTrip(ControlFrame frame) {
    expect(FrameCodec.decode(FrameCodec.encode(frame)), equals(frame));
  }

  test('round-trips a challenge', () {
    expectRoundTrip(
      ControlFrame.challenge(nonce: Uint8List.fromList(List.generate(16, (i) => i))),
    );
  });

  test('round-trips a join request', () {
    expectRoundTrip(
      ControlFrame.joinRequest(
        version: 1,
        displayName: 'Device 1',
        passwordProof: Uint8List.fromList(List.filled(16, 7)),
      ),
    );
  });

  test('round-trips a join request with an empty proof for an open group', () {
    expectRoundTrip(
      ControlFrame.joinRequest(
        version: 1,
        displayName: 'Device 1',
        passwordProof: Uint8List(0),
      ),
    );
  });

  test('round-trips a join acceptance carrying a full roster', () {
    expectRoundTrip(
      ControlFrame.joinAccepted(
        memberId: 'm2',
        roster: const [
          Member(id: 'm1', displayName: 'You', isHost: true),
          Member(
            id: 'm2',
            displayName: 'Device 1',
            presence: MemberPresence.reconnecting,
            isTalking: true,
          ),
        ],
      ),
    );
  });

  test('round-trips every rejection reason', () {
    for (final reason in JoinRejectReason.values) {
      expectRoundTrip(ControlFrame.joinRejected(reason: reason));
    }
  });

  test('round-trips a roster update', () {
    expectRoundTrip(
      ControlFrame.rosterUpdate(
        members: const [Member(id: 'm1', displayName: 'You', isHost: true)],
      ),
    );
  });

  test('round-trips an empty roster', () {
    expectRoundTrip(const ControlFrame.rosterUpdate(members: []));
  });

  test('round-trips talk start and stop', () {
    expectRoundTrip(const ControlFrame.talkStart(memberId: 'm3'));
    expectRoundTrip(const ControlFrame.talkStop(memberId: 'm3'));
  });

  test('round-trips the payload-free frames', () {
    expectRoundTrip(const ControlFrame.leave());
    expectRoundTrip(const ControlFrame.ping());
    expectRoundTrip(const ControlFrame.pong());
  });

  test('preserves multi-byte display names', () {
    expectRoundTrip(
      ControlFrame.joinRequest(
        version: 1,
        displayName: 'Grüße 🎧',
        passwordProof: Uint8List(0),
      ),
    );
  });

  test('throws on an empty buffer', () {
    expect(
      () => FrameCodec.decode(Uint8List(0)),
      throwsA(isA<FrameDecodeException>()),
    );
  });

  test('throws on an unknown frame type', () {
    expect(
      () => FrameCodec.decode(Uint8List.fromList([250])),
      throwsA(isA<FrameDecodeException>()),
    );
  });

  test('throws on a truncated frame rather than reading past the end', () {
    final full = FrameCodec.encode(
      const ControlFrame.talkStart(memberId: 'm3'),
    );

    expect(
      () => FrameCodec.decode(full.sublist(0, full.length - 1)),
      throwsA(isA<FrameDecodeException>()),
    );
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/domain/protocol/frame_codec_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:bconnect/domain/protocol/control_frame.dart'`

- [ ] **Step 3: Create the frame union**

Create `lib/domain/protocol/control_frame.dart`:

```dart
import 'dart:typed_data';

import 'package:freezed_annotation/freezed_annotation.dart';

import '../models/member.dart';

part 'control_frame.freezed.dart';

enum JoinRejectReason { wrongPassword, full, incompatibleVersion }

/// Control-plane messages (spec section 5.3).
///
/// Audio frames are deliberately absent: they never cross the Dart boundary
/// (spec section 3.5).
@freezed
sealed class ControlFrame with _$ControlFrame {
  /// Host to client on connect, carrying the nonce for the password proof.
  const factory ControlFrame.challenge({
    required Uint8List nonce,
  }) = ChallengeFrame;

  /// An empty [passwordProof] is sent when joining an open group.
  const factory ControlFrame.joinRequest({
    required int version,
    required String displayName,
    required Uint8List passwordProof,
  }) = JoinRequestFrame;

  const factory ControlFrame.joinAccepted({
    required String memberId,
    required List<Member> roster,
  }) = JoinAcceptedFrame;

  const factory ControlFrame.joinRejected({
    required JoinRejectReason reason,
  }) = JoinRejectedFrame;

  const factory ControlFrame.rosterUpdate({
    required List<Member> members,
  }) = RosterUpdateFrame;

  const factory ControlFrame.talkStart({required String memberId}) =
      TalkStartFrame;

  const factory ControlFrame.talkStop({required String memberId}) =
      TalkStopFrame;

  const factory ControlFrame.leave() = LeaveFrame;
  const factory ControlFrame.ping() = PingFrame;
  const factory ControlFrame.pong() = PongFrame;
}
```

- [ ] **Step 4: Create the codec**

Create `lib/domain/protocol/frame_codec.dart`:

```dart
import 'dart:convert';
import 'dart:typed_data';

import '../models/member.dart';
import 'control_frame.dart';

class FrameDecodeException implements Exception {
  const FrameDecodeException(this.message);

  final String message;

  @override
  String toString() => 'FrameDecodeException: $message';
}

/// Frame type discriminators. Values are part of the wire format and must
/// never be reordered or reused.
abstract final class _FrameType {
  static const int challenge = 1;
  static const int joinRequest = 2;
  static const int joinAccepted = 3;
  static const int joinRejected = 4;
  static const int rosterUpdate = 5;
  static const int talkStart = 6;
  static const int talkStop = 7;
  static const int leave = 8;
  static const int ping = 9;
  static const int pong = 10;
}

class _Writer {
  final BytesBuilder _out = BytesBuilder();

  void uint8(int value) => _out.addByte(value);

  /// Length-prefixed so the reader never has to guess where a field ends.
  void bytes(Uint8List value) {
    uint8(value.length);
    _out.add(value);
  }

  void string(String value) => bytes(Uint8List.fromList(utf8.encode(value)));

  void member(Member m) {
    string(m.id);
    string(m.displayName);
    uint8((m.isHost ? 1 : 0) | (m.isSelf ? 2 : 0) | (m.isTalking ? 4 : 0));
    uint8(m.presence.index);
  }

  void members(List<Member> list) {
    uint8(list.length);
    list.forEach(member);
  }

  Uint8List take() => _out.takeBytes();
}

class _Reader {
  _Reader(this._data);

  final Uint8List _data;
  int _offset = 0;

  int uint8() {
    if (_offset >= _data.length) {
      throw const FrameDecodeException('unexpected end of frame');
    }
    return _data[_offset++];
  }

  Uint8List bytes() {
    final length = uint8();
    if (_offset + length > _data.length) {
      throw const FrameDecodeException('field length exceeds frame');
    }
    final value = Uint8List.fromList(
      _data.sublist(_offset, _offset + length),
    );
    _offset += length;
    return value;
  }

  String string() {
    try {
      return utf8.decode(bytes());
    } on FormatException catch (e) {
      throw FrameDecodeException('invalid UTF-8: ${e.message}');
    }
  }

  Member member() {
    final id = string();
    final displayName = string();
    final flags = uint8();
    final presenceIndex = uint8();

    if (presenceIndex >= MemberPresence.values.length) {
      throw const FrameDecodeException('unknown member presence');
    }

    return Member(
      id: id,
      displayName: displayName,
      isHost: flags & 1 != 0,
      isSelf: flags & 2 != 0,
      isTalking: flags & 4 != 0,
      presence: MemberPresence.values[presenceIndex],
    );
  }

  List<Member> members() =>
      List<Member>.generate(uint8(), (_) => member(), growable: false);
}

abstract final class FrameCodec {
  static Uint8List encode(ControlFrame frame) {
    final w = _Writer();

    switch (frame) {
      case ChallengeFrame(:final nonce):
        w.uint8(_FrameType.challenge);
        w.bytes(nonce);
      case JoinRequestFrame(
          :final version,
          :final displayName,
          :final passwordProof
        ):
        w.uint8(_FrameType.joinRequest);
        w.uint8(version);
        w.string(displayName);
        w.bytes(passwordProof);
      case JoinAcceptedFrame(:final memberId, :final roster):
        w.uint8(_FrameType.joinAccepted);
        w.string(memberId);
        w.members(roster);
      case JoinRejectedFrame(:final reason):
        w.uint8(_FrameType.joinRejected);
        w.uint8(reason.index);
      case RosterUpdateFrame(:final members):
        w.uint8(_FrameType.rosterUpdate);
        w.members(members);
      case TalkStartFrame(:final memberId):
        w.uint8(_FrameType.talkStart);
        w.string(memberId);
      case TalkStopFrame(:final memberId):
        w.uint8(_FrameType.talkStop);
        w.string(memberId);
      case LeaveFrame():
        w.uint8(_FrameType.leave);
      case PingFrame():
        w.uint8(_FrameType.ping);
      case PongFrame():
        w.uint8(_FrameType.pong);
    }

    return w.take();
  }

  static ControlFrame decode(Uint8List data) {
    final r = _Reader(data);

    switch (r.uint8()) {
      case _FrameType.challenge:
        return ControlFrame.challenge(nonce: r.bytes());
      case _FrameType.joinRequest:
        return ControlFrame.joinRequest(
          version: r.uint8(),
          displayName: r.string(),
          passwordProof: r.bytes(),
        );
      case _FrameType.joinAccepted:
        return ControlFrame.joinAccepted(
          memberId: r.string(),
          roster: r.members(),
        );
      case _FrameType.joinRejected:
        final index = r.uint8();
        if (index >= JoinRejectReason.values.length) {
          throw const FrameDecodeException('unknown rejection reason');
        }
        return ControlFrame.joinRejected(
          reason: JoinRejectReason.values[index],
        );
      case _FrameType.rosterUpdate:
        return ControlFrame.rosterUpdate(members: r.members());
      case _FrameType.talkStart:
        return ControlFrame.talkStart(memberId: r.string());
      case _FrameType.talkStop:
        return ControlFrame.talkStop(memberId: r.string());
      case _FrameType.leave:
        return const ControlFrame.leave();
      case _FrameType.ping:
        return const ControlFrame.ping();
      case _FrameType.pong:
        return const ControlFrame.pong();
      case final unknown:
        throw FrameDecodeException('unknown frame type $unknown');
    }
  }
}
```

- [ ] **Step 5: Generate the freezed code**

Run: `dart run build_runner build`
Expected: `wrote 1 output` for `control_frame.freezed.dart`

- [ ] **Step 6: Run test to verify it passes**

Run: `flutter test test/domain/protocol/frame_codec_test.dart`
Expected: PASS (13 tests)

Note: freezed generates `==` using deep collection equality, so the `Uint8List` and `List<Member>` fields compare by value. That is what makes `expectRoundTrip` meaningful.

- [ ] **Step 7: Commit**

```bash
git add lib/domain/protocol test/domain/protocol
git commit -m "feat: add control frames and binary codec"
```

---

### Task 6: Session state and roster reducer

**Files:**
- Create: `lib/domain/models/session_state.dart`
- Create: `lib/domain/session/roster.dart`
- Test: `test/domain/session/roster_test.dart`

**Interfaces:**
- Consumes: `Member`, `MemberPresence`, `DiscoveredGroup` (Task 2); `ProtocolLimits` (Task 3)
- Produces:
  - `enum JoinStep { connecting, authenticating, awaitingRoster }`
  - `enum SessionError { wrongPassword, groupFull, hostLeft, connectionLost, incompatibleVersion, bluetoothOff, permissionDenied, peripheralUnsupported }`
  - Sealed `SessionState` with `idle`, `discovering`, `joining`, `connected`, `failed` and subclasses `SessionIdle`, `SessionDiscovering`, `SessionJoining`, `SessionConnected`, `SessionFailed`
  - `Roster.add`, `Roster.remove`, `Roster.setTalking`, `Roster.setPresence`, `Roster.talkingCount`, `Roster.isFull`, `Roster.canTalk` — all static, all pure

- [ ] **Step 1: Write the failing test**

Create `test/domain/session/roster_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';

import 'package:bconnect/domain/models/member.dart';
import 'package:bconnect/domain/protocol/protocol_limits.dart';
import 'package:bconnect/domain/session/roster.dart';

void main() {
  const host = Member(id: 'm1', displayName: 'You', isHost: true, isSelf: true);
  const one = Member(id: 'm2', displayName: 'Device 1');
  const two = Member(id: 'm3', displayName: 'Device 2');

  group('add', () {
    test('appends a new member', () {
      expect(Roster.add(const [host], one), const [host, one]);
    });

    test('replaces an existing member with the same id', () {
      final result = Roster.add(
        const [host, one],
        const Member(id: 'm2', displayName: 'Renamed'),
      );

      expect(result.length, 2);
      expect(result[1].displayName, 'Renamed');
    });

    test('does not mutate the input list', () {
      const input = [host];
      Roster.add(input, one);

      expect(input, const [host]);
    });
  });

  group('remove', () {
    test('drops the matching member', () {
      expect(Roster.remove(const [host, one], 'm2'), const [host]);
    });

    test('is a no-op for an unknown id', () {
      expect(Roster.remove(const [host], 'nope'), const [host]);
    });
  });

  group('setTalking', () {
    test('marks only the named member', () {
      final result = Roster.setTalking(const [host, one], 'm2', true);

      expect(result[0].isTalking, isFalse);
      expect(result[1].isTalking, isTrue);
    });

    test('clears the flag again', () {
      var result = Roster.setTalking(const [host, one], 'm2', true);
      result = Roster.setTalking(result, 'm2', false);

      expect(result[1].isTalking, isFalse);
    });
  });

  group('setPresence', () {
    test('updates only the named member', () {
      final result =
          Roster.setPresence(const [host, one], 'm2', MemberPresence.reconnecting);

      expect(result[0].presence, MemberPresence.online);
      expect(result[1].presence, MemberPresence.reconnecting);
    });
  });

  group('talkingCount', () {
    test('counts members currently talking', () {
      var r = Roster.setTalking(const [host, one, two], 'm2', true);
      r = Roster.setTalking(r, 'm3', true);

      expect(Roster.talkingCount(r), 2);
    });
  });

  group('isFull', () {
    test('is false below the maximum', () {
      final r = List.generate(
        ProtocolLimits.maxMembers - 1,
        (i) => Member(id: '$i', displayName: 'D$i'),
      );

      expect(Roster.isFull(r), isFalse);
    });

    test('is true at the maximum', () {
      final r = List.generate(
        ProtocolLimits.maxMembers,
        (i) => Member(id: '$i', displayName: 'D$i'),
      );

      expect(Roster.isFull(r), isTrue);
    });
  });

  group('canTalk', () {
    test('allows a talker below the concurrent cap', () {
      final r = List.generate(
        ProtocolLimits.maxMembers,
        (i) => Member(id: '$i', displayName: 'D$i'),
      );
      var withTalkers = Roster.setTalking(r, '0', true);
      withTalkers = Roster.setTalking(withTalkers, '1', true);

      expect(Roster.canTalk(withTalkers, '2'), isTrue);
    });

    test('refuses a talker once the concurrent cap is reached', () {
      final r = List.generate(
        ProtocolLimits.maxMembers,
        (i) => Member(id: '$i', displayName: 'D$i'),
      );
      var withTalkers = r;
      for (var i = 0; i < ProtocolLimits.maxConcurrentTalkers; i++) {
        withTalkers = Roster.setTalking(withTalkers, '$i', true);
      }

      expect(Roster.canTalk(withTalkers, '7'), isFalse);
    });

    test('always allows a member who is already talking', () {
      final r = List.generate(
        ProtocolLimits.maxMembers,
        (i) => Member(id: '$i', displayName: 'D$i'),
      );
      var withTalkers = r;
      for (var i = 0; i < ProtocolLimits.maxConcurrentTalkers; i++) {
        withTalkers = Roster.setTalking(withTalkers, '$i', true);
      }

      expect(Roster.canTalk(withTalkers, '0'), isTrue);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/domain/session/roster_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:bconnect/domain/session/roster.dart'`

- [ ] **Step 3: Create the session state union**

Create `lib/domain/models/session_state.dart`:

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

import 'discovered_group.dart';
import 'member.dart';

part 'session_state.freezed.dart';

enum JoinStep { connecting, authenticating, awaitingRoster }

enum SessionError {
  wrongPassword,
  groupFull,
  hostLeft,
  connectionLost,
  incompatibleVersion,
  bluetoothOff,
  permissionDenied,
  peripheralUnsupported,
}

@freezed
sealed class SessionState with _$SessionState {
  const factory SessionState.idle() = SessionIdle;

  const factory SessionState.discovering() = SessionDiscovering;

  const factory SessionState.joining({
    required DiscoveredGroup group,
    required JoinStep step,
  }) = SessionJoining;

  const factory SessionState.connected({
    required String groupId,
    required String groupName,
    required String myMemberId,
    required bool isHost,
    required List<Member> roster,
  }) = SessionConnected;

  const factory SessionState.failed({required SessionError error}) =
      SessionFailed;
}
```

- [ ] **Step 4: Create the roster reducer**

Create `lib/domain/session/roster.dart`:

```dart
import '../models/member.dart';
import '../protocol/protocol_limits.dart';

/// Pure roster transformations. Every method returns a new list; none mutate
/// their input, so these are safe to call directly from a Notifier.
abstract final class Roster {
  /// Appends [member], or replaces an existing entry with the same id.
  static List<Member> add(List<Member> current, Member member) {
    final index = current.indexWhere((m) => m.id == member.id);
    final next = List<Member>.of(current);

    if (index == -1) {
      next.add(member);
    } else {
      next[index] = member;
    }
    return List.unmodifiable(next);
  }

  static List<Member> remove(List<Member> current, String memberId) =>
      List.unmodifiable(current.where((m) => m.id != memberId));

  static List<Member> setTalking(
    List<Member> current,
    String memberId,
    bool talking,
  ) =>
      _update(current, memberId, (m) => m.copyWith(isTalking: talking));

  static List<Member> setPresence(
    List<Member> current,
    String memberId,
    MemberPresence presence,
  ) =>
      _update(current, memberId, (m) => m.copyWith(presence: presence));

  static int talkingCount(List<Member> current) =>
      current.where((m) => m.isTalking).length;

  static bool isFull(List<Member> current) =>
      current.length >= ProtocolLimits.maxMembers;

  /// Whether [memberId] may start transmitting (spec section 5.4). A member
  /// already holding the floor is always allowed, so re-asserting talk does
  /// not fail at the cap.
  static bool canTalk(List<Member> current, String memberId) {
    final already =
        current.any((m) => m.id == memberId && m.isTalking);
    if (already) return true;

    return talkingCount(current) < ProtocolLimits.maxConcurrentTalkers;
  }

  static List<Member> _update(
    List<Member> current,
    String memberId,
    Member Function(Member) transform,
  ) =>
      List.unmodifiable([
        for (final m in current) m.id == memberId ? transform(m) : m,
      ]);
}
```

- [ ] **Step 5: Generate the freezed code**

Run: `dart run build_runner build`
Expected: `wrote 1 output` for `session_state.freezed.dart`

- [ ] **Step 6: Run test to verify it passes**

Run: `flutter test test/domain/session/roster_test.dart`
Expected: PASS (14 tests)

- [ ] **Step 7: Commit**

```bash
git add lib/domain test/domain/session
git commit -m "feat: add session state union and roster reducer"
```

---

### Task 7: Transport interface and in-memory fake

**Files:**
- Create: `lib/transport/group_transport.dart`
- Create: `lib/transport/fake/fake_hub.dart`
- Create: `lib/transport/fake/fake_transport.dart`
- Test: `test/transport/fake_transport_test.dart`

**Interfaces:**
- Consumes: `DiscoveredGroup` (Task 2), `AudioRoute` (Task 2), `ProtocolLimits` (Task 3)
- Produces:
  - Sealed `TransportEvent` with `ScanResultEvent(group)`, `PeerConnectedEvent(peerId)`, `PeerDisconnectedEvent(peerId)`, `ControlMessageEvent(peerId, bytes)`, `TransportErrorEvent(message)`
  - `abstract interface class GroupTransport` — the methods listed below
  - `FakeHub({DateTime Function()? clock})` with `void reset()`
  - `FakeTransport(FakeHub hub, {String? deviceId})`

**Connection identity.** A connection has one id, shared by both ends. When a
client connects to a host, both sides receive `PeerConnectedEvent` carrying the
same `peerId`, and `sendControl(peerId, …)` delivers to the opposite end. This
keeps host and client code symmetric.

**Plan B note.** Plan B adds an `AudioLevelEvent` to the `TransportEvent` union
for the level meters. It must not add any audio *frame* event — audio bytes
never cross the Dart boundary (spec §3.5).

- [ ] **Step 1: Write the failing test**

Create `test/transport/fake_transport_test.dart`:

```dart
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
    expect(
      () => client.connect('nobody'),
      throwsA(isA<TransportException>()),
    );
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/transport/fake_transport_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:bconnect/transport/fake/fake_hub.dart'`

- [ ] **Step 3: Create the transport interface**

Create `lib/transport/group_transport.dart`:

```dart
import 'dart:typed_data';

import '../domain/models/audio.dart';
import '../domain/models/discovered_group.dart';

class TransportException implements Exception {
  const TransportException(this.message);

  final String message;

  @override
  String toString() => 'TransportException: $message';
}

/// Events raised by a transport.
///
/// Plan B adds an audio *level* event for the meters. It must never carry
/// audio frames: those stay entirely inside the platform layer
/// (spec section 3.5).
sealed class TransportEvent {
  const TransportEvent();
}

final class ScanResultEvent extends TransportEvent {
  const ScanResultEvent(this.group);

  final DiscoveredGroup group;
}

final class PeerConnectedEvent extends TransportEvent {
  const PeerConnectedEvent(this.peerId);

  final String peerId;
}

final class PeerDisconnectedEvent extends TransportEvent {
  const PeerDisconnectedEvent(this.peerId);

  final String peerId;
}

final class ControlMessageEvent extends TransportEvent {
  const ControlMessageEvent(this.peerId, this.bytes);

  final String peerId;
  final Uint8List bytes;
}

final class TransportErrorEvent extends TransportEvent {
  const TransportErrorEvent(this.message);

  final String message;
}

/// The seam between the session layer and the radio (spec section 4).
///
/// A connection has a single id shared by both ends, so host and client code
/// stay symmetric.
abstract interface class GroupTransport {
  Stream<TransportEvent> get events;

  /// False on devices whose Bluetooth stack cannot act as a peripheral, which
  /// disables hosting but not joining (spec section 8).
  Future<bool> isPeripheralSupported();

  Future<void> startAdvertising({
    required String groupName,
    required int groupId,
    required int memberCount,
    required bool isLocked,
    required bool isFull,
  });

  /// Re-advertises with a changed member count or full flag.
  Future<void> updateAdvertisement({
    required int memberCount,
    required bool isFull,
  });

  Future<void> stopAdvertising();

  Future<void> startScan();
  Future<void> stopScan();

  /// Returns the id of the new connection.
  Future<String> connect(String deviceId);

  Future<void> disconnect(String peerId);

  Future<void> sendControl(String peerId, Uint8List bytes);

  Future<void> setMicEnabled(bool enabled);
  Future<void> setAudioRoute(AudioRoute route);
  Future<void> startTalking();
  Future<void> stopTalking();

  Future<void> dispose();
}
```

- [ ] **Step 4: Create the hub**

Create `lib/transport/fake/fake_hub.dart`:

```dart
import 'dart:typed_data';

import '../../domain/models/discovered_group.dart';
import '../../domain/protocol/advert_payload.dart';
import '../group_transport.dart';
import 'fake_transport.dart';

class _Advert {
  const _Advert(this.name, this.payload);

  final String name;
  final AdvertPayload payload;
}

class _Connection {
  const _Connection(this.id, this.a, this.b);

  final String id;
  final FakeTransport a;
  final FakeTransport b;

  FakeTransport other(FakeTransport self) => identical(self, a) ? b : a;

  bool involves(FakeTransport t) => identical(t, a) || identical(t, b);
}

/// In-memory broker standing in for the BLE radio.
///
/// Every peer in a test shares one hub. Because it is an object rather than a
/// singleton, tests are isolated from each other.
class FakeHub {
  FakeHub({DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;

  final Map<String, FakeTransport> _peers = {};
  final Map<String, _Advert> _adverts = {};
  final List<_Connection> _connections = [];

  int _nextConnectionId = 0;

  void register(FakeTransport peer) => _peers[peer.deviceId] = peer;

  void unregister(FakeTransport peer) {
    _adverts.remove(peer.deviceId);
    _peers.remove(peer.deviceId);

    for (final c in _connections.where((c) => c.involves(peer)).toList()) {
      _closeConnection(c);
    }
  }

  void advertise(String deviceId, String name, AdvertPayload payload) {
    _adverts[deviceId] = _Advert(name, payload);
    _broadcastScanResult(deviceId);
  }

  void stopAdvertising(String deviceId) => _adverts.remove(deviceId);

  /// Delivers the current adverts to a peer that has just started scanning.
  void deliverCurrentAdverts(FakeTransport scanner) {
    for (final deviceId in _adverts.keys) {
      if (deviceId == scanner.deviceId) continue;
      scanner.emit(ScanResultEvent(_toGroup(deviceId)));
    }
  }

  void _broadcastScanResult(String deviceId) {
    for (final peer in _peers.values) {
      if (peer.deviceId == deviceId || !peer.isScanning) continue;
      peer.emit(ScanResultEvent(_toGroup(deviceId)));
    }
  }

  DiscoveredGroup _toGroup(String deviceId) {
    final advert = _adverts[deviceId]!;

    return DiscoveredGroup(
      groupId: advert.payload.groupIdHex,
      deviceId: deviceId,
      name: advert.name,
      memberCount: advert.payload.memberCount,
      isLocked: advert.payload.isLocked,
      isFull: advert.payload.isFull,
      rssi: -55,
      lastSeen: _clock(),
    );
  }

  String connect(FakeTransport client, String hostDeviceId) {
    final host = _peers[hostDeviceId];
    if (host == null) {
      throw TransportException('no device with id $hostDeviceId');
    }

    final id = 'conn${_nextConnectionId++}';
    _connections.add(_Connection(id, client, host));

    client.emit(PeerConnectedEvent(id));
    host.emit(PeerConnectedEvent(id));

    return id;
  }

  void send(FakeTransport from, String peerId, Uint8List bytes) {
    final connection = _find(peerId, from);
    connection.other(from).emit(ControlMessageEvent(peerId, bytes));
  }

  void disconnect(FakeTransport from, String peerId) =>
      _closeConnection(_find(peerId, from));

  _Connection _find(String peerId, FakeTransport from) {
    for (final c in _connections) {
      if (c.id == peerId && c.involves(from)) return c;
    }
    throw TransportException('no connection $peerId on ${from.deviceId}');
  }

  void _closeConnection(_Connection c) {
    _connections.remove(c);
    c.a.emit(PeerDisconnectedEvent(c.id));
    c.b.emit(PeerDisconnectedEvent(c.id));
  }

  void reset() {
    _peers.clear();
    _adverts.clear();
    _connections.clear();
    _nextConnectionId = 0;
  }
}
```

- [ ] **Step 5: Create the fake transport**

Create `lib/transport/fake/fake_transport.dart`:

```dart
import 'dart:async';
import 'dart:typed_data';

import '../../domain/models/audio.dart';
import '../../domain/protocol/advert_payload.dart';
import '../group_transport.dart';
import 'fake_hub.dart';

/// A [GroupTransport] backed by [FakeHub] instead of a radio.
///
/// The audio methods record their arguments rather than producing sound, so
/// tests can assert on mic and routing behaviour without a device.
class FakeTransport implements GroupTransport {
  FakeTransport(this._hub, {String? deviceId})
      : deviceId = deviceId ?? 'device${_counter++}' {
    _hub.register(this);
  }

  static int _counter = 0;

  final FakeHub _hub;
  final String deviceId;

  final StreamController<TransportEvent> _events =
      StreamController<TransportEvent>.broadcast();

  bool isScanning = false;
  bool micEnabled = true;
  bool isTalking = false;
  AudioRoute audioRoute = AudioRoute.speaker;

  String? _advertisedName;
  AdvertPayload? _advertisedPayload;

  /// Visible to [FakeHub]; not part of [GroupTransport].
  void emit(TransportEvent event) {
    if (!_events.isClosed) _events.add(event);
  }

  @override
  Stream<TransportEvent> get events => _events.stream;

  @override
  Future<bool> isPeripheralSupported() async => true;

  @override
  Future<void> startAdvertising({
    required String groupName,
    required int groupId,
    required int memberCount,
    required bool isLocked,
    required bool isFull,
  }) async {
    // Validates the name against the scan-response budget, exactly as the
    // real transport will (spec section 5.1).
    AdvertPayload.encodeName(groupName);

    _advertisedName = groupName;
    _advertisedPayload = AdvertPayload(
      groupId: groupId,
      memberCount: memberCount,
      isLocked: isLocked,
      isFull: isFull,
    );

    _hub.advertise(deviceId, groupName, _advertisedPayload!);
  }

  @override
  Future<void> updateAdvertisement({
    required int memberCount,
    required bool isFull,
  }) async {
    final current = _advertisedPayload;
    if (current == null) {
      throw const TransportException('not advertising');
    }

    _advertisedPayload = AdvertPayload(
      groupId: current.groupId,
      memberCount: memberCount,
      isLocked: current.isLocked,
      isFull: isFull,
    );

    _hub.advertise(deviceId, _advertisedName!, _advertisedPayload!);
  }

  @override
  Future<void> stopAdvertising() async {
    _advertisedName = null;
    _advertisedPayload = null;
    _hub.stopAdvertising(deviceId);
  }

  @override
  Future<void> startScan() async {
    isScanning = true;
    _hub.deliverCurrentAdverts(this);
  }

  @override
  Future<void> stopScan() async => isScanning = false;

  @override
  Future<String> connect(String deviceId) async => _hub.connect(this, deviceId);

  @override
  Future<void> disconnect(String peerId) async => _hub.disconnect(this, peerId);

  @override
  Future<void> sendControl(String peerId, Uint8List bytes) async =>
      _hub.send(this, peerId, bytes);

  @override
  Future<void> setMicEnabled(bool enabled) async => micEnabled = enabled;

  @override
  Future<void> setAudioRoute(AudioRoute route) async => audioRoute = route;

  @override
  Future<void> startTalking() async => isTalking = true;

  @override
  Future<void> stopTalking() async => isTalking = false;

  @override
  Future<void> dispose() async {
    _hub.unregister(this);
    await _events.close();
  }
}
```

- [ ] **Step 6: Run test to verify it passes**

Run: `flutter test test/transport/fake_transport_test.dart`
Expected: PASS (14 tests)

- [ ] **Step 7: Verify analysis is clean**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 8: Commit**

```bash
git add lib/transport test/transport
git commit -m "feat: add transport interface and in-memory fake"
```

---

### Task 8: Host session

**Files:**
- Create: `lib/domain/session/host_session.dart`
- Test: `test/session/host_session_test.dart`

**Interfaces:**
- Consumes: `GroupTransport`, `TransportEvent` subclasses, `TransportException` (Task 7); `ControlFrame` subclasses, `JoinRejectReason`, `FrameCodec` (Task 5); `Roster` (Task 6); `SessionState` subclasses, `SessionError` (Task 6); `PasswordProof` (Task 4); `GroupConfig`, `Member` (Task 2)
- Produces:
  - `HostSession({required GroupTransport transport, required GroupConfig config, required String hostDisplayName, Random? random})`
  - `Stream<SessionState> get states`, `SessionState get state`, `int get groupId`
  - `Future<void> start()`, `Future<void> stop()`, `Future<bool> requestTalk()`, `Future<void> stopTalk()`, `Future<void> dispose()`
  - `static const String hostMemberId = 'm1'`

The host assigns member ids: itself `m1`, then `m2`, `m3`, … in join order.

- [ ] **Step 1: Write the failing test**

Create `test/session/host_session_test.dart`:

```dart
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:bconnect/domain/models/group_config.dart';
import 'package:bconnect/domain/models/session_state.dart';
import 'package:bconnect/domain/protocol/control_frame.dart';
import 'package:bconnect/domain/protocol/frame_codec.dart';
import 'package:bconnect/domain/protocol/password_proof.dart';
import 'package:bconnect/domain/protocol/protocol_limits.dart';
import 'package:bconnect/domain/session/host_session.dart';
import 'package:bconnect/transport/fake/fake_hub.dart';
import 'package:bconnect/transport/fake/fake_transport.dart';
import 'package:bconnect/transport/group_transport.dart';

void main() {
  late FakeHub hub;
  late FakeTransport hostTransport;
  late FakeTransport clientTransport;
  late HostSession session;

  setUp(() {
    hub = FakeHub();
    hostTransport = FakeTransport(hub, deviceId: 'host');
    clientTransport = FakeTransport(hub, deviceId: 'client');
  });

  tearDown(() async {
    await session.dispose();
    await hostTransport.dispose();
    await clientTransport.dispose();
  });

  HostSession build({String? password}) => session = HostSession(
        transport: hostTransport,
        config: GroupConfig(name: 'Team Alpha', password: password),
        hostDisplayName: 'You',
        random: Random(7),
      );

  /// Reads control frames arriving at the client.
  Stream<ControlFrame> clientFrames() => clientTransport.events
      .whereType<ControlMessageEvent>()
      .map((e) => FrameCodec.decode(e.bytes));

  Future<void> sendToHost(String peerId, ControlFrame frame) =>
      clientTransport.sendControl(peerId, FrameCodec.encode(frame));

  group('start', () {
    test('enters connected with only the host in the roster', () async {
      await build().start();

      final state = session.state as SessionConnected;

      expect(state.groupName, 'Team Alpha');
      expect(state.isHost, isTrue);
      expect(state.myMemberId, HostSession.hostMemberId);
      expect(state.roster.length, 1);
      expect(state.roster.single.isHost, isTrue);
      expect(state.roster.single.isSelf, isTrue);
      expect(state.roster.single.displayName, 'You');
    });

    test('advertises the group so a scanner can find it', () async {
      await build(password: 'hunter2').start();

      final found = clientTransport.events.whereType<ScanResultEvent>().first;
      await clientTransport.startScan();

      final group = (await found).group;

      expect(group.name, 'Team Alpha');
      expect(group.isLocked, isTrue);
      expect(group.memberCount, 1);
    });
  });

  group('join handshake', () {
    test('challenges a peer as soon as it connects', () async {
      await build().start();

      final challenge = clientFrames().first;
      await clientTransport.connect('host');

      expect(await challenge, isA<ChallengeFrame>());
      expect(
        ((await challenge) as ChallengeFrame).nonce.length,
        ProtocolLimits.nonceLength,
      );
    });

    test('accepts a join into an open group with an empty proof', () async {
      await build().start();

      final frames = clientFrames();
      final peerId = await clientTransport.connect('host');

      await frames.first; // challenge
      final accepted = frames.whereType<JoinAcceptedFrame>().first;

      await sendToHost(
        peerId,
        ControlFrame.joinRequest(
          version: ProtocolLimits.protocolVersion,
          displayName: 'Device 1',
          passwordProof: Uint8List(0),
        ),
      );

      final frame = await accepted;

      expect(frame.memberId, 'm2');
      expect(frame.roster.length, 2);
      expect((session.state as SessionConnected).roster.length, 2);
    });

    test('accepts a correct password proof', () async {
      await build(password: 'hunter2').start();

      final frames = clientFrames();
      final peerId = await clientTransport.connect('host');

      final challenge = (await frames.first) as ChallengeFrame;
      final accepted = frames.whereType<JoinAcceptedFrame>().first;

      await sendToHost(
        peerId,
        ControlFrame.joinRequest(
          version: ProtocolLimits.protocolVersion,
          displayName: 'Device 1',
          passwordProof: PasswordProof.compute(
            password: 'hunter2',
            nonce: challenge.nonce,
          ),
        ),
      );

      expect((await accepted).memberId, 'm2');
    });

    test('rejects an incorrect password proof', () async {
      await build(password: 'hunter2').start();

      final frames = clientFrames();
      final peerId = await clientTransport.connect('host');

      final challenge = (await frames.first) as ChallengeFrame;
      final rejected = frames.whereType<JoinRejectedFrame>().first;

      await sendToHost(
        peerId,
        ControlFrame.joinRequest(
          version: ProtocolLimits.protocolVersion,
          displayName: 'Device 1',
          passwordProof: PasswordProof.compute(
            password: 'wrong',
            nonce: challenge.nonce,
          ),
        ),
      );

      expect((await rejected).reason, JoinRejectReason.wrongPassword);
      expect((session.state as SessionConnected).roster.length, 1);
    });

    test('rejects a mismatched protocol version', () async {
      await build().start();

      final frames = clientFrames();
      final peerId = await clientTransport.connect('host');

      await frames.first;
      final rejected = frames.whereType<JoinRejectedFrame>().first;

      await sendToHost(
        peerId,
        ControlFrame.joinRequest(
          version: ProtocolLimits.protocolVersion + 1,
          displayName: 'Device 1',
          passwordProof: Uint8List(0),
        ),
      );

      expect((await rejected).reason, JoinRejectReason.incompatibleVersion);
    });

    test('rejects a join once the group is full', () async {
      await build().start();

      // Fill every remaining slot.
      final extras = <FakeTransport>[];
      for (var i = 0; i < ProtocolLimits.maxMembers - 1; i++) {
        final t = FakeTransport(hub, deviceId: 'extra$i');
        extras.add(t);
        final frames =
            t.events.whereType<ControlMessageEvent>().map((e) => FrameCodec.decode(e.bytes));
        final accepted = frames.whereType<JoinAcceptedFrame>().first;
        final peerId = await t.connect('host');
        await t.sendControl(
          peerId,
          FrameCodec.encode(ControlFrame.joinRequest(
            version: ProtocolLimits.protocolVersion,
            displayName: 'Extra $i',
            passwordProof: Uint8List(0),
          )),
        );
        await accepted;
      }
      addTearDown(() async {
        for (final t in extras) {
          await t.dispose();
        }
      });

      expect((session.state as SessionConnected).roster.length,
          ProtocolLimits.maxMembers);

      final frames = clientFrames();
      final peerId = await clientTransport.connect('host');
      await frames.first;
      final rejected = frames.whereType<JoinRejectedFrame>().first;

      await sendToHost(
        peerId,
        ControlFrame.joinRequest(
          version: ProtocolLimits.protocolVersion,
          displayName: 'One Too Many',
          passwordProof: Uint8List(0),
        ),
      );

      expect((await rejected).reason, JoinRejectReason.full);
    });
  });

  group('membership changes', () {
    Future<String> joinClient() async {
      final frames = clientFrames();
      final peerId = await clientTransport.connect('host');
      await frames.first;
      final accepted = frames.whereType<JoinAcceptedFrame>().first;
      await sendToHost(
        peerId,
        ControlFrame.joinRequest(
          version: ProtocolLimits.protocolVersion,
          displayName: 'Device 1',
          passwordProof: Uint8List(0),
        ),
      );
      await accepted;
      return peerId;
    }

    test('removes a member that sends leave', () async {
      await build().start();
      final peerId = await joinClient();

      await sendToHost(peerId, const ControlFrame.leave());
      await Future<void>.delayed(Duration.zero);

      expect((session.state as SessionConnected).roster.length, 1);
    });

    test('removes a member that disconnects', () async {
      await build().start();
      final peerId = await joinClient();

      await clientTransport.disconnect(peerId);
      await Future<void>.delayed(Duration.zero);

      expect((session.state as SessionConnected).roster.length, 1);
    });

    test('marks a member talking and clears it again', () async {
      await build().start();
      final peerId = await joinClient();

      await sendToHost(peerId, const ControlFrame.talkStart(memberId: 'm2'));
      await Future<void>.delayed(Duration.zero);
      expect(
        (session.state as SessionConnected)
            .roster
            .firstWhere((m) => m.id == 'm2')
            .isTalking,
        isTrue,
      );

      await sendToHost(peerId, const ControlFrame.talkStop(memberId: 'm2'));
      await Future<void>.delayed(Duration.zero);
      expect(
        (session.state as SessionConnected)
            .roster
            .firstWhere((m) => m.id == 'm2')
            .isTalking,
        isFalse,
      );
    });

    test('answers a ping with a pong', () async {
      await build().start();
      final peerId = await joinClient();

      final pong = clientFrames().whereType<PongFrame>().first;
      await sendToHost(peerId, const ControlFrame.ping());

      expect(await pong, isA<PongFrame>());
    });
  });

  group('talk control', () {
    test('grants the floor below the concurrent cap', () async {
      await build().start();

      expect(await session.requestTalk(), isTrue);
      expect(hostTransport.isTalking, isTrue);
    });

    test('refuses the floor once the cap is reached', () async {
      await build().start();

      // Occupy every slot with other members.
      final extras = <FakeTransport>[];
      for (var i = 0; i < ProtocolLimits.maxConcurrentTalkers; i++) {
        final t = FakeTransport(hub, deviceId: 'talker$i');
        extras.add(t);
        final frames =
            t.events.whereType<ControlMessageEvent>().map((e) => FrameCodec.decode(e.bytes));
        final accepted = frames.whereType<JoinAcceptedFrame>().first;
        final peerId = await t.connect('host');
        await t.sendControl(
          peerId,
          FrameCodec.encode(ControlFrame.joinRequest(
            version: ProtocolLimits.protocolVersion,
            displayName: 'Talker $i',
            passwordProof: Uint8List(0),
          )),
        );
        final memberId = (await accepted).memberId;
        await t.sendControl(
          peerId,
          FrameCodec.encode(ControlFrame.talkStart(memberId: memberId)),
        );
      }
      addTearDown(() async {
        for (final t in extras) {
          await t.dispose();
        }
      });
      await Future<void>.delayed(Duration.zero);

      expect(await session.requestTalk(), isFalse);
      expect(hostTransport.isTalking, isFalse);
    });

    test('stopTalk clears the talking flag', () async {
      await build().start();
      await session.requestTalk();

      await session.stopTalk();

      expect(hostTransport.isTalking, isFalse);
      expect(
        (session.state as SessionConnected)
            .roster
            .firstWhere((m) => m.id == HostSession.hostMemberId)
            .isTalking,
        isFalse,
      );
    });
  });

  group('stop', () {
    test('tells members the group ended and returns to idle', () async {
      await build().start();

      final frames = clientFrames();
      final peerId = await clientTransport.connect('host');
      await frames.first;
      final accepted = frames.whereType<JoinAcceptedFrame>().first;
      await sendToHost(
        peerId,
        ControlFrame.joinRequest(
          version: ProtocolLimits.protocolVersion,
          displayName: 'Device 1',
          passwordProof: Uint8List(0),
        ),
      );
      await accepted;

      final leave = frames.whereType<LeaveFrame>().first;
      await session.stop();

      expect(await leave, isA<LeaveFrame>());
      expect(session.state, isA<SessionIdle>());
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/session/host_session_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:bconnect/domain/session/host_session.dart'`

- [ ] **Step 3: Write the implementation**

Create `lib/domain/session/host_session.dart`:

```dart
import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import '../../transport/group_transport.dart';
import '../models/group_config.dart';
import '../models/member.dart';
import '../models/session_state.dart';
import '../protocol/control_frame.dart';
import '../protocol/frame_codec.dart';
import '../protocol/password_proof.dart';
import '../protocol/protocol_limits.dart';
import 'roster.dart';

/// Host-role state machine (spec section 5.3).
///
/// Owns the roster, verifies join requests, and relays talk state. It never
/// touches audio bytes: the transport handles those natively.
class HostSession {
  HostSession({
    required GroupTransport transport,
    required GroupConfig config,
    required String hostDisplayName,
    Random? random,
  })  : _transport = transport,
        _config = config,
        _hostDisplayName = hostDisplayName,
        _random = random ?? Random.secure();

  static const String hostMemberId = 'm1';

  final GroupTransport _transport;
  final GroupConfig _config;
  final String _hostDisplayName;
  final Random _random;

  final StreamController<SessionState> _states =
      StreamController<SessionState>.broadcast();

  /// Nonce issued to each connected peer, pending its join request.
  final Map<String, Uint8List> _challenges = {};

  /// Member id for each peer that has completed the handshake.
  final Map<String, String> _memberIdByPeer = {};

  StreamSubscription<TransportEvent>? _subscription;

  SessionState _state = const SessionState.idle();
  int _groupId = 0;
  int _nextMemberNumber = 2;

  SessionState get state => _state;
  Stream<SessionState> get states => _states.stream;
  int get groupId => _groupId;

  Future<void> start() async {
    _groupId = _random.nextInt(0x10000);
    _subscription = _transport.events.listen(_onEvent);

    _setState(
      SessionState.connected(
        groupId: _groupId.toRadixString(16).padLeft(4, '0'),
        groupName: _config.name,
        myMemberId: hostMemberId,
        isHost: true,
        roster: [
          Member(
            id: hostMemberId,
            displayName: _hostDisplayName,
            isHost: true,
            isSelf: true,
          ),
        ],
      ),
    );

    await _transport.startAdvertising(
      groupName: _config.name,
      groupId: _groupId,
      memberCount: 1,
      isLocked: _config.isLocked,
      isFull: false,
    );
  }

  Future<void> stop() async {
    for (final peerId in _memberIdByPeer.keys.toList()) {
      await _send(peerId, const ControlFrame.leave());
      await _transport.disconnect(peerId);
    }

    _memberIdByPeer.clear();
    _challenges.clear();

    await _transport.stopTalking();
    await _transport.stopAdvertising();

    _setState(const SessionState.idle());
  }

  /// Returns false when the concurrent-talker cap is already reached
  /// (spec section 5.4).
  Future<bool> requestTalk() async {
    final current = _state;
    if (current is! SessionConnected) return false;
    if (!Roster.canTalk(current.roster, hostMemberId)) return false;

    _setRosterTalking(hostMemberId, true);
    await _transport.startTalking();
    await _broadcast(const ControlFrame.talkStart(memberId: hostMemberId));

    return true;
  }

  Future<void> stopTalk() async {
    _setRosterTalking(hostMemberId, false);
    await _transport.stopTalking();
    await _broadcast(const ControlFrame.talkStop(memberId: hostMemberId));
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    await _states.close();
  }

  void _onEvent(TransportEvent event) {
    switch (event) {
      case PeerConnectedEvent(:final peerId):
        _challenge(peerId);
      case PeerDisconnectedEvent(:final peerId):
        _removePeer(peerId);
      case ControlMessageEvent(:final peerId, :final bytes):
        _onControl(peerId, bytes);
      case ScanResultEvent():
      case TransportErrorEvent():
        break;
    }
  }

  Future<void> _challenge(String peerId) async {
    final nonce = PasswordProof.generateNonce(_random);
    _challenges[peerId] = nonce;
    await _send(peerId, ControlFrame.challenge(nonce: nonce));
  }

  Future<void> _onControl(String peerId, Uint8List bytes) async {
    final ControlFrame frame;
    try {
      frame = FrameCodec.decode(bytes);
    } on FrameDecodeException {
      return; // Ignore malformed traffic rather than tearing down the group.
    }

    switch (frame) {
      case JoinRequestFrame(:final version, :final displayName, :final passwordProof):
        await _onJoinRequest(peerId, version, displayName, passwordProof);
      case TalkStartFrame(:final memberId):
        await _onRemoteTalk(peerId, memberId, true);
      case TalkStopFrame(:final memberId):
        await _onRemoteTalk(peerId, memberId, false);
      case LeaveFrame():
        _removePeer(peerId);
        await _transport.disconnect(peerId);
      case PingFrame():
        await _send(peerId, const ControlFrame.pong());
      case ChallengeFrame():
      case JoinAcceptedFrame():
      case JoinRejectedFrame():
      case RosterUpdateFrame():
      case PongFrame():
        break; // Host-bound peers never send these.
    }
  }

  Future<void> _onJoinRequest(
    String peerId,
    int version,
    String displayName,
    Uint8List proof,
  ) async {
    final current = _state;
    if (current is! SessionConnected) return;

    Future<void> reject(JoinRejectReason reason) async {
      await _send(peerId, ControlFrame.joinRejected(reason: reason));
      await _transport.disconnect(peerId);
      _challenges.remove(peerId);
    }

    if (version != ProtocolLimits.protocolVersion) {
      return reject(JoinRejectReason.incompatibleVersion);
    }

    if (Roster.isFull(current.roster)) {
      return reject(JoinRejectReason.full);
    }

    if (_config.isLocked) {
      final nonce = _challenges[peerId];
      if (nonce == null ||
          !PasswordProof.verify(
            password: _config.password!,
            nonce: nonce,
            proof: proof,
          )) {
        return reject(JoinRejectReason.wrongPassword);
      }
    }

    final memberId = 'm${_nextMemberNumber++}';
    _memberIdByPeer[peerId] = memberId;
    _challenges.remove(peerId);

    final roster = Roster.add(
      current.roster,
      Member(id: memberId, displayName: displayName),
    );
    _setState(current.copyWith(roster: roster));

    await _send(
      peerId,
      ControlFrame.joinAccepted(memberId: memberId, roster: roster),
    );
    await _broadcast(
      ControlFrame.rosterUpdate(members: roster),
      except: peerId,
    );
    await _updateAdvertisement(roster);
  }

  Future<void> _onRemoteTalk(
    String peerId,
    String memberId,
    bool talking,
  ) async {
    // A member may only change its own talk state.
    if (_memberIdByPeer[peerId] != memberId) return;

    final current = _state;
    if (current is! SessionConnected) return;

    if (talking && !Roster.canTalk(current.roster, memberId)) {
      // Floor busy: tell the requester to stand down (spec section 5.4).
      await _send(peerId, ControlFrame.talkStop(memberId: memberId));
      return;
    }

    _setRosterTalking(memberId, talking);
    await _broadcast(
      talking
          ? ControlFrame.talkStart(memberId: memberId)
          : ControlFrame.talkStop(memberId: memberId),
      except: peerId,
    );
  }

  void _removePeer(String peerId) {
    final memberId = _memberIdByPeer.remove(peerId);
    _challenges.remove(peerId);
    if (memberId == null) return;

    final current = _state;
    if (current is! SessionConnected) return;

    final roster = Roster.remove(current.roster, memberId);
    _setState(current.copyWith(roster: roster));

    unawaited(_broadcast(ControlFrame.rosterUpdate(members: roster)));
    unawaited(_updateAdvertisement(roster));
  }

  void _setRosterTalking(String memberId, bool talking) {
    final current = _state;
    if (current is! SessionConnected) return;

    _setState(
      current.copyWith(
        roster: Roster.setTalking(current.roster, memberId, talking),
      ),
    );
  }

  Future<void> _updateAdvertisement(List<Member> roster) =>
      _transport.updateAdvertisement(
        memberCount: roster.length,
        isFull: Roster.isFull(roster),
      );

  Future<void> _send(String peerId, ControlFrame frame) async {
    try {
      await _transport.sendControl(peerId, FrameCodec.encode(frame));
    } on TransportException {
      // The peer vanished mid-send; _removePeer handles the disconnect event.
    }
  }

  Future<void> _broadcast(ControlFrame frame, {String? except}) async {
    for (final peerId in _memberIdByPeer.keys.toList()) {
      if (peerId == except) continue;
      await _send(peerId, frame);
    }
  }

  void _setState(SessionState next) {
    _state = next;
    if (!_states.isClosed) _states.add(next);
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/session/host_session_test.dart`
Expected: PASS (16 tests)

- [ ] **Step 5: Verify analysis is clean**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add lib/domain/session/host_session.dart test/session/host_session_test.dart
git commit -m "feat: add host session state machine"
```

---

### Task 9: Client session

**Files:**
- Create: `lib/domain/session/client_session.dart`
- Test: `test/session/client_session_test.dart`

**Interfaces:**
- Consumes: everything Task 8 consumes, plus `HostSession` (Task 8) in tests, and `DiscoveredGroup` (Task 2)
- Produces:
  - `ClientSession({required GroupTransport transport, required String displayName})`
  - `Stream<SessionState> get states`, `SessionState get state`
  - `Future<void> join(DiscoveredGroup group, {String? password})`, `Future<void> leave()`, `Future<bool> requestTalk()`, `Future<void> stopTalk()`, `Future<void> dispose()`

The client marks its own entry in every roster it receives, since the host
sends `isSelf: false` for all members.

- [ ] **Step 1: Write the failing test**

Create `test/session/client_session_test.dart`:

```dart
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:bconnect/domain/models/discovered_group.dart';
import 'package:bconnect/domain/models/group_config.dart';
import 'package:bconnect/domain/models/session_state.dart';
import 'package:bconnect/domain/session/client_session.dart';
import 'package:bconnect/domain/session/host_session.dart';
import 'package:bconnect/transport/fake/fake_hub.dart';
import 'package:bconnect/transport/fake/fake_transport.dart';
import 'package:bconnect/transport/group_transport.dart';

void main() {
  late FakeHub hub;
  late FakeTransport hostTransport;
  late FakeTransport clientTransport;
  late HostSession host;
  late ClientSession client;

  setUp(() {
    hub = FakeHub();
    hostTransport = FakeTransport(hub, deviceId: 'host');
    clientTransport = FakeTransport(hub, deviceId: 'client');
    client = ClientSession(
      transport: clientTransport,
      displayName: 'Device 1',
    );
  });

  tearDown(() async {
    await client.dispose();
    await host.dispose();
    await clientTransport.dispose();
    await hostTransport.dispose();
  });

  Future<void> startHost({String? password}) async {
    host = HostSession(
      transport: hostTransport,
      config: GroupConfig(name: 'Team Alpha', password: password),
      hostDisplayName: 'You',
      random: Random(7),
    );
    await host.start();
  }

  /// Discovers the advertised group the way the Discover screen does.
  Future<DiscoveredGroup> discover() async {
    final found = clientTransport.events.whereType<ScanResultEvent>().first;
    await clientTransport.startScan();
    return (await found).group;
  }

  Future<SessionState> connectedState() =>
      client.states.firstWhere((s) => s is SessionConnected);

  Future<SessionState> failedState() =>
      client.states.firstWhere((s) => s is SessionFailed);

  group('join', () {
    test('reaches connected in an open group', () async {
      await startHost();
      final group = await discover();

      final connected = connectedState();
      await client.join(group);

      final state = await connected as SessionConnected;

      expect(state.groupName, 'Team Alpha');
      expect(state.isHost, isFalse);
      expect(state.myMemberId, 'm2');
      expect(state.roster.length, 2);
    });

    test('marks its own entry in the roster', () async {
      await startHost();
      final group = await discover();

      final connected = connectedState();
      await client.join(group);

      final state = await connected as SessionConnected;
      final me = state.roster.firstWhere((m) => m.id == state.myMemberId);

      expect(me.isSelf, isTrue);
      expect(state.roster.where((m) => m.isSelf).length, 1);
    });

    test('passes through the joining steps in order', () async {
      await startHost();
      final group = await discover();

      final steps = <JoinStep>[];
      client.states.listen((s) {
        if (s is SessionJoining) steps.add(s.step);
      });

      final connected = connectedState();
      await client.join(group);
      await connected;

      expect(steps, containsAllInOrder(
        [JoinStep.connecting, JoinStep.authenticating, JoinStep.awaitingRoster],
      ));
    });

    test('reaches connected in a password group with the right password',
        () async {
      await startHost(password: 'hunter2');
      final group = await discover();

      final connected = connectedState();
      await client.join(group, password: 'hunter2');

      expect(await connected, isA<SessionConnected>());
    });

    test('fails with wrongPassword when the password is wrong', () async {
      await startHost(password: 'hunter2');
      final group = await discover();

      final failed = failedState();
      await client.join(group, password: 'nope');

      expect((await failed as SessionFailed).error, SessionError.wrongPassword);
    });

    test('fails with wrongPassword when no password is supplied', () async {
      await startHost(password: 'hunter2');
      final group = await discover();

      final failed = failedState();
      await client.join(group);

      expect((await failed as SessionFailed).error, SessionError.wrongPassword);
    });

    test('fails when the device is not reachable', () async {
      await startHost();
      final group = await discover();

      final failed = failedState();
      await client.join(group.copyWith(deviceId: 'gone'));

      expect(
        (await failed as SessionFailed).error,
        SessionError.connectionLost,
      );
    });
  });

  group('roster updates', () {
    test('reflects another member joining', () async {
      await startHost();
      final group = await discover();

      final connected = connectedState();
      await client.join(group);
      await connected;

      final grown = client.states.firstWhere(
        (s) => s is SessionConnected && s.roster.length == 3,
      );

      final second = FakeTransport(hub, deviceId: 'client2');
      addTearDown(second.dispose);
      final other =
          ClientSession(transport: second, displayName: 'Device 2');
      addTearDown(other.dispose);
      await other.join(group);

      expect((await grown as SessionConnected).roster.length, 3);
    });

    test('reflects the host marking a member as talking', () async {
      await startHost();
      final group = await discover();

      final connected = connectedState();
      await client.join(group);
      await connected;

      final talking = client.states.firstWhere(
        (s) =>
            s is SessionConnected &&
            s.roster.any((m) => m.id == HostSession.hostMemberId && m.isTalking),
      );

      await host.requestTalk();

      expect(await talking, isA<SessionConnected>());
    });
  });

  group('talk control', () {
    test('grants the floor and tells the host', () async {
      await startHost();
      final group = await discover();

      final connected = connectedState();
      await client.join(group);
      await connected;

      expect(await client.requestTalk(), isTrue);
      expect(clientTransport.isTalking, isTrue);

      await Future<void>.delayed(Duration.zero);
      expect(
        (host.state as SessionConnected)
            .roster
            .firstWhere((m) => m.id == 'm2')
            .isTalking,
        isTrue,
      );
    });

    test('stopTalk clears the floor', () async {
      await startHost();
      final group = await discover();

      final connected = connectedState();
      await client.join(group);
      await connected;

      await client.requestTalk();
      await client.stopTalk();

      expect(clientTransport.isTalking, isFalse);
    });

    test('refuses to talk when not connected', () async {
      expect(await client.requestTalk(), isFalse);
    });
  });

  group('teardown', () {
    test('leave returns to idle and removes the member from the host',
        () async {
      await startHost();
      final group = await discover();

      final connected = connectedState();
      await client.join(group);
      await connected;

      await client.leave();
      await Future<void>.delayed(Duration.zero);

      expect(client.state, isA<SessionIdle>());
      expect((host.state as SessionConnected).roster.length, 1);
    });

    test('fails with hostLeft when the host ends the group', () async {
      await startHost();
      final group = await discover();

      final connected = connectedState();
      await client.join(group);
      await connected;

      final failed = failedState();
      await host.stop();

      expect((await failed as SessionFailed).error, SessionError.hostLeft);
    });

    test('fails with connectionLost when the link drops unexpectedly',
        () async {
      await startHost();
      final group = await discover();

      final connected = connectedState();
      await client.join(group);
      await connected;

      final failed = failedState();
      await hostTransport.dispose();

      expect(
        (await failed as SessionFailed).error,
        SessionError.connectionLost,
      );
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/session/client_session_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:bconnect/domain/session/client_session.dart'`

- [ ] **Step 3: Write the implementation**

Create `lib/domain/session/client_session.dart`:

```dart
import 'dart:async';
import 'dart:typed_data';

import '../../transport/group_transport.dart';
import '../models/discovered_group.dart';
import '../models/member.dart';
import '../models/session_state.dart';
import '../protocol/control_frame.dart';
import '../protocol/frame_codec.dart';
import '../protocol/password_proof.dart';
import '../protocol/protocol_limits.dart';
import 'roster.dart';

/// Client-role state machine (spec section 5.3).
class ClientSession {
  ClientSession({
    required GroupTransport transport,
    required String displayName,
  })  : _transport = transport,
        _displayName = displayName;

  final GroupTransport _transport;
  final String _displayName;

  final StreamController<SessionState> _states =
      StreamController<SessionState>.broadcast();

  StreamSubscription<TransportEvent>? _subscription;

  SessionState _state = const SessionState.idle();
  DiscoveredGroup? _group;
  String? _peerId;
  String? _password;
  String? _myMemberId;

  /// Set once the host has ended the group, so the disconnect that follows is
  /// reported as hostLeft rather than connectionLost.
  bool _hostEnded = false;

  SessionState get state => _state;
  Stream<SessionState> get states => _states.stream;

  Future<void> join(DiscoveredGroup group, {String? password}) async {
    _group = group;
    _password = password;
    _myMemberId = null;
    _hostEnded = false;

    _subscription ??= _transport.events.listen(_onEvent);
    _setState(SessionState.joining(group: group, step: JoinStep.connecting));

    try {
      _peerId = await _transport.connect(group.deviceId);
    } on TransportException {
      _setState(const SessionState.failed(error: SessionError.connectionLost));
      return;
    }

    _setState(
      SessionState.joining(group: group, step: JoinStep.authenticating),
    );
  }

  Future<void> leave() async {
    final peerId = _peerId;
    if (peerId != null) {
      await _send(const ControlFrame.leave());
      await _transport.stopTalking();
      try {
        await _transport.disconnect(peerId);
      } on TransportException {
        // Already gone.
      }
    }

    _peerId = null;
    _myMemberId = null;
    _setState(const SessionState.idle());
  }

  /// Returns false when not connected, or when the concurrent-talker cap is
  /// already reached (spec section 5.4).
  Future<bool> requestTalk() async {
    final current = _state;
    final memberId = _myMemberId;
    if (current is! SessionConnected || memberId == null) return false;
    if (!Roster.canTalk(current.roster, memberId)) return false;

    _setTalking(memberId, true);
    await _transport.startTalking();
    await _send(ControlFrame.talkStart(memberId: memberId));

    return true;
  }

  Future<void> stopTalk() async {
    final memberId = _myMemberId;
    if (memberId == null) return;

    _setTalking(memberId, false);
    await _transport.stopTalking();
    await _send(ControlFrame.talkStop(memberId: memberId));
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    await _states.close();
  }

  void _onEvent(TransportEvent event) {
    switch (event) {
      case ControlMessageEvent(:final peerId, :final bytes)
          when peerId == _peerId:
        _onControl(bytes);
      case PeerDisconnectedEvent(:final peerId) when peerId == _peerId:
        _onDisconnected();
      case ControlMessageEvent():
      case PeerDisconnectedEvent():
      case PeerConnectedEvent():
      case ScanResultEvent():
      case TransportErrorEvent():
        break;
    }
  }

  Future<void> _onControl(Uint8List bytes) async {
    final ControlFrame frame;
    try {
      frame = FrameCodec.decode(bytes);
    } on FrameDecodeException {
      return;
    }

    switch (frame) {
      case ChallengeFrame(:final nonce):
        await _answerChallenge(nonce);
      case JoinAcceptedFrame(:final memberId, :final roster):
        _onAccepted(memberId, roster);
      case JoinRejectedFrame(:final reason):
        _onRejected(reason);
      case RosterUpdateFrame(:final members):
        _onRoster(members);
      case TalkStartFrame(:final memberId):
        _setTalking(memberId, true);
      case TalkStopFrame(:final memberId):
        _setTalking(memberId, false);
      case LeaveFrame():
        // The host ended the group.
        _hostEnded = true;
        _setState(const SessionState.failed(error: SessionError.hostLeft));
      case PingFrame():
        await _send(const ControlFrame.pong());
      case JoinRequestFrame():
      case PongFrame():
        break;
    }
  }

  Future<void> _answerChallenge(Uint8List nonce) async {
    final password = _password;

    await _send(
      ControlFrame.joinRequest(
        version: ProtocolLimits.protocolVersion,
        displayName: _displayName,
        passwordProof: password == null || password.isEmpty
            ? Uint8List(0)
            : PasswordProof.compute(password: password, nonce: nonce),
      ),
    );

    _setState(
      SessionState.joining(group: _group!, step: JoinStep.awaitingRoster),
    );
  }

  void _onAccepted(String memberId, List<Member> roster) {
    _myMemberId = memberId;
    final group = _group!;

    _setState(
      SessionState.connected(
        groupId: group.groupId,
        groupName: group.name,
        myMemberId: memberId,
        isHost: false,
        roster: _markSelf(roster, memberId),
      ),
    );
  }

  void _onRejected(JoinRejectReason reason) {
    _setState(
      SessionState.failed(
        error: switch (reason) {
          JoinRejectReason.wrongPassword => SessionError.wrongPassword,
          JoinRejectReason.full => SessionError.groupFull,
          JoinRejectReason.incompatibleVersion =>
            SessionError.incompatibleVersion,
        },
      ),
    );
    _peerId = null;
  }

  void _onRoster(List<Member> members) {
    final current = _state;
    final memberId = _myMemberId;
    if (current is! SessionConnected || memberId == null) return;

    _setState(current.copyWith(roster: _markSelf(members, memberId)));
  }

  void _onDisconnected() {
    _peerId = null;

    if (_hostEnded || _state is SessionFailed) return;
    if (_state is SessionIdle) return;

    _setState(const SessionState.failed(error: SessionError.connectionLost));
  }

  /// The host sends `isSelf: false` for everyone, so the client marks its own
  /// entry on arrival.
  List<Member> _markSelf(List<Member> roster, String memberId) =>
      List.unmodifiable([
        for (final m in roster) m.copyWith(isSelf: m.id == memberId),
      ]);

  void _setTalking(String memberId, bool talking) {
    final current = _state;
    if (current is! SessionConnected) return;

    _setState(
      current.copyWith(
        roster: Roster.setTalking(current.roster, memberId, talking),
      ),
    );
  }

  Future<void> _send(ControlFrame frame) async {
    final peerId = _peerId;
    if (peerId == null) return;

    try {
      await _transport.sendControl(peerId, FrameCodec.encode(frame));
    } on TransportException {
      // The link dropped; _onDisconnected reports it.
    }
  }

  void _setState(SessionState next) {
    _state = next;
    if (!_states.isClosed) _states.add(next);
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/session/client_session_test.dart`
Expected: PASS (15 tests)

- [ ] **Step 5: Verify analysis is clean**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add lib/domain/session/client_session.dart test/session/client_session_test.dart
git commit -m "feat: add client session state machine"
```

---

### Task 10: Multi-member integration test

**Files:**
- Test: `test/integration/group_flow_test.dart`

**Interfaces:**
- Consumes: `HostSession` (Task 8), `ClientSession` (Task 9), `FakeHub`, `FakeTransport` (Task 7)
- Produces: nothing — this task adds no production code

This is the spec §10 integration case: a host plus three clients in a single
test process. No new implementation should be needed; if a test here fails,
fix the session layer rather than the test.

- [ ] **Step 1: Write the test**

Create `test/integration/group_flow_test.dart`:

```dart
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:bconnect/domain/models/discovered_group.dart';
import 'package:bconnect/domain/models/group_config.dart';
import 'package:bconnect/domain/models/session_state.dart';
import 'package:bconnect/domain/protocol/protocol_limits.dart';
import 'package:bconnect/domain/session/client_session.dart';
import 'package:bconnect/domain/session/host_session.dart';
import 'package:bconnect/transport/fake/fake_hub.dart';
import 'package:bconnect/transport/fake/fake_transport.dart';
import 'package:bconnect/transport/group_transport.dart';

/// One simulated device.
class _Device {
  _Device(this.transport, this.session);

  final FakeTransport transport;
  final ClientSession session;

  Future<void> dispose() async {
    await session.dispose();
    await transport.dispose();
  }
}

void main() {
  late FakeHub hub;
  late FakeTransport hostTransport;
  late HostSession host;
  final devices = <_Device>[];

  setUp(() {
    hub = FakeHub();
    hostTransport = FakeTransport(hub, deviceId: 'host');
  });

  tearDown(() async {
    for (final d in devices) {
      await d.dispose();
    }
    devices.clear();
    await host.dispose();
    await hostTransport.dispose();
  });

  Future<void> startHost({String? password}) async {
    host = HostSession(
      transport: hostTransport,
      config: GroupConfig(name: 'Team Alpha', password: password),
      hostDisplayName: 'You',
      random: Random(11),
    );
    await host.start();
  }

  Future<DiscoveredGroup> discoverWith(FakeTransport t) async {
    final found = t.events.whereType<ScanResultEvent>().first;
    await t.startScan();
    return (await found).group;
  }

  Future<_Device> joinDevice(String name, {String? password}) async {
    final transport = FakeTransport(hub, deviceId: 'dev-$name');
    final session = ClientSession(transport: transport, displayName: name);
    final device = _Device(transport, session);
    devices.add(device);

    final group = await discoverWith(transport);
    final connected =
        session.states.firstWhere((s) => s is SessionConnected);
    await session.join(group, password: password);
    await connected;

    return device;
  }

  test('three clients join an open group and everyone sees four members',
      () async {
    await startHost();

    await joinDevice('Device 1');
    await joinDevice('Device 2');
    final third = await joinDevice('Device 3');

    await Future<void>.delayed(Duration.zero);

    expect((host.state as SessionConnected).roster.length, 4);
    expect((third.session.state as SessionConnected).roster.length, 4);

    for (final d in devices) {
      final state = d.session.state as SessionConnected;
      expect(state.roster.where((m) => m.isSelf).length, 1);
    }
  });

  test('three clients join a password group with the right password',
      () async {
    await startHost(password: 'hunter2');

    await joinDevice('Device 1', password: 'hunter2');
    await joinDevice('Device 2', password: 'hunter2');
    await joinDevice('Device 3', password: 'hunter2');

    await Future<void>.delayed(Duration.zero);

    expect((host.state as SessionConnected).roster.length, 4);
  });

  test('the advertised member count tracks the roster', () async {
    await startHost();
    await joinDevice('Device 1');
    await joinDevice('Device 2');

    final scanner = FakeTransport(hub, deviceId: 'scanner');
    addTearDown(scanner.dispose);

    expect((await discoverWith(scanner)).memberCount, 3);
  });

  test('concurrent talkers are capped, and the floor frees up again',
      () async {
    await startHost();

    final talkers = <_Device>[];
    for (var i = 0; i < ProtocolLimits.maxConcurrentTalkers; i++) {
      talkers.add(await joinDevice('Talker $i'));
    }
    final extra = await joinDevice('One Too Many');

    for (final d in talkers) {
      expect(await d.session.requestTalk(), isTrue);
    }
    await Future<void>.delayed(Duration.zero);

    expect(await extra.session.requestTalk(), isFalse);

    await talkers.first.session.stopTalk();
    await Future<void>.delayed(Duration.zero);

    expect(await extra.session.requestTalk(), isTrue);
  });

  test('a member leaving is removed from every other roster', () async {
    await startHost();

    final first = await joinDevice('Device 1');
    final second = await joinDevice('Device 2');

    final shrunk = second.session.states.firstWhere(
      (s) => s is SessionConnected && s.roster.length == 2,
    );

    await first.session.leave();

    expect((await shrunk as SessionConnected).roster.length, 2);
    expect((host.state as SessionConnected).roster.length, 2);
  });

  test('ending the group fails every client with hostLeft', () async {
    await startHost();

    final a = await joinDevice('Device 1');
    final b = await joinDevice('Device 2');

    final aFailed = a.session.states.firstWhere((s) => s is SessionFailed);
    final bFailed = b.session.states.firstWhere((s) => s is SessionFailed);

    await host.stop();

    expect((await aFailed as SessionFailed).error, SessionError.hostLeft);
    expect((await bFailed as SessionFailed).error, SessionError.hostLeft);
    expect(host.state, isA<SessionIdle>());
  });

  test('the group fills up and refuses an extra member', () async {
    await startHost();

    for (var i = 0; i < ProtocolLimits.maxMembers - 1; i++) {
      await joinDevice('Device $i');
    }
    await Future<void>.delayed(Duration.zero);

    expect((host.state as SessionConnected).roster.length,
        ProtocolLimits.maxMembers);

    final transport = FakeTransport(hub, deviceId: 'dev-extra');
    final session =
        ClientSession(transport: transport, displayName: 'Extra');
    devices.add(_Device(transport, session));

    final group = await discoverWith(transport);
    expect(group.isFull, isTrue);

    final failed = session.states.firstWhere((s) => s is SessionFailed);
    await session.join(group);

    expect((await failed as SessionFailed).error, SessionError.groupFull);
  });
}
```

- [ ] **Step 2: Run the test**

Run: `flutter test test/integration/group_flow_test.dart`
Expected: PASS (7 tests)

If any test fails, correct `host_session.dart` or `client_session.dart`. Do
not weaken the test to make it pass.

- [ ] **Step 3: Run the whole suite**

Run: `flutter test`
Expected: PASS — all tests from Tasks 1–10

- [ ] **Step 4: Commit**

```bash
git add test/integration
git commit -m "test: add multi-member group flow integration test"
```

---

### Task 11: Transport and session providers

**Files:**
- Create: `lib/state/transport_provider.dart`
- Create: `lib/state/session_provider.dart`
- Test: `test/state/session_provider_test.dart`

**Interfaces:**
- Consumes: `GroupTransport` (Task 7), `HostSession` (Task 8), `ClientSession` (Task 9), `SessionState`, `GroupConfig`, `DiscoveredGroup` (Tasks 2, 6)
- Produces:
  - `final transportProvider = Provider<GroupTransport>(…)` — throws unless overridden
  - `final clockProvider = Provider<DateTime Function()>(…)` — defaults to `DateTime.now`
  - `class SessionController extends Notifier<SessionState>` with `createGroup`, `joinGroup`, `leave`, `requestTalk`, `stopTalk`, `reset`
  - `final sessionProvider = NotifierProvider<SessionController, SessionState>(SessionController.new)`

`sessionProvider` is deliberately **not** autoDispose: an active call must
survive navigation between the group screen and the audio-output screen
(spec §6.2).

- [ ] **Step 1: Write the failing test**

Create `test/state/session_provider_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bconnect/domain/models/group_config.dart';
import 'package:bconnect/domain/models/session_state.dart';
import 'package:bconnect/state/session_provider.dart';
import 'package:bconnect/state/transport_provider.dart';
import 'package:bconnect/transport/fake/fake_hub.dart';
import 'package:bconnect/transport/fake/fake_transport.dart';
import 'package:bconnect/transport/group_transport.dart';

void main() {
  late FakeHub hub;
  late FakeTransport transport;
  late ProviderContainer container;

  setUp(() {
    hub = FakeHub();
    transport = FakeTransport(hub, deviceId: 'me');
    container = ProviderContainer(
      overrides: [transportProvider.overrideWithValue(transport)],
    );
  });

  tearDown(() async {
    container.dispose();
    await transport.dispose();
  });

  test('starts idle', () {
    expect(container.read(sessionProvider), isA<SessionIdle>());
  });

  test('transportProvider throws unless overridden', () {
    final bare = ProviderContainer();
    addTearDown(bare.dispose);

    expect(() => bare.read(transportProvider), throwsUnimplementedError);
  });

  test('createGroup reaches connected as host', () async {
    await container.read(sessionProvider.notifier).createGroup(
          const GroupConfig(name: 'Team Alpha'),
          displayName: 'You',
        );

    final state = container.read(sessionProvider) as SessionConnected;

    expect(state.isHost, isTrue);
    expect(state.groupName, 'Team Alpha');
    expect(state.roster.single.isSelf, isTrue);
  });

  test('joinGroup reaches connected as a client', () async {
    final hostTransport = FakeTransport(hub, deviceId: 'host');
    addTearDown(hostTransport.dispose);

    final hostContainer = ProviderContainer(
      overrides: [transportProvider.overrideWithValue(hostTransport)],
    );
    addTearDown(hostContainer.dispose);

    await hostContainer.read(sessionProvider.notifier).createGroup(
          const GroupConfig(name: 'Team Alpha'),
          displayName: 'Host',
        );

    final found = transport.events.whereType<ScanResultEvent>().first;
    await transport.startScan();
    final group = (await found).group;

    await container
        .read(sessionProvider.notifier)
        .joinGroup(group, displayName: 'Device 1');

    final state = container.read(sessionProvider) as SessionConnected;

    expect(state.isHost, isFalse);
    expect(state.roster.length, 2);
  });

  test('joinGroup with the wrong password fails', () async {
    final hostTransport = FakeTransport(hub, deviceId: 'host');
    addTearDown(hostTransport.dispose);

    final hostContainer = ProviderContainer(
      overrides: [transportProvider.overrideWithValue(hostTransport)],
    );
    addTearDown(hostContainer.dispose);

    await hostContainer.read(sessionProvider.notifier).createGroup(
          const GroupConfig(name: 'Team Alpha', password: 'hunter2'),
          displayName: 'Host',
        );

    final found = transport.events.whereType<ScanResultEvent>().first;
    await transport.startScan();

    await container.read(sessionProvider.notifier).joinGroup(
          (await found).group,
          password: 'nope',
          displayName: 'Device 1',
        );

    expect(
      (container.read(sessionProvider) as SessionFailed).error,
      SessionError.wrongPassword,
    );
  });

  test('leave returns to idle', () async {
    final notifier = container.read(sessionProvider.notifier);
    await notifier.createGroup(
      const GroupConfig(name: 'Team Alpha'),
      displayName: 'You',
    );

    await notifier.leave();

    expect(container.read(sessionProvider), isA<SessionIdle>());
  });

  test('requestTalk grants the floor to the host', () async {
    final notifier = container.read(sessionProvider.notifier);
    await notifier.createGroup(
      const GroupConfig(name: 'Team Alpha'),
      displayName: 'You',
    );

    expect(await notifier.requestTalk(), isTrue);
    expect(transport.isTalking, isTrue);

    await notifier.stopTalk();
    expect(transport.isTalking, isFalse);
  });

  test('reset clears a failure back to idle', () async {
    final notifier = container.read(sessionProvider.notifier);
    await notifier.createGroup(
      const GroupConfig(name: 'Team Alpha'),
      displayName: 'You',
    );
    await notifier.leave();

    notifier.reset();

    expect(container.read(sessionProvider), isA<SessionIdle>());
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/state/session_provider_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:bconnect/state/transport_provider.dart'`

- [ ] **Step 3: Create the transport provider**

Create `lib/state/transport_provider.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../transport/group_transport.dart';

/// The active transport.
///
/// Plan A has no real implementation, so every entry point must override this
/// with a `FakeTransport`. Plan B supplies the BLE implementation.
final transportProvider = Provider<GroupTransport>((ref) {
  throw UnimplementedError(
    'transportProvider must be overridden with a GroupTransport '
    'implementation.',
  );
});

/// Injected so tests can control time without waiting for real clocks.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);
```

- [ ] **Step 4: Create the session provider**

Create `lib/state/session_provider.dart`:

```dart
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models/discovered_group.dart';
import '../domain/models/group_config.dart';
import '../domain/models/session_state.dart';
import '../domain/session/client_session.dart';
import '../domain/session/host_session.dart';
import 'transport_provider.dart';

/// Owns whichever role the device is currently playing.
///
/// Not autoDispose: an active call must survive navigating away from the
/// group screen (spec section 6.2).
class SessionController extends Notifier<SessionState> {
  HostSession? _host;
  ClientSession? _client;
  StreamSubscription<SessionState>? _subscription;

  @override
  SessionState build() {
    ref.onDispose(() {
      unawaited(_teardown());
    });
    return const SessionState.idle();
  }

  Future<void> createGroup(
    GroupConfig config, {
    required String displayName,
  }) async {
    await _teardown();

    final host = HostSession(
      transport: ref.read(transportProvider),
      config: config,
      hostDisplayName: displayName,
    );
    _host = host;
    _subscription = host.states.listen((s) => state = s);

    await host.start();
    state = host.state;
  }

  Future<void> joinGroup(
    DiscoveredGroup group, {
    String? password,
    required String displayName,
  }) async {
    await _teardown();

    final client = ClientSession(
      transport: ref.read(transportProvider),
      displayName: displayName,
    );
    _client = client;
    _subscription = client.states.listen((s) => state = s);

    // Completes once the handshake settles either way.
    final settled = client.states.firstWhere(
      (s) => s is SessionConnected || s is SessionFailed,
    );

    await client.join(group, password: password);
    state = await settled;
  }

  Future<void> leave() async {
    await _host?.stop();
    await _client?.leave();
    await _teardown();
    state = const SessionState.idle();
  }

  Future<bool> requestTalk() async =>
      await _host?.requestTalk() ?? await _client?.requestTalk() ?? false;

  Future<void> stopTalk() async {
    await _host?.stopTalk();
    await _client?.stopTalk();
  }

  /// Dismisses a failure without tearing anything else down.
  void reset() => state = const SessionState.idle();

  Future<void> _teardown() async {
    await _subscription?.cancel();
    _subscription = null;

    await _host?.dispose();
    await _client?.dispose();
    _host = null;
    _client = null;
  }
}

final sessionProvider =
    NotifierProvider<SessionController, SessionState>(SessionController.new);
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/state/session_provider_test.dart`
Expected: PASS (8 tests)

- [ ] **Step 6: Commit**

```bash
git add lib/state test/state
git commit -m "feat: add transport and session providers"
```

---

### Task 12: Discovered groups provider with TTL expiry

**Files:**
- Create: `lib/state/discovered_groups_provider.dart`
- Test: `test/state/discovered_groups_provider_test.dart`

**Interfaces:**
- Consumes: `transportProvider`, `clockProvider` (Task 11); `ScanResultEvent` (Task 7); `ProtocolLimits.advertTtl` (Task 3)
- Produces: `final discoveredGroupsProvider = StreamProvider.autoDispose<List<DiscoveredGroup>>(…)`

autoDispose is required: scanning must stop the moment the Discover screen is
left, because continuous BLE scanning is a significant battery drain
(spec §6.2). Results are sorted by descending RSSI so the strongest signal
sits at the top, and entries older than `advertTtl` are dropped.

- [ ] **Step 1: Write the failing test**

Create `test/state/discovered_groups_provider_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bconnect/domain/models/discovered_group.dart';
import 'package:bconnect/domain/protocol/protocol_limits.dart';
import 'package:bconnect/state/discovered_groups_provider.dart';
import 'package:bconnect/state/transport_provider.dart';
import 'package:bconnect/transport/fake/fake_hub.dart';
import 'package:bconnect/transport/fake/fake_transport.dart';

void main() {
  late FakeHub hub;
  late FakeTransport me;
  late DateTime now;

  setUp(() {
    now = DateTime(2026, 8, 26, 12);
    hub = FakeHub(clock: () => now);
    me = FakeTransport(hub, deviceId: 'me');
  });

  tearDown(() async => me.dispose());

  ProviderContainer makeContainer() {
    final container = ProviderContainer(
      overrides: [
        transportProvider.overrideWithValue(me),
        clockProvider.overrideWithValue(() => now),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<FakeTransport> advertise(
    String deviceId,
    String name, {
    int groupId = 0x1A2B,
    int memberCount = 1,
    bool isLocked = false,
  }) async {
    final host = FakeTransport(hub, deviceId: deviceId);
    addTearDown(host.dispose);
    await host.startAdvertising(
      groupName: name,
      groupId: groupId,
      memberCount: memberCount,
      isLocked: isLocked,
      isFull: false,
    );
    return host;
  }

  test('starts scanning when first watched', () async {
    final container = makeContainer();

    container.listen(discoveredGroupsProvider, (_, __) {});
    await Future<void>.delayed(Duration.zero);

    expect(me.isScanning, isTrue);
  });

  test('stops scanning when disposed', () async {
    final container = makeContainer();

    final subscription =
        container.listen(discoveredGroupsProvider, (_, __) {});
    await Future<void>.delayed(Duration.zero);
    subscription.close();
    await Future<void>.delayed(Duration.zero);

    expect(me.isScanning, isFalse);
  });

  test('surfaces an advertising group', () async {
    await advertise('host1', 'Team Alpha', isLocked: true);
    final container = makeContainer();

    final groups = await container.read(discoveredGroupsProvider.future);

    expect(groups.single.name, 'Team Alpha');
    expect(groups.single.isLocked, isTrue);
  });

  test('deduplicates repeated adverts from the same group', () async {
    final host = await advertise('host1', 'Team Alpha');
    final container = makeContainer();

    container.listen(discoveredGroupsProvider, (_, __) {});
    await Future<void>.delayed(Duration.zero);

    await host.updateAdvertisement(memberCount: 4, isFull: false);
    await Future<void>.delayed(Duration.zero);

    final groups = container.read(discoveredGroupsProvider).value!;

    expect(groups.length, 1);
    expect(groups.single.memberCount, 4);
  });

  test('lists several groups sorted by descending signal strength', () async {
    await advertise('host1', 'Team Alpha', groupId: 0x0001);
    await advertise('host2', 'Project Beta', groupId: 0x0002);
    final container = makeContainer();

    final groups = await container.read(discoveredGroupsProvider.future);

    expect(groups.length, 2);
    for (var i = 1; i < groups.length; i++) {
      expect(groups[i - 1].rssi, greaterThanOrEqualTo(groups[i].rssi));
    }
  });

  test('drops a group that has not advertised within the TTL', () async {
    await advertise('host1', 'Team Alpha', groupId: 0x0001);
    final container = makeContainer();

    container.listen(discoveredGroupsProvider, (_, __) {});
    await Future<void>.delayed(Duration.zero);
    expect(container.read(discoveredGroupsProvider).value!.length, 1);

    // Advance past the TTL, then let a second group advertise so the list
    // recomputes.
    now = now.add(ProtocolLimits.advertTtl + const Duration(seconds: 1));
    await advertise('host2', 'Project Beta', groupId: 0x0002);
    await Future<void>.delayed(Duration.zero);

    final groups = container.read(discoveredGroupsProvider).value!;

    expect(groups.length, 1);
    expect(groups.single.name, 'Project Beta');
  });

  test('keeps a group that keeps advertising', () async {
    final host = await advertise('host1', 'Team Alpha');
    final container = makeContainer();

    container.listen(discoveredGroupsProvider, (_, __) {});
    await Future<void>.delayed(Duration.zero);

    now = now.add(ProtocolLimits.advertTtl - const Duration(seconds: 1));
    await host.updateAdvertisement(memberCount: 2, isFull: false);
    await Future<void>.delayed(Duration.zero);

    expect(container.read(discoveredGroupsProvider).value!.length, 1);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/state/discovered_groups_provider_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:bconnect/state/discovered_groups_provider.dart'`

- [ ] **Step 3: Write the implementation**

Create `lib/state/discovered_groups_provider.dart`:

```dart
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models/discovered_group.dart';
import '../domain/protocol/protocol_limits.dart';
import '../transport/group_transport.dart';
import 'transport_provider.dart';

/// Nearby groups, freshest first.
///
/// autoDispose so scanning stops as soon as the Discover screen is left;
/// continuous BLE scanning is a real battery cost (spec section 6.2).
final discoveredGroupsProvider =
    StreamProvider.autoDispose<List<DiscoveredGroup>>((ref) {
  final transport = ref.watch(transportProvider);
  final clock = ref.watch(clockProvider);

  final controller = StreamController<List<DiscoveredGroup>>();
  final byGroupId = <String, DiscoveredGroup>{};

  void publish() {
    final now = clock();
    byGroupId.removeWhere(
      (_, g) => now.difference(g.lastSeen) > ProtocolLimits.advertTtl,
    );

    final groups = byGroupId.values.toList()
      ..sort((a, b) => b.rssi.compareTo(a.rssi));

    if (!controller.isClosed) controller.add(List.unmodifiable(groups));
  }

  final subscription = transport.events
      .whereType<ScanResultEvent>()
      .listen((event) {
    byGroupId[event.group.groupId] = event.group;
    publish();
  });

  // Prunes stale entries even when nothing new arrives, so a group that goes
  // quiet disappears from the list on its own.
  final timer = Timer.periodic(const Duration(seconds: 1), (_) => publish());

  ref.onDispose(() {
    timer.cancel();
    unawaited(subscription.cancel());
    unawaited(transport.stopScan());
    unawaited(controller.close());
  });

  unawaited(transport.startScan());
  publish();

  return controller.stream;
});
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/state/discovered_groups_provider_test.dart`
Expected: PASS (7 tests)

- [ ] **Step 5: Commit**

```bash
git add lib/state/discovered_groups_provider.dart test/state/discovered_groups_provider_test.dart
git commit -m "feat: add discovered groups provider with TTL expiry"
```

---

### Task 13: Mic, audio route, and persisted settings providers

**Files:**
- Create: `lib/domain/models/recent_group.dart`
- Create: `lib/state/mic_provider.dart`
- Create: `lib/state/audio_route_provider.dart`
- Create: `lib/state/recent_groups_provider.dart`
- Create: `lib/state/display_name_provider.dart`
- Test: `test/state/settings_providers_test.dart`

**Interfaces:**
- Consumes: `transportProvider`, `clockProvider` (Task 11); `MicState`, `AudioRoute` (Task 2)
- Produces:
  - `class RecentGroup { String groupId; String name; int memberCount; DateTime lastJoined; Map<String, dynamic> toJson(); static RecentGroup fromJson(Map<String, dynamic>) }`
  - `final micProvider = NotifierProvider<MicController, MicState>(…)` with `Future<void> setMuted(bool)`, `Future<void> toggleMute()`, `void setTransmitting(bool)`
  - `final audioRouteProvider = NotifierProvider<AudioRouteController, AudioRoute>(…)` with `Future<void> setRoute(AudioRoute)`
  - `final recentGroupsProvider = AsyncNotifierProvider<RecentGroupsController, List<RecentGroup>>(…)` with `Future<void> record({required String groupId, required String name, required int memberCount})`, `Future<void> clear()`
  - `final displayNameProvider = AsyncNotifierProvider<DisplayNameController, String>(…)` with `Future<void> setName(String)`
  - `const String kDefaultDisplayName = 'My Device'`

Recent groups are capped at 5, most recent first.

- [ ] **Step 1: Write the failing test**

Create `test/state/settings_providers_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bconnect/domain/models/audio.dart';
import 'package:bconnect/state/audio_route_provider.dart';
import 'package:bconnect/state/display_name_provider.dart';
import 'package:bconnect/state/mic_provider.dart';
import 'package:bconnect/state/recent_groups_provider.dart';
import 'package:bconnect/state/transport_provider.dart';
import 'package:bconnect/transport/fake/fake_hub.dart';
import 'package:bconnect/transport/fake/fake_transport.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeTransport transport;
  late ProviderContainer container;
  late DateTime now;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    now = DateTime(2026, 8, 26, 12);
    transport = FakeTransport(FakeHub(), deviceId: 'me');
    container = ProviderContainer(
      overrides: [
        transportProvider.overrideWithValue(transport),
        clockProvider.overrideWithValue(() => now),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await transport.dispose();
  });

  group('micProvider', () {
    test('starts unmuted and not transmitting', () {
      final state = container.read(micProvider);

      expect(state.muted, isFalse);
      expect(state.transmitting, isFalse);
    });

    test('muting disables the mic on the transport', () async {
      await container.read(micProvider.notifier).setMuted(true);

      expect(container.read(micProvider).muted, isTrue);
      expect(transport.micEnabled, isFalse);
    });

    test('toggleMute flips the state both ways', () async {
      final notifier = container.read(micProvider.notifier);

      await notifier.toggleMute();
      expect(container.read(micProvider).muted, isTrue);

      await notifier.toggleMute();
      expect(container.read(micProvider).muted, isFalse);
      expect(transport.micEnabled, isTrue);
    });

    test('muting while transmitting also stops transmitting', () async {
      final notifier = container.read(micProvider.notifier);
      notifier.setTransmitting(true);

      await notifier.setMuted(true);

      expect(container.read(micProvider).transmitting, isFalse);
    });
  });

  group('audioRouteProvider', () {
    test('defaults to the speaker', () {
      expect(container.read(audioRouteProvider), AudioRoute.speaker);
    });

    test('switching to the earpiece reaches the transport', () async {
      await container
          .read(audioRouteProvider.notifier)
          .setRoute(AudioRoute.earpiece);

      expect(container.read(audioRouteProvider), AudioRoute.earpiece);
      expect(transport.audioRoute, AudioRoute.earpiece);
    });
  });

  group('displayNameProvider', () {
    test('defaults when nothing is stored', () async {
      expect(
        await container.read(displayNameProvider.future),
        kDefaultDisplayName,
      );
    });

    test('persists a new name', () async {
      await container.read(displayNameProvider.future);
      await container.read(displayNameProvider.notifier).setName('Atharva');

      expect(container.read(displayNameProvider).value, 'Atharva');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('display_name'), 'Atharva');
    });

    test('reloads a stored name', () async {
      SharedPreferences.setMockInitialValues({'display_name': 'Stored'});

      final fresh = ProviderContainer(
        overrides: [transportProvider.overrideWithValue(transport)],
      );
      addTearDown(fresh.dispose);

      expect(await fresh.read(displayNameProvider.future), 'Stored');
    });

    test('ignores an all-whitespace name', () async {
      await container.read(displayNameProvider.future);
      await container.read(displayNameProvider.notifier).setName('   ');

      expect(container.read(displayNameProvider).value, kDefaultDisplayName);
    });
  });

  group('recentGroupsProvider', () {
    test('starts empty', () async {
      expect(await container.read(recentGroupsProvider.future), isEmpty);
    });

    test('records a group', () async {
      await container.read(recentGroupsProvider.future);
      await container.read(recentGroupsProvider.notifier).record(
            groupId: '1a2b',
            name: 'Team Alpha',
            memberCount: 3,
          );

      final groups = container.read(recentGroupsProvider).value!;

      expect(groups.single.name, 'Team Alpha');
      expect(groups.single.memberCount, 3);
      expect(groups.single.lastJoined, now);
    });

    test('moves a repeated group to the front without duplicating it',
        () async {
      final notifier = container.read(recentGroupsProvider.notifier);
      await container.read(recentGroupsProvider.future);

      await notifier.record(groupId: 'a', name: 'A', memberCount: 1);
      await notifier.record(groupId: 'b', name: 'B', memberCount: 1);
      await notifier.record(groupId: 'a', name: 'A', memberCount: 5);

      final groups = container.read(recentGroupsProvider).value!;

      expect(groups.length, 2);
      expect(groups.first.groupId, 'a');
      expect(groups.first.memberCount, 5);
    });

    test('keeps at most five groups', () async {
      final notifier = container.read(recentGroupsProvider.notifier);
      await container.read(recentGroupsProvider.future);

      for (var i = 0; i < 7; i++) {
        await notifier.record(groupId: 'g$i', name: 'G$i', memberCount: 1);
      }

      final groups = container.read(recentGroupsProvider).value!;

      expect(groups.length, 5);
      expect(groups.first.groupId, 'g6');
    });

    test('survives a reload', () async {
      await container.read(recentGroupsProvider.future);
      await container.read(recentGroupsProvider.notifier).record(
            groupId: '1a2b',
            name: 'Team Alpha',
            memberCount: 3,
          );

      final fresh = ProviderContainer(
        overrides: [transportProvider.overrideWithValue(transport)],
      );
      addTearDown(fresh.dispose);

      final groups = await fresh.read(recentGroupsProvider.future);

      expect(groups.single.name, 'Team Alpha');
    });

    test('clear empties the list', () async {
      final notifier = container.read(recentGroupsProvider.notifier);
      await container.read(recentGroupsProvider.future);
      await notifier.record(groupId: 'a', name: 'A', memberCount: 1);

      await notifier.clear();

      expect(container.read(recentGroupsProvider).value, isEmpty);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/state/settings_providers_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:bconnect/state/mic_provider.dart'`

- [ ] **Step 3: Create the RecentGroup model**

Create `lib/domain/models/recent_group.dart`. This is a plain class rather
than a freezed one because it needs hand-written JSON and the project does
not depend on `json_serializable`.

```dart
/// An entry in the "Your Groups" list on the home screen.
class RecentGroup {
  const RecentGroup({
    required this.groupId,
    required this.name,
    required this.memberCount,
    required this.lastJoined,
  });

  final String groupId;
  final String name;
  final int memberCount;
  final DateTime lastJoined;

  Map<String, dynamic> toJson() => {
        'groupId': groupId,
        'name': name,
        'memberCount': memberCount,
        'lastJoined': lastJoined.toIso8601String(),
      };

  static RecentGroup fromJson(Map<String, dynamic> json) => RecentGroup(
        groupId: json['groupId'] as String,
        name: json['name'] as String,
        memberCount: json['memberCount'] as int,
        lastJoined: DateTime.parse(json['lastJoined'] as String),
      );

  @override
  bool operator ==(Object other) =>
      other is RecentGroup &&
      other.groupId == groupId &&
      other.name == name &&
      other.memberCount == memberCount &&
      other.lastJoined == lastJoined;

  @override
  int get hashCode => Object.hash(groupId, name, memberCount, lastJoined);
}
```

- [ ] **Step 4: Create the mic provider**

Create `lib/state/mic_provider.dart`:

```dart
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
```

- [ ] **Step 5: Create the audio route provider**

Create `lib/state/audio_route_provider.dart`:

```dart
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
```

- [ ] **Step 6: Create the display name provider**

Create `lib/state/display_name_provider.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String kDefaultDisplayName = 'My Device';
const String _key = 'display_name';

class DisplayNameController extends AsyncNotifier<String> {
  @override
  Future<String> build() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_key);

    return (stored == null || stored.trim().isEmpty)
        ? kDefaultDisplayName
        : stored;
  }

  Future<void> setName(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, trimmed);

    state = AsyncData(trimmed);
  }
}

final displayNameProvider =
    AsyncNotifierProvider<DisplayNameController, String>(
  DisplayNameController.new,
);
```

- [ ] **Step 7: Create the recent groups provider**

Create `lib/state/recent_groups_provider.dart`:

```dart
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/models/recent_group.dart';
import 'transport_provider.dart';

const int _maxRecentGroups = 5;
const String _key = 'recent_groups';

class RecentGroupsController extends AsyncNotifier<List<RecentGroup>> {
  @override
  Future<List<RecentGroup>> build() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_key) ?? const [];

    return List.unmodifiable([
      for (final entry in stored)
        RecentGroup.fromJson(jsonDecode(entry) as Map<String, dynamic>),
    ]);
  }

  /// Adds [groupId] to the front of the list, replacing any earlier entry for
  /// the same group.
  Future<void> record({
    required String groupId,
    required String name,
    required int memberCount,
  }) async {
    final current = state.value ?? const <RecentGroup>[];

    final next = <RecentGroup>[
      RecentGroup(
        groupId: groupId,
        name: name,
        memberCount: memberCount,
        lastJoined: ref.read(clockProvider)(),
      ),
      ...current.where((g) => g.groupId != groupId),
    ].take(_maxRecentGroups).toList();

    await _persist(next);
  }

  Future<void> clear() => _persist(const []);

  Future<void> _persist(List<RecentGroup> groups) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _key,
      [for (final g in groups) jsonEncode(g.toJson())],
    );

    state = AsyncData(List.unmodifiable(groups));
  }
}

final recentGroupsProvider =
    AsyncNotifierProvider<RecentGroupsController, List<RecentGroup>>(
  RecentGroupsController.new,
);
```

- [ ] **Step 8: Run test to verify it passes**

Run: `flutter test test/state/settings_providers_test.dart`
Expected: PASS (15 tests)

- [ ] **Step 9: Run the whole suite and check analysis**

Run: `flutter test && flutter analyze`
Expected: all tests PASS, `No issues found!`

- [ ] **Step 10: Commit**

```bash
git add lib/domain/models/recent_group.dart lib/state test/state
git commit -m "feat: add mic, audio route, and persisted settings providers"
```

---

### Task 14: Router, app shell, and home screen

**Files:**
- Modify: `lib/state/transport_provider.dart` (add `peripheralSupportedProvider`)
- Create: `lib/core/router/app_router.dart`
- Create: `lib/ui/home/home_shell.dart`
- Create: `lib/ui/home/home_screen.dart`
- Create: `lib/ui/common/action_card.dart`
- Modify: `lib/app.dart` (switch to `MaterialApp.router`)
- Test: `test/ui/home_screen_test.dart`

**Interfaces:**
- Consumes: `recentGroupsProvider` (Task 13), `transportProvider` (Task 11)
- Produces:
  - `final peripheralSupportedProvider = FutureProvider<bool>(…)`
  - `final appRouter = GoRouter(…)` with routes `/`, `/create`, `/discover`, `/join`, `/group`, `/group/audio`
  - `class HomeShell extends StatefulWidget` — bottom navigation over Home, Groups, Settings
  - `class HomeScreen extends ConsumerWidget`
  - `class ActionCard extends StatelessWidget({required String title, required String subtitle, required IconData icon, required VoidCallback? onTap, bool highlighted = false})`

Screens reached from a card (`/create`, `/discover`, `/join`, `/group`) are
pushed above the shell, which is why drawings 2–8 show a back arrow while
drawing 1 shows the bottom navigation.

`ActionCard` takes a nullable `onTap`: a null callback renders the card
disabled, which is how Create New Group is greyed out on a device without
peripheral support (spec §8).

- [ ] **Step 1: Write the failing test**

Create `test/ui/home_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bconnect/app.dart';
import 'package:bconnect/state/transport_provider.dart';
import 'package:bconnect/transport/fake/fake_hub.dart';
import 'package:bconnect/transport/fake/fake_transport.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeTransport transport;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    transport = FakeTransport(FakeHub(), deviceId: 'me');
  });

  tearDown(() async => transport.dispose());

  Future<void> pumpApp(WidgetTester tester, {bool peripheral = true}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          transportProvider.overrideWithValue(transport),
          peripheralSupportedProvider.overrideWith((ref) async => peripheral),
        ],
        child: const BconnectApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the app title and both action cards', (tester) async {
    await pumpApp(tester);

    expect(find.text('Group Talk'), findsOneWidget);
    expect(find.text('Bluetooth Communication'), findsOneWidget);
    expect(find.text('Create New Group'), findsOneWidget);
    expect(find.text('Join Existing Group'), findsOneWidget);
  });

  testWidgets('shows the bottom navigation destinations', (tester) async {
    await pumpApp(tester);

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Groups'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });

  testWidgets('tapping Create New Group navigates away from home',
      (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('Create New Group'));
    await tester.pumpAndSettle();

    // The pushed route covers the shell, so the bottom bar is gone.
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byType(BackButton), findsOneWidget);
  });

  testWidgets('tapping Join Existing Group opens the discover route',
      (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('Join Existing Group'));
    await tester.pumpAndSettle();

    expect(find.text('Join Group'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('says the list is empty when there are no recent groups',
      (tester) async {
    await pumpApp(tester);

    expect(find.text('No groups yet'), findsOneWidget);
  });

  testWidgets('lists a stored recent group', (tester) async {
    SharedPreferences.setMockInitialValues({
      'recent_groups': [
        '{"groupId":"1a2b","name":"Team Alpha","memberCount":3,'
            '"lastJoined":"2026-08-26T12:00:00.000"}',
      ],
    });

    await pumpApp(tester);

    expect(find.text('Team Alpha'), findsOneWidget);
    expect(find.text('3 Members'), findsOneWidget);
  });

  testWidgets('disables Create New Group without peripheral support',
      (tester) async {
    await pumpApp(tester, peripheral: false);

    expect(
      find.text("This device can't host a group"),
      findsOneWidget,
    );

    await tester.tap(find.text('Create New Group'));
    await tester.pumpAndSettle();

    // Still on home: the tap did nothing, so the shell is still visible.
    expect(find.byType(NavigationBar), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/ui/home_screen_test.dart`
Expected: FAIL — `peripheralSupportedProvider` is not defined

- [ ] **Step 3: Add the peripheral support provider**

Append to `lib/state/transport_provider.dart`:

```dart
/// Whether this device's Bluetooth stack can act as a peripheral.
///
/// False disables hosting but not joining (spec section 8). It is a real
/// limitation on some Android chipsets, so it must fail visibly on the home
/// screen rather than midway through creating a group.
final peripheralSupportedProvider = FutureProvider<bool>(
  (ref) => ref.watch(transportProvider).isPeripheralSupported(),
);
```

- [ ] **Step 4: Create the action card**

Create `lib/ui/common/action_card.dart`:

```dart
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// A large tappable card. A null [onTap] renders it disabled.
class ActionCard extends StatelessWidget {
  const ActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.highlighted = false,
    super.key,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final background = highlighted ? AppColors.primary : AppColors.surface;

    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                CircleAvatar(
                  radius: 22,
                  backgroundColor: highlighted
                      ? Colors.white24
                      : AppColors.surfaceRaised,
                  child: Icon(icon, color: AppColors.textPrimary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Create the home screen**

Create `lib/ui/home/home_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../state/recent_groups_provider.dart';
import '../../state/transport_provider.dart';
import '../common/action_card.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // A device that cannot advertise can still join, so only hosting is
    // disabled (spec section 8).
    final canHost =
        ref.watch(peripheralSupportedProvider).value ?? true;
    final recents = ref.watch(recentGroupsProvider);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.primary,
                child: Icon(Icons.bluetooth, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Group Talk',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  Text(
                    'Bluetooth Communication',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 28),
          ActionCard(
            title: 'Create New Group',
            subtitle: 'Create a group and invite others',
            icon: Icons.add,
            highlighted: true,
            onTap: canHost ? () => context.push('/create') : null,
          ),
          if (!canHost)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                "This device can't host a group",
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            ),
          const SizedBox(height: 16),
          ActionCard(
            title: 'Join Existing Group',
            subtitle: 'Discover and join available groups',
            icon: Icons.groups,
            onTap: () => context.push('/discover'),
          ),
          const SizedBox(height: 32),
          Text(
            'Your Groups',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 12),
          switch (recents) {
            AsyncData(value: final groups) when groups.isEmpty =>
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'No groups yet',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            AsyncData(value: final groups) => Column(
                children: [
                  for (final g in groups)
                    Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: AppColors.surfaceRaised,
                          child: Icon(Icons.person),
                        ),
                        title: Text(g.name),
                        subtitle: Text('${g.memberCount} Members'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push('/discover'),
                      ),
                    ),
                ],
              ),
            AsyncError() => const Text(
                'Could not load your groups',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            _ => const Center(child: CircularProgressIndicator()),
          },
        ],
      ),
    );
  }
}
```

- [ ] **Step 6: Create the shell**

Create `lib/ui/home/home_shell.dart`. The Groups and Settings tabs are filled
in by Tasks 16 and 19; for now Groups shows the recent list and Settings a
placeholder that Task 19 replaces.

```dart
import 'package:flutter/material.dart';

import '../settings/settings_screen.dart';
import 'home_screen.dart';

/// Bottom navigation over the three top-level destinations in drawing 1.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [
          HomeScreen(),
          HomeScreen(),
          SettingsScreen(embedded: true),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.groups), label: 'Groups'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}
```

- [ ] **Step 7: Create a temporary settings screen**

Create `lib/ui/settings/settings_screen.dart`. Task 19 replaces the body;
this exists so the shell compiles now.

```dart
import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({this.embedded = false, super.key});

  /// True when hosted inside the bottom navigation rather than pushed.
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: embedded ? null : AppBar(title: const Text('Settings')),
      body: const SafeArea(child: SizedBox.shrink()),
    );
  }
}
```

- [ ] **Step 8: Create the router**

Create `lib/core/router/app_router.dart`. The screens for `/create`,
`/discover`, `/join`, `/group` and `/group/audio` arrive in Tasks 15–19; each
of those tasks replaces its placeholder builder.

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../ui/home/home_shell.dart';

final appRouter = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const HomeShell(),
      routes: [
        GoRoute(
          path: 'create',
          builder: (context, state) => const _Pending('Create New Group'),
        ),
        GoRoute(
          path: 'discover',
          builder: (context, state) => const _Pending('Join Group'),
        ),
        GoRoute(
          path: 'join',
          builder: (context, state) => const _Pending('Join Group'),
        ),
        GoRoute(
          path: 'group',
          builder: (context, state) => const _Pending('Group'),
          routes: [
            GoRoute(
              path: 'audio',
              builder: (context, state) => const _Pending('Audio Output'),
            ),
          ],
        ),
      ],
    ),
  ],
);

/// Replaced task by task as each screen lands.
class _Pending extends StatelessWidget {
  const _Pending(this.title);

  final String title;

  @override
  Widget build(BuildContext context) =>
      Scaffold(appBar: AppBar(title: Text(title)));
}
```

- [ ] **Step 9: Switch the app to the router**

Replace `lib/app.dart`:

```dart
import 'package:flutter/material.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

class BconnectApp extends StatelessWidget {
  const BconnectApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Group Talk',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: AppTheme.dark,
      theme: AppTheme.dark,
      routerConfig: appRouter,
    );
  }
}
```

- [ ] **Step 10: Update the smoke test**

`test/widget_test.dart` asserts on `MaterialApp`, which `MaterialApp.router`
no longer exposes the same way. Replace its body:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bconnect/app.dart';
import 'package:bconnect/state/transport_provider.dart';
import 'package:bconnect/transport/fake/fake_hub.dart';
import 'package:bconnect/transport/fake/fake_transport.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('app builds with a dark theme', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final transport = FakeTransport(FakeHub(), deviceId: 'me');
    addTearDown(transport.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [transportProvider.overrideWithValue(transport)],
        child: const BconnectApp(),
      ),
    );
    await tester.pumpAndSettle();

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));

    expect(app.themeMode, ThemeMode.dark);
    expect(app.darkTheme!.brightness, Brightness.dark);
  });
}
```

- [ ] **Step 11: Run the tests**

Run: `flutter test test/widget_test.dart test/ui/home_screen_test.dart`
Expected: PASS (8 tests)

These navigation tests assert only that the route changed, because `/create`
and `/discover` are still placeholders. Task 15 strengthens the create
assertion once the real screen exists.

- [ ] **Step 12: Commit**

```bash
git add lib test
git commit -m "feat: add router, app shell, and home screen"
```

---

### Task 15: Create group screen

**Files:**
- Create: `lib/ui/create/create_group_screen.dart`
- Create: `lib/ui/common/utf8_byte_limit_formatter.dart`
- Modify: `lib/core/router/app_router.dart` (replace the `/create` placeholder)
- Modify: `test/ui/home_screen_test.dart` (strengthen the create-navigation assertion)
- Test: `test/ui/create_group_screen_test.dart`

**Interfaces:**
- Consumes: `sessionProvider` (Task 11), `displayNameProvider`, `recentGroupsProvider` (Task 13), `ProtocolLimits.maxGroupNameBytes` (Task 3), `GroupConfig` (Task 2)
- Produces:
  - `class Utf8ByteLimitFormatter extends TextInputFormatter` — `Utf8ByteLimitFormatter(int maxBytes)`
  - `class CreateGroupScreen extends ConsumerStatefulWidget`

The name field is limited in **UTF-8 bytes**, not characters, because that is
what the scan response budget measures (spec §5.1). A plain `maxLength` would
let 29 multi-byte characters through and then fail at advertise time.

- [ ] **Step 1: Write the failing test**

Create `test/ui/create_group_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bconnect/app.dart';
import 'package:bconnect/domain/models/session_state.dart';
import 'package:bconnect/domain/protocol/protocol_limits.dart';
import 'package:bconnect/state/session_provider.dart';
import 'package:bconnect/state/transport_provider.dart';
import 'package:bconnect/transport/fake/fake_hub.dart';
import 'package:bconnect/transport/fake/fake_transport.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeTransport transport;
  late ProviderContainer container;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    transport = FakeTransport(FakeHub(), deviceId: 'me');
  });

  tearDown(() async => transport.dispose());

  Future<void> openCreateScreen(WidgetTester tester) async {
    container = ProviderContainer(
      overrides: [transportProvider.overrideWithValue(transport)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const BconnectApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create New Group'));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the name field and both security options',
      (tester) async {
    await openCreateScreen(tester);

    expect(find.text('Group Name'), findsOneWidget);
    expect(find.text('Enter group name'), findsOneWidget);
    expect(find.text('Security'), findsOneWidget);
    expect(find.text('Open Group'), findsOneWidget);
    expect(find.text('Password Protected'), findsOneWidget);
    expect(find.text('Create Group'), findsWidgets);
  });

  testWidgets('defaults to an open group with the password field disabled',
      (tester) async {
    await openCreateScreen(tester);

    final field = tester.widget<TextField>(
      find.widgetWithText(TextField, 'Enter password'),
    );

    expect(field.enabled, isFalse);
  });

  testWidgets('choosing password protection enables the password field',
      (tester) async {
    await openCreateScreen(tester);

    await tester.tap(find.text('Password Protected'));
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(
      find.widgetWithText(TextField, 'Enter password'),
    );

    expect(field.enabled, isTrue);
  });

  testWidgets('refuses an empty group name', (tester) async {
    await openCreateScreen(tester);

    await tester.tap(find.text('Create Group'));
    await tester.pumpAndSettle();

    expect(find.text('Enter a group name'), findsOneWidget);
    expect(container.read(sessionProvider), isA<SessionIdle>());
  });

  testWidgets('refuses password protection with no password', (tester) async {
    await openCreateScreen(tester);

    await tester.enterText(
      find.widgetWithText(TextField, 'Enter group name'),
      'Team Alpha',
    );
    await tester.tap(find.text('Password Protected'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create Group'));
    await tester.pumpAndSettle();

    expect(find.text('Enter a password'), findsOneWidget);
    expect(container.read(sessionProvider), isA<SessionIdle>());
  });

  testWidgets('limits the name to the advertised byte budget',
      (tester) async {
    await openCreateScreen(tester);

    await tester.enterText(
      find.widgetWithText(TextField, 'Enter group name'),
      'a' * (ProtocolLimits.maxGroupNameBytes + 10),
    );
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(
      find.widgetWithText(TextField, 'Enter group name'),
    );

    expect(
      field.controller!.text.length,
      ProtocolLimits.maxGroupNameBytes,
    );
  });

  testWidgets('counts multi-byte characters against the byte budget',
      (tester) async {
    await openCreateScreen(tester);

    await tester.enterText(
      find.widgetWithText(TextField, 'Enter group name'),
      'ü' * 20, // 40 bytes
    );
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(
      find.widgetWithText(TextField, 'Enter group name'),
    );

    // 14 two-byte characters is 28 bytes; a fifteenth would exceed 29.
    expect(field.controller!.text.length, 14);
  });

  testWidgets('creates an open group and opens the group screen',
      (tester) async {
    await openCreateScreen(tester);

    await tester.enterText(
      find.widgetWithText(TextField, 'Enter group name'),
      'Team Alpha',
    );
    await tester.tap(find.text('Create Group'));
    await tester.pumpAndSettle();

    final state = container.read(sessionProvider) as SessionConnected;

    expect(state.groupName, 'Team Alpha');
    expect(state.isHost, isTrue);
  });

  testWidgets('creates a password group', (tester) async {
    await openCreateScreen(tester);

    await tester.enterText(
      find.widgetWithText(TextField, 'Enter group name'),
      'Team Alpha',
    );
    await tester.tap(find.text('Password Protected'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Enter password'),
      'hunter2',
    );
    await tester.tap(find.text('Create Group'));
    await tester.pumpAndSettle();

    expect(container.read(sessionProvider), isA<SessionConnected>());
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/ui/create_group_screen_test.dart`
Expected: FAIL — `Group Name` not found (the route is still a placeholder)

- [ ] **Step 3: Create the byte-limit formatter**

Create `lib/ui/common/utf8_byte_limit_formatter.dart`:

```dart
import 'dart:convert';

import 'package:flutter/services.dart';

/// Caps input at [maxBytes] encoded as UTF-8.
///
/// Character count is the wrong measure here: the group name has to fit the
/// BLE scan response, which is a byte budget (spec section 5.1).
class Utf8ByteLimitFormatter extends TextInputFormatter {
  const Utf8ByteLimitFormatter(this.maxBytes);

  final int maxBytes;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (utf8.encode(newValue.text).length <= maxBytes) return newValue;

    // Trim whole code points until the encoding fits, so a multi-byte
    // character is never cut in half. Uses runes rather than
    // `String.characters` to avoid depending on package:characters.
    var text = newValue.text;
    while (text.isNotEmpty && utf8.encode(text).length > maxBytes) {
      final runes = text.runes.toList()..removeLast();
      text = String.fromCharCodes(runes);
    }

    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
```

This deliberately uses `runes` (code points) rather than `String.characters`
(grapheme clusters). Grapheme clusters would be marginally more correct for
emoji sequences, but `characters` is not a direct dependency and importing it
would trip the `depend_on_referenced_packages` lint. Runes never produce
invalid UTF-8, which is the property that matters here.

- [ ] **Step 4: Create the screen**

Create `lib/ui/create/create_group_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../domain/models/group_config.dart';
import '../../domain/models/session_state.dart';
import '../../domain/protocol/protocol_limits.dart';
import '../../state/display_name_provider.dart';
import '../../state/recent_groups_provider.dart';
import '../../state/session_provider.dart';
import '../common/utf8_byte_limit_formatter.dart';

class CreateGroupScreen extends ConsumerStatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  ConsumerState<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends ConsumerState<CreateGroupScreen> {
  final _name = TextEditingController();
  final _password = TextEditingController();

  bool _locked = false;
  bool _obscure = true;
  bool _busy = false;
  String? _nameError;
  String? _passwordError;

  @override
  void dispose() {
    _name.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = _name.text.trim();
    final password = _password.text;

    setState(() {
      _nameError = name.isEmpty ? 'Enter a group name' : null;
      _passwordError =
          _locked && password.isEmpty ? 'Enter a password' : null;
    });

    if (_nameError != null || _passwordError != null) return;

    setState(() => _busy = true);

    final displayName = await ref.read(displayNameProvider.future);
    await ref.read(sessionProvider.notifier).createGroup(
          GroupConfig(name: name, password: _locked ? password : null),
          displayName: displayName,
        );

    final state = ref.read(sessionProvider);
    if (state is SessionConnected) {
      await ref.read(recentGroupsProvider.notifier).record(
            groupId: state.groupId,
            name: state.groupName,
            memberCount: state.roster.length,
          );
    }

    if (!mounted) return;
    setState(() => _busy = false);

    if (state is SessionConnected) context.go('/group');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create New Group')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Center(
              child: CircleAvatar(
                radius: 44,
                backgroundColor: AppColors.accent,
                child: Icon(Icons.groups, size: 40, color: Colors.white),
              ),
            ),
            const SizedBox(height: 28),
            const _Label('Group Name'),
            TextField(
              controller: _name,
              inputFormatters: const [
                Utf8ByteLimitFormatter(ProtocolLimits.maxGroupNameBytes),
              ],
              decoration: InputDecoration(
                hintText: 'Enter group name',
                filled: true,
                fillColor: AppColors.surface,
                errorText: _nameError,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            const _Label('Security'),
            _SecurityOption(
              icon: Icons.public,
              title: 'Open Group',
              subtitle: 'Anyone can join',
              selected: !_locked,
              onTap: () => setState(() => _locked = false),
            ),
            const SizedBox(height: 8),
            _SecurityOption(
              icon: Icons.lock,
              title: 'Password Protected',
              subtitle: 'Only with password',
              selected: _locked,
              onTap: () => setState(() => _locked = true),
            ),
            const SizedBox(height: 24),
            const _Label('Password (optional)'),
            TextField(
              controller: _password,
              enabled: _locked,
              obscureText: _obscure,
              decoration: InputDecoration(
                hintText: 'Enter password',
                filled: true,
                fillColor: AppColors.surface,
                errorText: _passwordError,
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscure ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _busy ? null : _create,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: const Size.fromHeight(52),
              ),
              child: _busy
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Create Group'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
          ),
        ),
      );
}

class _SecurityOption extends StatelessWidget {
  const _SecurityOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(icon, color: AppColors.textSecondary, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: selected ? AppColors.active : AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Wire the route**

In `lib/core/router/app_router.dart`, add the import and replace the
`create` route builder:

```dart
import '../../ui/create/create_group_screen.dart';
```

```dart
        GoRoute(
          path: 'create',
          builder: (context, state) => const CreateGroupScreen(),
        ),
```

- [ ] **Step 6: Strengthen the home navigation test**

In `test/ui/home_screen_test.dart`, replace the body of the
`tapping Create New Group navigates away from home` test with:

```dart
    await pumpApp(tester);

    await tester.tap(find.text('Create New Group'));
    await tester.pumpAndSettle();

    expect(find.text('Group Name'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
```

- [ ] **Step 7: Run the tests**

Run: `flutter test test/ui`
Expected: PASS (all home and create-screen tests)

- [ ] **Step 8: Commit**

```bash
git add lib/ui lib/core/router test/ui
git commit -m "feat: add create group screen with byte-limited name field"
```

---

### Task 16: Discover screen

**Files:**
- Create: `lib/ui/discover/discover_screen.dart`
- Create: `lib/ui/discover/widgets/group_tile.dart`
- Create: `lib/ui/discover/widgets/signal_bars.dart`
- Modify: `lib/core/router/app_router.dart` (replace the `/discover` placeholder)
- Test: `test/ui/discover_screen_test.dart`

**Interfaces:**
- Consumes: `discoveredGroupsProvider` (Task 12), `sessionProvider`, `displayNameProvider`, `recentGroupsProvider` (Tasks 11, 13), `DiscoveredGroup` (Task 2)
- Produces:
  - `class SignalBars extends StatelessWidget({required int rssi})` — 4 bars, filled by strength
  - `class GroupTile extends StatelessWidget({required DiscoveredGroup group, required VoidCallback? onTap})`
  - `class DiscoverScreen extends ConsumerWidget`

An open group joins immediately on tap. A locked group pushes `/join` with the
group as `extra`. A full group is not tappable, since the advertisement
already says so (spec §8).

RSSI → bars: `>= -55` is 4, `>= -67` is 3, `>= -80` is 2, otherwise 1.

- [ ] **Step 1: Write the failing test**

Create `test/ui/discover_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bconnect/app.dart';
import 'package:bconnect/domain/models/group_config.dart';
import 'package:bconnect/domain/models/session_state.dart';
import 'package:bconnect/state/session_provider.dart';
import 'package:bconnect/state/transport_provider.dart';
import 'package:bconnect/transport/fake/fake_hub.dart';
import 'package:bconnect/transport/fake/fake_transport.dart';
import 'package:bconnect/ui/discover/widgets/group_tile.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeHub hub;
  late FakeTransport transport;
  late ProviderContainer container;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    hub = FakeHub();
    transport = FakeTransport(hub, deviceId: 'me');
  });

  tearDown(() async => transport.dispose());

  /// Starts a real host session on its own transport, so the advertised
  /// group is genuinely joinable.
  Future<ProviderContainer> startHost(
    String name, {
    String? password,
    String deviceId = 'host',
  }) async {
    final hostTransport = FakeTransport(hub, deviceId: deviceId);
    addTearDown(hostTransport.dispose);

    final hostContainer = ProviderContainer(
      overrides: [transportProvider.overrideWithValue(hostTransport)],
    );
    addTearDown(hostContainer.dispose);

    await hostContainer.read(sessionProvider.notifier).createGroup(
          GroupConfig(name: name, password: password),
          displayName: 'Host',
        );

    return hostContainer;
  }

  Future<void> openDiscover(WidgetTester tester) async {
    container = ProviderContainer(
      overrides: [transportProvider.overrideWithValue(transport)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const BconnectApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Join Existing Group'));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the scanning header and a refresh control',
      (tester) async {
    await openDiscover(tester);

    expect(find.text('Join Group'), findsOneWidget);
    expect(find.text('Scanning for nearby groups...'), findsOneWidget);
    expect(find.text('Refresh'), findsOneWidget);
  });

  testWidgets('starts scanning on the transport', (tester) async {
    await openDiscover(tester);

    expect(transport.isScanning, isTrue);
  });

  testWidgets('lists a nearby group with its member count', (tester) async {
    await startHost('Team Alpha');
    await openDiscover(tester);

    expect(find.text('Team Alpha'), findsOneWidget);
    expect(find.text('1 Member'), findsOneWidget);
  });

  testWidgets('pluralises the member count', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GroupTile(
            group: DiscoveredGroup(
              groupId: '0001',
              deviceId: 'h',
              name: 'Project Beta',
              memberCount: 2,
              isLocked: false,
              isFull: false,
              rssi: -55,
              lastSeen: DateTime(2026, 8, 26),
            ),
            onTap: () {},
          ),
        ),
      ),
    );

    expect(find.text('2 Members'), findsOneWidget);
  });

  testWidgets('shows a closed padlock for a password group', (tester) async {
    await startHost('Team Gamma', password: 'hunter2');
    await openDiscover(tester);

    final tile = tester.widget<GroupTile>(find.byType(GroupTile));

    expect(tile.group.isLocked, isTrue);
    expect(find.byIcon(Icons.lock), findsOneWidget);
  });

  testWidgets('shows an open padlock for an open group', (tester) async {
    await startHost('Open Group');
    await openDiscover(tester);

    expect(find.byIcon(Icons.lock_open), findsOneWidget);
  });

  testWidgets('tapping an open group joins it and opens the group screen',
      (tester) async {
    await startHost('Team Alpha');
    await openDiscover(tester);

    await tester.tap(find.text('Team Alpha'));
    await tester.pumpAndSettle();

    final state = container.read(sessionProvider) as SessionConnected;

    expect(state.groupName, 'Team Alpha');
    expect(state.isHost, isFalse);
  });

  testWidgets('tapping a locked group does not join it directly',
      (tester) async {
    await startHost('Team Gamma', password: 'hunter2');
    await openDiscover(tester);

    await tester.tap(find.text('Team Gamma'));
    await tester.pumpAndSettle();

    // Navigated to /join rather than joining; Task 17 asserts on its content.
    expect(container.read(sessionProvider), isA<SessionIdle>());
    expect(find.byType(GroupTile), findsNothing);
  });

  testWidgets('lists several groups at once', (tester) async {
    await startHost('Team Alpha', deviceId: 'h1');
    await startHost('Project Beta', deviceId: 'h2');
    await openDiscover(tester);

    expect(find.byType(GroupTile), findsNWidgets(2));
  });

  testWidgets('stops scanning when the screen is closed', (tester) async {
    await openDiscover(tester);
    expect(transport.isScanning, isTrue);

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(transport.isScanning, isFalse);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/ui/discover_screen_test.dart`
Expected: FAIL — `Scanning for nearby groups...` not found

- [ ] **Step 3: Create the signal bars**

Create `lib/ui/discover/widgets/signal_bars.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Four ascending bars, filled according to RSSI.
class SignalBars extends StatelessWidget {
  const SignalBars({required this.rssi, super.key});

  final int rssi;

  int get _strength {
    if (rssi >= -55) return 4;
    if (rssi >= -67) return 3;
    if (rssi >= -80) return 2;
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 1; i <= 4; i++) ...[
          Container(
            width: 3,
            height: 4.0 * i,
            decoration: BoxDecoration(
              color: i <= _strength
                  ? AppColors.active
                  : AppColors.textSecondary.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(1),
            ),
          ),
          if (i < 4) const SizedBox(width: 2),
        ],
      ],
    );
  }
}
```

- [ ] **Step 4: Create the group tile**

Create `lib/ui/discover/widgets/group_tile.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../domain/models/discovered_group.dart';
import 'signal_bars.dart';

class GroupTile extends StatelessWidget {
  const GroupTile({required this.group, required this.onTap, super.key});

  final DiscoveredGroup group;

  /// Null when the group cannot be joined, which is how a full group is
  /// shown as unavailable before it is tapped (spec section 8).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final members =
        group.memberCount == 1 ? '1 Member' : '${group.memberCount} Members';

    return Opacity(
      opacity: onTap == null ? 0.5 : 1,
      child: Card(
        margin: const EdgeInsets.only(bottom: 10),
        child: ListTile(
          onTap: onTap,
          title: Text(
            group.name,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            group.isFull ? '$members · Full' : members,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                group.isLocked ? Icons.lock : Icons.lock_open,
                size: 18,
                color: group.isLocked
                    ? AppColors.accent
                    : AppColors.textSecondary,
              ),
              const SizedBox(width: 12),
              SignalBars(rssi: group.rssi),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Create the discover screen**

Create `lib/ui/discover/discover_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../domain/models/discovered_group.dart';
import '../../domain/models/session_state.dart';
import '../../state/discovered_groups_provider.dart';
import '../../state/display_name_provider.dart';
import '../../state/recent_groups_provider.dart';
import '../../state/session_provider.dart';
import 'widgets/group_tile.dart';

class DiscoverScreen extends ConsumerWidget {
  const DiscoverScreen({super.key});

  Future<void> _join(
    BuildContext context,
    WidgetRef ref,
    DiscoveredGroup group,
  ) async {
    if (group.isLocked) {
      context.push('/join', extra: group);
      return;
    }

    final displayName = await ref.read(displayNameProvider.future);
    await ref
        .read(sessionProvider.notifier)
        .joinGroup(group, displayName: displayName);

    final state = ref.read(sessionProvider);
    if (state is SessionConnected) {
      await ref.read(recentGroupsProvider.notifier).record(
            groupId: state.groupId,
            name: state.groupName,
            memberCount: state.roster.length,
          );
      if (context.mounted) context.go('/group');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(discoveredGroupsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Join Group')),
      body: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Scanning for nearby groups...',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                  SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ],
              ),
            ),
            Expanded(
              child: switch (groups) {
                AsyncData(value: final list) when list.isEmpty => const Center(
                    child: Text(
                      'No groups found nearby',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                AsyncData(value: final list) => ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: [
                      for (final g in list)
                        GroupTile(
                          group: g,
                          onTap:
                              g.isFull ? null : () => _join(context, ref, g),
                        ),
                    ],
                  ),
                AsyncError(:final error) => Center(
                    child: Text(
                      'Scan failed: $error',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                _ => const Center(child: CircularProgressIndicator()),
              },
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextButton.icon(
                onPressed: () => ref.invalidate(discoveredGroupsProvider),
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 6: Wire the route**

In `lib/core/router/app_router.dart`, add the import and replace the
`discover` route builder:

```dart
import '../../ui/discover/discover_screen.dart';
```

```dart
        GoRoute(
          path: 'discover',
          builder: (context, state) => const DiscoverScreen(),
        ),
```

- [ ] **Step 7: Run the tests**

Run: `flutter test test/ui/discover_screen_test.dart`
Expected: PASS (10 tests)

Also add `import 'package:bconnect/domain/models/discovered_group.dart';` to
the test file for the pluralisation case.

- [ ] **Step 8: Commit**

```bash
git add lib/ui/discover lib/core/router test/ui
git commit -m "feat: add discover screen with signal strength and lock state"
```

---

### Task 17: Join password screen

**Files:**
- Create: `lib/ui/join/join_password_screen.dart`
- Modify: `lib/core/router/app_router.dart` (replace the `/join` placeholder)
- Test: `test/ui/join_password_screen_test.dart`

**Interfaces:**
- Consumes: `sessionProvider`, `displayNameProvider`, `recentGroupsProvider`, `DiscoveredGroup`, `SessionError`
- Produces: `class JoinPasswordScreen extends ConsumerStatefulWidget({required DiscoveredGroup group})`

The group arrives as the route's `extra`. A wrong password keeps the user on
this screen with an inline error (spec §8) rather than bouncing them back to
the list.

- [ ] **Step 1: Write the failing test**

Create `test/ui/join_password_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bconnect/app.dart';
import 'package:bconnect/domain/models/group_config.dart';
import 'package:bconnect/domain/models/session_state.dart';
import 'package:bconnect/state/session_provider.dart';
import 'package:bconnect/state/transport_provider.dart';
import 'package:bconnect/transport/fake/fake_hub.dart';
import 'package:bconnect/transport/fake/fake_transport.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeHub hub;
  late FakeTransport transport;
  late ProviderContainer container;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    hub = FakeHub();
    transport = FakeTransport(hub, deviceId: 'me');
  });

  tearDown(() async => transport.dispose());

  /// Opens the password screen by driving the real discover flow.
  Future<void> openJoinScreen(WidgetTester tester) async {
    final hostTransport = FakeTransport(hub, deviceId: 'host');
    addTearDown(hostTransport.dispose);
    final hostContainer = ProviderContainer(
      overrides: [transportProvider.overrideWithValue(hostTransport)],
    );
    addTearDown(hostContainer.dispose);

    await hostContainer.read(sessionProvider.notifier).createGroup(
          const GroupConfig(name: 'Team Alpha', password: 'hunter2'),
          displayName: 'Host',
        );

    container = ProviderContainer(
      overrides: [transportProvider.overrideWithValue(transport)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const BconnectApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Join Existing Group'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Team Alpha'));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the group name and the protected notice', (tester) async {
    await openJoinScreen(tester);

    expect(find.text('Team Alpha'), findsOneWidget);
    expect(find.text('This group is password protected'), findsOneWidget);
    expect(find.text('Enter Password'), findsOneWidget);
    expect(find.text('Join Group'), findsWidgets);
    expect(find.text('Cancel'), findsOneWidget);
  });

  testWidgets('obscures the password until the reveal is tapped',
      (tester) async {
    await openJoinScreen(tester);

    expect(
      tester
          .widget<TextField>(find.widgetWithText(TextField, 'Enter Password'))
          .obscureText,
      isTrue,
    );

    await tester.tap(find.byIcon(Icons.visibility));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<TextField>(find.widgetWithText(TextField, 'Enter Password'))
          .obscureText,
      isFalse,
    );
  });

  testWidgets('refuses an empty password', (tester) async {
    await openJoinScreen(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Join Group'));
    await tester.pumpAndSettle();

    expect(find.text('Enter a password'), findsOneWidget);
    expect(container.read(sessionProvider), isA<SessionIdle>());
  });

  testWidgets('joins with the correct password', (tester) async {
    await openJoinScreen(tester);

    await tester.enterText(
      find.widgetWithText(TextField, 'Enter Password'),
      'hunter2',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Join Group'));
    await tester.pumpAndSettle();

    final state = container.read(sessionProvider) as SessionConnected;

    expect(state.groupName, 'Team Alpha');
    expect(state.isHost, isFalse);
  });

  testWidgets('stays on the screen and explains a wrong password',
      (tester) async {
    await openJoinScreen(tester);

    await tester.enterText(
      find.widgetWithText(TextField, 'Enter Password'),
      'wrong',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Join Group'));
    await tester.pumpAndSettle();

    expect(find.text('Incorrect password'), findsOneWidget);
    expect(find.text('This group is password protected'), findsOneWidget);
  });

  testWidgets('cancel returns to the group list', (tester) async {
    await openJoinScreen(tester);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Scanning for nearby groups...'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/ui/join_password_screen_test.dart`
Expected: FAIL — `This group is password protected` not found

- [ ] **Step 3: Create the screen**

Create `lib/ui/join/join_password_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../domain/models/discovered_group.dart';
import '../../domain/models/session_state.dart';
import '../../state/display_name_provider.dart';
import '../../state/recent_groups_provider.dart';
import '../../state/session_provider.dart';

class JoinPasswordScreen extends ConsumerStatefulWidget {
  const JoinPasswordScreen({required this.group, super.key});

  final DiscoveredGroup group;

  @override
  ConsumerState<JoinPasswordScreen> createState() =>
      _JoinPasswordScreenState();
}

class _JoinPasswordScreenState extends ConsumerState<JoinPasswordScreen> {
  final _password = TextEditingController();

  bool _obscure = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    if (_password.text.isEmpty) {
      setState(() => _error = 'Enter a password');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    final displayName = await ref.read(displayNameProvider.future);
    await ref.read(sessionProvider.notifier).joinGroup(
          widget.group,
          password: _password.text,
          displayName: displayName,
        );

    final state = ref.read(sessionProvider);
    if (!mounted) return;

    switch (state) {
      case SessionConnected():
        await ref.read(recentGroupsProvider.notifier).record(
              groupId: state.groupId,
              name: state.groupName,
              memberCount: state.roster.length,
            );
        if (mounted) context.go('/group');
      case SessionFailed(:final error):
        // Stay put so the password can be corrected (spec section 8).
        ref.read(sessionProvider.notifier).reset();
        setState(() {
          _busy = false;
          _error = switch (error) {
            SessionError.wrongPassword => 'Incorrect password',
            SessionError.groupFull => 'That group is full',
            SessionError.incompatibleVersion => 'Incompatible app version',
            _ => 'Could not join the group',
          };
        });
      case _:
        setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Join Group')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const SizedBox(height: 20),
            const Center(
              child: CircleAvatar(
                radius: 44,
                backgroundColor: AppColors.accent,
                child: Icon(Icons.lock, size: 38, color: Colors.white),
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: Text(
                widget.group.name,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
            const SizedBox(height: 6),
            const Center(
              child: Text(
                'This group is password protected',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
            const SizedBox(height: 36),
            const Text(
              'Enter Password',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _password,
              obscureText: _obscure,
              autofocus: true,
              onSubmitted: (_) => _join(),
              decoration: InputDecoration(
                hintText: 'Enter Password',
                filled: true,
                fillColor: AppColors.surface,
                errorText: _error,
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscure ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
            ),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: _busy ? null : _join,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: const Size.fromHeight(52),
              ),
              child: _busy
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Join Group'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _busy ? null : () => context.pop(),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Wire the route**

In `lib/core/router/app_router.dart`, add the imports and replace the `join`
route builder. The group travels as `extra`:

```dart
import '../../domain/models/discovered_group.dart';
import '../../ui/join/join_password_screen.dart';
```

```dart
        GoRoute(
          path: 'join',
          builder: (context, state) => JoinPasswordScreen(
            group: state.extra! as DiscoveredGroup,
          ),
        ),
```

- [ ] **Step 5: Run the tests**

Run: `flutter test test/ui`
Expected: PASS (all home, create, discover, and join tests)

- [ ] **Step 6: Commit**

```bash
git add lib/ui/join lib/core/router test/ui
git commit -m "feat: add join password screen with inline error handling"
```

---

### Task 18: Group screen and call controls

**Files:**
- Create: `lib/ui/group/group_screen.dart`
- Create: `lib/ui/group/widgets/member_tile.dart`
- Create: `lib/ui/group/widgets/call_controls.dart`
- Modify: `lib/core/router/app_router.dart` (replace the `/group` placeholder)
- Test: `test/ui/group_screen_test.dart`

**Interfaces:**
- Consumes: `sessionProvider`, `micProvider`, `SessionState`, `Member`, `MemberPresence`
- Produces:
  - `class MemberTile extends StatelessWidget({required Member member})`
  - `class CallControls extends StatelessWidget({required bool muted, required bool talking, required VoidCallback onSpeaker, required VoidCallback onToggleMute, required VoidCallback onTalkStart, required VoidCallback onTalkStop, required VoidCallback onEndCall})`
  - `class GroupScreen extends ConsumerWidget`

This single screen serves drawings 3, 6 and 8. It uses drawing 8's full-width
red End Call button throughout, in preference to the text link in 3 and 6, for
touch-target size (spec §6.3).

**Talk button is hold-to-talk**, matching spec §3.3 ("anyone who holds the talk
button transmits"). The label stays "Tap to Speak" as drawn.

A member's label is `You (Admin)` when they are both self and host, `You` when
self, otherwise their display name.

- [ ] **Step 1: Write the failing test**

Create `test/ui/group_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bconnect/app.dart';
import 'package:bconnect/domain/models/group_config.dart';
import 'package:bconnect/domain/models/session_state.dart';
import 'package:bconnect/state/mic_provider.dart';
import 'package:bconnect/state/session_provider.dart';
import 'package:bconnect/state/transport_provider.dart';
import 'package:bconnect/transport/fake/fake_hub.dart';
import 'package:bconnect/transport/fake/fake_transport.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeHub hub;
  late FakeTransport transport;
  late ProviderContainer container;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    hub = FakeHub();
    transport = FakeTransport(hub, deviceId: 'me');
  });

  tearDown(() async => transport.dispose());

  /// Creates a group through the real UI so the screen renders live state.
  Future<void> hostAGroup(WidgetTester tester) async {
    container = ProviderContainer(
      overrides: [transportProvider.overrideWithValue(transport)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const BconnectApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create New Group'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Enter group name'),
      'Team Alpha',
    );
    await tester.tap(find.text('Create Group'));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the group name, status, and controls', (tester) async {
    await hostAGroup(tester);

    expect(find.text('Team Alpha'), findsOneWidget);
    expect(find.text('Group is Active'), findsOneWidget);
    expect(find.text('Members'), findsOneWidget);
    expect(find.text('Invite'), findsOneWidget);
    expect(find.text('Speaker'), findsOneWidget);
    expect(find.text('Tap to Speak'), findsOneWidget);
    expect(find.text('Mute'), findsOneWidget);
    expect(find.text('End Call'), findsOneWidget);
  });

  testWidgets('labels the host as You (Admin)', (tester) async {
    await hostAGroup(tester);

    expect(find.text('You (Admin)'), findsOneWidget);
    expect(find.text('Online'), findsOneWidget);
  });

  testWidgets('shows the member count badge', (tester) async {
    await hostAGroup(tester);

    expect(find.text('1 Member'), findsOneWidget);
  });

  testWidgets('lists a member that joins', (tester) async {
    await hostAGroup(tester);

    final other = FakeTransport(hub, deviceId: 'other');
    addTearDown(other.dispose);
    final otherContainer = ProviderContainer(
      overrides: [transportProvider.overrideWithValue(other)],
    );
    addTearDown(otherContainer.dispose);

    final found = other.events.whereType<ScanResultEvent>().first;
    await other.startScan();

    await otherContainer.read(sessionProvider.notifier).joinGroup(
          (await found).group,
          displayName: 'Device 1',
        );
    await tester.pumpAndSettle();

    expect(find.text('Device 1'), findsOneWidget);
    expect(find.text('2 Members'), findsOneWidget);
  });

  testWidgets('holding the talk button transmits, releasing stops',
      (tester) async {
    await hostAGroup(tester);

    final gesture =
        await tester.startGesture(tester.getCenter(find.text('Tap to Speak')));
    await tester.pumpAndSettle();

    expect(transport.isTalking, isTrue);

    await gesture.up();
    await tester.pumpAndSettle();

    expect(transport.isTalking, isFalse);
  });

  testWidgets('the mute button toggles the mic', (tester) async {
    await hostAGroup(tester);

    await tester.tap(find.text('Mute'));
    await tester.pumpAndSettle();

    expect(container.read(micProvider).muted, isTrue);
    expect(transport.micEnabled, isFalse);

    await tester.tap(find.text('Mute'));
    await tester.pumpAndSettle();

    expect(container.read(micProvider).muted, isFalse);
  });

  testWidgets('a muted mic refuses to transmit', (tester) async {
    await hostAGroup(tester);

    await tester.tap(find.text('Mute'));
    await tester.pumpAndSettle();

    final gesture =
        await tester.startGesture(tester.getCenter(find.text('Tap to Speak')));
    await tester.pumpAndSettle();

    expect(transport.isTalking, isFalse);

    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('the speaker button opens the audio output screen',
      (tester) async {
    await hostAGroup(tester);

    await tester.tap(find.text('Speaker'));
    await tester.pumpAndSettle();

    expect(find.text('Audio Output'), findsWidgets);
  });

  testWidgets('End Call leaves the group and returns home', (tester) async {
    await hostAGroup(tester);

    await tester.tap(find.text('End Call'));
    await tester.pumpAndSettle();

    expect(container.read(sessionProvider), isA<SessionIdle>());
    expect(find.text('Group Talk'), findsOneWidget);
  });

  testWidgets('returns home when the host ends the group', (tester) async {
    // This device is a client; the host tears the group down underneath it.
    final hostTransport = FakeTransport(hub, deviceId: 'host');
    addTearDown(hostTransport.dispose);
    final hostContainer = ProviderContainer(
      overrides: [transportProvider.overrideWithValue(hostTransport)],
    );
    addTearDown(hostContainer.dispose);

    await hostContainer.read(sessionProvider.notifier).createGroup(
          const GroupConfig(name: 'Team Alpha'),
          displayName: 'Host',
        );

    container = ProviderContainer(
      overrides: [transportProvider.overrideWithValue(transport)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const BconnectApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Join Existing Group'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Team Alpha'));
    await tester.pumpAndSettle();

    expect(find.text('Group is Active'), findsOneWidget);

    await hostContainer.read(sessionProvider.notifier).leave();
    await tester.pumpAndSettle();

    expect(find.text('Group Talk'), findsOneWidget);
    expect(find.text('Group ended by host'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/ui/group_screen_test.dart`
Expected: FAIL — `Group is Active` not found

- [ ] **Step 3: Create the member tile**

Create `lib/ui/group/widgets/member_tile.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../domain/models/member.dart';

class MemberTile extends StatelessWidget {
  const MemberTile({required this.member, super.key});

  final Member member;

  String get _label {
    if (member.isSelf) return member.isHost ? 'You (Admin)' : 'You';
    return member.displayName;
  }

  String get _presence => switch (member.presence) {
        MemberPresence.online => 'Online',
        MemberPresence.reconnecting => 'Reconnecting',
        MemberPresence.offline => 'Offline',
      };

  Color get _presenceColor => switch (member.presence) {
        MemberPresence.online => AppColors.active,
        MemberPresence.reconnecting => Colors.amber,
        MemberPresence.offline => AppColors.textSecondary,
      };

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.surfaceRaised,
          child: Icon(
            member.isTalking ? Icons.graphic_eq : Icons.person,
            color: member.isTalking
                ? AppColors.active
                : AppColors.textSecondary,
          ),
        ),
        title: Text(
          _label,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          _presence,
          style: TextStyle(color: _presenceColor, fontSize: 12),
        ),
        trailing: Container(
          height: 8,
          width: 8,
          decoration: BoxDecoration(
            color: _presenceColor,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Create the call controls**

Create `lib/ui/group/widgets/call_controls.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

class CallControls extends StatelessWidget {
  const CallControls({
    required this.muted,
    required this.talking,
    required this.onSpeaker,
    required this.onToggleMute,
    required this.onTalkStart,
    required this.onTalkStop,
    required this.onEndCall,
    super.key,
  });

  final bool muted;
  final bool talking;
  final VoidCallback onSpeaker;
  final VoidCallback onToggleMute;
  final VoidCallback onTalkStart;
  final VoidCallback onTalkStop;
  final VoidCallback onEndCall;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _RoundButton(
              icon: Icons.volume_up,
              label: 'Speaker',
              background: AppColors.active,
              onTap: onSpeaker,
            ),
            // Hold to transmit (spec section 3.3); the label follows the
            // mockups.
            GestureDetector(
              onTapDown: (_) => onTalkStart(),
              onTapUp: (_) => onTalkStop(),
              onTapCancel: onTalkStop,
              child: Column(
                children: [
                  Container(
                    height: 76,
                    width: 76,
                    decoration: BoxDecoration(
                      color: talking ? AppColors.active : AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.mic,
                      size: 34,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Tap to Speak',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            _RoundButton(
              icon: muted ? Icons.mic_off : Icons.mic_none,
              label: 'Mute',
              background:
                  muted ? AppColors.danger : AppColors.surfaceRaised,
              onTap: onToggleMute,
            ),
          ],
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: onEndCall,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.danger,
            minimumSize: const Size.fromHeight(52),
          ),
          child: const Text('End Call'),
        ),
      ],
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.label,
    required this.background,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color background;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            height: 52,
            width: 52,
            decoration: BoxDecoration(
              color: background,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: Create the group screen**

Create `lib/ui/group/group_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../domain/models/session_state.dart';
import '../../state/mic_provider.dart';
import '../../state/session_provider.dart';
import 'widgets/call_controls.dart';
import 'widgets/member_tile.dart';

/// Serves drawings 3, 6 and 8 — one screen, three states.
class GroupScreen extends ConsumerWidget {
  const GroupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // A group can end underneath us, so failures navigate home with an
    // explanation rather than leaving a dead screen (spec section 8).
    ref.listen<SessionState>(sessionProvider, (previous, next) {
      if (next is! SessionFailed) return;

      final message = switch (next.error) {
        SessionError.hostLeft => 'Group ended by host',
        SessionError.connectionLost => 'Connection lost',
        SessionError.groupFull => 'That group is full',
        _ => 'Left the group',
      };

      ref.read(sessionProvider.notifier).reset();
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
      context.go('/');
    });

    final session = ref.watch(sessionProvider);
    final mic = ref.watch(micProvider);

    if (session is! SessionConnected) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final count = session.roster.length;
    // `firstOrNull` lives in package:collection, which is not a direct
    // dependency, so use `any` instead.
    final iAmTalking = session.roster
        .any((m) => m.id == session.myMemberId && m.isTalking);

    return Scaffold(
      appBar: AppBar(
        title: Text(session.groupName),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.push('/group/audio'),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),
            CircleAvatar(
              radius: 44,
              backgroundColor: AppColors.active,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.groups, color: Colors.white, size: 26),
                  Text(
                    count == 1 ? '1 Member' : '$count Members',
                    style: const TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.circle, size: 8, color: AppColors.active),
                SizedBox(width: 6),
                Text(
                  'Group is Active',
                  style: TextStyle(color: AppColors.active, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Members',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Ask others to open Join Group to find this group',
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Invite'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  for (final m in session.roster) MemberTile(member: m),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: CallControls(
                muted: mic.muted,
                talking: iAmTalking,
                onSpeaker: () => context.push('/group/audio'),
                onToggleMute: () =>
                    ref.read(micProvider.notifier).toggleMute(),
                onTalkStart: () async {
                  // A muted mic never transmits.
                  if (ref.read(micProvider).muted) return;

                  final granted =
                      await ref.read(sessionProvider.notifier).requestTalk();
                  if (!granted && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Too many people talking')),
                    );
                    return;
                  }
                  ref.read(micProvider.notifier).setTransmitting(true);
                },
                onTalkStop: () async {
                  await ref.read(sessionProvider.notifier).stopTalk();
                  ref.read(micProvider.notifier).setTransmitting(false);
                },
                onEndCall: () async {
                  await ref.read(sessionProvider.notifier).leave();
                  if (context.mounted) context.go('/');
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 6: Wire the route**

In `lib/core/router/app_router.dart`, add the import and replace the `group`
route builder, keeping its nested `audio` route:

```dart
import '../../ui/group/group_screen.dart';
```

```dart
        GoRoute(
          path: 'group',
          builder: (context, state) => const GroupScreen(),
          routes: [
            GoRoute(
              path: 'audio',
              builder: (context, state) => const _Pending('Audio Output'),
            ),
          ],
        ),
```

- [ ] **Step 7: Run the tests**

Run: `flutter test test/ui/group_screen_test.dart`
Expected: PASS (10 tests)

- [ ] **Step 8: Commit**

```bash
git add lib/ui/group lib/core/router test/ui
git commit -m "feat: add group screen with hold-to-talk and call controls"
```

---

### Task 19: Audio output and settings screens

**Files:**
- Create: `lib/ui/audio/audio_output_screen.dart`
- Rewrite: `lib/ui/settings/settings_screen.dart`
- Modify: `lib/core/router/app_router.dart` (replace the `/group/audio` placeholder, remove `_Pending`)
- Test: `test/ui/audio_and_settings_test.dart`

**Interfaces:**
- Consumes: `audioRouteProvider`, `displayNameProvider`, `recentGroupsProvider`, `peripheralSupportedProvider`
- Produces: `class AudioOutputScreen extends ConsumerWidget`; `class SettingsScreen extends ConsumerStatefulWidget({bool embedded})`

`_Pending` is deleted in this task: every route now has a real screen.

- [ ] **Step 1: Write the failing test**

Create `test/ui/audio_and_settings_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bconnect/app.dart';
import 'package:bconnect/domain/models/audio.dart';
import 'package:bconnect/state/audio_route_provider.dart';
import 'package:bconnect/state/display_name_provider.dart';
import 'package:bconnect/state/transport_provider.dart';
import 'package:bconnect/transport/fake/fake_hub.dart';
import 'package:bconnect/transport/fake/fake_transport.dart';
import 'package:bconnect/ui/audio/audio_output_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeTransport transport;
  late ProviderContainer container;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    transport = FakeTransport(FakeHub(), deviceId: 'me');
  });

  tearDown(() async => transport.dispose());

  Future<void> pumpApp(WidgetTester tester) async {
    container = ProviderContainer(
      overrides: [transportProvider.overrideWithValue(transport)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const BconnectApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openAudioScreen(WidgetTester tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('Create New Group'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Enter group name'),
      'Team Alpha',
    );
    await tester.tap(find.text('Create Group'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Speaker'));
    await tester.pumpAndSettle();
  }

  group('audio output', () {
    // Note: a pushed route leaves the group screen in the widget tree
    // beneath it, so `find.text('Speaker')` can match twice. Scope finders
    // with `find.descendant(of: find.byType(AudioOutputScreen), ...)`
    // wherever a label appears on both screens.

    testWidgets('lists both routes and the explanatory note', (tester) async {
      await openAudioScreen(tester);

      expect(find.text('Audio Output'), findsWidgets);
      expect(find.text('Earpiece'), findsOneWidget);
      expect(
        find.text('Use Speaker for group communication'),
        findsOneWidget,
      );
      expect(find.text('Use Earpiece for private listening'), findsOneWidget);
    });

    testWidgets('starts on the speaker', (tester) async {
      await openAudioScreen(tester);

      expect(container.read(audioRouteProvider), AudioRoute.speaker);
      expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);
    });

    testWidgets('switching to the earpiece reaches the transport',
        (tester) async {
      await openAudioScreen(tester);

      await tester.tap(find.text('Earpiece'));
      await tester.pumpAndSettle();

      expect(container.read(audioRouteProvider), AudioRoute.earpiece);
      expect(transport.audioRoute, AudioRoute.earpiece);
    });

    testWidgets('switching back to the speaker works', (tester) async {
      await openAudioScreen(tester);

      await tester.tap(find.text('Earpiece'));
      await tester.pumpAndSettle();

      // The group screen is still in the tree beneath this route and also has
      // a "Speaker" label, so scope the finder to this screen's option.
      await tester.tap(
        find.descendant(
          of: find.byType(AudioOutputScreen),
          matching: find.text('Speaker'),
        ),
      );
      await tester.pumpAndSettle();

      expect(container.read(audioRouteProvider), AudioRoute.speaker);
    });

    testWidgets('the call survives visiting this screen', (tester) async {
      await openAudioScreen(tester);
      await tester.pageBack();
      await tester.pumpAndSettle();

      // sessionProvider is not autoDispose (spec section 6.2).
      expect(find.text('Group is Active'), findsOneWidget);
    });
  });

  group('settings', () {
    Future<void> openSettings(WidgetTester tester) async {
      await pumpApp(tester);
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
    }

    testWidgets('shows the current display name', (tester) async {
      await openSettings(tester);

      expect(find.text('Display Name'), findsOneWidget);
      expect(find.text(kDefaultDisplayName), findsWidgets);
    });

    testWidgets('saves a new display name', (tester) async {
      await openSettings(tester);

      await tester.enterText(
        find.byType(TextField).first,
        'Atharva',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(container.read(displayNameProvider).value, 'Atharva');
    });

    testWidgets('reports that the device can host', (tester) async {
      await openSettings(tester);

      expect(find.text('Can host groups'), findsOneWidget);
    });

    testWidgets('clears recent groups', (tester) async {
      SharedPreferences.setMockInitialValues({
        'recent_groups': [
          '{"groupId":"1a2b","name":"Team Alpha","memberCount":3,'
              '"lastJoined":"2026-08-26T12:00:00.000"}',
        ],
      });

      await openSettings(tester);
      await tester.tap(find.text('Clear recent groups'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();

      expect(find.text('No groups yet'), findsOneWidget);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/ui/audio_and_settings_test.dart`
Expected: FAIL — `Earpiece` not found

- [ ] **Step 3: Create the audio output screen**

Create `lib/ui/audio/audio_output_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../domain/models/audio.dart';
import '../../state/audio_route_provider.dart';

class AudioOutputScreen extends ConsumerWidget {
  const AudioOutputScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final route = ref.watch(audioRouteProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Audio Output')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _RouteOption(
              icon: Icons.volume_up,
              label: 'Speaker',
              selected: route == AudioRoute.speaker,
              onTap: () => ref
                  .read(audioRouteProvider.notifier)
                  .setRoute(AudioRoute.speaker),
            ),
            const SizedBox(height: 12),
            _RouteOption(
              icon: Icons.hearing,
              label: 'Earpiece',
              selected: route == AudioRoute.earpiece,
              onTap: () => ref
                  .read(audioRouteProvider.notifier)
                  .setRoute(AudioRoute.earpiece),
            ),
            const SizedBox(height: 28),
            const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline,
                    size: 18, color: AppColors.textSecondary),
                SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Use Speaker for group communication',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 12),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Use Earpiece for private listening',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RouteOption extends StatelessWidget {
  const _RouteOption({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Icon(icon, color: AppColors.textPrimary),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: selected ? AppColors.primary : AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Rewrite the settings screen**

Replace `lib/ui/settings/settings_screen.dart` entirely:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../state/display_name_provider.dart';
import '../../state/recent_groups_provider.dart';
import '../../state/transport_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({this.embedded = false, super.key});

  /// True when hosted inside the bottom navigation rather than pushed.
  final bool embedded;

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _name = TextEditingController();
  bool _seeded = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final displayName = ref.watch(displayNameProvider);
    final canHost = ref.watch(peripheralSupportedProvider).value;

    // Seed the field once the stored name has loaded.
    if (!_seeded && displayName.hasValue) {
      _name.text = displayName.value!;
      _seeded = true;
    }

    return Scaffold(
      appBar: widget.embedded ? null : AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (widget.embedded)
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Text(
                  'Settings',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
            const Text(
              'Display Name',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _name,
              decoration: const InputDecoration(
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: () => ref
                    .read(displayNameProvider.notifier)
                    .setName(_name.text),
                child: const Text('Save'),
              ),
            ),
            const Divider(height: 40),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                canHost == false ? Icons.error_outline : Icons.bluetooth,
                color: canHost == false
                    ? AppColors.danger
                    : AppColors.textSecondary,
              ),
              title: Text(
                canHost == false ? "Can't host groups" : 'Can host groups',
                style: const TextStyle(color: AppColors.textPrimary),
              ),
              subtitle: Text(
                canHost == false
                    ? "This device's Bluetooth can't advertise, so it can "
                        'only join groups.'
                    : 'This device can create and advertise groups.',
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 12),
              ),
            ),
            const Divider(height: 40),
            TextButton.icon(
              onPressed: () =>
                  ref.read(recentGroupsProvider.notifier).clear(),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Clear recent groups'),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Wire the route and delete the placeholder**

In `lib/core/router/app_router.dart`, add the import, replace the `audio`
route builder, and **delete the `_Pending` class** — no routes use it now.

```dart
import '../../ui/audio/audio_output_screen.dart';
```

```dart
            GoRoute(
              path: 'audio',
              builder: (context, state) => const AudioOutputScreen(),
            ),
```

- [ ] **Step 6: Run the tests**

Run: `flutter test`
Expected: all tests PASS

- [ ] **Step 7: Verify analysis is clean**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 8: Commit**

```bash
git add lib test
git commit -m "feat: add audio output and settings screens"
```

---

### Task 20: End-to-end journey test

**Files:**
- Test: `test/ui/end_to_end_test.dart`

**Interfaces:**
- Consumes: everything
- Produces: nothing — no production code

This is the Phase 3 milestone check: the whole app driven through its real UI,
with two devices in one test process, and no Bluetooth anywhere.

- [ ] **Step 1: Write the test**

Create `test/ui/end_to_end_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bconnect/app.dart';
import 'package:bconnect/domain/models/session_state.dart';
import 'package:bconnect/state/session_provider.dart';
import 'package:bconnect/state/transport_provider.dart';
import 'package:bconnect/transport/fake/fake_hub.dart';
import 'package:bconnect/transport/fake/fake_transport.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeHub hub;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    hub = FakeHub();
  });

  testWidgets('create a password group, then a second device joins it',
      (tester) async {
    // Device A drives the UI.
    final aTransport = FakeTransport(hub, deviceId: 'a');
    addTearDown(aTransport.dispose);
    final aContainer = ProviderContainer(
      overrides: [transportProvider.overrideWithValue(aTransport)],
    );
    addTearDown(aContainer.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: aContainer,
        child: const BconnectApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Home -> Create.
    expect(find.text('Group Talk'), findsOneWidget);
    await tester.tap(find.text('Create New Group'));
    await tester.pumpAndSettle();

    // Fill in a password-protected group.
    await tester.enterText(
      find.widgetWithText(TextField, 'Enter group name'),
      'Team Alpha',
    );
    await tester.tap(find.text('Password Protected'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Enter password'),
      'hunter2',
    );
    await tester.tap(find.text('Create Group'));
    await tester.pumpAndSettle();

    // Now hosting.
    expect(find.text('Group is Active'), findsOneWidget);
    expect(find.text('You (Admin)'), findsOneWidget);
    expect(find.text('1 Member'), findsOneWidget);

    // Device B joins headlessly.
    final bTransport = FakeTransport(hub, deviceId: 'b');
    addTearDown(bTransport.dispose);
    final bContainer = ProviderContainer(
      overrides: [transportProvider.overrideWithValue(bTransport)],
    );
    addTearDown(bContainer.dispose);

    final found = bTransport.events.whereType<ScanResultEvent>().first;
    await bTransport.startScan();
    final group = (await found).group;

    expect(group.name, 'Team Alpha');
    expect(group.isLocked, isTrue);

    await bContainer.read(sessionProvider.notifier).joinGroup(
          group,
          password: 'hunter2',
          displayName: 'Device 1',
        );
    await tester.pumpAndSettle();

    // Device A's roster updated live.
    expect(find.text('Device 1'), findsOneWidget);
    expect(find.text('2 Members'), findsOneWidget);

    // Talk, then release.
    final gesture =
        await tester.startGesture(tester.getCenter(find.text('Tap to Speak')));
    await tester.pumpAndSettle();
    expect(aTransport.isTalking, isTrue);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(aTransport.isTalking, isFalse);

    // Route audio to the earpiece and come back.
    await tester.tap(find.text('Speaker'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Earpiece'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    // The call survived the detour.
    expect(find.text('Group is Active'), findsOneWidget);

    // End the call.
    await tester.tap(find.text('End Call'));
    await tester.pumpAndSettle();

    expect(find.text('Group Talk'), findsOneWidget);
    expect(aContainer.read(sessionProvider), isA<SessionIdle>());

    // Device B saw the group end.
    expect(
      (bContainer.read(sessionProvider) as SessionFailed).error,
      SessionError.hostLeft,
    );

    // The group is now in Your Groups.
    expect(find.text('Team Alpha'), findsOneWidget);
  });

  testWidgets('a wrong password keeps the user on the password screen',
      (tester) async {
    // Host headlessly.
    final hostTransport = FakeTransport(hub, deviceId: 'host');
    addTearDown(hostTransport.dispose);
    final hostContainer = ProviderContainer(
      overrides: [transportProvider.overrideWithValue(hostTransport)],
    );
    addTearDown(hostContainer.dispose);

    await hostContainer.read(sessionProvider.notifier).createGroup(
          const GroupConfig(name: 'Team Gamma', password: 'correct'),
          displayName: 'Host',
        );

    // Join through the UI.
    final transport = FakeTransport(hub, deviceId: 'me');
    addTearDown(transport.dispose);
    final container = ProviderContainer(
      overrides: [transportProvider.overrideWithValue(transport)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const BconnectApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Join Existing Group'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Team Gamma'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Enter Password'),
      'wrong',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Join Group'));
    await tester.pumpAndSettle();

    expect(find.text('Incorrect password'), findsOneWidget);

    // Correcting it succeeds.
    await tester.enterText(
      find.widgetWithText(TextField, 'Enter Password'),
      'correct',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Join Group'));
    await tester.pumpAndSettle();

    expect(find.text('Group is Active'), findsOneWidget);
  });
}
```

Add `import 'package:bconnect/domain/models/group_config.dart';` for the
second test.

- [ ] **Step 2: Run the test**

Run: `flutter test test/ui/end_to_end_test.dart`
Expected: PASS (2 tests)

If a step fails, fix the screen or session code rather than weakening the
test.

- [ ] **Step 3: Run the whole suite**

Run: `flutter test && flutter analyze`
Expected: all tests PASS, `No issues found!`

- [ ] **Step 4: Commit**

```bash
git add test/ui/end_to_end_test.dart
git commit -m "test: add end-to-end journey test"
```

---

## Done criteria for Plan A

- `flutter test` passes and `flutter analyze` reports no issues.
- `flutter run` on any Android device shows all seven screens and lets a user
  create a group, see it, and end the call — with `FakeTransport` wired in
  `main.dart` (real discovery arrives in Plan B).
- No native code has been written.

Note that `main.dart` still needs a transport override to run outside tests.
Add this in Task 1's file when first running the app manually:

```dart
runApp(
  ProviderScope(
    overrides: [
      transportProvider.overrideWithValue(FakeTransport(FakeHub())),
    ],
    child: const BconnectApp(),
  ),
);
```

Plan B replaces that override with the real BLE transport.
