# Roadmap: Goose

## Milestones

- ✅ **v1.0 Remote Server + Upstream PRs** — Phases 1-5 (shipped 2026-06-03)

## Phases

<details>
<summary>✅ v1.0 Remote Server + Upstream PRs (Phases 1-5) — SHIPPED 2026-06-03</summary>

- [x] Phase 1: Server Infrastructure (3/3 plans) — completed 2026-06-03
- [x] Phase 2: iOS Server Settings (2/2 plans) — completed 2026-06-03
- [x] Phase 3: iOS Upload Client (3/3 plans) — completed 2026-06-03
- [x] Phase 4: Upload Status Feedback (2/2 plans) — completed 2026-06-03
- [x] Phase 5: Upstream PR Integration (4/4 plans) — completed 2026-06-03

Full details: `.planning/milestones/v1.0-ROADMAP.md`

</details>

## Progress

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 1. Server Infrastructure | v1.0 | 3/3 | Complete | 2026-06-03 |
| 2. iOS Server Settings | v1.0 | 2/2 | Complete | 2026-06-03 |
| 3. iOS Upload Client | v1.0 | 3/3 | Complete | 2026-06-03 |
| 4. Upload Status Feedback | v1.0 | 2/2 | Complete | 2026-06-03 |
| 5. Upstream PR Integration | v1.0 | 4/4 | Complete | 2026-06-03 |

### Phase 6: WHOOP 4.0 (Gen4) Support

**Goal:** Expose Gen4 support in the iOS connect flow — the user can connect, capture, and upload data from a WHOOP 4.0 with the same experience as the 5.0. The Rust core and protocol already fully support Gen4 (DeviceType::Gen4, 4-byte header, CRC8, UUID 61080001-8D6D-82B8-614A-1C8CB0F8DCC6). What is missing is the iOS app-layer: onboarding recognises WHOOP 4.0, the BLE client scans the Gen4 service UUID, and the generation is correctly classified and propagated.
**Mode:** mvp
**Depends on:** Phase 3
**References:** `/Users/francisco/Documents/my-whoop/ios/OpenWhoop/BLE/` — existing Gen4 BLE patterns; `Rust/core/src/protocol.rs` — DeviceType::Gen4 already implemented
**Requirements**: GEN4-01, GEN4-02, GEN4-03, GEN4-04, GEN4-05
**Success Criteria** (what must be TRUE):
  1. A user with a WHOOP 4.0 can connect the device in the app (onboarding and connect flow)
  2. BLE scan includes the Gen4 service UUID (61080001-8D6D-82B8-614A-1C8CB0F8DCC6)
  3. Gen4 frames are captured, parsed, and written to SQLite correctly
  4. Upload sends `device_generation: "4.0"` in the payload (server already accepts this)
**Plans:** TBD

### Phase 7: Android Port Foundations

**Goal:** Establish the architectural foundations that do not close the door to a future Android port, without performing a rewrite now. The Rust core already compiles to Android targets (aarch64-linux-android, armv7-linux-androideabi) via Cargo. Formalise the FFI bridge to support JNI, document the architecture extension points, and validate that the Rust core works on an Android emulator. Context: upstream issues #2 and #9.
**Mode:** mvp
**Depends on:** Phase 6
**Requirements**: ANDROID-01, ANDROID-02, ANDROID-03
**Success Criteria** (what must be TRUE):
  1. `cargo build --target aarch64-linux-android` produces a static library without errors
  2. FFI bridge documentation describes how to integrate with JNI (Kotlin/Android)
  3. ADR documents the architectural choices that facilitate (or do not close) the Android port
**Plans:** TBD

### Phase 8: Additional Wearables Support

**Goal:** Add support for a second wearable type beyond WHOOP (e.g. Amazfit Helio Strap or Fitbit Air), validating that the Rust core + BLE pipeline architecture is extensible. Rust core handles parsing and SQLite; the iOS BLE layer is modular by GATT service. Context: upstream issue #14.
**Mode:** mvp
**Depends on:** Phase 6
**Requirements**: WEAR-01, WEAR-02, WEAR-03
**Success Criteria** (what must be TRUE):
  1. The user can connect a second device type and see captured data in the app
  2. Rust core has a separate parsing module for the new device (without contaminating the WHOOP module)
  3. The BLE→SQLite→upload pipeline works for the new device with the same server
**Plans:** TBD
