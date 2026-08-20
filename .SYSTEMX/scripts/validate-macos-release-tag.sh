#!/usr/bin/env bash
set -euo pipefail

# Fail-closed macOS release identity check. A release tag must already exist,
# exactly match VERSION, and resolve to the commit currently checked out.

ROOT_DIR="${CSA_IEM_RELEASE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
TAG_VALUE="${1:-${RELEASE_TAG:-}}"

[[ -n "$TAG_VALUE" ]] || { echo "FAIL: a release tag is required" >&2; exit 1; }
[[ "$TAG_VALUE" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || {
  echo "FAIL: release tag must use exact vX.Y.Z syntax: $TAG_VALUE" >&2
  exit 1
}
[[ -f "$ROOT_DIR/VERSION" ]] || { echo "FAIL: VERSION is missing under $ROOT_DIR" >&2; exit 1; }

VERSION_VALUE="$(sed -n '1p' "$ROOT_DIR/VERSION")"
[[ "${TAG_VALUE#v}" == "$VERSION_VALUE" ]] || {
  echo "FAIL: release tag $TAG_VALUE does not match VERSION $VERSION_VALUE" >&2
  exit 1
}

git -C "$ROOT_DIR" show-ref --verify --quiet "refs/tags/$TAG_VALUE" || {
  echo "FAIL: release tag does not exist locally: $TAG_VALUE" >&2
  exit 1
}

TAG_COMMIT="$(git -C "$ROOT_DIR" rev-list -n 1 "refs/tags/$TAG_VALUE")"
HEAD_COMMIT="$(git -C "$ROOT_DIR" rev-parse HEAD)"
[[ "$TAG_COMMIT" == "$HEAD_COMMIT" ]] || {
  echo "FAIL: release tag $TAG_VALUE resolves to $TAG_COMMIT, but checked-out HEAD is $HEAD_COMMIT" >&2
  exit 1
}

echo "PASS: release tag $TAG_VALUE exactly identifies checked-out commit $HEAD_COMMIT"
