#!/bin/bash
# Package DeDupo.app into a DMG for distribution.
#
# Prerequisites:
# - DeDupo.app must be built in Release configuration
# - create-dmg tool (brew install create-dmg)
#
# Usage: ./scripts/package-dmg.sh [path/to/DeDupo.app]

set -e

APP_PATH="${1:-build/Release/DeDupo.app}"
VERSION=$(defaults read "$APP_PATH/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null || echo "0.1.0")
DMG_NAME="DeDupo-${VERSION}.dmg"
OUTPUT_DIR="dist"

if [ ! -d "$APP_PATH" ]; then
    echo "Error: $APP_PATH not found."
    echo "Build the app in Release configuration first."
    exit 1
fi

mkdir -p "$OUTPUT_DIR"

# Remove old DMG if it exists
rm -f "$OUTPUT_DIR/$DMG_NAME"

echo "Creating DMG: $DMG_NAME"

# Check if create-dmg is available
if command -v create-dmg &> /dev/null; then
    create-dmg \
        --volname "DeDupo" \
        --volicon "$APP_PATH/Contents/Resources/AppIcon.icns" \
        --window-pos 200 120 \
        --window-size 600 400 \
        --icon-size 100 \
        --icon "DeDupo.app" 175 190 \
        --hide-extension "DeDupo.app" \
        --app-drop-link 425 190 \
        "$OUTPUT_DIR/$DMG_NAME" \
        "$APP_PATH"
else
    # Fallback to hdiutil
    echo "create-dmg not found, using hdiutil..."
    STAGING_DIR=$(mktemp -d)
    cp -R "$APP_PATH" "$STAGING_DIR/"
    ln -s /Applications "$STAGING_DIR/Applications"

    hdiutil create -volname "DeDupo" \
        -srcfolder "$STAGING_DIR" \
        -ov -format UDZO \
        "$OUTPUT_DIR/$DMG_NAME"

    rm -rf "$STAGING_DIR"
fi

echo "DMG created: $OUTPUT_DIR/$DMG_NAME"
