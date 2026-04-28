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
# 1) 릴리스 후보 동기화 상태 확인
./scripts/release_preflight.sh --stage pre-tag

# 2) 태그 생성
git tag -a vX.Y.Z -m "release: vX.Y.Z"

# 3) 태그 포함 최종 검증
./scripts/release_preflight.sh --stage tagged

# 4) 푸시
git push origin main --tags
```

## 옵션

- `--expected-tag vX.Y.Z`
  - 기본값: top `CHANGELOG.md`에서 자동 계산(`v<version>`)
- `--skip-fetch`
  - `git fetch origin main --tags` 생략
  - 오프라인/특수 상황에서만 사용 권장
