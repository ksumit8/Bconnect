import 'package:freezed_annotation/freezed_annotation.dart';

part 'discovered_group.freezed.dart';

@freezed
abstract class DiscoveredGroup with _$DiscoveredGroup {
  const factory DiscoveredGroup({
    /// Four lowercase hex digits, from the 2-byte advertised group id.
    required String groupId,

    /// Transport-specific address used to open a connection.
    required String deviceId,
    required String name,
    required int memberCount,
    required bool isLocked,
    required bool isFull,
    required int rssi,
    required DateTime lastSeen,
  }) = _DiscoveredGroup;
}
