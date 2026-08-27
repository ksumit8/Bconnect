import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'state/transport_provider.dart';
import 'transport/fake/fake_hub.dart';
import 'transport/fake/fake_transport.dart';

void main() => runApp(buildProductionApp());

/// The widget tree the shipping app runs.
///
/// Plan A has no real transport yet, so this wires in-memory stand-ins
/// (FakeTransport over FakeHub) as the running app's transport. Plan B
/// replaces this override with the real BLE transport; everything above
/// `transportProvider` is written against the `GroupTransport` interface, so
/// that swap should not require touching anything else here.
///
/// Extracted from [main] (rather than inlined in `runApp(...)`) so
/// `test/widget_test.dart` can pump this exact widget tree — including this
/// override — directly. That closes the gap the app once shipped with: every
/// test overrides `transportProvider` itself, so none of them could catch
/// `main()` failing to override it for the real app.
Widget buildProductionApp() => ProviderScope(
  overrides: [
    transportProvider.overrideWithValue(FakeTransport(FakeHub())),
  ],
  child: const BconnectApp(),
);
