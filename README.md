# Focus You

> Block Distractions & Focus Timer — macOS 메뉴바 집중력 앱

타이머를 시작하면 방해 사이트와 앱이 자동으로 차단되고, 타이머가 끝나면 자동으로 해제됩니다.

## 주요 기능

**타이머**
- **자유 타이머** — 1~240분, 프리셋 또는 슬라이더로 설정 (무료 120분)
- **뽀모도로** — 집중/휴식 사이클, Overflow 모드, 파이차트 UI
- **Flowmodoro** — 자유 집중 → 1/5 비례 자동 휴식

**차단**
- **웹사이트 차단** — 직접 배포판은 hosts/Network Extension, App Store 빌드는 Network Extension 전용
- **앱 차단** — 설치된 앱 목록에서 선택, 실행 시 자동 종료
- **카테고리 프리셋** — SNS, 뉴스, 동영상, 게임 한 번에 추가/제거
- **안전장치 3중** — 앱 종료/크래시/재부팅 시 차단 자동 해제

**생산성**
- **의도 입력** — 세션 시작 전 집중 목표 기록
- **3단계 회고** — 이모지 / 별점 / 방해요소 태그
- **스트릭** — 일일 완료 추적, 연속 기록
- **성장 시스템** — 🌱→🏞️ 5단계 누적 집중 시간 성장
- **마일스톤 배지** — 10개 달성 배지 + 명언

**분석**
- **통계 대시보드** — 일별/주별/월별/연간 집중 시간 차트
- **히트맵** — GitHub 스타일 집중 강도 시각화
- **데이터 내보내기** — CSV/JSON

**복구/지원**
- **데이터 도구** — 설정 진단 섹션에서 [백업 만들기, 백업 미리보기, 설정/세션/배지 선택 가져오기](docs/data-recovery.md)
- **진단 로그 내보내기** — 민감정보를 제외한 로컬 진단 번들을 사용자가 직접 공유

**연동**
- **70+ 테마** — 6개 카테고리
- **Shortcuts/Siri** — 음성으로 세션 제어
- **데스크톱 위젯** — 집중 상태/스트릭 표시
- **macOS Focus Mode** — 시스템 집중 모드 연동
- **Apple Calendar** — 세션 자동 기록
- **스케줄** — 요일별 자동 세션
- **번아웃 방지** — 일일 한계, 균형 점수, 스트레칭 알림

## 설치

### DMG 다운로드 (권장)

1. [최신 Release](https://github.com/jinhyuk9714/FocusYou/releases/latest)에서 배포된 `FocusYou-x.x.x.dmg` 다운로드
2. DMG를 열고 `Focus You.app`을 `Applications` 폴더로 드래그
3. Developer ID 서명 및 Apple notarization을 거친 DMG이므로 일반 앱처럼 실행

### 소스에서 빌드

요구 사항:
- macOS 14.0 (Sonoma) 이상
- Xcode 26.2+ (CI 기준)
- [xcodegen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

```bash
# Xcode CLI 설정 (최초 1회)
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer

# 프로젝트 생성 + 빌드
xcodegen generate
xcodebuild -project FocusYou.xcodeproj -scheme FocusYou -configuration Debug -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build
```

또는 Xcode에서 `FocusYou.xcodeproj`를 열고 Run (Cmd+R).

### 릴리즈 빌드 (DMG 생성)

```bash
./scripts/release.sh
# 결과: build/FocusYou-{version}.dmg
```

서명/공증 없이 배포 흐름만 확인할 때는 테스트용으로만 실행하세요:

```bash
./scripts/release.sh --skip-sign --skip-notarize
```

### Mac App Store 준비 빌드

App Store 제출 경로는 직접 배포 DMG와 분리되어 있습니다. `AppStore` configuration은 sandbox를 켜고 웹 차단을 Network Extension 전용으로 고정합니다.

```bash
xcodebuild -project FocusYou.xcodeproj -scheme FocusYou -configuration AppStore -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build
./scripts/release_appstore.sh --skip-export --allow-provisioning-updates
```

제출 준비 체크리스트와 App Review notes 템플릿은 [docs/app-store-submission.md](docs/app-store-submission.md)를 참고하세요.

개인정보 처리방침은 [docs/privacy-policy.md](docs/privacy-policy.md)에 공개되어 있습니다.

## CI

GitHub Actions에서 macOS 테스트를 자동 실행합니다:

- workflow: `.github/workflows/macos-tests.yml`
- trigger: `push`, `pull_request` (`main`)
- command: `xcodegen generate` + `xcodebuild ... test`

## Debug Fast Timer (개발용)

`Debug` 빌드에서만 시간 축소를 켤 수 있습니다.

앱에서 바로 설정하려면 `설정 > 개발자 > Fast Timer (디버그)`를 사용하세요.

```bash
# ON: 1분을 5초로 축소
defaults write com.sungjh.focusyou debugFastTimerEnabled -bool true
defaults write com.sungjh.focusyou debugSecondsPerMinute -float 5

# OFF
defaults delete com.sungjh.focusyou debugFastTimerEnabled
defaults delete com.sungjh.focusyou debugSecondsPerMinute
```

## 기술 스택

| 영역 | 기술 |
|------|------|
| UI | SwiftUI + MenuBarExtra |
| 데이터 | SwiftData |
| 차단 (웹) | Direct DMG: /etc/hosts 또는 Network Extension / App Store: Network Extension |
| 차단 (앱) | NSWorkspace 알림 기반 감시 |
| 권한 | Direct DMG: osascript + 영구 헬퍼 스크립트 / App Store: App Sandbox + App Group |
| 아키텍처 | MVVM + Service Layer, actor 기반 동시성 |

## 버전 로드맵

| 버전 | 기능 | 상태 |
|------|------|------|
| **v0.1** | 메뉴바 + 자유 타이머 + 차단 | ✅ |
| **v0.3** | 뽀모도로 + 파이차트 타이머 | ✅ |
| **v0.5** | 테마 70+ + 프로필 + 통계 | ✅ |
| **v1.0** | Flowmodoro + 스트릭 + 온보딩 | ✅ |
| **v1.4** | Shortcuts + Widget + Focus Mode | ✅ |
| **v1.5** | 성장 시스템 + 번아웃 방지 + 내보내기 | ✅ |
| **v2.0** | Pro 구독 + Network Extension 인프라 | ✅ |
| **v2.3** | 뷰 리팩토링 + 테스트 304개 | ✅ |
| v3.0 | AI 인사이트 + iOS | 예정 |

변경 내역은 `CHANGELOG.md`를 참고하세요.

## 프로젝트 구조

```
FocusYou/
├── Models/          # SwiftData 모델
├── ViewModels/      # @Observable 상태 관리
├── Views/           # SwiftUI 화면
├── Services/        # 차단, 타이머, 시스템, 알림
├── Extensions/      # 유틸리티 확장
├── Helpers/         # 상수, 에러 타입
└── Resources/       # 에셋, 카테고리 프리셋 JSON
```

## 수동 QA

안정성 시나리오(시작/중지, 완료, 강제종료, 재부팅 복구) 점검:

```bash
./scripts/qa_focusyou_state.sh snapshot
```

핵심 상태 검증 명령:

```bash
./scripts/qa_focusyou_state.sh assert-blocked
./scripts/qa_focusyou_state.sh assert-safetynet-armed
./scripts/qa_focusyou_state.sh assert-helper-ready
./scripts/qa_focusyou_state.sh assert-recovery-pending
./scripts/qa_focusyou_state.sh assert-recovered
```

데이터 도구 산출물 검증:

```bash
./scripts/qa_focusyou_state.sh assert-data-backup /path/to/FocusYouBackup-yyyyMMdd-HHmmss --require-store
./scripts/qa_focusyou_state.sh assert-diagnostics-bundle /path/to/FocusYouDiagnostics-yyyyMMdd-HHmmss
```

DEBUG 앱이 실행 중이면 생성과 검증을 한 번에 수행할 수 있습니다:

```bash
./scripts/qa_focusyou_state.sh qa-smoke-start-stop 120 example.com
./scripts/qa_focusyou_state.sh qa-smoke-completion-cleanup example.com
./scripts/qa_focusyou_state.sh qa-create-data-backup /path/to/output --require-store
./scripts/qa_focusyou_state.sh qa-create-diagnostics-bundle /path/to/output
./scripts/qa_focusyou_state.sh qa-smoke-data-tools /path/to/output
./scripts/qa_focusyou_state.sh qa-create-recovery-import-fixture /path/to/output
./scripts/qa_focusyou_state.sh qa-preview-data-import /path/to/FocusYouBackup-yyyyMMdd-HHmmss
./scripts/qa_focusyou_state.sh qa-validate-data-import /path/to/FocusYouBackup-yyyyMMdd-HHmmss --include-sessions --include-badges
./scripts/qa_focusyou_state.sh qa-smoke-recovery-import /path/to/output
```

상세 체크리스트는 `docs/manual-qa-checklist.md` 참고.

## 라이선스

All rights reserved.
