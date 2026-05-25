#!/usr/bin/env bash
set -euo pipefail

APP="dist/ClaudeMonitor.app"

echo "→ Assembling $APP..."
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"

echo "→ Building Swift package..."
swift build -c release 2>&1
cp .build/release/ClaudeMonitor "$APP/Contents/MacOS/ClaudeMonitor"

echo "→ Copying Info.plist..."
cp macos/Info.plist "$APP/Contents/Info.plist"

echo "→ Copying image assets..."
cp assets/claudecode.png "$APP/Contents/Resources/claudecode.png"
cp assets/claudecode.svg "$APP/Contents/Resources/claudecode.svg"
cp assets/github.png "$APP/Contents/Resources/github.png"
cp assets/github@2x.png "$APP/Contents/Resources/github@2x.png"

echo "→ Generating app icon..."
if bash scripts/build-icon.sh "$APP/Contents/Resources"; then
    echo "   ✓ AppIcon.icns copied to bundle."
else
    echo "   ⚠  Icon generation failed — skipping (see above for details)."
fi

echo ""
echo "✓ $APP is ready."
