# Focus You App Store Submission QA - v2.3.13 (38)

Date: 2026-05-17  
Baseline: `380e8b3`  
Version: `2.3.13`  
Build: `38`  
App Store Connect app ID: `6766774684`  
Build upload ID: `de235db9-e995-47be-8e13-89188135840a`

## Automated Checks

| Check | Result | Notes |
| --- | --- | --- |
| `git status --short --branch` | PASS | `main...origin/main`, no tracked changes before documentation updates |
| `xcodegen generate` | PASS | Generated project without tracked diff |
| AppStore unsigned build | PASS | `xcodebuild ... -configuration AppStore ... CODE_SIGNING_ALLOWED=NO build` |
| Full Debug test suite | PASS | XCTest run succeeded; Swift Testing reported 177 tests passing |
| Debug analyze | PASS | `** ANALYZE SUCCEEDED **` |
| QA script syntax/fixtures | PASS | `bash -n scripts/qa_focusyou_state.sh && bash scripts/test_qa_focusyou_state.sh` |
| Runtime cleanup state | PASS | `assert-clean` and `assert-helper-ready` |

## Archive, Entitlements, Upload

| Check | Result | Notes |
| --- | --- | --- |
| App Store archive | PASS | `./scripts/release_appstore.sh --skip-export --allow-provisioning-updates` |
| App entitlements | PASS | Sandbox, App Group, user-selected file read/write, Calendar, System Extension install |
| Widget entitlements | PASS | Sandbox and App Group |
| Network Extension entitlements | PASS | Sandbox, App Group, `content-filter-provider` |
| App Store export | PASS | `./scripts/release_appstore.sh --allow-provisioning-updates` produced `Focus You.pkg` |
| App Store upload | PASS | `./scripts/release_appstore.sh --upload --allow-provisioning-updates`; upload succeeded and package entered processing |

Note: the copied archive under `build/appstore` can receive local file-provider xattrs that make `codesign --deep --strict` complain about `com.apple.FinderInfo`. The original archive used by Xcode in `${TMPDIR}/focusyou-appstore-build` verified successfully with `codesign --verify --deep --strict --verbose=2`.

## TestFlight / App Store Connect Manual QA

These items require the uploaded build to finish App Store Connect processing:

| Scenario | Result | Notes |
| --- | --- | --- |
| Build `2.3.13 (38)` appears in TestFlight | BLOCKED | Waiting on App Store Connect processing/UI confirmation |
| Clean tester install and first launch | BLOCKED | Run after TestFlight build is available |
| Network Extension approval / deny / retry | BLOCKED | Requires TestFlight install |
| Start/stop/complete session cleanup | BLOCKED | Requires TestFlight install |
| Settings > Diagnostics backup/preview/import/export | BLOCKED | Requires TestFlight install |
| StoreKit sandbox monthly/annual purchase and restore | BLOCKED | Requires App Store Connect IAP/TestFlight environment |
| Korean and English screenshot capture | BLOCKED | Capture from processed TestFlight/App Store build |

## Submission Materials

- Paste-ready metadata: `docs/app-store-metadata.md`
- Review notes: `docs/app-store-metadata.md`
- Submission procedure: `docs/app-store-submission.md`
- Privacy policy: `docs/privacy-policy.md`
