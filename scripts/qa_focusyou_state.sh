#!/usr/bin/env bash

set -u

BEGIN_MARKER="# === Focus You BEGIN ==="
END_MARKER="# === Focus You END ==="

STATE_DIR="${FOCUSYOU_QA_STATE_DIR:-$HOME/Library/Application Support/FocusYou}"
INDICATOR_PATH="$STATE_DIR/blocking.active"
BACKUP_PATH="$STATE_DIR/hosts.backup"
LAUNCH_AGENT_PATH="${FOCUSYOU_QA_LAUNCH_AGENT_PATH:-$HOME/Library/LaunchAgents/com.sungjh.focusyou.cleanup.plist}"
HELPER_PATH="${FOCUSYOU_QA_HELPER_PATH:-/usr/local/bin/focusyou-helper}"
HOSTS_PATH="${FOCUSYOU_QA_HOSTS_PATH:-/etc/hosts}"
APP_BUNDLE_ID="com.sungjh.focusyou"
QA_AUTOMATION_ENABLED_KEY="qaAutomationEnabled"
QA_AUTOMATION_COMMAND_KEY="qaAutomationCommand"
QA_AUTOMATION_RESULT_KEY="qaAutomationResult"
QA_COMMAND_TIMEOUT_SECONDS=20
APP_COMMAND_OUTPUT_PATH=""
APP_COMMAND_RESULT_JSON=""

print_header() {
  echo "=== FocusYou QA Snapshot ($(date '+%Y-%m-%d %H:%M:%S')) ==="
}

file_state() {
  local path="$1"
  if [ -e "$path" ]; then
    echo "exists: $path"
    ls -l "$path"
  else
    echo "missing: $path"
  fi
}

hosts_marker_count() {
  if [ ! -r "$HOSTS_PATH" ]; then
    echo "unreadable"
    return
  fi
  local begin_count
  local end_count
  begin_count="$(grep -cF "$BEGIN_MARKER" "$HOSTS_PATH" || true)"
  end_count="$(grep -cF "$END_MARKER" "$HOSTS_PATH" || true)"
  echo "begin=$begin_count end=$end_count"
}

hosts_marker_block() {
  if [ ! -r "$HOSTS_PATH" ]; then
    echo "hosts unreadable: $HOSTS_PATH"
    return
  fi
  awk -v begin="$BEGIN_MARKER" -v end="$END_MARKER" '
    $0 == begin { in_block=1; print; next }
    in_block { print }
    $0 == end { in_block=0 }
  ' "$HOSTS_PATH"
}

helper_sudo_state() {
  if [ ! -x "$HELPER_PATH" ]; then
    echo "helper missing or not executable: $HELPER_PATH"
    return
  fi
  if sudo -n -l "$HELPER_PATH" >/dev/null 2>&1; then
    echo "sudo NOPASSWD check: OK"
  else
    echo "sudo NOPASSWD check: FAILED"
  fi
}

helper_nopasswd_ok() {
  [ -x "$HELPER_PATH" ] && sudo -n -l "$HELPER_PATH" >/dev/null 2>&1
}

app_process_matches() {
  pgrep -ifl "Focus You|FocusYou" 2>/dev/null | awk '
    {
      command = $0
      sub(/^[0-9]+[[:space:]]+/, "", command)
      if (command == "Focus You" ||
          command ~ /(^|\/)Focus You\.app\/Contents\/MacOS\/Focus You([[:space:]]|$)/) {
        print
      }
    }
  '
}

app_process_state() {
  local matches
  matches="$(app_process_matches)"
  if [ -n "$matches" ]; then
    echo "app process:"
    printf '%s\n' "$matches"
  else
    echo "app process: not running"
  fi
}

json_extract_string() {
  local json="$1"
  local key="$2"
  JSON_INPUT="$json" python3 - "$key" <<'PY' 2>/dev/null
import json
import os
import sys

try:
    payload = json.loads(os.environ.get("JSON_INPUT", ""))
except json.JSONDecodeError:
    sys.exit(0)

value = payload.get(sys.argv[1])
if isinstance(value, str):
    value = value.replace("\\/", "/")
    print(value)
PY
}

json_extract_detail_int() {
  local json="$1"
  local key="$2"
  JSON_INPUT="$json" python3 - "$key" <<'PY' 2>/dev/null
import json
import os
import sys

try:
    payload = json.loads(os.environ.get("JSON_INPUT", ""))
except json.JSONDecodeError:
    sys.exit(0)

details = payload.get("details")
if not isinstance(details, dict):
    sys.exit(0)

value = details.get(sys.argv[1])
if isinstance(value, int):
    print(value)
PY
}

build_app_command_json() {
  local command_id="$1"
  local action="$2"
  local duration_seconds="${3:-}"
  local domain="${4:-}"
  local destination_path="${5:-}"
  local backup_path="${6:-}"
  local include_focus_sessions="${7:-}"
  local include_badges="${8:-}"

  python3 - "$command_id" "$action" "$duration_seconds" "$domain" "$destination_path" "$backup_path" "$include_focus_sessions" "$include_badges" <<'PY'
import json
import sys

(
    command_id,
    action,
    duration_seconds,
    domain,
    destination_path,
    backup_path,
    include_focus_sessions,
    include_badges,
) = sys.argv[1:9]
payload = {
    "id": command_id,
    "action": action,
}

if duration_seconds:
    payload["durationSeconds"] = float(duration_seconds)
if domain:
    payload["domain"] = domain
if destination_path:
    payload["destinationPath"] = destination_path
if backup_path:
    payload["backupPath"] = backup_path
if include_focus_sessions:
    payload["includeFocusSessions"] = include_focus_sessions.lower() == "true"
if include_badges:
    payload["includeBadges"] = include_badges.lower() == "true"

print(json.dumps(payload, separators=(",", ":")))
PY
}

ensure_app_running() {
  if [ -n "$(app_process_matches)" ]; then
    return 0
  fi
  echo "FAIL: Focus You app process not found (run app from Xcode first)"
  return 1
}

send_app_command() {
  local action="$1"
  local duration_seconds="${2:-}"
  local domain="${3:-}"
  local destination_path="${4:-}"
  local command_id
  local command_json
  local max_loops
  local result_json
  local result_id
  local result_status
  local result_message
  local result_output_path
  local i

  command_id="$(uuidgen | tr '[:upper:]' '[:lower:]')"
  APP_COMMAND_OUTPUT_PATH=""
  APP_COMMAND_RESULT_JSON=""

  case "$action" in
    start_session)
      command_json="$(build_app_command_json "$command_id" "$action" "$duration_seconds" "$domain")"
      ;;
    stop_session|reset_to_idle|complete_session)
      command_json="$(build_app_command_json "$command_id" "$action")"
      ;;
    create_data_backup|create_diagnostics_bundle|create_recovery_import_fixture_backup)
      command_json="$(build_app_command_json "$command_id" "$action" "" "" "$destination_path")"
      ;;
    preview_data_import)
      command_json="$(build_app_command_json "$command_id" "$action" "" "" "" "$destination_path")"
      ;;
    validate_data_import)
      command_json="$(build_app_command_json "$command_id" "$action" "" "" "" "$destination_path" "${5:-}" "${6:-}")"
      ;;
    *)
      echo "FAIL: unknown app command action ($action)"
      return 1
      ;;
  esac

  defaults write "$APP_BUNDLE_ID" "$QA_AUTOMATION_ENABLED_KEY" -bool true
  defaults delete "$APP_BUNDLE_ID" "$QA_AUTOMATION_RESULT_KEY" >/dev/null 2>&1 || true
  defaults write "$APP_BUNDLE_ID" "$QA_AUTOMATION_COMMAND_KEY" -string "$command_json"

  max_loops=$((QA_COMMAND_TIMEOUT_SECONDS * 5))
  for ((i = 0; i < max_loops; i++)); do
    result_json="$(defaults read "$APP_BUNDLE_ID" "$QA_AUTOMATION_RESULT_KEY" 2>/dev/null || true)"
    if [ -n "$result_json" ]; then
      result_id="$(json_extract_string "$result_json" "id")"
      if [ "$result_id" = "$command_id" ]; then
        result_status="$(json_extract_string "$result_json" "status")"
        result_message="$(json_extract_string "$result_json" "message")"
        result_output_path="$(json_extract_string "$result_json" "outputPath")"
        APP_COMMAND_RESULT_JSON="$result_json"
        if [ "$result_status" = "ok" ]; then
          APP_COMMAND_OUTPUT_PATH="$result_output_path"
          echo "PASS: app command '$action' succeeded ($result_message)"
          return 0
        fi
        echo "FAIL: app command '$action' failed ($result_message)"
        return 1
      fi
    fi
    sleep 0.2
  done

  echo "FAIL: app command '$action' timed out (DEBUG build + running app required)"
  return 1
}

qa_start_session() {
  local duration_seconds="${1:-120}"
  local domain="${2:-example.com}"

  ensure_app_running || return 1
  send_app_command "start_session" "$duration_seconds" "$domain"
}

qa_stop_session() {
  ensure_app_running || return 1
  send_app_command "stop_session"
}

qa_complete_session() {
  ensure_app_running || return 1
  send_app_command "complete_session"
}

qa_reset_to_idle() {
  ensure_app_running || return 1
  send_app_command "reset_to_idle"
}

qa_smoke_start_stop() {
  local duration_seconds="${1:-120}"
  local domain="${2:-example.com}"

  qa_start_session "$duration_seconds" "$domain" || return 1
  assert_blocked || return 1
  qa_stop_session || return 1
  assert_clean
}

qa_smoke_completion_cleanup() {
  local domain="${1:-qa-completion.focusyou.example}"

  qa_start_session 60 "$domain" || return 1
  assert_safetynet_armed || return 1
  qa_complete_session || return 1
  assert_clean || return 1
  qa_reset_to_idle || return 1
  assert_clean
}

qa_create_data_backup() {
  local destination_dir="${1:-}"
  local assert_args=()

  if [ -z "$destination_dir" ]; then
    echo "FAIL: destination directory path required"
    return 1
  fi
  shift || true

  while [ "$#" -gt 0 ]; do
    case "$1" in
      --require-store)
        assert_args+=("--require-store")
        shift
        ;;
      *)
        echo "FAIL: unknown qa-create-data-backup option ($1)"
        return 1
        ;;
    esac
  done

  ensure_app_running || return 1
  send_app_command "create_data_backup" "" "" "$destination_dir" || return 1

  if [ -z "$APP_COMMAND_OUTPUT_PATH" ]; then
    echo "FAIL: app command did not return outputPath"
    return 1
  fi

  if [ "${#assert_args[@]}" -gt 0 ]; then
    assert_data_backup "$APP_COMMAND_OUTPUT_PATH" "${assert_args[@]}"
  else
    assert_data_backup "$APP_COMMAND_OUTPUT_PATH"
  fi
}

qa_create_diagnostics_bundle() {
  local destination_dir="${1:-}"

  if [ -z "$destination_dir" ]; then
    echo "FAIL: destination directory path required"
    return 1
  fi

  ensure_app_running || return 1
  send_app_command "create_diagnostics_bundle" "" "" "$destination_dir" || return 1

  if [ -z "$APP_COMMAND_OUTPUT_PATH" ]; then
    echo "FAIL: app command did not return outputPath"
    return 1
  fi

  assert_diagnostics_bundle "$APP_COMMAND_OUTPUT_PATH"
}

qa_create_recovery_import_fixture() {
  local destination_dir="${1:-}"

  if [ -z "$destination_dir" ]; then
    echo "FAIL: destination directory path required"
    return 1
  fi

  ensure_app_running || return 1
  send_app_command "create_recovery_import_fixture_backup" "" "" "$destination_dir" || return 1

  if [ -z "$APP_COMMAND_OUTPUT_PATH" ]; then
    echo "FAIL: app command did not return outputPath"
    return 1
  fi

  assert_data_backup "$APP_COMMAND_OUTPUT_PATH" --require-store
}

qa_smoke_data_tools() {
  local destination_dir="${1:-}"

  if [ -z "$destination_dir" ]; then
    echo "FAIL: destination directory path required"
    return 1
  fi

  qa_create_data_backup "$destination_dir" || return 1
  qa_create_diagnostics_bundle "$destination_dir"
}

require_import_detail() {
  local key="$1"
  local value
  value="$(json_extract_detail_int "$APP_COMMAND_RESULT_JSON" "$key")"
  if [ -z "$value" ]; then
    echo "FAIL: import details missing integer field ($key)"
    return 1
  fi
  printf '%s\n' "$value"
}

qa_preview_data_import() {
  local backup_dir="${1:-}"
  local profile_count
  local session_count
  local badge_count

  if [ -z "$backup_dir" ]; then
    echo "FAIL: backup directory path required"
    return 1
  fi

  assert_data_backup "$backup_dir" --require-store || return 1
  ensure_app_running || return 1
  send_app_command "preview_data_import" "" "" "$backup_dir" || return 1

  profile_count="$(require_import_detail "profileCandidateCount")" || return 1
  session_count="$(require_import_detail "focusSessionCandidateCount")" || return 1
  badge_count="$(require_import_detail "badgeCandidateCount")" || return 1

  if [ "$profile_count" -lt 1 ]; then
    echo "FAIL: data import preview found no profile candidates"
    return 1
  fi

  echo "PASS: data import preview is valid (profiles=$profile_count sessions=$session_count badges=$badge_count)"
}

qa_validate_data_import() {
  local backup_dir="${1:-}"
  local include_sessions="false"
  local include_badges="false"
  local selected_count
  local imported_profiles
  local imported_sessions
  local imported_badges

  if [ -z "$backup_dir" ]; then
    echo "FAIL: backup directory path required"
    return 1
  fi
  shift || true

  while [ "$#" -gt 0 ]; do
    case "$1" in
      --include-sessions)
        include_sessions="true"
        shift
        ;;
      --include-badges)
        include_badges="true"
        shift
        ;;
      *)
        echo "FAIL: unknown qa-validate-data-import option ($1)"
        return 1
        ;;
    esac
  done

  assert_data_backup "$backup_dir" --require-store || return 1
  ensure_app_running || return 1
  send_app_command "validate_data_import" "" "" "$backup_dir" "$include_sessions" "$include_badges" || return 1

  selected_count="$(require_import_detail "selectedCandidateCount")" || return 1
  imported_profiles="$(require_import_detail "importedProfileCount")" || return 1
  imported_sessions="$(require_import_detail "importedFocusSessionCount")" || return 1
  imported_badges="$(require_import_detail "importedBadgeCount")" || return 1

  if [ "$selected_count" -lt 1 ]; then
    echo "FAIL: data import validation selected no candidates"
    return 1
  fi

  echo "PASS: data import dry-run is valid (selected=$selected_count profiles=$imported_profiles sessions=$imported_sessions badges=$imported_badges)"
}

qa_smoke_recovery_import() {
  local destination_dir="${1:-}"
  local backup_dir

  if [ -z "$destination_dir" ]; then
    echo "FAIL: destination directory path required"
    return 1
  fi

  qa_create_recovery_import_fixture "$destination_dir" || return 1
  backup_dir="$APP_COMMAND_OUTPUT_PATH"
  if [ -z "$backup_dir" ]; then
    echo "FAIL: app command did not return backup outputPath"
    return 1
  fi

  qa_preview_data_import "$backup_dir" || return 1
  qa_validate_data_import "$backup_dir" || return 1
  qa_validate_data_import "$backup_dir" --include-sessions --include-badges
}

json_file_is_valid() {
  local path="$1"
  python3 -m json.tool "$path" >/dev/null 2>&1
}

assert_directory_basename() {
  local path="$1"
  local prefix="$2"
  local label="$3"
  local basename_value

  basename_value="$(basename "$path")"
  case "$basename_value" in
    "$prefix"-*)
      return 0
      ;;
    *)
      echo "FAIL: $label directory name must start with $prefix- ($basename_value)"
      return 1
      ;;
  esac
}

assert_data_backup() {
  local backup_dir="${1:-}"
  local require_store=0
  local manifest_path
  local store_candidate

  if [ -z "$backup_dir" ]; then
    echo "FAIL: backup directory path required"
    return 1
  fi
  shift || true

  while [ "$#" -gt 0 ]; do
    case "$1" in
      --require-store)
        require_store=1
        shift
        ;;
      *)
        echo "FAIL: unknown assert-data-backup option ($1)"
        return 1
        ;;
    esac
  done

  if [ ! -d "$backup_dir" ]; then
    echo "FAIL: backup directory missing ($backup_dir)"
    return 1
  fi

  assert_directory_basename "$backup_dir" "FocusYouBackup" "backup" || return 1

  manifest_path="$backup_dir/diagnostics.json"
  if [ ! -f "$manifest_path" ]; then
    echo "FAIL: diagnostics.json missing ($manifest_path)"
    return 1
  fi

  if ! json_file_is_valid "$manifest_path"; then
    echo "FAIL: diagnostics.json is not valid JSON ($manifest_path)"
    return 1
  fi

  if [ "$require_store" -eq 1 ]; then
    store_candidate="$(
      find "$backup_dir" -maxdepth 1 -type f \( -name "*.store" -o -name "*.sqlite" \) -print -quit
    )"
    if [ -z "$store_candidate" ]; then
      echo "FAIL: store file not found in backup ($backup_dir)"
      return 1
    fi
  fi

  echo "PASS: data backup bundle is valid ($backup_dir)"
}

assert_diagnostics_bundle() {
  local bundle_dir="${1:-}"
  local manifest_path
  local policy_path

  if [ -z "$bundle_dir" ]; then
    echo "FAIL: diagnostics bundle directory path required"
    return 1
  fi

  if [ ! -d "$bundle_dir" ]; then
    echo "FAIL: diagnostics bundle directory missing ($bundle_dir)"
    return 1
  fi

  assert_directory_basename "$bundle_dir" "FocusYouDiagnostics" "diagnostics bundle" || return 1

  manifest_path="$bundle_dir/manifest.json"
  if [ ! -f "$manifest_path" ]; then
    echo "FAIL: manifest.json missing ($manifest_path)"
    return 1
  fi

  if ! json_file_is_valid "$manifest_path"; then
    echo "FAIL: manifest.json is not valid JSON ($manifest_path)"
    return 1
  fi

  policy_path="$bundle_dir/redaction-policy.txt"
  if [ ! -f "$policy_path" ]; then
    echo "FAIL: redaction-policy.txt missing ($policy_path)"
    return 1
  fi

  if [ -n "$HOME" ] && grep -R -F "$HOME" "$manifest_path" "$policy_path" >/dev/null 2>&1; then
    echo "FAIL: home directory path appears in diagnostics bundle ($bundle_dir)"
    return 1
  fi

  echo "PASS: diagnostics bundle is valid ($bundle_dir)"
}

snapshot() {
  print_header
  echo "hosts markers: $(hosts_marker_count)"
  echo
  echo "[state files]"
  file_state "$INDICATOR_PATH"
  file_state "$BACKUP_PATH"
  file_state "$LAUNCH_AGENT_PATH"
  echo
  echo "[helper]"
  file_state "$HELPER_PATH"
  helper_sudo_state
  echo
  echo "[app]"
  app_process_state
  echo
  echo "[hosts marker block]"
  hosts_marker_block
  echo
}

assert_clean() {
  local markers
  local indicator_exists=0
  local backup_exists=0
  local launch_agent_exists=0

  markers="$(hosts_marker_count)"
  if [[ "$markers" == *"begin=0 end=0"* ]]; then
    :
  else
    echo "FAIL: hosts markers still present ($markers)"
    return 1
  fi

  if [ -e "$INDICATOR_PATH" ]; then
    indicator_exists=1
  fi
  if [ -e "$BACKUP_PATH" ]; then
    backup_exists=1
  fi
  if [ -e "$LAUNCH_AGENT_PATH" ]; then
    launch_agent_exists=1
  fi

  if [ "$indicator_exists" -eq 1 ] || [ "$backup_exists" -eq 1 ] || [ "$launch_agent_exists" -eq 1 ]; then
    echo "FAIL: safety files remain (indicator=$indicator_exists backup=$backup_exists launchAgent=$launch_agent_exists)"
    return 1
  fi

  echo "PASS: clean state"
}

assert_blocked() {
  local markers
  markers="$(hosts_marker_count)"
  if [[ "$markers" == *"begin=1 end=1"* ]]; then
    echo "PASS: blocking markers present"
    return 0
  fi
  echo "FAIL: blocking markers not found ($markers)"
  return 1
}

assert_safetynet_armed() {
  local markers
  local indicator_exists=0
  local backup_exists=0
  local launch_agent_exists=0

  markers="$(hosts_marker_count)"
  if [[ "$markers" != *"begin=1 end=1"* ]]; then
    echo "FAIL: blocking markers not found ($markers)"
    return 1
  fi

  if [ -e "$INDICATOR_PATH" ]; then
    indicator_exists=1
  fi
  if [ -e "$BACKUP_PATH" ]; then
    backup_exists=1
  fi
  if [ -e "$LAUNCH_AGENT_PATH" ]; then
    launch_agent_exists=1
  fi

  if [ "$indicator_exists" -ne 1 ] || [ "$backup_exists" -ne 1 ] || [ "$launch_agent_exists" -ne 1 ]; then
    echo "FAIL: safety net not armed (indicator=$indicator_exists backup=$backup_exists launchAgent=$launch_agent_exists)"
    return 1
  fi

  echo "PASS: safety net armed"
}

assert_recovered() {
  local markers
  local indicator_exists=0
  local backup_exists=0
  local launch_agent_exists=0

  markers="$(hosts_marker_count)"
  if [[ "$markers" != *"begin=0 end=0"* ]]; then
    echo "FAIL: hosts markers still present ($markers)"
    return 1
  fi

  if [ -e "$INDICATOR_PATH" ]; then
    indicator_exists=1
  fi
  if [ -e "$BACKUP_PATH" ]; then
    backup_exists=1
  fi
  if [ -e "$LAUNCH_AGENT_PATH" ]; then
    launch_agent_exists=1
  fi

  if [ "$indicator_exists" -eq 1 ] || [ "$backup_exists" -eq 1 ] || [ "$launch_agent_exists" -eq 1 ]; then
    echo "FAIL: recovery artifacts remain (indicator=$indicator_exists backup=$backup_exists launchAgent=$launch_agent_exists)"
    return 1
  fi

  echo "PASS: recovered state"
}

assert_helper_ready() {
  if [ ! -x "$HELPER_PATH" ]; then
    echo "FAIL: helper missing or not executable ($HELPER_PATH)"
    return 1
  fi

  if ! helper_nopasswd_ok; then
    echo "FAIL: helper sudo NOPASSWD is not configured"
    return 1
  fi

  echo "PASS: helper is ready"
}

assert_recovery_pending() {
  local markers
  local indicator_exists=0
  local backup_exists=0
  local launch_agent_exists=0

  markers="$(hosts_marker_count)"
  if [[ "$markers" != *"begin=1 end=1"* ]]; then
    echo "FAIL: expected blocked hosts markers for pending recovery ($markers)"
    return 1
  fi

  if [ -e "$INDICATOR_PATH" ]; then
    indicator_exists=1
  fi
  if [ -e "$BACKUP_PATH" ]; then
    backup_exists=1
  fi
  if [ -e "$LAUNCH_AGENT_PATH" ]; then
    launch_agent_exists=1
  fi

  if [ "$indicator_exists" -ne 1 ] || [ "$backup_exists" -ne 1 ] || [ "$launch_agent_exists" -ne 1 ]; then
    echo "FAIL: recovery retry signals missing (indicator=$indicator_exists backup=$backup_exists launchAgent=$launch_agent_exists)"
    return 1
  fi

  echo "PASS: recovery is pending with retry signals intact"
}

watch_loop() {
  local interval="$1"
  while true; do
    snapshot
    sleep "$interval"
  done
}

usage() {
  cat <<EOF
Usage:
  $(basename "$0") snapshot
  $(basename "$0") assert-clean
  $(basename "$0") assert-blocked
  $(basename "$0") assert-safetynet-armed
  $(basename "$0") assert-helper-ready
  $(basename "$0") assert-recovery-pending
  $(basename "$0") assert-recovered
  $(basename "$0") assert-data-backup <FocusYouBackup-* dir> [--require-store]
  $(basename "$0") assert-diagnostics-bundle <FocusYouDiagnostics-* dir>
  $(basename "$0") qa-start-session [duration_seconds] [domain]
  $(basename "$0") qa-stop-session
  $(basename "$0") qa-complete-session
  $(basename "$0") qa-reset-to-idle
  $(basename "$0") qa-smoke-start-stop [duration_seconds] [domain]
  $(basename "$0") qa-smoke-completion-cleanup [domain]
  $(basename "$0") qa-create-data-backup <destination-dir> [--require-store]
  $(basename "$0") qa-create-diagnostics-bundle <destination-dir>
  $(basename "$0") qa-create-recovery-import-fixture <destination-dir>
  $(basename "$0") qa-smoke-data-tools <destination-dir>
  $(basename "$0") qa-preview-data-import <FocusYouBackup-* dir>
  $(basename "$0") qa-validate-data-import <FocusYouBackup-* dir> [--include-sessions] [--include-badges]
  $(basename "$0") qa-smoke-recovery-import <destination-dir>
  $(basename "$0") watch [interval_seconds]
EOF
}

cmd="${1:-snapshot}"
case "$cmd" in
  snapshot)
    snapshot
    ;;
  assert-clean)
    assert_clean
    ;;
  assert-blocked)
    assert_blocked
    ;;
  assert-safetynet-armed)
    assert_safetynet_armed
    ;;
  assert-helper-ready)
    assert_helper_ready
    ;;
  assert-recovery-pending)
    assert_recovery_pending
    ;;
  assert-recovered)
    assert_recovered
    ;;
  assert-data-backup)
    shift
    assert_data_backup "$@"
    ;;
  assert-diagnostics-bundle)
    shift
    assert_diagnostics_bundle "$@"
    ;;
  qa-start-session)
    qa_start_session "${2:-120}" "${3:-example.com}"
    ;;
  qa-stop-session)
    qa_stop_session
    ;;
  qa-complete-session)
    qa_complete_session
    ;;
  qa-reset-to-idle)
    qa_reset_to_idle
    ;;
  qa-smoke-start-stop)
    qa_smoke_start_stop "${2:-120}" "${3:-example.com}"
    ;;
  qa-smoke-completion-cleanup)
    qa_smoke_completion_cleanup "${2:-qa-completion.focusyou.example}"
    ;;
  qa-create-data-backup)
    shift
    qa_create_data_backup "$@"
    ;;
  qa-create-diagnostics-bundle)
    shift
    qa_create_diagnostics_bundle "$@"
    ;;
  qa-create-recovery-import-fixture)
    shift
    qa_create_recovery_import_fixture "$@"
    ;;
  qa-smoke-data-tools)
    qa_smoke_data_tools "${2:-}"
    ;;
  qa-preview-data-import)
    shift
    qa_preview_data_import "$@"
    ;;
  qa-validate-data-import)
    shift
    qa_validate_data_import "$@"
    ;;
  qa-smoke-recovery-import)
    qa_smoke_recovery_import "${2:-}"
    ;;
  watch)
    interval="${2:-2}"
    watch_loop "$interval"
    ;;
  *)
    usage
    exit 1
    ;;
esac
