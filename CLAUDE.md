# CLAUDE.md — Focus You 프로젝트 규칙

> 이 파일은 Claude Code가 프로젝트 작업 시 반드시 따라야 할 규칙과 컨벤션을 정의합니다.

## 프로젝트 개요

**Focus You**는 macOS 메뉴바 집중력 앱입니다.
핵심: **타이머 시작 → 차단 자동 활성, 타이머 종료 → 차단 자동 해제.**
7개 경쟁 앱(1Focus, Be Focused, Session, Ultimate Focus, Focused Work, focusedOS, Forest)의
장점을 단계적으로 흡수하되, 매 버전이 완성된 제품으로 출시됩니다.

- **앱 이름**: Focus You
  - App Store 부제: "Block Distractions & Focus Timer"
  - 대안: Focus on You
- **번들 ID**: com.yourname.focusyou
- **타겟**: macOS 14.0+ (Sonoma 이상)
- **언어**: Swift 5.9+
- **UI**: SwiftUI (AppKit 사용 최소화)
- **아키텍처**: MVVM + Service Layer
- **디자인 철학**: "출시된 제품 > 완벽한 계획." 프로그레시브 디스클로저. 집중을 방해하는 집중 앱이 되지 말 것.

---

## 기술 스택 & 의존성

### 프레임워크 (Apple 네이티브만 사용)

v0.1~v1.0에서 사용:
- **SwiftUI** — 모든 UI
- **SwiftData** — 데이터 영속화 (macOS 14+)
- **Combine** — 리액티브 데이터 흐름
- **UserNotifications** — 알림
- **Charts** — 통계 차트 (v0.5+, Swift Charts, 사용 중)

v1.x 이후 추가:
- **ServiceManagement** — 로그인 시 자동 시작
- **StoreKit 2** — 인앱 구독 (v2.0)
- **WidgetKit** — 데스크톱 위젯 (v1.x)
- **AppIntents** — Shortcuts/Siri (v1.x)
- **CoreML** — AI 인사이트 (v3.0)
- **Network Extension** — App Store 차단 (v2.0)

### 데이터 저장
- **SwiftData** — 세션 기록, 차단 프로필, 스케줄, 회고록
- **UserDefaults / @AppStorage** — 간단한 설정값
- **JSON 파일** — 프리셋 카테고리, 테마 데이터 (번들 리소스)

### 외부 라이브러리
- 가능한 한 사용하지 않는다
- 정말 필요한 경우에만 SPM으로 추가
- CocoaPods, Carthage 사용 금지

---

## 코드 컨벤션

### 네이밍
```
타입: PascalCase → FocusSession, TimerState
변수/함수: camelCase → startBlocking(), remainingTime
상수: camelCase → let maxBlockDuration
파일명 = 타입명 → FocusSession.swift
View: ~View → TimerView.swift
ViewModel: ~ViewModel → TimerViewModel.swift
Service/Manager: ~Service 또는 ~Manager → BlockingService.swift
```

### Swift 스타일 핵심 규칙
1. guard let 우선, Force unwrap(!) 절대 금지
2. 매직 넘버 금지 → Constants.swift에 상수 정의
3. 축약 금지 → `dur` ❌ `duration` ✅
4. 외부 불필요 노출 → private/fileprivate
5. async/await 사용, completion handler 지양
6. Strict Concurrency 대비 (@Sendable, actor 등)

### SwiftUI 컨벤션
- View body 50줄 초과 시 → 하위 View로 분리
- 모든 View에 `#Preview { }` 필수
- 모든 색상은 ThemeManager 경유 (하드코딩 금지)
- 애니메이션: .spring() 또는 .easeInOut 사용

### 에러 핸들링
```swift
enum FocusYouError: LocalizedError {
    case hostsFileAccessDenied
    case appNotFound(bundleId: String)
    case timerAlreadyRunning
    case subscriptionRequired(feature: String)
    var errorDescription: String? { /* ... */ }
}
```

### 로깅
```swift
import os
private let logger = Logger(subsystem: "com.yourname.focusyou", category: "Timer")
// print() 금지, os.Logger 사용
```

---

## 프로젝트 구조

> v0.5 기준 실제 파일 구조. 이후 버전에서 추가되는 파일은 해당 버전 개발 시 생성.

```
FocusYou/
├── FocusYouApp.swift                    # @main, MenuBarExtra + AppDelegate
├── Info.plist
│
├── Models/                              # SwiftData (iCloud 호환 설계)
│   ├── BlockProfile.swift               # 차단 프로필
│   ├── BlockedSite.swift                # 차단 웹사이트
│   ├── BlockedApp.swift                 # 차단 앱
│   ├── FocusSession.swift               # 세션 기록 (모든 모드 공통)
│   └── AppTheme.swift                   # 테마 모델
│
├── ViewModels/
│   ├── AppState.swift                   # @Observable 전역 상태
│   ├── TimerViewModel.swift
│   ├── BlockListViewModel.swift
│   ├── ProfileViewModel.swift           # v0.5+
│   ├── StatsViewModel.swift             # v0.5+
│   └── SettingsViewModel.swift
│
├── Views/
│   ├── MenuBar/
│   │   └── MenuBarView.swift            # 메뉴바 팝오버 메인
│   ├── Main/
│   │   └── MainDashboardView.swift      # 메인 대시보드 윈도우 (v0.5+)
│   ├── Timer/
│   │   ├── TimerView.swift              # 타이머 영역 (모드별 분기)
│   │   ├── PieChartTimerView.swift      # 파이차트 (v0.3+)
│   │   └── PomodoroConfigView.swift     # 뽀모도로 설정 (v0.3+)
│   ├── BlockList/
│   │   ├── BlockListView.swift
│   │   ├── WebsiteBlockView.swift
│   │   ├── AppBlockView.swift
│   │   └── CategoryPickerView.swift
│   ├── Profile/                         # v0.5+
│   │   ├── ProfileListView.swift
│   │   └── ProfileEditorView.swift
│   ├── Stats/                           # v0.5+
│   │   └── StatsView.swift              # 기본 통계 (Swift Charts)
│   ├── Settings/
│   │   └── SettingsView.swift           # 설정 + 테마 선택 통합
│   ├── Onboarding/                      # v1.0 예정
│   │   └── OnboardingView.swift
│   └── Components/
│       ├── TimePickerView.swift
│       └── StreakBadgeView.swift         # v1.0 예정
│
├── Services/
│   ├── Blocking/
│   │   ├── WebsiteBlocker.swift         # 프로토콜 (v1/v2 추상화)
│   │   ├── HostsFileBlocker.swift       # v1 구현 (hosts 파일)
│   │   ├── AppBlocker.swift
│   │   └── BlockingCoordinator.swift    # 차단 통합 (actor)
│   ├── Timer/
│   │   ├── FreeTimer.swift              # 자유 타이머 (슬립/웨이크 대응)
│   │   ├── PomodoroEngine.swift         # v0.3+ (Overflow 포함)
│   │   └── FlowmodoroEngine.swift       # v1.0 예정
│   ├── System/
│   │   ├── HostsFileManager.swift       # hosts 파일 마커 관리
│   │   ├── PrivilegedHelper.swift       # osascript 권한 상승
│   │   └── DNSManager.swift             # DNS 캐시 플러시
│   ├── Theme/
│   │   └── ThemeManager.swift           # v0.5+ 테마 단일 진실 원천
│   └── Notification/
│       └── NotificationService.swift
│
├── Resources/
│   ├── Assets.xcassets
│   ├── Presets/                          # 카테고리 차단 프리셋 (JSON)
│   └── Themes/ThemeCatalog.json         # v0.5+
│
├── Extensions/
│   ├── Date+Extensions.swift
│   ├── String+Extensions.swift
│   ├── Color+Theme.swift
│   └── View+Modifiers.swift
│
└── Helpers/
    ├── Constants.swift
    └── FocusYouError.swift              # LocalizedError 열거형

FocusYouTests/
├── BlockingCoordinatorTests.swift
├── HostsFileManagerTests.swift
├── NotificationServiceSettingsTests.swift
├── PomodoroEngineTests.swift
├── SettingsViewModelTests.swift
├── StringExtensionsTests.swift
└── ThemeManagerTests.swift

# v1.x 이후 추가 예정 (필요 시 생성)
# Services/Sound/SoundManager.swift        ← 앰비언트 사운드
# Services/Schedule/ScheduleManager.swift  ← 스케줄
# Services/Automation/ShortcutsProvider.swift ← Shortcuts
# Services/Subscription/SubscriptionManager.swift ← v2.0 Pro
# Views/Retrospect/                        ← 회고 시스템
# Views/Widgets/                           ← 데스크톱 위젯
```

---

## 작업 규칙

### DO
1. 모든 View에 `#Preview { }` 작성
2. 하나의 파일 = 하나의 책임
3. 복잡한 로직에 한국어 주석
4. 에러 핸들링 + 사용자 피드백
5. VoiceOver 접근성 레이블
6. 다크모드/라이트모드 테스트
7. design.md 버전 로드맵 순서 준수 (현재 개발 중인 버전의 범위만 구현)
8. 테마 색상은 반드시 ThemeManager 경유

### DON'T
1. 외부 라이브러리 무단 추가
2. Force unwrap (!)
3. 전역 변수 남용
4. 매직 넘버
5. body 50줄 초과 View
6. Storyboard/XIB
7. print() 디버깅
8. Finder, 시스템 설정을 기본 차단에 포함
9. 하드코딩 색상
10. 동기 파일/네트워크 작업

---

## 버전 관리

### 버전 체계 (Semantic Versioning)

`Major.Minor.Patch` — 예: v1.2.3

```
v0.x.x  — 정식 출시 전. 자유롭게 변경 가능.
v1.0.0  — 첫 공개 출시 (Gumroad 등)
v1.x.0  — 기능 추가 (Minor)
v1.x.x  — 버그 수정 (Patch)
v2.0.0  — Pro 구독 + App Store 출시
v3.0.0  — AI + iOS 확장
```

Focus You 버전 계획:
```
v0.1.0  메뉴바 + 자유 타이머 + 차단          (내부 사용)
v0.3.0  뽀모도로 + 파이차트                   (지인 테스트)
v0.5.0  테마 + 프로필 + 통계                  (베타 배포)
v1.0.0  Flowmodoro + 스트릭 + 온보딩          (첫 공개 출시)
v1.x.0  의도 입력, 회고, 사운드 등            (피드백 기반)
v2.0.0  Pro 구독 + Network Extension          (App Store)
v3.0.0  AI 인사이트 + iOS                     (플랫폼 확장)
```

### Git 브랜치 전략

```
main     — 항상 동작하는 코드. 직접 커밋 금지.
develop  — 일상 개발 브랜치.
feature/ — 기능 개발: develop에서 분기 → develop에 머지
hotfix/  — 긴급 수정: main에서 분기 → main + develop에 머지

흐름:
main:     v0.1.0 --------→ v0.3.0 --------→ v1.0.0
              ↑                ↑                ↑
develop:  ──●──●──●──머지──●──●──●──머지──●──●──머지
              ↑     ↑           ↑
feature:  pomodoro  pie-chart   flowmodoro
```

버전 태그:
```bash
git checkout main
git merge develop
git tag v0.1.0
git push origin main --tags
```

### 커밋 메시지 규칙

```
feat: 뽀모도로 Overflow 모드 추가
fix: 타이머 백그라운드에서 멈추는 버그 수정
refactor: BlockingCoordinator actor 전환
ui: 파이차트 드래그 인터랙션 구현
docs: README 설치 가이드 추가
chore: SwiftLint 설정 추가
```

각 버전 출시 시 GitHub Releases에 변경 로그 작성.

---

## 디자인 영감 출처

> 상세 경쟁 분석은 design.md 부록 A 참조.

| 앱 | 핵심 흡수 |
|----|----------|
| **1Focus** | 차단 메커니즘 |
| **Be Focused** | 뽀모도로 UX |
| **Session** | 의도 입력, Overflow, Shortcuts, 분석 |
| **Ultimate Focus** | 파이차트 타이머, 70+ 테마, 회고 |
| **Focused Work** | Flowmodoro |
| **focusedOS** | 앱 딤, 앰비언트 사운드 |
| **Forest** | 스트릭, 비주얼 성장 |

**Focus You만의 차별화:** 차단+타이머 완전 연동, Flowmodoro 통합, 프로그레시브 디스클로저

---

## 참고 문서

- `design.md` — 상세 기능 명세, UX 설계, 수익 모델
- Apple HIG: https://developer.apple.com/design/human-interface-guidelines/
- SwiftUI: https://developer.apple.com/documentation/swiftui/
- StoreKit 2: https://developer.apple.com/documentation/storekit/
- AppIntents: https://developer.apple.com/documentation/appintents/
