import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'state/transport_provider.dart';
import 'transport/ble/ble_permissions.dart';
import 'transport/ble/ble_transport.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Ask before the first screen renders, so Discover and Create are usable
  // immediately rather than failing silently on first tap.
  //
  // This is not redundant with the plugin's own `authorize()`. Observed on the
  // IV2201: `authorize()` raises the Nearby-devices dialog but only requests
  // BLUETOOTH_CONNECT and BLUETOOTH_ADVERTISE, leaving BLUETOOTH_SCAN denied —
  // and a denied SCAN makes discovery return nothing while reporting success.
  // `BlePermissions.request()` asks for all three together.
  await BlePermissions.request();

  // Separate, and its result deliberately ignored: this only governs whether
  // the foreground service's "Group active" notification is visible. Hosting
  // works either way.
  await BlePermissions.requestNotifications();

  runApp(buildProductionApp());
}

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
