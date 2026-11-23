#!/usr/bin/env bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$DIR"

APP_PATH="$DIR/build/Crucial.app"
DIST_DIR="$DIR/dist"
DMG_NAME="Crucial-1.0.0-arm64.dmg"
DMG_PATH="$DIST_DIR/$DMG_NAME"
VOLUME_NAME="Crucial Installer"

if [ ! -d "$APP_PATH" ]; then
    echo "Error: $APP_PATH does not exist. Run ./scripts/build_app.sh first."
    exit 1
fi

mkdir -p "$DIST_DIR"
rm -f "$DMG_PATH"

STAGING="/tmp/crucial_dmg_staging"
rm -rf "$STAGING"
mkdir -p "$STAGING"

echo "==> Staging Crucial.app and Applications shortcut..."
cp -R "$APP_PATH" "$STAGING/Crucial.app"
ln -s /Applications "$STAGING/Applications"

echo "==> Building compressed DMG..."
hdiutil create \
    -volname "$VOLUME_NAME" \
    -srcfolder "$STAGING" \
    -ov \
    -format UDZO \
    "$DMG_PATH"

rm -rf "$STAGING"

echo "==> DMG successfully created at: $DMG_PATH"
ls -lh "$DMG_PATH"
