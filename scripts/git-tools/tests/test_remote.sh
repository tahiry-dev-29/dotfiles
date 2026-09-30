#!/usr/bin/env bash
# Git Tools - Remote Service Tests
set -euo pipefail

TEST_DIR="$(mktemp -d /tmp/gwt_test_remote_XXXXXX)"
trap 'rm -rf "$TEST_DIR"' EXIT

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR/../lib"

source "$LIB_DIR/core.sh"
source "$LIB_DIR/executor.sh"
source "$LIB_DIR/repo.sh"
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

echo "=== Running Remote Branch Tests ==="

# Setup a fake bare upstream remote and a clone
UPSTREAM="$TEST_DIR/upstream.git"
git init --bare "$UPSTREAM" >/dev/null 2>&1

LOCAL_CLONE="$TEST_DIR/local"
git clone "$UPSTREAM" "$LOCAL_CLONE" >/dev/null 2>&1
git -C "$LOCAL_CLONE" config user.name "Test User"
git -C "$LOCAL_CLONE" config user.email "test@example.com"
echo "Remote init" > "$LOCAL_CLONE/file.txt"
git -C "$LOCAL_CLONE" add file.txt
git -C "$LOCAL_CLONE" commit -m "feat: remote init" >/dev/null 2>&1
git -C "$LOCAL_CLONE" push origin HEAD:main >/dev/null 2>&1

# Push a secondary branch to remote
git -C "$LOCAL_CLONE" checkout -b "feature/remote-test" >/dev/null 2>&1
echo "Remote test branch" > "$LOCAL_CLONE/remote.txt"
git -C "$LOCAL_CLONE" add remote.txt
git -C "$LOCAL_CLONE" commit -m "feat: remote test" >/dev/null 2>&1
git -C "$LOCAL_CLONE" push origin "feature/remote-test" >/dev/null 2>&1

# Switch back to main and delete local branch to simulate pure remote branch
git -C "$LOCAL_CLONE" checkout main >/dev/null 2>&1
git -C "$LOCAL_CLONE" branch -D "feature/remote-test" >/dev/null 2>&1

# 1. Test Remote Branch List
echo "[1] Testing Remote Branch Listing"
REMOTE_LIST="$(remote_branch_list "$LOCAL_CLONE")"
assert_true "grep -q 'origin/feature/remote-test' <<<'$REMOTE_LIST'" "Lists origin/feature/remote-test"
assert_true "! grep -q '/HEAD' <<<'$REMOTE_LIST'" "Filters out /HEAD reference"

# 2. Test Track and Switch
echo "[2] Testing Remote Track and Switch"
remote_track_and_switch "$LOCAL_CLONE" "origin/feature/remote-test"
assert_eq "feature/remote-test" "$(git -C "$LOCAL_CLONE" rev-parse --abbrev-ref HEAD)" "Switches and tracks remote branch"

echo ""
echo "=== Remote Tests Summary: $PASSED passed, $FAILED failed ==="
[[ $FAILED -eq 0 ]]
