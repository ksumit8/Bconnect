import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models/discovered_group.dart';
import '../domain/protocol/protocol_limits.dart';
import '../transport/group_transport.dart';
import 'transport_provider.dart';

/// Nearby groups, freshest first.
///
/// autoDispose so scanning stops as soon as the Discover screen is left;
/// continuous BLE scanning is a real battery cost (spec section 6.2).
final discoveredGroupsProvider =
    StreamProvider.autoDispose<List<DiscoveredGroup>>((ref) {
  final transport = ref.watch(transportProvider);
  final clock = ref.watch(clockProvider);

  final controller = StreamController<List<DiscoveredGroup>>();
  final byGroupId = <String, DiscoveredGroup>{};

  void publish() {
    final now = clock();
    byGroupId.removeWhere(
      (_, g) => now.difference(g.lastSeen) > ProtocolLimits.advertTtl,
    );

    final groups = byGroupId.values.toList()
      ..sort((a, b) => b.rssi.compareTo(a.rssi));

    if (!controller.isClosed) controller.add(List.unmodifiable(groups));
  }

  final subscription = transport.events
      .whereType<ScanResultEvent>()
      .listen((event) {
    byGroupId[event.group.groupId] = event.group;
    publish();
  });

  // Prunes stale entries even when nothing new arrives, so a group that goes
  // quiet disappears from the list on its own.
  final timer = Timer.periodic(const Duration(seconds: 1), (_) => publish());

  ref.onDispose(() {
    timer.cancel();
    unawaited(subscription.cancel());
    unawaited(transport.stopScan());
    unawaited(controller.close());
  });

  unawaited(transport.startScan());
  publish();

  return controller.stream;
});
