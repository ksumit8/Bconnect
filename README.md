# Bconnect

Offline push-to-talk voice groups over Bluetooth LE, for Android.

Create a named group — open or password-protected — and it advertises itself to
nearby devices. They discover it, join, and hold a button to talk. No internet,
no server, no accounts.

## Status

**The app is complete; the radio is not.**

Everything above the transport is built and tested: the protocol, the session
state machines, the Riverpod state layer, and all seven screens. All Bluetooth
sits behind a single `GroupTransport` interface, currently backed by an
in-memory fake — so the whole app runs and is testable without hardware.

That means: **two phones running this build cannot yet hear each other.** The
native BLE and audio layer is the next phase.

- 219 tests passing, `flutter analyze` clean
- Runs on a real Android device today
- Bluetooth transport and audio pipeline: not yet implemented

## Architecture

| Layer | Contents |
|---|---|
| UI | 7 screens (`lib/ui/`) |
| State | Riverpod 3 providers, non-codegen (`lib/state/`) |
| Domain | Session logic, roster, protocol codecs — pure Dart, no plugins (`lib/domain/`) |
| Transport | `GroupTransport` interface + in-memory fake (`lib/transport/`) |

The transport seam is the point of the design. Swapping the fake for a real BLE
implementation should not require changes above it.

### Protocol

- Group metadata (member count, lock state) rides in the BLE advertisement;
  the group name goes in the scan response, which buys ~29 bytes instead of ~15
- Joining is authenticated by an HMAC-SHA256 challenge — the password itself is
  never transmitted
- Control frames are a compact binary format; audio frames never cross the Dart
  boundary by design
- Max 8 members (host + 7), max 3 concurrent talkers

The radio link is deliberately unencrypted (no Bluetooth pairing, so the join
flow stays simple). Treat it as walkie-talkie grade, not confidential.

## Running it

```bash
flutter pub get
flutter run
```

`main.dart` wires the in-memory transport. You can create a group, see the
roster, hold to talk and end the call — all locally.

```bash
flutter test      # 219 tests
flutter analyze
```

## Design documents

- [`docs/superpowers/specs/`](docs/superpowers/specs/) — the design spec, including
  why Classic Bluetooth was rejected (Android will not let a client learn a
  host's Classic MAC address) and why BLE GATT was chosen instead
- [`docs/superpowers/plans/`](docs/superpowers/plans/) — the implementation plan

## Hardware findings

A throughput spike on two Android phones (TC27 / Android 14, IV2201 / Android 13):

| Measure | Result |
|---|---|
| Sustained throughput | 278–479 kbps |
| Latency, idle link | 83 ms median |
| Latency, saturated link | 1294 ms median |
| MTU | 517 |

Voice at 12.2 kbps needs ~4% of that, so there is comfortable headroom. Note
that latency degrades ~15× once the link saturates — the concurrent-talker cap
and low-bitrate codec are latency decisions as much as bandwidth ones.

Still unverified: whether one host sustains seven simultaneous connections.

## Licence note

`flutter_blue_plus` requires a paid commercial licence for for-profit use.
`bluetooth_low_energy` (MIT) covers both central and peripheral roles and is the
intended dependency for the native layer.

## Built with

Flutter 3.38 · Dart 3.10 · Riverpod 3 · freezed · go_router
