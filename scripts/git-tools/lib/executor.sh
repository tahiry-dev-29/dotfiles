#!/usr/bin/env bash
# Git Tools - Safe Command Executor
# Executes processes safely without eval or arbitrary shell interpolation.
set -euo pipefail

EXEC_STDOUT=""
EXEC_STDERR=""
EXEC_EXIT_CODE=0

# Execute command safely, capturing output and exit code
# Usage: exec_cmd git status --porcelain
exec_cmd() {
  local stdout_file stderr_file
  stdout_file="$(mktemp)"
  stderr_file="$(mktemp)"

  EXEC_EXIT_CODE=0
  if "$@" >"$stdout_file" 2>"$stderr_file"; then
    EXEC_EXIT_CODE=0
  else
    EXEC_EXIT_CODE=$?
  fi

  EXEC_STDOUT="$(<"$stdout_file")"
  EXEC_STDERR="$(<"$stderr_file")"

  rm -f "$stdout_file" "$stderr_file"
  return "$EXEC_EXIT_CODE"
}

# Run a git command in a specific directory or repo root
# Usage: exec_git "$repo_root" worktree list --porcelain
exec_git() {
  local dir="$1"
  shift
  exec_cmd git -C "$dir" "$@"
}

# Execute git command and exit with error message if it fails
exec_git_or_fail() {
  local dir="$1"
  local action_desc="$2"
  shift 2

  if ! exec_git "$dir" "$@"; then
    log_err "Failed: $action_desc"
    if [[ -n "$EXEC_STDERR" ]]; then
      log_err "Git returned:"
      printf '%s\n' "$EXEC_STDERR" >&2
    fi
    return "$EXEC_EXIT_CODE"
  fi
  return 0
}
