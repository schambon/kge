#!/usr/bin/env bash
# Build, sign, notarize and staple a distributable KGE.dmg.
#
# Prerequisites (one-time):
#   - a "Developer ID Application" certificate in your keychain
#   - a notarytool keychain profile:
#       xcrun notarytool store-credentials notary --apple-id <id> --team-id <team>
#
# Usage: scripts/make-dmg.sh [--no-notarize]
# Env:   NOTARY_PROFILE  keychain profile name (default: notary)
#        TEAM_ID         Apple team ID (default: read from project.yml)
set -euo pipefail

cd "$(dirname "$0")/../KGE"

NOTARY_PROFILE="${NOTARY_PROFILE:-notary}"
TEAM_ID="${TEAM_ID:-$(sed -n 's/^ *DEVELOPMENT_TEAM: *//p' project.yml | head -1)}"
NOTARIZE=1
[[ "${1:-}" == "--no-notarize" ]] && NOTARIZE=0
[[ -n "$TEAM_ID" ]] || { echo "TEAM_ID not set and not found in project.yml" >&2; exit 1; }

BUILD=build
DIST=dist
rm -rf "$BUILD" "$DIST"
mkdir -p "$BUILD" "$DIST"

echo "==> Archiving"
xcodebuild -project KGE.xcodeproj -scheme KGE -configuration Release \
  -destination 'generic/platform=macOS' -archivePath "$BUILD/KGE.xcarchive" \
  archive -quiet

cat > "$BUILD/export.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>method</key><string>developer-id</string>
  <key>teamID</key><string>$TEAM_ID</string>
</dict></plist>
PLIST

echo "==> Exporting (Developer ID)"
xcodebuild -exportArchive -archivePath "$BUILD/KGE.xcarchive" \
  -exportOptionsPlist "$BUILD/export.plist" -exportPath "$BUILD/export" -quiet

APP="$BUILD/export/KGE.app"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$APP/Contents/Info.plist")"
DMG="$DIST/KGE-$VERSION.dmg"

echo "==> Creating $DMG"
STAGE="$BUILD/dmg"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname KGE -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
codesign --sign "Developer ID Application" --timestamp "$DMG"

if [[ $NOTARIZE -eq 1 ]]; then
  echo "==> Notarizing (this can take a few minutes)"
  xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$DMG"
  spctl --assess --type open --context context:primary-signature -v "$DMG"
fi

echo "==> Done: KGE/$DMG"
