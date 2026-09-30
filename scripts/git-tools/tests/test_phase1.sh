#!/usr/bin/env bash
# Git Tools - Phase 1 Integration Tests
# Runs in an isolated temporary Git repository. Never touches real user repositories.
set -euo pipefail

TEST_DIR="$(mktemp -d /tmp/gwt_test_XXXXXX)"
trap 'rm -rf "$TEST_DIR"' EXIT

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR/../lib"

source "$LIB_DIR/core.sh"
source "$LIB_DIR/executor.sh"
source "$LIB_DIR/repo.sh"
source "$LIB_DIR/worktree_service.sh"
source "$LIB_DIR/branch_service.sh"

PASSED=0
FAILED=0

assert_eq() {
  local expected="$1"
  local actual="$2"
  local msg="$3"
  if [[ "$expected" == "$actual" ]]; then
    printf '  ✔ %s\n' "$msg"
    PASSED=$((PASSED + 1))
  else
    printf '  ✘ %s (expected "%s", got "%s")\n' "$msg" "$expected" "$actual" >&2
    FAILED=$((FAILED + 1))
  fi
}

assert_true() {
  local cmd="$1"
  local msg="$2"
  if eval "$cmd"; then
    printf '  ✔ %s\n' "$msg"
    PASSED=$((PASSED + 1))
  else
    printf '  ✘ %s (failed: %s)\n' "$msg" "$cmd" >&2
    FAILED=$((FAILED + 1))
  fi
}

echo "=== Running Phase 1 Git Tools Tests in $TEST_DIR ==="

# 1. Setup isolated test repo
MAIN_REPO="$TEST_DIR/main-repo"
mkdir -p "$MAIN_REPO"
git -C "$MAIN_REPO" init --initial-branch=main >/dev/null 2>&1
git -C "$MAIN_REPO" config user.name "Test User"
git -C "$MAIN_REPO" config user.email "test@example.com"

# Initial commit
echo "Initial content" > "$MAIN_REPO/file.txt"
git -C "$MAIN_REPO" add file.txt
git -C "$MAIN_REPO" commit -m "feat: initial commit" >/dev/null 2>&1
INITIAL_SHA="$(git -C "$MAIN_REPO" rev-parse HEAD)"

# 2. Test Repository Detection
echo "[1] Testing Repository Detection"
TOP_LEVEL="$(require_git_repo "$MAIN_REPO")"
assert_eq "$MAIN_REPO" "$TOP_LEVEL" "Detects top level repo"

SUBDIR="$MAIN_REPO/src/deep/nested"
mkdir -p "$SUBDIR"
assert_eq "$MAIN_REPO" "$(require_git_repo "$SUBDIR")" "Resolves repo from nested subdirectory"

NOT_A_REPO="$TEST_DIR/outside"
mkdir -p "$NOT_A_REPO"
assert_true "! (require_git_repo '$NOT_A_REPO' >/dev/null 2>&1)" "Fails gracefully when outside git repo"

# 3. Test Base & Protected Branches
echo "[2] Testing Branch Properties"
BASE="$(get_default_base_branch "$MAIN_REPO")"
assert_eq "main" "$BASE" "Identifies main as default base branch"
assert_true "is_protected_branch '$MAIN_REPO' 'main'" "main is protected"
assert_true "is_protected_branch '$MAIN_REPO' 'master'" "master is protected"
assert_true "! is_protected_branch '$MAIN_REPO' 'feature/test'" "feature branch is not protected"

# 4. Test Worktree Creation (Branch)
echo "[3] Testing Worktree Branch Creation"
WT_FEATURE="$TEST_DIR/wt-feature"
worktree_create_branch "$MAIN_REPO" "$WT_FEATURE" "feature/my-feature" "true" "main"
assert_true "[[ -d '$WT_FEATURE' ]]" "Worktree directory created"
assert_eq "feature/my-feature" "$(git -C "$WT_FEATURE" rev-parse --abbrev-ref HEAD)" "Worktree has correct branch"

# 5. Test Detached Worktree Creation
echo "[4] Testing Detached Worktree Creation"
WT_DETACHED="$TEST_DIR/wt-detached"
worktree_create_detached "$MAIN_REPO" "$WT_DETACHED" "$INITIAL_SHA"
assert_true "[[ -d '$WT_DETACHED' ]]" "Detached worktree directory created"
assert_eq "HEAD" "$(git -C "$WT_DETACHED" rev-parse --abbrev-ref HEAD)" "Detached worktree HEAD is detached"
assert_eq "$INITIAL_SHA" "$(git -C "$WT_DETACHED" rev-parse HEAD)" "Detached HEAD points to expected commit"

# 6. Test Dirty Worktree Detection
echo "[5] Testing Worktree Dirty Check"
assert_true "worktree_dirty_check '$WT_FEATURE'" "Clean worktree passes dirty check"
echo "uncommitted changes" >> "$WT_FEATURE/file.txt"
assert_true "! worktree_dirty_check '$WT_FEATURE'" "Dirty worktree detected"

# 7. Test Worktree Removal Safety
echo "[6] Testing Safe Worktree Removal"
# Clean removal of detached worktree
worktree_remove "$MAIN_REPO" "$WT_DETACHED" "false"
assert_true "[[ ! -d '$WT_DETACHED' ]]" "Clean worktree removed safely"

# Dirty removal without force must fail
assert_true "! worktree_remove '$MAIN_REPO' '$WT_FEATURE' 'false' >/dev/null 2>&1" "Safe remove refuses dirty worktree"
# Dirty removal with force
worktree_remove "$MAIN_REPO" "$WT_FEATURE" "true"
assert_true "[[ ! -d '$WT_FEATURE' ]]" "Forced remove successfully deleted dirty worktree"

# 8. Test Branch Service & Safe Deletion
echo "[7] Testing Branch Operations & Safety"
git -C "$MAIN_REPO" checkout -b "feature/merged-branch" >/dev/null 2>&1
echo "merged update" >> "$MAIN_REPO/file.txt"
git -C "$MAIN_REPO" commit -am "feat: merged update" >/dev/null 2>&1
git -C "$MAIN_REPO" checkout main >/dev/null 2>&1
git -C "$MAIN_REPO" merge "feature/merged-branch" >/dev/null 2>&1

git -C "$MAIN_REPO" checkout -b "feature/unmerged-branch" >/dev/null 2>&1
echo "unmerged work" >> "$MAIN_REPO/file.txt"
git -C "$MAIN_REPO" commit -am "feat: unmerged work" >/dev/null 2>&1
git -C "$MAIN_REPO" checkout main >/dev/null 2>&1

# Attempt to delete protected branch
assert_true "! branch_delete '$MAIN_REPO' 'main' 'false' >/dev/null 2>&1" "Protected branch deletion rejected"

# Attempt to delete unmerged branch safely
assert_true "! branch_delete '$MAIN_REPO' 'feature/unmerged-branch' 'false' >/dev/null 2>&1" "Safe delete refuses unmerged branch"

# Safe delete merged branch
branch_delete "$MAIN_REPO" "feature/merged-branch" "false"
assert_true "! git -C '$MAIN_REPO' show-ref --verify --quiet refs/heads/feature/merged-branch" "Merged branch safely deleted"

# Force delete unmerged branch
branch_delete "$MAIN_REPO" "feature/unmerged-branch" "true"
assert_true "! git -C '$MAIN_REPO' show-ref --verify --quiet refs/heads/feature/unmerged-branch" "Unmerged branch deleted with force"

echo ""
echo "=== Test Summary: $PASSED passed, $FAILED failed ==="
[[ $FAILED -eq 0 ]]
