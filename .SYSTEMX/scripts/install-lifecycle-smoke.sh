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
export CSA_IEM_DISABLE_PROCESS_STOP=1
export CSA_IEM_AUTO_CONFIRM_TERMINAL_GATES=1
export CSA_IEM_SCRATCH_PATH="$SCRATCH_DIR"
export CSA_IEM_GUI_BUILD_DIR="$BUILD_DIR"

echo "[1/7] isolated CLI install"
bash "$ROOT_DIR/install-remote.sh" --version >/dev/null
bash "$ROOT_DIR/install-remote.sh" --help >/dev/null
if bash "$ROOT_DIR/install-remote.sh" --csa-ilem-unknown-option >/dev/null 2>&1; then
  echo "FAIL: remote installer accepted an unknown option" >&2
  exit 1
fi

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
(cd "$INSTALL_ROOT/current" && shasum -a 256 -c --strict SHA256SUMS >/dev/null)
echo "Installed payload checksum verified"

echo "[2/7] installed wrapper identity"
test "$(readlink "$INSTALL_ROOT/current")" = "$INSTALL_ROOT/$(sed -n '1p' "$ROOT_DIR/VERSION")"
test -f "$INSTALL_ROOT/current/VERSION"
test -d "$INSTALL_ROOT/current/.SYSTEMX"

echo "[3/7] isolated update/replacement"
bash "$ROOT_DIR/install.sh" \
  --install-root "$INSTALL_ROOT" \
  --bin-dir "$BIN_DIR" \
  --no-deps \
  --no-open \
  --no-shell-profile \
  --force
test -L "$INSTALL_ROOT/current"
test -x "$BIN_DIR/csa-ilem"
test -f "$SENTINEL"
test -d "$APP_DIR/CSA-iEM.app"
test ! -e "$INSTALL_ROOT/current/dist/CSA-iEM.app"
if find "$INSTALL_ROOT" -type d -name 'CSA-iEM.app' -print -quit | grep -q .; then
  echo "FAIL: installer retained a duplicate runnable app in the versioned install tree" >&2
  exit 1
fi

echo "[4/7] canonical GUI bundle identity and signature"
test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP_DIR/CSA-iEM.app/Contents/Info.plist")" = "com.waynetechlab.csa-iem"
test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_DIR/CSA-iEM.app/Contents/Info.plist")" = "$(sed -n '1p' "$ROOT_DIR/VERSION")"
codesign --verify --deep --strict "$APP_DIR/CSA-iEM.app"

echo "[5/7] isolated uninstall"
bash "$ROOT_DIR/uninstall.sh" --install-root "$INSTALL_ROOT" --bin-dir "$BIN_DIR"
test ! -e "$INSTALL_ROOT/current"
test ! -e "$INSTALL_ROOT/$(sed -n '1p' "$ROOT_DIR/VERSION")"
test ! -e "$BIN_DIR/csa-ilem"
test ! -e "$BIN_DIR/csa-iem"

echo "[6/7] sentinel preservation"
test -f "$SENTINEL"

echo "[7/7] no real-target references"
case "$INSTALL_ROOT:$BIN_DIR:$APP_DIR" in
  "$TEST_ROOT"/*:"$TEST_ROOT"/*:"$TEST_ROOT"/*) ;;
  *) echo "FAIL: lifecycle smoke escaped its temporary root" >&2; exit 1 ;;
esac

echo "PASS: isolated install/update/uninstall, canonical-only GUI, and signature lifecycle smoke"
