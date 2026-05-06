#!/usr/bin/env bash

set -euo pipefail

# Focus You Mac App Store archive/export helper.
#
# Direct Developer ID DMG releases continue to use scripts/release.sh.
# This script archives the AppStore configuration and exports or uploads it
# with App Store Connect signing/export options.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

APP_NAME="Focus You"
SCHEME="FocusYou"
PROJECT="FocusYou.xcodeproj"
CONFIGURATION="AppStore"
TEAM_ID="9VRNY5PMG3"
OUTPUT_DIR="$ROOT_DIR/build/appstore"
BUILD_DIR="${FOCUSYOU_APPSTORE_WORK_DIR:-${TMPDIR:-/tmp}/focusyou-appstore-build}"
ARCHIVE_PATH="$BUILD_DIR/$SCHEME-AppStore.xcarchive"
EXPORT_PATH="$OUTPUT_DIR/export"
EXPORT_OPTIONS_PLIST="$BUILD_DIR/exportOptions-appstore.plist"

SKIP_EXPORT=0
ALLOW_PROVISIONING_UPDATES=0
EXPORT_DESTINATION="export"

info() { printf '\033[0;36mINFO:\033[0m %s\n' "$1"; }
pass() { printf '\033[0;32mPASS:\033[0m %s\n' "$1"; }
fail() { printf '\033[0;31mFAIL:\033[0m %s\n' "$1"; exit 1; }

usage() {
  cat <<'EOF'
Usage: ./scripts/release_appstore.sh [--skip-export] [--upload] [--allow-provisioning-updates]

Options:
  --skip-export                 Create the .xcarchive only.
  --upload                      Export destination is App Store Connect upload.
  --allow-provisioning-updates  Let xcodebuild manage App Store profiles.
  -h, --help                    Show this help.

Output:
  build/appstore/FocusYou-AppStore.xcarchive
  build/appstore/export/        Exported App Store package or upload logs
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-export)
      SKIP_EXPORT=1
      shift
      ;;
    --upload)
      EXPORT_DESTINATION="upload"
      shift
      ;;
    --allow-provisioning-updates)
      ALLOW_PROVISIONING_UPDATES=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      fail "Unknown argument: $1"
      ;;
  esac
done

VERSION=$(grep 'MARKETING_VERSION:' "$ROOT_DIR/project.yml" | head -1 | sed 's/.*: *"\{0,1\}\([^"]*\)"\{0,1\}/\1/' | tr -d '[:space:]')
BUILD_NUMBER=$(grep 'CURRENT_PROJECT_VERSION:' "$ROOT_DIR/project.yml" | head -1 | sed 's/.*: *"\{0,1\}\([^"]*\)"\{0,1\}/\1/' | tr -d '[:space:]')
[[ -n "$VERSION" ]] || fail "Could not read MARKETING_VERSION from project.yml"
[[ -n "$BUILD_NUMBER" ]] || fail "Could not read CURRENT_PROJECT_VERSION from project.yml"

PROVISIONING_ARGS=()
if [[ "$ALLOW_PROVISIONING_UPDATES" -eq 1 ]]; then
  PROVISIONING_ARGS=(-allowProvisioningUpdates)
fi

info "Preparing App Store archive for $APP_NAME $VERSION ($BUILD_NUMBER)"
info "Cleaning build directories..."
rm -rf "$BUILD_DIR"
rm -rf "$OUTPUT_DIR"
mkdir -p "$BUILD_DIR"
mkdir -p "$OUTPUT_DIR"

info "Generating Xcode project..."
xcodegen generate || fail "xcodegen generate failed"
pass "Project generated"

info "Archiving $SCHEME ($CONFIGURATION)..."
xcodebuild archive \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -archivePath "$ARCHIVE_PATH" \
  "${PROVISIONING_ARGS[@]}" \
  SKIP_INSTALL=NO \
  BUILD_LIBRARY_FOR_DISTRIBUTION=NO \
  | tail -40

[[ -d "$ARCHIVE_PATH" ]] || fail "Archive not found at $ARCHIVE_PATH"
ditto --noextattr --norsrc "$ARCHIVE_PATH" "$OUTPUT_DIR/FocusYou-AppStore.xcarchive"
pass "Archive created: $OUTPUT_DIR/FocusYou-AppStore.xcarchive"

if [[ "$SKIP_EXPORT" -eq 1 ]]; then
  info "Skipping export by request"
  exit 0
fi

cat > "$EXPORT_OPTIONS_PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>destination</key>
  <string>$EXPORT_DESTINATION</string>
  <key>generateAppStoreInformation</key>
  <true/>
  <key>manageAppVersionAndBuildNumber</key>
  <false/>
  <key>method</key>
  <string>app-store-connect</string>
  <key>signingStyle</key>
  <string>automatic</string>
  <key>stripSwiftSymbols</key>
  <true/>
  <key>teamID</key>
  <string>$TEAM_ID</string>
  <key>uploadSymbols</key>
  <true/>
</dict>
</plist>
EOF

info "Exporting archive for App Store Connect destination: $EXPORT_DESTINATION"
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_PATH" \
  -exportOptionsPlist "$EXPORT_OPTIONS_PLIST" \
  "${PROVISIONING_ARGS[@]}" \
  | tail -60

pass "App Store export finished: $EXPORT_PATH"
