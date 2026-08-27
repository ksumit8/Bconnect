# Device testing

BLE cannot be emulated. These checks run on two physical Android phones.

Find device ids with `adb devices -l`. Below, `$A` and `$B` are those ids.

## Build and install on both

    flutter build apk --debug
    adb -s $A install -r build/app/outputs/flutter-apk/app-debug.apk
    adb -s $B install -r build/app/outputs/flutter-apk/app-debug.apk

Bluetooth must be ON on both. Grant permissions when the app asks, or:

    adb -s $A shell pm grant com.example.bconnect android.permission.BLUETOOTH_SCAN
    adb -s $A shell pm grant com.example.bconnect android.permission.BLUETOOTH_CONNECT
    adb -s $A shell pm grant com.example.bconnect android.permission.BLUETOOTH_ADVERTISE

## Check 1 — the group is really on air (Task 4)

On phone A, create a password-protected group named "Team Alpha".

Verify with something other than our own scanning code, so the check is
independent. Either works:

- **nRF Connect** on phone B: open it, tap SCAN with "No filter".
- **The Phase 0 spike app** (`../ble_spike`), which has its own scanner.

PASS when: an entry named `Team Alpha` appears, with a signal reading.

A weaker but always-available corroboration, useful when neither scanner is
installed — confirm the Android BLE stack accepted the advertisement on
phone A itself:

    adb -s $A logcat -d -s BtGatt.AdvertiseManager:* bt_stack:* | tail

If nothing appears, check in this order — the first is by far the most common:
1. `BLUETOOTH_SCAN` is missing `neverForLocation` in the manifest. Android
   then returns zero results while reporting success.
2. Phone A's app lost foreground; advertising stops with it.
3. Bluetooth is off on either device.
