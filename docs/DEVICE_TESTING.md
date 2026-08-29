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

## Check 2 — a central can connect and exchange control frames (Task 5)

With phone A hosting "Team Alpha", on phone B open nRF Connect, find
`Team Alpha`, and tap CONNECT.

PASS when:
- nRF Connect shows CONNECTED
- a service `0000b1c7-...` is listed
- inside it, a characteristic `0000b1c8-...` shows properties
  READ, WRITE, WRITE NO RESPONSE, NOTIFY

Then, on phone A, watch logcat:

    adb -s $A logcat | grep -i flutter

PASS when a connection is registered (the roster does not change yet —
`HostSession` only adds a member after a valid JOIN_REQUEST, which nRF
Connect does not send).

## Check 3 — our own app discovers a real group (Task 6)

1. Phone A: create a password-protected group "Team Alpha".
2. Phone B: open the app, tap **Join Existing Group**.

PASS when phone B's list shows:
- the name `Team Alpha`
- a **closed padlock** (it is password-protected)
- `1 Member`
- signal bars

FAIL modes:
- List stays empty -> check `neverForLocation` in the manifest first.
- Name shows as `Unnamed group` -> the radio dropped the name to fit the
  packet; the group is still joinable, but shorten the group name.
- Padlock is open -> the `isLocked` flag is not surviving the advertisement;
  check `AdvertPayload` encode/decode.

## Check 4 — two phones join a real group (Task 7)

1. Phone A: create a password-protected group "Team Alpha" with password
   `hunter2`.
2. Phone B: Join Existing Group -> tap `Team Alpha` -> enter `hunter2` ->
   tap Join Group.

PASS when ALL of these hold:
- Phone B lands on the group screen showing `Group is Active`
- Phone B's roster shows 2 members
- **Phone A's roster grows to 2 members without being touched**
- Phone A's member badge reads `2 Members`

3. Now test the wrong password: phone B leaves, rejoins, enters `wrong`.

PASS when phone B stays on the password screen showing `Incorrect password`,
and phone A's roster stays at 1.

4. Finally, phone A taps End Call.

PASS when phone B returns to its home screen showing `Group ended by host`.

### Note on granting permissions

Some devices refuse `adb shell pm grant` with
`SecurityException: Neither user 2000 nor current process has
GRANT_RUNTIME_PERMISSIONS` (observed on the IV2201). There, accept the
Nearby-devices dialog in the UI instead.

## Check 5 — permissions and Bluetooth off (Task 8)

Uninstall and reinstall so permissions are fresh:

    adb -s $A uninstall com.example.bconnect
    adb -s $A install -r build/app/outputs/flutter-apk/app-debug.apk

Launch WITHOUT granting anything via adb.

PASS when the system permission dialog appears on first launch.

Then turn Bluetooth OFF on phone A and launch the app.

PASS when the home screen shows `This device can't host a group` and the
Create card does not navigate when tapped.

## Check 6 — real-world conditions (Task 9)

**Duplicate adverts.** Phone A hosts. On phone B, open Join Group, press
Refresh five times.

PASS when `Team Alpha` appears exactly ONCE in the list, not five times, and
the list keeps updating afterwards — five rapid restarts is also what trips
Android's scan-frequency throttle, so this doubles as the regression test for
that.

**Out of range.** With both phones in a group, walk phone B away until it
disconnects (or turn its Bluetooth off).

PASS when phone A's roster drops back to 1 member, and phone B shows
`Connection lost` and returns home.

**Rejoin.** Bring phone B back / turn Bluetooth on, and join again.

PASS when the join succeeds and phone A's roster returns to 2.

**Battery.** Leave phone A hosting for 5 minutes with the screen on.

PASS when the group is still discoverable from phone B afterwards.

## Check 7 — the group survives backgrounding (Task 10)

1. Phone A: create "Team Alpha".
2. PASS when a notification appears: `Group active`.
3. Press HOME on phone A, then lock the screen.
4. Phone B: open Join Group.

PASS when `Team Alpha` is STILL listed with phone A's screen off.

5. Phone B joins while phone A stays locked.

PASS when the join succeeds, and phone A shows 2 members when unlocked.

6. Phone A: End Call.

PASS when the `Group active` notification disappears.

This is the check that the in-memory fake could never model: the Phase 0
spike showed advertising stops when the app loses foreground.
