#!/usr/bin/env bash
# Git Tools - Modern TUI Header & Contextual Footer Service
set -euo pipefail

# Render clean modern multi-line header
render_header() {
  local tool_title="$1"
  local repo_name="$2"
  local current_branch="$3"
  local meta_info="$4"

  printf '%s%s · %s%s\n' "$C_BOLD" "$tool_title" "$repo_name" "$C_RESET"
  printf '%sbranch: %s%s · %s%s%s\n' "$C_CYAN" "$current_branch" "$C_RESET" "$C_DIM" "$meta_info" "$C_RESET"
}

# Render contextual footer based on layout mode
render_footer() {
  local context="$1"     # gwt or gb
  local mode="${2:-wide}" # wide, medium, narrow

  if [[ "$mode" == "narrow" ]]; then
    printf '↑↓ Move │ TAB Select │ Enter Details │ ? Help │ q Quit'
    return 0
  fi

  if [[ "$context" == "gwt" ]]; then
    if [[ "$mode" == "wide" ]]; then
      printf '↑↓ Move │ TAB Select │ Enter Open │ n New │ p PR │ i Issue │ c Commit │ t Tag │ m Multi │ r Remove │ ? Help │ q Quit'
    else
      printf '↑↓ Move │ TAB Select │ Enter Open │ n New │ p PR │ i Issue │ m Multi │ r Remove │ ? Help │ q Quit'
    fi
  else
    if [[ "$mode" == "wide" ]]; then
      printf '↑↓ Move │ TAB Select │ Enter Details │ s Switch │ w Worktree │ d Delete │ p PR │ f Filter │ m Multi │ ? Help │ q Quit'
    else
      printf '↑↓ Move │ TAB Select │ Enter Details │ s Switch │ w Worktree │ d Delete │ f Filter │ m Multi │ ? Help │ q Quit'
    fi
  fi
}
