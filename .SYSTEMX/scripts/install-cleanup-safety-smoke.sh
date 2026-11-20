#!/usr/bin/env bash
set -euo pipefail

# Exercise installer cleanup helpers inside disposable directories. Do not run
# the install entrypoint or touch /Applications, shell profiles, or user data.
ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/csa-iem-install-safety.XXXXXX")"
trap 'rm -rf -- "$TEST_ROOT"' EXIT

sed '/^while \[\[ "\$#" -gt 0 \]\]; do$/,$d' "$ROOT_DIR/install.sh" > "$TEST_ROOT/install-functions.sh"
source "$TEST_ROOT/install-functions.sh"
APP_VERSION="$(sed -n '1p' "$ROOT_DIR/VERSION")"
INSTALL_ROOT="$TEST_ROOT/install"
mkdir -p -- "$INSTALL_ROOT"
validate_install_root
INSTALL_DIR="$INSTALL_ROOT/$APP_VERSION"

make_install() {
  local candidate="$1"
  local version="$2"
  local marked="$3"
  mkdir -p -- "$candidate"
  printf '%s\n' "$version" > "$candidate/VERSION"
  : > "$candidate/install.sh"
  : > "$candidate/csa-iem"
  : > "$candidate/SHA256SUMS"
  if [[ "$marked" == "yes" ]]; then
    printf '%s|%s\n' "$APP_BUNDLE_IDENTIFIER" "$version" > "$candidate/$INSTALL_RECEIPT_NAME"
  fi
}

mkdir -p -- "$INSTALL_DIR"
printf 'private data\n' > "$INSTALL_DIR/important.txt"
if prepare_current_install_version >/dev/null 2>&1; then
  echo 'FAIL: unrecognized same-version directory was replaced' >&2
  exit 1
fi
test -f "$INSTALL_DIR/important.txt"

rm -rf -- "$INSTALL_DIR"
make_install "$INSTALL_DIR" "$APP_VERSION" no
prepare_current_install_version
test ! -e "$INSTALL_DIR"
test "$(find "$INSTALL_ROOT" -mindepth 1 -maxdepth 1 -name ".csa-iem-preserved-$APP_VERSION-*" -type d | wc -l | tr -d ' ')" = 1
INSTALL_ROLLBACK_DIR=""
INSTALL_ROLLBACK_KIND=""

make_install "$INSTALL_DIR" "$APP_VERSION" yes
printf 'previous usable version\n' > "$INSTALL_DIR/prior-sentinel.txt"
STAGED_INSTALL_DIR="$(mktemp -d "$INSTALL_ROOT/.csa-iem-test-stage.XXXXXX")"
make_install "$STAGED_INSTALL_DIR" "$APP_VERSION" yes
printf 'invalid checksum\n' > "$STAGED_INSTALL_DIR/SHA256SUMS"
if verify_staged_install "$STAGED_INSTALL_DIR" >/dev/null 2>&1; then
  echo 'FAIL: corrupt staged payload passed verification' >&2
  exit 1
fi
test -f "$INSTALL_DIR/prior-sentinel.txt"

printf '%s\n' 'replacement payload' > "$STAGED_INSTALL_DIR/new-sentinel.txt"
(cd "$STAGED_INSTALL_DIR" && shasum -a 256 VERSION > SHA256SUMS)
verify_staged_install "$STAGED_INSTALL_DIR"
prepare_current_install_version
test ! -e "$INSTALL_DIR"
mv -- "$STAGED_INSTALL_DIR" "$INSTALL_DIR"
STAGED_INSTALL_DIR=""
test -f "$INSTALL_DIR/new-sentinel.txt"
rollback_current_install_version
test -f "$INSTALL_DIR/prior-sentinel.txt"
test ! -e "$INSTALL_DIR/new-sentinel.txt"

make_install "$INSTALL_ROOT/0.7.0" 0.7.0 yes
make_install "$INSTALL_ROOT/0.6.0" 0.6.0 no
make_install "$INSTALL_ROOT/0.5.0" 0.5.0 yes
mkdir -p -- "$INSTALL_ROOT/0.5.0/dist/CSA-iEM.app/Contents"
printf 'user app copy\n' > "$INSTALL_ROOT/0.5.0/dist/CSA-iEM.app/Contents/keep.txt"
mkdir -p -- "$INSTALL_ROOT/unrelated-folder"
printf 'keep\n' > "$INSTALL_ROOT/unrelated-folder/data.txt"
cleanup_old_install_versions >/dev/null
test ! -e "$INSTALL_ROOT/0.7.0"
test -d "$INSTALL_ROOT/0.6.0"
test -f "$INSTALL_ROOT/0.5.0/dist/CSA-iEM.app/Contents/keep.txt"
test -f "$INSTALL_ROOT/unrelated-folder/data.txt"
test -d "$INSTALL_DIR"

BIN_DIR="$TEST_ROOT/bin"
mkdir -p -- "$BIN_DIR"
printf 'unrelated tool\n' > "$BIN_DIR/csa-iem"
if validate_command_links >/dev/null 2>&1; then
  echo 'FAIL: unrelated command file was accepted for replacement' >&2
  exit 1
fi
test -f "$BIN_DIR/csa-iem"
rm -- "$BIN_DIR/csa-iem"
ln -s -- "$TEST_ROOT/outside-tool" "$BIN_DIR/csa-iem"
if validate_command_links >/dev/null 2>&1; then
  echo 'FAIL: external command symlink was accepted for replacement' >&2
  exit 1
fi
rm -- "$BIN_DIR/csa-iem"
ln -s -- "$INSTALL_DIR/csa-iem" "$BIN_DIR/csa-iem"
validate_command_links

ln -s -- "$TEST_ROOT/outside" "$INSTALL_ROOT/current"
if validate_current_install_link >/dev/null 2>&1; then
  echo 'FAIL: external current symlink was accepted' >&2
  exit 1
fi
rm -- "$INSTALL_ROOT/current"
ln -s -- "$INSTALL_DIR" "$INSTALL_ROOT/current"
validate_current_install_link

ln -s -- "$INSTALL_ROOT" "$TEST_ROOT/install-link"
INSTALL_ROOT="$TEST_ROOT/install-link"
if validate_install_root >/dev/null 2>&1; then
  echo 'FAIL: symlinked install root was accepted' >&2
  exit 1
fi

make_app() {
  local candidate="$1"
  local bundle_id="$2"
  mkdir -p -- "$candidate/Contents"
  cat > "$candidate/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0"><dict><key>CFBundleIdentifier</key><string>$bundle_id</string></dict></plist>
EOF
}

APP_INSTALL_DIR_OVERRIDE="$TEST_ROOT/apps"
make_app "$APP_INSTALL_DIR_OVERRIDE/CSA-iEM.app.backup-owned" "$APP_BUNDLE_IDENTIFIER"
make_app "$APP_INSTALL_DIR_OVERRIDE/CSA-iEM.app.backup-other" "com.example.unrelated"
make_app "$TEST_ROOT/outside.app" "$APP_BUNDLE_IDENTIFIER"
ln -s -- "$TEST_ROOT/outside.app" "$APP_INSTALL_DIR_OVERRIDE/CSA-iEM.app.backup-link"
remove_stale_gui_app_bundles "$APP_INSTALL_DIR_OVERRIDE/CSA-iEM.app" >/dev/null
test -d "$APP_INSTALL_DIR_OVERRIDE/CSA-iEM.app.backup-owned"
test -d "$APP_INSTALL_DIR_OVERRIDE/CSA-iEM.app.backup-other"
test -L "$APP_INSTALL_DIR_OVERRIDE/CSA-iEM.app.backup-link"
test -d "$TEST_ROOT/outside.app"

make_app "$INSTALL_DIR/dist/CSA-iEM.app" "$APP_BUNDLE_IDENTIFIER"
printf 'nested data\n' > "$INSTALL_DIR/dist/CSA-iEM.app/Contents/keep.txt"
remove_legacy_install_tree_app_bundle >/dev/null
test -f "$INSTALL_DIR/dist/CSA-iEM.app/Contents/keep.txt"

ROLLBACK_TEST_ROOT="$APP_INSTALL_DIR_OVERRIDE/.csa-iem-rollback-test"
make_app "$ROLLBACK_TEST_ROOT/CSA-iEM.app" "$APP_BUNDLE_IDENTIFIER"
printf 'prior app data\n' > "$ROLLBACK_TEST_ROOT/CSA-iEM.app/Contents/keep.txt"
PRIOR_IDENTITY="$(stat -f '%d:%i' "$ROLLBACK_TEST_ROOT/CSA-iEM.app")"
preserve_prior_gui_app_bundle "$ROLLBACK_TEST_ROOT" "$ROLLBACK_TEST_ROOT/CSA-iEM.app" >/dev/null
RETAINED_APP="$(find "$INSTALL_ROOT/Recovery/InstalledApps" -mindepth 2 -maxdepth 2 -type d -name 'CSA-iEM.app' -print -quit)"
test -n "$RETAINED_APP"
test "$(stat -f '%d:%i' "$RETAINED_APP")" = "$PRIOR_IDENTITY"
test -f "$RETAINED_APP/Contents/keep.txt"
test ! -e "$ROLLBACK_TEST_ROOT"

make_app "$APP_INSTALL_DIR_OVERRIDE/CSA-iEM.app" "$APP_BUNDLE_IDENTIFIER"
make_app "$TEST_ROOT/other-app/CSA-iEM.app" "$APP_BUNDLE_IDENTIFIER"
mkdir -p -- "$APP_INSTALL_DIR_OVERRIDE/CSA-iEM.app/Contents/MacOS" "$TEST_ROOT/other-app/CSA-iEM.app/Contents/MacOS"
cat > "$TEST_ROOT/idle-app.c" <<'EOF'
#include <unistd.h>
int main(void) { sleep(30); return 0; }
EOF
cc "$TEST_ROOT/idle-app.c" -o "$APP_INSTALL_DIR_OVERRIDE/CSA-iEM.app/Contents/MacOS/CSA-iEM"
cp "$APP_INSTALL_DIR_OVERRIDE/CSA-iEM.app/Contents/MacOS/CSA-iEM" "$TEST_ROOT/other-app/CSA-iEM.app/Contents/MacOS/CSA-iEM"
"$APP_INSTALL_DIR_OVERRIDE/CSA-iEM.app/Contents/MacOS/CSA-iEM" &
OWNED_PID=$!
"$TEST_ROOT/other-app/CSA-iEM.app/Contents/MacOS/CSA-iEM" &
OTHER_PID=$!
sleep 0.1
DISABLE_PROCESS_STOP=0
stop_running_gui_instances "$APP_INSTALL_DIR_OVERRIDE/CSA-iEM.app"
OWNED_STATE="$(ps -p "$OWNED_PID" -o stat= 2>/dev/null || true)"
if [[ -n "$OWNED_STATE" && "$OWNED_STATE" != Z* ]]; then
  echo 'FAIL: target app process was not stopped' >&2
  exit 1
fi
wait "$OWNED_PID" 2>/dev/null || true
if ! kill -0 "$OTHER_PID" 2>/dev/null; then
  echo 'FAIL: unrelated same-name app process was stopped' >&2
  exit 1
fi
kill "$OTHER_PID" 2>/dev/null || true
wait "$OTHER_PID" 2>/dev/null || true

UNINSTALL_ROOT="$TEST_ROOT/uninstall"
UNINSTALL_BIN="$TEST_ROOT/uninstall-bin"
make_install "$UNINSTALL_ROOT/$APP_VERSION" "$APP_VERSION" no
mkdir -p -- "$UNINSTALL_BIN" "$UNINSTALL_ROOT/unrelated-folder"
printf 'keep\n' > "$UNINSTALL_ROOT/unrelated-folder/data.txt"
if bash "$ROOT_DIR/uninstall.sh" --install-root "$UNINSTALL_ROOT" --bin-dir "$UNINSTALL_BIN" >/dev/null 2>&1; then
  echo 'FAIL: uninstaller accepted an unmarked version directory' >&2
  exit 1
fi
test -d "$UNINSTALL_ROOT/$APP_VERSION"
test -f "$UNINSTALL_ROOT/unrelated-folder/data.txt"

printf '%s|%s\n' "$APP_BUNDLE_IDENTIFIER" "$APP_VERSION" > "$UNINSTALL_ROOT/$APP_VERSION/$INSTALL_RECEIPT_NAME"
ln -s -- "$UNINSTALL_ROOT/$APP_VERSION" "$UNINSTALL_ROOT/current"
ln -s -- "$UNINSTALL_ROOT/$APP_VERSION/csa-iem" "$UNINSTALL_BIN/csa-iem"
printf 'unrelated tool\n' > "$UNINSTALL_BIN/openproj"
bash "$ROOT_DIR/uninstall.sh" --install-root "$UNINSTALL_ROOT" --bin-dir "$UNINSTALL_BIN" >/dev/null
test ! -e "$UNINSTALL_ROOT/$APP_VERSION"
test ! -e "$UNINSTALL_ROOT/current"
test ! -e "$UNINSTALL_BIN/csa-iem"
test -f "$UNINSTALL_ROOT/unrelated-folder/data.txt"
test -f "$UNINSTALL_BIN/openproj"

echo 'PASS: verified install staging and rollback, owned cleanup, and guarded uninstall'
