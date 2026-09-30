#!/usr/bin/env bash
# Git Tools - Commit Service
set -euo pipefail

# List commits for search / selection
# Output format: sha TAB author TAB date TAB subject
commit_list() {
  local root="$1"
  local limit="${2:-100}"
  local branch="${3:-HEAD}"

  git -C "$root" log "$branch" -n "$limit" \
    --format="%h%x09%an%x09%ad%x09%s" --date=relative 2>/dev/null || true
}

# Inspect commit details
commit_inspect() {
  local root="$1"
  local sha="$2"

  git -C "$root" show --stat --decorate "$sha" 2>/dev/null || true
}

# Verify if a ref / commit-ish resolves to a valid commit
commit_verify() {
  local root="$1"
  local ref="$2"

  git -C "$root" rev-parse --verify --quiet "$ref^{commit}" >/dev/null 2>&1
}

# Get commit summary line (short sha + subject)
commit_summary() {
  local root="$1"
  local ref="$2"

  git -C "$root" log -1 --format="%h %s" "$ref" 2>/dev/null || echo "$ref"
}
