#!/bin/bash
set -euo pipefail

# Local universal macOS build script for Dante for Creators.
# For App Store distribution, use `fastlane mac release` or Xcode Archive (AppStore configuration).

SCHEME="Textream"
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$PROJECT_DIR/build/release"
ARCHIVE_ARM="$BUILD_DIR/Dante-arm64.xcarchive"
ARCHIVE_X86="$BUILD_DIR/Dante-x86_64.xcarchive"
APP_NAME="Dante.app"
OUTPUT_DIR="$BUILD_DIR/universal"
OUTPUT_APP="$OUTPUT_DIR/$APP_NAME"
DMG_NAME="Dante-for-Creators.dmg"
DMG_PATH="$BUILD_DIR/$DMG_NAME"
DEVELOPER_ID_ENTITLEMENTS="$PROJECT_DIR/Textream/Textream-DeveloperID.entitlements"

echo "🧹 Cleaning previous build…"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR" "$OUTPUT_DIR"

echo "🔨 Building for Apple Silicon (arm64)…"
xcodebuild archive \
  -project "$PROJECT_DIR/Textream.xcodeproj" \
  -scheme "$SCHEME" \
  -configuration Release \
  -archivePath "$ARCHIVE_ARM" \
  -destination "generic/platform=macOS" \
  ARCHS=arm64 \
  ONLY_ACTIVE_ARCH=NO \
  SKIP_INSTALL=NO \
  BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  DEVELOPMENT_TEAM="" \
  -quiet

echo "🔨 Building for Intel (x86_64)…"
xcodebuild archive \
  -project "$PROJECT_DIR/Textream.xcodeproj" \
  -scheme "$SCHEME" \
  -configuration Release \
  -archivePath "$ARCHIVE_X86" \
  -destination "generic/platform=macOS" \
  ARCHS=x86_64 \
  ONLY_ACTIVE_ARCH=NO \
  SKIP_INSTALL=NO \
  BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  DEVELOPMENT_TEAM="" \
  -quiet

ARM_APP="$ARCHIVE_ARM/Products/Applications/$APP_NAME"
X86_APP="$ARCHIVE_X86/Products/Applications/$APP_NAME"

echo "🧬 Creating universal binary…"
cp -R "$ARM_APP" "$OUTPUT_APP"

has_both_architectures() {
  local architectures
  architectures=" $(lipo -archs "$1") "
  [[ "$architectures" == *" arm64 "* && "$architectures" == *" x86_64 "* ]]
}

# Find all Mach-O binaries and lipo them together
find "$ARM_APP" -type f | while read -r arm_file; do
  rel="${arm_file#$ARM_APP}"
  x86_file="$X86_APP$rel"
  out_file="$OUTPUT_APP$rel"

  if [ -f "$x86_file" ] && file "$arm_file" | grep -q "Mach-O"; then
    # Swift packages can embed prebuilt frameworks that are already universal.
    if has_both_architectures "$arm_file"; then
      continue
    fi
    lipo -create "$arm_file" "$x86_file" -output "$out_file"
    has_both_architectures "$out_file"
  fi
done

# Strip extended attributes / Finder metadata before signing so codesign & Gatekeeper stay clean
xattr -cr "$OUTPUT_APP"

sign_nested_code() {
  local identity="$1"
  shift
  if [ -d "$OUTPUT_APP/Contents/Frameworks" ]; then
    while IFS= read -r -d '' code; do
      if [ "$#" -gt 0 ]; then
        codesign --force --sign "$identity" "$@" "$code"
      else
        codesign --force --sign "$identity" "$code"
      fi
    done < <(find "$OUTPUT_APP/Contents/Frameworks" -depth \
      \( -type d -name '*.framework' -o -type f -name '*.dylib' \) -print0)
  fi
}

if [ -n "${SIGNING_IDENTITY:-}" ]; then
  echo "🖋️  Signing universal app with Developer ID…"
  sign_nested_code "$SIGNING_IDENTITY" --options runtime --timestamp
  codesign \
    --force \
    --sign "$SIGNING_IDENTITY" \
    --options runtime \
    --timestamp \
    --generate-entitlement-der \
    --entitlements "$DEVELOPER_ID_ENTITLEMENTS" \
    "$OUTPUT_APP"

  codesign --verify --deep --strict --verbose=2 "$OUTPUT_APP"
else
  echo "⚠️  SIGNING_IDENTITY is not set; creating a deeply ad-hoc signed build."
  sign_nested_code -
  codesign --force --sign - "$OUTPUT_APP"
  codesign --verify --deep --strict --verbose=2 "$OUTPUT_APP"
fi

echo "📦 Creating DMG…"
rm -f "$DMG_PATH"

DMG_STAGING="$BUILD_DIR/dmg_staging"
rm -rf "$DMG_STAGING"
mkdir -p "$DMG_STAGING"
cp -R "$OUTPUT_APP" "$DMG_STAGING/"
xattr -cr "$DMG_STAGING/$APP_NAME"
ln -s /Applications "$DMG_STAGING/Applications"

hdiutil create \
  -volname "Dante for Creators" \
  -srcfolder "$DMG_STAGING" \
  -ov \
  -format UDZO \
  "$DMG_PATH" \
  -quiet

if [ -n "${SIGNING_IDENTITY:-}" ]; then
  echo "🖋️  Signing DMG with Developer ID…"
  codesign \
    --force \
    --sign "$SIGNING_IDENTITY" \
    --timestamp \
    --identifier com.playbookinteractivemediallc.app.dmg \
    "$DMG_PATH"

  codesign --verify --strict --verbose=2 "$DMG_PATH"

  if [ -n "${APPLE_NOTARY_KEY_PATH:-}" ] && [ -n "${APPLE_NOTARY_KEY_ID:-}" ] && [ -n "${APPLE_NOTARY_ISSUER_ID:-}" ]; then
    echo "🍎 Submitting DMG for Apple notarization (App Store Connect API key)…"
    xcrun notarytool submit "$DMG_PATH" \
      --key "$APPLE_NOTARY_KEY_PATH" \
      --key-id "$APPLE_NOTARY_KEY_ID" \
      --issuer "$APPLE_NOTARY_ISSUER_ID" \
      --wait
    echo "📎 Stapling notarization ticket to DMG and universal app…"
    xcrun stapler staple "$DMG_PATH"
    xcrun stapler validate "$DMG_PATH"
    xcrun stapler staple "$OUTPUT_APP"
    xcrun stapler validate "$OUTPUT_APP"
    spctl --assess --type open --context context:primary-signature --verbose=2 "$DMG_PATH"
    spctl --assess --type execute --verbose=2 "$OUTPUT_APP"
  elif [ -n "${APPLE_ID:-}" ] && [ -n "${APPLE_APP_PASSWORD:-}" ] && [ -n "${APPLE_TEAM_ID:-}" ]; then
    echo "🍎 Submitting DMG for Apple notarization (Apple ID)…"
    xcrun notarytool submit "$DMG_PATH" \
      --apple-id "$APPLE_ID" \
      --password "$APPLE_APP_PASSWORD" \
      --team-id "$APPLE_TEAM_ID" \
      --wait
    echo "📎 Stapling notarization ticket to DMG and universal app…"
    xcrun stapler staple "$DMG_PATH"
    xcrun stapler validate "$DMG_PATH"
    xcrun stapler staple "$OUTPUT_APP"
    xcrun stapler validate "$OUTPUT_APP"
    spctl --assess --type open --context context:primary-signature --verbose=2 "$DMG_PATH"
    spctl --assess --type execute --verbose=2 "$OUTPUT_APP"
  else
    echo "⚠️  Developer ID signed, but notarization credentials are not set; skipping notarytool."
  fi
fi

rm -rf "$DMG_STAGING"

echo ""
echo "✅ Done!"
echo "   App:  $OUTPUT_APP"
echo "   DMG:  $DMG_PATH"
echo ""
lipo -info "$OUTPUT_APP/Contents/MacOS/Dante"
