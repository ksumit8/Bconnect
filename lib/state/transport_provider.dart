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
