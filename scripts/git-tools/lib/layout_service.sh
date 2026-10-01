#!/usr/bin/env bash
# Git Tools - Responsive Terminal Layout & Formatting Service
set -euo pipefail

# Get terminal dimensions and layout mode
# Modes: wide (>= 120 cols), medium (80-119 cols), narrow (< 80 cols)
terminal_get_mode() {
  local cols
  cols="$(tput cols 2>/dev/null || echo 100)"

  if (( cols >= 120 )); then
    echo "wide"
  elif (( cols >= 80 )); then
    echo "medium"
  else
    echo "narrow"
  fi
}

terminal_get_cols() {
  tput cols 2>/dev/null || echo 100
}

# Smart path truncation preserving prefix and meaningful suffix
# e.g. /home/user/projects/repo/worktree-feature-auth -> .../projects/repo/worktree-feature-auth
truncate_path() {
  local path="$1"
  local max_len="${2:-40}"

  # Replace $HOME with ~
  if [[ "$path" == "$HOME"* ]]; then
    path="~${path#"$HOME"}"
  fi

  if (( ${#path} <= max_len )); then
    printf '%s\n' "$path"
    return 0
  fi

  local base parent
  base="$(basename "$path")"
  parent="$(dirname "$path")"

  if (( ${#base} + 6 >= max_len )); then
    printf '.../%.*s\n' "$(( max_len - 4 ))" "$base"
    return 0
  fi

  local avail=$(( max_len - ${#base} - 5 ))
  printf '%s/.../%s\n' "${parent:0:$avail}" "$base"
}

# Smart text truncation
truncate_text() {
  local text="$1"
  local max_len="${2:-35}"

  if (( ${#text} <= max_len )); then
    printf '%s\n' "$text"
  else
    printf '%.*s...\n' "$(( max_len - 3 ))" "$text"
  fi
}
