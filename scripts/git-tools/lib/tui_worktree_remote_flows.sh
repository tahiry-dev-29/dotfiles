#!/usr/bin/env bash
# Git Tools - Worktree Remote & Ref Flows (PR, Issue, Commit, Tag)
set -euo pipefail

gwt_flow_pr() {
  local root="$1"
  if ! github_is_available "$root"; then
    log_warn "GitHub CLI (gh) is not available or not authenticated."
    return
  fi

  local prs=()
  while IFS= read -r pr_line; do
    [[ -n "$pr_line" ]] && prs+=("$pr_line")
  done < <(github_list_prs "$root")

  if [[ ${#prs[@]} -eq 0 ]]; then
    log_warn "No open Pull Requests found."
    return
  fi

  local pr_display=()
  for p in "${prs[@]}"; do
    local num title author head base ci
    IFS=$'\t' read -r num title author head base ci <<<"$p"
    local formatted; formatted="$(printf '#%-5s %-30s %-12s %s -> %s [%s]' "$num" "$title" "@$author" "$head" "$base" "$ci")"
    pr_display+=("$(printf '%s\t%s' "$num" "$formatted")")
  done

  local sel; sel="$(printf '%s\n' "${pr_display[@]}" | fzf --reverse --delimiter=$'\t' --with-nth=2 --prompt="Select PR> ")" || return
  local pr_num; pr_num="$(cut -f1 <<<"$sel")"
  [[ -z "$pr_num" ]] && return

  local default_path; default_path="$(format_worktree_path "$root" "pr-$pr_num")"
  local dest_path; dest_path="$(prompt_input "Destination directory" "$default_path")"

  printf '\n%sCreate mode:%s [1] Detached commit (testing)  [2] Local branch\n' "$C_CYAN" "$C_RESET"
  local mode_choice; mode_choice="$(prompt_input "Choice [1/2]" "1")"
  local mode="detached"
  [[ "$mode_choice" == "2" ]] && mode="branch"

  ui_preview_action "Create Worktree from PR #$pr_num ($mode)" "pr_create_worktree $root $pr_num $dest_path $mode"
  if confirm "Proceed?"; then
    pr_create_worktree "$root" "$pr_num" "$dest_path" "$mode"
  fi
}

gwt_flow_issue() {
  local root="$1"
  if ! github_is_available "$root"; then
    log_warn "GitHub CLI (gh) is not available or not authenticated."
    return
  fi

  local issues=()
  while IFS= read -r issue_line; do
    [[ -n "$issue_line" ]] && issues+=("$issue_line")
  done < <(github_list_issues "$root")

  if [[ ${#issues[@]} -eq 0 ]]; then
    log_warn "No open Issues found."
    return
  fi

  local issue_display=()
  for i in "${issues[@]}"; do
    local num title author state
    IFS=$'\t' read -r num title author state <<<"$i"
    local formatted; formatted="$(printf '#%-5s %-40s %-12s [%s]' "$num" "$title" "@$author" "$state")"
    issue_display+=("$(printf '%s\t%s\t%s' "$num" "$title" "$formatted")")
  done

  local sel; sel="$(printf '%s\n' "${issue_display[@]}" | fzf --reverse --delimiter=$'\t' --with-nth=3 --prompt="Select Issue> ")" || return
  local num title
  num="$(cut -f1 <<<"$sel")"
  title="$(cut -f2 <<<"$sel")"
  [[ -z "$num" ]] && return

  issue_create_worktree "$root" "$num" "$title"
}

gwt_flow_commit() {
  local root="$1"
  local commits=()
  while IFS= read -r c; do
    [[ -n "$c" ]] && commits+=("$c")
  done < <(commit_list "$root" 50)

  local commit_display=()
  for c in "${commits[@]}"; do
    local sha author date subj
    IFS=$'\t' read -r sha author date subj <<<"$c"
    local formatted; formatted="$(printf '%-8s %-12s %-14s %s' "$sha" "$author" "$date" "$subj")"
    commit_display+=("$(printf '%s\t%s' "$sha" "$formatted")")
  done

  local sel; sel="$(printf '%s\n' "${commit_display[@]}" | fzf --reverse --delimiter=$'\t' --with-nth=2 --prompt="Select Commit> ")" || return
  local sha; sha="$(cut -f1 <<<"$sel")"
  [[ -z "$sha" ]] && return

  printf '\n%sCreate mode:%s [1] Detached worktree  [2] New branch worktree\n' "$C_CYAN" "$C_RESET"
  local choice; choice="$(prompt_input "Choice [1/2]" "1")"
  if [[ "$choice" == "2" ]]; then
    local branch; branch="$(prompt_input "New branch name")"
    [[ -z "$branch" ]] && return
    local dest_path; dest_path="$(prompt_input "Destination directory" "$(format_worktree_path "$root" "$branch")")"
    ui_preview_action "Create Worktree from commit" "git worktree add -b $branch $dest_path $sha"
    if confirm "Create worktree?"; then
      worktree_create_branch "$root" "$dest_path" "$branch" "true" "$sha"
    fi
  else
    local dest_path; dest_path="$(prompt_input "Destination directory" "$(format_worktree_path "$root" "detached-$sha")")"
    ui_preview_action "Create Detached Worktree" "git worktree add --detach $dest_path $sha"
    if confirm "Create detached worktree?"; then
      worktree_create_detached "$root" "$dest_path" "$sha"
    fi
  fi
}

gwt_flow_tag() {
  local root="$1"
  local tags=()
  while IFS= read -r t; do
    [[ -n "$t" ]] && tags+=("$t")
  done < <(tag_list "$root")

  if [[ ${#tags[@]} -eq 0 ]]; then
    log_warn "No tags found."
    return
  fi

  local tag_display=()
  for t in "${tags[@]}"; do
    local tag date subj
    IFS=$'\t' read -r tag date subj <<<"$t"
    local formatted; formatted="$(printf '%-20s %-12s %s' "$tag" "$date" "$subj")"
    tag_display+=("$(printf '%s\t%s' "$tag" "$formatted")")
  done

  local sel; sel="$(printf '%s\n' "${tag_display[@]}" | fzf --reverse --delimiter=$'\t' --with-nth=2 --prompt="Select Tag> ")" || return
  local tag; tag="$(cut -f1 <<<"$sel")"
  [[ -z "$tag" ]] && return

  local dest_path; dest_path="$(prompt_input "Destination directory" "$(format_worktree_path "$root" "$tag")")"
  ui_preview_action "Create Detached Worktree from Tag" "git worktree add --detach $dest_path $tag"
  if confirm "Create detached worktree?"; then
    worktree_create_detached "$root" "$dest_path" "$tag"
  fi
}
