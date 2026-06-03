# Pitfalls Research

**Domain:** Multi-device BLE expansion + Android cross-compilation + second wearable — on top of existing iOS+Rust BLE capture app
**Researched:** 2026-06-03
**Confidence:** HIGH — all pitfalls derived from direct code inspection of the existing codebase (GooseBLEClient, GooseNotificationEvent, GooseUploadService, store.rs, protocol.rs, Cargo.toml, build_ios_rust.sh) and verified against CoreBluetooth delegate semantics, Rust cross-compilation requirements, and JNI memory rules.

---

## Critical Pitfalls

Mistakes that cause data loss, silent frame misrouting, or require rewrites.

---

### Pitfall 1: Device type string mismatch between Swift and Rust

**What goes wrong:**
`GooseNotificationEvent.rustDeviceType` is derived purely from the characteristic UUID prefix: `characteristicUUID.lowercased().hasPrefix("610800") ? "GEN4" : "GOOSE"`. This string is then passed verbatim into the Rust bridge as `"device_type"` in every bridge call. The Rust `parse_device_type` function accepts `"GEN4"` for Gen4. Everything works for WHOOP Gen4 (service `61080001-...`) and Gen5/Goose (`fd4b0001-...`). The pitfall is a second wearable: its characteristic UUIDs will not start with `"610800"`, so it falls through to `"GOOSE"` — which maps to the Goose (Gen5) protocol parser. The bytes get fed to the wrong parser, producing either silent garbage or a CRC validation failure with no user-visible error.

**Why it happens:**
The device type classification is implicit — derived from a UUID prefix heuristic rather than an explicit enum at connect time. Adding a third device that uses neither UUID prefix requires extending this heuristic, but the heuristic is a computed `var` on `GooseNotificationEvent` deep in `GooseBLETypes.swift`. Developers adding a new wearable are likely to add the UUID to the scan list and write a new Rust parsing module, but forget to update `rustDeviceType` — and every notification from that device silently routes to the wrong parser.

**Consequences:**
Frames from the second wearable are parsed by the wrong Rust module. `parse_frame_hex` returns either an error (dropped silently in the pipeline) or a structurally malformed `ParsedFrame` that gets stored in `decoded_frames` with a wrong `device_type` TEXT column value. Metric algorithms that filter by `device_type` produce nonsense output. The frame reassembly key in `gooseFrames(in:event:)` uses `rustDeviceType` as a discriminator, so the wrong header length (4 vs 8 bytes) is used, corrupting reassembly.

**Prevention:**
Introduce a proper `WearableKind` enum in `GooseBLETypes.swift` that is resolved at service discovery time (in `processDiscoveredCharacteristics`) and stored on `GooseBLEClient` alongside `commandCharacteristic`. Propagate `WearableKind` through `GooseNotificationEvent` (or store it on the active peripheral context). Never derive device type from a characteristic UUID prefix at notification time — that approach breaks the moment a third device exists.

**Warning signs:**
- A new wearable's notifications appear in the log with `type=GOOSE` despite the device not being a WHOOP Gen5.
- `parse_frame_hex` returns CRC errors for every frame from the new device.
- Frame reassembly for the new device produces only zero-length or oversized frames.

**Phase to address:** WEAR-01 (second wearable BLE pipeline) — must define the `WearableKind` extension point before writing any notification handling code.

---

### Pitfall 2: Gen4 device classification at scan time vs connect time — the race condition

**What goes wrong:**
The current `whoopIdentityEvidence` function accepts a peripheral as a WHOOP candidate if it advertises a service UUID in `whoopServices` (which already contains both `fd4b0001-...` for Gen5 and `61080001-...` for Gen4), or if its name contains "whoop". Device generation (Gen4 vs Gen5) is not classified at scan/connect time — it is derived per-notification from `characteristicUUID`. This means `GooseBLEClient` has no `connectedDeviceGeneration` property. The iOS layer does not know it has a Gen4 until the first notification arrives.

The race condition: `sendClientHello` is called in `processDiscoveredCharacteristics` as soon as the command characteristic is found. The Gen4 and Gen5 HELLO commands have the same framing (`buildV5CommandFrame`), so this part is safe. But `supportsV5HistoricalSync`, `supportsV5AlarmCommands`, and `supportsV5ClockCommands` are all computed from `isV5CommandCharacteristic` which checks for the `fd4b0002-...` prefix. A Gen4 device uses `61080002-...` for its command characteristic, so `isV5CommandCharacteristic` returns `false` — and all those capabilities are reported as unsupported before any data has flowed.

**Why it happens:**
The naming "V5" in `supportsV5HistoricalSync` is misleading — it really means "fd4b prefix" which is the Gen5 UUID family. Gen4 uses the `61080` prefix family. The existing code was written for Gen5 only, so Gen4 was never expected to reach the `canSyncHistorical` guard. Adding Gen4 to the scan without updating these guards means Gen4 historical sync is silently disabled the moment the device connects.

**Consequences:**
Historical sync UI shows "disabled" for Gen4 devices even when the hardware supports it. Clock sync, alarm writes, and sensor commands are blocked for Gen4. If historical sync is triggered manually and the guard is bypassed, the command is written using the wrong characteristic (wrong UUID), and the strap ignores it.

**Prevention:**
At `processDiscoveredCharacteristics` time, resolve and store the connected device generation (Gen4 when `61080002-...` is the command characteristic; Gen5 when `fd4b0002-...` is found). Store this as a `connectedDeviceKind: ConnectedDeviceKind` property on `GooseBLEClient`. Rewrite `supportsV5HistoricalSync` etc. to check `connectedDeviceKind` rather than checking `commandCharacteristic.uuid` prefix. Rename these computed vars to `supportsHistoricalSync` to eliminate the "V5" misnomer.

**Warning signs:**
- Gen4 connects but `canSyncHistorical` is false in the UI.
- Logs show `"historical_sync.auto_skipped"` immediately after Gen4 connection despite `autoHistoricalSyncOnReady = true`.
- `commandCharacteristic.uuid.uuidString` in the alarm write support summary shows `61080002-...` but `supportsV5AlarmCommands` is false.

**Phase to address:** GEN4-01 (Gen4 BLE iOS layer) — the very first step must be resolving and storing device generation, not just adding the UUID to the scan filter.

---

### Pitfall 3: `scanForPeripherals(withServices:)` with both WHOOP service UUIDs does not require two separate scans

**What goes wrong:**
The assumption that "adding Gen4 scan support" means "call `scanForPeripherals` twice" is wrong and harmful. `CBCentralManager.scanForPeripherals(withServices:)` accepts an array — passing both `fd4b0001-...` and `61080001-...` in a single array causes CoreBluetooth to report any peripheral advertising either UUID. Calling `scanForPeripherals` a second time while a scan is already active silently restarts the scan with only the new parameters, dropping the first UUID from the filter. Any in-flight discovery of the first UUID is aborted.

**Why it happens:**
The current `whoopServices` array already contains both UUIDs: `fd4b0001-...` and `61080001-...`. Developers working on Gen4 support who do not read `GooseBLEClient.swift` carefully may assume only one UUID is scanned for (because the existing code was only tested with Gen5 hardware) and try to add a second `scanForPeripherals` call.

**Consequences:**
The second `scanForPeripherals` call drops the first UUID filter. If Gen5 is discovered mid-scan, its discovery event is lost. The scan runs with only the Gen4 UUID, so Gen5 devices are invisible until the next scan cycle. This is not logged as an error — CoreBluetooth silently accepts the new parameters.

**Prevention:**
The scan call at line ~134 of `GooseBLEClient+UserActions.swift` already passes `whoopServices` (both UUIDs). Gen4 scan support requires only verifying that `61080001-...` is in `whoopServices` — which it already is. The actual work for Gen4 is in classification at connect time, not scan time. Document this explicitly to prevent future confusion.

**Warning signs:**
- `startScan` is called more than once in sequence without `stopScan` between them.
- Second call to `scanForPeripherals` appears anywhere in the codebase.
- Logs show `"scan.started"` twice without an intervening `"scan.stopped"`.

**Phase to address:** GEN4-01 — verify at the outset that no second scan call is added; the scan filter is already correct.

---

### Pitfall 4: Background scan filter stops matching in the background without `CBCentralManagerOptionRestoreIdentifierKey`

**What goes wrong:**
When iOS suspends the app during a BLE scan (e.g., user puts phone down during overnight data capture), CoreBluetooth's background execution mode (`bluetooth-central` in `UIBackgroundModes`) allows scanning to continue — but only for peripherals advertising service UUIDs that were declared in `scanForPeripherals(withServices:)`. Adding a second wearable whose primary service UUID is not in the `withServices` array means that device is invisible in the background, even if its BLE advertisement is active.

The deeper pitfall: adding a third-party wearable (Polar OH1, Amazfit, etc.) whose primary service UUID is unknown or unpublished means the `withServices` array cannot be populated correctly, and background scanning for that device is impossible without the `nil` (all peripherals) option — which iOS does not permit in the background.

**Why it happens:**
Developers test on-screen with the app in the foreground, where `withServices: nil` and `CBCentralManagerScanOptionAllowDuplicatesKey: false` both work. Background execution applies stricter rules that are not enforced during foreground testing.

**Consequences:**
The second wearable is only discoverable while the app is in the foreground. Overnight/background capture silently captures zero data from the new device. This manifests as "works in testing, fails in production overnight runs."

**Prevention:**
- Know the primary GATT service UUID of every target wearable before starting implementation. Background scanning requires this UUID.
- Add the new wearable's primary service UUID to `whoopServices` (or a renamed `knownWearableServices` array).
- Verify background scanning behavior explicitly: lock the screen, wait 30 seconds, confirm the device is discovered in the log.
- If the second wearable does not advertise a stable service UUID, background capture is not possible — document this as a constraint.

**Warning signs:**
- Second wearable discovered in foreground tests but not in overnight BLE log.
- No `"device.discovered"` log entry for the second wearable after screen-lock.
- `whoopServices` array does not contain the second wearable's primary service UUID.

**Phase to address:** WEAR-01 — before any code, confirm the target wearable's service UUID and its background scan behavior.

---

### Pitfall 5: `panic = "abort"` in the release profile is incompatible with JNI on Android

**What goes wrong:**
`Cargo.toml` declares `panic = "abort"` in `[profile.release]`. On iOS this is correct — panicking in Rust and unwinding through the Swift FFI boundary is undefined behavior, so aborting is the right choice. On Android, however, the JNI bridge runs Rust inside a JVM process. A Rust `panic = "abort"` causes the entire JVM process to receive `SIGABRT` and die instantly — there is no chance for the JVM to handle the exception, log it, or surface it to the Kotlin/Java layer. This also means the Android app cannot recover from any Rust error.

**Why it happens:**
The `panic = "abort"` setting was added for iOS and is appropriate there. Cross-compilation to Android reuses the same `Cargo.toml` and the same `[profile.release]`, so the setting applies to the Android target as well.

**Consequences:**
Any unhandled Rust error (including rusqlite errors if the SQLite file is corrupted or the path is wrong) causes the entire Android process to die with SIGABRT. On Android, unlike iOS, this is fully visible to users as an app crash — not just a silent failure. The crash cannot be caught or reported.

**Prevention:**
Use a `[profile.release-android]` custom profile or a `[target.aarch64-linux-android]` override that sets `panic = "unwind"`. Alternatively, ensure all Rust functions exposed via JNI return `Result` types that are never unwrapped without an `or_else` — `std::panic::catch_unwind` at the JNI boundary is the correct pattern, returning a Java exception instead of aborting.

**Warning signs:**
- Android app silently dies with no Java stack trace; only a native `SIGABRT` in logcat.
- `panic = "abort"` applies to the `aarch64-linux-android` target profile.
- JNI bridge functions use `.unwrap()` or `.expect()` on `Result` types.

**Phase to address:** ANDROID-01 (Rust JNI-ready compilation) — the profile and unwrap discipline must be established before any JNI bridge function is written.

---

### Pitfall 6: `rusqlite` with `bundled` feature cross-compiles to Android but requires the correct `cc` toolchain and NDK linker

**What goes wrong:**
`rusqlite = { version = "0.37", features = ["bundled"] }` compiles SQLite from source via the `cc` crate. On the iOS build, this works because `build_ios_rust.sh` sets `CARGO_TARGET_AARCH64_APPLE_IOS_LINKER` to the Xcode `clang` binary. For Android, the equivalent linker path must be set for `aarch64-linux-android`. If it is not set, Cargo uses the host `cc` (macOS clang), which produces iOS/macOS binaries instead of Android ELF shared objects. The error message is a linker error (`ld: warning: ignoring file ...wrong architecture`) that looks like a build failure but is actually a configuration problem.

The secondary issue: the NDK provides `aarch64-linux-android21-clang` (or the version-specific variant); the correct executable path depends on the NDK version installed and the minimum API level. NDK r23+ changed the toolchain layout, dropping the `aarch64-linux-android-clang` without version suffix that was standard in older tutorials.

**Why it happens:**
Cross-compilation for Android requires setting environment variables that parallel what `build_ios_rust.sh` does for iOS, but for the Android toolchain. There is no existing Android build script in this repo — it must be created from scratch. The `bundled` SQLite feature is the right choice (avoids depending on the Android system SQLite), but it requires the C compiler chain to be fully resolved.

**Consequences:**
Without explicit NDK linker configuration, `cargo build --target aarch64-linux-android` fails with a cryptic linker error. This blocks the entire ANDROID-01 milestone.

**Prevention:**
Create a `.cargo/config.toml` in `Rust/core/` (or a project-root config) that sets:
```toml
[target.aarch64-linux-android]
linker = "/path/to/NDK/toolchains/llvm/prebuilt/darwin-x86_64/bin/aarch64-linux-android21-clang"
ar = "/path/to/NDK/toolchains/llvm/prebuilt/darwin-x86_64/bin/llvm-ar"
```
Set `ANDROID_NDK_HOME` as an env var and derive the linker path from it in a build script rather than hardcoding an absolute path. Use NDK r25 or later (stable ABI). Pin the NDK version in the ADR.

**Warning signs:**
- `cargo build --target aarch64-linux-android` produces `ld: warning: ignoring file ... for architecture arm64e`.
- `cc` is not set in `CARGO_TARGET_AARCH64_LINUX_ANDROID_LINKER`.
- Build fails with `error: linker 'cc' not found` or `error: linking with 'aarch64-linux-android-gcc' failed`.

**Phase to address:** ANDROID-01 — the linker configuration is the very first blocking issue to resolve.

---

## Moderate Pitfalls

Mistakes that require significant rework but not data loss or rewrites.

---

### Pitfall 7: JNI string handling — UTF-8 vs Modified UTF-8 mismatch

**What goes wrong:**
JNI's `GetStringUTFChars` / `NewStringUTF` use Modified UTF-8 (MUTF-8), not standard UTF-8. The primary difference: null bytes (`\0`) are encoded as the two-byte sequence `0xC0 0x80` in MUTF-8, and supplementary Unicode characters (above U+FFFF) are encoded as surrogate pairs rather than as 4-byte UTF-8 sequences. Rust strings are always standard UTF-8. If the Rust bridge sends a JSON string containing a null byte (e.g., in a hex-encoded BLE frame) or a 4-byte Unicode sequence via `NewStringUTF`, the JVM may crash with `JNI DETECTED ERROR IN APPLICATION: input is not valid Modified UTF-8`.

**Why it happens:**
The existing Rust bridge uses JSON over a C FFI call (`goose_bridge_handle_json`). Translating this to JNI requires encoding the JSON as a Java String and passing it to a JNI native method. Developers familiar with `CString` in Rust + C FFI assume UTF-8 equivalence and use `env.new_string(json_str)` directly in the `jni` crate without validating for null bytes.

**Consequences:**
Any BLE frame hex string containing `\0` in its payload (valid in binary BLE data) causes a JVM crash when the response is returned via JNI. This does not happen in iOS (C FFI passes raw bytes; Swift handles the null termination). The bug is hard to reproduce because it requires specific BLE packet content.

**Prevention:**
- At the JNI boundary, use the `jni` crate's `env.new_string()` only for well-validated strings that cannot contain null bytes or surrogate pairs.
- For binary or JSON payloads, prefer `jbyteArray` over `jstring` — pass bytes from Rust to Java as `byte[]`, then decode in Java/Kotlin as UTF-8.
- If `jstring` must be used, replace null bytes (`\0`) with a safe placeholder (e.g., space or Unicode replacement character) before calling `env.new_string()`.

**Warning signs:**
- `JNI DETECTED ERROR IN APPLICATION: input is not valid Modified UTF-8` in Android logcat.
- Bridge payloads that include hex-encoded BLE frames (which can legitimately contain `0x00` bytes).
- Use of `env.new_string(result)` without prior validation of the string content.

**Phase to address:** ANDROID-02 (JNI bridge wrapper) — the string encoding policy must be defined before any bridge function is implemented.

---

### Pitfall 8: Calling the synchronous Rust bridge from the Android main thread (analogous to the iOS @MainActor rule)

**What goes wrong:**
The existing Rust bridge (`goose_bridge_handle_json`) is synchronous and can block for significant time on database operations (SQLite writes, metric computations). On iOS, the architectural constraint is documented: "Never call from `@MainActor` with expensive methods; always dispatch to a background queue first." The JNI equivalent: calling a native method that blocks on the Android main thread (UI thread) triggers an `ANR` (Application Not Responding) dialog after 5 seconds and may kill the process.

**Why it happens:**
The simplest JNI wrapper calls the native function directly from a Kotlin coroutine or from a button handler — both of which may run on the main thread unless explicitly dispatched to `Dispatchers.IO`. Android developers accustomed to Room's auto-off-main-thread behavior may assume any database operation is automatically offloaded.

**Consequences:**
UI freezes during bridge calls. Android system detects the main thread blocked > 5 seconds and shows ANR dialog. This is a regression from the iOS behavior (which enforces background dispatch via `DispatchQueue`) and gives the Android port a reputation for being unresponsive.

**Prevention:**
- All JNI calls to the Rust bridge must be wrapped in `withContext(Dispatchers.IO)` in Kotlin.
- Add a `ThreadLocal` check in the JNI wrapper function that asserts the call is not on the main thread (analogous to the iOS architecture rule).
- Document the constraint in the ADR for the Android architecture.

**Warning signs:**
- `bridge.request(...)` called directly from a Composable or from a ViewModel without explicit `IO` dispatch.
- ANR traces showing the main thread blocked in a native method.
- StrictMode `detectAll()` reports disk reads on the main thread.

**Phase to address:** ANDROID-02 (JNI bridge wrapper) — the threading model must be the first documented decision in the ADR.

---

### Pitfall 9: `tungstenite` (WebSocket dependency) brings in TLS dependencies that fail to compile for Android targets

**What goes wrong:**
`tungstenite = "0.28"` is used for the local debug WebSocket server (`ws://127.0.0.1:8765`). The `tungstenite` default feature set includes TLS support via `native-tls` or `rustls`. On Android, `native-tls` tries to link against OpenSSL or the platform TLS library, which is not available in the NDK toolchain without explicit configuration. `rustls` pulls in `ring`, which has its own C assembly files that require Android-specific compiler flags. Either way, the default `tungstenite` dependency causes the Android build to fail on TLS-related compilation.

**Why it happens:**
The dependency was added for iOS where the build script handles all linker setup. The Android build inherits the same `Cargo.toml` and encounters the same TLS dependency with a different (and incomplete) linker environment.

**Consequences:**
`cargo build --target aarch64-linux-android` fails with TLS-related C compilation errors before any app code is reached. The error message implicates `ring` or `openssl-sys`, not `tungstenite`, making the root cause non-obvious.

**Prevention:**
Add a `[target.aarch64-linux-android]` section to `Cargo.toml` that replaces `tungstenite` with `tungstenite` using only the non-TLS feature set (`default-features = false`), or exclude the `tungstenite` dependency entirely for Android targets using a Cargo feature flag.

More practically: the debug WebSocket server is an iOS-only debugging tool. Guard it with `#[cfg(not(target_os = "android"))]` in the Rust source so Android compilation skips the entire module.

**Warning signs:**
- Android build fails with `error[E0433]: failed to resolve: use of undeclared crate or module 'ring'`.
- `ring` or `openssl-sys` appears in the build error chain when building for `aarch64-linux-android`.
- `cargo build --target aarch64-linux-android --features=` resolves the error — confirming it is a feature/dependency issue.

**Phase to address:** ANDROID-01 — the first compilation attempt will surface this; must be resolved before any JNI code is written.

---

### Pitfall 10: Frame reassembly buffers keyed by `frameReassemblyKey` will collide with a second wearable if both devices are connected simultaneously

**What goes wrong:**
`frameReassemblyKey(for:)` returns: `"\(deviceID)|\(serviceUUID)|\(characteristicUUID)|\(rustDeviceType)"`. This key is used to buffer partial frames in `frameReassemblyBuffers`. If two devices are connected simultaneously (both WHOOP and the second wearable), each has a distinct `deviceID` and characteristic UUID, so keys do not collide. However, `GooseBLEClient` is architecturally single-peripheral: `activePeripheral` is a single `CBPeripheral?`. The existing state machine (`connectionState = "ready"`, `commandCharacteristic`, etc.) has no concept of managing two simultaneous connections.

**Why it happens:**
The BLE client was designed for one active device at a time. Adding a second wearable implies either: (a) a second `GooseBLEClient` instance, or (b) making `GooseBLEClient` multi-peripheral. Option (b) would require significant refactoring of `connectionState`, `commandCharacteristic`, `batteryLevelCharacteristic`, and all the single-peripheral state properties. Option (a) is architecturally cleaner but means two separate pipelines.

**Consequences:**
If option (b) is attempted without refactoring, `commandCharacteristic` gets overwritten when the second device is connected, breaking commands to the first device. `connectionState` becomes ambiguous. `canSendHello` always refers to the last-connected device.

**Prevention:**
For v2.0, scope the second wearable to a sequential (not simultaneous) connection model: only one device connected at a time, with switching between them via the existing disconnect-reconnect flow. Document this constraint in the ADR. Do not attempt multi-peripheral simultaneously in this milestone.

**Warning signs:**
- `GooseBLEClient` attempts to hold two `activePeripheral` references.
- `commandCharacteristic` is reassigned during the connection of the second device.
- UI shows `connectionState = "ready"` for both devices simultaneously.

**Phase to address:** WEAR-01 — define the single-active-device constraint explicitly before any multi-device code is written.

---

### Pitfall 11: `device_type` TEXT in the SQLite schema accepts any string — wrong type silently stored, corrupts metric queries

**What goes wrong:**
The `decoded_frames` table has `device_type TEXT NOT NULL`. The `raw_evidence` table has no `device_type` column — the device model is captured only in `device_model TEXT NOT NULL`. The `ble_raw_notifications` table has `device_type TEXT` (nullable). These columns accept any string; there is no CHECK constraint enforcing that `device_type` must be one of `GOOSE`, `GEN4`, `MAVERICK`, `PUFFIN`. When the second wearable is added, its device type string (e.g., `POLAR_OH1` or `AMAZFIT`) is stored verbatim. Metric queries that `WHERE device_type = 'GOOSE' OR device_type = 'GEN4'` now silently exclude the second wearable, producing metrics that appear correct but are computed from incomplete data.

**Why it happens:**
The existing code hardcodes two device types and no future extensibility guard was built in. The Rust `parse_device_type` function only accepts four strings; any other string returns an error. But the SQL schema has no equivalent validation. If the second wearable's data bypasses `parse_device_type` (e.g., stored via a direct SQL insert from a new bridge method), a new device_type value enters the schema without going through the Rust validation layer.

**Consequences:**
Historical data for the second wearable is stored correctly but excluded from all metric rollups that filter by known device types. The dashboard (if one exists) shows health scores computed only from WHOOP data, silently ignoring Polar/Amazfit data. This is a silent correctness bug, not a crash.

**Prevention:**
Before inserting any second-wearable frames, extend `parse_device_type` in `bridge.rs` with the new device type string. Add the new type to `DeviceType` in `protocol.rs`. Add a `CHECK (device_type IN ('GEN4','MAVERICK','PUFFIN','GOOSE','POLAR_OH1'))` constraint to the schema migration for the second wearable. Test that metric queries include the new device type in their results.

**Warning signs:**
- Second wearable frames are stored but metric dashboard scores do not change after a day of use.
- `SELECT DISTINCT device_type FROM decoded_frames` shows a new string that `parse_device_type` does not recognize.
- No new `DeviceType` variant was added to `protocol.rs` for the second wearable.

**Phase to address:** WEAR-02 (Rust parsing module for second wearable) — the schema migration and `DeviceType` extension must be the first change, before any parsing logic.

---

### Pitfall 12: `GooseUploadService` classifies device generation from a single string comparison — breaks for non-WHOOP devices

**What goes wrong:**
`GooseUploadService.performUpload` contains: `let deviceGeneration = deviceType == "GEN4" ? "4.0" : "5.0"`. Any device that is not `"GEN4"` receives `device_generation = "5.0"` in the upload payload, including the second wearable. The server's `POST /v1/ingest-decoded` endpoint stores `device_generation` as metadata. The second wearable (Polar OH1, Amazfit, etc.) is silently tagged as WHOOP 5.0 in TimescaleDB.

**Why it happens:**
The classification was written as a two-way branch because only two device types existed at the time. Extending to three device types requires changing this branch, but it is easy to miss because the logic is in the upload service, not in the BLE layer or the Rust bridge.

**Consequences:**
TimescaleDB contains heart rate data tagged `device_generation = "5.0"` for a Polar OH1. Queries filtering by `device_generation` are wrong. The server cannot distinguish WHOOP Gen5 data from Polar OH1 data in retrospect without re-processing all rows.

**Prevention:**
Replace the two-way branch with a proper mapping from `rustDeviceType` to a `device_generation` string, defaulting to the device's own identifier (e.g., `"POLAR_OH1"`) rather than a WHOOP generation string. Coordinate with the server's `DecodedBatch` schema to accept non-WHOOP generation strings.

**Warning signs:**
- Second wearable data uploaded with `device_generation = "5.0"` in the JSON payload.
- `deviceType == "GEN4" ? "4.0" : "5.0"` remains unchanged after the second wearable is added.
- TimescaleDB shows two different wearable types with the same `device_generation`.

**Phase to address:** WEAR-03 (second wearable E2E upload) — update `GooseUploadService` in the same commit that adds the second wearable's bridge method.

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Keep "V5" naming for Gen5 guards (`supportsV5HistoricalSync`) after Gen4 support added | Zero renaming effort | Misleading to future developers; "V5" means "Gen5 only" but the code also serves Gen4 after fix | Never — rename when Gen4 support is added |
| Derive `rustDeviceType` from characteristic UUID prefix at notification time | Simple, no stored state | Breaks on third device type; wrong header length causes frame corruption | Never for a device with its own parsing module |
| `panic = "abort"` applied uniformly across all targets | Safe on iOS (correct) | Kills JVM process on Android; no error recovery possible | iOS only — override for Android |
| Single `GooseBLEClient` instance manages two devices | No architecture change | Ambiguous connection state, overwritten characteristics | Acceptable in v2.0 only if single-device-at-a-time is enforced and documented |
| Hardcode `device_generation` as `"5.0"` fallback in upload | Works for WHOOP-only data | Silent tagging of non-WHOOP data as WHOOP Gen5 | Never once a second wearable is added |

---

## Integration Gotchas

| Integration Point | Common Mistake | Correct Approach |
|-------------------|----------------|------------------|
| Rust → JNI (Android) | Return `jstring` via `env.new_string()` with unchecked content | Validate no null bytes in JSON; prefer `jbyteArray` for binary payloads |
| Android build → rusqlite bundled | Assume iOS linker config works for Android | Set `CARGO_TARGET_AARCH64_LINUX_ANDROID_LINKER` and `AR` explicitly; use NDK r25+ clang |
| GooseNotificationEvent → Rust bridge | Use `rustDeviceType` heuristic for third device | Resolve `WearableKind` at connect time; propagate through event struct |
| GooseUploadService → server | Two-way `deviceType == "GEN4"` branch | Extend to a full mapping; coordinate with server `device_generation` schema |
| Second wearable → SQLite schema | Store new device type string without schema migration | Add `DeviceType` variant in Rust + `CHECK` constraint in migration before first insert |
| Gen4 → historical sync guards | `supportsV5HistoricalSync` returns false for Gen4 | Check `connectedDeviceKind` enum, not `commandCharacteristic` UUID prefix |

---

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Synchronous Rust bridge on Android main thread | ANR dialog after 5 seconds; unresponsive UI | Wrap all bridge calls in `withContext(Dispatchers.IO)` | Immediately on first expensive bridge call (SQLite query) |
| Frame reassembly buffer not keyed by device when multiple wearables active in sequence | Frame from second wearable interpreted with wrong device's buffered bytes | Flush reassembly buffer on device disconnect; key includes `deviceID` (already done, but verify flush on disconnect) | First switch between two wearables without explicit disconnect |
| Second wearable adds unbounded new SQLite rows to `decoded_frames` without device-scoped TTL | Storage grows unboundedly on device with two wearables | Add a `device_type`-scoped cleanup policy when second wearable is integrated | After ~30 days of dual-wearable capture |

---

## "Looks Done But Isn't" Checklist

- [ ] **Gen4 historical sync:** Gen4 device connects and shows "connected" but `canSyncHistorical` is actually false — verify `connectedDeviceKind` is used in the guard, not `commandCharacteristic.uuid` prefix.
- [ ] **Gen4 upload:** Upload payload logs `device_generation = "5.0"` instead of `"4.0"` — verify the `deviceType == "GEN4"` branch in `GooseUploadService` is reached with a real Gen4 device.
- [ ] **Android compilation:** `cargo build --target aarch64-linux-android` completes without error on a clean checkout — verify `.cargo/config.toml` linker settings work after `git clone`.
- [ ] **Android panic safety:** JNI bridge function that receives an invalid `device_type` string returns a Java exception, does not abort the JVM — verify `catch_unwind` or `Result`-only surface at every JNI entry point.
- [ ] **Second wearable background scan:** Second wearable is discovered after locking the screen for 60 seconds — verify its primary service UUID is in the `withServices` array.
- [ ] **Second wearable device_type in schema:** `SELECT DISTINCT device_type FROM decoded_frames` shows the new device type string, not `GOOSE` — verify `parse_device_type` extension.
- [ ] **Second wearable upload:** TimescaleDB row for second wearable has correct `device_generation` field, not `"5.0"` — verify `GooseUploadService` mapping extended.

---

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Wrong `device_type` stored in `decoded_frames` | HIGH | `UPDATE decoded_frames SET device_type = '...' WHERE characteristic_uuid LIKE '61080%'`; re-run metric algorithms |
| Gen4 historical sync silently disabled | LOW | Fix `supportsV5HistoricalSync` guard; trigger manual sync; no data loss |
| `panic = "abort"` causing JVM crash on Android | LOW | Add `panic = "unwind"` to Android target profile; rebuild; existing data unaffected |
| `device_generation = "5.0"` for second wearable in TimescaleDB | MEDIUM | `UPDATE` all rows where `device_id` matches the second wearable's UUID; requires knowing the device UUID at insertion time |
| Android build blocked by `tungstenite` TLS compile error | LOW | Add `#[cfg(not(target_os = "android"))]` guard on WebSocket module; no data involved |
| Frame reassembly corruption from wrong header length | MEDIUM | Corrupted frames in `decoded_frames` cannot be recovered; re-capture required if original `raw_evidence` not stored |

---

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| Device type string mismatch (Pitfall 1) | WEAR-01 | `SELECT DISTINCT device_type FROM decoded_frames` after second wearable capture session |
| Gen4 classification race at connect time (Pitfall 2) | GEN4-01 | `canSyncHistorical = true` for Gen4 device in UI after connection |
| Double `scanForPeripherals` call (Pitfall 3) | GEN4-01 | Grep for second `scanForPeripherals` call; logs show single `"scan.started"` |
| Background scan missing second wearable UUID (Pitfall 4) | WEAR-01 | Device discovered in BLE log after 60s screen-lock |
| `panic = "abort"` on Android JNI (Pitfall 5) | ANDROID-01 | Rust function returning `Err` returns Java exception, not SIGABRT in logcat |
| rusqlite bundled + NDK linker (Pitfall 6) | ANDROID-01 | `cargo build --target aarch64-linux-android` succeeds on clean checkout |
| JNI MUTF-8 string mismatch (Pitfall 7) | ANDROID-02 | Send JSON with null byte; JVM does not crash |
| Blocking main thread via JNI (Pitfall 8) | ANDROID-02 | StrictMode shows no disk I/O on main thread; no ANR in 30s test |
| tungstenite TLS compile failure on Android (Pitfall 9) | ANDROID-01 | `cargo build --target aarch64-linux-android` succeeds without TLS errors |
| Single-peripheral state machine collision (Pitfall 10) | WEAR-01 | ADR documents single-device constraint; `activePeripheral` is not overwritten during wearable switch |
| Wrong `device_type` in SQLite schema (Pitfall 11) | WEAR-02 | `SELECT DISTINCT device_type FROM decoded_frames` shows expected string for second wearable |
| `GooseUploadService` two-way branch (Pitfall 12) | WEAR-03 | TimescaleDB `device_generation` field matches second wearable identity, not `"5.0"` |

---

## Sources

- `GooseSwift/GooseBLETypes.swift` — `rustDeviceType` computed property (line 34–36): characteristic UUID prefix heuristic
- `GooseSwift/GooseBLEClient+Commands.swift` — `supportsV5HistoricalSync`, `isV5CommandCharacteristic` (lines 147–165)
- `GooseSwift/GooseBLEClient+UserActions.swift` — `startScan` passing `whoopServices` array (lines 134–138)
- `GooseSwift/GooseBLEClient.swift` — `whoopServices` array with both WHOOP UUID families (lines 366–369)
- `GooseSwift/GooseAppModel+NotificationPipeline.swift` — `gooseFrames(in:event:)` header length branch on `rustDeviceType` (lines 791–807)
- `GooseSwift/GooseUploadService.swift` — `deviceGeneration` two-way branch (line 88)
- `Rust/core/src/bridge.rs` — `parse_device_type` accepting `"GEN_4"`, `"GEN4"`, `"GOOSE"` variants (lines 7956–7966)
- `Rust/core/src/protocol.rs` — `DeviceType` enum with Gen4 header length and CRC rules (lines 26–58)
- `Rust/core/src/store.rs` — `decoded_frames` schema with `device_type TEXT NOT NULL` (lines 951–970); `ble_raw_notifications` schema (lines 1561–1583)
- `Rust/core/Cargo.toml` — `panic = "abort"` in release profile (line 156); `crate-type = ["rlib", "staticlib", "cdylib"]` (line 12); `tungstenite = "0.28"` (line 146)
- `Scripts/build_ios_rust.sh` — `CARGO_TARGET_AARCH64_APPLE_IOS_LINKER` pattern (lines 93–109)
- rusqlite README — `bundled` feature compiles SQLite via `cc` crate, requires host C compiler to be set (Context7 `/rusqlite/rusqlite`)
- Apple Developer — `UIBackgroundModes: bluetooth-central` requires `withServices:` array for background scanning (non-nil required in background)
- JNI Specification — Modified UTF-8 encoding for `NewStringUTF` / `GetStringUTFChars`; null bytes encoded as `0xC0 0x80`

---
*Pitfalls research for: v2.0 Multi-Device & Platform Foundations*
*Researched: 2026-06-03*
