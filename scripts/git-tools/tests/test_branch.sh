#!/usr/bin/env bash
# Git Tools - Dedicated Branch Service Tests
set -euo pipefail

TEST_DIR="$(mktemp -d /tmp/gwt_test_br_XXXXXX)"
trap 'rm -rf "$TEST_DIR"' EXIT

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR/../lib"

source "$LIB_DIR/core.sh"
source "$LIB_DIR/executor.sh"
source "$LIB_DIR/config.sh"
source "$LIB_DIR/repo.sh"
source "$LIB_DIR/worktree_service.sh"
source "$LIB_DIR/branch_service.sh"
source "$LIB_DIR/remote_service.sh"

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

echo "=== Running Branch Tests ==="

MAIN_REPO="$TEST_DIR/branch-repo"
mkdir -p "$MAIN_REPO"
git -C "$MAIN_REPO" init --initial-branch=main >/dev/null 2>&1
git -C "$MAIN_REPO" config user.name "Test User"
git -C "$MAIN_REPO" config user.email "test@example.com"
echo "Base content" > "$MAIN_REPO/base.txt"
git -C "$MAIN_REPO" add base.txt
git -C "$MAIN_REPO" commit -m "feat: base commit" >/dev/null 2>&1

# Create merged branch
git -C "$MAIN_REPO" checkout -b "feature/done" >/dev/null 2>&1
echo "done" >> "$MAIN_REPO/base.txt"
git -C "$MAIN_REPO" commit -am "feat: done" >/dev/null 2>&1
git -C "$MAIN_REPO" checkout main >/dev/null 2>&1
git -C "$MAIN_REPO" merge "feature/done" >/dev/null 2>&1

# Create unmerged branch
git -C "$MAIN_REPO" checkout -b "feature/wip" >/dev/null 2>&1
echo "wip" >> "$MAIN_REPO/base.txt"
git -C "$MAIN_REPO" commit -am "feat: wip work" >/dev/null 2>&1
git -C "$MAIN_REPO" checkout main >/dev/null 2>&1

load_config "$MAIN_REPO"

# 1. Filters
echo "[1] Testing Branch Filters"
MERGED_LIST="$(branch_list "$MAIN_REPO" "main" "MERGED")"
assert_true "grep -q 'feature/done' <<<'$MERGED_LIST'" "MERGED filter includes feature/done"
assert_true "! grep -q 'feature/wip' <<<'$MERGED_LIST'" "MERGED filter excludes feature/wip"

UNMERGED_LIST="$(branch_list "$MAIN_REPO" "main" "NOT_MERGED")"
assert_true "grep -q 'feature/wip' <<<'$UNMERGED_LIST'" "NOT_MERGED filter includes feature/wip"
assert_true "! grep -q 'feature/done' <<<'$UNMERGED_LIST'" "NOT_MERGED filter excludes feature/done"

# 2. Branch Switch
echo "[2] Testing Safe Branch Switch"
assert_eq "main" "$(git -C "$MAIN_REPO" rev-parse --abbrev-ref HEAD)" "Initially on main"
branch_switch "$MAIN_REPO" "feature/done"
assert_eq "feature/done" "$(git -C "$MAIN_REPO" rev-parse --abbrev-ref HEAD)" "Switched to feature/done"
branch_switch "$MAIN_REPO" "main"
assert_eq "main" "$(git -C "$MAIN_REPO" rev-parse --abbrev-ref HEAD)" "Switched back to main"

# 3. Custom Protected Branches
echo "[3] Testing Custom Protected Branches Config"
git -C "$MAIN_REPO" config gwt.protectedBranches "release/* staging"
assert_true "is_protected_branch '$MAIN_REPO' 'release/v1.0'" "Custom wildcard pattern release/* is protected"
assert_true "is_protected_branch '$MAIN_REPO' 'staging'" "Custom branch staging is protected"
assert_true "! is_protected_branch '$MAIN_REPO' 'feature/auth'" "Standard feature branch is not protected"

# 4. Cannot delete current checkout
echo "[4] Testing Active Branch Delete Protection"
assert_true "! branch_delete '$MAIN_REPO' 'main' 'false' >/dev/null 2>&1" "Refuses deleting current branch"

echo ""
echo "=== Branch Tests Summary: $PASSED passed, $FAILED failed ==="
[[ $FAILED -eq 0 ]]
