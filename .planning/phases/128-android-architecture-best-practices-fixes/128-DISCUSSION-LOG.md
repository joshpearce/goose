# Phase 128: Android Architecture & Best-Practices Fixes — Discussion Log

**Date:** 2026-06-28
**Mode:** Interactive (gsd-autonomous)

## Areas Discussed

### A-09: Sub-ViewModel lifecycle fix approach

**Options presented:**
1. Minimal: make private + lazy
2. ViewModelProvider.Factory
3. Hilt DI

**User selection:** Hilt DI

**Notes:** Hilt adds build complexity but user prefers correct long-term approach. D-09a fallback documented if CI build fails.

---

### A-07: Reference cycle fix approach

**Options presented:**
1. WeakReference in callback
2. SharedFlow/Channel

**User selection:** SharedFlow/Channel

**Notes:** More idiomatic Kotlin/Compose. WhoopBleClient exposes `syncCompleteEvent: SharedFlow<Unit>`, AppViewModel collects it.

---

### A-08: GooseUploadClient observable state

**Options presented:**
1. Expose StateFlow in AppViewModel (centralised state)
2. Companion StateFlow on GooseUploadClient

**User selection:** Expose via AppViewModel (option 1)

**Notes:** AppViewModel already owns all observable state. uploadStatus: StateFlow<UploadState> collected by MoreScreen.

---

## Deferred Ideas

- Full Hilt migration beyond sub-ViewModels
- iOS threading fixes
- Rust god-file decomposition
