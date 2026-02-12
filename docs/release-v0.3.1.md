# Focus You v0.3.1 Release Notes

## Summary

v0.3.1 is a stabilization patch release for v0.3.x.

## Fixed

- Menu bar error handling now uses an inline panel instead of `.alert`, preventing popover dismissal during retry flows.
- Pomodoro focus-phase transition failure path now performs additional blocking cleanup attempts for better state consistency.
- Settings persistence reliability improved in `SettingsViewModel`.

## Ops/Release

- Added complete AppIcon asset files for macOS slots.
- CI workflow now pins Xcode and caches Homebrew artifacts for faster/repeatable runs.
- `CHANGELOG.md` now includes both `0.3.1` and `0.1.0` entries.
