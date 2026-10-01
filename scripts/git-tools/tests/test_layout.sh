#!/usr/bin/env bash
# Git Tools - Responsive Layout & Truncation Tests
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR/../lib"

source "$LIB_DIR/core.sh"
source "$LIB_DIR/layout_service.sh"
source "$LIB_DIR/tui_header_footer.sh"

PASSED=0
FAILED=0

assert_eq() {
  local expected="$1" actual="$2" msg="$3"
  if [[ "$expected" == "$actual" ]]; then
    printf '  ✔ %s\n' "$msg"
    PASSED=$((PASSED + 1))
  else
    printf '  ✘ %s (expected "%s", got "%s")\n' "$msg" "$expected" "$actual" >&2
    FAILED=$((FAILED + 1))
  fi
}

assert_true() {
  local cmd="$1" msg="$2"
  if eval "$cmd"; then
    printf '  ✔ %s\n' "$msg"
    PASSED=$((PASSED + 1))
  else
    printf '  ✘ %s (failed: %s)\n' "$msg" "$cmd" >&2
    FAILED=$((FAILED + 1))
  fi
}

echo "=== Running Layout & Truncation Tests ==="

# 1. Path truncation
echo "[1] Testing Path Truncation"
SHORT_PATH="/home/user/app"
assert_eq "/home/user/app" "$(truncate_path "$SHORT_PATH" 30)" "Short path remains unchanged"

LONG_PATH="/very/deep/nested/directory/structure/and/another/folder/my-feature-worktree"
TRUNC_PATH="$(truncate_path "$LONG_PATH" 35)"
assert_true "[[ ${#TRUNC_PATH} -le 35 ]]" "Truncated path respects max length limit"
assert_true "grep -q 'my-feature-worktree' <<<'$TRUNC_PATH'" "Preserves meaningful worktree suffix"

# 2. Text truncation
echo "[2] Testing Text Truncation"
SHORT_TEXT="feature/auth"
assert_eq "feature/auth" "$(truncate_text "$SHORT_TEXT" 20)" "Short text not truncated"

LONG_TEXT="fix: authenticate redirect on invalid session token from oauth provider"
TRUNC_TEXT="$(truncate_text "$LONG_TEXT" 25)"
assert_true "[[ ${#TRUNC_TEXT} -le 25 ]]" "Truncated text respects limit"
assert_true "grep -q '\.\.\.' <<<'$TRUNC_TEXT'" "Contains ellipsis"

# 3. Header & Footer Rendering
echo "[3] Testing Header & Footer Rendering"
HEADER="$(render_header "GWT" "my-project" "main" "3 worktrees")"
assert_true "grep -q 'GWT · my-project' <<<'$HEADER'" "Header contains title and project"
assert_true "grep -q 'branch: main' <<<'$HEADER'" "Header contains branch"

FOOTER_NARROW="$(render_footer "gwt" "narrow")"
assert_true "grep -q 'Help' <<<'$FOOTER_NARROW'" "Narrow footer is compact"

FOOTER_WIDE="$(render_footer "gwt" "wide")"
assert_true "grep -q 'New' <<<'$FOOTER_WIDE'" "Wide footer contains full action set"

echo ""
echo "=== Layout Tests Summary: $PASSED passed, $FAILED failed ==="
[[ $FAILED -eq 0 ]]
