#!/usr/bin/env bash
set -euo pipefail

SOURCE_PATH="${BASH_SOURCE[0]}"
while [[ -h "$SOURCE_PATH" ]]; do
  SOURCE_DIR="$(cd -P -- "$(dirname -- "$SOURCE_PATH")" && pwd)"
  SOURCE_PATH="$(readlink "$SOURCE_PATH")"
  [[ "$SOURCE_PATH" != /* ]] && SOURCE_PATH="$SOURCE_DIR/$SOURCE_PATH"
done
SCRIPT_DIR="$(cd -P -- "$(dirname -- "$SOURCE_PATH")" && pwd)"
APP_NAME="CSA-iEM"
GUI_TARGET="CSAiEMMacApp"
APP_VERSION="$(sed -n '1p' "$SCRIPT_DIR/VERSION" 2>/dev/null || printf '0.0.0')"
DIST_DIR="${CSA_IEM_DIST_DIR:-$SCRIPT_DIR/dist}"
DIST_APP_DIR="$DIST_DIR/$APP_NAME.app"
SCRATCH_ID="$(printf '%s' "$SCRIPT_DIR" | shasum | awk '{print $1}')"
SCRATCH_PATH="${CSA_IEM_SCRATCH_PATH:-${TMPDIR:-/tmp}/csa-iem-swiftpm-$SCRATCH_ID}"
BUILD_ROOT="${CSA_IEM_GUI_BUILD_DIR:-${TMPDIR:-/tmp}/csa-iem-gui-$SCRATCH_ID}"
APP_DIR="$BUILD_ROOT/$APP_NAME.app"

CLI_FILES=(
  "VERSION"
  "CSA-iLEM.sh"
  "stage2-workspace.sh"
  "stage3-cleanup.sh"
  "repo-consolidation-recovery.py"
  "repo-consolidation-local-cleanup.py"
  "CSA-iLEM-Open.sh"
  "csa-ilem"
  "csa-ilem-open"
  "csa-iem"
  "csa-iem-open"
  "csa-iem-gui"
  "csa-iem-build-gui"
  "openproj"
  "csa-ilem-gui"
  "csa-ilem-build-gui"
  "SHA256SUMS"
  "install-remote.sh"
  "CSA-iEM.ps1"
  "stage2-workspace.ps1"
  "stage3-cleanup.ps1"
  "install.ps1"
  "csa-iem-tray.ps1"
  "install-remote.ps1"
  "update-win.ps1"
  "uninstall.ps1"
  "install.sh"
  "uninstall.sh"
)

RESOURCE_FILES=(
  "README.md"
  "LICENSE.txt"
  "NOTICE.md"
  "TERMS-OF-SERVICE.md"
  "PRIVACY-NOTICE.md"
  "DISCLAIMER.md"
  "CHANGELOG.md"
  "STATUS.md"
  "SECURITY.md"
  "PROJECT-INFO.md"
  "SHA256SUMS"
)

HELP_FILES=(
  "docs/Help-Center.md"
  "docs/Brand-System.md"
  "docs/macOS-App-Notes.md"
  "docs/Windows-11-Notes.md"
  "docs/wiki/CSA-iLEM-Dashboard-and-Module-Matrix.md"
)

print_help() {
  cat <<EOF
$APP_NAME GUI bundle builder
Version: $APP_VERSION

Usage:
  ./build-gui-app.sh
  ./build-gui-app.sh --version
  ./build-gui-app.sh --help

Environment:
  CSA_IEM_SCRATCH_PATH   Override the SwiftPM scratch directory.
  CSA_IEM_GUI_BUILD_DIR  Override the temporary app build directory.
  CSA_IEM_DIST_DIR       Override the published bundle output directory.
EOF
}

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --help|-h)
      print_help
      exit 0
      ;;
    --version)
      printf '%s %s\n' "$APP_NAME" "$APP_VERSION"
      exit 0
      ;;
    *)
      printf 'Unknown argument: %s\n' "$1" >&2
      exit 1
      ;;
  esac
done

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "$APP_NAME GUI builds are supported only on macOS." >&2
  exit 1
fi

if ! command -v swift >/dev/null 2>&1; then
  echo "Swift is required to build the $APP_NAME GUI." >&2
  echo "Install Xcode Command Line Tools or Xcode, then try again." >&2
  exit 1
fi

if ! command -v shasum >/dev/null 2>&1; then
  echo "shasum is required to verify the GUI build payload." >&2
  exit 1
fi
if ! (cd "$SCRIPT_DIR" && shasum -a 256 -c --strict SHA256SUMS >/dev/null); then
  echo "Source checksum verification failed; refresh SHA256SUMS only after reviewing every payload change." >&2
  exit 1
fi

echo "Building $GUI_TARGET..."
swift build --scratch-path "$SCRATCH_PATH" -c release --package-path "$SCRIPT_DIR" --product "$GUI_TARGET"

BIN_DIR="$(swift build --scratch-path "$SCRATCH_PATH" -c release --package-path "$SCRIPT_DIR" --product "$GUI_TARGET" --show-bin-path)"
BIN_PATH="$BIN_DIR/$GUI_TARGET"

if [[ ! -x "$BIN_PATH" ]]; then
  echo "Built GUI binary not found: $BIN_PATH" >&2
  exit 1
fi

rm -rf "$BUILD_ROOT"
mkdir -p "$BUILD_ROOT"
rm -rf "$APP_DIR"
mkdir -p \
  "$APP_DIR/Contents/MacOS" \
  "$APP_DIR/Contents/Resources/CLI" \
  "$APP_DIR/Contents/Resources/Help" \
  "$APP_DIR/Contents/Resources/assets"

cp "$BIN_PATH" "$APP_DIR/Contents/MacOS/$APP_NAME"
chmod +x "$APP_DIR/Contents/MacOS/$APP_NAME"

for file_name in "${CLI_FILES[@]}"; do
  if [[ ! -f "$SCRIPT_DIR/$file_name" ]]; then
    echo "Missing CLI resource: $file_name" >&2
    exit 1
  fi
  cp -f "$SCRIPT_DIR/$file_name" "$APP_DIR/Contents/Resources/CLI/$file_name"
done

for file_name in "${RESOURCE_FILES[@]}"; do
  if [[ ! -f "$SCRIPT_DIR/$file_name" ]]; then
    echo "Missing bundle resource: $file_name" >&2
    exit 1
  fi
  cp -f "$SCRIPT_DIR/$file_name" "$APP_DIR/Contents/Resources/$(basename "$file_name")"
done

for file_name in "${HELP_FILES[@]}"; do
  if [[ ! -f "$SCRIPT_DIR/$file_name" ]]; then
    echo "Missing help resource: $file_name" >&2
    exit 1
  fi
  cp -f "$SCRIPT_DIR/$file_name" "$APP_DIR/Contents/Resources/Help/$(basename "$file_name")"
done

cp -R "$SCRIPT_DIR/assets/." "$APP_DIR/Contents/Resources/assets/"

if command -v iconutil >/dev/null 2>&1; then
  tmp_iconset_dir="$(mktemp -d "${TMPDIR:-/tmp}/csa-iem-iconset.XXXXXX")"
  mkdir -p "$tmp_iconset_dir/AppIcon.iconset"
  cp "$SCRIPT_DIR/assets/AppIcon.appiconset/appicon-16x16@1x.png" "$tmp_iconset_dir/AppIcon.iconset/icon_16x16.png"
  cp "$SCRIPT_DIR/assets/AppIcon.appiconset/appicon-16x16@2x.png" "$tmp_iconset_dir/AppIcon.iconset/icon_16x16@2x.png"
  cp "$SCRIPT_DIR/assets/AppIcon.appiconset/appicon-32x32@1x.png" "$tmp_iconset_dir/AppIcon.iconset/icon_32x32.png"
  cp "$SCRIPT_DIR/assets/AppIcon.appiconset/appicon-32x32@2x.png" "$tmp_iconset_dir/AppIcon.iconset/icon_32x32@2x.png"
  cp "$SCRIPT_DIR/assets/AppIcon.appiconset/appicon-128x128@1x.png" "$tmp_iconset_dir/AppIcon.iconset/icon_128x128.png"
  cp "$SCRIPT_DIR/assets/AppIcon.appiconset/appicon-128x128@2x.png" "$tmp_iconset_dir/AppIcon.iconset/icon_128x128@2x.png"
  cp "$SCRIPT_DIR/assets/AppIcon.appiconset/appicon-256x256@1x.png" "$tmp_iconset_dir/AppIcon.iconset/icon_256x256.png"
  cp "$SCRIPT_DIR/assets/AppIcon.appiconset/appicon-256x256@2x.png" "$tmp_iconset_dir/AppIcon.iconset/icon_256x256@2x.png"
  cp "$SCRIPT_DIR/assets/AppIcon.appiconset/appicon-512x512@1x.png" "$tmp_iconset_dir/AppIcon.iconset/icon_512x512.png"
  cp "$SCRIPT_DIR/assets/AppIcon.appiconset/appicon-512x512@2x.png" "$tmp_iconset_dir/AppIcon.iconset/icon_512x512@2x.png"
  if ! iconutil -c icns "$tmp_iconset_dir/AppIcon.iconset" -o "$APP_DIR/Contents/Resources/AppIcon.icns" >/dev/null 2>&1; then
    echo "Warning: failed to generate AppIcon.icns with iconutil." >&2
  fi
  rm -rf "$tmp_iconset_dir"
fi

chmod +x \
  "$APP_DIR/Contents/Resources/CLI/CSA-iLEM.sh" \
  "$APP_DIR/Contents/Resources/CLI/stage2-workspace.sh" \
  "$APP_DIR/Contents/Resources/CLI/stage3-cleanup.sh" \
  "$APP_DIR/Contents/Resources/CLI/repo-consolidation-recovery.py" \
  "$APP_DIR/Contents/Resources/CLI/repo-consolidation-local-cleanup.py" \
  "$APP_DIR/Contents/Resources/CLI/CSA-iLEM-Open.sh" \
  "$APP_DIR/Contents/Resources/CLI/csa-iem" \
  "$APP_DIR/Contents/Resources/CLI/csa-iem-open" \
  "$APP_DIR/Contents/Resources/CLI/csa-iem-gui" \
  "$APP_DIR/Contents/Resources/CLI/csa-iem-build-gui" \
  "$APP_DIR/Contents/Resources/CLI/csa-ilem" \
  "$APP_DIR/Contents/Resources/CLI/csa-ilem-open" \
  "$APP_DIR/Contents/Resources/CLI/csa-ilem-gui" \
  "$APP_DIR/Contents/Resources/CLI/csa-ilem-build-gui" \
  "$APP_DIR/Contents/Resources/CLI/openproj" \
  "$APP_DIR/Contents/Resources/CLI/install-remote.sh" \
  "$APP_DIR/Contents/Resources/CLI/CSA-iEM.ps1" \
  "$APP_DIR/Contents/Resources/CLI/stage2-workspace.ps1" \
  "$APP_DIR/Contents/Resources/CLI/stage3-cleanup.ps1" \
  "$APP_DIR/Contents/Resources/CLI/install.ps1" \
  "$APP_DIR/Contents/Resources/CLI/csa-iem-tray.ps1" \
  "$APP_DIR/Contents/Resources/CLI/install-remote.ps1" \
  "$APP_DIR/Contents/Resources/CLI/update-win.ps1" \
  "$APP_DIR/Contents/Resources/CLI/uninstall.ps1" \
  "$APP_DIR/Contents/Resources/CLI/install.sh" \
  "$APP_DIR/Contents/Resources/CLI/uninstall.sh"

cat > "$APP_DIR/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "https://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleDisplayName</key>
  <string>$APP_NAME</string>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundleIdentifier</key>
  <string>com.waynetechlab.csa-iem</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>LSApplicationCategoryType</key>
  <string>public.app-category.developer-tools</string>
  <key>CFBundleShortVersionString</key>
  <string>$APP_VERSION</string>
  <key>CFBundleVersion</key>
  <string>$APP_VERSION</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
EOF

if command -v codesign >/dev/null 2>&1; then
  signed_bundle=0
  for _ in 1 2 3; do
    if command -v xattr >/dev/null 2>&1; then
      xattr -cr "$APP_DIR"
      xattr -d com.apple.FinderInfo "$APP_DIR" >/dev/null 2>&1 || true
      xattr -d 'com.apple.fileprovider.fpfs#P' "$APP_DIR" >/dev/null 2>&1 || true
    fi
    if codesign --force --deep --sign - --timestamp=none "$APP_DIR" >/dev/null 2>&1 \
      && codesign --verify --deep --strict "$APP_DIR" >/dev/null 2>&1; then
      signed_bundle=1
      break
    fi
    sleep 0.2
  done
  if [[ "$signed_bundle" -ne 1 ]]; then
    echo "Failed to create a valid ad-hoc signature for $APP_DIR." >&2
    exit 1
  fi
fi

# Documents may be iCloud/File Provider-backed. Publish a clean copy only
# after signing so Finder metadata cannot invalidate the bundle mid-build.
for stale_app in \
  "$DIST_DIR/$APP_NAME "*".app" \
  "$DIST_DIR/CSA-iLEM "*".app" \
  "$DIST_DIR/$APP_NAME-"*".app" \
  "$DIST_DIR/CSA-iLEM-"*".app"; do
  [[ -e "$stale_app" ]] || continue
  rm -rf -- "$stale_app"
done
rm -rf "$DIST_APP_DIR"
ditto --norsrc "$APP_DIR" "$DIST_APP_DIR"
xattr -rc "$DIST_APP_DIR" >/dev/null 2>&1 || true
if command -v codesign >/dev/null 2>&1; then
  if ! codesign --force --deep --sign - --timestamp=none "$DIST_APP_DIR" >/dev/null 2>&1 \
    || ! codesign --verify --deep --strict "$DIST_APP_DIR" >/dev/null 2>&1; then
    echo "Published GUI bundle signature verification failed: $DIST_APP_DIR" >&2
    exit 1
  fi
fi

echo
echo "$APP_NAME GUI bundle created:"
echo "  $DIST_APP_DIR"
echo "SwiftPM scratch path:"
echo "  $SCRATCH_PATH"
echo
echo "Open it with:"
echo "  open '$APP_DIR'"
