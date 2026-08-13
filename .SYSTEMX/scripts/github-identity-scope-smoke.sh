#!/usr/bin/env bash
set -euo pipefail

# Disposable GitHub identity-scope test. It exercises two owner/login bindings
# without contacting GitHub, changing gh auth state, or using real credentials.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/csa-iem-gh-identity.XXXXXX")"

cleanup() {
  if [[ "$TEST_ROOT" == "${TMPDIR:-/tmp}"/csa-iem-gh-identity.* && -d "$TEST_ROOT" ]]; then
    find "$TEST_ROOT" -depth -delete
  fi
}
trap cleanup EXIT

GH_STUB_ROOT="$TEST_ROOT/bin"

mkdir -p "$GH_STUB_ROOT"

cat > "$GH_STUB_ROOT/gh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "auth" && "${2:-}" == "token" ]]; then
  login=""
  while [[ "$#" -gt 0 ]]; do
    if [[ "$1" == "--user" ]]; then
      shift
      login="${1:-}"
    fi
    shift
  done
  printf 'token-%s\n' "$login"
  exit 0
fi

if [[ "${1:-}" == "api" && "${2:-}" == "user" ]]; then
  if [[ -n "${GH_TOKEN:-}" ]]; then
    if [[ "${GH_STUB_MISMATCH:-0}" == "1" && "$GH_TOKEN" == "token-login-b" ]]; then
      printf 'login-wrong\n'
    else
      printf '%s\n' "${GH_TOKEN#token-}"
    fi
  else
    printf 'ambient-login\n'
  fi
  exit 0
fi

if [[ "${1:-}" == "repo" && "${2:-}" == "list" ]]; then
  exit 0
fi

exit 1
EOF
chmod +x "$GH_STUB_ROOT/gh"

echo "[1/5] two-account binding success"
PATH="$GH_STUB_ROOT:$PATH" GH_CONFIG_DIR="$TEST_ROOT/gh-config" \
  TEST_ROOT="$TEST_ROOT" ROOT_DIR="$ROOT_DIR" \
  bash -c '
    set -euo pipefail
    export CSA_IEM_STAGE3_LIBRARY_ONLY=1
    source "$ROOT_DIR/stage3-cleanup.sh"
    trap - EXIT
    TMP_ROOT="$TEST_ROOT/success-tmp"
    mkdir -p "$TMP_ROOT"
    GITHUB_HOST="github.test"
    GITHUB_ACCOUNT_BINDINGS=("owner-a=login-a" "owner-b=login-b")
    GITHUB_BINDINGS_FILE="$TMP_ROOT/bindings.tsv"
    initialize_github_accounts
    test "$(wc -l < "$GITHUB_BINDINGS_FILE" | tr -d " ")" = 2
    grep -q $"^owner-a\\tlogin-a\\t" "$GITHUB_BINDINGS_FILE"
    grep -q $"^owner-b\\tlogin-b\\t" "$GITHUB_BINDINGS_FILE"
  '
echo "[2/5] independent binding evidence"
test -f "$TEST_ROOT/success-tmp/bindings.tsv"
cat "$TEST_ROOT/success-tmp/bindings.tsv"
grep -q 'owner-a' "$TEST_ROOT/success-tmp/bindings.tsv"
grep -q 'owner-b' "$TEST_ROOT/success-tmp/bindings.tsv"

echo "[3/5] mismatched account response"
set +e
PATH="$GH_STUB_ROOT:$PATH" GH_CONFIG_DIR="$TEST_ROOT/gh-config-mismatch" GH_STUB_MISMATCH=1 \
  TEST_ROOT="$TEST_ROOT" ROOT_DIR="$ROOT_DIR" \
  bash -c '
    set -euo pipefail
    export CSA_IEM_STAGE3_LIBRARY_ONLY=1
    source "$ROOT_DIR/stage3-cleanup.sh"
    trap - EXIT
    TMP_ROOT="$TEST_ROOT/mismatch-tmp"
    mkdir -p "$TMP_ROOT"
    GITHUB_HOST="github.test"
    GITHUB_ACCOUNT_BINDINGS=("owner-a=login-a" "owner-b=login-b")
    GITHUB_BINDINGS_FILE="$TMP_ROOT/bindings.tsv"
    initialize_github_accounts
  ' > "$TEST_ROOT/mismatch.log" 2>&1
mismatch_status=$?
set -e

echo "[4/5] mismatch remains blocked"
test "$mismatch_status" -ne 0
grep -q 'owner-a' "$TEST_ROOT/mismatch-tmp/bindings.tsv"
! grep -q 'owner-b' "$TEST_ROOT/mismatch-tmp/bindings.tsv"

echo "[5/5] no global auth mutation"
test ! -e "$TEST_ROOT/gh-config/hosts.yml"
printf 'Mismatch preflight exit status: %s\n' "$mismatch_status"
echo "PASS: multi-account GitHub identity binding and mismatch fail-closed behavior verified locally"
