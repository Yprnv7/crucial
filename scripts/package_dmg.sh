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

echo "==> Staging Crucial.app, Applications shortcut, and Gatekeeper helper..."
cp -R "$APP_PATH" "$STAGING/Crucial.app"
find "$STAGING/Crucial.app/Contents/Resources/models" -type l -delete 2>/dev/null || true
xattr -cr "$STAGING/Crucial.app" || true
codesign --force --deep --sign - "$STAGING/Crucial.app"
ln -s /Applications "$STAGING/Applications"

# Add one-click double-clickable installer / Gatekeeper helper script
cat << 'EOF' > "$STAGING/Open Crucial (Bypass Gatekeeper).command"
#!/usr/bin/env bash
DIR="$(cd "$(dirname "$0")" && pwd)"
echo "--------------------------------------------------------"
echo "  Crucial macOS Installer & Gatekeeper Authorization"
echo "--------------------------------------------------------"
echo "==> Installing Crucial to /Applications..."
rm -rf /Applications/Crucial.app
cp -R "$DIR/Crucial.app" /Applications/Crucial.app

echo "==> Authorizing Crucial (removing macOS quarantine)..."
xattr -cr /Applications/Crucial.app

echo "==> Launching Crucial..."
open /Applications/Crucial.app

echo "Crucial is now running from /Applications."
echo ""
echo "Press any key to close this terminal window..."
read -n 1 -s -r
exit 0
EOF
chmod +x "$STAGING/Open Crucial (Bypass Gatekeeper).command"

# Add clean instructions file
cat << 'EOF' > "$STAGING/INSTALL_INSTRUCTIONS.txt"
Crucial for macOS - Installation Guide
======================================

Option 1 (Easiest - 1 Click):
Double-click "Open Crucial (Bypass Gatekeeper).command".
It will automatically install Crucial to /Applications, clear quarantine, and open the app!

Option 2 (Drag & Drop):
1. Drag Crucial.app to the Applications folder shortcut.
2. In Applications, Right-Click (or Control-Click) Crucial and select "Open".
3. When the prompt asks, click "Open".

If macOS Sequoia displays "Apple could not verify Crucial":
1. Open macOS System Settings.
2. Go to "Privacy & Security".
3. Scroll down to "Security".
4. Click "Open Anyway" next to Crucial.
EOF

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
