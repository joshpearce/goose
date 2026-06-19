<!-- generated-by: gsd-doc-writer -->
# Architecture Overview

Goose is a two-tier biometric platform. An iOS app captures raw biometric data from a WHOOP wearable over Bluetooth Low Energy and persists it locally in SQLite (schema v21) via a Rust core library. A self-hosted server (FastAPI + TimescaleDB, deployed via Docker Compose) receives decoded biometric streams from the app and provides a read API and a static dashboard. The two tiers are loosely coupled: the iOS app operates fully offline and uploads opportunistically when a server URL and API key are configured.

---

## Component Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│ iOS App (GooseSwift)                                                │
│                                                                     │
│  WHOOP Device                                                       │
│      │ BLE GATT notifications                                       │
│      ▼                                                              │
│  GooseBLEClient  ──onNotification──►  GooseAppModel                │
│                                           │                         │
│                              notificationIngestQueue                │
│                                           │                         │
│                                           ▼                         │
│                                 NotificationFrameParser             │
│                                    (Rust: protocol.parse_frame_hex) │
│                                           │ frames                  │
│                                           ▼                         │
│                               CaptureFrameWriteQueue                │
│                                    (Rust: capture.import_frame_batch)│
│                                           │ SQLite write            │
│                                           ▼                         │
│                                  goose.sqlite (local, schema v21)   │
│                                           │                         │
│                              ┌────────────┴───────────┐            │
│                              │                        │             │
│                              ▼                        ▼             │
│                       HealthDataStore          GooseUploadService   │
│                       (Rust: metrics.*)         (detached tasks)    │
│                       @MainActor scores         │                   │
│                                                 │ POST /v1/ingest-  │
│                                                 │ decoded + Bearer  │
└─────────────────────────────────────────────────┼───────────────────┘
                                                  │ HTTPS
┌─────────────────────────────────────────────────▼───────────────────┐
│ Self-Hosted Server (Docker Compose)                                 │
│                                                                     │
│  goose-ingest (FastAPI, port 8770)                                  │
│      │ store.upsert_streams → daily.compute_day                     │
│      ▼                                                              │
│  goose-db (TimescaleDB / PostgreSQL 16)                             │
│      hypertables: hr_samples, rr_intervals, events, battery,       │
│      spo2_samples, skin_temp_samples, resp_samples,                 │
│      gravity_samples, raw_frames                                    │
│      plain tables: sleep_sessions, exercise_sessions, daily_metrics,│
│      devices, raw_batches, profile                                  │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Operational Modes

The app operates in eight distinct modes. Modes are not mutually exclusive: overnight guard can run concurrently with BLE real-time monitoring; activity recording always co-exists with a capture session. The sections below describe each mode: what triggers it, which components are active, how data flows, and how it terminates.

---

### Mode 1 — Real-Time BLE Monitoring (Normal Operation)

**Trigger:** WHOOP device connects and `GooseBLEClient.connectionState` transitions to `"ready"`. This is the baseline operating state; all other modes layer on top of it.

**Active components:**
- `GooseBLEClient` — CoreBluetooth central; subscribes to GATT notification characteristics and writes command frames.
- `GooseAppModel.notificationIngestQueue` — serial `DispatchQueue` that serialises incoming raw bytes.
- `NotificationFrameParser` — calls `Rust: protocol.parse_frame_hex` via `GooseRustBridge` to reassemble multi-packet WHOOP frames.
- `CaptureFrameWriteQueue` — batches parsed frames and calls `Rust: capture.import_frame_batch` to persist them to SQLite.
- `GooseUploadService` — triggered after each successful write batch via `GooseAppModel.triggerUpload`.
- `WhoopDataSignalPipeline` — ingests `WhoopDataSignalSample` on its own queue; feeds HR and motion aggregators.

**Data flow:**

```
WHOOP GATT notification bytes
  → GooseBLEClient.onNotification callback
  → GooseAppModel.handleNotification (dispatched to notificationIngestQueue)
  → NotificationFrameParser → Rust: protocol.parse_frame_hex
      (multi-packet reassembly; buffered remainder kept between calls)
  → Parsed frames handed back to @MainActor
  → CaptureFrameWriteQueue.enqueue(frames)
      → Rust: capture.import_frame_batch (on capture-frame-row-build queue)
      → SQLite: decoded_frames, hr_samples, rr_intervals, events, gravity2_samples, ...
  → GooseAppModel.triggerUpload (on write-batch success)
      → GooseUploadService.upload (detached Task.utility)
```

**Termination:** BLE disconnection, app backgrounding beyond allowed time, or user disconnects from the WHOOP. On disconnect, `GooseBLEClient.connectionState` transitions away from `"ready"`, and all downstream components drain their pending queues before going idle.

---

### Mode 2 — Overnight Guard Mode

**Trigger:** User taps "Start Overnight Guard" in the app. `GooseAppModel.startOvernightGuard()` is called. Requires `ble.connectionState == "ready"`.

**Active components:**
- `OvernightRawNotificationSpool` — append-only JSONL spool of every raw BLE notification, command write, historical range poll telemetry, and event log entry. Written to `ApplicationSupport/GooseSwift/overnight-guard/<sessionID>/`.
- `OvernightSQLiteMirrorQueue` — a dedicated `DispatchQueue(label: "com.goose.swift.overnight-sqlite-mirror", qos: .utility)` that batches rows and calls `Rust: overnight.insert_raw_notification_batch` (flush every 2 s, batch limit 256). Holds its own `GooseRustBridge` instance.
- Physiology packet capture — `startPhysiologyPacketCapture` is called automatically when overnight guard starts (unless a health capture session is already active).
- Heartbeat scheduler — `scheduleOvernightGuardHeartbeat()` fires on `DispatchQueue.main` every `overnightGuardHeartbeatInterval` to refresh power state and watchdog, then writes a status snapshot.
- Range poll scheduler — `scheduleOvernightGuardRangePoll()` fires periodically (default interval, 8 s initial delay) to call `GooseBLEClient.pollHistoricalRange()`. Polls are suspended during final sync.
- Watchdog — monitors incoming target packet types (K18, K24, K25, K26, packet types 47/49/56, event IDs 17/29) and sets `overnightGuardWatchdogWarning` if no targets arrive within the watchdog window.
- Critical background task — `UIApplication.beginBackgroundTask` is claimed at startup and refreshed during final sync and export to give iOS additional time to run.

**Data flow (per BLE notification during guard):**

```
BLE notification
  → GooseAppModel.handleNotification (normal parse path, as Mode 1)
  → GooseAppModel.persistOvernightRawNotificationBeforeInterpretation
      → OvernightRawNotificationSpool.append (JSONL file append, nonisolated)
      → OvernightSQLiteMirrorQueue.enqueueRawNotification
          → Rust: overnight.insert_raw_notification_batch (batched flush)
  → Published to @MainActor: overnightGuardRawNotificationCount updated every 50 notifications
```

**Final sync sequence (user-triggered):**

```
User taps "Final Sync"
  → GooseAppModel.requestOvernightGuardFinalSync()
  → Live physiology stream paused (stopPhysiologySignalCapture or stopHealthPacketCapture)
  → 2.2 s grace period, then:
  → GooseBLEClient.syncHistoricalPacketsPreservingUnreadQueue(rangeFirst: true)
      (runs historical sync — see Mode 5)
  → On terminal sync progress: scheduleOvernightGuardFinalSyncDrain
      → overnightGuardFinalSyncDrainInterval pause to drain trailing frames
      → completeOvernightGuard(reason: "final_sync_complete")
  → exportOvernightGuardBundle: OvernightSQLiteMirrorQueue.flushSynchronously()
      → GooseLocalDataExporter.createBundle (ZIP on global .userInitiated queue)
      → overnightGuardExportURL set; export available to share sheet
```

**Crash recovery:** On next app launch, `GooseAppModel.recoverUncleanOvernightGuardSessionIfNeeded()` scans the overnight-guard directory on `rustStartupQueue`, finds the most recent unfinished session, and calls `OvernightRawNotificationSpool.resume()` to re-attach state. The session is available for export without requiring a new guard session.

**Termination:** Manual stop (`stopOvernightGuard(reason: "manual_stop")`), successful final sync drain, or app termination. On completion, all scheduled work items are cancelled, `overnightGuardActive` is set to `false`, and (on final sync path) the bundle export is initiated automatically.

---

### Mode 3 — Workout / Activity Recording Mode

**Trigger:** User starts a workout from the Home or Activity tab (`beginActivityRecording`), or the passive activity detector elevates a candidate session to confirmed status. Can also be triggered by `detectionMethod: "auto_detected"` from `PassiveActivityDetectionPipeline`.

**Active components:**
- `GooseAppModel.beginActivityRecording` — records `ActiveActivityPersistence` struct with session UUID, capture session reference, start time, and provenance.
- Movement/heart rate capture stream — `ble.startMovementHeartRateCapture()` is called for user-assigned activities (K10 raw motion packets).
- High-frequency historical sync — `enterActivityHighFrequencyHistorySyncIfNeeded` is called on activity start for user-assigned activities; exits on activity finish.
- `CaptureFrameWriteQueue` — batches incoming raw motion frames; `importedFrameCount` is tracked in `ActiveActivityPersistence`.
- `WorkoutLiveActivityController` — starts an `ActivityKit` Live Activity when a workout begins. Pushes `WorkoutLiveActivityAttributes.ContentState` updates as HR and elapsed time change.

**Data flow:**

```
beginActivityRecording(activity:, startedAt:)
  → capture.start_session (Rust, on rustStartupQueue)
      creates capture_sessions row in SQLite
  → ble.startMovementHeartRateCapture() (K10 raw motion GATT subscription)
  → Live Activity started via WorkoutLiveActivityController

BLE K10 motion packets arriving
  → Normal parse/write path (Mode 1)
  → ActiveActivityPersistence.importedFrameCount incremented

finishActivityRecording(...)
  → capture.finish_session (Rust: marks session ended)
  → activity.create_session (Rust: writes activity_sessions row)
  → appendActivityMetric per metric (duration, distance, hr zones, etc.)
  → ble.stopMovementHeartRateCapture() or stopHealthPacketCapture
  → exitActivityHighFrequencyHistorySyncIfNeeded
  → refreshActivityTimeline (Rust: activity.list_sessions_with_metrics)
  → Live Activity ended
```

**GPS activities:** When `activity.usesGPS == true`, `CoreLocation` provides route points; distance and elevation gain are stored via `appendActivityMetric` with source `ios.core_location`.

**Termination:** User taps "Stop Workout". `finishActivityRecording` writes the completed session to SQLite and stops all associated streams. Auto-detected candidates call `finishAutoDetectedActivityIfActive` when the capture times out.

---

### Mode 4 — Capture Session Mode

**Trigger:** `GooseAppModel.startHealthPacketCapture(mode:duration:source:)` is called. Modes:
- `.walk` — movement/HR stream (K10 raw motion packets).
- `.temperature` — temperature history via historical sync.
- `.physiology` — physiology signal stream (HRV, SpO2, skin temp, respiration).
- `.hrMonitor` — external HR monitor BLE stream (GATT heart rate service).

Also triggered automatically on overnight guard start (`startPhysiologyPacketCapture`) and on WHOOP connection from launch arguments (`autoStartHealthPacketCaptureOnReady`).

**Active components:**
- `ActiveHealthPacketCapture` — value type holding `sessionID`, `startedAt`, `mode`, and `importedFrameCount`.
- `CaptureFrameWriteQueue` — all incoming frames during the session are attributed to the capture session ID.
- Timeout scheduler — `scheduleHealthPacketCaptureTimeout(duration:)` fires on `DispatchQueue.main` and calls `stopHealthPacketCapture(reason: "duration_elapsed")`.
- Stream retry scheduler — if no frames arrive within 8 s, retries the stream subscription up to 12 times.

**Data flow:**

```
startHealthPacketCapture(mode: .physiology, duration: 30*60)
  → Rust: capture.start_session (creates capture_sessions row)
  → ble.startPhysiologySignalCapture() (subscribes to physiology GATT characteristics)
  → optional: scheduleHistoricalSyncForPhysiologyCaptureIfNeeded
      (after 20 s: ble.syncHistoricalPackets if autoSyncHistoryDuringPhysiologyCapture)

BLE packets arriving during capture
  → Normal parse/write path (Mode 1)
  → capture.import_frame_batch attributes frames to the active session ID

stopHealthPacketCapture(reason:)
  → Rust: capture.finish_session (marks session ended, records frame_count)
  → ble.stopPhysiologySignalCapture() / stopMovementHeartRateCapture()
  → publishHealthPacketCaptureUIUpdate, publishPacketImportRevision
```

**Temperature mode specifics:** `.temperature` mode stops the movement stream, waits 0.8 s, then calls `ble.syncHistoricalPackets(rangeFirst: true)` to pull temperature history via the historical sync path.

**Termination:** Timeout elapsed, manual stop, or capture is stopped as a side effect of overnight guard final sync or activity recording finish.

---

### Mode 5 — Historical Sync Mode

**Trigger:** One of several callers:
- `GooseBLEClient.syncHistoricalPackets` — generic one-shot sync.
- `GooseBLEClient.syncHistoricalPacketsPreservingUnreadQueue` — used by overnight guard final sync to preserve the unread queue.
- `GooseBLEClient.pollHistoricalRange` — range-only poll (no data transfer).
- `GooseBLEClient.enterHighFrequencyHistorySync` / `exitHighFrequencyHistorySync` — used during workout recording for higher-cadence history pulls.

Requires `ble.canSyncHistorical == true` (connection ready, command characteristic present, no sync already in progress).

**Active components:**
- `GooseBLEClient.beginHistoricalSync` — owns the state machine: `isHistoricalSyncing`, `historicalSyncStatus`, `historicalPacketCount`, pending command tracking.
- `GooseBLEClient+HistoricalCommands.swift` — writes WHOOP command frames via `writeHistoricalCommand(_:)`.
- `GooseBLEClient+HistoricalHandlers.swift` — handles incoming historical data characteristic notifications; routes to frame parser.

**State machine (Gen5 / GOOSE device):**

```
beginHistoricalSync
  → optional: writeHistoricalCommand(.getDataRange)   [if rangeFirst=true]
      ← WHOOP responds with GET_DATA_RANGE_RESULT notification
  → writeHistoricalCommand(.sendHistoricalData)
      ← WHOOP streams historical data notifications (parsed via NotificationFrameParser)
      ← each parsed frame → CaptureFrameWriteQueue (import_frame_batch)
      ← HISTORY_START notification received (historyStartReceived = true)
      ← HISTORY_END notification → historyEndAckQueued = true
          → writeHistoricalCommand(.historicalDataResult) [ACK payload]
      ← HISTORY_COMPLETE notification
  → completeHistoricalSync(reason: "history_result_ack_sent_after_complete")
  → notifyHistoricalSyncProgress(status: "synced", terminal: true, failed: false)
```

**State machine (Gen4 device):**

```
beginHistoricalSync
  → writeHistoricalCommand(.getDataRange)  [cmd 34, payload 0x00]
      ← Gen4 range response
  → writeHistoricalCommand(.sendHistoricalData)  [cmd 22]
      ← Gen4 streams pages
  → gen4PageRequestPayload loop:  [cmd 23, seq+page_count=16]
      each page batch → parsed → CaptureFrameWriteQueue
  → completeHistoricalSync on final page or HISTORY_COMPLETE
```

**Timeout handling:** Each command write schedules a timeout work item (8 s for debug commands). On timeout, `failHistoricalSync` is called. A single idle-completion retry with `AbortHistoricalTransmits` is scheduled when HISTORY_END is received but HISTORY_COMPLETE does not follow within the idle window.

**Termination:** `completeHistoricalSync` or `failHistoricalSync`. Both set `isHistoricalSyncing = false` and call `notifyHistoricalSyncProgress` with `terminal: true`. Progress is reported back to `GooseAppModel.handleHistoricalSyncProgress`, which routes to overnight guard or capture session handlers as appropriate.

---

### Mode 6 — Debug Session Mode

**Trigger:** `GooseAppModel` calls the Rust bridge method `debug.serve_once` (or via the debug bridge commands exposed in `GooseBLEClient+DebugAndSync.swift`). The WebSocket server is started from within the Rust library, not from Swift.

**Active components:**
- `Rust: debug_ws_server` (`Rust/core/src/debug_ws_server.rs`) — a single-accept TCP listener bound to `127.0.0.1:8765`. Accepts one WebSocket connection, streams debug event envelopes from SQLite, and terminates after the session ends or the idle timeout expires.
- `Rust: debug_ws` (`Rust/core/src/debug_ws.rs`) — protocol types (`DebugCommandEnvelope`, `DebugEventInput`) and SQLite session bookkeeping.
- `GooseBLEClient+DebugAndSync.swift` — exposes Swift-side debug command writes (`writeDebugCommand`, `scheduleDebugCommandTimeout`, `handleDebugCommandValue`). Sequences are in range 120–159; timeouts are 8 s per command.

**Data flow:**

```
Swift: rust.request(method: "debug.serve_once", args: {database_path, session_id, port: 8765, ...})
  → Rust: bind_debug_ws_listener (TcpListener on 127.0.0.1:8765)
  → Rust: accept one WebSocket handshake (token auth on Upgrade header)
  → Rust: poll SQLite for new debug_events rows since last_sequence
  → Send JSON event envelopes over WebSocket at poll_interval_ms
  → Rust: idle_timeout_ms elapsed without new events → completes

GooseBLEClient debug command write (parallel):
  nextDebugSequence() → sequence in [120,159]
  writeValue(commandFrame) to commandCharacteristic
  scheduleDebugCommandTimeout (8 s)
  handleDebugCommandValue on incoming notification → completeDebugCommand
```

**Termination:** The Rust WebSocket server terminates after: (a) the idle timeout (`idle_timeout_ms`) elapses with no new events, (b) `max_events` is reached, (c) the client disconnects, or (d) the bridge call returns an error. The Rust call is synchronous and blocking; it must be dispatched from a background queue.

---

### Mode 7 — Upload Sync Mode

**Trigger:** Three entry points:
- `GooseAppModel.triggerUpload(for:deviceEvent:)` — called automatically after each successful `CaptureFrameWriteQueue` write batch. Uses a 30 s `sinceTimestamp` window.
- `GooseAppModel.triggerManualUpload()` — called from the "Sync Now" button in the More tab. Uses `lastUploadAt` or 24 h ago.
- `GooseAppModel.triggerBackfillAndUpload()` — called from the "Sync pendente" button; runs `sync.backfill_streams` first to populate `hr_samples`/`rr_intervals` from `decoded_frames`, then uploads.

**Prerequisites:** `UserDefaults` key `goose.remote.uploadEnabled == true`, `goose.remote.serverURL` set to a valid URL, Keychain entry `goose.remote / apiKey` present and non-empty.

**Active components:**
- `GooseUploadService` — holds its own `GooseRustBridge` instance and `NSLock`-protected counters (`_pendingBatchCount`, `_lastUploadTimestamp`, `_lastSyncedCount`, `_pendingRowCount`).
- Swift concurrency detached tasks (`Task.detached(priority: .utility)`) — all network and Rust bridge calls run off `@MainActor`.
- `URLSession` (ephemeral, 15 s request timeout) — HTTP client.

**Data flow:**

```
GooseUploadService.upload(deviceID:deviceType:sinceTimestamp:)
  → stateLock: _pendingBatchCount += 1
  → Task.detached { performUpload(...) }

performUpload:
  1. captureAllPendingRowIDs:
       sync.rows_pending_upload (per stream table, limit 500)
       → [String: [Int]] snapshot of pending rowIDs BEFORE HTTP call
  2. upload.get_recent_decoded_streams
       → hr[], rr[], events[], battery[], spo2[], skin_temp[], resp[], gravity[]
  3. buildUploadPayload (device_generation: "5.0" for GOOSE / "4.0" for GEN4 /
       device_type + device_class: "HR_MONITOR" for external HR monitors)
  4. POST /v1/ingest-decoded (Bearer token, application/json)
       → up to 3 attempts: 0s / 1s / 2s / 4s retry
  5. On 2xx: markStreamsSynced (sync.mark_synced per stream)
  6. uploadRawFrames:
       upload.get_raw_frames_for_upload (limit 2000)
       → POST /v1/ingest-frames (Bearer token)
  7. stateLock: _lastUploadTimestamp = Date(), _lastSyncedCount = upserted total
  8. refreshPendingRowCount (sync.rows_pending_upload hr_samples, limit 10,000)
  9. publishStatus → Task { @MainActor in onStatusUpdate?(status) }
```

**Server import (fresh install):** `GooseAppModel.importHistoricalDataFromServer()` runs the reverse direction: fetches device list from `/v1/devices`, pages through `/v1/export/frames/{deviceID}` (5,000 frames/page), calls `Rust: capture.import_frame_batch` for each page (idempotent: deterministic `evidence_id` = `"server-import/<deviceID>/<capturedAtMs>/<hexPrefix8>"`), then calls `sync.backfill_streams` to derive decoded HR/RR streams.

**Termination:** Single-attempt job completes when all retries are exhausted (success or silent failure). `_pendingBatchCount` is decremented on every code path. Rows are never deleted while `synced = 0`; failed uploads are retried on the next trigger.

---

### Mode 8 — Sleep Staging / Overnight Recovery Analysis

**Trigger:** `GooseAppModel.maybeScheduleMorningSleepSync()` — called from `handleBLEConnectionStateChange` when state transitions to `"ready"` and `overnightGuardActive == false`. Fires once per calendar day after 04:00 local time (guarded by `UserDefaults: goose.swift.last_band_sleep_sync_date`).

**Active components:**
- `GooseAppModel.syncBandSleepHistory()` — async function running in a detached `Task` context. Owns a local `GooseRustBridge` instance (separate from `GooseAppModel.rust` to avoid data races).
- `HealthDataStore` — `markBandSleepSyncRequested` / `markBandSleepSyncFailed` / `refreshSleepAfterBandSync` update UI state on `@MainActor`.
- `Rust: sleep_staging` (`Rust/core/src/sleep_staging.rs`) — pure, no DB access. Implements Cole-Kripke (1992) binary wake/sleep classification extended to 4-class (wake/light/deep/REM) using HR + motion features.

**Algorithm constants:**
- `COLE_KRIPKE_EPOCH_MINUTES = 0.5` (30 s epochs; matches my-whoop reference and AASM standard)
- `COLE_KRIPKE_SCALE_FACTOR = 0.001` (raw g-unit magnitude → activity index)
- `COLE_KRIPKE_WAKE_THRESHOLD = 1.0`
- `DEEP_HR_PERCENTILE = 0.25` (p25 personal HR percentile → candidate deep)
- `DEEP_STILLNESS_ACTIVITY_MAX = 0.05`
- `REM_CLOCK_PROXY_MIN = 0.4` (first 40% of night is non-REM territory)
- `NO_REM_ONSET_MINUTES = 15.0` (no-REM onset guard)

**Data flow:**

```
maybeScheduleMorningSleepSync()  [on BLE connection ready, after 04:00]
  → UserDefaults.set(Date(), forKey: last_band_sleep_sync_date)  [written first, before any await]
  → store.gravity_rows_between(overnight_window: yesterday 20:00 – today 12:00)
      → if gravityCount >= 100: skip BLE sync (sufficient local data)
      → if gravityCount < 100:
          ble.syncHistoricalPackets(rangeFirst: true)  [triggers Mode 5]
          poll ble.historicalSyncStatus (1 s intervals, max 120 attempts)
          wait for "synced" or fail
  → metrics.sleep_staging(device_id, sleep_start_ts, sleep_end_ts)
      → Rust reads gravity rows from SQLite
      → Cole-Kripke epoch classification
      → 4-class refinement (deep: low HR p25 + near-zero motion; REM: clock proxy >= 0.4 + not near onset)
      → returns staging_method, stage_minutes (BTreeMap<String, f64>), epochs[]
  → if staging_method == "no_imu_data": early exit (sets "A aguardar sincronização")
  → bandSleepId = "band_ble.<deviceId>.<yyyy-MM-dd>"  [deterministic, prevents duplicates]
  → sleep.import_external_history(sessions: [{sleep_id, source: "band_ble", stage_summary, ...}])
      [idempotent: UNIQUE ON (platform, platform_record_id) → ON CONFLICT DO NOTHING]
  → HealthDataStore.refreshSleepAfterBandSync
  → bandSleepImportStatus = "Sincronizado da pulseira"
```

**Overnight window:** yesterday 20:00 local → today 12:00 local (16-hour window; covers all typical sleep patterns).

**Termination:** Single async function; completes when staging and import succeed, or on any error (BLE sync failure, staging error, bridge error). The `last_band_sleep_sync_date` UserDefaults key prevents re-entry for the rest of the calendar day.

---

## Data Flow

### Primary real-time BLE → SQLite path

1. **GooseBLEClient** receives raw BLE characteristic notification bytes on its `notificationIngestQueue`. The `onNotification` callback is set by `GooseAppModel`.
2. **GooseAppModel.handleNotification** dispatches work to `notificationIngestQueue`. `NotificationFrameParser` calls the Rust bridge (`GooseRustBridge`) to reassemble multi-packet frames via `protocol.parse_frame_hex`.
3. Parsed frames are handed to **CaptureFrameWriteQueue**, which batches rows and calls the Rust bridge method `capture.import_frame_batch` on its own dedicated queue. Rust writes decoded samples to `goose.sqlite` at `ApplicationSupport/GooseSwift/goose.sqlite`.
4. When a write batch succeeds, `GooseAppModel.triggerUpload` is called, which dispatches `GooseUploadService.upload` on Swift concurrency detached tasks.

### Upload path (iOS → server)

1. **GooseUploadService** runs entirely on Swift concurrency detached tasks (`Task.detached(priority: .utility)`) — never on `@MainActor`.
2. It calls the Rust bridge method `upload.get_recent_decoded_streams` to fetch decoded biometric streams from SQLite. After a successful POST, it calls `sync.rows_pending_upload` to locate the `hr_samples` row IDs that were included, then `sync.mark_synced` to set `synced = 1` on those rows.
3. It POSTs a `DecodedBatch` JSON payload to `POST /v1/ingest-decoded` with a `Bearer` token loaded from the iOS Keychain (`RemoteServerKeychain`, service: `goose.remote`, account: `apiKey`). The server URL is stored in `UserDefaults` under the key `goose.remote.serverURL`.
4. After decoded stream upload succeeds, `GooseUploadService` also calls `upload.get_raw_frames_for_upload` and attempts to POST raw BLE frames to `POST /v1/ingest-frames`.
5. Retry logic: up to 3 attempts with 1 s / 2 s / 4 s backoff. Silent failure after 3 attempts — raw data is already in local SQLite and will be retried next trigger.
6. Upload status (`lastUploadAt`, `pendingBatchCount`) is published back to `@MainActor` via `Task { @MainActor in ... }`.

### Metric score path (on-demand)

`HealthDataStore` (a `@MainActor @Observable` class) holds its own `GooseRustBridge` instance. It queries Rust `metrics.*` methods via Swift concurrency (`bridge.requestAsync`) on cooperative Task threads, then publishes results as observable properties consumed by SwiftUI views.

### Exercise detection path

`exercise.detect_sessions` is dispatched through the Rust bridge. It accepts a time-windowed array of HR samples and gravity rows from `gravity2_samples`, applies a dual-gate filter (HR above resting HR margin AND smoothed accelerometer magnitude above motion threshold), groups contiguous active pairs into sessions, and computes per-session metrics: strain, calories (Keytel active EE + resting EE), heart rate zones (Edwards 5-zone based on HRR%), and zone time percentages.

### Server daily analysis path

When `POST /v1/ingest-decoded` is received, the server calls `daily.compute_day` for each calendar day touched by the batch (throttled: at most once per device/day per 120 s; single-flight). `compute_day` reads the raw stream hypertables, runs the sleep → recovery → strain → exercise pipeline (modules in `server/ingest/app/analysis/`), and persists results idempotently to `sleep_sessions`, `exercise_sessions`, and `daily_metrics`.

---

## Key Abstractions

| Abstraction | File | Description |
|---|---|---|
| `GooseAppModel` | `GooseSwift/GooseAppModel.swift` + `GooseAppModel+*.swift` | Central `@MainActor` coordinator; owns BLE client, Rust bridge, all notification queues, upload service. Split across 9 extension files by concern. |
| `GooseBLEClient` | `GooseSwift/GooseBLEClient.swift` + `GooseBLEClient+*.swift` | CoreBluetooth central manager; WHOOP GATT connection and proprietary frame framing; command writes. Split across 11 extension files. |
| `GooseRustBridge` | `GooseSwift/GooseRustBridge.swift` | JSON-RPC envelope over `goose_bridge_handle_json` / `goose_bridge_free_string` (C FFI). Schema: `goose.bridge.request.v1`. Stateless — multiple instances are normal. |
| `HealthDataStore` | `GooseSwift/HealthDataStore.swift` + `HealthDataStore+*.swift` | `@MainActor @Observable` metric query layer. Holds its own `GooseRustBridge`; publishes scored health metrics to SwiftUI views as observable properties. |
| `GooseUploadService` | `GooseSwift/GooseUploadService.swift` | Fetches pending-upload rows from Rust (`upload.get_recent_decoded_streams`), POSTs to `POST /v1/ingest-decoded`, then marks stream rows synced via `sync.rows_pending_upload` + `sync.mark_synced`. Runs on Swift concurrency detached tasks; never touches `@MainActor` inline. |
| `CaptureFrameWriteQueue` | `GooseSwift/CaptureFrameWriteQueue.swift` | Batches parsed BLE frames and writes them to SQLite via Rust bridge `capture.import_frame_batch`. |
| `NotificationFrameParser` | `GooseSwift/NotificationFrameParsing.swift` | Delegates raw BLE bytes to Rust for frame reassembly and compact summary extraction. |
| `OvernightSQLiteMirrorQueue` | `GooseSwift/OvernightSQLiteMirrorQueue.swift` | During overnight guard mode, queues raw notification rows for Rust bridge SQLite insert (flush every 2 s, batch limit 256, max 4096 queued rows). |
| Rust core (`libgoose_core.a`) | `Rust/core/src/bridge.rs` | 148 dispatched methods: protocol parsing, SQLite persistence, metric algorithms, BLE frame import, exercise detection, upload sync, export. Entry point: `bridge.rs`. |
| FastAPI ingest service | `server/ingest/app/main.py` | Bearer-gated REST API: `POST /v1/ingest-decoded`, read endpoints, daily compute. No OpenAPI schema exposed publicly (`docs_url=None`). |

---

## Rust Core Modules

The Rust library (`Rust/core/src/`) is compiled to `libgoose_core.a` and linked into the iOS app via a C FFI pair. Key modules:

| Module | File | Responsibility |
|---|---|---|
| `bridge` | `bridge.rs` | FFI dispatch table; routes JSON `method` strings to internal functions; 148 methods |
| `protocol` | `protocol.rs` | WHOOP BLE frame parsing; packet reassembly; V24 biometric decode tables |
| `store` | `store.rs` | SQLite schema (v21); all persistence helpers; `synced` flag management; `V24BiometricBatch` decode |
| `metrics` | `metrics.rs` | Health algorithm implementations (HRV, recovery, strain scores) |
| `metric_features` | `metric_features.rs` | Feature extraction layer used by `metrics` |
| `metric_readiness` | `metric_readiness.rs` | Per-metric readiness and availability checks |
| `sleep_staging` | `sleep_staging.rs` | Cole-Kripke actigraphy + HR-aided sleep staging; AASM-compatible epoch classification |
| `sleep_validation` | `sleep_validation.rs` | Sleep window and stage label validation |
| `exercise_detection` | `exercise_detection.rs` | Dual-gate (HR + motion) exercise session detection; Edwards 5-zone intensity; Keytel calorie estimation |
| `energy_rollup` | `energy_rollup.rs` | Daily/hourly active and resting energy rollup; Mifflin-St Jeor RMR; Harris-Benedict RMR |
| `recovery_rollup` | `recovery_rollup.rs` | Daily recovery metric rollup |
| `baselines` | `baselines.rs` | EWMA personal baselines (HRV RMSSD, resting HR); cold-start guard; trust levels |
| `step_counter` | `step_counter.rs` | Step count ingestion and daily/hourly rollup |
| `step_discovery` | `step_discovery.rs` | Step packet discovery from raw BLE capture |
| `step_motion_estimator` | `step_motion_estimator.rs` | Motion-based step estimation |
| `activity_sessions` | `activity_sessions.rs` | Activity session persistence and querying |
| `capture_import` | `capture_import.rs` | Batch BLE frame import pipeline |
| `capture_correlation` | `capture_correlation.rs` | Correlation analysis for captured frame sequences |
| `capture_sanitize` | `capture_sanitize.rs` | Sanitisation of raw capture data for export |
| `commands` | `commands.rs` | WHOOP command definitions and validation evidence |
| `health_sync` | `health_sync.rs` | HealthKit sync dry-run and activity sync |
| `historical_sync` | `historical_sync.rs` | WHOOP Gen4/Gen5 historical data sync state machine (dry-run planning) |
| `timeline` | `timeline.rs` | Decoded frame timeline reconstruction |
| `export` | `export.rs` | ZIP/CSV export of raw frames and decoded streams |
| `debug_ws_server` | `debug_ws_server.rs` | Local WebSocket debug server (`ws://127.0.0.1:8765`); single-accept, token-gated |
| `debug_ws` | `debug_ws.rs` | WebSocket protocol types and session bookkeeping |

---

## SQLite Schema (v21)

The embedded SQLite database at `ApplicationSupport/GooseSwift/goose.sqlite` is managed by the Rust core. Schema version is declared as `CURRENT_SCHEMA_VERSION = 21` in `store.rs`.

Stream tables with `synced` flag (used by the upload pipeline — membership enforced by `STREAM_ALLOWLIST` in `store.rs`):

| Table | Content | Synced flag |
|---|---|---|
| `battery` | Battery level samples | Yes |
| `events` | WHOOP event packets | Yes |
| `exercise_sessions` | Detected exercise sessions | Yes |
| `gravity` | Raw gravity (legacy) | Yes |
| `gravity2_samples` | Accelerometer XYZ from V24 frames | Yes |
| `hr_samples` | Heart rate BPM samples | Yes |
| `resp_samples` | Respiration rate (V24 decode) | Yes |
| `rr_intervals` | R-R interval data | Yes |
| `skin_temp_samples` | Skin temperature delta (V24 decode) | Yes |
| `spo2_samples` | SpO2 (V24 decode) | Yes |

The `synced` column (default `0`) is used by the upload pipeline: `upload.get_recent_decoded_streams` reads rows for the `since_ts` window; `sync.rows_pending_upload` returns pending row IDs per stream; `sync.mark_synced` sets `synced = 1` on those row IDs after a confirmed server POST. Pruning (`prune_synced_stream_rows`) only removes rows where `synced = 1`. Tables that did not have a `synced` column at creation receive it via the `ensure_synced_columns` migration.

`V24BiometricBatch` (`store.rs`) is the Rust struct that groups raw V24 decode fields (SpO2 photodiode counts, skin temp raw ADC, respiration raw ADC) before they are written to their respective tables.

---

## Directory Structure

```
goose/
├── GooseSwift/                 iOS app source (Swift/SwiftUI, iOS 26.0)
│   ├── GooseAppModel*.swift    Central coordinator + 9 extension files
│   ├── GooseBLEClient*.swift   CoreBluetooth + WHOOP protocol (11 extension files)
│   ├── GooseRustBridge.swift   C FFI bridge (JSON-RPC)
│   ├── HealthDataStore*.swift  Metric query layer (@MainActor @Observable)
│   ├── GooseUploadService.swift Server upload (detached tasks, synced-flag aware)
│   ├── OvernightSQLiteMirrorQueue.swift  Overnight guard SQLite mirror
│   └── *Views.swift / *Screen.swift  SwiftUI UI
├── GooseWorkoutLiveActivityExtension/
│   └── GooseWorkoutLiveActivityWidget.swift  ActivityKit / Dynamic Island
├── Rust/core/src/              Rust library (libgoose_core)
│   ├── bridge.rs               FFI dispatch table (148 methods)
│   ├── protocol.rs             WHOOP BLE frame parsing + V24 decode tables
│   ├── store.rs                SQLite schema v21 + synced-flag helpers
│   ├── metrics.rs              Health algorithm implementations
│   ├── metric_features.rs      Feature extraction
│   ├── sleep_staging.rs        Cole-Kripke actigraphy + sleep staging
│   ├── exercise_detection.rs   Dual-gate exercise detection + calorie estimation
│   ├── energy_rollup.rs        Daily/hourly energy rollup (Keytel, Mifflin-St Jeor)
│   ├── baselines.rs            EWMA personal baselines (HRV, RHR)
│   ├── debug_ws_server.rs      Local WebSocket debug server (ws://127.0.0.1:8765)
│   └── ...                     40+ additional modules
├── server/
│   ├── ingest/app/             FastAPI ingest service
│   │   ├── main.py             Route definitions
│   │   ├── ingest.py           Raw-frame batch pipeline
│   │   ├── store.py            Idempotent DB upserts
│   │   ├── read.py             Read queries
│   │   └── analysis/           Daily pipeline (sleep/recovery/strain/exercise)
│   ├── db/init.sql             TimescaleDB schema (hypertables)
│   └── docker-compose.yml      goose-db + goose-ingest services
├── Scripts/build_ios_rust.sh   Cross-compile Rust → iOS static libs
└── GooseSwift.xcodeproj        Xcode project (iOS 26.0 deployment target)
```

---

## Threading Model

| Thread / Queue | Owner | Used For |
|---|---|---|
| `@MainActor` (main thread) | Swift runtime | All `@Observable` state mutations, SwiftUI rendering, `GooseAppModel` and `HealthDataStore` methods |
| `com.goose.swift.notification-ingest` | `GooseAppModel` | Initial BLE notification receipt and frame boundary detection |
| `com.goose.swift.notification-parse` | `GooseAppModel` | Rust frame parsing calls (blocking FFI) |
| `com.goose.swift.capture-frame-row-build` | `GooseAppModel` | Building SQLite row structs from parsed frames |
| `com.goose.swift.capture-frame-enqueue` | `CaptureFrameWriteQueue` | Enqueue gate for incoming frame batches (qos: .utility) |
| `com.goose.swift.capture-frame-writes` | `CaptureFrameWriteQueue` | Actual SQLite write calls via Rust bridge (qos: .utility) |
| `com.goose.swift.rust-startup` | `GooseAppModel` | Rust bridge initialisation and crash recovery on app launch |
| `com.goose.swift.activity-timeline-refresh` | `GooseAppModel` | Activity timeline query calls to Rust bridge |
| `com.goose.swift.overnight-sqlite-mirror` | `OvernightSQLiteMirrorQueue` | Batched SQLite inserts of overnight raw notifications (qos: .utility) |
| `com.goose.swift.overnight-raw-spool` | `OvernightRawNotificationSpool` | JSONL file appends for overnight guard spool (qos: .utility) |
| `com.goose.swift.corebluetooth` | `GooseBLEClient` | CoreBluetooth central manager queue |
| `com.goose.swift.realtime-vitals` | `GooseBLEClient` | Real-time vitals processing (qos: .userInitiated) |
| `com.goose.swift.historical-write` | `GooseBLEClient` | Historical sync write operations (qos: .utility) |
| Swift concurrency detached task (`.utility`) | `GooseUploadService` | Rust bridge `upload.get_recent_decoded_streams` + HTTP upload + `sync.mark_synced` |
| Swift concurrency `Task` (cooperative pool) | `HealthDataStore` | Metric score queries via `bridge.requestAsync`; heart rate timeline refresh |
| `CBCentralManager` queue | CoreBluetooth | BLE delegate callbacks from `GooseBLEClient` |

**Critical constraint:** `GooseRustBridge.request(...)` is a blocking synchronous call (it calls `goose_bridge_handle_json` via C FFI and waits for a response). It must never be called from `@MainActor` inline for any expensive method. Always dispatch to a background queue first.

---

## Persistence Boundaries

| Store | Location | Owner | Contains |
|---|---|---|---|
| `goose.sqlite` (schema v21) | `ApplicationSupport/GooseSwift/goose.sqlite` | Rust core (via `rusqlite`) | All captured BLE frames, decoded biometric samples (including V24 streams and gravity2_samples), metric scores, activity sessions, synced flags |
| Overnight guard spool | `ApplicationSupport/GooseSwift/overnight-guard/<sessionID>/` | `OvernightRawNotificationSpool` | JSONL files: raw notifications, command writes, range telemetry, event log, status snapshots |
| `UserDefaults` | iOS system | Swift | Onboarding state, device identity, HR estimates, server URL (`goose.remote.serverURL`), upload enabled flag (`goose.remote.uploadEnabled`), last band sleep sync date |
| iOS Keychain | iOS system | `RemoteServerKeychain` | Server API token (service: `goose.remote`, account: `apiKey`) |
| TimescaleDB | Docker volume `goose-db-data` | Server | Hypertables for HR, RR, events, battery, SpO2, skin temp, respiration, gravity; derived tables for sleep/exercise/daily metrics |
| Raw frame archive | Docker volume `goose-raw-data` (`/data/raw`) | Server | Archived raw BLE frame batches (hex, by device/date) |

---

## Server API Summary

All `/v1` routes require `Authorization: Bearer <GOOSE_API_KEY>`. The OpenAPI schema is intentionally disabled (`docs_url=None`, `redoc_url=None`, `openapi_url=None`) to avoid advertising the API surface publicly.

| Method | Path | Description |
|---|---|---|
| `GET` | `/healthz` | DB connectivity check (no auth required) |
| `POST` | `/v1/ingest-decoded` | Ingest a decoded biometric stream batch from the iOS app |
| `POST` | `/v1/ingest` | Ingest a raw BLE frame batch (legacy / reference) |
| `POST` | `/v1/ingest-frames` | Ingest raw BLE frames for trust-chain reconstruction |
| `GET` | `/v1/devices` | List known devices |
| `GET` | `/v1/export/frames/{device_id}` | Page through raw BLE frames for server import flow |
| `GET` | `/v1/streams/{kind}` | Query a decoded stream (hr, rr, events, battery, spo2, skin_temp, resp, gravity) |
| `GET` | `/v1/batches` | List raw batch records for a device |
| `GET` | `/v1/batches/{batch_id}/frames` | Retrieve raw BLE frames for a specific batch |
| `GET` | `/v1/summary` | Stream row counts for a device/time range |
| `GET` | `/v1/daily` | Daily metric rows for a date range |
| `GET` | `/v1/today` | Most recent daily metric row for a device |
| `GET` | `/v1/sleep` | Sleep sessions for a date |
| `GET` | `/v1/workouts` | Exercise sessions for a date range |
| `POST` | `/v1/compute-daily` | Force recompute daily metrics for a device/date |
| `POST` | `/v1/backfill-workouts` | Recompute exercise sessions over a date range |
| `GET` | `/v1/profile` | Retrieve user profile (height/weight/age/sex) |
| `POST` | `/v1/profile` | Create or update user profile |
| `GET` | `/` | Static dashboard SPA |
| `GET` | `/architecture` | Static architecture page (no auth required) |

---

## Architectural Constraints

- **Rust bridge is synchronous.** `goose_bridge_handle_json` blocks the calling thread. All bridge calls for expensive operations (capture import, metric computation, upload fetch) must happen on a background `DispatchQueue`.
- **Multiple bridge instances are intentional.** `GooseAppModel`, `HealthDataStore`, `OvernightSQLiteMirrorQueue`, `CaptureFrameWriteQueue`, and `GooseUploadService` each hold their own `GooseRustBridge` instance. The Rust library is stateless across calls; state lives in SQLite.
- **Database path convention.** The SQLite file is always resolved via `HealthDataStore.defaultDatabasePath()`. Every bridge call that accesses storage must pass `database_path` in its args.
- **Upload is opt-in.** `GooseUploadService` checks `UserDefaults` key `goose.remote.uploadEnabled` before every upload attempt. An unconfigured or disabled server URL results in a silent no-op — local SQLite is unaffected.
- **Synced flag is the upload cursor.** The `synced` INTEGER column (default `0`) on stream tables is the source of truth for upload state. Only tables in `STREAM_ALLOWLIST` (`store.rs`) are eligible for synced-flag operations. Rows are never deleted while `synced = 0` regardless of age; only `synced = 1` rows are eligible for pruning.
- **Server ingest is idempotent.** All `store.upsert_*` calls use `ON CONFLICT DO UPDATE` or `DO NOTHING`. The iOS app may upload the same window multiple times; the server deduplicates by `(device_id, ts)` primary keys on each hypertable.
- **Overnight guard rowID pre-capture prevents upload race.** `GooseUploadService.captureAllPendingRowIDs` snapshots pending row IDs before the HTTP call. `markStreamsSynced` is called only inside the `uploadSucceeded == true` branch, eliminating the race where rows arriving during an upload would be incorrectly marked synced.
- **Sleep sync fires at most once per calendar day.** `UserDefaults: goose.swift.last_band_sleep_sync_date` is written before any async work to prevent retry loops on drop-and-reconnect.
- **No circular imports.** The `GooseWorkoutLiveActivityExtension` target shares only `WorkoutLiveActivityAttributes.swift` with the main app. It has no access to `GooseAppModel`, `GooseRustBridge`, or any SQLite layer.
- **iOS deployment target: 26.0.** All Swift source targets `IPHONEOS_DEPLOYMENT_TARGET = 26.0` as set in `GooseSwift.xcodeproj/project.pbxproj`. App marketing version is `0.1.0`.
