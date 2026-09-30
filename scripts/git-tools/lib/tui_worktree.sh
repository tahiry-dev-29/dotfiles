#!/usr/bin/env bash
# Git Tools - Worktree TUI Controller
set -euo pipefail

run_gwt_tui() {
  local root="$1"
  require_fzf || return 1
  load_config "$root"

  while true; do
    local rows=() display_rows=()
    while IFS= read -r line; do
      [[ -n "$line" ]] && rows+=("$line")
    done < <(worktree_list "$root")

    if [[ ${#rows[@]} -eq 0 ]]; then
      log_warn "No worktrees found."
      return 0
    fi

    for r in "${rows[@]}"; do
      # Format: path TAB branch TAB head_sha TAB is_main TAB is_detached TAB dirty_str TAB ahead_behind TAB upstream
      local p b sha is_m is_d dirty ab up
      IFS=$'\t' read -r p b sha is_m is_d dirty ab up <<<"$r"
      local marker=" "
      [[ "$is_m" -eq 1 ]] && marker="●"
      [[ "$is_d" -eq 1 ]] && marker="⬡"

      local label
      label="$(printf '%-2s %-25s %-8s %-24s %-12s %s' "$marker" "$b" "$sha" "$dirty" "$ab" "$p")"
      display_rows+=("$(printf '%s\t%s' "$p" "$label")")
    done

    local current_b
    current_b="$(git -C "$root" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")"
    local header
    header="$(printf 'Repo: %s | Current: %s | Worktrees: %d\nEnter=Open | n=New | p=PR | i=Issue | c=Commit | t=Tag | d=Detach | r=Remove | m=Multi | ?=Help | q=Quit' \
      "$(basename "$root")" "$current_b" "${#rows[@]}")"
    local preview_cmd
    preview_cmd="git -C {1} log --oneline -5 --decorate 2>/dev/null; echo '--- status ---'; git -C {1} status --short 2>/dev/null"

    local fzf_out key selected_path
    fzf_out="$(printf '%s\n' "${display_rows[@]}" | \
      ui_select "gwt> " "$header" "enter,n,p,i,c,t,d,r,m,R,?,q,esc" "$preview_cmd" $'\t' 2 false)" || break

    key="$(head -n1 <<<"$fzf_out")"
    local selected_line
    selected_line="$(sed -n 2p <<<"$fzf_out")"
    selected_path="$(cut -f1 <<<"$selected_line")"

    case "$key" in
      q|esc) break ;;
      R) github_cache_invalidate "prs_"; continue ;;
      \?) ui_help_modal "gwt" ;;
      n) gwt_flow_new "$root"; ui_pause ;;
      p) gwt_flow_pr "$root"; ui_pause ;;
      i) gwt_flow_issue "$root"; ui_pause ;;
      c) gwt_flow_commit "$root"; ui_pause ;;
      t) gwt_flow_tag "$root"; ui_pause ;;
      d) gwt_flow_detached "$root"; ui_pause ;;
      m) gwt_flow_multi_remove "$root"; ui_pause ;;
      r)
        if [[ -n "$selected_path" ]]; then
          gwt_flow_remove "$root" "$selected_path"
          ui_pause
        fi
        ;;
      enter|"")
        if [[ -n "$selected_path" ]]; then
          printf '%s\n' "$selected_path"
          break
        fi
        ;;
    esac
  done
}
