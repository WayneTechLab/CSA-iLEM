#!/usr/bin/env bash
set -euo pipefail

portal_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
checkout_dir="$(cd "$portal_dir/.." && pwd -P)"
session_file="$portal_dir/.portal-local/session.json"
node -e 'const s = require(process.argv[1]); if (!s.ready || s.project !== "demo-csa-iem") process.exit(1)' "$session_file"

cd "$checkout_dir"
swift build -c debug --product CSAiEMMacApp
bin_dir="$(swift build -c debug --show-bin-path)"
bundle="$portal_dir/.portal-local/CSA-iEM Portal Test.app"
mkdir -p "$bundle/Contents/MacOS"
cp "$bin_dir/CSAiEMMacApp" "$bundle/Contents/MacOS/CSAiEMPortalTest"
cat > "$bundle/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key><string>CSAiEMPortalTest</string>
  <key>CFBundleIdentifier</key><string>com.waynetechlab.csa-iem.portal-test</string>
  <key>CFBundleName</key><string>CSA-iEM Portal Test</string>
  <key>CFBundleDisplayName</key><string>CSA-iEM Portal Test</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>CFBundleShortVersionString</key><string>0.8.0</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>NSAppTransportSecurity</key><dict><key>NSAllowsLocalNetworking</key><true/></dict>
</dict>
</plist>
PLIST
codesign --force --sign - "$bundle"
open -na "$bundle" --args --portal-sync-fixture "$session_file"
printf 'Opened isolated debug app at %s\n' "$bundle"
