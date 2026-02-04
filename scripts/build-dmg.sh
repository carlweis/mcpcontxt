#!/bin/bash
set -e

# Load environment variables from .env if it exists
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
fi

# Build configuration
APP_NAME="MCPControl"
SCHEME="MCPControl"
VERSION="1.0.0"
BUILD_DIR="build"
DIST_DIR="dist"

# Signing configuration (set these in .env or as environment variables)
DEVELOPER_ID="${DEVELOPER_ID:-Developer ID Application: Your Name (TEAM_ID)}"
APPLE_ID="${APPLE_ID:-your@email.com}"
TEAM_ID="${TEAM_ID:-YOUR_TEAM_ID}"
APP_PASSWORD="${APP_PASSWORD:-xxxx-xxxx-xxxx-xxxx}"

echo "==> Building $APP_NAME v$VERSION"

# Create dist directory if it doesn't exist
mkdir -p "$DIST_DIR"

# Step 1: Clean and build release
echo "==> Step 1: Building release..."
xcodebuild -scheme "$SCHEME" \
    -configuration Release \
    -derivedDataPath "$BUILD_DIR" \
    clean build

APP_PATH="$BUILD_DIR/Build/Products/Release/$APP_NAME.app"

if [ ! -d "$APP_PATH" ]; then
    echo "Error: Build failed - $APP_PATH not found"
    exit 1
fi

echo "==> Build complete: $APP_PATH"

# Step 2: Code sign with Developer ID (skip if using default placeholder)
if [[ "$DEVELOPER_ID" != *"Your Name"* ]]; then
    echo "==> Step 2: Code signing with Developer ID..."
    codesign --deep --force --verify --verbose \
        --sign "$DEVELOPER_ID" \
        --options runtime \
        "$APP_PATH"
    echo "==> Code signing complete"
else
    echo "==> Step 2: Skipping code signing (no Developer ID configured)"
    echo "    Set DEVELOPER_ID in .env to enable signing"
fi

# Step 3: Create DMG
echo "==> Step 3: Creating DMG..."
DMG_PATH="$DIST_DIR/$APP_NAME-$VERSION.dmg"

# Remove existing DMG if present
rm -f "$DMG_PATH"

# Check if create-dmg is available
if command -v create-dmg &> /dev/null; then
    create-dmg \
        --volname "$APP_NAME" \
        --window-pos 200 120 \
        --window-size 600 400 \
        --icon-size 100 \
        --icon "$APP_NAME.app" 150 185 \
        --app-drop-link 450 185 \
        "$DMG_PATH" \
        "$APP_PATH"
else
    echo "    create-dmg not found, using hdiutil instead"
    echo "    For prettier DMGs, install create-dmg: brew install create-dmg"

    # Create a temporary directory for DMG contents
    DMG_TEMP="$BUILD_DIR/dmg-temp"
    rm -rf "$DMG_TEMP"
    mkdir -p "$DMG_TEMP"

    # Copy app and create Applications symlink
    cp -R "$APP_PATH" "$DMG_TEMP/"
    ln -s /Applications "$DMG_TEMP/Applications"

    # Create DMG
    hdiutil create -volname "$APP_NAME" \
        -srcfolder "$DMG_TEMP" \
        -ov -format UDZO \
        "$DMG_PATH"

    rm -rf "$DMG_TEMP"
fi

echo "==> DMG created: $DMG_PATH"

# Step 4: Notarize the DMG (skip if using default placeholder)
if [[ "$APPLE_ID" != *"your@email"* ]] && [[ "$APP_PASSWORD" != *"xxxx"* ]]; then
    echo "==> Step 4: Notarizing DMG..."
    xcrun notarytool submit "$DMG_PATH" \
        --apple-id "$APPLE_ID" \
        --team-id "$TEAM_ID" \
        --password "$APP_PASSWORD" \
        --wait

    # Step 5: Staple the notarization ticket
    echo "==> Step 5: Stapling notarization ticket..."
    xcrun stapler staple "$DMG_PATH"
    echo "==> Notarization complete"
else
    echo "==> Step 4: Skipping notarization (credentials not configured)"
    echo "    Set APPLE_ID, TEAM_ID, and APP_PASSWORD in .env to enable notarization"
fi

echo ""
echo "==> Done! DMG ready at: $DMG_PATH"
echo ""
echo "To distribute:"
echo "  1. Upload to GitHub Releases or your website"
echo "  2. Users can download and drag to Applications"
