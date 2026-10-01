#!/usr/bin/env bash
# Git Tools - Bootstrap, Environment & Package Manager Tests
set -euo pipefail

TEST_DIR="$(mktemp -d /tmp/gwt_test_boot_XXXXXX)"
trap 'rm -rf "$TEST_DIR"' EXIT

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR/../lib"

source "$LIB_DIR/core.sh"
source "$LIB_DIR/executor.sh"
source "$LIB_DIR/config.sh"
source "$LIB_DIR/repo.sh"
source "$LIB_DIR/env_service.sh"
source "$LIB_DIR/pkg_service.sh"
source "$LIB_DIR/worktree_service.sh"
source "$LIB_DIR/bootstrap_service.sh"

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

echo "=== Running Bootstrap & Environment Tests ==="

MAIN_REPO="$TEST_DIR/main-project"
mkdir -p "$MAIN_REPO"
git -C "$MAIN_REPO" init --initial-branch=main >/dev/null 2>&1
git -C "$MAIN_REPO" config user.name "Test User"
git -C "$MAIN_REPO" config user.email "test@example.com"
echo "init" > "$MAIN_REPO/app.js"
git -C "$MAIN_REPO" add app.js
git -C "$MAIN_REPO" commit -m "feat: init" >/dev/null 2>&1

# Setup environment files in primary worktree
echo "PORT=3000" > "$MAIN_REPO/.env"
echo "LOCAL_SECRET=abc" > "$MAIN_REPO/.env.local"
echo "PROD_SECRET=danger" > "$MAIN_REPO/.env.production"

# 1. Environment Allowlist & Denylist
echo "[1] Testing Environment File Allowlist"
ALLOWED="$(env_find_allowed_files "$MAIN_REPO")"
assert_true "grep -q '^\.env$' <<<'$ALLOWED'" "Includes .env"
assert_true "grep -q '^\.env\.local$' <<<'$ALLOWED'" "Includes .env.local"
assert_true "! grep -q '^\.env\.production$' <<<'$ALLOWED'" "Excludes .env.production by default"

# 2. Copy to target worktree
echo "[2] Testing Environment Copying"
TARGET_WT="$TEST_DIR/wt-feature"
mkdir -p "$TARGET_WT"
env_copy_files "$MAIN_REPO" "$TARGET_WT" "false" >/dev/null 2>&1

assert_true "[[ -f '$TARGET_WT/.env' ]]" ".env was copied"
assert_true "[[ -f '$TARGET_WT/.env.local' ]]" ".env.local was copied"
assert_true "[[ ! -f '$TARGET_WT/.env.production' ]]" ".env.production was NOT copied"

# 3. Do not overwrite existing without force
echo "[3] Testing Overwrite Protection"
echo "CUSTOM_PORT=8080" > "$TARGET_WT/.env"
env_copy_files "$MAIN_REPO" "$TARGET_WT" "false" >/dev/null 2>&1
assert_eq "CUSTOM_PORT=8080" "$(<"$TARGET_WT/.env")" "Existing target .env preserved when overwrite=false"

# 4. Dirty primary worktree does not block env copying
echo "[4] Testing Dirty Primary Worktree"
echo "dirty uncommitted change" >> "$MAIN_REPO/app.js"
touch "$MAIN_REPO/untracked_scratch.tmp"
TARGET_WT2="$TEST_DIR/wt-feature2"
mkdir -p "$TARGET_WT2"
env_copy_files "$MAIN_REPO" "$TARGET_WT2" "false" >/dev/null 2>&1
assert_true "[[ -f '$TARGET_WT2/.env' ]]" "Env copy succeeds even when primary worktree is dirty"

# 5. Duplicate Branch Checkout Guard
echo "[5] Testing Duplicate Branch Checkout Guard"
WT_ALPHA="$TEST_DIR/wt-alpha"
worktree_create_branch "$MAIN_REPO" "$WT_ALPHA" "feature/shared" "true" "main"
assert_true "[[ -d '$WT_ALPHA' ]]" "First worktree with feature/shared created"

WT_BETA="$TEST_DIR/wt-beta"
# Attempting to checkout feature/shared in a second worktree must fail
assert_true "! worktree_create_branch '$MAIN_REPO' '$WT_BETA' 'feature/shared' 'false' '' >/dev/null 2>&1" "Duplicate branch checkout rejected"
assert_true "[[ ! -d '$WT_BETA' ]]" "Conflicting worktree not created"

# 6. Package Manager Detection
echo "[6] Testing Package Manager Detection"
PKG_DIR="$TEST_DIR/npm-project"
mkdir -p "$PKG_DIR"
echo '{"name": "test"}' > "$PKG_DIR/package.json"
touch "$PKG_DIR/package-lock.json"
DETECT_NPM="$(pkg_detect "$PKG_DIR")"
assert_true "grep -q 'npm.*npm ci' <<<'$DETECT_NPM'" "Detects npm ci for package-lock.json"

touch "$PKG_DIR/pnpm-lock.yaml"
DETECT_CONFLICT="$(pkg_detect "$PKG_DIR")"
assert_true "grep -q 'conflicting lockfiles' <<<'$DETECT_CONFLICT'" "Detects conflicting lockfiles"

echo '{"name": "test", "packageManager": "pnpm@9.0.0"}' > "$PKG_DIR/package.json"
DETECT_PM_FIELD="$(pkg_detect "$PKG_DIR")"
assert_true "grep -q 'pnpm.*packageManager field' <<<'$DETECT_PM_FIELD'" "packageManager field resolves conflict"

echo ""
echo "=== Bootstrap Tests Summary: $PASSED passed, $FAILED failed ==="
[[ $FAILED -eq 0 ]]
