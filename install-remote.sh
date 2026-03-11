#!/usr/bin/env bash
set -euo pipefail

APP_NAME="CSA-iEM"
APP_VENDOR="Wayne Tech Lab LLC"
REMOTE_INSTALLER_VERSION="0.1.0"
DEFAULT_REPO_SLUG="${CSA_IEM_REPO_SLUG:-WayneTechLab/CSA-iLEM}"
DEFAULT_REF="${CSA_IEM_REF:-main}"
INSTALL_ROOT=""
BIN_DIR=""
USE_FORCE=0
UPDATE_SHELL_PROFILE=1
KEEP_TEMP=0
REF_VALUE="$DEFAULT_REF"
REPO_SLUG="$DEFAULT_REPO_SLUG"

print_help() {
  cat <<EOF
$APP_NAME remote installer
Version: $REMOTE_INSTALLER_VERSION
Provider: $APP_VENDOR

Usage:
  curl -fsSL https://raw.githubusercontent.com/$DEFAULT_REPO_SLUG/main/install-remote.sh | bash
  curl -fsSL https://raw.githubusercontent.com/$DEFAULT_REPO_SLUG/main/install-remote.sh | bash -s -- --force
  curl -fsSL https://raw.githubusercontent.com/$DEFAULT_REPO_SLUG/main/install-remote.sh | bash -s -- --ref your-tag-or-branch
  ./install-remote.sh --version

Options:
  --ref <value>            Branch, tag, or commit to install. Default: $DEFAULT_REF
  --repo <owner/repo>      GitHub repository slug. Default: $DEFAULT_REPO_SLUG
  --install-root <dir>     Override the versioned install root.
  --bin-dir <dir>          Override the command symlink directory.
  --force                  Force reinstall of the target version.
  --no-shell-profile       Do not modify ~/.zprofile.
  --keep-temp              Keep the downloaded temp directory after install.
  --version                Show the installer version.
  --help                   Show this help.
EOF
}

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --help|-h)
      print_help
      exit 0
      ;;
    --version)
      printf '%s remote installer %s\n' "$APP_NAME" "$REMOTE_INSTALLER_VERSION"
      exit 0
      ;;
    --ref)
      shift
      REF_VALUE="${1:-}"
      ;;
    --repo)
      shift
      REPO_SLUG="${1:-}"
      ;;
    --install-root)
      shift
      INSTALL_ROOT="${1:-}"
      ;;
    --bin-dir)
      shift
      BIN_DIR="${1:-}"
      ;;
    --force)
      USE_FORCE=1
      ;;
    --no-shell-profile)
      UPDATE_SHELL_PROFILE=0
      ;;
    --keep-temp)
      KEEP_TEMP=1
      ;;
    *)
      printf 'Unknown argument: %s\n' "$1" >&2
      exit 1
      ;;
  esac
  shift
done

if [[ -z "$REF_VALUE" || -z "$REPO_SLUG" ]]; then
  echo "Both --repo and --ref values must be non-empty." >&2
  exit 1
fi

if [[ "$(uname -s)" != "Darwin" ]]; then
  printf '%s remote installs are supported only on macOS.\n' "$APP_NAME" >&2
  exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
  echo "curl is required to download the installer bundle." >&2
  exit 1
fi

if ! command -v tar >/dev/null 2>&1; then
  echo "tar is required to extract the installer bundle." >&2
  exit 1
fi

if ! command -v mktemp >/dev/null 2>&1; then
  echo "mktemp is required to stage the installer bundle." >&2
  exit 1
fi

TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/csa-iem-install.XXXXXX")"
ARCHIVE_PATH="$TEMP_DIR/csa-iem.tar.gz"
ARCHIVE_URL="https://api.github.com/repos/$REPO_SLUG/tarball/$REF_VALUE"

cleanup() {
  if [[ "$KEEP_TEMP" -eq 0 && -d "$TEMP_DIR" ]]; then
    rm -rf "$TEMP_DIR"
  fi
}
trap cleanup EXIT

echo "Downloading $APP_NAME from $REPO_SLUG ($REF_VALUE)..."
curl --fail --silent --show-error --location \
  --retry 3 --retry-delay 1 --connect-timeout 20 \
  "$ARCHIVE_URL" -o "$ARCHIVE_PATH"

echo "Extracting installer bundle..."
tar -xzf "$ARCHIVE_PATH" -C "$TEMP_DIR"

SOURCE_DIR="$(find "$TEMP_DIR" -mindepth 1 -maxdepth 1 -type d | head -n 1)"
if [[ -z "${SOURCE_DIR:-}" || ! -f "$SOURCE_DIR/install.sh" ]]; then
  echo "The downloaded archive does not contain install.sh." >&2
  exit 1
fi

INSTALL_ARGS=()
if [[ -n "$INSTALL_ROOT" ]]; then
  INSTALL_ARGS+=(--install-root "$INSTALL_ROOT")
fi
if [[ -n "$BIN_DIR" ]]; then
  INSTALL_ARGS+=(--bin-dir "$BIN_DIR")
fi
if [[ "$USE_FORCE" -eq 1 ]]; then
  INSTALL_ARGS+=(--force)
fi
if [[ "$UPDATE_SHELL_PROFILE" -eq 0 ]]; then
  INSTALL_ARGS+=(--no-shell-profile)
fi

echo "Running local installer..."
chmod +x "$SOURCE_DIR/install.sh"
if [[ "${#INSTALL_ARGS[@]}" -gt 0 ]]; then
  "$SOURCE_DIR/install.sh" "${INSTALL_ARGS[@]}"
else
  "$SOURCE_DIR/install.sh"
fi

echo
echo "$APP_NAME remote install finished."
echo "Verify with:"
echo "  source ~/.zprofile"
echo "  csa-iem --version"
if [[ "$KEEP_TEMP" -eq 1 ]]; then
  echo "Temp files kept at: $TEMP_DIR"
fi
