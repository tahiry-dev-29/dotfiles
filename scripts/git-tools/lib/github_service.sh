#!/usr/bin/env bash
# Git Tools - GitHub CLI Service & Caching Layer
set -euo pipefail

github_is_available() {
  local root="$1"
  local provider
  provider="$(detect_provider "$root")"
  [[ "$provider" != "github" ]] && return 1

  command -v gh >/dev/null 2>&1 || return 1
  gh auth status >/dev/null 2>&1 || return 1
  return 0
}

# Fetch or read from short-lived cache
_gh_cache_exec() {
  local cache_key="$1"
  local ttl_sec="${CFG_CACHE_TTL_SEC:-60}"
  local cache_file="/tmp/gwt_gh_cache_${cache_key//[^a-zA-Z0-9_]/_}"
  shift

  if [[ -f "$cache_file" ]]; then
    local age
    age=$(( $(date +%s) - $(stat -c %Y "$cache_file" 2>/dev/null || echo 0) ))
    if (( age < ttl_sec )); then
      cat "$cache_file"
      return 0
    fi
  fi

  local output
  if output="$("$@")"; then
    printf '%s\n' "$output" > "$cache_file"
    printf '%s\n' "$output"
    return 0
  else
    return 1
  fi
}

# Invalidate cache for a key
github_cache_invalidate() {
  local key_pattern="${1:-*}"
  rm -f /tmp/gwt_gh_cache_*${key_pattern}* 2>/dev/null || true
}

# List Pull Requests
# Format: number TAB title TAB author TAB headRef TAB baseRef TAB checks
github_list_prs() {
  local root="$1"
  local repo_id
  repo_id="$(basename "$root")"

  _gh_cache_exec "prs_${repo_id}" gh -R "$(git -C "$root" remote get-url origin)" pr list \
    --limit 30 \
    --json number,title,author,headRefName,baseRefName,statusCheckRollup \
    --jq '.[] | [
      .number,
      .title,
      (.author.login // "unknown"),
      .headRefName,
      .baseRefName,
      (if .statusCheckRollup == null or (.statusCheckRollup | length == 0) then "no-ci"
       elif [ .statusCheckRollup[]? | select(.conclusion != "SUCCESS" and .conclusion != "NEUTRAL") ] | length > 0 then "FAIL"
       else "PASS" end)
    ] | @tsv' 2>/dev/null || true
}

# Find open PR associated with a branch name
github_get_pr_for_branch() {
  local root="$1"
  local branch="$2"
  [[ -z "$branch" ]] && return 1

  github_list_prs "$root" | awk -F'\t' -v br="$branch" '$4 == br { print $1 "\t" $2 "\t" $3 "\t" $6; exit }'
}

# List Issues
# Format: number TAB title TAB author TAB state
github_list_issues() {
  local root="$1"
  local repo_id
  repo_id="$(basename "$root")"

  _gh_cache_exec "issues_${repo_id}" gh -R "$(git -C "$root" remote get-url origin)" issue list \
    --limit 30 \
    --json number,title,author,state \
    --jq '.[] | [
      .number,
      .title,
      (.author.login // "unknown"),
      .state
    ] | @tsv' 2>/dev/null || true
}

# View single PR formatted details
github_view_pr() {
  local root="$1"
  local pr_num="$2"
  gh -R "$(git -C "$root" remote get-url origin)" pr view "$pr_num" 2>/dev/null || true
}

# View single Issue formatted details
github_view_issue() {
  local root="$1"
  local issue_num="$2"
  gh -R "$(git -C "$root" remote get-url origin)" issue view "$issue_num" 2>/dev/null || true
}
