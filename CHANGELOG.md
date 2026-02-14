# Changelog

All notable changes to this project are documented in this file.

## [1.0.1] - 2026-02-14

### Added
- 기본 프로필 부트스트랩: 앱 시작 시 기본 프로필 보장 및 legacy `profile == nil` 차단 항목 자동 이관.
- 프로필 스코프 회귀 테스트 추가 (`AppState`, `BlockListViewModel`, `PrivateRelayDetector`, `ProfileBootstrapper`).

### Changed
- 세션 시작/차단 목록/온보딩/대시보드가 활성 프로필 기준으로 일관 동작하도록 연동 강화.
- `PrivateRelayDetector` 파서를 구조 의존 방식에서 재귀 탐색 방식으로 개선.
- AppDelegate 윈도우 정책 옵저버의 main actor 호출 경고 정리.

### Fixed
- 플로우모도로 집중→휴식 전환 시 차단 해제 실패하면 `isBlockingActive`와 재시도 UI 상태가 정확히 유지되도록 수정.
- 프로필 모드 라벨 버그 수정 (`flowmodoro`가 `자유`로 보이던 문제 수정).

### Testing
- `xcodebuild -project FocusYou.xcodeproj -scheme FocusYou -configuration Debug -destination 'platform=macOS' test` (132 tests, 0 failures)
- `./scripts/qa_focusyou_state.sh assert-helper-ready`
- `./scripts/qa_focusyou_state.sh assert-clean`

## [1.0.0] - 2026-02-14

### Added
- Flowmodoro 타이머 모드: 카운트업 집중 → 1/5 비례 자동 휴식 계산 → 휴식 카운트다운.
- Flowmodoro 집중 중 차단 유지, 휴식 중 자동 해제.
- 스트릭 시스템: 일일 완료 추적, 연속 기록, 대시보드·통계 화면 표시.
- 온보딩 3스텝 플로우: 환영 → 차단 카테고리 선택 → 준비 완료.
- 프로필 원클릭 시작: 프로필 칩 탭으로 해당 타이머 설정 즉시 세션 시작.
- StreakCalculator 유닛 테스트 추가.
- FlowmodoroEngine 유닛 테스트 추가.

### Changed
- AppState에 Flowmodoro 상태 머신 통합 (focus/rest 페이즈 전환).
- 대시보드에 스트릭 배지 및 Flowmodoro 퀵스타트 추가.
- StatsView에 스트릭 정보 카드 추가.
- TimerView에 Flowmodoro 모드 UI 및 프로필 빠른 시작 섹션 추가.

### Testing
- 69 tests, 0 failures.

## [0.6.0] - 2026-02-14

### Added
- Settings 테마 섹션에 실시간 프리뷰 패널 추가 (대시보드/팝오버 미리보기 전환).
- 설정에서 "대시보드 나란히 열기" 동작 추가로 테마 변경을 실시간 비교 가능.
- DEBUG 전용 QA 자동화 브리지 및 start/stop 스모크 명령 추가.
- 릴리스 전 정합성 검사 스크립트 `scripts/release_preflight.sh` 및 운영 문서 추가.

### Changed
- Settings 테마 UX를 자동 저장 기반 플로우로 명확화.

### Testing
- AppState 라이프사이클 회귀 테스트 확장 (start/stop/complete/reset/startup cleanup/error-retry).
- PomodoroEngine duration 검증 확장 (single cycle, max cycle, 전체 타임라인 합계).
- `xcodebuild -project FocusYou.xcodeproj -scheme FocusYou -configuration Debug -destination 'platform=macOS' test` (33 tests, 0 failures)
- `./scripts/qa_focusyou_state.sh assert-helper-ready`
- `./scripts/qa_focusyou_state.sh assert-clean`

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
