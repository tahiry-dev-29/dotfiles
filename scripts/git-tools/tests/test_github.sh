#!/usr/bin/env bash
# Git Tools - GitHub & PR/Issue Unit Tests
set -euo pipefail

TEST_DIR="$(mktemp -d /tmp/gwt_test_gh_XXXXXX)"
trap 'rm -rf "$TEST_DIR"' EXIT

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR/../lib"

source "$LIB_DIR/core.sh"
source "$LIB_DIR/executor.sh"
source "$LIB_DIR/config.sh"
source "$LIB_DIR/repo.sh"
source "$LIB_DIR/github_service.sh"
source "$LIB_DIR/issue_service.sh"
source "$LIB_DIR/pr_service.sh"

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

echo "=== Running GitHub & Issue Workflow Tests ==="

# 1. Slugify utility
echo "[1] Testing Slugify Utility"
assert_eq "authentication-redirect" "$(slugify "Authentication Redirect")" "Converts to lowercase and hyphens"
assert_eq "fix-oauth2-token-refresh" "$(slugify "Fix: OAuth2 Token / Refresh!!")" "Cleans special characters and punctuation"
assert_eq "short" "$(slugify "---short---")" "Strips leading and trailing hyphens"

# 2. Issue Branch Suggestion
echo "[2] Testing Issue Branch Generation"
BRANCH_SUGGEST="$(issue_suggest_branch "421" "Fix authentication timeout")"
assert_eq "feature/421-fix-authentication-timeout" "$BRANCH_SUGGEST" "Formats issue branch using default pattern"

# 3. Provider Detection
echo "[3] Testing Remote Provider Detection"
LOCAL_REPO="$TEST_DIR/local-repo"
mkdir -p "$LOCAL_REPO"
git -C "$LOCAL_REPO" init >/dev/null 2>&1
assert_eq "local" "$(detect_provider "$LOCAL_REPO")" "Detects local repo with no remote"

git -C "$LOCAL_REPO" remote add origin git@github.com:test-user/my-repo.git
assert_eq "github" "$(detect_provider "$LOCAL_REPO")" "Detects github provider from origin URL"

# 4. Fallback when gh is unavailable for non-github repos
echo "[4] Testing Graceful Fallback"
NON_GH_REPO="$TEST_DIR/gitlab-repo"
mkdir -p "$NON_GH_REPO"
git -C "$NON_GH_REPO" init >/dev/null 2>&1
git -C "$NON_GH_REPO" remote add origin git@gitlab.com:test-user/my-repo.git
assert_true "! github_is_available '$NON_GH_REPO'" "github_is_available returns false for non-GitHub remotes"

echo ""
echo "=== GitHub Tests Summary: $PASSED passed, $FAILED failed ==="
[[ $FAILED -eq 0 ]]
