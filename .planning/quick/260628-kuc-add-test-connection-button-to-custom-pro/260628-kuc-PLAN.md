---
phase: quick-260628-kuc
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - GooseSwift/CustomEndpointCoachProvider.swift
  - GooseSwift/CoachSettingsSheet.swift
autonomous: true
requirements: [QUICK-KUC-01]
must_haves:
  truths:
    - "After entering Base URL + API Key + Model ID, a Test Connection button is visible in the custom provider settings."
    - "Tapping Test Connection fires a minimal chat-completion HTTP request to the configured endpoint and shows an inline success or error result."
    - "A reachable, correctly-configured endpoint shows a success result; an unreachable or rejecting endpoint shows an inline error message with the cause."
  artifacts:
    - "GooseSwift/CustomEndpointCoachProvider.swift — testConnection() method (non-streaming, 1-token request)"
    - "GooseSwift/CoachSettingsSheet.swift — Test Connection button + inline result state in CustomEndpointConfigView"
  key_links:
    - "CustomEndpointConfigView button -> provider.testConnection() -> URLSession request to {baseURL}/v1/chat/completions"
---

<objective>
Add a Test Connection button to the custom provider settings UI so the user can verify their endpoint/key/model before relying on the Coach chat.

Purpose: Today the only way to know if a custom endpoint works is to start a chat and watch it silently fail (send() swallows non-2xx by finishing the stream). A one-tap probe gives immediate, explicit feedback.
Output: A testConnection() method on CustomEndpointCoachProvider and a Test Connection button with inline success/error display in CustomEndpointConfigView.
</objective>

<execution_context>
@$HOME/.claude/gsd-core/workflows/execute-plan.md
@$HOME/.claude/gsd-core/templates/summary.md
</execution_context>

<context>
@.planning/STATE.md
@GooseSwift/CustomEndpointCoachProvider.swift
@GooseSwift/CoachSettingsSheet.swift
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Add testConnection() probe method to CustomEndpointCoachProvider</name>
  <files>GooseSwift/CustomEndpointCoachProvider.swift</files>
  <behavior>
    - Success: a 2xx HTTP response from the configured endpoint returns a success outcome.
    - Invalid URL: when validateBaseURL(baseURL) is false, returns a failure outcome describing the URL problem (do not perform a network call).
    - Missing key: when no API key is stored or the stored key is empty, returns a failure outcome describing the missing key (do not perform a network call).
    - Non-2xx response: returns a failure outcome that includes the HTTP status code.
    - Transport error (host unreachable, TLS failure, timeout): returns a failure outcome carrying the underlying error's localized message.
  </behavior>
  <action>
    In CustomEndpointCoachProvider, add a public async method testConnection() that returns a Result-style outcome the UI can render. Introduce a small nested enum/struct in this file to represent the outcome — a success case and a failure case carrying a human-readable String message. Do NOT add anything to the CoachProvider protocol; keep this method on CustomEndpointCoachProvider only.

    Reuse the existing guards and request shape from send(): first guard Self.validateBaseURL(baseURL) (failure message: invalid URL), then guard a non-empty key loaded from the keychain via the existing CustomEndpointKeychain.load() path (failure message: missing API key). Build the request the same way buildRequest() does — same URL composition ({trimmedBase}/v1/chat/completions), same Authorization Bearer header, Content-Type application/json, and the same model field — but build a NON-streaming, minimal probe body: set stream to false, send a single short user message (e.g. role user with a one-character content), and request the smallest possible output by setting max_tokens to 1. Accept header should be application/json (not text/event-stream) since this is a non-streaming probe. Use a short timeoutInterval (e.g. 15 seconds) on this request rather than the 180s streaming timeout.

    Perform the request with URLSession.shared.data(for:). Inspect the response as HTTPURLResponse: a status in 200..<300 yields the success outcome; any other status yields a failure outcome whose message includes the status code (and, when the body is small and decodable as UTF-8, append it for diagnostics). Wrap the call so a thrown URLError/transport error is converted to a failure outcome carrying error.localizedDescription. The method must never throw to the caller — it always resolves to the outcome type so the UI can display it inline. Keep the existing buildRequest() private helper untouched; either add a sibling private helper for the probe request or inline the probe-request construction inside testConnection().

    Note: send() currently uses max_tokens implicitly (none); the probe explicitly sets max_tokens to 1 to keep the call cheap, per the task constraint of a 1-token request.
  </action>
  <verify>
    <automated>cd /Users/francisco/Documents/goose && xcodebuild -project GooseSwift.xcodeproj -scheme GooseSwift -destination 'generic/platform=iOS Simulator' -quiet build 2>&1 | tail -20</automated>
  </verify>
  <done>CustomEndpointCoachProvider exposes an async testConnection() returning a success/failure outcome with a human-readable message; invalid URL and missing key short-circuit without a network call; non-2xx includes the status code; transport errors carry localizedDescription; CoachProvider protocol is unchanged; project builds.</done>
</task>

<task type="auto">
  <name>Task 2: Add Test Connection button with inline result to CustomEndpointConfigView</name>
  <files>GooseSwift/CoachSettingsSheet.swift</files>
  <action>
    In CustomEndpointConfigView (the private struct around line 435), add the Test Connection affordance below the existing Save Endpoint button, following the surrounding SwiftUI patterns (2-space indentation, String(localized:) for all user-facing text, .buttonStyle, VStack(alignment: .leading, spacing: 12) layout).

    Add @State for the test flow: an isTesting Bool and a testResult value holding the outcome message + whether it was a success (e.g. an optional small struct or an optional enum mirroring the provider outcome, plus the message string). Add a Test Connection button styled as .bordered (secondary to the prominent Save Endpoint button). Disable the button when baseURL is empty, when the URL is invalid (reuse urlIsInvalid), or while isTesting is true. While testing, show a ProgressView next to or in place of the button label.

    On tap, run a Task that sets isTesting true, calls await provider.testConnection(), stores the resulting outcome in testResult, then sets isTesting false — all on the main actor (the provider is @MainActor @Observable, so call from a SwiftUI Task which already hops to the main actor). Before testing, the button's action should NOT require a prior Save: read the current field values into the provider first by assigning provider.baseURL = baseURL and provider.modelID = modelID, and if apiKey is non-empty persist it via the same try? provider.saveEndpoint(apiKey:) path saveCustomEndpoint() uses, so the probe tests exactly what the user typed. (Reuse the existing save logic rather than duplicating validation.)

    Render the result inline below the button: when testResult is a success, show a green check-prefixed Text reading the success message (e.g. "Connection successful"); when it is a failure, show a red Text with the failure message prefixed by an error indicator. Use .font(.caption) and .foregroundStyle(.green)/.foregroundStyle(.red) consistent with the existing urlIsInvalid error Text at line 456. Clear testResult when the user edits any field is NOT required, but reset it at the start of each test tap so stale results never linger.
  </action>
  <verify>
    <automated>cd /Users/francisco/Documents/goose && xcodebuild -project GooseSwift.xcodeproj -scheme GooseSwift -destination 'generic/platform=iOS Simulator' -quiet build 2>&1 | tail -20</automated>
  </verify>
  <done>CustomEndpointConfigView shows a Test Connection button below Save Endpoint; it is disabled for empty/invalid URL and while a test is in flight; tapping it probes the typed credentials and displays an inline green success or red error message; styling matches the existing config view; project builds.</done>
</task>

</tasks>

<verification>
- Build succeeds: xcodebuild -project GooseSwift.xcodeproj -scheme GooseSwift -destination 'generic/platform=iOS Simulator' build
- Manual (simulator): open Coach settings, select Custom provider, enter a known-good Base URL + API Key + Model ID, tap Test Connection -> "✓ Connection successful". Enter a bad URL/key -> "✗ Error: ..." with the cause.
- CoachProvider protocol diff is empty (no new protocol requirement added).
</verification>

<success_criteria>
- A Test Connection button is present in the custom provider settings UI and works on a real configured endpoint.
- Success and failure both render inline with clear, distinct styling.
- testConnection() lives only on CustomEndpointCoachProvider; the CoachProvider protocol is unchanged.
- The probe uses a minimal, non-streaming, max_tokens=1 request and never throws to the UI.
</success_criteria>

<output>
Create `.planning/quick/260628-kuc-add-test-connection-button-to-custom-pro/260628-kuc-SUMMARY.md` when done
</output>
