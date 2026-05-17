# Mac App Store Submission Prep

Focus You has two distribution paths:

- Direct DMG: Developer ID signed/notarized build through `scripts/release.sh`.
- Mac App Store: sandboxed `AppStore` configuration through `scripts/release_appstore.sh`.

The App Store build must not use `/etc/hosts`, `/usr/local/bin/focusyou-helper`, sudo prompts, administrator AppleScript, or LaunchAgent recovery. Website blocking for App Store review must use the Network Extension/System Extension path only.

## Current Review Blockers

Resolve these before selecting a build for review:

- App Store Connect subscription products need complete metadata: product IDs, display names, durations, localized descriptions, pricing, subscription group, screenshot if requested, and review notes explaining the Pro gates.
- StoreKit sandbox QA must cover purchase, restore, cancellation/expiration behavior, and unavailable product loading before review.
- App Store screenshots must be captured from the signed App Store build, not the direct DMG build.
- Public legal/support URLs must be reachable without authentication.
- App Review notes must state that the App Store build does not modify `/etc/hosts`, install helpers, or request administrator privileges.
- A signed archive/export must be inspected for sandbox, App Group, Network Extension, file access, and calendar entitlements.

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
- Subtitle: `Block Distractions & Focus Timer`
- Category: Productivity
- Privacy policy URL: `https://github.com/jinhyuk9714/FocusYou/blob/main/docs/privacy-policy.md`
- Support URL: public project support page or repository issues/contact page before submission
- Copyright owner and age rating metadata
- Screenshots from the App Store build for menu bar, active session, settings/diagnostics, and subscription flow
- Subscription product IDs exactly matching `FocusYou/FocusYou.storekit` and App Store Connect
- Review notes with Network Extension purpose, optional Calendar purpose, file access purpose, and subscription restore path

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
The app includes Pro subscription gates. The Restore Purchases control is available in the subscription/paywall flow. Subscription product IDs and durations are configured in App Store Connect and StoreKit sandbox before review.

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

Add sandbox tester details, temporary review credentials if any, and exact subscription product IDs before submission.

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
