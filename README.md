# Focus You

> Block Distractions & Focus Timer — macOS 메뉴바 집중력 앱

타이머를 시작하면 방해 사이트와 앱이 자동으로 차단되고, 타이머가 끝나면 자동으로 해제됩니다.

## 주요 기능

- **자유 타이머** — 1~180분, 프리셋(25/50/90분) 또는 슬라이더로 설정
- **웹사이트 차단** — hosts 파일 기반, IPv4+IPv6 동시 차단
- **앱 차단** — 설치된 앱 목록에서 선택, 실행 시 자동 종료
- **카테고리 프리셋** — SNS, 뉴스, 동영상, 게임 한 번에 추가/제거
- **비밀번호 최초 1회** — 영구 헬퍼 스크립트로 이후 비밀번호 불필요
- **안전장치 3중** — 앱 종료/크래시/재부팅 시 차단 자동 해제
- **메뉴바 전용** — Dock에 표시되지 않는 가벼운 앱

## 요구 사항

- macOS 14.0 (Sonoma) 이상
- Xcode 15+
- [xcodegen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

## 빌드

```bash
# Xcode CLI 설정 (최초 1회)
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer

# 프로젝트 생성 + 빌드
xcodegen generate
xcodebuild -scheme FocusYou -configuration Debug build
```

또는 Xcode에서 `FocusYou.xcodeproj`를 열고 Run (Cmd+R).

## CI

GitHub Actions에서 macOS 테스트를 자동 실행합니다:

- workflow: `.github/workflows/macos-tests.yml`
- trigger: `push`, `pull_request` (`develop`, `main`)
- command: `xcodegen generate` + `xcodebuild ... test`

## Debug Fast Timer (개발용)

`Debug` 빌드에서만 시간 축소를 켤 수 있습니다.

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
| 차단 (웹) | /etc/hosts 파일 수정 |
| 차단 (앱) | NSWorkspace 알림 기반 감시 |
| 권한 | osascript + 영구 헬퍼 스크립트 |
| 아키텍처 | MVVM + Service Layer, actor 기반 동시성 |

## 버전 로드맵

| 버전 | 기능 | 상태 |
|------|------|------|
| **v0.1** | 메뉴바 + 자유 타이머 + 차단 | ✅ 완료 |
| v0.3 | 뽀모도로 + 파이차트 타이머 | 예정 |
| v0.5 | 테마 10종 + 프로필 + 통계 | 예정 |
| v1.0 | Flowmodoro + 스트릭 + 온보딩 | 예정 |
| v2.0 | Pro 구독 + Network Extension | 예정 |

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

상세 체크리스트는 `docs/manual-qa-checklist.md` 참고.

## 라이선스

All rights reserved.
