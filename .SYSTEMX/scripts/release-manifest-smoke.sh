#!/usr/bin/env bash
set -euo pipefail

# Deterministic release-trust smoke test. It validates the same local payload
# contract used by install.sh/install-remote.sh and proves tampering fails
# closed. It does not sign, notarize, publish, or install anything.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

for required in VERSION SHA256SUMS install.sh install-remote.sh; do
  [[ -f "$required" ]] || { echo "FAIL: missing release input $required" >&2; exit 1; }
done

VERSION_VALUE="$(sed -n '1p' VERSION)"
[[ "$VERSION_VALUE" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || {
  echo "FAIL: VERSION is not semantic-version shaped" >&2
  exit 1
}

shasum -a 256 -c --strict SHA256SUMS >/dev/null

TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/csa-iem-release-manifest.XXXXXX")"
cleanup() { rm -rf "$TEMP_DIR"; }
trap cleanup EXIT

cp VERSION install.sh install-remote.sh "$TEMP_DIR/"
awk '$2 == "VERSION" || $2 == "install.sh" || $2 == "install-remote.sh"' SHA256SUMS > "$TEMP_DIR/SHA256SUMS"
(
  cd "$TEMP_DIR"
  shasum -a 256 -c --strict SHA256SUMS >/dev/null
)

printf '# deliberate tamper\n' >> "$TEMP_DIR/install-remote.sh"
if (
  cd "$TEMP_DIR"
  shasum -a 256 -c --strict SHA256SUMS >/dev/null
); then
  echo "FAIL: tampered installer payload passed checksum verification" >&2
  exit 1
fi

echo "PASS: release manifest version $VERSION_VALUE and tamper rejection"
