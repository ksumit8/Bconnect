import 'package:permission_handler/permission_handler.dart';

enum BlePermissionResult { granted, denied, permanentlyDenied }

/// Runtime permissions for BLE.
///
/// Android 12+ (API 31) needs the three `BLUETOOTH_*` runtime permissions, and
/// nothing else — the manifest declares `neverForLocation` on `BLUETOOTH_SCAN`,
/// so no location prompt is required or wanted.
///
/// On API 30 and below those three permissions do not exist as runtime
/// permissions; `permission_handler` reports them granted without a prompt, and
/// the legacy `BLUETOOTH`/`BLUETOOTH_ADMIN` declarations in the manifest are
/// install-time. The one real gap is `ACCESS_FINE_LOCATION`, which API 30 and
/// below require before delivering scan results. Requesting it unconditionally
/// would raise a location prompt on modern Android, which is exactly what
/// `neverForLocation` exists to avoid, and branching on it needs an OS-version
/// lookup this project has no dependency for. Both target devices are API 33
/// and 34, so the gap is unreached — but a pre-Android-12 device will scan and
/// find nothing.
abstract final class BlePermissions {
  /// Worst-of: a permanent denial outranks an ordinary denial, because the UI
  /// must route the user to app settings rather than re-prompting.
  static BlePermissionResult combine(List<BlePermissionResult> results) {
    if (results.contains(BlePermissionResult.permanentlyDenied)) {
      return BlePermissionResult.permanentlyDenied;
    }
    if (results.contains(BlePermissionResult.denied)) {
      return BlePermissionResult.denied;
    }
    return BlePermissionResult.granted;
  }

  static BlePermissionResult _map(PermissionStatus s) {
    if (s.isGranted || s.isLimited) return BlePermissionResult.granted;
    if (s.isPermanentlyDenied) return BlePermissionResult.permanentlyDenied;
    return BlePermissionResult.denied;
  }

  /// Requested separately from [request] and deliberately not folded into its
  /// result: a refused notification permission costs the user the "Group
  /// active" notification, but hosting, scanning and joining all still work.
  /// Letting it turn the whole permission result into `denied` would be wrong.
  ///
  /// Android 13+ only. On older versions `permission_handler` reports it
  /// granted without prompting.
  static Future<BlePermissionResult> requestNotifications() async {
    return _map(await Permission.notification.request());
  }

  static Future<BlePermissionResult> request() async {
    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.bluetoothAdvertise,
    ].request();

    return combine(statuses.values.map(_map).toList());
  }
}
