# Bconnect

Offline push-to-talk voice groups over Bluetooth LE, for Android.

Create a named group — open or password-protected — and it advertises itself to
nearby devices. They discover it, join, and hold a button to talk. No internet,
no server, no accounts.

## Status

**The control plane works over a real radio. Audio is next.**

Two phones discover each other, connect, authenticate with a password, exchange
live roster updates and tear down cleanly — all over Bluetooth LE, with no fake
transport anywhere in the path. Hosting survives the screen lock via a
foreground service.

What is not built yet is the voice itself: the talk button and audio route are
wired through the UI and the protocol, but no audio crosses the link.

- 239 tests passing, `flutter analyze` clean
- Verified on two physical Android phones (Android 13 and 14) — see
  [`docs/DEVICE_TESTING.md`](docs/DEVICE_TESTING.md) for the checks
- Audio pipeline: not yet implemented
- Still unverified: whether one host sustains seven simultaneous connections
  (needs a third phone)

## Architecture

| Layer | Contents |
|---|---|
| UI | 7 screens (`lib/ui/`) |
| State | Riverpod 3 providers, non-codegen (`lib/state/`) |
| Domain | Session logic, roster, protocol codecs — pure Dart, no plugins (`lib/domain/`) |
| Transport | `GroupTransport` interface, real BLE implementation, in-memory fake (`lib/transport/`) |

The transport seam is the point of the design. Swapping the fake for the real
BLE implementation touched exactly one line above it — the provider override in
`main.dart`. `FakeTransport` remains as the test double for every widget and
session test.

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

`main.dart` wires the real BLE transport, so you need a physical Android device
with Bluetooth on — two of them to see anything interesting. The app asks for
the Nearby-devices permission on first launch.

```bash
flutter test      # 239 tests
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

Four things the plan did not anticipate, each found only on hardware and each
fixed:

| Symptom | Cause |
|---|---|
| `connect()` never called back, retried forever | An active LE scan starves the connection attempt; stop scanning first |
| Subscribing hung with no error on either side | The CCCD descriptor write is forwarded to Dart and must be answered |
| Join hung waiting for a challenge that was sent | A notification published before the client subscribes is silently dropped |
| Join hung on the second attempt only | The challenge can arrive before `connect()` returns, i.e. before the caller knows its own peer id |

## Licence note

`flutter_blue_plus` requires a paid commercial licence for for-profit use.
`bluetooth_low_energy` (MIT) covers both central and peripheral roles and is
what this uses.

## Built with

Flutter 3.38 · Dart 3.10 · Riverpod 3 · freezed · go_router
