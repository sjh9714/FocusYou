# AGENTS.md - FocusYou Codex Working Guide

This file defines project-specific operating rules for coding agents (Codex) in this repository.

## 1) Current Product State

- App: `Focus You` (macOS menu bar app)
- Bundle ID: `com.sungjh.focusyou`
- Target: macOS 14+
- Architecture: SwiftUI + SwiftData + Service Layer + actor-based blocking flow
- Main branch for daily work: `develop`

Recent baseline is already stabilized for:
- blocking activation/deactivation safety
- crash/reboot recovery
- helper-based hosts restore
- QA script and CI (`macOS Tests`)

## 2) v0.3 Scope (Do This)

Target release: `v0.3.0`

In scope:
- Pomodoro mode implementation
- Pie chart timer UX
- session flow integration with existing blocking lifecycle
- regression-safe integration with current QA/test setup

Out of scope:
- subscription/paywall
- Network Extension
- major UI theme system work (`v0.5+`)
- iOS expansion

## 3) Canonical Commands

Project generation:
```bash
xcodegen generate
```

Build:
```bash
xcodebuild -project FocusYou.xcodeproj -scheme FocusYou -configuration Debug -destination 'platform=macOS' build
```

Tests:
```bash
xcodebuild -project FocusYou.xcodeproj -scheme FocusYou -configuration Debug -destination 'platform=macOS' test
```

QA state checks:
```bash
./scripts/qa_focusyou_state.sh snapshot
./scripts/qa_focusyou_state.sh assert-clean
./scripts/qa_focusyou_state.sh assert-blocked
./scripts/qa_focusyou_state.sh assert-safetynet-armed
./scripts/qa_focusyou_state.sh assert-helper-ready
./scripts/qa_focusyou_state.sh assert-recovery-pending
./scripts/qa_focusyou_state.sh assert-recovered
```

Manual checklist:
- `docs/manual-qa-checklist.md`

## 4) High-Risk Areas (Handle Carefully)

Do not casually change behavior in:
- `FocusYou/Services/Blocking/BlockingCoordinator.swift`
- `FocusYou/Services/System/PrivilegedHelper.swift`
- `FocusYou/Services/System/HostsFileManager.swift`
- `FocusYou/ViewModels/AppState.swift`
- `scripts/qa_focusyou_state.sh`

Rules:
- Never bypass helper flow for hosts restore in app logic.
- Keep recovery signals consistent (`blocking.active`, `hosts.backup`, launch agent plist).
- On cleanup failure, preserve retry signals and surface user-visible error.

## 5) Coding Rules

- No force unwrap.
- Avoid magic numbers; prefer `Constants`.
- Keep new code Swift concurrency safe (`async/await`, actor awareness).
- Use `os.Logger` (no `print` debugging in production paths).
- Do not reintroduce placeholder IDs like `com.yourname.*`.
- Keep external dependencies minimal (Apple-native first).

## 6) Branch and Commit Policy

Branching:
- base: `develop`
- feature branches: `feature/v0.3-*`

Commit style:
- `feat: ...`
- `fix: ...`
- `refactor: ...`
- `test: ...`
- `docs: ...`
- `chore: ...`

Prefer small, reviewable commits with build/test passing per logical unit.

## 7) Done Criteria for v0.3 Work Items

Before marking done:
1. `xcodegen generate` succeeds
2. `xcodebuild ... test` succeeds
3. QA baseline returns to clean state:
   - `assert-helper-ready` PASS
   - `assert-clean` PASS
4. CI workflow (`.github/workflows/macos-tests.yml`) remains green on push/PR

## 8) Quick Handoff Template

When handing off to another agent/person, include:
- what changed
- why it changed
- test command + result
- QA command + result
- remaining risks / TODOs
