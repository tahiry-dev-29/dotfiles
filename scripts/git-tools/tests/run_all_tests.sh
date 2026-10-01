#!/usr/bin/env bash
# Git Tools - Master Test Suite Runner
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

SUITES=(
  "test_phase1.sh"
  "test_worktree.sh"
  "test_branch.sh"
  "test_remote.sh"
  "test_safety.sh"
  "test_github.sh"
  "test_bootstrap.sh"
  "test_layout.sh"
  "test_manual_tui.sh"
)

TOTAL_SUITES=${#SUITES[@]}
PASSED_SUITES=0
FAILED_SUITES=0

echo "=========================================================="
echo "      Running Git Tools Full Production Test Suite"
echo "=========================================================="
echo ""

for suite in "${SUITES[@]}"; do
  echo "--- Running $suite ---"
  if bash "$SCRIPT_DIR/$suite"; then
    echo "✔ $suite PASSED"
    PASSED_SUITES=$((PASSED_SUITES + 1))
  else
    echo "✘ $suite FAILED"
    FAILED_SUITES=$((FAILED_SUITES + 1))
  fi
  echo ""
done

echo "=========================================================="
echo "Test Execution Summary: $PASSED_SUITES/$TOTAL_SUITES suites passed"
echo "=========================================================="

if [[ $FAILED_SUITES -eq 0 ]]; then
  echo "All test suites passed successfully! 🚀"
  exit 0
else
  echo "Some test suites failed!" >&2
  exit 1
fi
