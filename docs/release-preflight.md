# Release Preflight

`scripts/release_preflight.sh`는 릴리스 직전 main/태그/체인지로그 불일치를 자동으로 차단합니다.

## 왜 필요한가

- `main`과 원격 기준선이 어긋난 상태에서 잘못된 커밋으로 태그를 찍는 실수 방지
- `CHANGELOG.md` 최상단 버전과 태그 버전 불일치 방지
- 태그가 실제 릴리스 커밋(`main HEAD`)을 가리키는지 검증

## 사용법

```bash
./scripts/release_preflight.sh --stage pre-tag
```

- `pre-tag` 단계:
  - 로컬 `main`과 `origin/main` 동기화 확인
  - top `CHANGELOG.md` 버전 파싱
  - 예상 태그(`vX.Y.Z`)와 changelog 버전 일치 확인
  - 태그가 아직 없어도 통과 (릴리스 직전 상태)

```bash
./scripts/release_preflight.sh --stage tagged
```

- `tagged` 단계:
  - `pre-tag` 체크 + 아래 추가
  - 태그 존재 필수
  - 태그 커밋 == `main HEAD`

## 권장 릴리스 순서

```bash
# 1) 버전/CHANGELOG 정리 후 main에 커밋/푸시
xcodegen generate
git add project.yml FocusYou.xcodeproj CHANGELOG.md
git commit -m "chore: prepare vX.Y.Z release"
git push origin main

# 2) 태그 전 릴리스 후보 정합성 확인
./scripts/release_preflight.sh --stage pre-tag --expected-tag vX.Y.Z

# 3) signed/notarized DMG 생성
./scripts/release.sh

# 4) 검증된 main HEAD에 태그 생성/푸시
git tag -a vX.Y.Z -m "vX.Y.Z"
git push origin vX.Y.Z
./scripts/release_preflight.sh --stage tagged --expected-tag vX.Y.Z

# 5) GitHub Release 생성과 공개 asset smoke
gh release create vX.Y.Z build/FocusYou-X.Y.Z.dmg --title "FocusYou vX.Y.Z" --notes-file /path/to/notes.md --latest
gh release download vX.Y.Z --repo jinhyuk9714/FocusYou --pattern "FocusYou-X.Y.Z.dmg"
```

공개 asset smoke에서는 GitHub Release의 SHA256 digest와 다운로드한 DMG를 비교하고, `spctl`, DMG mount, 앱 `codesign --verify`, 임시 설치 확인을 수행합니다.

## Mac App Store 경로

GitHub Release DMG와 Mac App Store 제출은 별도 경로입니다. App Store 제출 후보는 `AppStore` configuration으로 archive/export하며, 태그/DMG preflight 대신 App Store Connect validation과 sandbox/Network Extension QA를 기준으로 삼습니다.

```bash
xcodegen generate
xcodebuild -project FocusYou.xcodeproj -scheme FocusYou -configuration AppStore -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build
./scripts/release_appstore.sh --skip-export --allow-provisioning-updates
```

실제 제출 준비와 App Review notes는 `docs/app-store-submission.md`를 기준으로 확인합니다. 직접 배포판의 `scripts/release.sh` 경로는 그대로 유지합니다.

## 옵션

- `--expected-tag vX.Y.Z`
  - 기본값: top `CHANGELOG.md`에서 자동 계산(`v<version>`)
- `--skip-fetch`
  - `git fetch origin main --tags` 생략
  - 오프라인/특수 상황에서만 사용 권장
