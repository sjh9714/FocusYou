#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

CHANGELOG_PATH="$ROOT_DIR/CHANGELOG.md"
STAGE="pre-tag"
EXPECTED_TAG=""
SKIP_FETCH=0

usage() {
  cat <<'EOF'
Usage:
  ./scripts/release_preflight.sh [--stage pre-tag|tagged] [--expected-tag vX.Y.Z] [--skip-fetch]

Description:
  Release preflight checks for branch/tag/changelog consistency.

Checks:
  1) main/develop branch synchronization policy
  2) expected release tag matches top CHANGELOG version
  3) (tagged stage) tag points to intended release commit

Stages:
  --stage pre-tag
    - Requires main == develop
    - Requires top CHANGELOG version is valid
    - Requires expected tag value matches top CHANGELOG version
    - Tag may be missing (pre-tag state)

  --stage tagged
    - Includes all pre-tag checks
    - Requires expected tag exists
    - Requires tag commit == main HEAD == develop HEAD
EOF
}

info() {
  printf 'INFO: %s\n' "$1"
}

pass() {
  printf 'PASS: %s\n' "$1"
}

fail() {
  printf 'FAIL: %s\n' "$1"
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --stage)
      [[ $# -ge 2 ]] || fail "--stage requires a value"
      STAGE="$2"
      shift 2
      ;;
    --expected-tag)
      [[ $# -ge 2 ]] || fail "--expected-tag requires a value"
      EXPECTED_TAG="$2"
      shift 2
      ;;
    --skip-fetch)
      SKIP_FETCH=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      fail "unknown argument: $1"
      ;;
  esac
done

if [[ "$STAGE" != "pre-tag" && "$STAGE" != "tagged" ]]; then
  fail "invalid --stage value: $STAGE (use pre-tag|tagged)"
fi

command -v git >/dev/null 2>&1 || fail "git command not found"

if [[ ! -f "$CHANGELOG_PATH" ]]; then
  fail "CHANGELOG not found at $CHANGELOG_PATH"
fi

if [[ "$SKIP_FETCH" -eq 0 ]]; then
  info "fetching latest refs (origin/main, origin/develop, tags)"
  git fetch origin main develop --tags >/dev/null 2>&1 || fail "git fetch failed"
fi

git rev-parse --verify main >/dev/null 2>&1 || fail "local branch 'main' not found"
git rev-parse --verify develop >/dev/null 2>&1 || fail "local branch 'develop' not found"
git rev-parse --verify origin/main >/dev/null 2>&1 || fail "remote ref 'origin/main' not found"
git rev-parse --verify origin/develop >/dev/null 2>&1 || fail "remote ref 'origin/develop' not found"

main_head="$(git rev-parse main)"
develop_head="$(git rev-parse develop)"
origin_main_head="$(git rev-parse origin/main)"
origin_develop_head="$(git rev-parse origin/develop)"

[[ "$main_head" == "$origin_main_head" ]] || fail "local main != origin/main (pull/push first)"
[[ "$develop_head" == "$origin_develop_head" ]] || fail "local develop != origin/develop (pull/push first)"

if [[ "$main_head" != "$develop_head" ]]; then
  divergence="$(git rev-list --left-right --count main...develop)"
  fail "main/develop not synchronized (main...develop=$divergence)"
fi
pass "main and develop are synchronized"

top_changelog_version="$(
  sed -nE 's/^## \[([0-9]+\.[0-9]+\.[0-9]+)\].*$/\1/p' "$CHANGELOG_PATH" | head -n 1
)"

[[ -n "$top_changelog_version" ]] || fail "failed to parse top version from CHANGELOG.md"
pass "top CHANGELOG version = $top_changelog_version"

if [[ -z "$EXPECTED_TAG" ]]; then
  EXPECTED_TAG="v$top_changelog_version"
fi

if [[ "$EXPECTED_TAG" != v* ]]; then
  EXPECTED_TAG="v$EXPECTED_TAG"
fi

tag_version="${EXPECTED_TAG#v}"
[[ "$tag_version" == "$top_changelog_version" ]] || fail "tag/version mismatch (tag=$EXPECTED_TAG changelog=$top_changelog_version)"
pass "expected tag matches top CHANGELOG version ($EXPECTED_TAG)"

if git rev-parse --verify "refs/tags/$EXPECTED_TAG" >/dev/null 2>&1; then
  tag_commit="$(git rev-list -n 1 "$EXPECTED_TAG")"
  if [[ "$tag_commit" != "$main_head" ]]; then
    fail "tag $EXPECTED_TAG points to $(git rev-parse --short "$tag_commit"), expected $(git rev-parse --short "$main_head")"
  fi
  pass "tag $EXPECTED_TAG points to release commit ($(git rev-parse --short "$tag_commit"))"
else
  if [[ "$STAGE" == "tagged" ]]; then
    fail "tag $EXPECTED_TAG not found (tagged stage requires existing tag)"
  fi
  info "tag $EXPECTED_TAG not found yet (allowed in pre-tag stage)"
fi

pass "release preflight checks passed (stage=$STAGE)"
