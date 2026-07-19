#!/bin/bash
# Build TimezoneMachine and wrap it in a minimal .app bundle, then launch it.
# The bundle exists only so the binary gets an Info.plist: LSUIElement hides the Dock
# icon, and CFBundleIdentifier gives UserDefaults somewhere to store the zone list.
set -euo pipefail
cd "$(dirname "$0")"

swift run TimezoneCheck
swift build -c release --product TimezoneMachine

APP="TimezoneMachine.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/TimezoneMachine "$APP/Contents/MacOS/"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>TimezoneMachine</string>
  <key>CFBundleExecutable</key><string>TimezoneMachine</string>
  <key>CFBundleIdentifier</key><string>com.jony.timezonemachine</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
</dict>
</plist>
PLIST

pkill -x TimezoneMachine || true
# Wait for the old process to actually exit — open'ing while it is still dying fails with -600.
while pgrep -x TimezoneMachine >/dev/null; do sleep 0.1; done
open "$APP"
echo "running — look for the globe in the menu bar"
