# FocusYou Manual QA Checklist

This checklist verifies the critical recovery and blocking flows after recent stability patches.

## Pre-check

1. Build and run the app from Xcode.
2. Open `차단 목록` and add at least one website (for example `example.com`).
3. Open Terminal at the repo root and run:

```bash
./scripts/qa_focusyou_state.sh snapshot
```

4. Confirm clean baseline:

```bash
./scripts/qa_focusyou_state.sh assert-clean
./scripts/qa_focusyou_state.sh assert-helper-ready
```

Expected:
- hosts markers are absent (`begin=0 end=0`)
- `~/Library/Application Support/FocusYou/blocking.active` is missing
- `~/Library/Application Support/FocusYou/hosts.backup` is missing

## Scenario 1: Start -> Stop

1. Start a focus session.
2. Verify blocked state:

```bash
./scripts/qa_focusyou_state.sh assert-blocked
```

3. Stop the session from UI.
4. Verify clean state:

```bash
./scripts/qa_focusyou_state.sh assert-clean
```

Expected:
- Blocking deactivates fully.
- No leftover indicator/backup files.
- If `차단된 앱 알림` is ON, deactivation notification is shown.

## Scenario 2: Timer Completion

1. Start a short session (1 minute).
2. Wait for timer completion.
3. Verify clean state:

```bash
./scripts/qa_focusyou_state.sh assert-clean
```

Expected:
- Completion notification is shown.
- Deactivation notification follows only when blocking was active and setting allows it.

## Scenario 3: Force Quit During Active Blocking

1. Start a focus session and confirm blocked state + safety net armed:

```bash
./scripts/qa_focusyou_state.sh assert-blocked
./scripts/qa_focusyou_state.sh assert-safetynet-armed
```

2. Force-quit app (`Activity Monitor` or `kill -9`).
3. Relaunch app.
4. Run:

```bash
./scripts/qa_focusyou_state.sh snapshot
./scripts/qa_focusyou_state.sh assert-recovered
```

Expected:
- App startup runs emergency cleanup.
- Hosts markers are removed.
- Indicator/backup files are removed after successful cleanup.
- If cleanup fails, app shows an inline error panel and files remain for retry.

## Scenario 4: Reboot Recovery

1. Start a focus session and confirm blocked state + safety net armed:

```bash
./scripts/qa_focusyou_state.sh assert-blocked
./scripts/qa_focusyou_state.sh assert-safetynet-armed
```

2. Reboot the machine.
3. After login, run:

```bash
./scripts/qa_focusyou_state.sh snapshot
./scripts/qa_focusyou_state.sh assert-recovered
```

4. If step 3 fails, launch FocusYou and run:

```bash
./scripts/qa_focusyou_state.sh snapshot
./scripts/qa_focusyou_state.sh assert-recovered
```

Expected:
- Reboot 직후에는 LaunchAgent가 먼저 복구를 시도해 clean 상태가 될 수 있음.
- LaunchAgent 복구가 실패한 경우 앱 시작 시 startup cleanup이 복구를 완료해야 함.
- Failed cleanup must not silently clear the retry signals.

## Scenario 5: Recovery Failure Path (Signals Must Stay)

Goal:
- 복구가 실패해도 재시도 신호(`blocking.active`, `hosts.backup`, LaunchAgent plist)가 지워지지 않아야 함.

1. Start a focus session and confirm safety net is armed:

```bash
./scripts/qa_focusyou_state.sh assert-safetynet-armed
```

2. Force a helper failure (temporary) in another terminal:

```bash
sudo mv /usr/local/bin/focusyou-helper /usr/local/bin/focusyou-helper.disabled
```

3. Force-quit FocusYou, then relaunch FocusYou.
4. When admin prompt appears for cleanup fallback, click `Cancel`.
5. Verify pending recovery state:

```bash
./scripts/qa_focusyou_state.sh snapshot
./scripts/qa_focusyou_state.sh assert-recovery-pending
```

6. Restore helper and retry cleanup:

```bash
sudo mv /usr/local/bin/focusyou-helper.disabled /usr/local/bin/focusyou-helper
./scripts/qa_focusyou_state.sh assert-helper-ready
```

7. In app error panel, click `다시 시도`, then verify:

```bash
./scripts/qa_focusyou_state.sh assert-recovered
```

Expected:
- 실패 시점에는 `assert-recovery-pending`가 PASS여야 함.
- 복구 재시도 성공 후 `assert-recovered`가 PASS여야 함.

## Optional Live Monitor

Use this during manual actions:

```bash
./scripts/qa_focusyou_state.sh watch 2
```

This prints state every 2 seconds.
