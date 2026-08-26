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

/// Whether this device's Bluetooth stack can act as a peripheral.
///
/// False disables hosting but not joining (spec section 8). It is a real
/// limitation on some Android chipsets, so it must fail visibly on the home
/// screen rather than midway through creating a group.
///
/// `retry: null` (via a function that always returns null) opts out of
/// Riverpod's default automatic retry. This is a one-shot capability query,
/// not a flaky operation, so retrying it is meaningless; worse, while a
/// retry is pending the provider reports `AsyncLoading` with the error
/// merely attached rather than a stable `AsyncError` (isLoading stays true
/// for up to ~30s of cumulative backoff across the default 10 retries).
/// Consumers that treat "loading" as optimistically true would then show
/// hosting as available for that whole window despite the probe having
/// already failed.
final peripheralSupportedProvider = FutureProvider<bool>(
  (ref) => ref.watch(transportProvider).isPeripheralSupported(),
  retry: (retryCount, error) => null,
);
