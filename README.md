# Focus You

Focus You는 집중 세션을 시작하는 동안 방해 웹사이트와 앱을 막고, 끝나면 차단을 해제하는 macOS 메뉴바 앱입니다. 단순한 타이머가 아니라 차단, 회고, 통계, 스케줄, 위젯을 한 흐름으로 묶어 “집중을 시작하고 마무리하는 루틴”을 만들도록 설계했습니다.

## 문제 의식

집중 앱은 타이머만 제공하면 실제 방해 요소를 막지 못하고, 차단 앱은 사용자가 왜 집중하려 했는지 기록하기 어렵습니다. Focus You는 세션 시작 전에 의도를 남기고, 세션 중에는 웹사이트와 앱을 차단하며, 종료 후에는 회고와 통계를 통해 다음 세션을 조정할 수 있게 합니다.

## 주요 기능

- 자유 타이머, Pomodoro, Flowmodoro 기반 집중 세션
- 웹사이트 차단: 직접 배포 빌드는 hosts 또는 Network Extension, App Store 빌드는 Network Extension 경로 사용
- 앱 차단: 선택한 앱이 실행되면 감지 후 종료
- SNS, 뉴스, 동영상, 게임 등 카테고리 프리셋 관리
- 세션 의도 입력, 종료 회고, 스트릭, 마일스톤 배지, 성장 단계
- 일/주/월/연 단위 통계, 히트맵, CSV/JSON 내보내기
- Apple Calendar 기록, Shortcuts/App Intents, WidgetKit 위젯, macOS Focus Mode 연동
- 설정 백업, 가져오기 미리보기, 진단 로그 번들 생성

## 기술 스택

| 영역 | 사용 기술 |
| --- | --- |
| 앱 | Swift 6, SwiftUI, MenuBarExtra |
| 데이터 | SwiftData |
| 차단 | NetworkExtension, hosts 파일 경로, NSWorkspace 앱 감시 |
| 시스템 연동 | App Intents, WidgetKit, EventKit, UserNotifications |
| 상태 관리 | MVVM, `@Observable`, actor 기반 서비스 |
| 프로젝트 생성 | XcodeGen |
| 테스트 | XCTest |

## 프로젝트 구조

```text
FocusYou/
├── FocusYou/                  # macOS 앱 본체
│   ├── Models/                # SwiftData 모델
│   ├── ViewModels/            # 앱 상태와 화면 상태
│   ├── Views/                 # SwiftUI 화면
│   ├── Services/              # 차단, 타이머, 통계, 캘린더, 진단 등
│   └── Resources/             # 테마, 프리셋, 로컬라이즈 리소스
├── FocusYouNetworkExtension/  # Network Extension 차단 경로
├── FocusYouWidget/            # macOS 위젯
├── FocusYouTests/             # XCTest 기반 단위 테스트
├── docs/                      # QA, App Store, 개인정보 문서
├── scripts/                   # 릴리스와 QA 자동화
└── project.yml                # XcodeGen 설정
```

## 로컬 빌드

요구 사항:

- macOS 14.0 이상
- Xcode 26.2 기준 프로젝트 설정
- XcodeGen

```bash
brew install xcodegen
xcodegen generate
xcodebuild -project FocusYou.xcodeproj -scheme FocusYou -configuration Debug -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build
```

Xcode에서 실행하려면 `xcodegen generate` 후 생성된 `FocusYou.xcodeproj`를 열고 `FocusYou` scheme을 실행합니다.

## 검증

```bash
xcodebuild -project FocusYou.xcodeproj -scheme FocusYou -configuration Debug -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO test
```

수동 QA 보조 스크립트는 실행 중인 디버그 앱의 차단 상태, 백업, 진단 번들을 확인하는 용도입니다.

```bash
./scripts/qa_focusyou_state.sh snapshot
./scripts/qa_focusyou_state.sh assert-blocked
./scripts/qa_focusyou_state.sh assert-safetynet-armed
```

## 배포 메모

직접 배포용 DMG와 App Store 제출용 설정이 분리되어 있습니다. `AppStore` configuration은 sandbox와 App Group을 사용하고, 웹 차단은 Network Extension 경로를 사용하도록 구성되어 있습니다.

```bash
./scripts/release.sh
./scripts/release.sh --skip-sign --skip-notarize
./scripts/release_appstore.sh --skip-export --allow-provisioning-updates
```

개인정보 처리방침과 App Store 제출 메모는 `docs/` 아래 문서에 정리되어 있습니다.

## 라이선스

All rights reserved.
