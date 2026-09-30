#!/usr/bin/env bash
# Git Tools - Issue Workflow Service
set -euo pipefail

# Suggest a clean branch name for an issue
issue_suggest_branch() {
  local issue_num="$1"
  local issue_title="$2"
  local slug
  slug="$(slugify "$issue_title")"

  local pattern="${CFG_ISSUE_BRANCH_PATTERN:-}"
  [[ -z "$pattern" ]] && pattern="feature/{issue}-{slug}"

  local branch="${pattern/\{issue\}/$issue_num}"
  branch="${branch/\{slug\}/$slug}"
  printf '%s\n' "$branch"
}

# Create branch & worktree from an issue
issue_create_worktree() {
  local root="$1"
  local issue_num="$2"
  local issue_title="$3"

  local suggested_branch
  suggested_branch="$(issue_suggest_branch "$issue_num" "$issue_title")"
  local branch
  branch="$(prompt_input "Branch name" "$suggested_branch")"
  [[ -z "$branch" ]] && { log_warn "Cancelled: empty branch name."; return 1; }

  local default_path
  default_path="$(format_worktree_path "$root" "$branch")"
  local dest_path
  dest_path="$(prompt_input "Destination path" "$default_path")"

  local base_branch
  base_branch="$(get_default_base_branch "$root")"

  ui_preview_action "Create Worktree from Issue #$issue_num" \
    "git worktree add -b $branch $dest_path $base_branch"

  if ! confirm "Create branch and worktree?"; then
    log_warn "Cancelled."
    return 0
  fi

  if worktree_create_branch "$root" "$dest_path" "$branch" "true" "$base_branch"; then
    log_ok "Worktree created at $dest_path for Issue #$issue_num"
    return 0
  else
    log_err "Failed to create worktree for Issue #$issue_num."
    [[ -n "$EXEC_STDERR" ]] && printf '%s\n' "$EXEC_STDERR" >&2
    return 1
  fi
}
