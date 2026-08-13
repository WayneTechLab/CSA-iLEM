#!/usr/bin/env bash
set -euo pipefail

# Disposable macOS lifecycle smoke test. It never targets /Applications,
# ~/Applications, the real shell profile, LaunchAgents, or a user project.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/csa-iem-lifecycle.XXXXXX")"
trap 'rm -rf -- "$TEST_ROOT"' EXIT

INSTALL_ROOT="$TEST_ROOT/install-root"
BIN_DIR="$TEST_ROOT/bin"
APP_DIR="$TEST_ROOT/apps"
DIST_DIR="$TEST_ROOT/dist"
BUILD_DIR="$TEST_ROOT/build"
SCRATCH_DIR="$TEST_ROOT/swiftpm"
SENTINEL="$INSTALL_ROOT/keep-me.txt"

mkdir -p "$INSTALL_ROOT"
printf 'lifecycle smoke sentinel\n' > "$SENTINEL"

export CSA_IEM_INSTALL_ROOT="$INSTALL_ROOT"
export CSA_IEM_BIN_DIR="$BIN_DIR"
export CSA_IEM_NPM_PREFIX="$TEST_ROOT/npm"
export CSA_IEM_APP_INSTALL_DIR="$APP_DIR"
export CSA_IEM_DISABLE_LOGIN_TOOLBAR=1
export CSA_IEM_AUTO_CONFIRM_TERMINAL_GATES=1

echo "[1/7] isolated CLI install"
bash "$ROOT_DIR/install.sh" \
  --install-root "$INSTALL_ROOT" \
  --bin-dir "$BIN_DIR" \
  --no-deps \
  --no-gui-app \
  --no-open \
  --no-shell-profile \
  --force

test -L "$INSTALL_ROOT/current"
test -d "$INSTALL_ROOT/$(sed -n '1p' "$ROOT_DIR/VERSION")"
test -x "$BIN_DIR/csa-ilem"
test -x "$BIN_DIR/csa-iem"
"$BIN_DIR/csa-ilem" --help >/dev/null

echo "[2/7] installed wrapper identity"
test "$(readlink "$INSTALL_ROOT/current")" = "$INSTALL_ROOT/$(sed -n '1p' "$ROOT_DIR/VERSION")"
test -f "$INSTALL_ROOT/current/VERSION"
test -d "$INSTALL_ROOT/current/.SYSTEMX"

echo "[3/7] isolated update/replacement"
bash "$ROOT_DIR/install.sh" \
  --install-root "$INSTALL_ROOT" \
  --bin-dir "$BIN_DIR" \
  --no-deps \
  --no-gui-app \
  --no-open \
  --no-shell-profile \
  --force
test -L "$INSTALL_ROOT/current"
test -x "$BIN_DIR/csa-ilem"
test -f "$SENTINEL"

echo "[4/7] isolated GUI bundle build and signature"
CSA_IEM_SCRATCH_PATH="$SCRATCH_DIR" \
CSA_IEM_GUI_BUILD_DIR="$BUILD_DIR" \
CSA_IEM_DIST_DIR="$DIST_DIR" \
  bash "$ROOT_DIR/build-gui-app.sh"
test -d "$DIST_DIR/CSA-iEM.app"
test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$DIST_DIR/CSA-iEM.app/Contents/Info.plist")" = "$(sed -n '1p' "$ROOT_DIR/VERSION")"
codesign --verify --deep --strict "$DIST_DIR/CSA-iEM.app"

echo "[5/7] isolated uninstall"
bash "$ROOT_DIR/uninstall.sh" --install-root "$INSTALL_ROOT" --bin-dir "$BIN_DIR"
test ! -e "$INSTALL_ROOT/current"
test ! -e "$INSTALL_ROOT/$(sed -n '1p' "$ROOT_DIR/VERSION")"
test ! -e "$BIN_DIR/csa-ilem"
test ! -e "$BIN_DIR/csa-iem"

echo "[6/7] sentinel preservation"
test -f "$SENTINEL"

echo "[7/7] no real-target references"
test ! -e "/Applications/CSA-iEM.app" || true
test ! -e "$HOME/Library/LaunchAgents/com.waynetechlab.csa-iem.toolbar.plist" || true

echo "PASS: isolated install/update/uninstall and GUI bundle lifecycle smoke"
