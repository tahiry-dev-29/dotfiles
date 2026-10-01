#!/usr/bin/env bash
# Git Tools - Modern Responsive Worktree TUI Controller
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
      log_warn "No worktrees found in $root."
      return 0
    fi

    local mode
    mode="$(terminal_get_mode)"

    for r in "${rows[@]}"; do
      # Format: path TAB branch TAB head_sha TAB is_main TAB is_detached TAB dirty_str TAB ahead_behind TAB upstream
      local p b sha is_m is_d dirty ab up
      IFS=$'\t' read -r p b sha is_m is_d dirty ab up <<<"$r"

      local marker="○"
      [[ "$is_m" -eq 1 ]] && marker="●"
      [[ "$is_d" -eq 1 ]] && marker="⬡"

      local t_path
      t_path="$(truncate_path "$p" 38)"

      local label
      if [[ "$mode" == "wide" ]]; then
        label="$(printf '%-2s %-24s %-8s %-24s %-10s %s' "$marker" "$(truncate_text "$b" 24)" "$sha" "$dirty" "$ab" "$t_path")"
      elif [[ "$mode" == "medium" ]]; then
        label="$(printf '%-2s %-20s %-18s %s' "$marker" "$(truncate_text "$b" 20)" "$dirty" "$t_path")"
      else
        label="$(printf '%-2s %-18s %s' "$marker" "$(truncate_text "$b" 18)" "$dirty")"
      fi
      display_rows+=("$(printf '%s\t%s' "$p" "$label")")
    done

    local current_b
    current_b="$(git -C "$root" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")"

    local header
    header="$(render_header "GWT" "$(basename "$root")" "$current_b" "${#rows[@]} worktrees")"
    local footer
    footer="$(render_footer "gwt" "$mode")"
    local full_header="${header}"$'\n'"${footer}"

    # Preview configuration according to responsive layout
    local preview_opt="right:45%:wrap"
    [[ "$mode" == "medium" ]] && preview_opt="right:35%:wrap"
    [[ "$mode" == "narrow" ]] && preview_opt="down:40%:wrap:hidden"

    local preview_cmd
    preview_cmd="source '$LIB_DIR/core.sh' 2>/dev/null; source '$LIB_DIR/preview_service.sh' 2>/dev/null; preview_render_worktree {1}"

    local fzf_out key selected_path
    fzf_out="$(printf '%s\n' "${display_rows[@]}" | \
      ui_select "gwt> " "$full_header" "enter,n,p,i,c,t,d,r,m,R,?,q,esc" "$preview_cmd" $'\t' 2 false "$preview_opt")" || break

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
