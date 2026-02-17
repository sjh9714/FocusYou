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
BUILD_DIR="$ROOT_DIR/build"
ARCHIVE_PATH="$BUILD_DIR/$SCHEME.xcarchive"

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

# ─── Read version from project.yml ───────────────────────────

VERSION=$(grep 'MARKETING_VERSION:' "$ROOT_DIR/project.yml" | head -1 | sed 's/.*: *"\{0,1\}\([^"]*\)"\{0,1\}/\1/' | tr -d '[:space:]')
[[ -n "$VERSION" ]] || fail "Could not read MARKETING_VERSION from project.yml"
info "Version: $VERSION"

DMG_NAME="FocusYou-${VERSION}.dmg"
DMG_PATH="$BUILD_DIR/$DMG_NAME"

# ─── Clean build directory ───────────────────────────────────

info "Cleaning build directory..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# ─── Step 1: Generate Xcode project ─────────────────────────

info "Generating Xcode project..."
xcodegen generate || fail "xcodegen generate failed"
pass "Project generated"

# ─── Step 2: Archive ─────────────────────────────────────────

info "Archiving $SCHEME..."
xcodebuild archive \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Release \
  -archivePath "$ARCHIVE_PATH" \
  DEVELOPMENT_TEAM="9VRNY5PMG3" \
  CODE_SIGN_IDENTITY="Developer ID Application" \
  CODE_SIGNING_REQUIRED=YES \
  CODE_SIGNING_ALLOWED=YES \
  ENABLE_HARDENED_RUNTIME=YES \
  SKIP_INSTALL=NO \
  BUILD_LIBRARY_FOR_DISTRIBUTION=NO \
  | tail -5

[[ -d "$ARCHIVE_PATH" ]] || fail "Archive not found at $ARCHIVE_PATH"
pass "Archive created"

# ─── Step 3: Extract .app bundle ─────────────────────────────

APP_PATH="$BUILD_DIR/$APP_NAME.app"
cp -R "$ARCHIVE_PATH/Products/Applications/$APP_NAME.app" "$APP_PATH" 2>/dev/null || \
cp -R "$ARCHIVE_PATH/Products/usr/local/bin/$APP_NAME.app" "$APP_PATH" 2>/dev/null || \
fail "Could not extract .app from archive"

[[ -d "$APP_PATH" ]] || fail ".app not found at $APP_PATH"
pass "App extracted: $APP_PATH"

# ─── Step 4: Code signing (optional) ─────────────────────────

if [[ "$SKIP_SIGN" -eq 0 ]]; then
  info "Signing app with Developer ID..."
  # Requires: Developer ID Application certificate in keychain
  codesign --deep --force --options runtime \
    --sign "Developer ID Application" \
    "$APP_PATH" || fail "Code signing failed"
  pass "App signed"
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
