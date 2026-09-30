#!/usr/bin/env bash
# Git Tools - Branch TUI Action Flows
set -euo pipefail

gb_flow_checkout() {
  local root="$1" branch="$2"
  branch_switch "$root" "$branch"
}

gb_flow_create_worktree() {
  local root="$1" branch="$2"
  local clean_branch="${branch#origin/}"
  local default_path
  default_path="$(format_worktree_path "$root" "$clean_branch")"
  local dest_path
  dest_path="$(prompt_input "Destination directory for '$clean_branch'" "$default_path")"

  ui_preview_action "Create Worktree for branch" "git worktree add $dest_path $branch"
  if confirm "Create worktree?"; then
    if worktree_create_branch "$root" "$dest_path" "$branch" "false" ""; then
      log_ok "Worktree created at $dest_path"
    else
      log_err "Failed to create worktree."
      [[ -n "$EXEC_STDERR" ]] && printf '%s\n' "$EXEC_STDERR" >&2
    fi
  else
    log_warn "Cancelled."
  fi
}

gb_flow_delete() {
  local root="$1" branch="$2" base_branch="$3"
  if is_protected_branch "$root" "$branch"; then
    log_err "Branch '$branch' is protected and cannot be deleted."
    return
  fi

  local is_merged=0
  if git -C "$root" branch --merged "$base_branch" --format="%(refname:short)" 2>/dev/null | grep -qx "$branch"; then
    is_merged=1
  fi

  if [[ $is_merged -eq 1 ]]; then
    ui_preview_action "Safe Delete Branch (Merged)" "git branch -d $branch"
    if confirm "Delete merged branch '$branch'?" && branch_delete "$root" "$branch" "false"; then
      log_ok "Branch '$branch' deleted."
    else
      log_err "Failed to delete branch '$branch'."
      [[ -n "$EXEC_STDERR" ]] && printf '%s\n' "$EXEC_STDERR" >&2
    fi
  else
    log_warn "Branch '$branch' is NOT merged into '$base_branch'!"
    ui_preview_action "Force Delete Branch (Unmerged)" "git branch -D $branch"
    if confirm "Force delete unmerged branch '$branch'?" && branch_delete "$root" "$branch" "true"; then
      log_ok "Branch '$branch' force deleted."
    else
      log_err "Failed to force delete branch '$branch'."
      [[ -n "$EXEC_STDERR" ]] && printf '%s\n' "$EXEC_STDERR" >&2
    fi
  fi
}

gb_flow_pr() {
  local root="$1" branch="$2"
  if ! github_is_available "$root"; then
    log_warn "GitHub CLI is not available or not authenticated."
    return
  fi
  local pr_record
  pr_record="$(github_get_pr_for_branch "$root" "$branch" || true)"
  if [[ -n "$pr_record" ]]; then
    local pr_num pr_title
    pr_num="$(cut -f1 <<<"$pr_record")"
    pr_title="$(cut -f2 <<<"$pr_record")"
    log_info "Associated PR #$pr_num: $pr_title"
    if confirm "Open PR #$pr_num in browser?"; then
      pr_open_web "$root" "$pr_num"
    fi
  else
    log_info "No open PR found for branch '$branch'."
    pr_create_interactive "$root"
  fi
}

gb_flow_multi_delete() {
  local root="$1" base_branch="$2"
  printf '\n%sSelect branches to delete with TAB, then press ENTER:%s\n' "$C_YELLOW" "$C_RESET"
  local branches=()
  while IFS= read -r b; do
    [[ -n "$b" ]] && branches+=("$b")
  done < <(git -C "$root" for-each-ref --format="%(refname:short)" refs/heads/ 2>/dev/null)

  local sel
  sel="$(printf '%s\n' "${branches[@]}" | fzf --multi --reverse --prompt="Select branches to delete> ")" || return 0
  local -a to_delete=()
  while IFS= read -r item; do
    [[ -n "$item" ]] && to_delete+=("$item")
  done <<<"$sel"

  [[ ${#to_delete[@]} -eq 0 ]] && return 0

  printf '\n%sBranches selected for deletion (%d):%s\n' "$C_BOLD" "${#to_delete[@]}" "$C_RESET"
  for b in "${to_delete[@]}"; do
    if is_protected_branch "$root" "$b"; then
      printf '  %s✘ %s [PROTECTED - WILL SKIP]%s\n' "$C_RED" "$b" "$C_RESET"
    else
      printf '  %s● %s%s\n' "$C_YELLOW" "$b" "$C_RESET"
    fi
  done

  if ! confirm "Proceed with bulk deletion of eligible branches?"; then
    log_warn "Bulk deletion cancelled."
    return 0
  fi

  for b in "${to_delete[@]}"; do
    if is_protected_branch "$root" "$b"; then
      log_warn "Skipped protected branch: $b"
      continue
    fi
    branch_delete "$root" "$b" "false" 2>/dev/null || branch_delete "$root" "$b" "true" 2>/dev/null || log_err "Failed: $b"
    log_ok "Deleted: $b"
  done
}
