import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

/// `package:flutter_test` auto-discovers this file and calls
/// [testExecutable] before `testMain()` runs, once per test file — so this
/// is the one place that can change every `testWidgets`' timeout at once.
///
/// Without it, all 47+ `testWidgets` in this suite inherit
/// [AutomatedTestWidgetsFlutterBinding.defaultTestTimeout]'s 10-minute
/// default. Several tests here fail by *hanging* rather than asserting (an
/// un-pumped `pumpAndSettle()` against a perpetual spinner, a timer that
/// never fires, a future that never completes) — with the 10-minute
/// default, that stalls the whole run for minutes per hung test instead of
/// failing fast. One such stall previously ran long enough to kill an agent
/// mid-mutation and leave a removed guard behind in production code that
/// nearly shipped. 30 seconds is generous for this suite (confirmed by
/// running the full suite after adding this) while still failing fast
/// enough that a hang is caught, not waited out.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  if (binding is AutomatedTestWidgetsFlutterBinding) {
    binding.defaultTestTimeout = const Timeout(Duration(seconds: 30));
  }
  await testMain();
}
