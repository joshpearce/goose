---
name: strap-notification-mirroring
description: Mirror incoming phone calls and internal Goose health alerts to WHOOP strap vibration — CTCallCenter + internal event hooks
metadata:
  type: seed
  trigger_condition: after Android port milestone ships
  planted_date: 2026-06-28
---

## Idea

Make the WHOOP strap buzz when:
1. Incoming phone call / FaceTime (via CTCallCenter)
2. Internal Goose health alerts — HR spike, HRV dip, sedentary nudge

`buzz(loops:)` already works (cmd 0x13, both Gen4 and Gen5 via `whoopGenerationFromCapabilities()`).
BreatheView and CoachRouteViews already call it. Infrastructure is complete — this phase is
purely wiring + settings UI.

## iOS limitation (documented)

iOS sandbox blocks interception of third-party app notifications (WhatsApp, SMS, etc.).
Only accessible from the background:
- Phone calls: `CTCallCenter.callEventHandler` ✅
- FaceTime / VoIP: CallKit ✅
- Internal Goose events: direct call ✅
- Other apps: not possible without jailbreak ❌

## Tasks

### Task 1 — CTCallCenter integration
- File: new `GooseAppModel+CallNotifications.swift`
- Import `CoreTelephony` (add framework to GooseSwift target)
- Set `CTCallCenter().callEventHandler` in `GooseAppModel.init` or on first BLE connect
- On `.incoming` or `.dialing` state → `ble.buzz(loops: callBuzzLoops)`
- Guard on `UserDefaults` toggle `goose.haptic.callBuzz.enabled`
- Cancel / stop on `.disconnected`

### Task 2 — Internal alert hooks
Wire existing published events → buzz:
| Event | Existing source | Loops |
|-------|----------------|-------|
| HR spike (>threshold) | `GooseAppModel+NotificationPipeline.swift` | 2 |
| HRV dip (<threshold) | `HealthDataStore` or metric callback | 1 |
| Sedentary nudge (no movement N min) | new detection or existing inactivity | 3 |

Thresholds configurable via `UserDefaults`.

### Task 3 — Settings UI
- Section in More → Settings (or More → Device)
- Toggle: "Buzz on incoming calls" (default on)
- Toggle: "Buzz on HR spike" + threshold slider
- Toggle: "Buzz on HRV dip" + threshold slider
- Toggle: "Buzz on sedentary nudge" + interval picker
- Test button: `ble.buzz(loops: 2)`

## Files

- `GooseSwift/GooseAppModel+CallNotifications.swift` (new)
- `GooseSwift/GooseSwift.xcodeproj/project.pbxproj` (CoreTelephony + new file)
- `GooseSwift/MoreRouteViews.swift` or equivalent settings view (UI section)
- `GooseSwift/GooseAppModel+NotificationPipeline.swift` (HR hook)

## Out of scope

- SMS / third-party app mirroring (iOS sandbox — impossible)
- CallKit VoIP (no VoIP app planned, skip for now)
- Advanced haptic patterns beyond `buzz(loops:)` — covered by `advanced-haptic-breathe-primitive.md`

## Effort estimate

~1 phase, 3–4 tasks, ~1 day.

## Dependencies

- `buzz(loops:)` — already done (v10.0)
- Android port milestone — must ship first (user requirement)
