# Phase 129: Android Sleep & Health UI — Discussion Log

**Date:** 2026-06-28
**Mode:** Interactive (gsd-autonomous)

## Areas Discussed

### Charts Library

**Options:** Vico (Compose-native) vs Canvas manual
**Selection:** Vico
**Notes:** Add `com.patrykandpatrick.vico:compose` + `compose-m3` to build.gradle.kts

---

### Sleep Screen Placement

**Options:** Inside HealthScreen vs new tab
**Selection:** Inside HealthScreen (existing tab)
**Notes:** Sleep bevel at top, health cards below. No new tab.

---

### 14-day History Bridge Method

**Options:** `metrics.daily_recovery_metrics` (1 call) vs `metrics.goose_sleep_v1` per day (14 calls)
**Selection:** `metrics.daily_recovery_metrics`
**Notes:** Single call returns daily array. Parse last 14 entries.

---

## Deferred Ideas

- Separate Sleep tab
- Sleep staging hypnogram (v17.0)
- Interactive chart zoom/pan
