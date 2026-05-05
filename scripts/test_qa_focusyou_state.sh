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
    "version": "2.3.8"
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

make_fake_app_command_environment() {
  local fake_bin="$1"
  local fake_defaults_dir="$2"

  mkdir -p "$fake_bin" "$fake_defaults_dir"

  cat > "$fake_bin/pgrep" <<'SH'
#!/usr/bin/env bash
if [[ -n "${QA_FAKE_PGREP_OUTPUT:-}" ]]; then
  printf '%s\n' "$QA_FAKE_PGREP_OUTPUT"
else
  echo "123 Focus You"
fi
exit 0
SH

  cat > "$fake_bin/uuidgen" <<'SH'
#!/usr/bin/env bash
echo "11111111-2222-3333-4444-555555555555"
SH

  cat > "$fake_bin/defaults" <<'SH'
#!/usr/bin/env bash
set -euo pipefail

store_dir="${QA_FAKE_DEFAULTS_DIR:?}"
mkdir -p "$store_dir"

case "${1:-}" in
  write)
    key="${3:-}"
    value="${5:-}"
    if [[ "$key" == "qaAutomationCommand" ]]; then
      python3 - "$value" > "$store_dir/qaAutomationResult" <<'PY'
import json
import os
import sys

command = json.loads(sys.argv[1])
action = command["action"]
output_path = os.environ.get("QA_FAKE_COMMAND_OUTPUT_PATH", "")
message = f"fake_{action}"
details = None
command_log = os.environ.get("QA_FAKE_COMMAND_LOG")
if command_log:
    with open(command_log, "a", encoding="utf-8") as handle:
        handle.write(json.dumps(command, sort_keys=True) + "\n")

def arm_blocking_state():
    hosts_path = os.environ.get("FOCUSYOU_QA_HOSTS_PATH")
    state_dir = os.environ.get("FOCUSYOU_QA_STATE_DIR")
    launch_agent_path = os.environ.get("FOCUSYOU_QA_LAUNCH_AGENT_PATH")
    domain = command.get("domain", "qa.example")
    if hosts_path:
        with open(hosts_path, "w", encoding="utf-8") as handle:
            handle.write("# fixture hosts\n")
            handle.write("# === Focus You BEGIN ===\n")
            handle.write(f"0.0.0.0\t{domain}\n")
            handle.write("# === Focus You END ===\n")
    if state_dir:
        os.makedirs(state_dir, exist_ok=True)
        for name in ("blocking.active", "hosts.backup"):
            with open(os.path.join(state_dir, name), "w", encoding="utf-8") as handle:
                handle.write("fixture\n")
    if launch_agent_path:
        os.makedirs(os.path.dirname(launch_agent_path), exist_ok=True)
        with open(launch_agent_path, "w", encoding="utf-8") as handle:
            handle.write("fixture\n")

def clear_blocking_state():
    hosts_path = os.environ.get("FOCUSYOU_QA_HOSTS_PATH")
    state_dir = os.environ.get("FOCUSYOU_QA_STATE_DIR")
    launch_agent_path = os.environ.get("FOCUSYOU_QA_LAUNCH_AGENT_PATH")
    if hosts_path:
        with open(hosts_path, "w", encoding="utf-8") as handle:
            handle.write("# fixture hosts\n")
    if state_dir:
        for name in ("blocking.active", "hosts.backup"):
            try:
                os.remove(os.path.join(state_dir, name))
            except FileNotFoundError:
                pass
    if launch_agent_path:
        try:
            os.remove(launch_agent_path)
        except FileNotFoundError:
            pass

if action == "create_data_backup":
    output_path = os.environ.get("QA_FAKE_BACKUP_OUTPUT_PATH", output_path)
elif action == "create_diagnostics_bundle":
    output_path = os.environ.get("QA_FAKE_DIAGNOSTICS_OUTPUT_PATH", output_path)
elif action == "create_recovery_import_fixture_backup":
    output_path = os.environ.get("QA_FAKE_FIXTURE_BACKUP_OUTPUT_PATH", output_path)
elif action in ("preview_data_import", "validate_data_import"):
    output_path = ""
    details = json.loads(os.environ.get("QA_FAKE_IMPORT_DETAILS", "{}"))
elif action == "start_session":
    message = "started"
    arm_blocking_state()
elif action == "complete_session":
    message = "completed"
    clear_blocking_state()

if action in (
    "create_data_backup",
    "create_diagnostics_bundle",
    "create_recovery_import_fixture_backup",
) and not output_path:
    raise SystemExit("missing fake command output path")

if os.environ.get("QA_FAKE_ESCAPE_OUTPUT_SLASHES") == "1":
    output_path = output_path.replace("/", "\\/")

payload = {
    "id": command["id"],
    "status": "ok",
    "message": message,
    "handledAt": 1714867200,
    "outputPath": output_path,
}
if details is not None:
    payload["details"] = details
print(json.dumps(payload))
PY
    else
      printf '%s\n' "$value" > "$store_dir/$key"
    fi
    ;;
  read)
    key="${3:-}"
    if [[ -f "$store_dir/$key" ]]; then
      cat "$store_dir/$key"
    else
      exit 1
    fi
    ;;
  delete)
    rm -f "$store_dir/${3:-}"
    ;;
  *)
    exit 0
    ;;
esac
SH

  chmod +x "$fake_bin/pgrep" "$fake_bin/uuidgen" "$fake_bin/defaults"
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

fake_bin="$TMP_DIR/fake bin"
fake_defaults_dir="$TMP_DIR/fake defaults"
make_fake_app_command_environment "$fake_bin" "$fake_defaults_dir"

snapshot_noise_output=$(
  QA_FAKE_PGREP_OUTPUT=$'401 tee /tmp/focusyou-v2312-fullqa/final-checks.txt\n402 /bin/zsh -c rg FocusYou scripts\n403 /Applications/Focus You.app/Contents/MacOS/Focus You' \
  PATH="$fake_bin:$PATH" \
  "$QA_SCRIPT" snapshot
)
if grep -F "tee /tmp/focusyou-v2312-fullqa" <<<"$snapshot_noise_output" >/dev/null ||
   grep -F "/bin/zsh -c rg FocusYou" <<<"$snapshot_noise_output" >/dev/null; then
  printf '%s\n' "$snapshot_noise_output"
  fail "snapshot app process should ignore command/path-only FocusYou noise"
fi
if ! grep -F "/Applications/Focus You.app/Contents/MacOS/Focus You" <<<"$snapshot_noise_output" >/dev/null; then
  printf '%s\n' "$snapshot_noise_output"
  fail "snapshot app process should include real Focus You executable"
fi
echo "PASS: snapshot app process ignores FocusYou path-only noise"

generated_backup="$TMP_DIR/Generated Output/FocusYouBackup-20260505-050607"
make_backup_fixture "$generated_backup"
QA_FAKE_DEFAULTS_DIR="$fake_defaults_dir" \
QA_FAKE_COMMAND_OUTPUT_PATH="$generated_backup" \
PATH="$fake_bin:$PATH" \
run_success "qa create data backup handles spaced output path" \
  "$QA_SCRIPT" qa-create-data-backup "$TMP_DIR/QA Destination" --require-store

generated_diagnostics="$TMP_DIR/Generated Output/FocusYouDiagnostics-20260505-050607"
make_diagnostics_fixture "$generated_diagnostics"
QA_FAKE_DEFAULTS_DIR="$fake_defaults_dir" \
QA_FAKE_COMMAND_OUTPUT_PATH="$generated_diagnostics" \
PATH="$fake_bin:$PATH" \
run_success "qa create diagnostics bundle handles spaced output path" \
  "$QA_SCRIPT" qa-create-diagnostics-bundle "$TMP_DIR/QA Destination"

fixture_backup="$TMP_DIR/Generated Output/Fixture/FocusYouBackup-20260505-050607"
make_backup_fixture "$fixture_backup"
QA_FAKE_DEFAULTS_DIR="$fake_defaults_dir" \
QA_FAKE_COMMAND_OUTPUT_PATH="$fixture_backup" \
PATH="$fake_bin:$PATH" \
run_success "qa create recovery import fixture handles spaced output path" \
  "$QA_SCRIPT" qa-create-recovery-import-fixture "$TMP_DIR/QA Destination"

escaped_backup="$TMP_DIR/Escaped Output/FocusYouBackup-20260505-050607"
make_backup_fixture "$escaped_backup"
QA_FAKE_DEFAULTS_DIR="$fake_defaults_dir" \
QA_FAKE_COMMAND_OUTPUT_PATH="$escaped_backup" \
QA_FAKE_ESCAPE_OUTPUT_SLASHES=1 \
PATH="$fake_bin:$PATH" \
run_success "qa create data backup handles defaults escaped output path" \
  "$QA_SCRIPT" qa-create-data-backup "$TMP_DIR/QA Destination"

smoke_backup="$TMP_DIR/Generated Output/Smoke/FocusYouBackup-20260505-060708"
smoke_diagnostics="$TMP_DIR/Generated Output/Smoke/FocusYouDiagnostics-20260505-060708"
make_backup_fixture "$smoke_backup"
make_diagnostics_fixture "$smoke_diagnostics"
QA_FAKE_DEFAULTS_DIR="$fake_defaults_dir" \
QA_FAKE_BACKUP_OUTPUT_PATH="$smoke_backup" \
QA_FAKE_DIAGNOSTICS_OUTPUT_PATH="$smoke_diagnostics" \
PATH="$fake_bin:$PATH" \
run_success "qa smoke data tools handles empty backup options" \
  "$QA_SCRIPT" qa-smoke-data-tools "$TMP_DIR/QA Destination"

import_details='{"profileCandidateCount":1,"selectedCandidateCount":1,"siteCandidateCount":2,"appCandidateCount":1,"scheduleCandidateCount":1,"focusSessionCandidateCount":3,"badgeCandidateCount":2,"importedProfileCount":1,"importedSiteCount":2,"importedAppCount":1,"importedScheduleCount":1,"importedFocusSessionCount":3,"importedBadgeCount":2,"skippedFocusSessionCount":0,"skippedBadgeCount":0}'

QA_FAKE_DEFAULTS_DIR="$fake_defaults_dir" \
QA_FAKE_IMPORT_DETAILS="$import_details" \
PATH="$fake_bin:$PATH" \
run_success "qa preview data import parses details" \
  "$QA_SCRIPT" qa-preview-data-import "$valid_backup"

QA_FAKE_DEFAULTS_DIR="$fake_defaults_dir" \
QA_FAKE_IMPORT_DETAILS="$import_details" \
PATH="$fake_bin:$PATH" \
run_success "qa validate data import handles history flags" \
  "$QA_SCRIPT" qa-validate-data-import "$valid_backup" --include-sessions --include-badges

recovery_backup="$TMP_DIR/Generated Output/Recovery/FocusYouBackup-20260505-070809"
recovery_command_log="$TMP_DIR/recovery command log.jsonl"
make_backup_fixture "$recovery_backup"
QA_FAKE_DEFAULTS_DIR="$fake_defaults_dir" \
QA_FAKE_FIXTURE_BACKUP_OUTPUT_PATH="$recovery_backup" \
QA_FAKE_IMPORT_DETAILS="$import_details" \
QA_FAKE_COMMAND_LOG="$recovery_command_log" \
PATH="$fake_bin:$PATH" \
run_success "qa smoke recovery import creates fixture backup and dry-runs import" \
  "$QA_SCRIPT" qa-smoke-recovery-import "$TMP_DIR/QA Destination"

if ! grep -F '"action": "create_recovery_import_fixture_backup"' "$recovery_command_log" >/dev/null; then
  fail "qa smoke recovery import did not create a fixture backup"
fi

if grep -F '"action": "create_data_backup"' "$recovery_command_log" >/dev/null; then
  fail "qa smoke recovery import should not depend on current app data backup"
fi

if [ "$(grep -cF '"action": "validate_data_import"' "$recovery_command_log")" -ne 2 ]; then
  fail "qa smoke recovery import should run default and history dry-run validation"
fi

if ! grep -F '"includeBadges": true' "$recovery_command_log" >/dev/null ||
   ! grep -F '"includeFocusSessions": true' "$recovery_command_log" >/dev/null; then
  fail "qa smoke recovery import should run history dry-run with sessions and badges"
fi

completion_command_log="$TMP_DIR/completion command log.jsonl"
completion_hosts="$TMP_DIR/completion-hosts"
completion_state_dir="$TMP_DIR/completion-state"
completion_launch_agent="$TMP_DIR/completion-launch-agent.plist"
QA_FAKE_DEFAULTS_DIR="$fake_defaults_dir" \
QA_FAKE_COMMAND_LOG="$completion_command_log" \
FOCUSYOU_QA_HOSTS_PATH="$completion_hosts" \
FOCUSYOU_QA_STATE_DIR="$completion_state_dir" \
FOCUSYOU_QA_LAUNCH_AGENT_PATH="$completion_launch_agent" \
PATH="$fake_bin:$PATH" \
run_success "qa smoke completion cleanup sends start and complete commands" \
  "$QA_SCRIPT" qa-smoke-completion-cleanup qa-complete.example

if ! grep -F '"action": "start_session"' "$completion_command_log" >/dev/null ||
   ! grep -F '"action": "complete_session"' "$completion_command_log" >/dev/null; then
  fail "qa smoke completion cleanup should start and complete a session"
fi

if grep -F '"action": "stop_session"' "$completion_command_log" >/dev/null; then
  fail "qa smoke completion cleanup should not use manual stop"
fi

echo "PASS: qa_focusyou_state data tool tests"
