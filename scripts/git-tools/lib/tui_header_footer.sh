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

  if [[ "$context" == "gwt" ]]; then
    if [[ "$mode" == "narrow" ]]; then
      printf '%sEnter%s Open  %sn%s New  %sd%s Remove  %s?%s Help  %sq%s Quit\n' "$C_CYAN" "$C_RESET" "$C_CYAN" "$C_RESET" "$C_CYAN" "$C_RESET" "$C_CYAN" "$C_RESET" "$C_CYAN" "$C_RESET"
      printf '%sp%s PR  %si%s Issue  %sc%s Commit  %st%s Tag  %sm%s Multi' "$C_CYAN" "$C_RESET" "$C_CYAN" "$C_RESET" "$C_CYAN" "$C_RESET" "$C_CYAN" "$C_RESET" "$C_CYAN" "$C_RESET"
    else
      printf '%sEnter%s Open   %sn%s New    %sp%s PR       %si%s Issue    %sc%s Commit  %st%s Tag\n' "$C_CYAN" "$C_RESET" "$C_CYAN" "$C_RESET" "$C_CYAN" "$C_RESET" "$C_CYAN" "$C_RESET" "$C_CYAN" "$C_RESET" "$C_CYAN" "$C_RESET"
      printf '%sd%s Remove   %sm%s Multi  %sR%s Refresh  %s?%s Help     %sq%s Quit' "$C_CYAN" "$C_RESET" "$C_CYAN" "$C_RESET" "$C_CYAN" "$C_RESET" "$C_CYAN" "$C_RESET" "$C_CYAN" "$C_RESET"
    fi
  else
    if [[ "$mode" == "narrow" ]]; then
      printf '%sEnter%s Details  %ss%s Switch  %sd%s Delete  %s?%s Help  %sq%s Quit\n' "$C_CYAN" "$C_RESET" "$C_CYAN" "$C_RESET" "$C_CYAN" "$C_RESET" "$C_CYAN" "$C_RESET" "$C_CYAN" "$C_RESET"
      printf '%sw%s Worktree  %sp%s PR  %sf%s Filter  %sm%s Multi' "$C_CYAN" "$C_RESET" "$C_CYAN" "$C_RESET" "$C_CYAN" "$C_RESET" "$C_CYAN" "$C_RESET"
    else
      printf '%sEnter%s Details  %ss%s Switch  %sw%s Worktree  %sd%s Delete  %sp%s PR\n' "$C_CYAN" "$C_RESET" "$C_CYAN" "$C_RESET" "$C_CYAN" "$C_RESET" "$C_CYAN" "$C_RESET" "$C_CYAN" "$C_RESET"
      printf '%sf%s Filter     %sm%s Multi   %sR%s Refresh   %s?%s Help    %sq%s Quit' "$C_CYAN" "$C_RESET" "$C_CYAN" "$C_RESET" "$C_CYAN" "$C_RESET" "$C_CYAN" "$C_RESET" "$C_CYAN" "$C_RESET"
    fi
  fi
}
