#!/usr/bin/env bash
# Git Tools - Worktree Service
set -euo pipefail

# Output format per row: path TAB branch TAB head_sha TAB is_main(1|0) TAB is_detached(1|0) TAB dirty_str TAB ahead_behind TAB upstream
worktree_list() {
  local root="$1"
  local line path="" branch="" head_sha="" is_detached=0 is_bare=0

  while IFS= read -r line || [[ -n "$line" ]]; do
    case "$line" in
      worktree\ *)
        path="${line#worktree }"
        ;;
      HEAD\ *)
        head_sha="${line#HEAD }"
        ;;
      branch\ *)
        branch="${line#branch }"
        branch="${branch#refs/heads/}"
        is_detached=0
        ;;
      detached)
        branch="(detached)"
        is_detached=1
        ;;
      bare)
        branch="(bare)"
        is_bare=1
        ;;
      "")
        if [[ -n "$path" && $is_bare -eq 0 ]]; then
          _emit_worktree_record "$path" "$branch" "$head_sha" "$is_detached"
          path="" branch="" head_sha="" is_detached=0
        fi
        ;;
    esac
  done < <(git -C "$root" worktree list --porcelain 2>/dev/null)

  if [[ -n "$path" && $is_bare -eq 0 ]]; then
    _emit_worktree_record "$path" "$branch" "$head_sha" "$is_detached"
  fi
}

_emit_worktree_record() {
  local path="$1" branch="$2" head_sha="$3" is_detached="$4"
  local is_main=0 dirty_str="clean" mod_count=0 untracked_count=0
  local ahead_behind="-" upstream="-"

  [[ -d "$path/.git" ]] && is_main=1

  if [[ -d "$path" ]]; then
    mod_count="$(git -C "$path" status --porcelain 2>/dev/null | grep -c -v '^??' || true)"
    untracked_count="$(git -C "$path" status --porcelain 2>/dev/null | grep -c '^??' || true)"
    if [[ $mod_count -gt 0 || $untracked_count -gt 0 ]]; then
      dirty_str="dirty (mod:${mod_count}, untracked:${untracked_count})"
    fi

    if [[ "$is_detached" -eq 0 && "$branch" != "(detached)" && "$branch" != "(bare)" ]]; then
      upstream="$(git -C "$path" rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null || echo "-")"
      if [[ "$upstream" != "-" ]]; then
        local counts
        counts="$(git -C "$path" rev-list --left-right --count '@{upstream}...HEAD' 2>/dev/null || true)"
        if [[ -n "$counts" ]]; then
          local behind ahead
          behind="$(awk '{print $1}' <<<"$counts")"
          ahead="$(awk '{print $2}' <<<"$counts")"
          ahead_behind="↑${ahead} ↓${behind}"
        fi
      fi
    fi
  else
    dirty_str="missing"
  fi

  printf '%s\t%s\t%s\t%d\t%d\t%s\t%s\t%s\n' \
    "$path" "$branch" "${head_sha:0:7}" "$is_main" "$is_detached" "$dirty_str" "$ahead_behind" "$upstream"
}

worktree_dirty_check() {
  local path="$1"
  [[ ! -d "$path" ]] && return 2
  local dirty
  dirty="$(git -C "$path" status --porcelain 2>/dev/null || true)"
  [[ -n "$dirty" ]] && return 1
  return 0
}

# Check if branch is already checked out in any worktree
worktree_find_branch_checkout() {
  local root="$1"
  local target_branch="$2"
  local line path="" branch=""

  while IFS= read -r line || [[ -n "$line" ]]; do
    case "$line" in
      worktree\ *) path="${line#worktree }" ;;
      branch\ *)
        branch="${line#branch refs/heads/}"
        if [[ "$branch" == "$target_branch" ]]; then
          printf '%s\n' "$path"
          return 0
        fi
        ;;
      "") path="" branch="" ;;
    esac
  done < <(git -C "$root" worktree list --porcelain 2>/dev/null)
  return 1
}

# Create worktree for an existing or new branch with duplicate checkout guard
worktree_create_branch() {
  local root="$1"
  local dest_path="$2"
  local branch="$3"
  local create_new="${4:-false}"
  local base_branch="${5:-}"

  local existing_wt
  if existing_wt="$(worktree_find_branch_checkout "$root" "$branch")"; then
    log_err "Branch '$branch' is already checked out at: $existing_wt"
    EXEC_STDERR="fatal: '$branch' is already checked out at '$existing_wt'"
    EXEC_EXIT_CODE=1
    return 1
  fi

  if [[ "$create_new" == "true" ]]; then
    if [[ -n "$base_branch" ]]; then
      exec_git "$root" worktree add -b "$branch" "$dest_path" "$base_branch"
    else
      exec_git "$root" worktree add -b "$branch" "$dest_path"
    fi
  else
    exec_git "$root" worktree add "$dest_path" "$branch"
  fi
}

worktree_create_detached() {
  local root="$1"
  local dest_path="$2"
  local commit_ish="$3"
  exec_git "$root" worktree add --detach "$dest_path" "$commit_ish"
}

worktree_remove() {
  local root="$1"
  local target_path="$2"
  local force="${3:-false}"

  if [[ "$force" == "true" ]]; then
    exec_git "$root" worktree remove --force "$target_path"
  else
    exec_git "$root" worktree remove "$target_path"
  fi
}
