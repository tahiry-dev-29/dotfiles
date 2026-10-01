#!/usr/bin/env bash
# Git Tools - Worktree Local Action Flows (New, Detached, Bulk, Remove)
set -euo pipefail

gwt_flow_new() {
  local root="$1"
  printf '\n%s=== Create Branch Worktree ===%s\n' "$C_BOLD" "$C_RESET"
  local branch; branch="$(prompt_input "Branch name (e.g. feature/my-feature)")"
  [[ -z "$branch" ]] && { log_warn "Cancelled: empty branch name."; return; }

  local default_path; default_path="$(format_worktree_path "$root" "$branch")"
  local dest_path; dest_path="$(prompt_input "Destination directory" "$default_path")"

  local is_new="false"
  if ! git -C "$root" show-ref --verify --quiet "refs/heads/$branch" 2>/dev/null; then
    is_new="true"
  fi

  local base_branch=""
  if [[ "$is_new" == "true" ]]; then
    base_branch="$(prompt_input "Base branch" "$(get_default_base_branch "$root")")"
    ui_preview_action "Create Worktree with new branch" "git worktree add -b $branch $dest_path $base_branch"
  else
    ui_preview_action "Create Worktree from existing branch" "git worktree add $dest_path $branch"
  fi

  if confirm "Proceed with creation?"; then
    if worktree_create_branch "$root" "$dest_path" "$branch" "$is_new" "$base_branch"; then
      log_ok "Worktree created at: $dest_path"
      bootstrap_worktree "$root" "$dest_path" "$branch"
    else
      log_err "Failed to create worktree."
      [[ -n "$EXEC_STDERR" ]] && printf '%s\n' "$EXEC_STDERR" >&2
    fi
  else
    log_warn "Cancelled."
  fi
}

gwt_flow_detached() {
  local root="$1"
  printf '\n%s=== Create Detached Worktree ===%s\n' "$C_BOLD" "$C_RESET"
  local commit_ish; commit_ish="$(prompt_input "Commit SHA / Tag / Ref")"
  [[ -z "$commit_ish" ]] && { log_warn "Cancelled: empty ref."; return; }

  local rev
  if ! rev="$(git -C "$root" rev-parse --short "$commit_ish" 2>/dev/null)"; then
    log_err "Invalid commit or ref: $commit_ish"
    return
  fi

  local default_path; default_path="$(format_worktree_path "$root" "detached-$rev")"
  local dest_path; dest_path="$(prompt_input "Destination directory" "$default_path")"

  ui_preview_action "Create Detached Worktree" "git worktree add --detach $dest_path $commit_ish"
  if confirm "Proceed with creation?"; then
    if worktree_create_detached "$root" "$dest_path" "$commit_ish"; then
      log_ok "Detached worktree created at: $dest_path (HEAD at $rev)"
      bootstrap_worktree "$root" "$dest_path" "$commit_ish"
    else
      log_err "Failed to create detached worktree."
      [[ -n "$EXEC_STDERR" ]] && printf '%s\n' "$EXEC_STDERR" >&2
    fi
  fi
}

# Mode C: Multiple worktrees, one branch each
gwt_flow_bulk_create() {
  local root="$1"
  printf '\n%sSelect branches to create worktrees for (TAB to select, Enter to confirm):%s\n' "$C_YELLOW" "$C_RESET"
  local branches=()
  while IFS= read -r b; do
    [[ -n "$b" ]] && branches+=("$b")
  done < <(git -C "$root" for-each-ref --format="%(refname:short)" refs/heads/ 2>/dev/null)

  local sel
  sel="$(printf '%s\n' "${branches[@]}" | fzf --multi --reverse --prompt="Select branches for worktrees> ")" || return 0
  local -a chosen=()
  while IFS= read -r item; do
    [[ -n "$item" ]] && chosen+=("$item")
  done <<<"$sel"

  [[ ${#chosen[@]} -eq 0 ]] && return 0

  printf '\n%sBulk Worktree Creation Preview (%d):%s\n' "$C_BOLD" "${#chosen[@]}" "$C_RESET"
  for b in "${chosen[@]}"; do
    local p; p="$(format_worktree_path "$root" "$b")"
    printf '  ● %-25s -> %s\n' "$b" "$p"
  done

  if ! confirm "Create all worktrees and run bootstrap?"; then
    log_warn "Cancelled."
    return 0
  fi

  for b in "${chosen[@]}"; do
    local p; p="$(format_worktree_path "$root" "$b")"
    if worktree_create_branch "$root" "$p" "$b" "false" ""; then
      log_ok "Created $p for $b"
      bootstrap_worktree "$root" "$p" "$b"
    else
      log_err "Failed for $b"
    fi
  done
}

gwt_flow_remove() {
  local root="$1" target_path="$2"
  if [[ -d "$target_path/.git" ]]; then
    log_err "Cannot remove the main repository checkout: $target_path"
    return
  fi

  local dirty_status=0
  worktree_dirty_check "$target_path" || dirty_status=$?

  local force="false"
  if [[ $dirty_status -eq 1 ]]; then
    log_warn "Worktree contains uncommitted/untracked changes!"
    ui_preview_action "Force Remove Dirty Worktree" "git worktree remove --force $target_path"
    if ! confirm "Worktree is dirty. Force remove anyway?"; then
      log_warn "Removal cancelled."
      return
    fi
    force="true"
  else
    ui_preview_action "Remove Worktree" "git worktree remove $target_path"
    if ! confirm "Remove worktree at $target_path?"; then
      log_warn "Removal cancelled."
      return
    fi
  fi

  if worktree_remove "$root" "$target_path" "$force"; then
    log_ok "Worktree removed: $target_path"
  else
    log_err "Failed to remove worktree."
    [[ -n "$EXEC_STDERR" ]] && printf '%s\n' "$EXEC_STDERR" >&2
  fi
}

gwt_flow_multi_remove() {
  local root="$1"
  printf '\n%sSelect worktrees to remove with TAB, then press ENTER:%s\n' "$C_YELLOW" "$C_RESET"
  local wts=()
  while IFS= read -r w; do
    local p; p="$(cut -f1 <<<"$w")"
    [[ -n "$p" && ! -d "$p/.git" ]] && wts+=("$p")
  done < <(worktree_list "$root")

  if [[ ${#wts[@]} -eq 0 ]]; then
    log_warn "No removable linked worktrees found."
    return
  fi

  local sel; sel="$(printf '%s\n' "${wts[@]}" | fzf --multi --reverse --prompt="Select worktrees to remove> ")" || return 0
  local -a to_remove=()
  while IFS= read -r item; do
    [[ -n "$item" ]] && to_remove+=("$item")
  done <<<"$sel"

  [[ ${#to_remove[@]} -eq 0 ]] && return 0

  printf '\n%sWorktrees selected for removal (%d):%s\n' "$C_BOLD" "${#to_remove[@]}" "$C_RESET"
  for p in "${to_remove[@]}"; do
    printf '  %s● %s%s\n' "$C_YELLOW" "$p" "$C_RESET"
  done

  if confirm "Proceed with bulk removal?"; then
    for p in "${to_remove[@]}"; do
      gwt_flow_remove "$root" "$p"
    done
  fi
}
