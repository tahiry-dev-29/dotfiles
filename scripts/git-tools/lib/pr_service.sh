#!/usr/bin/env bash
# Git Tools - Pull Request Workflow Service
set -euo pipefail

# Fetch and create a worktree for a GitHub PR
# Mode can be "branch" (creates local branch) or "detached" (no local branch)
pr_create_worktree() {
  local root="$1"
  local pr_num="$2"
  local dest_path="$3"
  local mode="${4:-detached}" # detached or branch
  local head_branch="${5:-pr-$pr_num}"

  log_info "Fetching PR #$pr_num from origin..."
  if [[ "$mode" == "detached" ]]; then
    if ! exec_git "$root" fetch origin "pull/$pr_num/head"; then
      log_err "Failed to fetch PR #$pr_num."
      return 1
    fi
    local pr_sha
    pr_sha="$(git -C "$root" rev-parse FETCH_HEAD)"
    worktree_create_detached "$root" "$dest_path" "$pr_sha"
  else
    if ! exec_git "$root" fetch origin "pull/$pr_num/head:$head_branch"; then
      log_err "Failed to fetch PR #$pr_num into branch '$head_branch'."
      return 1
    fi
    worktree_create_branch "$root" "$dest_path" "$head_branch" "false" ""
  fi
}

# Open PR in web browser
pr_open_web() {
  local root="$1"
  local pr_num="$2"
  gh -R "$(git -C "$root" remote get-url origin)" pr view "$pr_num" --web 2>/dev/null || true
}

# Interactive create PR flow with preview
pr_create_interactive() {
  local root="$1"
  local current_branch
  current_branch="$(git -C "$root" rev-parse --abbrev-ref HEAD)"

  if is_protected_branch "$root" "$current_branch"; then
    log_err "Cannot create a PR from protected branch '$current_branch'."
    return 1
  fi

  local base_branch
  base_branch="$(get_default_base_branch "$root")"
  local title
  title="$(prompt_input "PR Title" "$(git -C "$root" log -1 --format=%s)")"
  [[ -z "$title" ]] && { log_warn "PR creation cancelled: empty title."; return 1; }

  ui_preview_action "Create Pull Request" "gh pr create --base $base_branch --head $current_branch --title '$title' --fill"
  if ! confirm "Submit Pull Request?"; then
    log_warn "PR creation cancelled."
    return 0
  fi

  exec_cmd gh -R "$(git -C "$root" remote get-url origin)" pr create \
    --base "$base_branch" --head "$current_branch" --title "$title" --fill
  github_cache_invalidate "prs_"
}
