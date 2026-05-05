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

## Scenario 6: Data Tools Output Verification

Goal:
- 설정 > 진단의 데이터 도구가 만든 백업/진단 산출물을 로컬에서 재현 가능하게 검증합니다.
- 검증 명령은 지정한 폴더를 읽기만 하며 원본 Application Support와 백업 파일을 수정하지 않아야 합니다.

1. Open `설정 > 진단 > 데이터 도구 > 백업 만들기`.
2. Select a temporary destination folder and create a backup.
3. Verify the generated backup folder:

```bash
./scripts/qa_focusyou_state.sh assert-data-backup /path/to/FocusYouBackup-yyyyMMdd-HHmmss
```

4. If the current app has a SwiftData store file, also run:

```bash
./scripts/qa_focusyou_state.sh assert-data-backup /path/to/FocusYouBackup-yyyyMMdd-HHmmss --require-store
```

5. Open `설정 > 진단 > 데이터 도구 > 진단 로그 내보내기`.
6. Verify the generated diagnostics folder:

```bash
./scripts/qa_focusyou_state.sh assert-diagnostics-bundle /path/to/FocusYouDiagnostics-yyyyMMdd-HHmmss
```

7. Run `백업 미리보기` against the backup folder and confirm that the summary opens without changing the backup folder.
8. Run `백업 가져오기` only from the normal settings screen, confirm the final confirmation dialog appears, and import only after selecting at least one candidate.

Expected:
- Backup validation reports `PASS: data backup bundle is valid`.
- Diagnostics validation reports `PASS: diagnostics bundle is valid`.
- Diagnostics validation fails if `manifest.json` or `redaction-policy.txt` is missing, or if the manifest/policy contains the raw home directory path.
- Safe mode window still offers backup, preview, diagnostics export, and Application Support actions, but does not offer Import.

DEBUG 앱이 실행 중이면 생성과 검증을 터미널에서 함께 실행할 수 있습니다:

```bash
mkdir -p /tmp/focusyou-data-tools-qa
./scripts/qa_focusyou_state.sh qa-create-data-backup /tmp/focusyou-data-tools-qa --require-store
./scripts/qa_focusyou_state.sh qa-create-diagnostics-bundle /tmp/focusyou-data-tools-qa
```

원샷으로는:

```bash
./scripts/qa_focusyou_state.sh qa-smoke-data-tools /tmp/focusyou-data-tools-qa
```

백업 Import 미리보기와 dry-run 검증까지 확인하려면:

```bash
./scripts/qa_focusyou_state.sh qa-preview-data-import /path/to/FocusYouBackup-yyyyMMdd-HHmmss
./scripts/qa_focusyou_state.sh qa-validate-data-import /path/to/FocusYouBackup-yyyyMMdd-HHmmss --include-sessions --include-badges
./scripts/qa_focusyou_state.sh qa-smoke-recovery-import /tmp/focusyou-data-tools-qa
```

참고:
- 이 생성 훅은 DEBUG 전용입니다. Release 빌드에서는 동작하지 않습니다.
- 명령은 지정한 destination 아래에 새 백업/진단 폴더를 만들고, 반환된 경로를 곧바로 검증합니다.
- Import 검증은 in-memory context에서만 dry-run으로 실행하며 현재 persistent store에 새 데이터를 저장하지 않습니다.

## Optional Live Monitor

Use this during manual actions:

```bash
./scripts/qa_focusyou_state.sh watch 2
```

This prints state every 2 seconds.

## Optional Debug Automation (Start/Stop Smoke)

DEBUG 빌드에서 앱 실행 중이면 아래 명령으로 시작/중지를 반자동 검증할 수 있습니다.

```bash
./scripts/qa_focusyou_state.sh qa-start-session 120 example.com
./scripts/qa_focusyou_state.sh assert-blocked
./scripts/qa_focusyou_state.sh qa-stop-session
./scripts/qa_focusyou_state.sh assert-clean
```

원샷으로는:

```bash
./scripts/qa_focusyou_state.sh qa-smoke-start-stop 120 example.com
```

참고:
- 이 훅은 DEBUG 전용입니다. Release 빌드에서는 동작하지 않습니다.
- 앱 프로세스가 실행 중이어야 합니다.
