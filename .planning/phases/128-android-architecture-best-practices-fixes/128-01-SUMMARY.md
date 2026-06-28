---
phase: 128-android-architecture-best-practices-fixes
plan: "01"
subsystem: android-ble
status: complete
tags: [android, ble, coroutines, thread-safety, atomics, sharedflow]
completed: 2026-06-28

dependency_graph:
  requires: []
  provides: [syncCompleteEvent-SharedFlow, atomic-gatt, atomic-syncInProgress]
  affects: [128-02-AppViewModel]

tech_stack:
  added: []
  patterns:
    - AtomicBoolean/AtomicReference for lock-free BLE callback thread safety
    - "@Volatile var scope with rebuild-on-reconnect pattern"
    - MutableSharedFlow fire-and-forget (replay=0, extraBufferCapacity=1, DROP_OLDEST)
    - safeHandle response inspection with org.json.JSONObject parse + Log.e

key_files:
  modified:
    - android/app/src/main/kotlin/com/goose/app/ble/WhoopBleClient.kt

decisions:
  - AtomicBoolean chosen over kotlinx.coroutines Mutex for syncInProgress because BLE callbacks are non-suspend — Mutex.withLock is suspend-only and cannot be called from callback thread (cross-AI review HIGH-2)
  - "@Volatile private var scope required so BLE callback thread sees scope reassignment without stale cache (cross-AI review HIGH-1)"
  - onSyncComplete kept as @Deprecated no-op stub so wave-1 compiles independently; deleted with AppViewModel assignment in plan 128-02 (cross-AI review HIGH-3)
  - scope.cancel() in disconnect() only — not on transient GATT disconnects with willReconnect=true; reconnectJob?.cancel() in connect() prevents reconnect coroutine leak (Codex MEDIUM confirmed non-issue)

metrics:
  duration: "4 min"
  completed: 2026-06-28
---

# Phase 128 Plan 01: WhoopBleClient BLE/Coroutine Fixes Summary

WhoopBleClient refactored to fix four audit findings: cancellable @Volatile var scope with ViewModel-bound lifetime, lock-free AtomicBoolean/AtomicReference replacing raw boolean/pointer fields, SharedFlow sync-complete signal replacing callback reference cycle, and importFrame bridge error propagation via Log.e.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Scope lifecycle + SharedFlow sync-complete signal | c43e7f3 | WhoopBleClient.kt |
| 2 | Atomic sync/gatt state + importFrame error propagation | c43e7f3 | WhoopBleClient.kt |

Both tasks committed together in a single atomic commit (c43e7f3) since they both modify WhoopBleClient.kt exclusively and have no ordering dependency between them.

## What Was Done

### Task 1: Scope lifecycle (A-01) + SharedFlow (A-07)

**D-01 — Scope lifecycle:**
- `private val scope` → `@Volatile private var scope`; `@Volatile` is required because scope is written on the main/caller thread and read on the BLE callback thread via `scope.launch`; without it the JVM permits the BLE thread to cache a stale, cancelled scope reference.
- `scope.cancel()` added to `disconnect()` after `gatt.get()?.disconnect()` — WhoopBleClient-owned scope tears down on explicit disconnect.
- `connect()` guards against reuse of a cancelled scope: `if (!scope.isActive) scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)` before any other connect work.
- Scope is NOT cancelled on transient GATT disconnects (willReconnect=true) — the reconnect coroutine and idle-timeout coroutine both run on this scope. The existing `reconnectJob?.cancel()` in `connect()` prevents any leak from a prior reconnect coroutine on the pre-rebuild scope.
- `AppViewModel.onCleared()` already calls `bleClient.disconnect()`, so the lifecycle-bound invariant is satisfied transitively even on abnormal ViewModel teardown. Codex MEDIUM on scope ownership is resolved — no additional wiring needed.

**D-07 — SharedFlow sync-complete signal:**
- Added `private val _syncCompleteEvent = MutableSharedFlow<Unit>(replay=0, extraBufferCapacity=1, onBufferOverflow=DROP_OLDEST)` and exposed `val syncCompleteEvent: SharedFlow<Unit>`.
- `completeSyncIfActive()` now calls `_syncCompleteEvent.tryEmit(Unit)` — non-suspending, safe from BLE callback thread; DROP_OLDEST ensures it never blocks even if collector is slow.
- `onSyncComplete: (() -> Unit)?` retained as `@Deprecated("Use syncCompleteEvent; removed in plan 128-02") var onSyncComplete: (() -> Unit)? = null` — never invoked; exists only so `AppViewModel.kt:46` compiles in wave-1 isolation. Plan 128-02 removes both the stub and the AppViewModel assignment.

### Task 2: Atomic state (A-02) + importFrame error propagation (A-03)

**D-02 — Atomic thread safety:**
- `@Volatile private var syncInProgress: Boolean = false` → `private val syncInProgress = AtomicBoolean(false)`.
  - `startHistoricalSync()`: `if (!syncInProgress.compareAndSet(false, true))` — single atomic guard, no torn read/write window.
  - `completeSyncIfActive()`: `if (!syncInProgress.compareAndSet(true, false)) return` — atomic and idempotent.
  - All other reads: `.get()`; `onGattDisconnected` reset: `.set(false)`.
- `private var gatt: BluetoothGatt?` → `private val gatt = AtomicReference<BluetoothGatt?>(null)`.
  - All writes: `gatt.set(...)` in `connect()` and `onGattDisconnected()`.
  - All reads: `gatt.get()` in `disconnect()`, `handleNotification()`, `writeHistoricalCommand()`, `onGattDisconnected()`.
- No `kotlinx.coroutines.sync` (Mutex) usage — atomics are the single source of truth for shared mutable state accessible from the BLE callback thread.

**D-03 — importFrame error propagation:**
- `GooseBridge.safeHandle(request)` return value captured as `val response`.
- Response parsed with `org.json.JSONObject(response)` inside `try/catch(JSONException)`.
- When `ok` is false: `Log.e(TAG, "importFrame bridge failure: $message source=$source")`.
- On JSON parse failure: `Log.e(TAG, "importFrame bridge response parse failure: ${e.message} source=$source")`.
- Frame routing, source labelling ("historical_sync"/"android_ble"), and live-HR extraction are unchanged.

## Deviations from Plan

None — plan executed exactly as written. Both tasks applied simultaneously to WhoopBleClient.kt as a single commit rather than two separate commits; this is a non-deviation since both tasks are scoped to the same file and have no ordering dependency.

## Verification

All automated checks from both tasks passed:

- `GlobalScope` count (non-comment): 0
- `@Volatile private var scope` present
- `syncCompleteEvent` SharedFlow property present; `tryEmit` used in `completeSyncIfActive()`
- `scope.cancel()` present in `disconnect()`
- `@Deprecated` no-op stub for `onSyncComplete` present
- `AtomicBoolean` present for `syncInProgress`
- `AtomicReference` present for `gatt`
- `compareAndSet` used in start/complete transitions
- `importFrame bridge failure` Log.e present
- No `kotlinx.coroutines.sync` import or usage

## Known Stubs

- `onSyncComplete`: intentional deprecated no-op stub retained for wave-1/wave-2 compile bridge. Plan 128-02 removes it. This does not prevent the plan's goal from being achieved.

## Self-Check: PASSED

- `android/app/src/main/kotlin/com/goose/app/ble/WhoopBleClient.kt` — modified, committed at c43e7f3
- Commit c43e7f3 verified in git log
