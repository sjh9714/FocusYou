#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
QA_SCRIPT="$ROOT_DIR/scripts/qa_focusyou_state.sh"
TMP_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

fail() {
  echo "FAIL: $1"
  exit 1
}

run_success() {
  local name="$1"
  shift
  local output

  if ! output="$("$@" 2>&1)"; then
    printf '%s\n' "$output"
    fail "$name expected success"
  fi

  if [[ "$output" != PASS:* ]]; then
    printf '%s\n' "$output"
    fail "$name expected PASS output"
  fi

  echo "PASS: $name"
}

run_failure() {
  local name="$1"
  local expected="$2"
  shift 2
  local output

  if output="$("$@" 2>&1)"; then
    printf '%s\n' "$output"
    fail "$name expected failure"
  fi

  if [[ "$output" != *"$expected"* ]]; then
    printf '%s\n' "$output"
    fail "$name expected message containing '$expected'"
  fi

  echo "PASS: $name"
}

make_backup_fixture() {
  local dir="$1"
  local manifest="${2:-valid}"
  local include_store="${3:-yes}"

  mkdir -p "$dir"
  if [[ "$manifest" == "valid" ]]; then
    cat > "$dir/diagnostics.json" <<'JSON'
{
  "copiedFiles": ["default.store"],
  "diagnostics": {
    "supportDirectoryExists": true
  }
}
JSON
  elif [[ "$manifest" == "invalid" ]]; then
    printf '{ invalid json\n' > "$dir/diagnostics.json"
  fi

  if [[ "$include_store" == "yes" ]]; then
    printf 'store fixture\n' > "$dir/default.store"
  fi
}

make_diagnostics_fixture() {
  local dir="$1"
  local manifest="${2:-valid}"
  local include_policy="${3:-yes}"

  mkdir -p "$dir"
  if [[ "$manifest" == "valid" ]]; then
    cat > "$dir/manifest.json" <<'JSON'
{
  "app": {
    "version": "2.3.7"
  },
  "dataStore": {
    "status": "ok"
  }
}
JSON
  elif [[ "$manifest" == "invalid" ]]; then
    printf '{ invalid json\n' > "$dir/manifest.json"
  elif [[ "$manifest" == "home-leak" ]]; then
    printf '{"path":"%s/Library/Application Support/FocusYou"}\n' "$HOME" > "$dir/manifest.json"
  fi

  if [[ "$include_policy" == "yes" ]]; then
    printf 'redaction policy fixture\n' > "$dir/redaction-policy.txt"
  fi
}

valid_backup="$TMP_DIR/FocusYouBackup-20260505-010203"
make_backup_fixture "$valid_backup"
run_success "valid backup bundle" "$QA_SCRIPT" assert-data-backup "$valid_backup" --require-store

missing_manifest="$TMP_DIR/FocusYouBackup-20260505-020304"
make_backup_fixture "$missing_manifest" missing yes
run_failure "backup missing manifest" "diagnostics.json missing" "$QA_SCRIPT" assert-data-backup "$missing_manifest"

invalid_backup="$TMP_DIR/FocusYouBackup-20260505-030405"
make_backup_fixture "$invalid_backup" invalid yes
run_failure "backup invalid JSON" "diagnostics.json is not valid JSON" "$QA_SCRIPT" assert-data-backup "$invalid_backup"

missing_store="$TMP_DIR/FocusYouBackup-20260505-040506"
make_backup_fixture "$missing_store" valid no
run_failure "backup missing required store" "store file not found" "$QA_SCRIPT" assert-data-backup "$missing_store" --require-store

valid_diagnostics="$TMP_DIR/FocusYouDiagnostics-20260505-010203"
make_diagnostics_fixture "$valid_diagnostics"
run_success "valid diagnostics bundle" "$QA_SCRIPT" assert-diagnostics-bundle "$valid_diagnostics"

missing_policy="$TMP_DIR/FocusYouDiagnostics-20260505-020304"
make_diagnostics_fixture "$missing_policy" valid no
run_failure "diagnostics missing policy" "redaction-policy.txt missing" "$QA_SCRIPT" assert-diagnostics-bundle "$missing_policy"

home_leak="$TMP_DIR/FocusYouDiagnostics-20260505-030405"
make_diagnostics_fixture "$home_leak" home-leak yes
run_failure "diagnostics home path leak" "home directory path appears" "$QA_SCRIPT" assert-diagnostics-bundle "$home_leak"

echo "PASS: qa_focusyou_state data tool tests"
