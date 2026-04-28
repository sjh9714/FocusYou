# Changelog

All notable changes to this project are documented in this file.

## [Unreleased]

### Changed
- README 설치 및 릴리즈 빌드 안내를 signed/notarized DMG 배포 흐름에 맞게 갱신.

## [2.3.3] - 2026-04-28

### Changed
- 프로젝트 정리: XcodeGen shared source 구성, Swift 6 경고, AppIntents 의존성, 릴리즈 스크립트, 문서 스냅샷 정합성 개선.
- 공식 DMG 배포 경로가 앱과 DMG 모두 Developer ID 서명, notarization, stapling을 거치도록 보강.

## [2.3.2] - 2026-02-22

### Added
- 테스트 커버리지 강화: 1개 신규 + 3개 확장 테스트 파일, ~23개 테스트 추가.
  - HostsFileManagerTests 확장: IPv6 엔트리, 중복 도메인, 빈 배열, readHostsFile 에러 경로, buildCleanContent 엣지 케이스 (+6개).
  - PrivilegedHelperTests 신규: shellEscapeForDoubleQuotes 순수 로직 (백틱, 달러, 혼합, 일반, 빈 문자열) (+5개).
  - AppIntentsTests 확장: TogglePauseIntent/GetFocusStatusIntent/StopFocusIntent 상태 전이 (+7개).
  - NotificationServiceSettingsTests 확장: 명언 설정, 토글 반영 (+4개).

### Changed
- PrivilegedHelper: shellEscapeForDoubleQuotes 접근 제어자 private → internal (테스트 접근용).
- AppStatePauseResumeTests/AppStateLifecycleTests/AppIntentsTests: 개발 환경 UserDefaults 오염 방지 setUp/tearDown 강화 (debugFastTimer, enableFocusMode, enableCalendarSync).

## [2.3.1] - 2026-02-19

### Changed
- 뷰 리팩토링 2차: 나머지 대형 뷰 6개를 9개 하위 컴포넌트로 분리.
  - MainDashboardView(1,022→168줄): DashboardIdleHeroView, DashboardActiveHeroView, DashboardCompletedHeroView 추출.
  - FocusingContentView(454→185줄): FocusingStatusView, FocusingControlsView 추출.
  - IdleContentView(421→282줄): IdleTimerConfigView 추출.
  - ProfileEditorView(364→97줄): ProfileEditorFormSections 추출.
  - PaywallView(351→168줄): PaywallContentView 추출.
  - SettingsGeneralTabView(313→196줄): SettingsThemeSectionView 추출.
- 순수 리팩토링 — 동작 변경 없음, 전체 123개 테스트 통과.

## [2.3.0] - 2026-02-19

### Changed
- 대형 뷰 파일 5개를 17개 하위 컴포넌트로 분리 (CLAUDE.md "body 50줄 초과 시 분리" 가이드라인 준수).
  - TimerView(1,142줄) → IdleContentView + FocusingContentView + CompletedContentView (삭제).
  - MainDashboardView(1,335→1,021줄): DashboardStatsRowView, DashboardQuickActionsView, DashboardRecentSessionsView 추출.
  - SettingsView(677→29줄): SettingsGeneralTabView, SettingsFocusTabView, SettingsIntegrationTabView, SettingsAdvancedTabView 분리.
  - StatsView(408→176줄): StatsSummaryCardsView, StatsChartsView, StatsSessionHistoryView 추출.
  - MenuBarView(328→236줄): 중복 에러/경고 패널 공유 컴포넌트로 교체.
- 공유 컴포넌트 추가: ErrorPanelView, PrivateRelayWarningPanel (MainDashboardView/MenuBarView 중복 제거).
- 순수 리팩토링 — 동작 변경 없음, 전체 282개 테스트 통과.

## [2.2.1] - 2026-02-19

### Added
- 테스트 커버리지 강화: 4개 신규 테스트 파일, ~23개 테스트 추가.
  - CalendarSyncServiceTests: 이벤트 제목/노트 생성 검증 (6개).
  - AppBlockerTests: 활성화/비활성화 상태 전이 (4개).
  - BlockProfileModelTests: 모델 초기값, 타이머 모드, 취소 강도 (5개).
  - FreeTimerAdjustedResumeTests: 실시간 조정 재개 (5개).
  - FocusModeControllerTests 확장: DND 상태 추적 (3개).

### Changed
- CalendarSyncService: eventTitle/eventNotes 접근 제어자 internal로 변경 (테스트 접근용).
- AppBlocker: isMonitoring → isMonitoringActive (private(set) internal 접근).

## [2.2.0] - 2026-02-19

### Added
- 스케줄 시스템 고도화:
  - 스케줄 세션 시 남은 시간 자동 계산 (프로필 기본값 대신 스케줄 종료까지 남은 시간 사용).
  - 일시정지 후 재개 시 실시간 조정 (초 단위 정밀도, 실제 집중 시간만 기록).
  - 세션 중지 후 재참여 배너 즉시 표시 (스케줄 진행 중이면 "참여하기" 버튼).
  - 활성 스케줄 배너 표시 (팝오버/대시보드).
- FreeTimer: `resumeWithAdjustedRemaining(_:)` — 스케줄 세션 실시간 재개.
- FocusModeObserver 확장: 시스템 Focus Mode 상태 감지 강화.
- SubscriptionManager: 영수증 재검증 개선.

### Removed
- AmbientSoundManager 제거 (앱 차단과 기능 중복, 향후 재설계 예정).
- AppDimmingManager 제거 (앱 terminate 방식과 중복).
- 관련 설정 UI, 상수, 테스트 일괄 정리.

### Changed
- ScheduleManager: 분 단위 → 초 단위 정밀도로 남은 시간 계산 개선.
- MainDashboardView: 스케줄 배너/재참여 배너 UI 추가.
- MenuBarView: 스케줄 배너/재참여 배너 UI 추가.
- TimerView: 스케줄 세션 표시 개선.
- SettingsView: 앰비언트 사운드/앱 디밍 섹션 제거.
- ProfileEditorView: UI 정리.
- ScheduleEditorView: UI 개선.

## [2.1.2] - 2026-02-18

### Added
- 테스트 커버리지 강화: 5개 테스트 파일, 37개 테스트 추가.
  - WebsiteBlockerFactoryTests: 전략 생성, UserDefaults 폴백, 팩토리 패턴 검증.
  - SharedBlockingDataTests: JSON 인코딩/디코딩, Sendable 검증.
  - FocusYouErrorTests: 16개 에러 케이스 로컬라이제이션 + 연관값 검증.
  - FocusSessionModelTests: 초기값, complete/cancel 상태 전이, 타임스탬프.
  - AppStatePauseResumeTests: 일시정지/재개, 중복 시작 방지, 회고 저장, 에러 해제.

## [2.1.1] - 2026-02-18

### Fixed
- GitHub Actions CI: CODE_SIGNING_ALLOWED=NO 추가 (서명 설정 이후 프로비저닝 프로파일 누락 해결).

## [2.1.0] - 2026-02-18

### Added
- Network Extension 인프라: App Store 배포용 웹사이트 차단 (NEFilterDataProvider).
- WebsiteBlockerFactory: hosts ↔ NE 전략 패턴 전환 (설정에서 선택 가능).
- SharedBlockingData: App Groups 기반 앱 ↔ NE 크로스 프로세스 통신.
- StoreKit 2 통합: SubscriptionManager (구매/복원/트랜잭션 감시/영수증 검증).
- 앱 시작 시 refreshEntitlements() 호출로 Pro 상태 실시간 동기화.

### Fixed
- Pro 게이팅 강화: 서비스 레이어에 Pro 체크 추가 (앰비언트 사운드, 캘린더 동기화, 차단 한도).
- CalendarSync: off-actor SwiftData 변경을 @MainActor Task로 격리.
- 세션 저장: complete()/cancel() 후 명시적 modelContext.save() 추가.
- BlockingCoordinator: activateBlocking() 상태 가드 (이중 활성화 방지).
- LaunchAgent 안전장치: sudo -n 실패 시 osascript 관리자 권한 fallback 추가.
- 통계: 취소 세션을 총 집중 시간/일별 데이터/히트맵에서 제외.
- startOfWeek: Calendar.firstWeekday 기반 로케일 대응.
- 사운드 미리듣기: Task 참조 저장 + 취소 패턴 적용.
- FreeTimer: 슬립/웨이크 옵저버 이중 디스패치 제거 (MainActor.assumeIsolated).
- 뽀모도로: 마지막 사이클 후 불필요한 longBreak 제거.
- PrivilegedHelper: 쉘 이스케이프 보강 (백틱/달러 문자).
- BlockProfile.setAsDefault(): isDefault 유일성 보장 메서드 추가.
- hasAutoOpenedDashboard를 AppDelegate로 이동 (static var → 인스턴스).
- AppState 강참조를 AppDelegate에 저장 (씬 리빌드 시 해제 방지).

### Changed
- Apple Developer Program 서명 설정 + 번들 ID 정리.
- NE 타겟 엔타이틀먼트 + 코드 서명 구성.

### Testing
- 123 tests, 0 failures.
- PomodoroEngine 테스트 새 동작(마지막 longBreak 없음)에 맞게 업데이트.

## [2.0.1] - 2026-02-15

### Changed
- 하드코딩 색상 2곳을 ThemeManager 시맨틱 색상으로 전환 (ExportView, HealthCheckView).
- 매직넘버 패딩 4곳을 Constants.Design.spacingXS로 통일.
- 접근성 레이블 8곳 추가 (ProfileListView, MainDashboardView, MenuBarView, AppBlockView, TimerView, SettingsView, WebsiteBlockView).
- 무료 한도 카운터에 경고색 적용 (WebsiteBlockView, AppBlockView).
- StatsView 잠금 섹션을 블러 오버레이에서 플레이스홀더 카드로 변경.
- PaywallView 버튼 문구 개선 ("곧 출시 예정" → "App Store 출시 시 이용 가능").
- MenuBarView blockingBadge 애니메이션을 `.symbolEffect(.pulse)`로 통일.
- MenuBarView, CompletedContentView @Query에 `wasCompleted` 필터 추가.

## [2.0.0] - 2026-02-15

### Added
- Freemium 기능 게이팅 인프라 구축 (Pro 구독 대비).
- LicenseManager 서비스: isPro 플래그 + 무료 한도 체크 (사이트 10개, 앱 5개, 프로필 1개, 타이머 2시간, 테마 10개, 통계 기간 제한, 회고 Level 1).
- PaywallView: 기능별 맥락 메시지를 보여주는 업그레이드 안내 시트.
- ProBadge / ProLockedOverlay 컴포넌트.
- 17개 Pro 전용 기능 열거 (ProFeature enum).
- 기능 게이팅 통합: WebsiteBlockView, AppBlockView, ProfileListView, StatsView, SettingsView, TimerView, ThemeManager.
- LicenseManagerTests: 한도 체크 경계값 + Pro 무시 + 기능 열거 전수 테스트.

### Changed
- 모든 Scene 윈도우에 LicenseManager environment 주입.
- 설정 일반 탭에 구독 상태 섹션 추가.
- 무료 사용자에게 타이머 슬라이더 최대값 120분 제한.
- 통계 월간/연간 기간 및 히트맵/트렌드 섹션에 블러 오버레이.
- 테마 선택 시 무료 10개 이후 잠금 + ProBadge.

## [1.5.1] - 2026-02-15

### Changed
- 설정 화면을 4탭 구조로 개편 (일반/집중/연동/고급).
- 핵심 기능 기본값 ON으로 변경: 의도 입력, 회고, 번아웃 방지.
- 프로비저닝 프로파일 에러 수정 (ad-hoc 서명 설정 추가).

### Testing
- 211 tests, 0 failures.

## [1.5.0] - 2026-02-15

### Added
- 회고 Level 2-3: 별점(1-5) + 방해요소 태그 (#SNS #이메일 #전화 #소음 #피곤) 다중 선택.
- 통계 확장: 연간 기간 필터, 히트맵(GitHub 스타일), 의도별 카테고리 분석, 월간 트렌드 라인 차트.
- 데이터 내보내기: CSV/JSON 포맷, 날짜 범위 필터, NSSavePanel 파일 저장.
- 번아웃 방지: 일일 집중 한계 알림(기본 6시간), 균형 점수(집중:휴식 비율), 90분 스트레칭 알림.
- 비주얼 성장 시스템: 🌱→🌿→🌳→🌲→🏞️ 5단계 누적 집중 시간 기반 성장.
- 동기부여 시스템: 10개 마일스톤 배지(스트릭/시간/세션), 25개 명언(KR/EN), 축하 오버레이.
- Badge SwiftData 모델 추가.

### Changed
- ThemeManager에 시맨틱 상태 색상 추가 (warning/success/danger).
- SettingsView body를 computed property로 분리 (67줄 → 20줄).
- BurnoutDetector 매직 넘버를 Constants로 이동.
- v1.5 뷰 7개에 접근성 레이블 추가 (VoiceOver 지원).
- 하드코딩 .orange 색상 14곳을 ThemeManager 경유로 전환.
- RetrospectView의 print() 6곳을 os.Logger로 전환.

### Testing
- 211 tests, 0 failures.
- GrowthManagerTests, BurnoutDetectorTests, ExportServiceTests, MilestoneDetectorTests 신규 추가.

## [1.4.0] - 2026-02-15

### Added
- Shortcuts/Siri 통합: AppIntents로 세션 시작/중지/상태 확인/통계 조회.
- macOS Focus Mode 연동: 시스템 집중 모드 활성화 시 자동 세션 시작.
- 데스크톱 위젯: WidgetKit 기반 집중 상태/스트릭 위젯.
- 앱 디밍: 차단 앱 윈도우 투명도 조절 (0.1~0.8).
- Apple Calendar 동기화: 완료 세션을 Focus You 캘린더에 자동 기록.
- 스케줄 시스템: 요일별 자동 집중 세션 시작.
- Health Check 진단 뷰: DNS/hosts 파일/차단 상태 실시간 검증.
- Private Relay 감지 및 경고 배너.
- 앰비언트 사운드: 빗소리, 카페, 자연, 화이트 노이즈 (AVAudioEngine).
- 의도 입력: 세션 시작 전 집중 목표 기록.
- 회고 Level 1: 이모지 4종 원탭 회고.
- 로그인 시 자동 시작 (ServiceManagement).
- 테마 70+ 확장 (ThemeCatalog.json).

### Changed
- BlockSchedule SwiftData 모델 추가.
- SharedDataProvider로 앱↔위젯 데이터 공유 (App Groups).
- FocusModeObserver로 시스템 집중 모드 감지.
- AppDimmingManager로 NSWindow 레벨 투명도 제어.

### Testing
- 203 tests, 0 failures.

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
