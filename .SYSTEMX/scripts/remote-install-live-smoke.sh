#!/usr/bin/env bash
set -euo pipefail

# Opt-in networked remote-install smoke. It downloads a GitHub archive and
# installs only into temporary roots; it never changes the shell profile,
# login toolbar, /Applications, or a user project.

if [[ "${CSA_IEM_REMOTE_INSTALL_SMOKE:-0}" != "1" ]]; then
  echo "Set CSA_IEM_REMOTE_INSTALL_SMOKE=1 to run the networked remote-install smoke." >&2
  exit 2
fi

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
REPO_SLUG="${CSA_IEM_REMOTE_REPO:-WayneTechLab/CSA-iLEM}"
REF_VALUE="${CSA_IEM_REMOTE_REF:-main}"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/csa-iem-remote-smoke.XXXXXX")"

cleanup() {
  rm -rf -- "$TEST_ROOT"
}
trap cleanup EXIT

INSTALL_ROOT="$TEST_ROOT/install-root"
BIN_DIR="$TEST_ROOT/bin"
APP_DIR="$TEST_ROOT/apps"

export CSA_IEM_DISABLE_LOGIN_TOOLBAR=1
export CSA_IEM_APP_INSTALL_DIR="$APP_DIR"

echo "Downloading and installing $REPO_SLUG ($REF_VALUE) into a temporary root"
bash "$ROOT_DIR/install-remote.sh" \
  --repo "$REPO_SLUG" \
  --ref "$REF_VALUE" \
  --install-root "$INSTALL_ROOT" \
  --bin-dir "$BIN_DIR" \
  --no-shell-profile \
  --no-deps \
  --no-gui-app \
  --no-open \
  --force

test -L "$INSTALL_ROOT/current"
test -x "$BIN_DIR/csa-iem"
test -x "$BIN_DIR/csa-ilem"
test "$(readlink "$INSTALL_ROOT/current")" = "$INSTALL_ROOT/$(sed -n '1p' "$ROOT_DIR/VERSION")"

(cd "$INSTALL_ROOT/current" && shasum -a 256 -c --strict SHA256SUMS >/dev/null)
export CSA_IEM_SCRATCH_PATH="$TEST_ROOT/swiftpm"
export CSA_IEM_GUI_BUILD_DIR="$TEST_ROOT/build"
export CSA_IEM_DIST_DIR="$INSTALL_ROOT/current/dist"
"$INSTALL_ROOT/current/build-gui-app.sh"
test -d "$INSTALL_ROOT/current/dist/CSA-iEM.app"
codesign --verify --deep --strict "$INSTALL_ROOT/current/dist/CSA-iEM.app"

echo "PASS: networked remote-install, installed-payload, and GUI-build smoke"
