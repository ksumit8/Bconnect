# Bconnect Plan B2 — Audio Pipeline Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Carry voice between phones that are already in a group, so holding the talk button on one is heard on the others.

**Architecture:** Kotlin owns the entire audio path — microphone → AMR-NB encode → GATT → decode → mix → speaker. Dart never handles an audio byte; it only tells Kotlin when to start and stop, and receives throttled level events. The host relays each talker's frames to every other member rather than mixing, so no transcoding happens and nobody hears themselves.

**Tech Stack:** Kotlin, Android `MediaCodec` (`audio/3gpp`), `AudioRecord`, `AudioTrack`, `BluetoothGattServer` / `BluetoothGatt`, Flutter `MethodChannel` / `EventChannel`.

**Spec:** `docs/superpowers/specs/2026-08-26-bluetooth-group-talk-design.md`

**Predecessor:** `docs/superpowers/plans/2026-08-27-bluetooth-group-talk-plan-b1.md` — complete except Gate 3. The control plane works on hardware: two phones discover, connect, authenticate, exchange roster updates and tear down over BLE.

---

## Global Constraints

Every task's requirements implicitly include this section.

- **Android only.** `minSdkVersion` 24.
- **Dart SDK is `^3.10.7`.** Do not add Dart dependencies. Everything new is Kotlin.
- **Audio frames must never cross the platform channel** (spec §3.5). Dart sends commands and receives control frames, talking state and level meters. If you find yourself putting a `Uint8List` of audio on a channel, stop — that is the thing this plan exists to avoid.
- **Frame layout is fixed** (spec §5.4): `[seq: uint16][memberId: uint8][len: uint8][payload]`, big-endian, 20 ms frames.
- **Codec:** AMR-NB at 12.2 kbps via `MediaCodec` (`audio/3gpp`), 8 kHz mono. Placed behind a Kotlin interface so Opus can replace it later (spec §5.4).
- **The host relays; it does not mix** (spec §5.4). Each client mixes locally.
- **Max 3 concurrent talkers**, max 8 members — already enforced in Dart by `ProtocolLimits`. Kotlin must not re-implement these; the floor is granted by the existing control plane before Kotlin is told to transmit.
- **`RECORD_AUDIO` is a runtime permission.** It is requested only when the user first tries to talk, not at startup — a walkie-talkie that demands the microphone before you have joined anything reads as hostile.
- **The existing 239 tests must keep passing**, and `FakeTransport` stays the test double. No Dart test can exercise the audio path; that is what the device checks are for.
- **Expected test counts are indicative, not contractual.**

## What "done" looks like

Two phones in a group, as of the end of Plan B1:

1. Phone A holds the talk button and speaks.
2. Phone B hears it, out of the speaker, with usable delay.
3. Phone B holds talk and speaks; phone A hears it.
4. Both can talk at once and each hears the other.
5. The earpiece/speaker toggle changes where the audio comes out.
6. Mute silences the microphone without leaving the group.

## Testing strategy — read this before Task 1

Audio cannot be unit-tested off-device any more than the radio could. This plan has three kinds of verification, and **every task states which applies**:

- **Unit-testable (Kotlin, JVM)** — frame encode/decode, the jitter buffer's ordering and drop logic, the mixer's saturation arithmetic. These get real tests under `android/app/src/test/`.
- **Unit-testable (Dart)** — only the thin command surface and event mapping.
- **Device-verified** — anything touching a microphone, a speaker or the radio. Written checklists with expected output, run on two phones, **observed output pasted into the report**.

A task that claims device verification without pasting observed output has not been verified.

## The architectural problem this plan opens with

Spec §3.5 requires the audio path to be entirely in Kotlin. But Plan B1 built the BLE transport **in Dart**, on the `bluetooth_low_energy` plugin. The plugin owns the GATT server on the host and the GATT client on the joiner. Kotlin has no handle on either.

There are three ways out, and they differ enough that guessing would be expensive:

**A. Kotlin runs its own GATT alongside the plugin's.** The host registers a *second* `BluetoothGattServer` carrying only the audio characteristics; the joiner opens its *own* `connectGatt()` to the same peer. Android permits multiple GATT server registrations and multiple client instances per app, sharing one ACL link. Spec-faithful, and no audio ever reaches Dart. Unproven on this hardware.

**B. Audio rides the existing Dart connection.** Kotlin captures, encodes, decodes and plays; Dart ferries the encoded frames over new `audioUp`/`audioDown` characteristics on the connection it already owns. Simple and reuses everything Plan B1 verified — but it violates §3.5 and puts 50–150 messages per second per talker on the UI isolate, which is exactly the jitter risk §3.5 was written to avoid.

**C. Move the whole transport to Kotlin.** Fully spec-faithful and best for audio, but discards a verified working implementation and roughly doubles this plan.

**Task 1 settles it by measurement, not argument.** It is a gate, in the spirit of the Phase 0 spike: prove or disprove option A on the actual phones before any audio code is written. If the gate passes, the plan proceeds as written. If it fails, Task 1's fallback ruling switches Tasks 4 and 7 to option B and the rest of the plan is unchanged. Option C is not attempted without the user's agreement — it is a rewrite, not a task.

**The peer's MAC address is recoverable.** `bluetooth_low_energy` derives its peer UUID from the device address (`UUID.fromAddress`), so a peerId like `00000000-0000-0000-0000-766ecb7a78ad` carries the MAC `76:6E:CB:7A:78:AD` in its last twelve hex digits. Verified against live peerIds during Plan B1. That is how Dart tells Kotlin which device to open an audio link to.

## File structure

| File | Responsibility |
|---|---|
| `android/.../audio/AudioCodec.kt` | Interface: encode PCM → frame payload, decode payload → PCM. Lets Opus replace AMR later. |
| `android/.../audio/AmrNbCodec.kt` | `MediaCodec` implementation of the above. |
| `android/.../audio/AudioFrame.kt` | The wire frame: seq, memberId, payload. Pure, JVM-testable. |
| `android/.../audio/JitterBuffer.kt` | Per-talker reordering and late-drop. Pure, JVM-testable. |
| `android/.../audio/Mixer.kt` | Sums decoded PCM from several talkers with saturation. Pure, JVM-testable. |
| `android/.../audio/MicCapture.kt` | `AudioRecord` → 20 ms PCM chunks. |
| `android/.../audio/SpeakerOutput.kt` | `AudioTrack` playback plus speaker/earpiece routing. |
| `android/.../audio/AudioLink.kt` | The GATT transport for audio frames (shape decided by Task 1). |
| `android/.../audio/AudioEngine.kt` | Wires the above together; the single object `MainActivity` talks to. |
| `android/.../MainActivity.kt` | Extends the existing method channel with audio commands; adds the event channel. |
| `lib/transport/ble/ble_audio.dart` | Dart side of the audio channel. Commands out, level/error events in. |
| `lib/transport/ble/ble_transport.dart` | Its audio stubs stop being stubs. |

---

### Task 1: Gate — can Kotlin hold its own GATT beside the plugin's?

**Files:**
- Create: `android/app/src/main/kotlin/com/example/bconnect/audio/GattProbe.kt`
- Modify: `android/app/src/main/kotlin/com/example/bconnect/MainActivity.kt`
- Modify: `docs/DEVICE_TESTING.md`

**Interfaces:**
- Consumes: a peer MAC string from Dart
- Produces: a yes/no answer that decides Tasks 4 and 7

**Verification: device-verified. This task produces a measurement, not a feature.**

Do not write any audio code in this task. Do not proceed to Task 2 until the gate has an answer and the answer is recorded in the ledger.

- [ ] **Step 1: Write the probe**

Create `android/app/src/main/kotlin/com/example/bconnect/audio/GattProbe.kt`:

```kotlin
package com.example.bconnect.audio

import android.annotation.SuppressLint
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCallback
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattServer
import android.bluetooth.BluetoothGattServerCallback
import android.bluetooth.BluetoothGattService
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothProfile
import android.content.Context
import android.util.Log
import java.util.UUID

/**
 * Answers one question: can this app run a SECOND GATT server and a SECOND
 * GATT client alongside the ones `bluetooth_low_energy` already owns, over the
 * same ACL link?
 *
 * If yes, the audio path can live entirely in Kotlin as spec section 3.5
 * requires. If no, audio has to ride the Dart connection instead.
 *
 * Throwaway. Delete it once Task 1 has its answer.
 */
@SuppressLint("MissingPermission")
class GattProbe(private val context: Context) {
    companion object {
        private const val TAG = "BCX-PROBE"
        val AUDIO_SERVICE: UUID = UUID.fromString("0000b1d0-0000-1000-8000-00805f9b34fb")
        val AUDIO_CHAR: UUID = UUID.fromString("0000b1d1-0000-1000-8000-00805f9b34fb")
    }

    private val manager get() =
        context.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager

    private var server: BluetoothGattServer? = null
    private var client: BluetoothGatt? = null

    /** Host side: publish a second GATT server carrying only the audio service. */
    fun startServer() {
        val cb = object : BluetoothGattServerCallback() {
            override fun onServiceAdded(status: Int, service: BluetoothGattService) {
                Log.i(TAG, "server onServiceAdded status=$status uuid=${service.uuid}")
            }

            override fun onConnectionStateChange(
                device: android.bluetooth.BluetoothDevice, status: Int, newState: Int
            ) {
                Log.i(TAG, "server conn ${device.address} status=$status newState=$newState")
            }
        }

        val s = manager.openGattServer(context, cb)
        if (s == null) {
            Log.e(TAG, "openGattServer returned null — SECOND SERVER REFUSED")
            return
        }
        server = s

        val service = BluetoothGattService(
            AUDIO_SERVICE, BluetoothGattService.SERVICE_TYPE_PRIMARY
        )
        service.addCharacteristic(
            BluetoothGattCharacteristic(
                AUDIO_CHAR,
                BluetoothGattCharacteristic.PROPERTY_NOTIFY or
                    BluetoothGattCharacteristic.PROPERTY_WRITE_NO_RESPONSE,
                BluetoothGattCharacteristic.PERMISSION_WRITE,
            )
        )
        val added = s.addService(service)
        Log.i(TAG, "addService returned $added")
    }

    /** Client side: open our own GATT to a peer the Dart plugin is already connected to. */
    fun connect(address: String) {
        val device = manager.adapter.getRemoteDevice(address)
        val cb = object : BluetoothGattCallback() {
            override fun onConnectionStateChange(g: BluetoothGatt, status: Int, newState: Int) {
                Log.i(TAG, "client conn status=$status newState=$newState")
                if (newState == BluetoothProfile.STATE_CONNECTED) g.discoverServices()
            }

            override fun onServicesDiscovered(g: BluetoothGatt, status: Int) {
                val found = g.getService(AUDIO_SERVICE)
                Log.i(TAG, "client discovered status=$status audioService=${found != null}")
            }
        }
        client = device.connectGatt(context, false, cb, BluetoothDevice.TRANSPORT_LE)
    }

    fun stop() {
        client?.close(); client = null
        server?.close(); server = null
    }
}
```

Add `import android.bluetooth.BluetoothDevice` at the top.

- [ ] **Step 2: Expose the probe on the existing method channel**

In `MainActivity.kt`, inside the existing `setMethodCallHandler` `when (call.method)` block, add three branches before `else`:

```kotlin
                    "probeServer" -> {
                        probe.startServer()
                        result.success(null)
                    }
                    "probeConnect" -> {
                        probe.connect(call.argument<String>("address")!!)
                        result.success(null)
                    }
                    "probeStop" -> {
                        probe.stop()
                        result.success(null)
                    }
```

and a field on the class:

```kotlin
    private val probe by lazy { GattProbe(this) }
```

- [ ] **Step 3: Drive the probe from Dart**

In `lib/transport/ble/ble_transport.dart`, add a temporary method — clearly marked, to be deleted in Step 6:

```dart
  /// TEMPORARY — Plan B2 Task 1 gate only. Delete once the gate has an answer.
  ///
  /// The peer MAC is carried in the last twelve hex digits of the peerId,
  /// because `bluetooth_low_energy` builds its peer UUID with
  /// `UUID.fromAddress`.
  static String macFromPeerId(String peerId) {
    final hex = peerId.replaceAll('-', '');
    final node = hex.substring(hex.length - 12).toUpperCase();
    return List.generate(6, (i) => node.substring(i * 2, i * 2 + 2)).join(':');
  }

  Future<void> probeServer() => _serviceChannel.invokeMethod<void>('probeServer');
  Future<void> probeConnect(String peerId) => _serviceChannel
      .invokeMethod<void>('probeConnect', {'address': macFromPeerId(peerId)});
  Future<void> probeStop() => _serviceChannel.invokeMethod<void>('probeStop');
```

- [ ] **Step 4: Write the failing test for the MAC extraction**

This one piece IS unit-testable, and it is load-bearing — a wrong MAC makes the whole gate look like a hardware failure.

Add to `test/transport/ble/ble_transport_contract_test.dart`:

```dart
  test('recovers the peer MAC from a peerId', () {
    // Real peerId observed on device during Plan B1 Check 4.
    expect(
      BleTransport.macFromPeerId('00000000-0000-0000-0000-766ecb7a78ad'),
      '76:6E:CB:7A:78:AD',
    );
  });
```

Run: `flutter test test/transport/ble/ble_transport_contract_test.dart`
Expected: FAIL — `macFromPeerId` is not defined. Then implement Step 3 and re-run.
Expected: PASS.

**Mutation-verify it:** change the `substring` to take the FIRST twelve digits instead of the last, confirm the test fails, then restore.

- [ ] **Step 5: Run the gate on two phones**

Append to `docs/DEVICE_TESTING.md`:

```markdown
## Check 9 — Gate: a second GATT stack beside the plugin's (Plan B2 Task 1)

1. Phone A hosts "Team Alpha"; phone B joins. Both are connected as of Plan B1.
2. On phone A call `probeServer()`; on phone B call `probeConnect(peerId)`.
3. Watch both logs: `adb -s $A logcat -s BCX-PROBE:*`

PASS when ALL of these hold:
- phone A logs `addService returned true` and `server onServiceAdded status=0`
- phone B logs `client conn status=0 newState=2`
- phone B logs `client discovered status=0 audioService=true`
- **the Plan B1 control connection survives** — phone A's roster still shows
  2 members and neither side reports a disconnect

FAIL modes and what they mean:
- `openGattServer returned null` -> the platform refuses a second server.
- `audioService=false` -> the second server exists but is not visible to a
  second client on the shared link.
- The roster drops to 1 -> the second stack disturbs the first. This is the
  worst outcome and rules option A out on its own.
```

**Paste every one of those log lines into your report**, plus a screenshot of phone A's roster after the probe.

- [ ] **Step 6: Rule, record, and clean up**

Write the ruling into the ledger in this exact form:

- **Gate PASSED** — Tasks 4 and 7 proceed as written (option A). Delete `GattProbe.kt`, the three `MainActivity` branches, and `probeServer`/`probeConnect`/`probeStop` from `ble_transport.dart`. **Keep `macFromPeerId` and its test** — Task 4 needs it.
- **Gate FAILED** — record which FAIL mode, verbatim. Tasks 4 and 7 switch to option B: `AudioLink` becomes a thin Kotlin object that hands encoded frames to Dart over the method channel, and `BleTransport` writes them to `BleUuids.audioUp` / notifies on `BleUuids.audioDown` on the existing connection. Every other task is unchanged. Delete the probe as above. Note in the ledger that spec §3.5 is now knowingly violated and why.

Do not soften a failed gate into a pass. "It mostly connected" is a fail.

- [ ] **Step 7: Commit**

```bash
git add android lib/transport/ble/ble_transport.dart test/transport/ble docs/DEVICE_TESTING.md
git commit -m "test: gate whether Kotlin can hold a second GATT stack"
```

---

### Task 2: Audio frame codec

**Files:**
- Create: `android/app/src/main/kotlin/com/example/bconnect/audio/AudioFrame.kt`
- Test: `android/app/src/test/kotlin/com/example/bconnect/audio/AudioFrameTest.kt`

**Interfaces:**
- Consumes: nothing
- Produces: `AudioFrame(seq: Int, memberId: Int, payload: ByteArray)`, `AudioFrame.encode(): ByteArray`, `AudioFrame.decode(bytes: ByteArray): AudioFrame?`

**Verification: unit-testable (JVM).** Pure bytes, no Android APIs.

- [ ] **Step 1: Confirm JVM unit tests run at all**

The project has no `android/app/src/test/` yet. Create the directory and add to `android/app/build.gradle.kts`, inside the `dependencies` block (add the block if absent):

```kotlin
dependencies {
    testImplementation("junit:junit:4.13.2")
}
```

Run: `cd android && ./gradlew :app:testDebugUnitTest`
Expected: builds and reports zero tests. If Gradle cannot resolve JUnit, report BLOCKED rather than skipping the tests — every pure piece in this plan depends on this harness.

- [ ] **Step 2: Write the failing test**

Create `android/app/src/test/kotlin/com/example/bconnect/audio/AudioFrameTest.kt`:

```kotlin
package com.example.bconnect.audio

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class AudioFrameTest {
    @Test
    fun `round trips every field`() {
        val payload = ByteArray(32) { it.toByte() }
        val frame = AudioFrame(seq = 0x1234, memberId = 7, payload = payload)

        val decoded = AudioFrame.decode(frame.encode())!!

        assertEquals(0x1234, decoded.seq)
        assertEquals(7, decoded.memberId)
        assertArrayEquals(payload, decoded.payload)
    }

    @Test
    fun `seq is big endian across the byte boundary`() {
        // Catches a byte-swap that a symmetric round-trip test cannot see.
        val bytes = AudioFrame(seq = 0x0102, memberId = 0, payload = ByteArray(0)).encode()

        assertEquals(0x01.toByte(), bytes[0])
        assertEquals(0x02.toByte(), bytes[1])
    }

    @Test
    fun `seq wraps at 16 bits rather than overflowing the field`() {
        val frame = AudioFrame(seq = 0xFFFF, memberId = 1, payload = ByteArray(1))

        assertEquals(0xFFFF, AudioFrame.decode(frame.encode())!!.seq)
    }

    @Test
    fun `rejects a buffer shorter than the header`() {
        assertNull(AudioFrame.decode(ByteArray(3)))
    }

    @Test
    fun `rejects a truncated payload rather than reading past the end`() {
        // Header claims 10 bytes of payload; only 2 follow.
        val bytes = byteArrayOf(0, 1, 5, 10, 0xAA.toByte(), 0xBB.toByte())

        assertNull(AudioFrame.decode(bytes))
    }

    @Test
    fun `rejects a payload longer than one byte can describe`() {
        val tooBig = AudioFrame(seq = 1, memberId = 1, payload = ByteArray(256))

        try {
            tooBig.encode()
            throw AssertionError("expected encode to reject a 256-byte payload")
        } catch (e: IllegalArgumentException) {
            // expected: the length field is one byte
        }
    }
}
```

- [ ] **Step 3: Run it and watch it fail**

Run: `cd android && ./gradlew :app:testDebugUnitTest`
Expected: compilation failure — `AudioFrame` does not exist.

- [ ] **Step 4: Implement**

Create `android/app/src/main/kotlin/com/example/bconnect/audio/AudioFrame.kt`:

```kotlin
package com.example.bconnect.audio

/**
 * One 20 ms slice of one talker's voice, as it travels on the wire.
 *
 * Layout is fixed by spec section 5.4: [seq: uint16][memberId: uint8][len: uint8][payload].
 * Big-endian, to match every other multi-byte field in this protocol.
 *
 * `seq` exists so the receiver can reorder and discard late frames. It is
 * per-talker, not global, and wraps at 16 bits — about 21 minutes of
 * continuous speech at 50 frames per second.
 */
data class AudioFrame(
    val seq: Int,
    val memberId: Int,
    val payload: ByteArray,
) {
    companion object {
        const val HEADER_BYTES = 4
        const val MAX_PAYLOAD = 255

        fun decode(bytes: ByteArray): AudioFrame? {
            if (bytes.size < HEADER_BYTES) return null
            val len = bytes[3].toInt() and 0xFF
            // Refuse rather than read past the end: a truncated frame from a
            // dropped connection must not become a crash.
            if (bytes.size < HEADER_BYTES + len) return null
            return AudioFrame(
                seq = ((bytes[0].toInt() and 0xFF) shl 8) or (bytes[1].toInt() and 0xFF),
                memberId = bytes[2].toInt() and 0xFF,
                payload = bytes.copyOfRange(HEADER_BYTES, HEADER_BYTES + len),
            )
        }
    }

    fun encode(): ByteArray {
        require(payload.size <= MAX_PAYLOAD) {
            "payload is ${payload.size} bytes; the length field holds at most $MAX_PAYLOAD"
        }
        val out = ByteArray(HEADER_BYTES + payload.size)
        out[0] = ((seq shr 8) and 0xFF).toByte()
        out[1] = (seq and 0xFF).toByte()
        out[2] = (memberId and 0xFF).toByte()
        out[3] = payload.size.toByte()
        payload.copyInto(out, HEADER_BYTES)
        return out
    }

    // data class gives us == on the reference for ByteArray, which is wrong
    // and would make test failures baffling.
    override fun equals(other: Any?): Boolean =
        other is AudioFrame && other.seq == seq && other.memberId == memberId &&
            other.payload.contentEquals(payload)

    override fun hashCode(): Int =
        (seq * 31 + memberId) * 31 + payload.contentHashCode()
}
```

- [ ] **Step 5: Run the tests**

Run: `cd android && ./gradlew :app:testDebugUnitTest`
Expected: 6 tests PASS.

**Mutation-verify each:** swap the two `seq` bytes in `encode`; drop the `bytes.size < HEADER_BYTES + len` guard; drop the `require`. Confirm a test fails for each, then restore.

- [ ] **Step 6: Commit**

```bash
git add android
git commit -m "feat: add audio frame wire codec"
```

---

### Task 3: Jitter buffer and mixer

**Files:**
- Create: `android/app/src/main/kotlin/com/example/bconnect/audio/JitterBuffer.kt`
- Create: `android/app/src/main/kotlin/com/example/bconnect/audio/Mixer.kt`
- Test: `android/app/src/test/kotlin/com/example/bconnect/audio/JitterBufferTest.kt`
- Test: `android/app/src/test/kotlin/com/example/bconnect/audio/MixerTest.kt`

**Interfaces:**
- Consumes: `AudioFrame` (Task 2)
- Produces: `JitterBuffer(depth: Int)` with `offer(frame): Boolean` and `poll(): AudioFrame?`; `Mixer.mix(tracks: List<ShortArray>): ShortArray`

**Verification: unit-testable (JVM).** Both are pure. The radio's latency measurements from Phase 0 justify the default depth, but nothing here touches hardware.

Phase 0 measured 83 ms median round-trip on an idle link and 1294 ms saturated. A three-frame (60 ms) buffer absorbs ordinary jitter without adding audible delay; it will not save a saturated link, and it should not try to.

- [ ] **Step 1: Write the failing tests**

Create `android/app/src/test/kotlin/com/example/bconnect/audio/JitterBufferTest.kt`:

```kotlin
package com.example.bconnect.audio

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class JitterBufferTest {
    private fun frame(seq: Int) = AudioFrame(seq, memberId = 1, payload = ByteArray(1))

    @Test
    fun `returns frames in order when they arrive in order`() {
        val b = JitterBuffer(depth = 3)
        b.offer(frame(1)); b.offer(frame(2)); b.offer(frame(3))

        assertEquals(1, b.poll()!!.seq)
        assertEquals(2, b.poll()!!.seq)
        assertEquals(3, b.poll()!!.seq)
    }

    @Test
    fun `reorders a frame that overtook its predecessor`() {
        val b = JitterBuffer(depth = 3)
        b.offer(frame(2)); b.offer(frame(1)); b.offer(frame(3))

        assertEquals(1, b.poll()!!.seq)
        assertEquals(2, b.poll()!!.seq)
    }

    @Test
    fun `holds frames until the buffer is full, so reordering has a chance`() {
        // Polling eagerly would defeat the whole point of the buffer.
        val b = JitterBuffer(depth = 3)
        b.offer(frame(1)); b.offer(frame(2))

        assertNull(b.poll())
    }

    @Test
    fun `drops a frame that arrives after its slot has already played`() {
        val b = JitterBuffer(depth = 2)
        b.offer(frame(5)); b.offer(frame(6))
        b.poll() // plays 5

        assertFalse(b.offer(frame(4)))
    }

    @Test
    fun `accepts a fresh sequence after a wrap past 0xFFFF`() {
        // 21 minutes of continuous speech reaches this. Treating the wrap as
        // "ancient, drop it" would mute the talker permanently.
        val b = JitterBuffer(depth = 2)
        b.offer(frame(0xFFFE)); b.offer(frame(0xFFFF))
        b.poll()

        assertTrue(b.offer(frame(0)))
    }

    @Test
    fun `does not grow without bound when nothing is polled`() {
        val b = JitterBuffer(depth = 3)
        repeat(100) { b.offer(frame(it)) }

        assertEquals(3, b.size)
    }
}
```

Create `android/app/src/test/kotlin/com/example/bconnect/audio/MixerTest.kt`:

```kotlin
package com.example.bconnect.audio

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Test

class MixerTest {
    @Test
    fun `a single track passes through untouched`() {
        val track = shortArrayOf(100, -100, 0)

        assertArrayEquals(track, Mixer.mix(listOf(track)))
    }

    @Test
    fun `sums two tracks sample by sample`() {
        val a = shortArrayOf(100, 200)
        val b = shortArrayOf(10, 20)

        assertArrayEquals(shortArrayOf(110, 220), Mixer.mix(listOf(a, b)))
    }

    @Test
    fun `saturates instead of wrapping on positive overflow`() {
        // Wrapping turns a loud moment into a violent click.
        val a = shortArrayOf(Short.MAX_VALUE)
        val b = shortArrayOf(1000)

        assertEquals(Short.MAX_VALUE, Mixer.mix(listOf(a, b))[0])
    }

    @Test
    fun `saturates instead of wrapping on negative overflow`() {
        val a = shortArrayOf(Short.MIN_VALUE)
        val b = shortArrayOf(-1000)

        assertEquals(Short.MIN_VALUE, Mixer.mix(listOf(a, b))[0])
    }

    @Test
    fun `pads to the longest track rather than truncating to the shortest`() {
        val a = shortArrayOf(1, 2, 3)
        val b = shortArrayOf(10)

        assertArrayEquals(shortArrayOf(11, 2, 3), Mixer.mix(listOf(a, b)))
    }

    @Test
    fun `no tracks mixes to silence, not to a crash`() {
        assertEquals(0, Mixer.mix(emptyList()).size)
    }
}
```

- [ ] **Step 2: Run them and watch them fail**

Run: `cd android && ./gradlew :app:testDebugUnitTest`
Expected: compilation failure — neither class exists.

- [ ] **Step 3: Implement the jitter buffer**

Create `android/app/src/main/kotlin/com/example/bconnect/audio/JitterBuffer.kt`:

```kotlin
package com.example.bconnect.audio

/**
 * Reorders one talker's frames and discards ones that arrive too late to use.
 *
 * There is one of these per talker. `depth` frames are held before anything is
 * released, which buys that much time for a frame that took a slower path.
 * Phase 0 measured 83 ms median round-trip on an idle link, so three 20 ms
 * frames absorbs ordinary jitter at a cost of 60 ms — below the threshold
 * where conversation starts to feel like a radio handover.
 *
 * Not thread-safe by design: it is owned by the single audio thread.
 */
class JitterBuffer(private val depth: Int) {
    private val frames = sortedMapOf<Int, AudioFrame>()
    private var lastPlayed: Int? = null

    val size: Int get() = frames.size

    /** Returns false when the frame was too late to be useful and was dropped. */
    fun offer(frame: AudioFrame): Boolean {
        val last = lastPlayed
        if (last != null && !isNewerThan(frame.seq, last)) return false

        frames[frame.seq] = frame
        // Never grow without bound: a listener that stops polling must not
        // turn a stalled link into an out-of-memory kill.
        while (frames.size > depth) frames.remove(frames.firstKey())
        return true
    }

    /** Null until the buffer has filled, then the oldest held frame. */
    fun poll(): AudioFrame? {
        if (frames.size < depth) return null
        val key = frames.firstKey()
        val frame = frames.remove(key)
        lastPlayed = key
        return frame
    }

    /**
     * Sequence comparison on a 16-bit field that wraps.
     *
     * A plain `>` would treat seq 0 as ancient once 0xFFFF has played, which
     * silences the talker for good roughly 21 minutes into a continuous
     * transmission. Anything within half the space ahead counts as newer.
     */
    private fun isNewerThan(a: Int, b: Int): Boolean =
        ((a - b) and 0xFFFF) in 1 until 0x8000
}
```

- [ ] **Step 4: Implement the mixer**

Create `android/app/src/main/kotlin/com/example/bconnect/audio/Mixer.kt`:

```kotlin
package com.example.bconnect.audio

/**
 * Sums several talkers into one output buffer.
 *
 * The host relays rather than mixing (spec section 5.4), so this runs on every
 * client, over at most `maxConcurrentTalkers` streams.
 */
object Mixer {
    fun mix(tracks: List<ShortArray>): ShortArray {
        if (tracks.isEmpty()) return ShortArray(0)
        if (tracks.size == 1) return tracks[0]

        val out = ShortArray(tracks.maxOf { it.size })
        for (track in tracks) {
            for (i in track.indices) {
                // Sum in Int, then clamp. Adding in Short would wrap, and a
                // wrap is heard as a hard click rather than as loudness.
                val sum = out[i].toInt() + track[i].toInt()
                out[i] = sum.coerceIn(Short.MIN_VALUE.toInt(), Short.MAX_VALUE.toInt()).toShort()
            }
        }
        return out
    }
}
```

- [ ] **Step 5: Run the tests**

Run: `cd android && ./gradlew :app:testDebugUnitTest`
Expected: 12 tests PASS (6 from Task 2, 6 new here, plus the mixer's 6 — 18 total).

**Mutation-verify:** replace `isNewerThan` with a plain `a > b` and confirm the wrap test fails; remove the `while (frames.size > depth)` trim and confirm the unbounded-growth test fails; replace `coerceIn` with a plain `.toShort()` and confirm both saturation tests fail. Restore each.

- [ ] **Step 6: Commit**

```bash
git add android
git commit -m "feat: add jitter buffer and PCM mixer"
```

---

### Task 4: The audio link

**Files:**
- Create: `android/app/src/main/kotlin/com/example/bconnect/audio/AudioLink.kt`
- Modify: `docs/DEVICE_TESTING.md`

**Interfaces:**
- Consumes: Task 1's ruling; `AudioFrame` (Task 2)
- Produces: `AudioLink` with `send(frame: AudioFrame)`, `onFrame: (AudioFrame) -> Unit`, `start(role)`, `stop()`

**Verification: device-verified.** Two phones, frames counted at both ends.

**Its shape depends entirely on Task 1.** Do not start until the ledger records the gate's answer.

- [ ] **Step 1: Read the gate ruling and pick the shape**

If the gate **passed**, `AudioLink` owns a `BluetoothGattServer` on the host and a `BluetoothGatt` client on the joiner, using `BleUuids.audioUp` / `audioDown`, entirely in Kotlin — extend `GattProbe`'s proven structure into a real class.

If the gate **failed**, `AudioLink` becomes a shim: `send` hands the encoded frame to Dart over the method channel, and Dart writes it on the existing connection; `onFrame` is fed from Dart. Write the class so `AudioEngine` cannot tell the difference — the interface below is identical either way.

```kotlin
interface AudioLink {
    var onFrame: ((AudioFrame) -> Unit)?
    fun start(isHost: Boolean)
    fun send(frame: AudioFrame)
    fun stop()
}
```

- [ ] **Step 2: Implement the host relay**

Whichever shape, the host's behaviour is the same and is spec §5.4: on receiving a frame from member X, forward the bytes **unchanged** to every connected member except X. Do not decode. Do not re-encode. Do not mix.

```kotlin
    /**
     * Relay, not mix (spec section 5.4).
     *
     * Forwarding the encoded bytes untouched avoids transcoding loss, avoids
     * the host computing N different mixes, and means nobody is ever sent
     * their own voice — so there is no echo problem to solve.
     */
    private fun relay(from: String, raw: ByteArray) {
        for ((address, peer) in peers) {
            if (address == from) continue
            peer.notify(raw)
        }
    }
```

- [ ] **Step 3: Add device Check 10**

Append to `docs/DEVICE_TESTING.md`:

```markdown
## Check 10 — frames cross the link (Plan B2 Task 4)

With two phones in a group, drive `AudioLink` directly with synthetic frames —
no microphone yet.

1. Phone B sends 250 frames (5 seconds' worth) of a known payload.
2. Count what phone A logs.

PASS when:
- phone A receives 250 frames, or loses fewer than 5
- sequence numbers arrive in order, or out of order by no more than 2
- the Plan B1 control connection still shows 2 members throughout

A loss rate above 2% here means the audio path will sound broken no matter how
good the codec is. Stop and investigate rather than continuing to Task 5.
```

- [ ] **Step 4: Run Check 10 and paste the counts**

- [ ] **Step 5: Commit**

```bash
git add android docs/DEVICE_TESTING.md
git commit -m "feat: carry audio frames over the radio"
```

---

### Task 5: Capture and encode

**Files:**
- Create: `android/app/src/main/kotlin/com/example/bconnect/audio/AudioCodec.kt`
- Create: `android/app/src/main/kotlin/com/example/bconnect/audio/AmrNbCodec.kt`
- Create: `android/app/src/main/kotlin/com/example/bconnect/audio/MicCapture.kt`

**Interfaces:**
- Consumes: `AudioFrame` (Task 2), `AudioLink` (Task 4)
- Produces: `AudioCodec` interface; `AmrNbCodec`; `MicCapture` with `start(onChunk: (ShortArray) -> Unit)` and `stop()`

**Verification: device-verified.** A microphone cannot be faked.

- [ ] **Step 1: Define the codec interface**

Spec §5.4 requires AMR to sit behind an interface so Opus can replace it.

```kotlin
package com.example.bconnect.audio

/** 20 ms of 8 kHz mono PCM in, one frame payload out, and back. */
interface AudioCodec {
    val sampleRate: Int
    val samplesPerFrame: Int
    fun encode(pcm: ShortArray): ByteArray
    fun decode(payload: ByteArray): ShortArray
    fun release()
}
```

- [ ] **Step 2: Implement AMR-NB over MediaCodec**

`AmrNbCodec` wraps two `MediaCodec` instances (`audio/3gpp`, 8000 Hz, 1 channel, bitrate 12200). Configure the encoder with `MediaFormat.KEY_BIT_RATE = 12200`.

Two things that bite here, both worth a comment in the code:

- `MediaCodec` is asynchronous by nature. Use the synchronous `dequeueInputBuffer` / `dequeueOutputBuffer` loop with a short timeout on the audio thread — the callback form drags the work onto another thread and reorders frames.
- AMR-NB emits a one-byte frame header. Keep it: the decoder needs it, and stripping it to save one byte per frame costs more than it saves.

- [ ] **Step 3: Implement microphone capture**

`AudioRecord` at 8000 Hz, `CHANNEL_IN_MONO`, `ENCODING_PCM_16BIT`, source `MediaRecorder.AudioSource.VOICE_COMMUNICATION` — it enables the platform's echo cancellation and noise suppression, which matters when the speaker is playing other talkers into the same room.

Read in `samplesPerFrame` chunks (160 samples = 20 ms at 8 kHz) on a dedicated thread. Never on the main thread.

- [ ] **Step 4: Request RECORD_AUDIO at first talk**

Add to `lib/transport/ble/ble_permissions.dart`:

```dart
  /// Asked when the user first tries to talk, not at startup: a walkie-talkie
  /// that demands the microphone before you have joined anything reads as
  /// hostile, and the permission is useless until there is someone to talk to.
  static Future<BlePermissionResult> requestMicrophone() async {
    return _map(await Permission.microphone.request());
  }
```

- [ ] **Step 5: Add device Check 11**

```markdown
## Check 11 — the microphone reaches the radio (Plan B2 Task 5)

Phone A hosts, phone B joins. Hold talk on phone B and speak for 5 seconds.

PASS when:
- the microphone permission dialog appears the FIRST time talk is held, and
  not before
- phone B logs roughly 250 encoded frames (50/second), each 32 bytes or fewer
- phone A logs roughly the same number received
- phone A's roster shows phone B as talking, and stops when talk is released
```

- [ ] **Step 6: Run Check 11 and paste the frame counts and sizes**

- [ ] **Step 7: Commit**

```bash
git add android lib/transport/ble/ble_permissions.dart docs/DEVICE_TESTING.md
git commit -m "feat: capture and encode microphone audio"
```

---

### Task 6: Decode, mix and play

**Files:**
- Create: `android/app/src/main/kotlin/com/example/bconnect/audio/SpeakerOutput.kt`
- Create: `android/app/src/main/kotlin/com/example/bconnect/audio/AudioEngine.kt`

**Interfaces:**
- Consumes: everything from Tasks 2–5
- Produces: `AudioEngine` with `startTalking()`, `stopTalking()`, `setMicEnabled(Boolean)`, `setRoute(speaker|earpiece)`, `start(isHost)`, `stop()`

**Verification: device-verified. This is the task where the app first makes a sound.**

- [ ] **Step 1: Implement playback**

`AudioTrack` at 8000 Hz mono, `STREAM_VOICE_CALL` usage. One buffer per 20 ms tick.

- [ ] **Step 2: Implement the engine loop**

One dedicated thread, driven at 20 ms:

1. Drain `AudioLink` into per-talker `JitterBuffer`s, keyed by `memberId`.
2. Poll each buffer; decode each frame it yields.
3. `Mixer.mix` the decoded tracks.
4. Write to `AudioTrack`.

A talker with no frame this tick contributes nothing — do not insert silence per talker and do not stall the tick waiting.

Retire a talker's buffer after ~1 second of nothing, so a member who leaves mid-word does not hold a slot forever.

- [ ] **Step 3: Add device Check 12 — the milestone**

```markdown
## Check 12 — one phone hears the other (Plan B2 Task 6)

Phone A hosts, phone B joins. Put the phones in different rooms so acoustic
coupling cannot fake a pass.

1. Hold talk on phone B and speak.

PASS when phone A plays the audio, intelligibly, with delay that does not
disrupt conversation.

2. Release, then hold talk on phone A and speak.

PASS when phone B hears it.

3. Both hold talk and speak at once.

PASS when each hears the other, and neither hears themselves.

Record what you actually heard, including the delay and any artefacts. "It
worked" is not a result; "clear, roughly a quarter-second behind, slight
click at the start of each transmission" is.
```

- [ ] **Step 4: Run Check 12**

This is what the whole plan is for. If it fails, say exactly what you heard.

- [ ] **Step 5: Commit**

```bash
git add android docs/DEVICE_TESTING.md
git commit -m "feat: decode, mix and play received audio"
```

---

### Task 7: Wire the engine to Dart

**Files:**
- Modify: `android/app/src/main/kotlin/com/example/bconnect/MainActivity.kt`
- Create: `lib/transport/ble/ble_audio.dart`
- Modify: `lib/transport/ble/ble_transport.dart`
- Test: `test/transport/ble/ble_audio_test.dart`

**Interfaces:**
- Consumes: `AudioEngine` (Task 6)
- Produces: `BleTransport.setMicEnabled` / `setAudioRoute` / `startTalking` / `stopTalking` stop being no-ops

**Verification: unit-testable for the command mapping; device-verified for the effect.**

- [ ] **Step 1: Extend the method channel**

Add to the existing `bconnect/group_service` handler — or a second channel `bconnect/audio`, which is cleaner — the methods `startTalking`, `stopTalking`, `setMicEnabled(enabled)`, `setAudioRoute(route)`, `startAudio(isHost)`, `stopAudio`.

- [ ] **Step 2: Write the failing test**

Create `test/transport/ble/ble_audio_test.dart`, using `TestDefaultBinaryMessengerBinding` to record what the channel receives:

```dart
  test('setAudioRoute sends the route as a string the platform understands', () async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(BleAudio.channel, (call) async {
      calls.add(call);
      return null;
    });

    await BleAudio.setAudioRoute(AudioRoute.earpiece);

    expect(calls.single.method, 'setAudioRoute');
    expect(calls.single.arguments, {'route': 'earpiece'});
  });
```

Add the mirror test for `speaker`, and one asserting `startTalking` sends no arguments.

**Mutation-verify:** make the mapping return `'speaker'` for both values and confirm the earpiece test fails.

- [ ] **Step 3: Implement `BleAudio` and replace the stubs**

The four `GroupTransport` audio methods in `BleTransport` now delegate to `BleAudio`. Keep them tolerant of a missing handler — the same broad `catch` the foreground-service methods use, and for the same reason: `flutter test` has no platform side.

- [ ] **Step 4: Confirm the suite still passes**

Run: `flutter test && flutter analyze`
Expected: all PASS, `No issues found!`

- [ ] **Step 5: Add device Check 13**

```markdown
## Check 13 — the controls do what they say (Plan B2 Task 7)

With two phones talking:

1. Tap Mute on the talking phone.

PASS when the other phone stops hearing it, and the roster still shows both
members.

2. Untap Mute.

PASS when audio resumes.

3. Toggle Speaker/Earpiece on the listening phone.

PASS when the sound moves between the loudspeaker and the earpiece. Hold the
phone to your ear to confirm the earpiece case.

4. End Call on the host.

PASS when audio stops on both phones and neither is left with a live
microphone. Confirm with:
    adb -s $A shell dumpsys media.audio_flinger | grep -i "Input thread"
```

- [ ] **Step 6: Run Check 13 and paste what you observed for all four**

- [ ] **Step 7: Commit**

```bash
git add android lib test docs/DEVICE_TESTING.md
git commit -m "feat: wire talk, mute and audio route to the engine"
```

---

### Task 8: Level meter

**Files:**
- Modify: `android/app/src/main/kotlin/com/example/bconnect/audio/AudioEngine.kt`
- Modify: `android/app/src/main/kotlin/com/example/bconnect/MainActivity.kt`
- Modify: `lib/transport/ble/ble_audio.dart`
- Modify: `lib/state/` — whichever provider drives the talk button

**Interfaces:**
- Consumes: `AudioEngine`
- Produces: an `EventChannel("bconnect/audio/events")` emitting `{level: 0.0-1.0}`, throttled

**Verification: device-verified.**

Spec §4.1 lists `audioLevel` as an event. The UI already has a talk button; a level meter is what tells the user their microphone is actually live.

- [ ] **Step 1: Compute the level in Kotlin**

RMS over each captured chunk, normalised to 0..1. **Emit at most 10 events per second**, not 50 — the UI cannot render faster than that and the channel traffic is pure waste. This throttle is the whole reason level events are allowed across the boundary at all when audio frames are not.

- [ ] **Step 2: Surface it in Dart and drive the existing talk button's visual state**

- [ ] **Step 3: Add device Check 14**

```markdown
## Check 14 — the level meter tracks the voice (Plan B2 Task 8)

Hold talk and speak, then go quiet while still holding.

PASS when the meter rises with speech and falls to near zero in silence,
and when it moves smoothly rather than in visible steps.
```

- [ ] **Step 4: Run it, then commit**

```bash
git add android lib docs/DEVICE_TESTING.md
git commit -m "feat: report microphone level to the UI"
```

---

### Task 9: Hardening and the full journey

**Files:**
- Modify: `android/app/src/main/kotlin/com/example/bconnect/audio/AudioEngine.kt`
- Modify: `docs/DEVICE_TESTING.md`

**Verification: device-verified.**

- [ ] **Step 1: Release the microphone whenever talking stops**

Not only on `stopTalking`, but on leaving the group, on the group ending, on the adapter dropping, and in `stop()`. A held `AudioRecord` blocks every other app on the phone from recording. Mirror the reasoning in Plan B1's `dispose()`.

- [ ] **Step 2: Survive the screen lock**

The foreground service from Plan B1 Task 10 keeps the process alive, but its `foregroundServiceType` is `connectedDevice`. Recording while backgrounded on Android 14 needs `microphone` in the type list too. Change the manifest to:

```xml
            android:foregroundServiceType="connectedDevice|microphone"
```

and add `<uses-permission android:name="android.permission.FOREGROUND_SERVICE_MICROPHONE" />`.

Android 14 kills a service that records without declaring it. Verify this rather than assuming it.

- [ ] **Step 3: Add device Check 15**

```markdown
## Check 15 — audio under real conditions (Plan B2 Task 9)

**Backgrounded.** Phone B joins, then locks its screen. Phone A talks.

PASS when phone B still plays the audio.

**Talking while locked.** Phone B holds talk with the screen off (via the
notification, or immediately after locking).

PASS when phone A hears it and phone B is not killed.

**Out of range mid-word.** Phone A talks; turn phone B's Bluetooth off
mid-sentence.

PASS when phone A stops cleanly, its roster drops to 1, and no microphone is
left held. Confirm with `dumpsys media.audio_flinger`.

**Five minutes.** Hold a conversation for five minutes.

PASS when audio quality does not degrade, no drift builds up, and no member is
dropped.
```

- [ ] **Step 4: Run all four and paste what you observed**

- [ ] **Step 5: Commit**

```bash
git add android docs/DEVICE_TESTING.md
git commit -m "fix: release the mic reliably and record while backgrounded"
```

---

### Task 10: Update the spec and README against what was measured

**Files:**
- Modify: `docs/superpowers/specs/2026-08-26-bluetooth-group-talk-design.md`
- Modify: `README.md`

**Verification: review.**

- [ ] **Step 1: Record Task 1's gate result in spec §9.1**

Alongside the Phase 0 gates, in the same form. If the gate failed, say plainly that §3.5 is not met and why.

- [ ] **Step 2: Record the measured audio latency in spec §5.4**

Replace any assumption with the number Check 12 produced.

- [ ] **Step 3: Rewrite the README status section**

It currently says audio is not implemented. State what works, what the measured delay is, and what remains — Gate 3 and anything Check 15 exposed.

- [ ] **Step 4: Commit**

```bash
git add docs README.md
git commit -m "docs: record measured audio behaviour"
```

---

## Self-review

**Spec coverage.** §3.5 audio-in-Kotlin — Tasks 1, 4–7, with Task 1 gating the claim honestly. §4.1 channel contract — Tasks 7, 8. §5.4 frame layout, AMR-NB, relay-not-mix, 3-talker cap — Tasks 2, 4, 5, 6; the cap is enforced by the existing Dart control plane and Task 6 deliberately does not duplicate it. §8 error handling — Task 9. §9.1 Gate 3 — **not covered here**: it still needs a third phone and remains Plan B1's Task 11.

**Gaps I am leaving open, deliberately.** Opus is not implemented; the codec interface in Task 5 is the seam for it and nothing more. Audio encryption is out of scope, as spec §7 already states — the link is walkie-talkie grade. Bluetooth headset routing is out of scope; Task 7 covers only the phone's own speaker and earpiece.

**Type consistency.** `AudioFrame` fields (`seq`, `memberId`, `payload`) are used identically in Tasks 2, 3, 4 and 6. `AudioCodec.samplesPerFrame` is defined in Task 5 and consumed in Tasks 5 and 6. `AudioLink`'s interface is fixed in Task 4 Step 1 and used unchanged in Task 6 regardless of which branch the gate took.

**Risk I want stated.** Task 1 can fail, and if it does the plan knowingly departs from the spec. That is why it is a measurement rather than a decision made here, and why its fallback is written out in advance instead of being improvised at the time.
