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
      bootstrap_worktree "$root" "$dest_path" "$branch"
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

  local active_wt
  if active_wt="$(worktree_find_branch_checkout "$root" "$branch")"; then
    log_err "Cannot delete branch '$branch': checked out in worktree ($active_wt)."
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
  printf '\n%sSelect branches with TAB (ESC/Enter to confirm selection):%s\n' "$C_YELLOW" "$C_RESET"
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

  local -a merged_list=() unmerged_list=() skipped_list=()
  for b in "${to_delete[@]}"; do
    if is_protected_branch "$root" "$b"; then
      skipped_list+=("$b (protected)")
    elif worktree_find_branch_checkout "$root" "$b" >/dev/null 2>&1; then
      skipped_list+=("$b (active in worktree)")
    elif git -C "$root" branch --merged "$base_branch" --format="%(refname:short)" 2>/dev/null | grep -qx "$b"; then
      merged_list+=("$b")
    else
      unmerged_list+=("$b")
    fi
  done

  printf '\n%sBulk Branch Deletion Preview:%s\n' "$C_BOLD" "$C_RESET"
  printf '  Total selected:  %d\n' "${#to_delete[@]}"
  printf '  %s✓ Merged:        %d%s\n' "$C_GREEN" "${#merged_list[@]}" "$C_RESET"
  printf '  %s⚠ Unmerged:      %d%s\n' "$C_YELLOW" "${#unmerged_list[@]}" "$C_RESET"
  printf '  %s✘ Skipped:       %d%s\n' "$C_RED" "${#skipped_list[@]}" "$C_RESET"

  for s in "${skipped_list[@]:-}"; do
    [[ -n "$s" ]] && printf '    %s- %s%s\n' "$C_DIM" "$s" "$C_RESET"
  done

  printf '\nOptions:\n'
  printf '  [1] Delete merged branches only (safe: git branch -d)\n'
  printf '  [2] Force delete ALL eligible branches (including unmerged)\n'
  printf '  [3] Cancel\n'
  local choice; choice="$(prompt_input "Choice [1/2/3]" "3")"

  case "$choice" in
    1)
      for b in "${merged_list[@]}"; do
        branch_delete "$root" "$b" "false" && log_ok "Deleted: $b" || log_err "Failed: $b"
      done
      ;;
    2)
      if confirm "DANGER: Permanently delete ${#unmerged_list[@]} unmerged branches?"; then
        for b in "${merged_list[@]}"; do
          branch_delete "$root" "$b" "false" && log_ok "Deleted: $b" || log_err "Failed: $b"
        done
        for b in "${unmerged_list[@]}"; do
          branch_delete "$root" "$b" "true" && log_ok "Force deleted: $b" || log_err "Failed: $b"
        done
      fi
      ;;
    *) log_warn "Bulk deletion cancelled." ;;
  esac
}
