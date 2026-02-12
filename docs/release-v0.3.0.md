# Focus You v0.3.0 Release Notes

## Summary

v0.3.0 introduces Pomodoro workflow and visual timer improvements while preserving the existing blocking recovery guarantees.

## Highlights

- New Pomodoro mode with configurable focus/break/cycle values.
- Pie chart timer and phase badges for clearer progress feedback.
- Per-phase blocking behavior:
  - focus: blocking enabled
  - breaks: blocking disabled
- Completed-session summary for Pomodoro outcomes.
- Debug Fast Timer path for faster manual verification in Debug builds.

## Stability and Recovery

- Startup emergency cleanup remains active for stale block artifacts.
- Recovery retry signals remain intact on cleanup failure:
  - `blocking.active`
  - `hosts.backup`
  - `com.sungjh.focusyou.cleanup.plist`
- Helper restore readiness can be validated via:
  - `./scripts/qa_focusyou_state.sh assert-helper-ready`

## QA Commands

```bash
./scripts/qa_focusyou_state.sh snapshot
./scripts/qa_focusyou_state.sh assert-clean
./scripts/qa_focusyou_state.sh assert-blocked
./scripts/qa_focusyou_state.sh assert-safetynet-armed
./scripts/qa_focusyou_state.sh assert-recovery-pending
./scripts/qa_focusyou_state.sh assert-recovered
```

Detailed steps: `docs/manual-qa-checklist.md`

QA execution log: `docs/qa-v0.3.0-2026-02-13.md`
