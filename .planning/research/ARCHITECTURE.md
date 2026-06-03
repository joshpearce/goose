# Architecture Research

**Domain:** iOS biometric app — multi-device BLE + cross-platform Rust core (v2.0)
**Researched:** 2026-06-03
**Confidence:** HIGH (based on direct source code inspection of all relevant files)

---

## Standard Architecture

### System Overview

```
┌──────────────────────────────────────────────────────────────────┐
│                         iOS SwiftUI Layer                         │
│  ┌────────────────┐  ┌────────────────┐  ┌──────────────────┐   │
│  │  GooseAppModel │  │ HealthDataStore │  │  GooseUpload-    │   │
│  │  @MainActor    │  │  @MainActor    │  │  Service         │   │
│  │  coordinator   │  │  query layer   │  │  (uploadQueue)   │   │
│  └───────┬────────┘  └───────┬────────┘  └────────┬─────────┘   │
│          │                   │                     │             │
│  ┌───────▼────────┐  ┌───────▼────────┐           │             │
│  │ GooseBLEClient │  │GooseRustBridge │           │ URLSession  │
│  │ (CBCentral-    │  │ (JSON-over-FFI)│           │ POST        │
│  │  Manager)      │  └───────┬────────┘           │ /v1/ingest  │
│  └───────┬────────┘          │                    └─────────────┘
│          │           ┌───────▼────────┐
│  BLE     │           │ libgoose_core  │  staticlib (iOS)
│  frames  │           │  Rust crate    │  cdylib (Android, future)
└──────────┼───────────┴────────────────┴──────────────────────────┘
           │
   ┌───────▼───────────────────────────────────────────┐
   │              BLE Layer (CoreBluetooth)             │
   │   WHOOP Gen5 service: fd4b0001-...                 │
   │   WHOOP Gen4 service: 61080001-...                 │
   └───────────────────────────────────────────────────┘
```

### Component Responsibilities

| Component | File(s) | Responsibility |
|-----------|---------|----------------|
| `GooseBLEClient` | `GooseBLEClient.swift` + `+*.swift` | CBCentralManager; scan, connect, characteristic routing, frame reassembly, command writes |
| `GooseAppModel` | `GooseAppModel.swift` + `+*.swift` | @MainActor coordinator; wires BLE → parser → SQLite → upload pipeline |
| `GooseRustBridge` | `GooseRustBridge.swift` | JSON-over-FFI; calls `goose_bridge_handle_json` / `goose_bridge_free_string` |
| `CaptureFrameWriteQueue` | `CaptureFrameWriteQueue.swift` | Batched SQLite inserts via Rust bridge on background queue |
| `OvernightSQLiteMirrorQueue` | `OvernightSQLiteMirrorQueue.swift` | Overnight guard: queues raw notification rows to Rust bridge |
| `GooseUploadService` | `GooseUploadService.swift` | URLSession POST to `/v1/ingest-decoded`; 3-attempt retry with 1s/2s/4s backoff |
| `GooseNotificationEvent` | `GooseBLETypes.swift` | BLE event value type; carries `rustDeviceType` derived from `characteristicUUID` prefix |
| Rust `bridge.rs` | `Rust/core/src/bridge.rs` | Dispatcher for all 80+ bridge RPC methods; C ABI entry point |
| Rust `protocol.rs` | `Rust/core/src/protocol.rs` | `DeviceType` enum (Gen4/Maverick/Puffin/Goose), frame parsing, `FrameAccumulator` |

---

## Integration Points for v2.0 Features

### 1. WHOOP Gen4 — iOS Layer

**Current state (verified by source inspection):** The Rust core is already complete. `DeviceType::Gen4` exists in `protocol.rs` with a 4-byte header and CRC8. The iOS BLE layer already scans both service UUIDs — they are listed in `whoopServices` at line 366 of `GooseBLEClient.swift`:

```
fd4b0001-cce1-4033-93ce-002d5875f58a  (Gen5/Maverick)
61080001-8d6d-82b8-614a-1c8cb0f8dcc6  (Gen4)
```

`notificationCharacteristicIDs` already includes the Gen4 characteristic UUIDs (`61080003` through `61080007`). The `rustDeviceType` routing is live: `GooseNotificationEvent.rustDeviceType` in `GooseBLETypes.swift:34-36` returns `"GEN4"` when `characteristicUUID` has prefix `"610800"`, and `"GOOSE"` otherwise. `GooseUploadService` already maps `"GEN4"` to `device_generation: "4.0"`.

**What is actually missing (iOS-only gap):**

| Gap | Location | Change required |
|-----|----------|-----------------|
| `supportsV5*` computed properties | `GooseBLEClient+Commands.swift:147-165` | Currently checks for `fd4b0002` prefix only; blocks command writes on Gen4 connections; need to also accept `61080002` |
| Onboarding device recognition | `GooseBLEClient+Parsing.swift:336` | `isWhoopName()` accepts any name containing "whoop" (case-insensitive); Gen4 device names should be tested against real hardware to confirm they contain "whoop" |
| `supportsV5*` UI hint in `alarmWriteSupportSummary` | `GooseBLEClient.swift:898` | The message "Alarm writes need fd4b0002 V5 command framing" will be wrong for Gen4; update to include Gen4 characteristic |

**Minimal change: one file.** Modify `GooseBLEClient+Commands.swift` only. Add `isGen4CommandCharacteristic` mirroring `isV5CommandCharacteristic`, then update `supportsV5*` guards to accept either. No new files.

---

### 2. Android JNI Bridge

**Current Cargo.toml state (verified):** `crate-type = ["rlib", "staticlib", "cdylib"]` — `cdylib` is already declared. The shared object for Android is available without changing `Cargo.toml`.

**Recommended approach: thin JNI wrapper inside the same crate, in `bridge.rs`.**

Rationale: the existing C ABI (`goose_bridge_handle_json` / `goose_bridge_free_string`) is already a thin wrapper over `handle_bridge_request`. Adding JNI symbols adds approximately 30 lines and zero new build complexity. A separate crate would require its own `Cargo.toml`, target overrides, CI configuration, and cross-dependency management — all overhead for two function signatures. `#[cfg(target_os = "android")]` gates the code at compile time; iOS builds are completely unaffected.

**Structure in `Rust/core/src/bridge.rs`:**

```rust
#[cfg(target_os = "android")]
mod jni_bridge {
    use jni::JNIEnv;
    use jni::objects::{JClass, JString};
    use jni::sys::jstring;

    #[no_mangle]
    pub unsafe extern "C" fn Java_com_goose_NativeLib_bridgeHandleJson(
        mut env: JNIEnv,
        _class: JClass,
        request: JString,
    ) -> jstring {
        let req: String = env.get_string(&request).unwrap().into();
        let resp = super::handle_bridge_request_str(&req);
        env.new_string(resp).unwrap().into_raw()
    }
}
```

This requires adding `jni = "0.21"` to `[target.'cfg(target_os = "android")'.dependencies]` in `Cargo.toml` and extracting a `handle_bridge_request_str(input: &str) -> String` helper from the existing C ABI function (three-line refactor).

**Build toolchain:** Use `cargo-ndk` to cross-compile to `aarch64-linux-android`. Add `Scripts/build_android_rust.sh` mirroring `Scripts/build_ios_rust.sh`. NDK path is the only required environment variable.

**Modified files:**
- `Rust/core/src/bridge.rs` — add `#[cfg(target_os = "android")]` JNI module + extract string helper
- `Rust/core/Cargo.toml` — add `[target.'cfg(target_os = "android")'.dependencies]` block with `jni`

**New files:**
- `Scripts/build_android_rust.sh`
- `docs/ADR-android-jni.md`

---

### 3. Additional Wearable (Second Device Type E2E)

**Where device-type routing happens in the existing pipeline:**

The routing decision happens at exactly one point: `GooseNotificationEvent.rustDeviceType` in `GooseBLETypes.swift:34-36`. This computed property reads `characteristicUUID` and returns a string that flows immutably through the entire pipeline — parser, Rust bridge args, upload payload. There is no re-derivation or late binding downstream.

```
characteristic UUID "61080003-..."
    → GooseNotificationEvent.rustDeviceType = "GEN4"   ← single derivation point
    → bridge arg device_type: "GEN4"
    → Rust DeviceType::Gen4 → 4-byte header, CRC8
    → device_generation "4.0" in upload payload
```

**For a second wearable (e.g., Polar H10), changes required at each layer:**

| Layer | File | Change |
|-------|------|--------|
| BLE scan | `GooseBLEClient.swift:366` | Add Polar service UUID to `whoopServices` array |
| Device identity filter | `GooseBLEClient+Parsing.swift:336` | `isWhoopName()` is too narrow; extract `isKnownWearableName()` or add separate check |
| `rustDeviceType` routing | `GooseBLETypes.swift:34` | Extend `rustDeviceType` to return `"POLAR"` for Polar characteristic UUID prefix |
| Rust frame parser | New: `Rust/core/src/protocol_polar.rs` | Device-specific `ParsedFrame` logic |
| Rust bridge dispatch | `Rust/core/src/bridge.rs` | Add `"polar.parse_frame"` to `BRIDGE_METHODS` and `handle_bridge_request` match |
| `lib.rs` module declaration | `Rust/core/src/lib.rs` | `pub mod protocol_polar;` |
| Upload payload | `GooseUploadService.swift:88` | Extend `deviceGeneration` mapping or add `device_type` field |

**Clean abstraction — WearableDescriptor:**

The current code scatters device identity across several arrays and functions (`whoopServices`, `commandCharacteristicIDs`, `notificationCharacteristicIDs`, `debugMenuCharacteristicIDs`, `isWhoopName`, `isV5CommandCharacteristic`, `isWhoopService`). Introducing a descriptor struct now (in Phase 6) avoids extending each array individually in Phase 8:

```swift
struct WearableDescriptor {
  let brandName: String
  let serviceUUIDs: [CBUUID]
  let commandCharacteristicUUIDs: [CBUUID]
  let notificationCharacteristicUUIDs: [CBUUID]
  let debugMenuCharacteristicUUIDs: [CBUUID]
  let rustDeviceType: String
  let isKnownName: (String) -> Bool
}
```

`GooseBLEClient` holds `[WearableDescriptor]` and all UUID lookups, name checks, and `rustDeviceType` derivation delegate to the matching descriptor. No protocol conformance, no dynamic dispatch, consistent with the property-based composition style of the codebase.

---

## Recommended Project Structure Changes

```
GooseSwift/
├── GooseBLEClient.swift              # MODIFY (Phase 6): whoopServices -> wearableDescriptors
├── GooseBLEClient+Commands.swift     # MODIFY (Phase 6): supportsV5* guards accept Gen4
├── GooseBLEClient+Parsing.swift      # MODIFY (Phase 6): isWhoopName -> isKnownWearableName
├── GooseBLETypes.swift               # MODIFY (Phase 8): rustDeviceType routing for second wearable
├── WearableDescriptor.swift          # NEW (Phase 6): device descriptor value type
├── GooseUploadService.swift          # MODIFY (Phase 8): device_type field in payload

Rust/core/src/
├── protocol.rs                       # EXISTING: DeviceType enum (Gen4 already done)
├── protocol_polar.rs                 # NEW (Phase 8): Polar frame parser
├── bridge.rs                         # MODIFY (Phase 7+8): JNI module, polar methods
├── lib.rs                            # MODIFY (Phase 8): pub mod protocol_polar

Scripts/
├── build_ios_rust.sh                 # EXISTING: unchanged
├── build_android_rust.sh             # NEW (Phase 7): cargo-ndk cross-compile

docs/
├── ADR-android-jni.md                # NEW (Phase 7): architecture decision record
```

---

## Recommended Build Order: Phases 6 to 8

### Phase 6: WHOOP Gen4 iOS Completion

**Dependency:** Rust core already done. iOS-only changes.

Changes:
- `GooseBLEClient+Commands.swift` — fix `supportsV5*` guards to not block Gen4 sessions
- `WearableDescriptor.swift` — introduce descriptor type (recommended here to avoid doing it under time pressure in Phase 8)
- `GooseBLEClient.swift`, `GooseBLEClient+Parsing.swift` — refactor arrays and name check to use descriptor

**Why first:** Lowest risk, no new Rust compilation targets, directly unblocks `GEN4-01` through `GEN4-05`. Can be validated without hardware if BLE simulation or a test harness is available.

### Phase 7: Android JNI Foundations

**Dependency:** Rust core compiles cleanly; Phase 6 work does not interfere.

Changes:
- `Rust/core/src/bridge.rs` — add `#[cfg(target_os = "android")]` JNI module
- `Rust/core/Cargo.toml` — add `jni` dependency under cfg-gated target block
- `Scripts/build_android_rust.sh` — cargo-ndk script
- CI — add `aarch64-linux-android` compile check (no device test required)
- `docs/ADR-android-jni.md` — decision record

**Why second:** No iOS changes. Can be developed in parallel with Phase 6 on a separate branch. The `cdylib` target already declared in Cargo.toml means no build system surprises. The ADR deliverable is self-contained.

### Phase 8: Additional Wearable E2E

**Dependency:** Requires `WearableDescriptor` from Phase 6. Rust bridge extension pattern proven by Phase 7. Upload payload extension is the only cross-layer coordination remaining.

Changes:
- `GooseBLEClient.swift` — add second wearable descriptor to `wearableDescriptors`
- `GooseBLETypes.swift` — extend `rustDeviceType` for new characteristic prefix
- `Rust/core/src/protocol_polar.rs` — new frame parser module
- `Rust/core/src/bridge.rs` — new bridge method(s) for second wearable
- `Rust/core/src/lib.rs` — `pub mod protocol_polar`
- `GooseUploadService.swift` — extend upload payload with `device_type` or extended mapping

**Why last:** Requires the most cross-layer coordination (iOS BLE + Rust protocol + server upload schema). Doing it after Phase 6 validates the descriptor abstraction and after Phase 7 validates the Rust bridge extension pattern.

---

## Data Flow

### Real-Time BLE to SQLite to Upload (unchanged from v1.0, shown for reference)

```
[BLE notification from WHOOP]
    ↓ characteristicUUID → rustDeviceType at GooseNotificationEvent init
[GooseBLEClient] notificationIngestQueue reassembles frames
    ↓ GooseNotificationEvent (rustDeviceType immutable from here)
[GooseAppModel+NotificationPipeline]
    ↓ notificationParseQueue
[NotificationFrameParser.parseBatch(deviceType:)]
    ↓ GooseRustBridge → bridge.rs → protocol.rs parse_frame
[CaptureFrameWriteQueue] batched SQLite write
    ↓ on write success
[GooseAppModel+Upload.triggerUpload]
    ↓ deviceType = event.rustDeviceType
[GooseUploadService.performUpload] → POST /v1/ingest-decoded
```

**Key invariant:** `rustDeviceType` is derived once at `GooseNotificationEvent` creation from `characteristicUUID`, then carried immutably. No component downstream re-derives it.

### Gen4 Frame Routing (existing, confirmed working)

```
characteristic UUID "61080003-..."
    → rustDeviceType = "GEN4"        (GooseBLETypes.swift:34)
    → bridge arg device_type: "GEN4" (GooseAppModel+NotificationPipeline.swift:514)
    → Rust DeviceType::Gen4          (protocol.rs: 4-byte header, CRC8)
    → device_generation "4.0"        (GooseUploadService.swift:88)
```

This is wired end-to-end. The only iOS gap is `supportsV5*` in `GooseBLEClient+Commands.swift` blocking command writes for Gen4 connections.

---

## Architectural Patterns

### Pattern 1: Routing by Characteristic UUID Prefix

**What:** Device type is determined at the BLE event boundary by examining which characteristic UUID delivered the notification. The UUID prefix (`fd4b` vs `61080`) encodes the generation.

**When to use:** Any time device-type-specific behavior is needed downstream — frame parsing, command writes, upload payload, UI display.

**Trade-offs:** Simple, zero overhead. Breaks if a future device shares UUID prefixes with WHOOP (unlikely given GATT conventions).

**Extend for new wearable:** Add a new prefix check to `GooseNotificationEvent.rustDeviceType`. With `WearableDescriptor`, the lookup becomes a flatMap over the descriptors array rather than a hardcoded if-chain.

### Pattern 2: Stateless Rust Bridge (JSON-RPC)

**What:** Every bridge call passes `database_path` in args. `GooseRustBridge` is not a singleton. Multiple instances (one per component) each call the same C FFI function.

**When to use:** Any new component that needs Rust core access creates its own `GooseRustBridge()` instance on its background queue. Never call from `@MainActor` inline.

**Extend for new protocol:** Add new bridge methods to `BRIDGE_METHODS` constant and `handle_bridge_request` match arms. The compile-time test `bridge_methods_constant_matches_dispatcher` catches any drift.

### Pattern 3: Concern-Scoped Extension Files

**What:** Large classes split into `+ConcernName.swift` extension files. Each extension owns a coherent behavioural slice.

**When to use:** When a new behaviour is added to an existing class. Do not add to the main file.

**For new wearable:** Add `GooseBLEClient+WearableDiscovery.swift` if descriptor-based lookup logic grows beyond a few lines.

---

## Anti-Patterns

### Anti-Pattern 1: Duplicating UUID Arrays Across Lists

**What people do:** Adding a Gen4 or Polar UUID to `notificationCharacteristicIDs` but forgetting `serviceDiscoveryIDs`, `debugMenuCharacteristicIDs`, or `commandCharacteristicIDs`.

**Why it's wrong:** Each array is checked independently. A UUID missing from `serviceDiscoveryIDs` means `discoverServices` never discovers it, silently breaking capture.

**Do this instead:** Centralise in `WearableDescriptor`. The descriptor owns all UUIDs for a device family. `GooseBLEClient` builds combined arrays by flatMapping over all descriptors.

### Anti-Pattern 2: Late Device Type Derivation

**What people do:** Deriving `rustDeviceType` from `peripheral.name` or from a stored property after connection, rather than from `characteristicUUID` at notification time.

**Why it's wrong:** A device can advertise a name before services are discovered; name-based derivation is ambiguous if a user owns both Gen4 and Gen5. Characteristic UUID is unambiguous and available at every notification event.

**Do this instead:** Keep `GooseNotificationEvent.rustDeviceType` as the single source of truth, derived at event creation.

### Anti-Pattern 3: Separate JNI Crate

**What people do:** Create a `goose-jni` crate that depends on `goose-core` to avoid "polluting" the iOS crate with Android code.

**Why it's wrong:** Doubles build configurations, CI targets, and version synchronisation. `#[cfg(target_os = "android")]` already gates the code at compile time — iOS static library is unaffected.

**Do this instead:** Add a `#[cfg(target_os = "android")]` module in `bridge.rs`.

### Anti-Pattern 4: Calling GooseRustBridge from @MainActor Inline

**What people do:** Calling `bridge.request(method:args:)` directly inside a SwiftUI view or `@MainActor` method.

**Why it's wrong:** `goose_bridge_handle_json` is synchronous and blocks the calling thread. On the main thread this freezes the UI.

**Do this instead:** Dispatch to a background `DispatchQueue`. All existing callers (`GooseUploadService.uploadQueue`, `notificationParseQueue`, `CaptureFrameWriteQueue`) follow this pattern.

---

## New vs. Modified Components Summary

| Component | Status | Phase |
|-----------|--------|-------|
| `GooseBLEClient+Commands.swift` | MODIFY: `supportsV5*` accept Gen4 command characteristic | 6 |
| `WearableDescriptor.swift` | NEW: device descriptor value type | 6 |
| `GooseBLEClient.swift` | MODIFY: `whoopServices` becomes `wearableDescriptors` | 6 |
| `GooseBLEClient+Parsing.swift` | MODIFY: `isWhoopName` widens to `isKnownWearableName` | 6 |
| `Rust/core/src/bridge.rs` | MODIFY: JNI module (Phase 7) + wearable methods (Phase 8) | 7, 8 |
| `Rust/core/Cargo.toml` | MODIFY: `jni` dependency (cfg-gated for android) | 7 |
| `Scripts/build_android_rust.sh` | NEW: cargo-ndk cross-compile script | 7 |
| `docs/ADR-android-jni.md` | NEW: architecture decision record | 7 |
| `Rust/core/src/protocol_polar.rs` | NEW: second wearable frame parser | 8 |
| `Rust/core/src/lib.rs` | MODIFY: `pub mod protocol_polar` | 8 |
| `GooseBLETypes.swift` | MODIFY: `rustDeviceType` routing for second wearable | 8 |
| `GooseUploadService.swift` | MODIFY: `device_type` field or extended mapping in payload | 8 |

### Unchanged Components (all three phases)

- `GooseRustBridge.swift` — C ABI is stable; JNI is an additive symbol
- `GooseAppModel+NotificationPipeline.swift` — routes by `event.rustDeviceType` string; new values flow through unchanged
- `CaptureFrameWriteQueue.swift` — device-agnostic batched write
- `OvernightSQLiteMirrorQueue.swift` — device-agnostic
- `GooseAppModel+Upload.swift` — calls `triggerUpload` with `event.rustDeviceType`; no change needed for Gen4 or new wearable
- `Rust/core/src/protocol.rs` — `DeviceType::Gen4` already implemented; new wearable gets its own module

---

## Sources

- Direct source inspection: `GooseBLEClient.swift` (lines 366–420, service and characteristic UUID arrays)
- Direct source inspection: `GooseBLETypes.swift` (lines 34–36, `rustDeviceType` derivation)
- Direct source inspection: `GooseBLEClient+Commands.swift` (lines 147–165, `supportsV5*` guards)
- Direct source inspection: `GooseBLEClient+Parsing.swift` (lines 302–410, `whoopIdentityEvidence`, `isWhoopName`)
- Direct source inspection: `GooseBLEClient+CentralDelegate.swift` (lines 89–200, scan and connect flow)
- Direct source inspection: `GooseAppModel+NotificationPipeline.swift` (lines 367–523, parse context and device type propagation)
- Direct source inspection: `GooseAppModel+Upload.swift` (upload trigger hook)
- Direct source inspection: `GooseUploadService.swift` (lines 29–88, `deviceType` to `device_generation` mapping)
- Direct source inspection: `Rust/core/src/protocol.rs` (lines 24–59, `DeviceType` enum with Gen4 header/CRC logic)
- Direct source inspection: `Rust/core/src/lib.rs` (module list)
- Direct source inspection: `Rust/core/Cargo.toml` (crate-type declaration, dependency list)
- `jni` crate 0.21 — standard Rust JNI bindings for Android: HIGH confidence (widely used, stable API)

---
*Architecture research for: Goose v2.0 Multi-Device & Platform Foundations*
*Researched: 2026-06-03*
