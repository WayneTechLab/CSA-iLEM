#!/usr/bin/env bash
set -euo pipefail

# Disposable contract test for validate-macos-release-tag.sh. It creates only
# a temporary Git repository and never creates, moves, or publishes a real tag.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VALIDATOR="$ROOT_DIR/.SYSTEMX/scripts/validate-macos-release-tag.sh"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/csa-iem-release-tag.XXXXXX")"
trap 'rm -rf -- "$TEST_ROOT"' EXIT

VERSION_VALUE="$(sed -n '1p' "$ROOT_DIR/VERSION")"
MISMATCH_VERSION="9999.0.0"
if [[ "$MISMATCH_VERSION" == "$VERSION_VALUE" ]]; then
  MISMATCH_VERSION="9999.0.1"
fi
git -C "$TEST_ROOT" init -q
git -C "$TEST_ROOT" config user.name "CSA-iEM Release Smoke"
git -C "$TEST_ROOT" config user.email "release-smoke@invalid.local"
printf '%s\n' "$VERSION_VALUE" > "$TEST_ROOT/VERSION"
printf 'release identity fixture\n' > "$TEST_ROOT/proof.txt"
git -C "$TEST_ROOT" add VERSION proof.txt
git -C "$TEST_ROOT" commit -q -m "release fixture"
git -C "$TEST_ROOT" tag "v$VERSION_VALUE"
git -C "$TEST_ROOT" tag "v$MISMATCH_VERSION"

CSA_IEM_RELEASE_ROOT="$TEST_ROOT" bash "$VALIDATOR" "v$VERSION_VALUE" >/dev/null

expect_failure() {
  local label="$1"
  shift
  if CSA_IEM_RELEASE_ROOT="$TEST_ROOT" bash "$VALIDATOR" "$@" >/dev/null 2>&1; then
    echo "FAIL: release validator accepted $label" >&2
    exit 1
  fi
}

expect_failure "a malformed tag" "release-$VERSION_VALUE"
git -C "$TEST_ROOT" tag -d "v$VERSION_VALUE" >/dev/null
expect_failure "the exact VERSION tag when it is missing" "v$VERSION_VALUE"
git -C "$TEST_ROOT" tag "v$VERSION_VALUE"
expect_failure "a tag that disagrees with VERSION" "v$MISMATCH_VERSION"

printf 'new untagged commit\n' >> "$TEST_ROOT/proof.txt"
git -C "$TEST_ROOT" add proof.txt
git -C "$TEST_ROOT" commit -q -m "untagged change"
expect_failure "a valid tag pointing at a different commit" "v$VERSION_VALUE"

echo "PASS: macOS release tag validation accepts only the existing VERSION tag at HEAD"
