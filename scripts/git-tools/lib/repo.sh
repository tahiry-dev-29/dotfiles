#!/usr/bin/env bash
# Git Tools - Repository Context & Detection
set -euo pipefail

# Require that cwd is inside a git repository and output top-level root
require_git_repo() {
  local dir="${1:-$PWD}"
  local toplevel
  if ! toplevel="$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null)"; then
    echo "Not a Git repository." >&2
    return 1
  fi
  printf '%s\n' "$toplevel"
}

# Resolve the main repo root (handles both main repo and linked worktrees)
get_main_repo_root() {
  local dir="${1:-$PWD}"
  local common
  common="$(git -C "$dir" rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)"
  if [[ -z "$common" ]]; then
    common="$(git -C "$dir" rev-parse --git-common-dir 2>/dev/null || true)"
    if [[ -n "$common" && "$common" != /* ]]; then
      common="$dir/${common#./}"
    fi
  fi

  if [[ -n "$common" && "$(basename "$common")" == ".git" ]]; then
    dirname "$common"
    return 0
  fi

  # Fallback to porcelain list
  git -C "$dir" worktree list --porcelain 2>/dev/null | sed -n 's/^worktree //p' | head -n1
}

# Get repository name (folder name of main repo root)
get_repo_name() {
  local root="$1"
  basename "$root"
}

# Determine default base branch
get_default_base_branch() {
  local root="$1"
  local base=""
  for b in main master develop trunk; do
    if git -C "$root" show-ref --verify --quiet "refs/heads/$b" 2>/dev/null; then
      base="$b"
      break
    fi
  done
  if [[ -z "$base" ]]; then
    base="$(git -C "$root" config --get init.defaultBranch 2>/dev/null || echo "main")"
  fi
  printf '%s\n' "$base"
}

# Check if a branch is protected
is_protected_branch() {
  local root="$1"
  local branch="$2"
  local custom_protected
  custom_protected="$(git -C "$root" config --get gwt.protectedBranches 2>/dev/null || true)"

  if [[ -n "$custom_protected" ]]; then
    local pattern
    for pattern in $custom_protected; do
      if [[ "$branch" == $pattern ]]; then
        return 0
      fi
    done
  fi

  case "$branch" in
    main|master|develop|trunk|release/*|stable|production)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

# Detect remote provider
detect_provider() {
  local root="$1"
  local remote_url
  remote_url="$(git -C "$root" remote get-url origin 2>/dev/null || true)"
  if [[ -z "$remote_url" ]]; then
    echo "local"
    return 0
  fi
  case "$remote_url" in
    *github.com*) echo "github" ;;
    *gitlab.com*) echo "gitlab" ;;
    *bitbucket.org*) echo "bitbucket" ;;
    *) echo "other" ;;
  esac
}
