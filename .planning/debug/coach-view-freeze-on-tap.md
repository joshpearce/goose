---
slug: coach-view-freeze-on-tap
status: gathering
trigger: app bloqueia (UI congelada) ao clicar Ask Coach
created: 2026-06-28
updated: 2026-06-28
---

## Symptoms

- **Expected:** Coach view opens, shows chat interface
- **Actual:** UI freezes completely (congelada, sem resposta) — entire app unresponsive
- **Errors:** None visible
- **Timeline:** Always — happens every single time
- **Reproduction:** Tap "Ask Coach" button

## Hypothesis

Synchronous Rust bridge call (`goose_bridge_handle_json`) executed on `@MainActor` during Coach view `onAppear` or `init`. Since the bridge is synchronous and blocks the calling thread, calling from the main thread freezes the UI.

## Current Focus

- hypothesis: Freeze is NOT reproducible in a clean/unsigned-in install. It only manifests in the SIGNED-IN CoachChatScreen path, which requires provider auth (OAuth/API key) to reach. Need user reproduction details (which provider signed in, conversation size, exact button).
- test: Built + ran on iPhone 17 Pro sim (iOS 26.5). Drove to Coach tab via deep link and opened the chat sheet.
- expecting: confirmation of where exactly the freeze happens in the user's environment
- next_action: CHECKPOINT — ask user for repro state (signed-in provider? existing conversation? does freeze happen on Coach TAB open or only after opening the chat sheet?)

## Evidence

- timestamp: 2026-06-28
  checked: CoachView.onAppear + body synchronous paths (refreshCoachSnapshot, CoachOverviewSnapshot.make, healthStore.snapshot/baselineProgress/CoachSummaries methods, CoachChatModel.init, CoachProviderRegistry.init, providers' isAuthenticated, model.recordUIAction→ble.record)
  found: All synchronous Coach overview code reads cached @Published/UserDefaults/Keychain state. No synchronous goose_bridge_handle_json call. loadBridgeCatalogsIfNeeded and refreshPacketInputsIfNeeded both dispatch to async Task. ble.record early-returns for info-level page.opened.
  implication: The "synchronous Rust bridge on main thread" hypothesis is not supported. Freeze must come from a runtime trap or a lock/actor deadlock not visible in source skim — needs runtime observation.

- timestamp: 2026-06-28
  checked: RUNTIME — built Debug for iPhone 17 Pro sim (BUILD SUCCEEDED), installed (bundle id is com.tigercraft4.goose, NOT com.goose.app), set goose.swift.onboardingComplete=YES to skip onboarding, launched into Home, navigated to Coach tab (deep link gooseswift://coach + confirm), opened the chat sheet via "Perguntar Sobre Isto".
  found: Coach OVERVIEW renders fully and stays responsive (header Treinador/ChatGPT, recommendation card, chat card, journal, COACH ROUTES, metric highlights). Opening the chat sheet shows the CoachSignInScreen ("Iniciar sessão no Coach") because no provider is authenticated — also fully responsive. Clock kept advancing (13:55→14:13) and screenshots kept updating throughout. NO FREEZE in any state I could reach.
  implication: The freeze does NOT occur in a clean install / not-signed-in state. The not-signed-in chat sheet shows CoachSignInScreen (no composer, no message list). The SIGNED-IN path renders CoachChatScreen (CoachComposer + ForEach(chat.messages)/CoachMessageBubble) which I could not reach without provider auth.

- timestamp: 2026-06-28
  checked: CoachComposer.swift GeometryReader→CoachComposerInputHeightKey preference→inputHeight @State→isMultilineInput→inputCornerRadius + .animation(value: isMultilineInput). git log -S on CoachComposer.
  found: The geometry/preference/state pattern is a SwiftUI feedback-loop candidate, BUT: (1) inputHeight only changes corner radius/animation, not the measured frame height, so the preference loop should converge; (2) git blame shows this exact code was introduced in the very first MVP commit 46f1638 (Jun 2) and is UNCHANGED since. If it caused an always-freeze it would have done so since day one.
  implication: CoachComposer is not a v16 regression and is an unlikely cause of an "always" freeze. The only signed-in-only screen is CoachChatScreen; its freeze (if any) is state-dependent (provider/conversation), not deterministic from source.

- timestamp: 2026-06-28
  checked: ble type after rename (commit 2b2c70c) and Swift6 actor commit (26d8c09). model.ble = bleCoordinator.asTransport; CoreBluetoothBLETransport is `@Observable final class ... @unchecked Sendable` (a class, main-thread accessed), NOT an actor. Properties read in Coach path (liveHeartRateBPM etc.) are synchronous main-thread reads.
  implication: No actor-isolation await/deadlock and no DispatchQueue.sync on the Coach open path. Rules out the rename/Swift6 commits as the freeze cause.

## Eliminated

- hypothesis: Synchronous Rust bridge call (goose_bridge_handle_json) on @MainActor in Coach view onAppear/init blocks the UI
  evidence: No bridge.request / requestValue / goose_bridge call exists anywhere in the synchronous Coach overview path. All bridge-backed catalog/packet loads are dispatched into async Tasks. CoachSummaries and snapshot(for:) read cached state only.
  timestamp: 2026-06-28

## Resolution

root_cause: (not yet confirmed) Not reproducible in clean/not-signed-in state. Leading hypothesis: freeze is specific to the SIGNED-IN CoachChatScreen path and/or the user's data/device state. Awaiting user repro details.
fix:
verification:
files_changed: []
