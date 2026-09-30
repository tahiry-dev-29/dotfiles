#!/usr/bin/env bash
# Git Tools - Configuration Management
set -euo pipefail

# Configuration defaults
CFG_PROTECTED_BRANCHES="main,master,develop,trunk,release/*,stable,production"
CFG_DEFAULT_BASE_BRANCH=""
CFG_WORKTREE_PATTERN="../{repo}-{branch}"
CFG_ISSUE_BRANCH_PATTERN="feature/{issue}-{slug}"
CFG_CACHE_TTL_SEC=60

load_config() {
  local root="$1"
  local global_cfg="$HOME/.config/git-tools/config"

  if [[ -f "$global_cfg" ]]; then
    while IFS='=' read -r key val || [[ -n "$key" ]]; do
      key="$(trim "$key")"
      val="$(trim "$val")"
      [[ "$key" =~ ^#.*$ || -z "$key" ]] && continue
      case "$key" in
        protected_branches)   CFG_PROTECTED_BRANCHES="$val" ;;
        default_base_branch)  CFG_DEFAULT_BASE_BRANCH="$val" ;;
        worktree_pattern)     CFG_WORKTREE_PATTERN="$val" ;;
        issue_branch_pattern) CFG_ISSUE_BRANCH_PATTERN="$val" ;;
        cache_ttl_sec)        CFG_CACHE_TTL_SEC="$val" ;;
      esac
    done < "$global_cfg"
  fi

  # Git config overrides
  local git_protected git_base git_pattern
  git_protected="$(git -C "$root" config --get gwt.protectedBranches 2>/dev/null || true)"
  [[ -n "$git_protected" ]] && CFG_PROTECTED_BRANCHES="$git_protected"

  git_base="$(git -C "$root" config --get gwt.defaultBaseBranch 2>/dev/null || true)"
  [[ -n "$git_base" ]] && CFG_DEFAULT_BASE_BRANCH="$git_base"

  git_pattern="$(git -C "$root" config --get gwt.worktreePattern 2>/dev/null || true)"
  [[ -n "$git_pattern" ]] && CFG_WORKTREE_PATTERN="$git_pattern"

  return 0
}

# Generate formatted worktree destination path
# Resolves {repo} and {branch} placeholders
format_worktree_path() {
  local root="$1"
  local branch_or_ref="$2"
  local repo_name slug

  repo_name="$(basename "$root")"
  slug="${branch_or_ref//\//-}"
  slug="${slug//_/-}"

  local target="$CFG_WORKTREE_PATTERN"
  target="${target/\{repo\}/$repo_name}"
  target="${target/\{branch\}/$slug}"

  if [[ "$target" == /* ]]; then
    printf '%s\n' "$target"
  else
    printf '%s\n' "$(dirname "$root")/${target#../}"
  fi
}

# Slugify an issue title or text
slugify() {
  local input="$1"
  local clean
  clean="$(echo "$input" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-')"
  clean="${clean#-}"
  clean="${clean%-}"
  printf '%.40s\n' "$clean"
}
