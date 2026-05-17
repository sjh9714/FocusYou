# Mac App Store Submission Prep

Focus You has two distribution paths:

- Direct DMG: Developer ID signed/notarized build through `scripts/release.sh`.
- Mac App Store: sandboxed `AppStore` configuration through `scripts/release_appstore.sh`.

The App Store build must not use `/etc/hosts`, `/usr/local/bin/focusyou-helper`, sudo prompts, administrator AppleScript, or LaunchAgent recovery. Website blocking for App Store review must use the Network Extension/System Extension path only.

## Current Submission Status

- App Store Connect app: `Focus You` (`6766774684`)
- Uploaded build: `2.3.13` (`38`) for `MAC_OS`
- Upload time: `2026-05-17 15:38 KST`
- Upload result: `Upload succeeded`; App Store Connect reported the uploaded package as processing.
- Build upload ID: `de235db9-e995-47be-8e13-89188135840a`
- Team: `9VRNY5PMG3`

Before App Review submission, finish these App Store Connect UI tasks:

- Wait for build `2.3.13 (38)` to finish processing and enable it for TestFlight.
- Run the TestFlight smoke checklist below with a clean tester account.
- Upload Korean and English screenshots captured from the App Store/TestFlight build.
- Confirm App Store Connect subscription metadata and sandbox purchase/restore behavior for the submitted products.

## Build Modes

| Path | Configuration | Sandbox | Website blocking | Release tool |
| --- | --- | --- | --- | --- |
| Direct DMG | `Release` | Off | hosts or Network Extension | `scripts/release.sh` |
| App Store | `AppStore` | On | Network Extension only | `scripts/release_appstore.sh` |

App Store entitlement files:

- `FocusYou/FocusYouAppStore.entitlements`
- `FocusYouNetworkExtension/FocusYouNetworkExtensionAppStore.entitlements`
- `FocusYouWidget/FocusYouWidgetAppStore.entitlements`

Expected App Store traits:

- App Sandbox enabled on app, widget, and Network Extension.
- App Group `group.com.sungjh.focusyou` present on targets that share data.
- Network Extension entitlement includes `content-filter-provider`.
- User Selected File read/write is present for backup, diagnostic bundle export, backup preview, and selected backup import.
- Calendar entitlement is present only for optional Apple Calendar sync.
- Apple Events/admin helper entitlements are not requested in the App Store build.

## Local Validation

Generate the project and compile the App Store configuration without signing:

```bash
xcodegen generate
xcodebuild -project FocusYou.xcodeproj -scheme FocusYou -configuration AppStore -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build
```

Create an App Store archive/export:

```bash
./scripts/release_appstore.sh --allow-provisioning-updates
./scripts/release_appstore.sh --skip-export --allow-provisioning-updates
./scripts/release_appstore.sh --upload --allow-provisioning-updates
```

Required signing/provisioning identifiers:

- `com.sungjh.focusyou`
- `com.sungjh.focusyou.network-extension`
- `com.sungjh.focusyou.widget`

After a signed archive/export, inspect entitlements:

```bash
codesign -d --entitlements :- "path/to/Focus You.app"
codesign -d --entitlements :- "path/to/Focus You.app/Contents/PlugIns/FocusYouWidget.appex"
codesign -d --entitlements :- "path/to/Focus You.app/Contents/Library/SystemExtensions/com.sungjh.focusyou.network-extension.systemextension"
```

Keep the App Store Connect macOS version aligned with `MARKETING_VERSION` from `project.yml`.

## Required App Store Connect Metadata

- App name: `Focus You`
- Subtitle: `Focus Timer & Site Blocker`
- Category: Productivity
- Privacy policy URL: `https://github.com/jinhyuk9714/FocusYou/blob/main/docs/privacy-policy.md`
- Support URL: `https://github.com/jinhyuk9714/FocusYou/issues`
- Terms of Use (EULA): `https://www.apple.com/legal/internet-services/itunes/dev/stdeula/`
- Category: Productivity
- Copyright owner and age rating metadata in App Store Connect account settings
- Screenshots from the App Store/TestFlight build for onboarding, dashboard, active session, diagnostics/data tools, and subscription flow
- Subscription product IDs exactly matching `FocusYou/FocusYou.storekit` and App Store Connect:
  - `com.sungjh.focusyou.pro.monthly` — Focus You Pro Monthly — recurring monthly subscription
  - `com.sungjh.focusyou.pro.annual` — Focus You Pro Annual — recurring annual subscription
  - `com.sungjh.focusyou.pro.lifetime` — Focus You Pro Lifetime — non-consumable; hidden by the app unless App Store Connect returns the product
- Review notes with Network Extension purpose, optional Calendar purpose, file access purpose, and subscription restore path

Paste-ready Korean and English metadata is in `docs/app-store-metadata.md`.

## Screenshot Set

Use `2880x1800` PNG screenshots when possible. Capture each slot in Korean and English from the App Store/TestFlight build, not the direct DMG build.

| Slot | Required view | Notes |
| --- | --- | --- |
| 1 | First launch / onboarding | Shows timer-only path and Network Extension approval expectation |
| 2 | Dashboard idle | Shows primary 25-minute focus action and calm premium layout |
| 3 | Active focus session | Shows timer ring, blocking status, pause/stop controls |
| 4 | Settings > Diagnostics | Shows backup, preview/import, diagnostics export without helper/hosts UI |
| 5 | Paywall | Shows monthly/annual plans, price/period disclosure, restore and legal links |

## App Review Notes Template

```text
Focus You is a macOS menu bar focus timer that blocks distracting websites/apps during user-started focus sessions.

Network Extension purpose:
The Mac App Store build uses a content filter Network Extension/System Extension to block only the websites selected by the user for the active focus session. The App Store build does not modify /etc/hosts, does not install a privileged helper, and does not use sudo or administrator AppleScript.

Calendar permission:
Calendar access is optional and only used when the user enables Apple Calendar sync. Completed focus sessions can be written to the user's calendar.

File access:
User Selected File read/write is used only for explicit user actions in Settings > Diagnostics: data backup, diagnostic bundle export, backup preview, and selected backup import.

Subscriptions:
The app includes Pro subscription gates. The Restore Purchases control is available in the subscription/paywall flow. Submitted product IDs are:
- com.sungjh.focusyou.pro.monthly: monthly auto-renewable subscription
- com.sungjh.focusyou.pro.annual: annual auto-renewable subscription

The lifetime product com.sungjh.focusyou.pro.lifetime is hidden unless App Store Connect returns the product, so unapproved lifetime metadata is not required for this review build.

Review path:
1. Launch Focus You.
2. Open Settings > Advanced and confirm the App Store build uses Network Extension blocking only.
3. Create or select a block profile with a test website.
4. Start a short focus session.
5. Approve the Network Extension/System Extension if macOS prompts.
6. Confirm the selected website is blocked during the session.
7. Stop or complete the session and confirm blocking is released.
8. Open Settings > Diagnostics and export a backup/diagnostic bundle to a user-selected folder.
9. Open the subscription flow, start a sandbox purchase, and verify Restore Purchases.
```

No account is required to use the core timer. Add sandbox tester details only if App Review needs a dedicated purchase test account for the subscription flow.

## TestFlight And Sandbox QA Checklist

- First launch behaves as a menu bar app and does not show direct-distribution helper prompts.
- Network Extension approval path is clear and recoverable after denial/cancel.
- Starting, stopping, and completing a session activates/deactivates Network Extension blocking.
- Force quit and relaunch do not leave the UI stuck or blocking active without a clear recovery path.
- Settings > Advanced does not expose hosts/helper controls in the App Store build.
- Settings > Diagnostics backup, import preview, and diagnostic export work under sandbox user-selected file access.
- Calendar sync can be enabled, denied, and disabled without blocking core timer use.
- StoreKit sandbox purchase succeeds for every submitted product ID.
- Restore Purchases updates Pro access after reinstall/sign-out/sign-in scenarios.
- Product loading failure has a review-safe fallback message and does not dead-end the user.
- Direct DMG release tooling still works independently through `scripts/release.sh`.
