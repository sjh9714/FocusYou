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
  watch)
    interval="${2:-2}"
    watch_loop "$interval"
    ;;
  *)
    usage
    exit 1
    ;;
esac
