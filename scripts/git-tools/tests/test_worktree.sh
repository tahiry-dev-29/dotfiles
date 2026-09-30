#!/usr/bin/env bash
# Git Tools - Dedicated Worktree Service Tests
set -euo pipefail

TEST_DIR="$(mktemp -d /tmp/gwt_test_wt_XXXXXX)"
trap 'rm -rf "$TEST_DIR"' EXIT

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR/../lib"

source "$LIB_DIR/core.sh"
source "$LIB_DIR/executor.sh"
source "$LIB_DIR/config.sh"
source "$LIB_DIR/repo.sh"
source "$LIB_DIR/worktree_service.sh"
source "$LIB_DIR/branch_service.sh"
source "$LIB_DIR/commit_service.sh"
source "$LIB_DIR/tag_service.sh"

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

echo "=== Running Worktree Tests ==="

MAIN_REPO="$TEST_DIR/sample-repo"
mkdir -p "$MAIN_REPO"
git -C "$MAIN_REPO" init --initial-branch=main >/dev/null 2>&1
git -C "$MAIN_REPO" config user.name "Test User"
git -C "$MAIN_REPO" config user.email "test@example.com"
echo "Root content" > "$MAIN_REPO/init.txt"
git -C "$MAIN_REPO" add init.txt
git -C "$MAIN_REPO" commit -m "feat: init" >/dev/null 2>&1
git -C "$MAIN_REPO" tag -a "v1.0.0" -m "release v1.0.0" >/dev/null 2>&1

load_config "$MAIN_REPO"

# 1. Path formatting
echo "[1] Testing Worktree Path Pattern Formatting"
FORMATTED="$(format_worktree_path "$MAIN_REPO" "feature/auth")"
assert_eq "$TEST_DIR/sample-repo-feature-auth" "$FORMATTED" "Formats path using ../{repo}-{branch}"

# 2. Tag detached worktree
echo "[2] Testing Tag Detached Worktree Creation"
WT_TAG="$TEST_DIR/wt-tag-1.0.0"
worktree_create_detached "$MAIN_REPO" "$WT_TAG" "v1.0.0"
assert_true "[[ -d '$WT_TAG' ]]" "Tag detached worktree created"
assert_eq "HEAD" "$(git -C "$WT_TAG" rev-parse --abbrev-ref HEAD)" "Tag worktree HEAD is detached"

# 3. Worktree list inspection
echo "[3] Testing Worktree List Query"
WT_LIST="$(worktree_list "$MAIN_REPO")"
assert_true "grep -q 'sample-repo.*main' <<<'$WT_LIST'" "Lists main checkout"
assert_true "grep -q 'wt-tag-1.0.0.*(detached)' <<<'$WT_LIST'" "Lists detached tag worktree"

# 4. Dirty tracking with untracked files
echo "[4] Testing Untracked File Detection"
assert_true "worktree_dirty_check '$WT_TAG'" "Initially clean"
touch "$WT_TAG/untracked.log"
assert_true "! worktree_dirty_check '$WT_TAG'" "Untracked file marked as dirty"

# Clean up
worktree_remove "$MAIN_REPO" "$WT_TAG" "true"
assert_true "[[ ! -d '$WT_TAG' ]]" "Removed successfully"

echo ""
echo "=== Worktree Tests Summary: $PASSED passed, $FAILED failed ==="
[[ $FAILED -eq 0 ]]
