---
title: Fix Coach view freeze on open
date: 2026-06-28
priority: high
---

## Problem

Tapping "Ask Coach" freezes the UI immediately (before any message sent). Happens every time. Consistent with synchronous Rust bridge call on @MainActor in `onAppear` or view `init`.

## Investigation targets

- Coach view `onAppear` — any `bridge.request(...)` calls on main thread
- Coach view model `init` — any SQLite/history load on main thread
- `CoachLocalToolContext`, `CodexCoachSupport` — initialization paths

## Fix direction

Move Rust bridge calls off @MainActor:
- `Task.detached { bridge.request(...) }` then `await MainActor.run { self.state = result }`
- Or dispatch to background `DispatchQueue` then call back to main

## References

- Anti-pattern: CLAUDE.md "Calling GooseRustBridge from @MainActor inline"
- Constraint: `goose_bridge_handle_json` is synchronous — blocks calling thread
