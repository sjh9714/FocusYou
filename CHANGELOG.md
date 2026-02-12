# Changelog

All notable changes to this project are documented in this file.

## [0.3.0] - 2026-02-13

### Added
- Pomodoro mode integrated into session flow (`focus`, `short break`, `long break`).
- Pie chart timer UI and phase progress indicators.
- Completion summary UI for Pomodoro sessions.
- Phase-based blocking behavior (focus phases block, break phases unblock).
- Debug Fast Timer support for rapid local QA.
- Manual QA state script and checklist for blocking/recovery scenarios.

### Changed
- Startup emergency cleanup flow hardened for stale blocking artifacts.
- Helper-based recovery and retry path handling improved.
- Settings screen now includes a Debug-only Fast Timer section in Debug builds.

### Testing
- `xcodebuild -project FocusYou.xcodeproj -scheme FocusYou -configuration Debug -destination 'platform=macOS' test`
- `./scripts/qa_focusyou_state.sh assert-helper-ready`
- `./scripts/qa_focusyou_state.sh assert-clean`
