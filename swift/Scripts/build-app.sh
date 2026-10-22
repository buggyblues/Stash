#!/bin/bash
#
# Builds Stash.app from the Swift package.
#
# Usage:
#   Scripts/build-app.sh [--debug] [--sign "Developer ID Application: ..."]
#
# The resulting bundle is written to swift/build/Stash.app.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$PACKAGE_DIR/.." && pwd)"

CONFIGURATION="release"
SIGN_IDENTITY="${STASH_SIGN_IDENTITY:-}"
SIGNING_CONFIG="$PACKAGE_DIR/.swiftpm/signing-identity"
APP_NAME="Stash"
BUNDLE_ID="com.zpaste.app"
QA_PROFILE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --debug)
            CONFIGURATION="debug"
            shift
            ;;
        --qa)
            APP_NAME="Stash-QA"
            BUNDLE_ID="com.zpaste.stash.qa"
            QA_PROFILE="$PACKAGE_DIR/build/qa-profile"
            shift
            ;;
        --sign)
            SIGN_IDENTITY="$2"
            shift 2
            ;;
        *)
            echo "unknown option: $1" >&2
            exit 1
            ;;
    esac
done

# Reuse one local certificate identity so TCC can recognise later builds.
# Explicit --sign and STASH_SIGN_IDENTITY override this per-machine preference.
if [[ -z "$SIGN_IDENTITY" && -f "$SIGNING_CONFIG" ]]; then
    SIGN_IDENTITY="$(cat "$SIGNING_CONFIG")"
fi
if [[ -z "$SIGN_IDENTITY" ]]; then
    SIGNING_CANDIDATES=()
    while IFS= read -r identity; do
        [[ -n "$identity" ]] && SIGNING_CANDIDATES+=("$identity")
    done < <(/usr/bin/security find-identity -v -p codesigning | /usr/bin/sed -En         's/^[[:space:]]*[0-9]+\) ([A-Fa-f0-9]{40}) "(Apple Development|Developer ID Application):.*"$/\1/p')
    if [[ ${#SIGNING_CANDIDATES[@]} -eq 1 ]]; then
        SIGN_IDENTITY="${SIGNING_CANDIDATES[0]}"
    else
        SIGN_IDENTITY="-"
        echo "warning: no single signing identity selected; ad-hoc builds may need Accessibility approval again after rebuilding. Use --sign or STASH_SIGN_IDENTITY to choose a certificate." >&2
    fi
fi

BUILD_DIR="$PACKAGE_DIR/.build/$CONFIGURATION"
APP_DIR="$PACKAGE_DIR/build/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "==> Building the Swift package ($CONFIGURATION)"
cd "$PACKAGE_DIR"
swift build -c "$CONFIGURATION"

echo "==> Assembling the app bundle"
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$BUILD_DIR/Stash" "$MACOS_DIR/Stash"

# The resource bundle of the UI target holds the app icon.
if [[ -d "$BUILD_DIR/Stash_StashUI.bundle" ]]; then
    cp -R "$BUILD_DIR/Stash_StashUI.bundle" "$RESOURCES_DIR/"
fi

# The application icon.
if [[ -f "$REPO_ROOT/resources/icon.icns" ]]; then
    cp "$REPO_ROOT/resources/icon.icns" "$RESOURCES_DIR/icon.icns"
fi

VERSION="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$PACKAGE_DIR/Scripts/Info.plist")"

cat > "$CONTENTS_DIR/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>Stash</string>
    <key>CFBundleIconFile</key>
    <string>icon</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>
    <string>$APP_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>$VERSION</string>
    <key>LSMinimumSystemVersion</key>
    <string>12.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>AGPL-3.0-or-later</string>
    <key>NSAppleEventsUsageDescription</key>
    <string>Stash needs to control other apps to paste the clipboard content into the app you are working in.</string>
    <key>NSUserActivityTypes</key>
    <array/>
    <key>StashImplementation</key>
    <string>swift</string>
</dict>
</plist>
PLIST

if [[ -n "$QA_PROFILE" ]]; then
    /usr/libexec/PlistBuddy -c "Add :LSEnvironment dict" "$CONTENTS_DIR/Info.plist"
    /usr/libexec/PlistBuddy -c "Add :LSEnvironment:STASH_PROFILE_DIRECTORY string $QA_PROFILE" "$CONTENTS_DIR/Info.plist"
fi

echo "==> Signing the bundle ($SIGN_IDENTITY)"
ENTITLEMENTS="$PACKAGE_DIR/Scripts/entitlements.plist"
CODESIGN_ARGS=(--force --options runtime --sign "$SIGN_IDENTITY")
if [[ "$SIGN_IDENTITY" != "-" ]]; then CODESIGN_ARGS+=(--timestamp); fi
if [[ -f "$ENTITLEMENTS" ]]; then
    CODESIGN_ARGS+=(--entitlements "$ENTITLEMENTS")
fi
codesign "${CODESIGN_ARGS[@]}" "$APP_DIR"
codesign --verify --deep --strict "$APP_DIR"
if [[ "$SIGN_IDENTITY" != "-" && -z "$QA_PROFILE" ]]; then
    mkdir -p "$(dirname "$SIGNING_CONFIG")"
    printf '%s\n' "$SIGN_IDENTITY" > "$SIGNING_CONFIG"
fi

echo "==> Done: $APP_DIR"
