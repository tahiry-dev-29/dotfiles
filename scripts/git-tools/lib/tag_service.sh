#!/usr/bin/env bash
# Git Tools - Tag Service
set -euo pipefail

# List tags sorted by creator date descending
# Output format: tag TAB date TAB subject/annotation
tag_list() {
  local root="$1"

  git -C "$root" tag -l --sort=-creatordate \
    --format="%(refname:short)%09%(creatordate:short)%09%(subject)" 2>/dev/null || true
}

# Inspect tag details
tag_inspect() {
  local root="$1"
  local tag="$2"

  git -C "$root" show "$tag" --stat 2>/dev/null || true
}

# Verify tag exists
tag_verify() {
  local root="$1"
  local tag="$2"

  git -C "$root" show-ref --verify --quiet "refs/tags/$tag" 2>/dev/null
}
