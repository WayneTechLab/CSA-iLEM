#!/usr/bin/env bash
set -euo pipefail

# Evaluate only the profile-line builders against malicious path text. This
# does not run install.sh or write a real user shell profile.
ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/csa-iem-profile-escape.XXXXXX")"
trap 'rm -rf -- "$TEST_ROOT"' EXIT
export HOME="$TEST_ROOT/home"
export MARKER="$TEST_ROOT/executed"
mkdir -p -- "$HOME"

eval "$(sed -n '/^escape_shell_double_quoted_literal() {/,/^}/p' "$ROOT_DIR/install.sh")"
eval "$(sed -n '/^build_path_export_line() {/,/^}/p' "$ROOT_DIR/install.sh")"

suffix='segment-$(touch "$MARKER")-`touch "$MARKER"`-quote"-slash\'
for candidate in "$HOME/$suffix" "$TEST_ROOT/outside/$suffix"; do
  export EXPECTED_BIN="$candidate"
  line="$(build_path_export_line "$candidate")"
  for shell_bin in bash zsh; do
    command -v "$shell_bin" >/dev/null 2>&1 || continue
    "$shell_bin" -c "$line; test \"\${PATH%%:*}\" = \"\$EXPECTED_BIN\""
    test ! -e "$MARKER"
  done
done

echo 'PASS: installer profile PATH lines preserve literal paths without executing substitutions'
