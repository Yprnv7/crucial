#!/usr/bin/env bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$DIR"

echo "==> Building Crucial in release mode..."
swift build -c release

APP_NAME="Crucial.app"
APP_DIR="$DIR/build/$APP_NAME"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "==> Packaging $APP_NAME..."
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# Copy compiled executable
cp ".build/release/Crucial" "$MACOS_DIR/Crucial"
chmod +x "$MACOS_DIR/Crucial"

# Copy AppIcon.icns if available
if [ -f "$DIR/resources/AppIcon.icns" ]; then
    cp "$DIR/resources/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
fi

# Create Info.plist
cat << 'EOF' > "$CONTENTS_DIR/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>Crucial</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.crucial.cleaner</string>
    <key>CFBundleName</key>
    <string>Crucial</string>
    <key>CFBundleDisplayName</key>
    <string>Crucial</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <false/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
    <key>NSDesktopFolderUsageDescription</key>
    <string>Crucial needs access to scan and clean idle developer caches, build artifacts, and junk files on your Desktop.</string>
    <key>NSDocumentsFolderUsageDescription</key>
    <string>Crucial needs access to scan and clean idle project caches, node_modules, and build artifacts in Documents.</string>
    <key>NSDownloadsFolderUsageDescription</key>
    <string>Crucial needs access to identify large, idle installer images (DMGs, PKGs, ZIPs) in your Downloads folder.</string>
    <key>NSSystemAdministrationUsageDescription</key>
    <string>Crucial needs administrative access to inspect system caches, Xcode DerivedData, and orphaned application residue.</string>
    <key>NSFullDiskAccessUsageDescription</key>
    <string>Crucial requires Full Disk Access to scan all junk categories, DerivedData, and orphaned application residue without prompting repeatedly.</string>
</dict>
</plist>
EOF

echo "==> Code-signing Crucial.app with stable ad-hoc signature..."
codesign --force --deep --sign - "$APP_DIR"

echo "==> Done! App bundle created at: $APP_DIR"
if [ -w "/Applications" ]; then
    echo "==> Installing to /Applications/Crucial.app..."
    rm -rf "/Applications/$APP_NAME"
    cp -R "$APP_DIR" "/Applications/$APP_NAME"
    codesign --force --deep --sign - "/Applications/$APP_NAME"
fi
echo "You can run it with: open -a Crucial"
