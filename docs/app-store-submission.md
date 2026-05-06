# Mac App Store Submission Prep

Focus You keeps two distribution paths:

- Direct DMG: Developer ID signed/notarized DMG through `scripts/release.sh`.
- Mac App Store: sandboxed `AppStore` configuration through `scripts/release_appstore.sh`.

The App Store build does not use `/etc/hosts`, `/usr/local/bin/focusyou-helper`, sudo prompts, or LaunchAgent recovery. Website blocking is fixed to the Network Extension/System Extension path.

## Build Modes

| Path | Configuration | Sandbox | Website blocking | Release tool |
| --- | --- | --- | --- | --- |
| Direct DMG | `Release` | Off | hosts or Network Extension | `scripts/release.sh` |
| App Store | `AppStore` | On | Network Extension only | `scripts/release_appstore.sh` |

The app, Network Extension, and Widget each have App Store entitlements files:

- `FocusYou/FocusYouAppStore.entitlements`
- `FocusYouNetworkExtension/FocusYouNetworkExtensionAppStore.entitlements`
- `FocusYouWidget/FocusYouWidgetAppStore.entitlements`

## Local Validation

Generate the project and confirm the App Store configuration compiles without signing:

```bash
xcodegen generate
xcodebuild -project FocusYou.xcodeproj -scheme FocusYou -configuration AppStore -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build
```

After a signed archive/export, inspect the shipped entitlements:

```bash
codesign -d --entitlements :- "path/to/Focus You.app"
codesign -d --entitlements :- "path/to/Focus You.app/Contents/PlugIns/FocusYouWidget.appex"
codesign -d --entitlements :- "path/to/Focus You.app/Contents/Library/SystemExtensions/com.sungjh.focusyou.network-extension.systemextension"
```

Direct DMG packaging also discovers the embedded `.systemextension` dynamically so the
App Store-compliant bundle file name is shared by both distribution paths.

Expected App Store traits:

- App Sandbox enabled on the app, widget, and Network Extension.
- App Group `group.com.sungjh.focusyou` present on all targets that share data.
- Network Extension entitlement includes `content-filter-provider`.
- User Selected File read/write entitlement is present for backup, diagnostic bundle, and import folder selection.
- Calendar entitlement is present for optional session calendar sync.
- Apple Events entitlement is not requested in the App Store build; administrator AppleScript flows are direct-distribution only.

## Archive And Export

Use the App Store-specific helper:

```bash
./scripts/release_appstore.sh --allow-provisioning-updates
```

To create only the archive:

```bash
./scripts/release_appstore.sh --skip-export --allow-provisioning-updates
```

To ask Xcode to upload to App Store Connect:

```bash
./scripts/release_appstore.sh --upload --allow-provisioning-updates
```

This path requires Apple Distribution signing plus App Store provisioning profiles for:

- `com.sungjh.focusyou`
- `com.sungjh.focusyou.network-extension`
- `com.sungjh.focusyou.widget`

Before selecting a build for review, keep the App Store Connect macOS version
aligned with `MARKETING_VERSION` from `project.yml`.

Use the published privacy policy URL in App Store Connect:

```text
https://github.com/jinhyuk9714/FocusYou/blob/main/docs/privacy-policy.md
```

## App Review Notes Template

Use this as the starting point for App Review notes:

```text
Focus You is a macOS menu bar focus timer that blocks distracting websites/apps during user-started focus sessions.

Network Extension purpose:
The Mac App Store build uses a content filter Network Extension/System Extension to block only the websites selected by the user for the active focus session. The App Store build does not modify /etc/hosts, does not install a privileged helper, and does not use sudo.

Calendar permission:
Calendar access is optional and only used when the user enables Apple Calendar sync. Completed focus sessions can be written to the user's calendar.

File access:
User Selected File read/write is used only for explicit user actions in Settings > Diagnostics: data backup, diagnostic bundle export, backup preview, and selected backup import.

Subscriptions:
The app includes Pro subscription gates. The Restore Purchases control is available in the subscription/paywall flow.

Review path:
1. Launch Focus You.
2. Open Settings > Advanced.
3. Confirm App Store build uses Network Extension blocking only.
4. Start a short focus session with a test website.
5. Approve the Network Extension/System Extension if macOS prompts.
6. Stop or complete the session and confirm blocking is released.
7. Open Settings > Diagnostics to test backup/diagnostic export to a selected folder.
```

Add App Store Connect subscription product IDs, sandbox tester details, and any temporary review credentials before submission.

## App Store QA Checklist

- First launch shows normal menu bar app behavior.
- Network Extension approval path is clear and does not dead-end the user.
- Starting, stopping, and completing a session activates and deactivates Network Extension blocking.
- Force quit and relaunch do not leave the UI stuck.
- Settings > Advanced does not show hosts/helper choices in the App Store build.
- Settings > Diagnostics keeps data tools available under sandbox user-selected folder access.
- StoreKit sandbox purchase and restore paths work for Pro-gated features.
- Direct DMG release tooling still works independently through `scripts/release.sh`.
