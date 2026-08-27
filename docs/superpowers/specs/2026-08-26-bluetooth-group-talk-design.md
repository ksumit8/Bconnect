# Bconnect — Bluetooth Group Talk

Design spec — 2026-08-26

## 1. Overview

Bconnect is an Android app for offline push-to-talk voice communication over
Bluetooth. A user creates a named group, optionally protected by a password.
The group advertises itself over Bluetooth Low Energy, so nearby devices see it
in a scan list and can join — entering the password if one is set. Once joined,
members hold a button to talk; everyone else hears them. Members can mute, route
audio to speaker or earpiece, and leave the group.

No internet, no server, no accounts.

## 2. Scope

### In scope

- Create a group (open or password-protected)
- Discover nearby groups, with name, member count, lock state, signal strength
- Join a group, entering a password when required
- Push-to-talk voice, with multiple simultaneous talkers
- Mute toggle, speaker/earpiece routing, end call
- Live member roster with presence and talking indicators
- Recently used groups on the home screen
- Settings: display name

### Out of scope

- iOS. Apple blocks Classic Bluetooth for non-MFi devices, and its
  peer-to-peer story is MultipeerConnectivity, a different transport that
  will not interoperate with Android. Cross-platform is a separate project.
- Text chat, file transfer, call recording
- Any server, cloud, or internet dependency
- Encryption of the audio stream (see Security, §7)

## 3. Decisions

These were settled during design. Each records the alternative rejected and why.

### 3.1 Android only

iOS cannot participate. Building an iOS transport would mean
MultipeerConnectivity, which cannot talk to Android, so it would be a second
product rather than a second platform.

### 3.2 Pure BLE GATT for both discovery and audio

The original plan was a hybrid: BLE for advertising groups, Classic Bluetooth
RFCOMM for audio. That approach has a hard blocker.

A client cannot learn the host's Classic Bluetooth MAC address. BLE
advertisements carry a random resolvable BLE address, not the Classic MAC, and
since Android 8 an app cannot read its own Classic MAC — `getAddress()` returns
`02:00:00:00:00:00`. So the host cannot publish it either. The only way a client
obtains a Classic MAC is Classic inquiry, which requires the host to sit in
Android's system discoverable mode: a system popup, a hard 300-second cap after
which the group becomes unjoinable, and ~12-second inquiry scans that disrupt
active connections.

The bandwidth the hybrid was buying turns out to be unnecessary. BLE with the
2M PHY sustains roughly 1.0–1.4 Mbps under good conditions. A voice codec at
12.2 kbps is about 1.5 KB/s per stream.

The host is the bottleneck, since it relays every talker to every other member.
With the 3-talker cap and a full 8-member group:

- **Per link**: each client receives at most 3 streams — 36.6 kbps (~4.6 KB/s).
- **Host aggregate**: 3 streams relayed to 7 clients — ~256 kbps (~32 KB/s)
  outbound, spread across 7 concurrent connections, plus ~37 kbps inbound.

Both figures sit well inside BLE's envelope, but the aggregate case — one
device sustaining seven simultaneous connections — is the assumption most
likely to break on real hardware. Phase 0 gates on it explicitly.

Rejected alternatives:

- **Hybrid (BLE advertise + Classic audio)** — the MAC wall above.
- **Hybrid with pre-pairing** — devices pair once in Android Settings, then the
  app connects to bonded devices. Solid link, but it deletes the Discover
  screen: groups no longer appear automatically to nearby devices.
- **Nearby Connections API** — the best fit technically, but it opportunistically
  uses Wi-Fi Direct rather than staying on the Bluetooth radio, and requires
  Google Play Services.

Phase 0 validates the throughput assumption on real hardware before anything is
built on it. See §9.

### 3.3 Push-to-talk with multiple concurrent talkers

Anyone holding the talk button transmits. The host relays; clients mix locally
(§5.4). Concurrent talkers are capped at 3 to bound bandwidth.

Rejected: single-talker floor control (frustrating contention), and full-duplex
open mic (needs echo cancellation and degrades past ~3 members).

### 3.4 No Bluetooth pairing; app-level password only

Joining uses an unpaired BLE connection, so Android never shows a pairing
dialog. Authentication is a password challenge at the application layer (§5.3).

Consequence: the radio link is unencrypted. Accepted deliberately — see §7.

### 3.5 Control plane in Dart, audio path entirely in Kotlin

Control messages occur at human rate — a join, a roster change, a handful per
minute. Audio is 50 frames per second per talker. Moving audio frames across the
platform channel would add latency, create garbage-collection pressure, and put
jitter-sensitive work on the same isolate that drives the UI.

So Kotlin owns the complete audio path: mic → encode → GATT, and GATT → decode →
mix → speaker. Dart never sees an audio byte. Dart receives control frames plus
throttled talking-state and level-meter events.

### 3.6 Freezed for models, but Riverpod without code generation

`freezed` earns its place: roughly ten data and union types would otherwise
need hand-written `copyWith`, `==`, and `hashCode`.

Riverpod's `@riverpod` generator does not. It mainly saves declaring a
provider's type, and dropping it removes `riverpod_generator`,
`riverpod_lint`, and `custom_lint` from the toolchain — three fewer packages
to keep inside this project's Dart SDK constraint (§3.7).

### 3.7 Dependency versions are pinned to Dart 3.10.7

The project runs Flutter 3.38.6, which ships Dart 3.10.7. Several current
releases require newer SDKs and **will not resolve**: `freezed` 4.0.0 needs
Dart ≥3.13; `flutter_riverpod` 3.4.x, `go_router` 18, `riverpod_generator`
4.0.6+, and `build_runner` 2.15.2+ all need ≥3.12.

The verified working set is `flutter_riverpod` 3.3.2, `freezed` 3.2.3,
`freezed_annotation` 3.1.0, `go_router` 17.5.0, `build_runner` 2.15.1,
`shared_preferences` 2.5.5, `crypto` 3.0.7, `mocktail` 1.0.5.

Upgrading Flutter would lift this constraint, but that is a separate decision
about the whole toolchain rather than something this project should force.

### 3.8 Custom Kotlin rather than an off-the-shelf plugin

No Flutter package provides the BLE peripheral + GATT server + audio pipeline
this needs as one coherent unit. `flutter_blue_classic`, the only maintained
Classic Bluetooth plugin, is client-only (no server socket) and GPL-3.0, which
is unsuitable for proprietary work.

Dart-side dependencies (`flutter_blue_plus`, `record`, `permission_handler`,
`audio_session`) are all MIT and used only where they do not sit on the
real-time path.

### 3.9 BLE package: bluetooth_low_energy (MIT), not flutter_blue_plus

`flutter_blue_plus` was named during planning and recorded as MIT. **That was
wrong.** It ships under the FlutterBluePlus License, which requires a paid
commercial licence for any for-profit use, and enforces it in the API via
`connect(license: License.commercial)`.

Free alternatives were checked by reading their LICENSE files directly and
resolving them against this project's Dart 3.10.7:

| Package | Licence | Dart SDK | Verdict |
|---|---|---|---|
| `bluetooth_low_energy` 6.2.1 | MIT | >=3.9.2 | **chosen** — central AND peripheral |
| `flutter_reactive_ble` 5.5.0 | BSD | >=2.17.0 | viable, central only |
| `ble_peripheral` 2.4.0 | MIT | >=3.2.0 | viable, peripheral only |
| `universal_ble` 2.1.1 | — | ^3.12.0 | rejected, needs newer Dart |
| `quick_blue` 0.4.1 | — | <3.0.0 | rejected, pre-Dart-3 |
| `flutter_blue_plus` 2.3.12 | paid | ^3.0.0 | rejected, licence |

`bluetooth_low_energy` covers both roles in one free dependency and is proven
on the target hardware (§9.1). This supersedes §3.8's assumption that the
central and peripheral halves would need hand-written Kotlin: the package's
own Android implementation is the platform layer. Kotlin is still expected for
the **audio path**, which must not cross the Dart boundary (§3.5).

## 4. Architecture

Five layers:

| Layer | Contents |
|---|---|
| UI | 7 screens (§6) |
| State | Riverpod 3.x providers (non-codegen API), `freezed` models |
| Domain | Pure Dart — session logic, roster, join handshake, message codec. No plugins |
| Transport | Abstract `GroupTransport`. Implementations: `BleTransport`, `FakeTransport` |
| Platform | Kotlin — BLE peripheral + GATT server, BLE central, audio, routing |

### 4.1 Platform channel contract

`MethodChannel("bconnect/transport")`:

```
startAdvertising(groupName, memberCount, locked)
stopAdvertising()
startScan() / stopScan()
connect(deviceId) / disconnect(peerId)
sendControl(peerId, bytes)
setMicEnabled(bool)
setAudioRoute(speaker | earpiece)
startTalking() / stopTalking()
```

`EventChannel("bconnect/transport/events")`:

```
scanResult / peerConnected / peerDisconnected
controlMessage(peerId, bytes)
talkingStateChanged / audioLevel / error
```

Audio frames never appear in either channel.

### 4.2 FakeTransport

`FakeTransport` implements `GroupTransport` as an in-memory hub, connecting a
host and several simulated clients within one process. It makes the full join →
talk → leave flow testable without hardware, and lets Phases 2 and 3 complete
before any Kotlin exists.

## 5. Protocol

### 5.1 Advertisement

BLE legacy advertising allows 31 bytes.

| Field | Bytes |
|---|---|
| Flags (added by the stack) | 3 |
| Service Data, 16-bit UUID: `magic(2) \| version(1) \| flags(1) \| memberCount(1) \| groupId(2)` | 11 |

`flags` bit 0 = password-protected, bit 1 = group full.

The **group name is carried in the scan response**, not the advertisement. This
allows roughly 29 bytes of UTF-8 rather than ~15, so ordinary group names are
not truncated. Group names are capped at 29 UTF-8 bytes at input time.

Everything the Discover screen renders — name, member count, lock state, RSSI —
comes directly from the scan result. No secondary connection or lookup is
needed to populate the list.

`magic` disambiguates from unrelated apps using the same 16-bit UUID.

### 5.2 GATT service

One custom 128-bit service UUID, three characteristics:

| Characteristic | Properties | Purpose |
|---|---|---|
| `control` | write, notify | Control frames (§5.3) |
| `audio_up` | write without response | Client → host audio |
| `audio_down` | notify | Host → client audio |

### 5.3 Control frames

Compact binary, versioned:

| Frame | Payload |
|---|---|
| `JOIN_REQUEST` | version, displayName, passwordProof |
| `JOIN_ACCEPTED` | memberId, roster |
| `JOIN_REJECTED` | reason: wrongPassword \| full \| incompatibleVersion |
| `ROSTER_UPDATE` | members |
| `TALK_START` / `TALK_STOP` | memberId |
| `LEAVE` | — |
| `PING` / `PONG` | — |

**Password challenge.** The password is never transmitted. On connect the host
issues a nonce. The client replies with `HMAC-SHA256(password, nonce)` truncated
to 16 bytes. A wrong password fails verification; a captured proof cannot be
replayed against a later nonce.

Open groups skip the proof entirely.

### 5.4 Audio

20 ms frames, AMR-NB at 12.2 kbps via Android's built-in `MediaCodec`
(`audio/3gpp`). No additional native dependency, hardware-backed on most
devices, and placed behind a codec interface so Opus can replace it later.

Frame layout: `[seq: uint16][memberId: uint8][len: uint8][payload]`.

**The host relays; it does not mix.** Each talker's encoded frames are tagged
with a member ID and forwarded to every member except the source. Each client
decodes the streams it receives and mixes them locally.

This choice avoids transcoding loss, avoids the host computing N distinct
per-client mixes, and removes the "don't echo my own voice back at me" problem
without special handling.

Concurrent talkers are capped at 3. A fourth talk request receives floor-busy
feedback rather than degrading audio for everyone.

### 5.5 Limits

- Maximum group size: 8 (host + 7), matching typical Android peripheral-role
  connection limits.
- `groupId` is 2 bytes. Collisions become likely around 256 concurrent nearby
  groups; the BLE device address disambiguates.

## 6. State and screens

### 6.1 Domain types

```dart
sealed class SessionState = Idle | Discovering | Joining | Connected | Failed;

class DiscoveredGroup {
  String groupId; String deviceId; String name;
  int memberCount; bool isLocked; bool isFull;
  int rssi; DateTime lastSeen;
}

class Member {
  String id; String displayName;
  bool isHost; bool isSelf;
  MemberPresence presence;  // online | reconnecting | offline
  bool isTalking;
}
```

### 6.2 Providers

| Provider | Type | Notes |
|---|---|---|
| `permissionsProvider` | AsyncNotifier | scan, advertise, connect, microphone |
| `adapterStateProvider` | Stream | drives the "turn on Bluetooth" banner |
| `transportProvider` | Provider | overridden with `FakeTransport` in tests |
| `sessionProvider` | Notifier | core — consumes transport events, owns host/client role logic |
| `discoveredGroupsProvider` | Stream, autoDispose | deduped by `groupId`; entries expire ~10 s after last advert |
| `micProvider` | Notifier | `{ muted, transmitting }` |
| `audioRouteProvider` | Notifier | speaker \| earpiece |
| `recentGroupsProvider` | AsyncNotifier | persisted; feeds "Your Groups" |
| `displayNameProvider` | AsyncNotifier | settings |

Two lifetime rules matter:

- `sessionProvider` is **kept alive**, so an active call survives navigation
  between the group screen and the audio-output screen.
- `discoveredGroupsProvider` is **autoDispose**, so BLE scanning stops on
  leaving the Discover screen. Continuous scanning is a significant battery
  drain.

### 6.3 Screens

Navigation via `go_router`. Dark Material 3 theme: near-black surfaces, blue
primary, green for active-group state, red for End Call, purple for the
create-group avatar.

| # | Screen | Contents |
|---|---|---|
| 1 | Home | Create / Join cards, Your Groups, bottom nav |
| 2 | Create Group | name (≤29 UTF-8 bytes), Open/Password radio, password field with reveal toggle |
| 3 | Group | header + settings, member badge, "Group is Active", roster with presence dots, Invite, Speaker / Tap to Speak / Mute, End Call |
| 4 | Discover | scanning indicator, rows with lock icon and RSSI signal bars, Refresh |
| 5 | Join Password | lock avatar, group name, password field, Join / Cancel |
| 6 | Audio Output | Speaker / Earpiece radio, explanatory note |
| 7 | Settings | display name, permission status, about |

The source mockups show eight frames; frames 3, 6 and 8 are the same Group
screen in different states. The full-width red End Call button from frame 8 is
used throughout, in preference to the text link in frames 3 and 6, for touch
target size.

## 7. Security

The BLE link is unencrypted. This follows from the decision to skip Bluetooth
pairing (§3.4) in order to preserve the join flow in the mockups.

- The password authenticates **joining**, not the audio stream. It prevents
  uninvited members from entering a group.
- Audio is transmitted in the clear and could in principle be captured by
  someone nearby with appropriate radio hardware.
- Bconnect is therefore appropriate for walkie-talkie-grade communication. It
  must not be presented as suitable for confidential conversation.

If confidentiality is later required, the intended path is deriving a key from
the group password and encrypting audio frames at the application layer. Open
groups would remain unprotected, since they have no shared secret.

## 8. Error handling

| Condition | Behaviour |
|---|---|
| BLE peripheral role unsupported | Detected at startup. Create Group is disabled with an explanation; joining still works. This is a real risk on some Android chipsets and must fail visibly, not mid-flow |
| App backgrounded | A foreground service keeps the group alive (`FOREGROUND_SERVICE_MICROPHONE` and `FOREGROUND_SERVICE_CONNECTED_DEVICE` on Android 14+). Without it the call drops when the screen locks |
| Bluetooth adapter off | Banner with prompt to enable |
| Permissions denied | Rationale screen; permanently-denied state deep-links to app settings |
| Host leaves | Clients show "Group ended by host" and return home |
| Client drops | Marked `reconnecting`; 3 retries at 1 s / 2 s / 4 s, then removed from roster |
| Wrong password | Inline error beneath the field; user stays on the screen |
| Group full | Advertised as a flag, so the row is greyed before it is tapped; a racing join is rejected with `full` |
| Incoming phone call | `audio_session` interruption handling — mic off, playback paused, resumed afterwards |

### 8.1 Android permissions

- Android 12+: `BLUETOOTH_SCAN` (`neverForLocation`), `BLUETOOTH_ADVERTISE`,
  `BLUETOOTH_CONNECT`, `RECORD_AUDIO`
- Android 11 and below: `BLUETOOTH`, `BLUETOOTH_ADMIN`, `ACCESS_FINE_LOCATION`
- Foreground service permissions as above

`minSdkVersion` 24.

## 9. Phasing

| Phase | Deliverable |
|---|---|
| 0 | **BLE throughput spike (throwaway code).** See gate below |
| 1 | Scaffolding — dependencies, dark theme, router, Riverpod setup, permission flow |
| 2 | Domain, protocol, `FakeTransport`. Fully unit-tested. No UI, no hardware |
| 3 | All 7 screens against `FakeTransport` — the entire app clickable end to end with zero Bluetooth |
| 4 | Kotlin BLE — peripheral, GATT server, central. Control plane only: real discovery and joining |
| 5 | Kotlin audio — capture, AMR-NB, relay, local mix, playback, speaker/earpiece routing, PTT |
| 6 | Hardening — multi-device integration, reconnection, interruptions, battery |

Phase 3 is the milestone to aim at: a complete, demoable application before any
native code exists.

### 9.1 Phase 0 gate

Phase 0 is a spike. Its output is a measurement and a go/no-go decision; the
code is discarded.

It must establish, on the actual target devices:

1. **Peripheral role works** — the device can advertise and run a GATT server.
2. **Single link** — sustained ≥60 kbps bidirectional, round trip <200 ms.
3. **Aggregate** — one host sustaining **3 or more simultaneous central
   connections** at ≥40 kbps outbound each, without connection drops. This is
   the assumption most likely to fail (§3.2) and the reason the spike exists.

If (1) or (2) fails, the design is not viable and §3.2 must be revisited —
most likely by falling back to the hybrid transport and accepting the
discoverable-mode limitations.

If only (3) fails, the fallback is graduated rather than fatal: reduce the
maximum group size and the concurrent-talker cap to whatever the hardware
sustains, and update §5.5.

#### Phase 0 RESULTS — executed 2026-08-27

Measured on a TC27 (Android 14) advertising to an IV2201 (Android 13), using
`bluetooth_low_energy` 6.2.1 for both roles.

| Gate | Result |
|---|---|
| 1. Peripheral role | **PASS** — both devices advertise, radio-confirmed |
| 2. Single link | **PASS** — 278–479 kbps, 83 ms idle RTT, MTU 517 |
| 3. Aggregate | **PARKED** — needs a third device; two were available |

Gate 2 detail: throughput 278.1 and 479.4 kbps across two runs against a
60 kbps requirement. Latency was measured separately on an idle link (83 ms
median, 108 ms max) and under deliberate saturation (1294 ms median, 3283 ms
max).

**Use 275 kbps as the planning figure, not 479** — run-to-run variance was
substantial.

**Latency collapses ~15× once the link saturates.** Voice at 12.2 kbps uses
roughly 4% of measured capacity, so this does not arise in normal operation,
but it means the concurrent-talker cap (§5.4) and the low-bitrate codec are
**latency** decisions as much as bandwidth ones. Neither may be relaxed on the
grounds that spare bandwidth exists.

Gate 3 remains the only unvalidated assumption in the transport design. Its
graduated fallback above still applies.

#### Phase 0 findings that bind Plan B

1. **`BLUETOOTH_SCAN` must declare `android:usesPermissionFlags="neverForLocation"`.**
   Without it, Android 12+ requires `ACCESS_FINE_LOCATION` for scan results to
   be delivered, and if that permission is absent the platform returns **zero
   results while reporting success**. This failure is silent and looks exactly
   like broken hardware; it cost roughly 50 minutes during the spike and led to
   an incorrect conclusion that the device could not scan.

2. **`flutter_blue_plus` must not be used.** It requires a paid commercial
   licence for for-profit use, enforced in the API. `bluetooth_low_energy`
   (MIT) covers both central and peripheral roles, resolves on Dart 3.10.7, and
   is what produced the results above. See §3.9.

3. **`bluetooth_low_energy`'s `authorize()` never completes** when permissions
   are already granted and the adapter is powered on. It must be skipped when
   `state == poweredOn`, or wrapped in a timeout, or the app hangs on a blank
   screen indefinitely.

### 9.2 Plan decomposition

This spec spans more work than one implementation plan should carry. It splits
cleanly at the native boundary:

- **Plan A — Phases 0–3.** Spike, scaffolding, domain, and the full UI on
  `FakeTransport`. Pure Dart, fully testable, no hardware. Ends at a demoable
  application.
- **Plan B — Phases 4–6.** The Kotlin BLE and audio implementation, plus
  hardening. Requires physical devices.

Plan A is written:
`docs/superpowers/plans/2026-08-26-bluetooth-group-talk-plan-a.md`.

Plan B is written after Phase 0's measurements are in hand, since those results
may change its content.

Note that Phase 0 does not block Plan A. Everything in Plan A runs on the fake
transport and is transport-agnostic; only two constants in
`protocol_limits.dart` depend on Phase 0's outcome. The two can proceed in
parallel.

## 10. Testing

- **Unit (pure Dart)** — protocol codec round-trips, HMAC proof verification and
  rejection, roster reducer, scan-result TTL expiry, concurrent-talker cap.
- **Integration via `FakeTransport`** — host plus 3 clients in a single test
  process. Covers: joining an open group, joining a locked group with correct
  and incorrect passwords, concurrent talkers, host leaving, client dropping.
- **Widget tests** — each screen with overridden providers.
- **Manual device matrix** — BLE cannot be emulated. Phases 4–6 require 2–3
  physical Android devices, ideally with different Bluetooth chipsets, since
  peripheral-role behaviour varies by vendor.

## 11. Open risks

1. **BLE peripheral-role reliability varies across Android chipsets.** Some
   devices advertise unreliably or cap concurrent centrals below 7. Phase 0
   measures this on the target hardware; §8 degrades gracefully where it is
   absent.
2. **Real-world throughput may fall short of the figures in §3.2**, which come
   from optimised peripheral hardware rather than phone-to-phone links. Phase 0
   gates on measured, not published, numbers.
3. **Sustained advertising, scanning and streaming drain battery.** Not
   quantified until Phase 6.
