# Goose Swift MVP: More

Source map: Flutter `SettingsView`, `DeviceView`, `CaptureView`, `DebugView`, Swift `MorePlaceholderView`, Swift `DeviceView`, Swift `ConnectionView`.

MVP rule: More owns operational surfaces: device, connection lab, capture/import, Health sync, raw export, algorithm settings, storage, debug, privacy, and support. It should be dense, inspectable, and honest about readiness.

## Parent View Contract

- [x] Create a dedicated `MoreView.swift` — implemented.
- [x] Keep this tab behind the Swift `More` tab item.
- [x] Define child routes: Device, Connection Lab, Capture, Debug, Local Store, Health Sync, Raw Export, Algorithms, Privacy, Support/About — all confirmed in `MoreRouteModels.swift` and `MoreView.swift`.
- [x] Keep operational rows compact and list-based.
- [x] Add status badges for ready, pending, blocked, unavailable, stale — `MoreStatusKind` enum with colour mapping.
- [ ] Add previews for default, connected, and debug-heavy states.

## Device

- [x] Keep current Swift `DeviceView` as the primary Device route.
- [x] Show status and advanced panels — "ADVANCED" tab in `DeviceView`.
- [x] Keep WHOOP image asset in Swift asset catalog.
- [x] Show live device name, connection, battery, firmware, model, last sync — battery at `ble.batteryLevelPercent`, lastSync via `relativeSummary`.
- [x] Show live HR, Rust status, last parsed frame summary.
- [x] Show actions: Bluetooth, scan, connect, reconnect, send hello, forget.
- [x] Show discovered devices list.
- [x] Show recent event log.
- [x] Ensure all copy is backed by `GooseBLEClient` or marked unavailable.

## Connection Lab

- [x] Keep existing `ConnectionView` as a lab/debug route, not the primary user device view.
- [x] Show Bluetooth state — `ble.bluetoothState.localizedBluetoothState`.
- [x] Show connection state — `ble.connectionState.localizedConnectionState`.
- [x] Show reconnect state — `ble.reconnectState.localizedReconnectState`.
- [x] Show remembered device.
- [x] Show live HR source/update.
- [x] Show Rust and client hello summaries.
- [x] Show discovered devices and event log.
- [x] Keep command actions available for debugging.

## Capture

- [x] Port capture/import surface from Flutter `CaptureView` — `MoreCaptureView` implemented.
- [x] Show capture session summary from `captureSessionSummary()`.
- [x] Show live notification capture summary from `liveNotificationCaptureSummary()`.
- [ ] Show selected discovered device.
- [x] Show recent notifications/events.
- [x] Add actions for starting/stopping capture — Start/Stop Capture button with session state.
- [ ] Add import capture file action — present as a row but marked disabled.
- [ ] Add import command evidence file action.
- [ ] Add import emulator log action.
- [x] Add local frame match action — present in `MoreCaptureView` (disabled pending implementation).
- [ ] Add validated sample/read command action.

## Local Store

- [x] Show SQLite/local store path — `store.databasePath` in `MoreLocalStoreView`.
- [x] Show storage check status from `storageCheckStatusSummary()`.
- [x] Show schema version.
- [x] Show storage next action from `storageCheckNextActionSummary()`.
- [x] Add Check action once Swift bridge supports storage check — `runStorageCheck()` button, disabled when no database.
- [x] Add empty state for no database yet — explicit "No Database Yet" section.

## Health Sync

- [x] Show backfill window from `healthSyncBackfillWindowSummary()`.
- [x] Show backfill validation issue from `healthSyncBackfillWindowIssueSummary()`.
- [ ] Add editable backfill start/end fields.
- [x] Show selected metric families from `healthSyncMetricFamilySummary()`.
- [x] Add family toggles: heart_rate, resting_heart_rate, hrv, steps, activity — `Toggle` per family in `MoreHealthSyncView`.
- [x] Show metric source rows via `healthSyncMetricSourceSummary(family)`.
- [x] Show unavailable families — `unavailableHealthSyncMetricSummary()` wired into `MoreCaptureViews`.
- [x] Show Health adapter availability.
- [x] Show Health authorization state.
- [ ] Show existing Goose records.
- [x] Show platform sleep imports only as reference/quarantined evidence.
- [x] Add Apple Health dry run action only for outbound/profile-boundary audits.
- [ ] Add Health Connect dry run action — iOS only; not applicable.
- [x] Add refresh Health adapter action.
- [x] Show platform reports from `healthSyncReports`.

## Raw Export

- [x] Show export window from `rawExportWindowSummary()`.
- [x] Show export window issues from `rawExportWindowIssueSummary()`.
- [x] Show export scope from `rawExportScopeSummary()`.
- [x] Add editable fields: start, end — `TextField` for `rawExportStart` / `rawExportEnd`.
- [ ] Add editable fields: capture sessions, packet types, sensor signals, metric families, algorithm ids, algorithm versions.
- [x] Add raw bytes toggle — `selectedRawFamilies` includes raw family selection.
- [ ] Add data family chips: raw_evidence, decoded_frames, packet_timeline, metric_inputs, algorithm_runs, calibration_labels, calibration_runs, sqlite — `selectedRawFamilies` exists but named chip UI not confirmed.
- [ ] Show recent capture sessions as shortcut rows for the export window.
- [x] Add Export action — export button, disabled when `!store.canRunRawExport`.
- [x] Show bundle path, zip path — `store.rawBundlePath` checked in button disabled state.
- [x] Show export status — `store.rawExportStatus` in `MoreInfoRow`.
- [x] Show privacy lint status — `store.privacyLintStatus`.
- [ ] Show bundle validation, zip validation, sanitized privacy statuses.

## Algorithms

- [x] Show algorithm preference picker per family — `Picker` per family in `MoreAlgorithmsView`.
- [x] Add "Defaults" action from `applyRecommendedAlgorithmDefaults()`.
- [x] Show reference benchmark details per family — Section "Reference Benchmarks" with `referenceDefinitions`.
- [x] Link to Health > Algorithms for deeper metric context — "Open Health > Algorithms" button.
- [x] Keep operational setting here and metric explanation in Health — boundary stated in view.

## Debug

- [x] Port `DebugView` as an explicit route — `MoreDebugView` implemented.
- [x] Show Rust bridge/core version.
- [x] Show frame CRC status — `store.frameCRCStatus`.
- [x] Show frame warnings — `store.frameWarningsStatus`.
- [ ] Show frame parse status, payload — not explicitly surfaced.
- [x] Show debug WebSocket status and next action — `store.debugWebSocketStatus`.
- [ ] Show UI coverage status and deferred surfaces.
- [ ] Show property suite and perf budget status.
- [ ] Show command evidence import/gate sweep/capture plan.
- [x] Show command shortcuts grouped by identity, battery, historical sync, haptics, sensors, config, firmware, reboot — `store.commandGroups` with `ForEach`.
- [x] Keep destructive commands gated behind explicit confirmation — `showDestructiveConfirmation` flag.

## Privacy And Support

- [x] Add Privacy route with local-data/export/privacy-lint summaries — `MorePrivacyView`.
- [x] Add Support route with logs/export bundle paths — `MoreSupportView`.
- [x] Add About route with app version, Rust core version, and license placeholders — `MoreAboutView` (implied via `supportRoutes`).
- [ ] Add data deletion/export links when implemented.

## Parallel Agent Tasks

- [x] Agent More-A: Extract More tab and build route list.
- [x] Agent More-B: Finalize Device route and Connection Lab split.
- [x] Agent More-C: Implement Capture route.
- [x] Agent More-D: Implement Local Store and Health Sync.
- [x] Agent More-E: Implement Raw Export.
- [x] Agent More-F: Implement Algorithms settings.
- [x] Agent More-G: Implement Debug route and command groups.
- [x] Agent More-H: Implement Privacy, Support, About.
- [ ] Agent More-I: Add previews and simulator screenshot verification.

## Acceptance Checks

- [x] More can be worked on without changing Home/Health/Coach code.
- [x] Device route continues to update live BLE state.
- [x] Every operational action is disabled unless its backing bridge exists and inputs are valid.
- [x] Raw export and Health sync clearly show pending/unavailable states.
- [x] Debug/destructive commands are not reachable by accidental taps — confirmation gate in place.
