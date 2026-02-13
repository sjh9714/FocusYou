#!/usr/bin/env bash

set -u

BEGIN_MARKER="# === Focus You BEGIN ==="
END_MARKER="# === Focus You END ==="

STATE_DIR="$HOME/Library/Application Support/FocusYou"
INDICATOR_PATH="$STATE_DIR/blocking.active"
BACKUP_PATH="$STATE_DIR/hosts.backup"
LAUNCH_AGENT_PATH="$HOME/Library/LaunchAgents/com.sungjh.focusyou.cleanup.plist"
HELPER_PATH="/usr/local/bin/focusyou-helper"
HOSTS_PATH="/etc/hosts"
APP_BUNDLE_ID="com.sungjh.focusyou"
QA_AUTOMATION_ENABLED_KEY="qaAutomationEnabled"
QA_AUTOMATION_COMMAND_KEY="qaAutomationCommand"
QA_AUTOMATION_RESULT_KEY="qaAutomationResult"
QA_COMMAND_TIMEOUT_SECONDS=20

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

app_process_state() {
  if pgrep -ifl "Focus You|FocusYou" >/dev/null 2>&1; then
    echo "app process:"
    pgrep -ifl "Focus You|FocusYou"
  else
    echo "app process: not running"
  fi
}

json_extract_string() {
  local json="$1"
  local key="$2"
  printf '%s' "$json" | sed -n "s/.*\"$key\"[[:space:]]*:[[:space:]]*\"\\([^\"]*\\)\".*/\\1/p" | head -n 1
}

ensure_app_running() {
  if pgrep -ifl "Focus You.app/Contents/MacOS/Focus You|Focus You" >/dev/null 2>&1; then
    return 0
  fi
  echo "FAIL: Focus You app process not found (run app from Xcode first)"
  return 1
}

send_app_command() {
  local action="$1"
  local duration_seconds="${2:-}"
  local domain="${3:-}"
  local command_id
  local command_json
  local max_loops
  local result_json
  local result_id
  local result_status
  local result_message
  local i

  command_id="$(uuidgen | tr '[:upper:]' '[:lower:]')"

  case "$action" in
    start_session)
      command_json="$(printf '{"id":"%s","action":"start_session","durationSeconds":%s,"domain":"%s"}' \
        "$command_id" "$duration_seconds" "$domain")"
      ;;
    stop_session|reset_to_idle)
      command_json="$(printf '{"id":"%s","action":"%s"}' "$command_id" "$action")"
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
        if [ "$result_status" = "ok" ]; then
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
  $(basename "$0") qa-start-session [duration_seconds] [domain]
  $(basename "$0") qa-stop-session
  $(basename "$0") qa-reset-to-idle
  $(basename "$0") qa-smoke-start-stop [duration_seconds] [domain]
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
  qa-start-session)
    qa_start_session "${2:-120}" "${3:-example.com}"
    ;;
  qa-stop-session)
    qa_stop_session
    ;;
  qa-reset-to-idle)
    qa_reset_to_idle
    ;;
  qa-smoke-start-stop)
    qa_smoke_start_stop "${2:-120}" "${3:-example.com}"
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
