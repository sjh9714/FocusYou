# Changelog

All notable changes to this project are documented in this file.

## [0.5.0] - 2026-02-14

### Added
- "Frosted Glass" design system: `.ultraThinMaterial` cards, gradient buttons, spring animations.
- Design tokens (`Constants.Design`) for consistent spacing, corners, and icon sizes.
- Reusable components: `PrimaryActionButtonStyle`, `SecondaryActionButtonStyle`, `SegmentedPill`, `ChipButton`, `IconBadge`.
- Dark mode support via `backgroundDarkHex` field on `AppTheme`.
- PieChartTimerView redesign with angular gradient arc, glow ring, and endpoint dot.
- SegmentedPill mode picker with `matchedGeometryEffect` sliding capsule.
- Capsule progress bar with gradient fill in FocusingContentView.
- Celebration animation (checkmark scale-in + confetti burst) in CompletedContentView.
- Breathing opacity animation for paused state.
- Custom segmented tab bar for BlockListView (replaces TabView).
- Skeleton loading animation for AppBlockView.
- Hover effects on WebsiteBlockView rows and CategoryPickerView cards.
- Profile management: `ProfileViewModel`, `ProfileListView`, `ProfileEditorView` with icon/color picker.
- Statistics dashboard: `StatsViewModel`, `StatsView` with Swift Charts (BarMark, SectorMark), period filtering.
- New windows registered: "프로필" and "통계".
- Enhanced SettingsView theme section with wider swatches, glow border, and mini timer preview.
- Dashboard quick-control card with hero state display (idle CTA / live timer / completion).
- Dashboard quick-start options for free mode presets and default Pomodoro launch.
- @Query enabled-only filter for MainDashboardView consistency.

### Changed
- Removed forced light appearance (`.preferredColorScheme(.light)`) for dark mode support.
- All views redesigned with frosted glass aesthetic and consistent design tokens.
- Buttons use custom ButtonStyle with gradient, shadow, and press scale.
- Hard `Divider` replaced with 0.5pt soft `Rectangle` dividers.
- MenuBarView footer uses icon-forward vertical buttons.
- Blocking badge in header has pulse animation.
- Version fallback in SettingsView uses "—" instead of hardcoded version.
- project.yml version bumped to 0.5.0 (build 5).

### Fixed
- BlockListView Preview now includes `.environment(ThemeManager.shared)`.

## [0.3.2] - 2026-02-13

### Fixed
- Hardened app termination cleanup by waiting for blocking deactivation with a bounded timeout.
- Migrated `NotificationService` from `@unchecked Sendable` class to `actor` for safer concurrency.
- Updated notification/settings tests to align with Swift concurrency actor isolation rules.

## [0.3.1] - 2026-02-13

### Fixed
- Replaced MenuBar error `.alert` with an inline error panel to avoid popover-dismiss side effects.
- Hardened Pomodoro focus-phase transition failure cleanup to reduce blocking-state mismatch risk.
- Stabilized settings persistence by moving away from `@AppStorage` in `SettingsViewModel`.

### Docs
- Added v0.3.0 manual QA execution log.

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

## [0.1.0] - 2026-02-13

### Added
- Initial menu bar app flow for focus timer start/stop.
- Website/app blocking with hosts-based web blocking and app monitoring.
- First-pass helper authorization flow and baseline UX updates.
