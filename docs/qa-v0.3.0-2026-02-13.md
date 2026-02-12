# Focus You v0.3.0 Manual QA Result

Date: 2026-02-13  
Environment: macOS (local machine), Debug build

Reference checklist: `docs/manual-qa-checklist.md`

## Summary

- Overall result: PASS
- Scenarios executed: 1 to 5
- Final state: recovered/clean (`assert-recovered` PASS)

## Scenario Results

### 1) Start -> Stop

- `./scripts/qa_focusyou_state.sh assert-blocked` => PASS
- `./scripts/qa_focusyou_state.sh assert-clean` => PASS

### 2) Timer Completion

- `./scripts/qa_focusyou_state.sh assert-clean` => PASS

### 3) Force Quit During Active Blocking

- Pre-check:
  - `assert-blocked` => PASS
  - `assert-safetynet-armed` => PASS
- Force quit:
  - `pkill -9 -f "Focus You.app/Contents/MacOS/Focus You"`
- Post-check:
  - `snapshot` shows `begin=0 end=0` and no recovery artifacts
  - `assert-recovered` => PASS

### 4) Reboot Recovery

- Pre-check:
  - `assert-blocked` => PASS
  - `assert-safetynet-armed` => PASS
- After reboot:
  - `snapshot` shows `begin=0 end=0`, artifacts removed
  - `assert-recovered` => PASS

### 5) Recovery Failure Path (Signals Must Stay)

- `assert-safetynet-armed` => PASS
- Helper disabled:
  - `sudo mv /usr/local/bin/focusyou-helper /usr/local/bin/focusyou-helper.disabled`
- Failure-state check:
  - `snapshot` shows marker block present and retry artifacts present
  - `assert-recovery-pending` => PASS
- Restore helper:
  - `sudo mv /usr/local/bin/focusyou-helper.disabled /usr/local/bin/focusyou-helper`
  - `assert-helper-ready` => PASS
- Retry recovery:
  - `assert-recovered` => PASS

## Final Verification

- `./scripts/qa_focusyou_state.sh assert-helper-ready` => PASS
- `./scripts/qa_focusyou_state.sh assert-clean` => PASS
