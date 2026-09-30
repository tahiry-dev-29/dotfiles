#!/usr/bin/env bash
# Git Tools - Safety and Command Execution Tests
set -euo pipefail

TEST_DIR="$(mktemp -d /tmp/gwt_test_safety_XXXXXX)"
trap 'rm -rf "$TEST_DIR"' EXIT

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR/../lib"

source "$LIB_DIR/core.sh"
source "$LIB_DIR/executor.sh"
source "$LIB_DIR/repo.sh"
source "$LIB_DIR/branch_service.sh"

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

echo "=== Running Safety Tests ==="

MAIN_REPO="$TEST_DIR/safety-repo"
mkdir -p "$MAIN_REPO"
git -C "$MAIN_REPO" init --initial-branch=main >/dev/null 2>&1
git -C "$MAIN_REPO" config user.name "Test User"
git -C "$MAIN_REPO" config user.email "test@example.com"
echo "Safe content" > "$MAIN_REPO/file.txt"
git -C "$MAIN_REPO" add file.txt
git -C "$MAIN_REPO" commit -m "feat: safe init" >/dev/null 2>&1

# 1. Shell Injection Prevention
echo "[1] Testing Command Injection Resistance"
INJECTION_CANARY="$TEST_DIR/CANARY_TRIGGERED"
MALICIOUS_BRANCH="feat;touch $INJECTION_CANARY"

# Execute safe git branch creation attempt
exec_git "$MAIN_REPO" branch "$MALICIOUS_BRANCH" 2>/dev/null || true

assert_true "[[ ! -f '$INJECTION_CANARY' ]]" "No shell execution triggered via branch argument injection"

# 2. Stderr capture
echo "[2] Testing Error Transparency"
exec_git "$MAIN_REPO" branch -d "nonexistent-branch-to-fail" 2>/dev/null || true
assert_true "[[ $EXEC_EXIT_CODE -ne 0 ]]" "Captures non-zero exit code on failure"
assert_true "[[ -n '$EXEC_STDERR' ]]" "Captures stderr without concealing Git errors"

echo ""
echo "=== Safety Tests Summary: $PASSED passed, $FAILED failed ==="
[[ $FAILED -eq 0 ]]
