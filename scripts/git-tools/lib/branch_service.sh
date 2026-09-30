#!/usr/bin/env bash
# Git Tools - Branch Service
set -euo pipefail

# Output format per branch:
# branch TAB is_current(1|0) TAB is_merged(1|0) TAB upstream TAB ahead_behind TAB worktree_path TAB last_commit_msg
branch_list() {
  local root="$1"
  local base_branch="${2:-}"
  local filter="${3:-ALL}"
  [[ -z "$base_branch" ]] && base_branch="$(get_default_base_branch "$root")"

  if [[ "$filter" == "REMOTE" ]]; then
    remote_branch_list "$root"
    return 0
  fi

  local current_branch
  current_branch="$(git -C "$root" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")"

  local -A merged_branches=()
  if git -C "$root" show-ref --verify --quiet "refs/heads/$base_branch" 2>/dev/null; then
    while IFS= read -r b; do
      b="$(trim "$b")"
      [[ -n "$b" ]] && merged_branches["$b"]=1
    done < <(git -C "$root" branch --merged "$base_branch" --format="%(refname:short)" 2>/dev/null)
  fi

  local -A wt_map=()
  local wt_line wt_path="" wt_br=""
  while IFS= read -r wt_line; do
    case "$wt_line" in
      worktree\ *) wt_path="${wt_line#worktree }" ;;
      branch\ *)   wt_br="${wt_line#branch refs/heads/}"; wt_map["$wt_br"]="$wt_path" ;;
      "") wt_path="" ;;
    esac
  done < <(git -C "$root" worktree list --porcelain 2>/dev/null)

  while IFS=$'\t' read -r b upstream date subj; do
    [[ -z "$b" ]] && continue
    local is_curr=0 is_mrg=0 ahead_behind="-" wt_p="-"

    [[ "$b" == "$current_branch" ]] && is_curr=1
    [[ -n "${merged_branches[$b]:-}" ]] && is_mrg=1
    [[ -n "${wt_map[$b]:-}" ]] && wt_p="${wt_map[$b]}"

    if [[ -n "$upstream" ]]; then
      local counts
      counts="$(git -C "$root" rev-list --left-right --count "$upstream...$b" 2>/dev/null || true)"
      if [[ -n "$counts" ]]; then
        local behind ahead
        behind="$(awk '{print $1}' <<<"$counts")"
        ahead="$(awk '{print $2}' <<<"$counts")"
        ahead_behind="↑${ahead} ↓${behind}"
      fi
    elif [[ "$b" != "$base_branch" ]] && git -C "$root" show-ref --verify --quiet "refs/heads/$base_branch" 2>/dev/null; then
      local counts
      counts="$(git -C "$root" rev-list --left-right --count "$base_branch...$b" 2>/dev/null || true)"
      if [[ -n "$counts" ]]; then
        local behind ahead
        behind="$(awk '{print $1}' <<<"$counts")"
        ahead="$(awk '{print $2}' <<<"$counts")"
        ahead_behind="base:↑${ahead} ↓${behind}"
      fi
    fi

    # Filter logic
    case "$filter" in
      MERGED)      [[ $is_mrg -eq 0 ]] && continue ;;
      NOT_MERGED)  [[ $is_mrg -eq 1 ]] && continue ;;
      WITH_CHANGES)
        [[ "$ahead_behind" == "-" || "$ahead_behind" =~ ↑0 ]] && continue
        ;;
    esac

    printf '%s\t%d\t%d\t%s\t%s\t%s\t%s\n' \
      "$b" "$is_curr" "$is_mrg" "${upstream:--}" "$ahead_behind" "$wt_p" "$subj"
  done < <(git -C "$root" for-each-ref --sort=-committerdate --format="%(refname:short)%09%(upstream:short)%09%(authordate:relative)%09%(subject)" refs/heads/ 2>/dev/null)
}

# Switch branch safely using git switch
branch_switch() {
  local root="$1"
  local branch="$2"
  local current_branch
  current_branch="$(git -C "$root" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")"
  if [[ "$branch" == "$current_branch" ]]; then
    log_info "Already on branch '$branch'."
    return 0
  fi

  local dirty_status=0
  worktree_dirty_check "$root" || dirty_status=$?
  if [[ $dirty_status -eq 1 ]]; then
    log_warn "Current worktree has uncommitted changes."
    if ! confirm "Switch to '$branch' anyway?"; then
      log_warn "Switch cancelled."
      return 1
    fi
  fi

  exec_git "$root" switch "$branch"
}

# Delete branch safely with protection checks
branch_delete() {
  local root="$1"
  local branch="$2"
  local force="${3:-false}"

  if is_protected_branch "$root" "$branch"; then
    log_err "Branch '$branch' is protected and cannot be deleted."
    return 2
  fi

  local current_branch
  current_branch="$(git -C "$root" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")"
  if [[ "$branch" == "$current_branch" ]]; then
    log_err "Cannot delete the currently checked out branch '$branch'."
    return 3
  fi

  if [[ "$force" == "true" ]]; then
    exec_git "$root" branch -D "$branch"
  else
    exec_git "$root" branch -d "$branch"
  fi
}
