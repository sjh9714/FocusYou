#!/usr/bin/env bash

set -euo pipefail

# ─────────────────────────────────────────────────────────────
# Focus You Release Script
# Archives, (optionally) signs/notarizes, and creates a DMG.
#
# Usage:
#   ./scripts/release.sh [--skip-sign] [--skip-notarize]
#
# Requirements:
#   - Xcode (xcodebuild)
#   - xcodegen
#   - hdiutil (macOS built-in)
#   - (Optional) Developer ID certificate for signing
#   - (Optional) App-specific password in keychain for notarization
# ─────────────────────────────────────────────────────────────

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

APP_NAME="Focus You"
SCHEME="FocusYou"
PROJECT="FocusYou.xcodeproj"
OUTPUT_DIR="$ROOT_DIR/build"
BUILD_DIR="${FOCUSYOU_RELEASE_WORK_DIR:-${TMPDIR:-/tmp}/focusyou-release-build}"
ARCHIVE_PATH="$BUILD_DIR/$SCHEME.xcarchive"
SIGN_IDENTITY="Developer ID Application: JINHYUK SUNG (9VRNY5PMG3)"
APP_PROFILE_NAME="Mac Team Direct Provisioning Profile: com.sungjh.focusyou"
NETWORK_EXTENSION_PROFILE_NAME="Mac Team Direct Provisioning Profile: com.sungjh.focusyou.network-extension"
WIDGET_PROFILE_NAME="Mac Team Direct Provisioning Profile: com.sungjh.focusyou.widget"
NETWORK_EXTENSION_RELEASE_ENTITLEMENTS="$ROOT_DIR/FocusYouNetworkExtension/FocusYouNetworkExtensionRelease.entitlements"

SKIP_SIGN=0
SKIP_NOTARIZE=0

# ─── Parse arguments ─────────────────────────────────────────

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-sign)
      SKIP_SIGN=1
      shift
      ;;
    --skip-notarize)
      SKIP_NOTARIZE=1
      shift
      ;;
    -h|--help)
      echo "Usage: $0 [--skip-sign] [--skip-notarize]"
      exit 0
      ;;
    *)
      echo "Unknown argument: $1"
      exit 1
      ;;
  esac
done

# ─── Helpers ─────────────────────────────────────────────────

info()  { printf '\033[0;36mINFO:\033[0m %s\n' "$1"; }
pass()  { printf '\033[0;32mPASS:\033[0m %s\n' "$1"; }
fail()  { printf '\033[0;31mFAIL:\033[0m %s\n' "$1"; exit 1; }

find_provisioning_profile() {
  local wanted_name="$1"
  local dir profile tmp name
  local search_dirs=(
    "$HOME/Library/Developer/Xcode/UserData/Provisioning Profiles"
    "$HOME/Library/MobileDevice/Provisioning Profiles"
  )

  for dir in "${search_dirs[@]}"; do
    [[ -d "$dir" ]] || continue
    for profile in "$dir"/*.provisionprofile "$dir"/*.mobileprovision; do
      [[ -f "$profile" ]] || continue
      tmp="$(mktemp)"
      if security cms -D -i "$profile" > "$tmp" 2>/dev/null; then
        name="$(/usr/libexec/PlistBuddy -c 'Print :Name' "$tmp" 2>/dev/null || true)"
        if [[ "$name" == "$wanted_name" ]]; then
          rm -f "$tmp"
          printf '%s\n' "$profile"
          return 0
        fi
      fi
      rm -f "$tmp"
    done
  done

  return 1
}

clear_bundle_detritus() {
  local path="$1"

  xattr -cr "$path" 2>/dev/null || true
  find "$path" -exec xattr -d com.apple.FinderInfo {} \; 2>/dev/null || true
  find "$path" -exec xattr -d 'com.apple.fileprovider.fpfs#P' {} \; 2>/dev/null || true
}

# ─── Read version from project.yml ───────────────────────────

VERSION=$(grep 'MARKETING_VERSION:' "$ROOT_DIR/project.yml" | head -1 | sed 's/.*: *"\{0,1\}\([^"]*\)"\{0,1\}/\1/' | tr -d '[:space:]')
[[ -n "$VERSION" ]] || fail "Could not read MARKETING_VERSION from project.yml"
info "Version: $VERSION"

DMG_NAME="FocusYou-${VERSION}.dmg"
DMG_PATH="$OUTPUT_DIR/$DMG_NAME"

# ─── Clean build directory ───────────────────────────────────

info "Cleaning build directories..."
rm -rf "$BUILD_DIR"
rm -rf "$OUTPUT_DIR"
mkdir -p "$BUILD_DIR"
mkdir -p "$OUTPUT_DIR"

# ─── Step 1: Generate Xcode project ─────────────────────────

info "Generating Xcode project..."
xcodegen generate || fail "xcodegen generate failed"
pass "Project generated"

# ─── Step 2: Archive ─────────────────────────────────────────

ARCHIVE_SIGNING_ARGS=(
  DEVELOPMENT_TEAM=""
  CODE_SIGN_IDENTITY=""
  CODE_SIGNING_REQUIRED=NO
  CODE_SIGNING_ALLOWED=NO
  ENABLE_HARDENED_RUNTIME=YES
)

info "Archiving $SCHEME..."
xcodebuild archive \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Release \
  -archivePath "$ARCHIVE_PATH" \
  "${ARCHIVE_SIGNING_ARGS[@]}" \
  SKIP_INSTALL=NO \
  BUILD_LIBRARY_FOR_DISTRIBUTION=NO \
  | tail -20

[[ -d "$ARCHIVE_PATH" ]] || fail "Archive not found at $ARCHIVE_PATH"
pass "Archive created"

# ─── Step 3: Extract .app bundle ─────────────────────────────
APP_PATH="$BUILD_DIR/$APP_NAME.app"
ARCHIVE_APP_PATH="$ARCHIVE_PATH/Products/Applications/$APP_NAME.app"
ARCHIVE_LOCAL_APP_PATH="$ARCHIVE_PATH/Products/usr/local/bin/$APP_NAME.app"

if [[ -d "$ARCHIVE_APP_PATH" ]]; then
  ditto --noextattr --norsrc "$ARCHIVE_APP_PATH" "$APP_PATH" || fail "Could not extract .app from archive"
elif [[ -d "$ARCHIVE_LOCAL_APP_PATH" ]]; then
  ditto --noextattr --norsrc "$ARCHIVE_LOCAL_APP_PATH" "$APP_PATH" || fail "Could not extract .app from archive"
else
  fail "Could not extract .app from archive"
fi

[[ -d "$APP_PATH" ]] || fail ".app not found at $APP_PATH"
clear_bundle_detritus "$APP_PATH"
pass "App extracted: $APP_PATH"

# ─── Step 4: Code signing verification ───────────────────────

if [[ "$SKIP_SIGN" -eq 0 ]]; then
  info "Embedding Developer ID provisioning profiles..."
  APP_PROFILE="$(find_provisioning_profile "$APP_PROFILE_NAME")" || fail "Provisioning profile not found: $APP_PROFILE_NAME"
  NETWORK_EXTENSION_PROFILE="$(find_provisioning_profile "$NETWORK_EXTENSION_PROFILE_NAME")" || fail "Provisioning profile not found: $NETWORK_EXTENSION_PROFILE_NAME"
  WIDGET_PROFILE="$(find_provisioning_profile "$WIDGET_PROFILE_NAME")" || fail "Provisioning profile not found: $WIDGET_PROFILE_NAME"

  WIDGET_PATH="$APP_PATH/Contents/PlugIns/FocusYouWidget.appex"
  NETWORK_EXTENSION_PATH="$APP_PATH/Contents/Library/SystemExtensions/FocusYouFilter.systemextension"

  [[ -d "$WIDGET_PATH" ]] || fail "Widget bundle not found at $WIDGET_PATH"
  [[ -d "$NETWORK_EXTENSION_PATH" ]] || fail "System extension bundle not found at $NETWORK_EXTENSION_PATH"

  ditto --noextattr --norsrc "$APP_PROFILE" "$APP_PATH/Contents/embedded.provisionprofile"
  ditto --noextattr --norsrc "$WIDGET_PROFILE" "$WIDGET_PATH/Contents/embedded.provisionprofile"
  ditto --noextattr --norsrc "$NETWORK_EXTENSION_PROFILE" "$NETWORK_EXTENSION_PATH/Contents/embedded.provisionprofile"
  clear_bundle_detritus "$APP_PATH"
  pass "Provisioning profiles embedded"

  info "Signing nested bundles with Developer ID..."
  clear_bundle_detritus "$NETWORK_EXTENSION_PATH"
  if ! codesign --force --options runtime --timestamp \
    --sign "$SIGN_IDENTITY" \
    --entitlements "$NETWORK_EXTENSION_RELEASE_ENTITLEMENTS" \
    "$NETWORK_EXTENSION_PATH"; then
    clear_bundle_detritus "$NETWORK_EXTENSION_PATH"
    codesign --force --options runtime --timestamp \
      --sign "$SIGN_IDENTITY" \
      --entitlements "$NETWORK_EXTENSION_RELEASE_ENTITLEMENTS" \
      "$NETWORK_EXTENSION_PATH" || fail "Network extension signing failed"
  fi

  clear_bundle_detritus "$WIDGET_PATH"
  if ! codesign --force --options runtime --timestamp \
    --sign "$SIGN_IDENTITY" \
    --entitlements "$ROOT_DIR/FocusYouWidget/FocusYouWidget.entitlements" \
    "$WIDGET_PATH"; then
    clear_bundle_detritus "$WIDGET_PATH"
    codesign --force --options runtime --timestamp \
      --sign "$SIGN_IDENTITY" \
      --entitlements "$ROOT_DIR/FocusYouWidget/FocusYouWidget.entitlements" \
      "$WIDGET_PATH" || fail "Widget signing failed"
  fi

  info "Signing app with Developer ID..."
  clear_bundle_detritus "$APP_PATH"
  if ! codesign --force --options runtime --timestamp \
    --sign "$SIGN_IDENTITY" \
    --entitlements "$ROOT_DIR/FocusYou/FocusYou.entitlements" \
    "$APP_PATH"; then
    clear_bundle_detritus "$APP_PATH"
    codesign --force --options runtime --timestamp \
      --sign "$SIGN_IDENTITY" \
      --entitlements "$ROOT_DIR/FocusYou/FocusYou.entitlements" \
      "$APP_PATH" || fail "App signing failed"
  fi

  info "Verifying Developer ID signature..."
  clear_bundle_detritus "$APP_PATH"
  codesign --verify --deep --strict --verbose=2 "$APP_PATH" || fail "Code signing verification failed"
  pass "App signed and verified"
else
  info "Skipping code signing (--skip-sign)"
fi

# ─── Step 5: Notarization (optional) ─────────────────────────

if [[ "$SKIP_SIGN" -eq 0 && "$SKIP_NOTARIZE" -eq 0 ]]; then
  info "Creating ZIP for notarization..."
  NOTARIZE_ZIP="$BUILD_DIR/$SCHEME-notarize.zip"
  ditto -c -k --keepParent "$APP_PATH" "$NOTARIZE_ZIP"

  info "Submitting for notarization..."
  xcrun notarytool submit "$NOTARIZE_ZIP" \
    --keychain-profile "FocusYou-Notarize" \
    --wait || fail "Notarization failed"

  info "Stapling notarization ticket..."
  xcrun stapler staple "$APP_PATH" || fail "Stapling failed"

  rm -f "$NOTARIZE_ZIP"
  pass "Notarization complete"
else
  info "Skipping notarization"
fi

# ─── Step 6: Create DMG ─────────────────────────────────────

info "Creating DMG..."

DMG_STAGING="$BUILD_DIR/dmg-staging"
rm -rf "$DMG_STAGING"
mkdir -p "$DMG_STAGING"

cp -R "$APP_PATH" "$DMG_STAGING/"
ln -s /Applications "$DMG_STAGING/Applications"

hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$DMG_STAGING" \
  -ov \
  -format UDZO \
  "$DMG_PATH" || fail "DMG creation failed"

rm -rf "$DMG_STAGING"

[[ -f "$DMG_PATH" ]] || fail "DMG not found at $DMG_PATH"
pass "DMG created: $DMG_PATH"

# ─── Summary ─────────────────────────────────────────────────

DMG_SIZE=$(du -sh "$DMG_PATH" | cut -f1)

echo ""
echo "════════════════════════════════════════"
echo "  Release Build Complete"
echo "════════════════════════════════════════"
echo "  Version:  $VERSION"
echo "  DMG:      $DMG_PATH"
echo "  Size:     $DMG_SIZE"
echo "  Signed:   $([ "$SKIP_SIGN" -eq 0 ] && echo 'Yes' || echo 'No')"
echo "  Notarized:$([ "$SKIP_NOTARIZE" -eq 0 ] && [ "$SKIP_SIGN" -eq 0 ] && echo ' Yes' || echo ' No')"
echo "════════════════════════════════════════"
