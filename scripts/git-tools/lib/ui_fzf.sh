#!/usr/bin/env bash
# Git Tools - Terminal UI & FZF Integration
set -euo pipefail

require_fzf() {
  if ! command -v fzf >/dev/null 2>&1; then
    log_err "fzf is required for the interactive UI but is not installed."
    return 1
  fi
  return 0
}

ui_select() {
  local prompt="$1"
  local header="$2"
  local expect_keys="$3"
  local preview_cmd="$4"
  local delimiter="${5:-$'\t'}"
  local with_nth="${6:-}"
  local multi="${7:-false}"
  local preview_window="${8:-right:50%:wrap}"

  local -a fzf_opts=(
    --ansi
    --reverse
    --height=100%
    --prompt="$prompt"
    --header="$header"
    --expect="$expect_keys"
    --delimiter="$delimiter"
  )

  [[ -n "$with_nth" ]] && fzf_opts+=(--with-nth="$with_nth")
  [[ "$multi" == "true" ]] && fzf_opts+=(--multi)
  [[ -n "$preview_cmd" ]] && fzf_opts+=(--preview="$preview_cmd" --preview-window="$preview_window")

  local result
  result="$(fzf "${fzf_opts[@]}")" || return 1
  printf '%s\n' "$result"
}

ui_pause() {
  printf '\n%sPress Enter to continue...%s' "$C_DIM" "$C_RESET"
  read -r _ </dev/tty || true
}

ui_preview_action() {
  local action_title="$1"
  local command_preview="$2"

  printf '\n%s╔══════════════════════════════════════════════════════╗%s\n' "$C_CYAN" "$C_RESET"
  printf '%s║ Action: %-44s ║%s\n' "$C_CYAN" "$action_title" "$C_RESET"
  printf '%s║ Command:                                             ║%s\n' "$C_CYAN" "$C_RESET"
  printf '%s║   %-48s ║%s\n' "$C_DIM" "$command_preview" "$C_RESET"
  printf '%s╚══════════════════════════════════════════════════════╝%s\n' "$C_CYAN" "$C_RESET"
}

ui_help_modal() {
  local context="${1:-gwt}"
  clear || true
  printf '%s╔══════════════════════════════════════════════════════════════════╗%s\n' "$C_BLUE" "$C_RESET"
  if [[ "$context" == "gwt" ]]; then
    printf '%s║               GWT — Git Worktree Manager Shortcuts               ║%s\n' "$C_BOLD" "$C_RESET"
    printf '%s╠══════════════════════════════════════════════════════════════════╣%s\n' "$C_BLUE" "$C_RESET"
    printf '║  %sEnter%s   Open selected worktree in shell                            ║\n' "$C_CYAN" "$C_RESET"
    printf '║  %sn%s       Create new branch worktree (+ auto bootstrap)              ║\n' "$C_CYAN" "$C_RESET"
    printf '║  %sp%s       Create worktree from GitHub Pull Request                   ║\n' "$C_CYAN" "$C_RESET"
    printf '║  %si%s       Create branch & worktree from GitHub Issue                 ║\n' "$C_CYAN" "$C_RESET"
    printf '║  %sc%s       Create worktree from Commit (branch or detached)           ║\n' "$C_CYAN" "$C_RESET"
    printf '║  %st%s       Create detached worktree from Tag                          ║\n' "$C_CYAN" "$C_RESET"
    printf '║  %sd%s       Create detached worktree directly from ref                 ║\n' "$C_CYAN" "$C_RESET"
    printf '║  %sr%s       Safe remove selected worktree                              ║\n' "$C_CYAN" "$C_RESET"
    printf '║  %sm%s       Toggle multi-select mode (bulk remove)                     ║\n' "$C_CYAN" "$C_RESET"
    printf '║  %sR%s       Refresh worktree list                                      ║\n' "$C_CYAN" "$C_RESET"
    printf '║  %s/%s       Fuzzy search worktrees                                     ║\n' "$C_CYAN" "$C_RESET"
    printf '║  %s?%s       Show this help screen                                      ║\n' "$C_CYAN" "$C_RESET"
    printf '║  %sq / Esc%s Exit Worktree Manager                                      ║\n' "$C_CYAN" "$C_RESET"
  else
    printf '%s║                GB — Git Branch Manager Shortcuts                 ║%s\n' "$C_BOLD" "$C_RESET"
    printf '%s╠══════════════════════════════════════════════════════════════════╣%s\n' "$C_BLUE" "$C_RESET"
    printf '║  %sEnter%s   Inspect Branch Details (commits, diff stat, PR)            ║\n' "$C_CYAN" "$C_RESET"
    printf '║  %ss%s       Safe switch to branch (checks dirty worktree first)        ║\n' "$C_CYAN" "$C_RESET"
    printf '║  %sw%s       Create new worktree for selected branch                    ║\n' "$C_CYAN" "$C_RESET"
    printf '║  %sd%s       Safe delete branch (-d if merged, confirms -D if unmerged) ║\n' "$C_CYAN" "$C_RESET"
    printf '║  %sp%s       Pull Request flow (inspect/open web/create)                ║\n' "$C_CYAN" "$C_RESET"
    printf '║  %sf%s       Cycle filter (ALL, MERGED, NOT MERGED, WITH CHANGES, ...)  ║\n' "$C_CYAN" "$C_RESET"
    printf '║  %sm%s       Toggle multi-select mode (bulk branch deletion)            ║\n' "$C_CYAN" "$C_RESET"
    printf '║  %sR%s       Refresh branch list                                        ║\n' "$C_CYAN" "$C_RESET"
    printf '║  %s/%s       Fuzzy search branches                                      ║\n' "$C_CYAN" "$C_RESET"
    printf '║  %s?%s       Show this help screen                                      ║\n' "$C_CYAN" "$C_RESET"
    printf '║  %sq / Esc%s Exit Branch Manager                                        ║\n' "$C_CYAN" "$C_RESET"
  fi
  printf '%s╚══════════════════════════════════════════════════════════════════╝%s\n' "$C_BLUE" "$C_RESET"
  ui_pause
}
