#!/usr/bin/env bash
set -euo pipefail

APP_NAME="CSA-iEM"
APP_VENDOR="Wayne Tech Lab LLC"
if [[ -z "${BASH_SOURCE[0]:-}" || ! -f "${BASH_SOURCE[0]}" ]]; then
  echo "Remote install must run from a reviewed local script file; piping a mutable URL into bash is not supported." >&2
  exit 1
fi
REMOTE_INSTALLER_VERSION="$(sed -n '1p' "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/VERSION" 2>/dev/null || printf '0.0.0')"
DEFAULT_REPO_SLUG="WayneTechLab/CSA-iLEM"
INSTALL_ROOT=""
BIN_DIR=""
USE_FORCE=0
UPDATE_SHELL_PROFILE=1
KEEP_TEMP=0
BOOTSTRAP_DEPS=0
INSTALL_GUI_APP=1
OPEN_GUI_APP=1
REF_VALUE=""
EXPECTED_ARCHIVE_SHA256=""
REPO_SLUG="$DEFAULT_REPO_SLUG"

print_help() {
  cat <<EOF
$APP_NAME remote installer
Version: $REMOTE_INSTALLER_VERSION
Provider: $APP_VENDOR

Usage:
  # Run a reviewed local copy with independently obtained release evidence.
  ./install-remote.sh --ref <40-character-commit-sha> --archive-sha256 <64-character-sha256>
  ./install-remote.sh --version

Options:
  --ref <sha>              Exact 40-character Git commit SHA; branches and tags are refused.
  --archive-sha256 <sha>   Expected SHA-256 of the complete GitHub tarball, obtained independently.
  --repo <owner/repo>      GitHub repository slug. Default: $DEFAULT_REPO_SLUG
  --install-root <dir>     Override the versioned install root.
  --bin-dir <dir>          Override the command symlink directory.
  --force                  Force reinstall of the target version.
  --no-shell-profile       Do not modify ~/.zprofile.
  --with-deps              Explicitly allow dependency bootstrap in the local installer.
  --no-deps                Keep dependency bootstrap off (the default).
  --no-gui-app             Do not build or install the native app bundle.
  --no-open                Do not open the installed app after installation.
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
    --archive-sha256)
      shift
      EXPECTED_ARCHIVE_SHA256="${1:-}"
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
    --no-deps)
      BOOTSTRAP_DEPS=0
      ;;
    --with-deps)
      BOOTSTRAP_DEPS=1
      ;;
    --no-gui-app)
      INSTALL_GUI_APP=0
      OPEN_GUI_APP=0
      ;;
    --no-open)
      OPEN_GUI_APP=0
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

if [[ ! "$REF_VALUE" =~ ^[0-9a-f]{40}$ ]]; then
  echo "Remote install requires --ref with an exact lowercase 40-character commit SHA; mutable branches and tags are refused." >&2
  exit 1
fi
if [[ ! "$EXPECTED_ARCHIVE_SHA256" =~ ^[0-9a-f]{64}$ ]]; then
  echo "Remote install requires --archive-sha256 from an independent trusted release record." >&2
  exit 1
fi
if [[ ! "$REPO_SLUG" =~ ^[A-Za-z0-9][A-Za-z0-9_.-]*/[A-Za-z0-9][A-Za-z0-9_.-]*$ || "$REPO_SLUG" == *..* ]]; then
  echo "Remote install requires a valid owner/repository slug." >&2
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

if ! command -v shasum >/dev/null 2>&1; then
  echo "shasum is required to verify the installer bundle." >&2
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
  --proto '=https' --proto-redir '=https' \
  --retry 3 --retry-delay 1 --connect-timeout 20 \
  "$ARCHIVE_URL" -o "$ARCHIVE_PATH"

ACTUAL_ARCHIVE_SHA256="$(shasum -a 256 "$ARCHIVE_PATH" | awk '{print $1}')"
if [[ "$ACTUAL_ARCHIVE_SHA256" != "$EXPECTED_ARCHIVE_SHA256" ]]; then
  echo "Downloaded archive digest does not match the independently supplied SHA-256; nothing was extracted or installed." >&2
  exit 1
fi

echo "Extracting installer bundle..."
tar -xzf "$ARCHIVE_PATH" -C "$TEMP_DIR"

SOURCE_DIR="$(find "$TEMP_DIR" -mindepth 1 -maxdepth 1 -type d | head -n 1)"
if [[ -z "${SOURCE_DIR:-}" || ! -f "$SOURCE_DIR/install.sh" ]]; then
  echo "The downloaded archive does not contain install.sh." >&2
  exit 1
fi

ARCHIVE_VERSION="$(sed -n '1p' "$SOURCE_DIR/VERSION" 2>/dev/null || true)"
if [[ -z "$ARCHIVE_VERSION" ]]; then
  echo "The downloaded archive does not contain a readable VERSION file." >&2
  exit 1
fi

if [[ "$REF_VALUE" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] && [[ "$ARCHIVE_VERSION" != "$REF_VALUE" ]]; then
  echo "Requested ref $REF_VALUE, but the extracted archive reports VERSION $ARCHIVE_VERSION." >&2
  exit 1
fi

if [[ ! -f "$SOURCE_DIR/SHA256SUMS" ]]; then
  echo "The downloaded archive does not contain SHA256SUMS." >&2
  exit 1
fi

echo "Verifying installer bundle checksums..."
(
  cd "$SOURCE_DIR"
  shasum -a 256 -c --strict SHA256SUMS >/dev/null
)

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
if [[ "$BOOTSTRAP_DEPS" -eq 1 ]]; then
  INSTALL_ARGS+=(--with-deps)
fi
if [[ "$INSTALL_GUI_APP" -eq 0 ]]; then
  INSTALL_ARGS+=(--no-gui-app)
fi
if [[ "$OPEN_GUI_APP" -eq 0 ]]; then
  INSTALL_ARGS+=(--no-open)
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
if [[ "$UPDATE_SHELL_PROFILE" -eq 1 ]]; then
  echo "  source ~/.zprofile"
fi
echo "  csa-iem --version"
if [[ "$KEEP_TEMP" -eq 1 ]]; then
  echo "Temp files kept at: $TEMP_DIR"
fi
