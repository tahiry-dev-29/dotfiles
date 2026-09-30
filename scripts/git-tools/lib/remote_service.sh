#!/usr/bin/env bash
# Git Tools - Remote Branch Service
set -euo pipefail

# List remote branches (excluding origin/HEAD)
# Output format: remote_ref TAB date TAB subject
remote_branch_list() {
  local root="$1"

  while IFS=$'\t' read -r ref date subj; do
    [[ -z "$ref" ]] && continue
    # Skip HEAD pointer e.g. origin/HEAD
    [[ "$ref" =~ /HEAD$ ]] && continue
    printf '%s\t%s\t%s\n' "$ref" "$date" "$subj"
  done < <(git -C "$root" branch -r --format="%(refname:short)%09%(committerdate:relative)%09%(subject)" 2>/dev/null)
}

# Fetch all remotes and prune deleted tracking refs
remote_fetch_prune() {
  local root="$1"
  exec_git "$root" fetch --all --prune
}

# Switch to a remote tracking branch locally
remote_track_and_switch() {
  local root="$1"
  local remote_ref="$2"
  local local_branch="${remote_ref#*/}"

  if git -C "$root" show-ref --verify --quiet "refs/heads/$local_branch" 2>/dev/null; then
    exec_git "$root" switch "$local_branch"
  else
    exec_git "$root" switch --track "$remote_ref"
  fi
}
