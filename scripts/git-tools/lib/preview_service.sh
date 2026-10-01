#!/usr/bin/env bash
# Git Tools - Structured Semantic Preview Service
set -euo pipefail

# Render structured preview for a worktree path
# Used by fzf preview runner
preview_render_worktree() {
  local p="$1"
  if [[ ! -d "$p" ]]; then
    printf '%sWORKTREE PATH NOT ACCESSIBLE: %s%s\n' "$C_RED" "$p" "$C_RESET"
    return 0
  fi

  local br sha is_detached="branch"
  br="$(git -C "$p" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")"
  sha="$(git -C "$p" rev-parse --short HEAD 2>/dev/null || echo "unknown")"
  [[ "$br" == "HEAD" ]] && is_detached="detached"

  printf '%s╔══════════════════════════════════════════════════════╗%s\n' "$C_BLUE" "$C_RESET"
  printf '%s║ WORKTREE: %-42s ║%s\n' "$C_BOLD" "$(basename "$p")" "$C_RESET"
  printf '%s╠══════════════════════════════════════════════════════╣%s\n' "$C_BLUE" "$C_RESET"
  printf '║ %sBranch:%s   %-43s ║\n' "$C_CYAN" "$C_RESET" "$br"
  printf '║ %sCommit:%s   %-43s ║\n' "$C_CYAN" "$C_RESET" "$sha"
  printf '║ %sType:%s     %-43s ║\n' "$C_CYAN" "$C_RESET" "$is_detached"
  printf '%s╠══════════════════════════════════════════════════════╣%s\n' "$C_BLUE" "$C_RESET"
  printf '%s║ STATUS:                                              ║%s\n' "$C_CYAN" "$C_RESET"

  local mod unt
  mod="$(git -C "$p" status --porcelain 2>/dev/null | grep -c -v '^??' || true)"
  unt="$(git -C "$p" status --porcelain 2>/dev/null | grep -c '^??' || true)"
  if (( mod == 0 && unt == 0 )); then
    printf '║   %s✓ Clean (no uncommitted or untracked changes)%s      ║\n' "$C_GREEN" "$C_RESET"
  else
    printf '║   %s⚠ %d modified · %d untracked file(s)%s              ║\n' "$C_YELLOW" "$mod" "$unt" "$C_RESET"
  fi

  printf '%s╠══════════════════════════════════════════════════════╣%s\n' "$C_BLUE" "$C_RESET"
  printf '%s║ RECENT COMMITS:                                      ║%s\n' "$C_CYAN" "$C_RESET"
  local commits
  commits="$(git -C "$p" log -n 5 --oneline 2>/dev/null || echo "  No commits")"
  while IFS= read -r line; do
    printf '║   %-48s ║\n' "${line:0:48}"
  done <<<"$commits"

  printf '%s╠══════════════════════════════════════════════════════╣%s\n' "$C_BLUE" "$C_RESET"
  printf '%s║ PATH:                                                ║%s\n' "$C_CYAN" "$C_RESET"
  printf '║   %-48s ║\n' "${p:0:48}"
  printf '%s╚══════════════════════════════════════════════════════╝%s\n' "$C_BLUE" "$C_RESET"
}

preview_render_branch() {
  local root="$1"
  local b="$2"
  local base="${3:-main}"

  printf '%s╔══════════════════════════════════════════════════════╗%s\n' "$C_BLUE" "$C_RESET"
  printf '%s║ BRANCH: %-44s ║%s\n' "$C_BOLD" "${b:0:44}" "$C_RESET"
  printf '%s╠══════════════════════════════════════════════════════╣%s\n' "$C_BLUE" "$C_RESET"

  local wt_p
  wt_p="$(git -C "$root" worktree list --porcelain 2>/dev/null | awk -v br="refs/heads/$b" '
    /^worktree / { p=$2 }
    /^branch / && $2 == br { print p; exit }
  ')"
  [[ -z "$wt_p" ]] && wt_p="None"

  printf '║ %sWorktree:%s %-43s ║\n' "$C_CYAN" "$C_RESET" "${wt_p:0:43}"
  printf '%s╠══════════════════════════════════════════════════════╣%s\n' "$C_BLUE" "$C_RESET"
  printf '%s║ RECENT COMMITS:                                      ║%s\n' "$C_CYAN" "$C_RESET"

  local commits
  commits="$(git -C "$root" log "$b" -n 5 --oneline 2>/dev/null || echo "  No commits")"
  while IFS= read -r line; do
    printf '║   %-48s ║\n' "${line:0:48}"
  done <<<"$commits"

  printf '%s╠══════════════════════════════════════════════════════╣%s\n' "$C_BLUE" "$C_RESET"
  printf '%s║ DIFF STAT (vs %s):                                ║%s\n' "$C_CYAN" "${base:0:20}" "$C_RESET"
  local diff_stat
  diff_stat="$(git -C "$root" diff --stat "$base...$b" 2>/dev/null | tail -n 4 || echo "  No diff")"
  while IFS= read -r line; do
    printf '║   %-48s ║\n' "${line:0:48}"
  done <<<"$diff_stat"

  printf '%s╚══════════════════════════════════════════════════════╝%s\n' "$C_BLUE" "$C_RESET"
}
