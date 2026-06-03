# Feature Research

**Domain:** iOS biometric app — Multi-device & Platform Foundations (v2.0)
**Researched:** 2026-06-03
**Confidence:** HIGH (primary source: direct codebase read; secondary: Context7/Apple/NDK docs)

---

## Context: What Is Already Built vs. What Is New

Before cataloguing features, it is critical to understand what v1.0 already shipped and what
the Rust core already supports, because several "v2.0 features" are partially or fully wired.

### Already wired at the Rust level (DeviceType::Gen4 fully implemented)
- `protocol.rs`: `DeviceType::Gen4` enum, 4-byte header parsing, CRC8 validation
- `GooseBLETypes.swift`: `rustDeviceType` auto-derived from characteristic UUID prefix
  (`"610800"` prefix → `"GEN4"`, else `"GOOSE"`)
- `GooseUploadService.swift`: `device_generation` maps `GEN4 → "4.0"`, else `"5.0"` (line 88)
- `GooseBLEClient.swift`: `whoopServices` array already contains both service UUIDs —
  `fd4b0001` (Gen5/Goose) and `61080001` (Gen4) — so `scanForPeripherals(withServices:)` already
  discovers both generations

### What is genuinely missing for Gen4 iOS layer
- Onboarding UI text says "WHOOP" generically but does not acknowledge WHOOP 4.0 as a supported
  device (no mention of Gen4 in `OnboardingStepViews.swift`)
- No `GooseDiscoveredDevice.generation` field — the discovered device struct carries only
  `id`, `name`, `rssi`; the UI cannot show "WHOOP 4.0" vs "WHOOP 5.0" to the user
- No generation-based UI distinction in `DeviceView.swift` or `ConnectionView.swift`
- Upload payload already sends correct `device_generation` but the triggering path
  (`GooseAppModel+Upload.swift` line 25) passes `deviceEvent.rustDeviceType` — this works
  correctly because `rustDeviceType` is already derived from the characteristic UUID

### Already wired at the Rust/FFI level for Android foundations
- `Cargo.toml` declares `crate-type = ["rlib", "staticlib", "cdylib"]` — `cdylib` is the
  correct type for a JNI `.so` shared library; no Cargo.toml change required
- Bridge API is two C symbols: `goose_bridge_handle_json` + `goose_bridge_free_string`; this
  maps trivially to two `native` methods in Kotlin/Java
- No JNI-specific code exists yet (no `jni` crate, no `extern "C" Java_*` functions)

---

## Feature Landscape

### Table Stakes (Users Expect These)

Features that, if missing, make the feature feel broken or incomplete.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| GEN4-01: BLE scan discovers Gen4 without user action | Both UUIDs in `whoopServices` already — scan already works. The gap is user-visible: onboarding says "find your WHOOP" without acknowledging WHOOP 4.0 is supported | LOW | `scanForPeripherals(withServices: whoopServices)` already passes both UUIDs; no scan code change needed |
| GEN4-02: `GooseDiscoveredDevice` carries generation | Device list UI currently shows name + RSSI only. User with two WHOOPs (4.0 and 5.0) cannot tell which is which | LOW | Add `generation: String` field derived from advertised service UUID at discovery time; `fd4b0001` → `"5.0"`, `61080001` → `"4.0"` |
| GEN4-03: Onboarding copy acknowledges WHOOP 4.0 | User with WHOOP 4.0 sees "Find your WHOOP" — unclear if supported | LOW | Update strings in `OnboardingStepViews.swift`; no logic change |
| GEN4-04: Device view shows generation label | After connection, `DeviceView` shows model number from `GooseBLEClient.modelNumber`. Should also show generation label for clarity | LOW | Read from `GooseDiscoveredDevice.generation` or infer from connected service UUID |
| GEN4-05: Upload payload generation field is tested E2E | `device_generation` is already sent correctly but never verified with a real Gen4 device | LOW | Unit test: verify `GooseUploadService` sends `"4.0"` when `deviceType == "GEN4"` (already wired; test is the deliverable) |
| ANDROID-01: Rust core cross-compiles for `aarch64-linux-android` | No Android app without this. Must be verified, not assumed. `cdylib` crate type is declared but never built for Android targets | MEDIUM | `rustup target add aarch64-linux-android armv7-linux-androideabi x86_64-linux-android`; `cargo build --target aarch64-linux-android --release`; NDK toolchain required; `bundled` SQLite in rusqlite may need special linker flags |
| ANDROID-02: Thin JNI wrapper (`goose_jni.rs`) for the two bridge functions | JNI naming convention requires `Java_com_example_GooseBridge_handleJson` etc. — the existing `goose_bridge_handle_json` C symbol is not callable directly from Java/Kotlin without JNI registration | MEDIUM | New `src/jni_bridge.rs` file; uses `jni` crate or raw `extern "C" JNIEXPORT`; wraps `goose_bridge_handle_json` and `goose_bridge_free_string`; ~50 lines |
| ANDROID-03: ADR documenting Android architecture decisions | The upstream issue #9 is open; without an ADR future contributors do not know how the Android layer is expected to work | LOW | Markdown ADR in `docs/adr/` covering: why cdylib, why JSON-over-JNI (not gRPC/protobuf), memory safety (who frees the returned string), threading model |
| WEAR-01: Second wearable has a dedicated Rust parsing module | If the new device reuses WHOOP's `protocol.rs`, the architecture is not extensible — it just hard-codes a second branch. A separate module validates extensibility | HIGH | New `src/[device]_protocol.rs`; must implement a common trait or follow same parse_frame pattern; SQLite schema may need `device_type` extension |
| WEAR-02: BLE scan includes second wearable service UUID | Cannot discover the device without its service UUID in `whoopServices` (or a parallel scan) | MEDIUM | Add UUID to `whoopServices` array in `GooseBLEClient.swift`; update `isWhoopService` logic to be generic `isKnownWearableService`; update `rustDeviceType` derivation in `GooseBLETypes.swift` |
| WEAR-03: Upload payload correctly identifies second wearable | Server receives `device_generation` or equivalent field identifying the new device type | LOW | Extension of existing `device_generation` logic in `GooseUploadService.swift`; may require server-side schema update |

### Differentiators (Competitive Advantage)

Features that add value beyond the minimum viable scope.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| GEN4-D1: Connection log shows device generation clearly | "Connected to WHOOP 4.0 (Gen4)" in the log view gives the user explicit confirmation their device is recognised correctly | LOW | Add generation to `record(source: "ble", title: "device.discovered")` body string |
| ANDROID-D1: `cargo-ndk` build script committed to repo | `Scripts/build_android_rust.sh` alongside `build_ios_rust.sh` — contributors can cross-compile for Android without researching NDK setup | LOW | Shell script mirroring `build_ios_rust.sh`; documents NDK path requirement |
| ANDROID-D2: Kotlin usage example in docs | A concrete Kotlin snippet showing how to call `GooseBridge.handleJson()` lowers the barrier to a future Android app | LOW | Part of ADR or separate `docs/android-integration.md` |
| WEAR-D1: Protocol documentation for the second wearable in `docs/` | Explains what the Rust parsing module does, which BLE characteristics are read, and how frames are structured — enables future contributors to add a third wearable | MEDIUM | Markdown; cites BLE spec or community reverse-engineering source |

### Anti-Features (Commonly Requested, Often Problematic)

Features to explicitly not build in this milestone.

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| Full Android app (Activities, UI) | Natural next step after Android foundations | Would take 3-4x the effort of the foundations alone; the milestone is explicitly "foundations only" — building UI now means no time for the wearable extensibility work | ADR + JNI bridge only; Android app is v3+ |
| Generic "multi-wearable abstraction layer" | Seems clean to define a `Wearable` Swift protocol for any future device | Premature abstraction before the second wearable is understood means redesigning when the third one arrives and doesn't fit | Add exactly one new device; extract abstraction only when a third device confirms the pattern |
| Vendor SDK / CocoaPod for the second wearable | Some wearables offer official iOS SDKs | Introducing an external Swift dependency contradicts the project constraint "no external iOS dependencies"; vendor SDKs often require NDAs or paid licences | Use only standard CoreBluetooth + an open GATT spec device (see below) |
| Automatic device-generation negotiation over BLE | Apps sometimes read firmware revision to confirm device type | Already solved at the UUID level: the Gen4 service UUID (`61080001-*`) is different from Gen5 (`fd4b0001-*`); reading firmware adds latency and complexity | UUID-derived `rustDeviceType` (already working) |
| TimescaleDB schema migration for new device columns | Adding device-type-specific columns to TimescaleDB now | Server schema change requires coordinated migration and breaks existing installs; new device type can use existing `device_generation` field if structured correctly | Reuse `device_generation` string field; no schema change required |
| Polar H10 as second wearable (vendor-dependent) | Polar H10 uses standard Heart Rate GATT (0x180D) but raw ECG is on a proprietary characteristic with no public spec | The ECG characteristic format is undocumented without Polar SDK agreement | Use a device with fully public GATT spec (see below) |

---

## Feature Dependencies

```
GEN4-01 (scan discovers Gen4)
    — already done at scan level; dependency is onboarding copy (GEN4-03)

GEN4-02 (GooseDiscoveredDevice.generation field)
    └──enables──> GEN4-04 (device view generation label)
    └──enables──> GEN4-D1 (connection log generation label)

ANDROID-01 (cross-compile for Android)
    └──required by──> ANDROID-02 (JNI wrapper, must be buildable to be useful)
    └──required by──> ANDROID-D1 (build script)

ANDROID-02 (JNI wrapper)
    └──enables──> ANDROID-D2 (Kotlin usage example)
    └──informs──> ANDROID-03 (ADR, documents what was actually built)

WEAR-01 (Rust parsing module for second wearable)
    └──required by──> WEAR-03 (upload identifies device correctly)
    └──informs──> WEAR-D1 (protocol docs)

WEAR-02 (BLE scan includes second wearable UUID)
    └──required by──> WEAR-01 (need to receive BLE frames to test the parser)
    └──required by──> WEAR-03 (upload triggered by BLE events from new device)
```

### Dependency Notes

- **GEN4-01 does not block anything**: scan already discovers Gen4 devices. The remaining GEN4 items
  are UI and documentation work that can proceed in parallel.
- **ANDROID-01 must precede ANDROID-02**: a JNI wrapper that does not build for Android targets is
  untestable and provides false confidence.
- **WEAR-02 must precede WEAR-01**: the Rust parser must be exercised with real BLE frames;
  without the scan including the device UUID, no frames arrive. WEAR-02 is the earliest deliverable.
- **WEAR-01 is the highest-effort item**: it requires choosing a second wearable, understanding its
  GATT protocol, implementing a Rust module, and writing tests. It gates the entire WEAR track.

---

## Second Wearable: Open GATT Spec Options

The project constraint prohibits vendor SDKs. Three device categories have fully public GATT specs:

### Option A: Polar H10 (Heart Rate + RR intervals only)
- Standard Heart Rate Service (0x180D), Heart Rate Measurement (0x2A37) — Bluetooth SIG public spec
- RR intervals included in the same characteristic payload
- ECG raw data: proprietary PMD characteristic — **no public spec without Polar SDK**
- Assessment: suitable for HR+RR only (same data as standard HR monitor); ECG not accessible
- Complexity: LOW (standard GATT 0x180D already parsed in `GooseBLEClient.swift` line 392)
- Already present: `standardHeartRateServiceID = CBUUID(string: "180D")` exists in the codebase

### Option B: Garmin HRM-Pro (Heart Rate + RR via standard GATT)
- Standard Heart Rate Service (0x180D) — same as Polar H10
- No proprietary characteristics accessible without Garmin SDK
- Assessment: identical scope to Polar H10 for this project's purposes
- Complexity: LOW

### Option C: Texas Instruments SensorTag (CC2650 / CC1350)
- Fully open GATT spec, publicly documented by TI
- Temperature, humidity, pressure, optical, movement (accelerometer/gyroscope/magnetometer)
- Not a health wearable — validates architecture extensibility but data is not biometric
- Complexity: MEDIUM (new Rust module for non-WHOOP sensor data; different data model)

### Option D: Any Bluetooth SIG-standardised heart rate monitor
- Devices advertising 0x180D Heart Rate Service with 0x2A37 characteristic have a fully public spec
- The standard Heart Rate Measurement characteristic format is documented in the Bluetooth GATT spec
- Multiple affordable devices: Wahoo TICKR, CooSpo HW807, Garmin HRM-Dual, generic chest straps
- Assessment: **best fit** — biometric data (HR + RR), no vendor NDA, standard parse logic, low cost
- Complexity: LOW for parsing (standard GATT); MEDIUM for end-to-end (new Rust module + BLE + upload)

### Recommendation
Use Option D: a generic Bluetooth SIG heart rate monitor (e.g., Wahoo TICKR or CooSpo HW807).
Rationale:
1. Standard 0x180D service UUID is already in `GooseBLEClient.swift` (line 392) — scan already
   discovers it; no new UUID needed
2. The Heart Rate Measurement (0x2A37) format is documented in the Bluetooth GATT spec, no NDA
3. The data (HR + optional RR intervals) maps directly to existing `hr` and `rr` stream fields
   in the server's `POST /v1/ingest-decoded` API — no server schema change required
4. It validates the architecture: a completely separate `src/heart_rate_gatt_protocol.rs` module
   with its own parse function, separate from `protocol.rs` (WHOOP-specific), confirms extensibility
5. Devices are inexpensive and widely available for testing

---

## MVP Definition

### Launch With (v2.0 — this milestone)

Minimum required to call the milestone complete.

- [x] GEN4-01 — BLE scan already discovers Gen4 (already done; just needs validation)
- [ ] GEN4-02 — `GooseDiscoveredDevice.generation` field populated at discovery
- [ ] GEN4-03 — Onboarding copy acknowledges WHOOP 4.0
- [ ] GEN4-04 — Device view shows generation label
- [ ] GEN4-05 — Upload payload E2E test for Gen4 `device_generation`
- [ ] ANDROID-01 — Cross-compile verified for `aarch64-linux-android`
- [ ] ANDROID-02 — Thin JNI wrapper (`jni_bridge.rs`)
- [ ] ANDROID-03 — ADR committed to `docs/adr/`
- [ ] WEAR-02 — BLE scan includes standard HR monitor service UUID (0x180D already present)
- [ ] WEAR-01 — `src/heart_rate_gatt_protocol.rs` Rust module with parse + tests
- [ ] WEAR-03 — Upload payload identifies HR-monitor-sourced data correctly

### Add After Validation (v2.x)

- [ ] GEN4-D1 — Generation label in connection log
- [ ] ANDROID-D1 — `Scripts/build_android_rust.sh` committed
- [ ] ANDROID-D2 — Kotlin usage example in docs
- [ ] WEAR-D1 — Protocol documentation for HR GATT module

### Future Consideration (v3+)

- [ ] Full Android app UI (Activities, ViewModel, UI framework)
- [ ] Third wearable support (extract Wearable abstraction after two devices confirmed)
- [ ] Background URLSession upload (complex, low value for personal use case)
- [ ] Persistent upload queue (SQLite-backed; defer until data loss is observed in practice)

---

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| GEN4-02 generation field in device struct | MEDIUM | LOW | P1 |
| GEN4-03 onboarding copy | LOW | LOW | P1 |
| GEN4-04 device view label | MEDIUM | LOW | P1 |
| GEN4-05 upload E2E test | LOW | LOW | P1 |
| ANDROID-01 cross-compile | HIGH | MEDIUM | P1 |
| ANDROID-02 JNI wrapper | HIGH | MEDIUM | P1 |
| ANDROID-03 ADR | MEDIUM | LOW | P1 |
| WEAR-02 scan includes HR monitor UUID | HIGH | LOW | P1 |
| WEAR-01 HR GATT Rust module | HIGH | HIGH | P1 |
| WEAR-03 upload identifies device | MEDIUM | LOW | P1 |
| GEN4-D1 connection log label | LOW | LOW | P2 |
| ANDROID-D1 build script | LOW | LOW | P2 |
| ANDROID-D2 Kotlin example | LOW | LOW | P2 |
| WEAR-D1 protocol docs | MEDIUM | MEDIUM | P2 |

---

## Complexity Analysis by Track

### Track 1: WHOOP Gen4 iOS Layer
**Overall complexity: LOW** — the hard work (Rust parsing, frame classification, upload payload) is
done. This track is 80% UI strings and struct fields.

New code estimate:
- `GooseDiscoveredDevice`: +1 `String` field
- `GooseBLEClient+CentralDelegate.swift`: +3-5 lines to populate `generation` from advertised service
- `OnboardingStepViews.swift`: string changes only
- `DeviceView.swift`: +5-10 lines to display generation label
- `GooseUploadServiceTests.swift` (new file or extension): unit test asserting `device_generation`

### Track 2: Android Port Foundations
**Overall complexity: MEDIUM** — requires NDK toolchain setup and JNI naming boilerplate, but the
Rust code does not change; only a thin wrapper and documentation are added.

Key risks:
- `rusqlite` with `bundled` feature uses `cc` crate to compile SQLite C code; cross-compilation
  for Android requires the NDK linker in `PATH` and a `.cargo/config.toml` `[target.*]` section
  specifying the correct linker. This is the most likely stumbling block.
- The JNI wrapper introduces the `jni` crate (or uses raw `extern "C"` with manual JNIEnv handling);
  the `jni` crate is the safer approach and is well-maintained

New code estimate:
- `Rust/core/src/jni_bridge.rs`: ~60-80 lines
- `.cargo/config.toml`: linker entries for android targets
- `Scripts/verify_android_build.sh`: ~20 lines
- `docs/adr/0001-android-jni-bridge.md`: ~150 lines

### Track 3: Second Wearable (Standard HR GATT Monitor)
**Overall complexity: MEDIUM-HIGH** — requires understanding the 0x2A37 Heart Rate Measurement
characteristic format, implementing a Rust parser, and wiring it through the iOS pipeline.

The 0x2A37 format is Bluetooth SIG-standardised:
- Byte 0: flags (bit 0 = HR format 8-bit/16-bit, bit 4 = RR present)
- Bytes 1-2: HR value (8-bit or 16-bit per flag)
- Remaining bytes: RR intervals (16-bit, units 1/1024 seconds)

This is simpler than the WHOOP proprietary frame format. The Rust module will be shorter than
`protocol.rs` and does not need CRC or frame length headers.

New code estimate:
- `Rust/core/src/heart_rate_gatt_protocol.rs`: ~150-200 lines + tests
- `GooseBLETypes.swift`: update `rustDeviceType` derivation for 0x180D service
- `GooseBLEClient+CentralDelegate.swift`: handle non-WHOOP peripheral naming
- `GooseAppModel+NotificationPipeline.swift`: route 0x2A37 notifications to new parser
- `GooseUploadService.swift`: pass correct device type string for HR monitor

---

## Sources

- Codebase read directly: `GooseSwift/GooseBLEClient.swift`, `GooseBLETypes.swift`,
  `GooseBLEClient+UserActions.swift`, `GooseBLEClient+Parsing.swift`,
  `GooseBLEClient+CentralDelegate.swift`, `GooseUploadService.swift`,
  `GooseAppModel+Upload.swift`, `OnboardingStepViews.swift`,
  `Rust/core/src/protocol.rs`, `Rust/core/Cargo.toml`, `Rust/core/src/bridge.rs`,
  `Rust/core/include/goose_core_bridge.h`
- PROJECT.md: `.planning/PROJECT.md` (constraints, active requirements, out-of-scope)
- CoreBluetooth API: Context7 `/websites/developer_apple_corebluetooth`
  `scanForPeripherals(withServices:options:)` — HIGH confidence
- Android NDK JNI: Context7 `/android/ndk` — JNI naming convention, `System.loadLibrary`,
  `JNI_OnLoad` registration — HIGH confidence
- Rust Android build: Context7 `/rust-mobile/rust-android-examples`
  `cargo-ndk`, `rustup target add aarch64-linux-android` — MEDIUM confidence
- Bluetooth GATT 0x180D Heart Rate Service, 0x2A37 Measurement characteristic format:
  Bluetooth SIG public specification (standard, HIGH confidence — no source needed)
- Confidence: HIGH overall. All critical implementation facts come from direct codebase reads.
  Android NDK details are MEDIUM (build environment specifics depend on local toolchain versions).
