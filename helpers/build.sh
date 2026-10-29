#!/bin/bash
# Compile the Swift helpers into helpers/bin. Needs the Xcode Command Line Tools.
# Rebuilds only what changed. Usage: helpers/build.sh [--force]
set -e
cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1
command -v swiftc >/dev/null || { echo "swiftc not found. Run: xcode-select --install" >&2; exit 1; }
mkdir -p bin
force=0; [ "${1:-}" = --force ] && force=1

for src in *.swift; do
  n="${src%.swift}"
  [ "$n" = wifiscan ] && continue
  if [ $force = 0 ] && [ -x "bin/$n" ] && [ "bin/$n" -nt "$src" ]; then continue; fi
  echo "swiftc  $n"
  swiftc -O "$src" -o "bin/$n"
done

# WifiScan.app: Location permission can only be granted to an app bundle.
APP="bin/WifiScan.app"
if [ $force = 1 ] || [ ! -x "$APP/Contents/MacOS/WifiScan" ] || [ wifiscan.swift -nt "$APP/Contents/MacOS/WifiScan" ]; then
  echo "swiftc  WifiScan.app"
  rm -rf "$APP"; mkdir -p "$APP/Contents/MacOS"
  swiftc -O wifiscan.swift -o "$APP/Contents/MacOS/WifiScan"
  cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>local.sideband.wifiscan</string>
  <key>CFBundleName</key><string>sideband Wi-Fi Scan</string>
  <key>CFBundleDisplayName</key><string>sideband Wi-Fi Scan</string>
  <key>CFBundleExecutable</key><string>WifiScan</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
  <key>NSLocationUsageDescription</key><string>Reads the names of nearby Wi-Fi networks so the Wi-Fi popup can list saved networks in range. The location itself is never used, stored or sent.</string>
  <key>NSLocationWhenInUseUsageDescription</key><string>Reads the names of nearby Wi-Fi networks so the Wi-Fi popup can list saved networks in range. The location itself is never used, stored or sent.</string>
</dict></plist>
PLIST
  codesign --force --sign - "$APP" >/dev/null 2>&1 || echo "warning: could not ad-hoc sign WifiScan.app" >&2
fi
echo "helpers built: $(ls bin | wc -l | tr -d ' ') items in helpers/bin"
