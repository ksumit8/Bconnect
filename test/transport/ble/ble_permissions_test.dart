import 'package:flutter_test/flutter_test.dart';

import 'package:bconnect/transport/ble/ble_permissions.dart';

void main() {
  group('BlePermissionResult mapping', () {
    test('all granted is granted', () {
      expect(
        BlePermissions.combine(const [
          BlePermissionResult.granted,
          BlePermissionResult.granted,
        ]),
        BlePermissionResult.granted,
      );
    });

    test('any denial makes the whole request denied', () {
      expect(
        BlePermissions.combine(const [
          BlePermissionResult.granted,
          BlePermissionResult.denied,
        ]),
        BlePermissionResult.denied,
      );
    });

    test('permanent denial outranks ordinary denial', () {
      // The UI must send the user to app settings, not re-prompt, so a
      // permanent denial anywhere has to win.
      expect(
        BlePermissions.combine(const [
          BlePermissionResult.denied,
          BlePermissionResult.permanentlyDenied,
        ]),
        BlePermissionResult.permanentlyDenied,
      );
    });

    test('an empty list is granted', () {
      expect(BlePermissions.combine(const []), BlePermissionResult.granted);
    });
  });
}
