import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'state/transport_provider.dart';
import 'transport/ble/ble_transport.dart';

void main() => runApp(buildProductionApp());

/// The widget tree the shipping app runs.
///
/// Wires the real Bluetooth LE transport. `FakeTransport` remains, but only as
/// the test double every widget and session test overrides in — the shipping
/// app has not used it since Plan B1 Task 4.
///
/// Everything above `transportProvider` is written against the
/// `GroupTransport` interface, so this is the only line the swap touched.
///
/// Extracted from [main] (rather than inlined in `runApp(...)`) so
/// `test/widget_test.dart` can pump this exact widget tree — including this
/// override — directly. That closes the gap the app once shipped with: every
/// test overrides `transportProvider` itself, so none of them could catch
/// `main()` failing to override it for the real app.
Widget buildProductionApp() => ProviderScope(
  overrides: [transportProvider.overrideWithValue(BleTransport())],
  child: const BconnectApp(),
);
