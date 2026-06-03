# Stack Research — v2.0 Multi-Device & Platform Foundations

**Domain:** Multi-device BLE biometric platform — iOS + Rust core + Android JNI foundations
**Researched:** 2026-06-03
**Confidence:** HIGH (CoreBluetooth and Android NDK verified against official docs; wearable UUIDs verified from Polar SDK source; existing codebase verified directly)

---

## Context: What Already Exists (Do Not Re-Research)

The v1.0 stack is validated and locked. This document covers only the **additions and changes** needed for v2.0.

| Layer | v1.0 Status |
|-------|------------|
| Swift/SwiftUI + URLSession | Locked — no new external dependencies permitted |
| Rust core (`goose-core`) | Locked — `rusqlite 0.37 bundled`, `serde 1.0`, `serde_json 1.0`, `tungstenite 0.28`, `zip 0.6`, `sha2 0.10`, `crc32fast 1.4`, `thiserror 2.0` |
| FastAPI + TimescaleDB + Docker | Locked — no changes for v2.0 |
| `crate-type = ["rlib", "staticlib", "cdylib"]` | Already present — `cdylib` is already there for Android |

---

## Feature 1: WHOOP 4.0 (Gen4) iOS App Layer

### What the Rust Core Already Has (Verified)

The Rust protocol layer is fully Gen4-aware — no Rust changes needed for this feature:

- `DeviceType::Gen4` defined in `Rust/core/src/protocol.rs` line 27
- Gen4 frame format: 4-byte header, CRC8 (`crc8(&frame[1..3]) == frame[3]`), `u16::from_le_bytes([frame[1], frame[2]])` payload length
- `bridge.rs` parses `"GEN_4" | "Gen4" | "gen4"` string tokens and routes to Gen4 parsing
- Gen4 primary service UUID `61080001-8d6d-82b8-614a-1c8cb0f8dcc6` already in `GooseBLEClient.swift`'s `whoopServices` array

### CoreBluetooth Multi-UUID Scan — No API Changes Needed

The current scan call is already correct:

```swift
central.scanForPeripherals(
  withServices: whoopServices,  // [CBUUID("fd4b0001-..."), CBUUID("61080001-...")]
  options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
)
```

`whoopServices` already contains both Gen5 (`fd4b0001-...`) and Gen4 (`61080001-...`) service UUIDs. `scanForPeripherals(withServices:)` applies OR logic: a peripheral advertising **any** of the listed UUIDs triggers `didDiscover`. The array already works as a multi-device scanner. No API change is needed.

**Verified from Apple CoreBluetooth official documentation:** `scanForPeripherals(withServices:)` with an array of `CBUUID` objects — peripherals advertising any of the listed services are returned.

### What Does Need to Change in Swift

1. **`GooseBLEClient+CentralDelegate.swift` — device generation inference.** In `didDiscover`, read `advertisementData[CBAdvertisementDataServiceUUIDsKey]` to determine which service UUID was matched. If the advertised UUIDs include `61080001-8d6d-82b8-614a-1c8cb0f8dcc6`, the device is Gen4. The existing method `advertisedServiceUUIDs(from:)` in `GooseBLEClient+Parsing.swift` already extracts this array — just add a generation check.

2. **Device generation propagation to upload payload.** The bridge call for frame ingestion already takes `device_type: String`. Swift must pass `"Gen4"` vs `"Maverick"` based on which service UUID triggered the connection. Currently there is no `deviceGeneration` property on the discovered device object.

3. **Onboarding copy.** Display "WHOOP 4.0" for Gen4 devices. The model string from the Device Information Service characteristic `0x2A24` identifies the hardware revision — add a case for known Gen4 model strings.

**No new frameworks or libraries.** These are logic changes to existing Swift files.

### Background Scanning Note

The app already declares `bluetooth-central` in `UIBackgroundModes`. Multi-UUID background scanning works: iOS filters on advertised service UUIDs using OR logic, and the `willRestoreState` delegate receives `CBCentralManagerRestoredStateScanServicesKey` with the full UUID array. `CBCentralManagerOptionRestoreIdentifierKey` is not required for v2.0 (state restoration across app termination is deferred to v3+).

**Confidence: HIGH** — verified against Apple CoreBluetooth official docs and direct codebase inspection.

---

## Feature 2: Android JNI Bridge Foundations

### Toolchain

| Tool | Version | Purpose | Source |
|------|---------|---------|--------|
| `cargo-ndk` | 4.1.2 (released Aug 2025) | Cross-compile Rust for Android ABIs | github.com/bbqsrc/cargo-ndk |
| Android NDK | r29 (auto-detected by cargo-ndk) | Clang cross-toolchain | Android Studio SDK Manager |
| Rust targets | 3 targets (see below) | Android ABI support | `rustup target add` |
| `jni` crate | 0.22.4 | Safe Rust-to-JVM bridging | docs.rs/jni |

**Required rustup targets:**
```bash
rustup target add aarch64-linux-android      # ARM64 devices — primary target
rustup target add armv7-linux-androideabi    # ARMv7 32-bit — legacy devices
rustup target add x86_64-linux-android      # x86_64 emulators — known issues, see below
```

Goose's MSRV is 1.94, exceeding cargo-ndk's minimum of Rust 1.86. No conflict.

cargo-ndk auto-detects the installed NDK. Override with `ANDROID_NDK_HOME` if needed. No Gradle or Android Studio project files are needed for v2.0 — this is a pure library + documentation milestone.

### Cargo.toml Changes Required

**`crate-type` is already correct.** The existing Cargo.toml already declares:
```toml
[lib]
crate-type = ["rlib", "staticlib", "cdylib"]
```

`cdylib` produces the `.so` the JVM loads via `System.loadLibrary(...)`. No change here.

**Add the `jni` crate as an optional dependency:**
```toml
[dependencies]
jni = { version = "0.22", optional = true }

[features]
android-jni = ["dep:jni"]
```

Using `optional = true` with a feature flag keeps the iOS build clean (no JNI linkage, no additional symbols). The feature is activated only for Android cross-compilation.

**`panic = "abort"` is already set** in `[profile.release]`. JNI requires that Rust panics do not unwind across FFI boundaries — this is already satisfied. The `jni` crate additionally wraps calls in `catch_unwind` as defence-in-depth.

### Known Issue: `rusqlite` Bundled + Android

The `bundled` feature compiles SQLite from source via the `cc` crate. Known upstream issues:

| Target | Status | Issue |
|--------|--------|-------|
| `aarch64-linux-android` | Likely works | No reported blockers |
| `armv7-linux-androideabi` | Partial | `-latomic` linking issue (PR #1037 unmerged) |
| `x86_64-linux-android` | Known broken | Build failures (issue #1380, PR #1592 in progress) |

**Recommendation for v2.0:** test `aarch64-linux-android` only. The `x86_64-linux-android` issue affects emulators only and can be deferred. If bundled compilation fails on any target, the fallback is linking against Android's system SQLite (API level 24+) by removing the `bundled` feature — but this changes persistence behaviour and is a risk to defer.

### JNI Calling Convention for the Goose Bridge

The existing iOS bridge exposes two C symbols: `goose_bridge_handle_json` and `goose_bridge_free_string`. For Android, **wrap these in a thin JNI shim** rather than replacing them:

```rust
// In a new src/android.rs module, gated behind the android-jni feature
#[cfg(feature = "android-jni")]
#[no_mangle]
pub extern "C" fn Java_com_goose_GooseBridge_handleJson(
    env: jni::JNIEnv,
    _class: jni::objects::JClass,
    request: jni::objects::JString,
) -> jni::sys::jstring {
    // Convert JString -> Rust &str -> call goose_bridge_handle_json -> JString
}
```

The `jni` crate calling convention (verified from docs.rs/jni 0.22.4):
1. First argument: `JNIEnv` (the JNI environment pointer, wrapped safely)
2. Second argument: `JClass` (for static methods) or `JObject` (for instance methods)
3. Subsequent arguments: Java types mapped to JNI equivalents (`JString`, `jint`, etc.)

The first action inside the function must be `.attach_current_thread()` or use `with_env(...)` — this is the `jni` crate's safety requirement.

**Why a shim over a full rewrite:** the existing C bridge is tested with 40+ integration tests. A thin JNI shim wrapping it maximises reuse, keeps the iOS and Android paths aligned, and adds minimal new Rust code. This approach is consistent with the ADR milestone scope.

### `tungstenite` on Android

The WebSocket debug server (`ws://127.0.0.1:8765`) is an iOS-only debug feature. For Android builds, guard with:
```rust
#[cfg(not(target_os = "android"))]
```
This is a compile-time guard, not a Cargo.toml change. No dependency removal needed for v2.0 since Android builds are CLI-only (no running app).

**Confidence: HIGH** for toolchain and calling conventions. **MEDIUM** for bundled SQLite on Android (aarch64 likely works; x86_64 known broken; unverified without Android hardware test).

---

## Feature 3: Additional Wearable — Recommended Candidate

### Recommended: Polar H10 (Heart Rate + RR Intervals via Standard GATT)

**Why Polar H10:**
- Standard Bluetooth SIG Heart Rate Service (`0x180D`) — no reverse engineering, publicly specified
- Includes RR interval data — maps directly to existing HRV computation in Rust core
- Published GATT UUIDs verified from Polar's own open-source SDK (`polarofficial/polar-ble-sdk` BlePMDClient.swift SHA cc1f2db)
- Distinct service UUID from WHOOP — clean pipeline separation in Rust parsing module
- Available to buy; widely used in research; well-documented community implementations

**BLE UUIDs (verified from official sources):**

| Service / Characteristic | UUID | Specification |
|--------------------------|------|--------------|
| Heart Rate Service | `0x180D` | Bluetooth SIG standard |
| Heart Rate Measurement | `0x2A37` | Bluetooth SIG standard |
| Body Sensor Location | `0x2A38` | Bluetooth SIG standard |
| PMD Service (ECG/Acc) | `FB005C80-02E7-F387-1CAD-8ACD2D8DF0C8` | Polar proprietary (verified from SDK) |
| PMD Control Point | `FB005C81-02E7-F387-1CAD-8ACD2D8DF0C8` | Polar proprietary (verified from SDK) |
| PMD Data | `FB005C82-02E7-F387-1CAD-8ACD2D8DF0C8` | Polar proprietary (verified from SDK) |

**Heart Rate Measurement data format (`0x2A37`) — Bluetooth SIG standard:**
- Byte 0: flags — bit 0 = HR format (0 = uint8, 1 = uint16), bit 4 = RR-interval present
- Bytes 1+: HR value (uint8 or uint16)
- If RR flag set: subsequent uint16 values in 1/1024 second units

**v2.0 scope: standard Heart Rate Service only.** Implement `0x180D` + `0x2A37` for HR and RR intervals. The proprietary PMD service (ECG at 130Hz) is out of scope — it requires the full PMD control-point protocol and is disproportionately complex relative to the goal of validating pipeline extensibility.

### iOS Changes for Polar H10

Add service UUID to the scan filter. The cleanest architecture is a separate `GoosePolarBLEClient.swift` with its own `CBCentralManager` instance, following the same delegate pattern as `GooseBLEClient`. This avoids entangling WHOOP-specific logic with Polar-specific logic and proves multi-device architecture more clearly than extending the existing client.

```swift
// GoosePolarBLEClient.swift
let polarH10Services = [CBUUID(string: "180D")]

central.scanForPeripherals(
  withServices: polarH10Services,
  options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
)
```

Device disambiguation within `didDiscover`: check peripheral name prefix `"Polar H10"` and/or presence of `0x180D` in advertised services (the same UUID could be advertised by other HR monitors — name prefix disambiguates).

**Note:** iOS allows multiple `CBCentralManager` instances, each scanning for different UUIDs simultaneously. They use the same Bluetooth radio but are separate logical scanners. No coordination issue.

### Rust Changes for Polar H10

New module `src/polar_h10.rs`:
- Parse HR Measurement bytes from `0x2A37` notifications
- Extract RR intervals if RR flag is set in flags byte
- Parse HR value as uint8 or uint16 based on bit 0 of flags byte

New bridge method `polar.ingest_hr_sample`:
- Accept HR + RR array + timestamp + device identifier
- Store to SQLite with `device_type = "polar_h10"` in a separate table or tagged in the existing frames table

The module is intentionally separate from `src/protocol.rs` (WHOOP-specific). This separation is the architectural validation point of this feature.

### Rejected Wearable Candidates

| Candidate | Reason for Rejection |
|-----------|---------------------|
| Amazfit Helio Strap | "Sport Research Open Protocol" has no publicly accessible GATT specification; SDK-gated only; insufficient documentation for a safe Rust parser |
| Fitbit Inspire Air | Proprietary BLE protocol; no published GATT spec; reverse engineering required |
| Garmin HRM-Pro | Primarily ANT+; BLE HR profile available but Polar H10 is better documented and more common in research contexts |
| Polar OH1 | Optical HR only; no ECG; Polar H10 is strictly superior for the validation scope |

**Confidence: HIGH** for BLE UUIDs (Bluetooth SIG spec + Polar SDK source). **MEDIUM** for exact iOS multi-client approach (architecturally sound but unverified against this specific codebase).

---

## Recommended Stack Additions Summary

### New Tools (Development Only)

| Tool | Version | Purpose |
|------|---------|---------|
| `cargo-ndk` | 4.1.2 | Android cross-compilation |
| Android NDK | r29 | Clang toolchain for Android ABIs |

### New Rust Dependency

| Crate | Version | Purpose | Feature-Gated |
|-------|---------|---------|---------------|
| `jni` | 0.22 | Safe JNI bridge types for Android | `android-jni` feature |

### No New iOS Dependencies

Zero new Swift packages, frameworks, or CocoaPods entries.

### New Rust Modules (Written, Not Imported)

| Module | Purpose |
|--------|---------|
| `src/polar_h10.rs` | Parse Polar H10 BLE HR + RR frames |
| `src/android.rs` | JNI shim wrapping existing C bridge (feature-gated) |

---

## Installation

```bash
# cargo-ndk (install once on development machine)
cargo install cargo-ndk
# or faster:
cargo binstall cargo-ndk

# Android Rust targets (install once)
rustup target add aarch64-linux-android
rustup target add armv7-linux-androideabi
rustup target add x86_64-linux-android

# Build Rust core for Android (in Rust/core/)
cargo ndk -t aarch64-linux-android build --release --features android-jni
```

---

## Alternatives Considered

| Decision | Recommended | Alternative | Why Not |
|----------|-------------|-------------|---------|
| JNI approach | Thin shim wrapping existing C FFI | Full JNI bridge rewrite | Existing C bridge has 40+ integration tests; shim minimises new code and risk |
| Android target scope | `aarch64-linux-android` only for v2.0 | All 4 targets | x86_64 has known rusqlite bundled failures; armv7 has `-latomic` issue; emulator targets can be deferred |
| Second wearable BLE scope | Standard `0x180D` only | Polar H10 + PMD (ECG) | ECG at 130Hz requires full PMD control-point protocol; disproportionate for extensibility validation |
| Polar iOS integration | Separate `GoosePolarBLEClient` | Extend `GooseBLEClient` | Separation proves multi-device architecture; avoids WHOOP-specific logic entanglement |
| `jni` crate vs raw FFI | `jni` 0.22 | Raw `extern "C"` with `*mut JNIEnv` | `jni` crate provides lifetime-safe wrappers preventing GC-related memory bugs |
| `rust-android-gradle` | Not used | cargo-ndk | Gradle plugin is for full Android apps; library-only foundation only needs cargo-ndk |
| Polar BLE SDK (iOS) | Not used — raw CoreBluetooth | polarofficial/polar-ble-sdk iOS framework | Introduces external Swift dependency; violates project constraint |

---

## What NOT to Add

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| `rust-android-gradle` Gradle plugin | Requires full Android Gradle project; out of scope for library-only foundation | `cargo-ndk` CLI |
| Polar BLE SDK iOS framework | External Swift dependency — violates the no-external-deps constraint | Raw CoreBluetooth with standard `0x180D` |
| Third-party BLE abstraction (RxBluetoothKit, SpeziBluetooth) | External Swift dependency; overkill for two known devices | Extend existing CBCentralManager delegate pattern |
| Full Android Activity/Gradle project | Scope — v2.0 is JNI bridge + ADR, not a working Android app | Defer to v3+ |
| `panic = "unwind"` on Android | JNI boundary requires abort or catch_unwind; current `panic = "abort"` is correct | Keep existing setting |
| PMD ECG service for Polar | Requires proprietary protocol; complexity disproportionate to v2.0 goal | Defer to v3+ if Polar support is expanded |

---

## Version Compatibility

| Package | Version | Compatibility Notes |
|---------|---------|---------------------|
| `cargo-ndk` | 4.1.2 | Requires Rust >= 1.86; Goose MSRV 1.94 — no conflict |
| `jni` | 0.22.4 | Targets JNI 1.6 (Android API 16+); works with any modern Android |
| `rusqlite bundled` | 0.37 | `aarch64-linux-android`: likely works; `x86_64-linux-android`: known broken upstream |
| Android NDK | r29 | cargo-ndk auto-selects latest installed; min NDK not enforced by cargo-ndk |
| CoreBluetooth multi-UUID scan | iOS 5.0+ | OR semantics verified; no minimum iOS version concern for this feature |
| `CBCentralManagerOptionRestoreIdentifierKey` | iOS 7.0+ | Available if state restoration added later; not required for v2.0 |

---

## Sources

- Apple CoreBluetooth docs — `CBCentralManager.scanForPeripherals(withServices:options:)` — verified OR semantics for UUID array, background scan restrictions — **HIGH confidence**
- Apple CoreBluetooth docs — `CBCentralManagerOptionRestoreIdentifierKey`, `willRestoreState` — verified state restoration API — **HIGH confidence**
- `polarofficial/polar-ble-sdk` GitHub — `BlePMDClient.swift` (SHA: cc1f2db0fae5c957422e528e63b0766b2e2de099) — verified PMD service UUID `FB005C80-02E7-F387-1CAD-8ACD2D8DF0C8` — **HIGH confidence**
- `polarofficial/polar-ble-sdk` GitHub — `BleHrClient.swift` — verified standard HR service `0x180D`, characteristics `0x2A37`, `0x2A38` — **HIGH confidence**
- Bluetooth SIG Heart Rate Service 1.0 specification — verified `0x180D` service and `0x2A37` data format — **HIGH confidence**
- `bbqsrc/cargo-ndk` GitHub README — version 4.1.2, Rust MSRV 1.86, NDK auto-detection — **HIGH confidence**
- `docs.rs/jni/0.22.4` — jni crate API, `cdylib` requirement, calling convention — **HIGH confidence**
- Android NDK Context7 docs (`/android/ndk`) — JNI `JNI_OnLoad` registration, `RegisterNatives` pattern — **HIGH confidence**
- `rusqlite/rusqlite` GitHub issues — Android bundled issues #1380, #1037 — **MEDIUM confidence** (open issues, not release notes)
- Goose codebase — `GooseBLEClient.swift` lines 366–420, `Rust/core/src/protocol.rs` lines 26–63, `Rust/core/Cargo.toml` — direct code verification — **HIGH confidence**

---

*Stack research for: Goose v2.0 Multi-Device & Platform Foundations*
*Researched: 2026-06-03*
