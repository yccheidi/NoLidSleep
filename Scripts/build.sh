#!/bin/bash
# Builds build/NoLidSleep.app (universal, ad-hoc signed) and build/NoLidSleep.zip
set -euo pipefail
cd "$(dirname "$0")/.."

APP=build/NoLidSleep.app
VERSION="${VERSION:-0.1.4}"

[ -f Resources/AppIcon.icns ] || swift Scripts/make_icon.swift Resources

swift build -c release --arch arm64 --arch x86_64

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
BIN=$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path 2>/dev/null)
cp "$BIN/NoLidSleep" "$APP/Contents/MacOS/NoLidSleep"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>NoLidSleep</string>
    <key>CFBundleDisplayName</key><string>NoLidSleep</string>
    <key>CFBundleIdentifier</key><string>io.github.yccheidi.NoLidSleep</string>
    <key>CFBundleExecutable</key><string>NoLidSleep</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>${VERSION}</string>
    <key>CFBundleVersion</key><string>${VERSION}</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
EOF

codesign --force --deep --sign - "$APP"

(cd build && rm -f NoLidSleep.zip && ditto -c -k --keepParent NoLidSleep.app NoLidSleep.zip)
echo "Built $APP and build/NoLidSleep.zip"

# Drag-to-install DMG
DMG=build/NoLidSleep.dmg
STAGE=$(mktemp -d)
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
rm -f "$DMG"
hdiutil create -volname "NoLidSleep" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
rm -rf "$STAGE"
echo "Built $DMG"
