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

/// The three-way decision of whether hosting should currently be offered,
/// shared by every screen that gates on it (Home's Create card, Settings'
/// "Can host groups" notice).
///
/// This is the single place that turns `peripheralSupportedProvider`'s
/// `AsyncValue<bool>` into a plain `bool`: loading is treated as
/// optimistically true so the UI doesn't flicker disabled while the probe is
/// still in flight, and a failed probe fails closed (treated as
/// unsupported) rather than defaulting to true, so a broken Bluetooth stack
/// doesn't let the user start creating a group only to fail partway through
/// (spec section 8). Extracted here — rather than each screen writing its
/// own `.when(...)` — because this exact three-way branch was previously
/// written twice and drifted: Home did it correctly, Settings read `.value`
/// directly and so reported "Can host groups" even when the probe had
/// failed.
final canHostProvider = Provider<bool>((ref) {
  return ref.watch(peripheralSupportedProvider).when(
        data: (supported) => supported,
        loading: () => true,
        error: (_, _) => false,
      );
});
