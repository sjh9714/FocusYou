# AGENTS.md - FocusYou Codex Working Guide

This file defines project-specific operating rules for coding agents (Codex) in this repository.

## 1) Current Product State

- App: `Focus You` (macOS menu bar app)
- Bundle ID: `com.sungjh.focusyou`
- Target: macOS 14+
- Architecture: SwiftUI + SwiftData + Service Layer + actor-based blocking flow
- Main branch for daily work and releases: `main`

Recent baseline is already stabilized for:
- blocking activation/deactivation safety
- crash/reboot recovery
- helper-based hosts restore
- QA script and CI (`macOS Tests`)

## 2) Current Maintenance Scope

Current baseline: `v2.3.3`

In scope:
- warning-free Swift 6 / XcodeGen builds
- blocking lifecycle safety and recovery maintenance
- release script, CI, and documentation consistency
- regression-safe integration with current QA/test setup

Out of scope:
- iOS expansion
- AI insights
- major UI theme rewrites
- unreviewed release/tag publishing

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
- base: `main`
- work directly on `main` for approved changes
- use temporary branches only when explicitly requested, then merge back to `main`

Commit style:
- `feat: ...`
- `fix: ...`
- `refactor: ...`
- `test: ...`
- `docs: ...`
- `chore: ...`

Prefer small, reviewable commits with build/test passing per logical unit.

## 7) Done Criteria

Before marking done:
1. `xcodegen generate` succeeds
2. `xcodebuild ... build` / `test` / `analyze` succeed for the changed surface
3. QA baseline returns to clean state when blocking code or scripts are touched:
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
