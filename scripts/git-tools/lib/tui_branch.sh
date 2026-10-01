#!/usr/bin/env bash
# Git Tools - Modern Responsive Branch TUI Controller
set -euo pipefail

ACTIVE_BRANCH_FILTER="ALL"

run_gb_tui() {
  local root="$1"
  require_fzf || return 1
  load_config "$root"
  local base_branch
  base_branch="$(get_default_base_branch "$root")"

  while true; do
    local rows=() display_rows=()
    while IFS= read -r line; do
      [[ -n "$line" ]] && rows+=("$line")
    done < <(branch_list "$root" "$base_branch" "$ACTIVE_BRANCH_FILTER")

    local mode
    mode="$(terminal_get_mode)"

    if [[ ${#rows[@]} -eq 0 ]]; then
      log_warn "No branches found for filter: $ACTIVE_BRANCH_FILTER"
      printf '%sPress f to change filter, R to refresh, q to quit...%s\n' "$C_DIM" "$C_RESET"
      local key; read -r -n 1 key </dev/tty || key="q"
      [[ "$key" == "f" ]] && { _gb_cycle_filter; continue; }
      [[ "$key" == "R" ]] && continue
      break
    fi

    for r in "${rows[@]}"; do
      if [[ "$ACTIVE_BRANCH_FILTER" == "REMOTE" ]]; then
        local rb rdate rsubj
        IFS=$'\t' read -r rb rdate rsubj <<<"$r"
        display_rows+=("$(printf '%s\t%-32s %-12s %s' "$rb" "$(truncate_text "$rb" 32)" "$rdate" "$(truncate_text "$rsubj" 30)")")
      else
        local b is_c is_m up ab wt subj
        IFS=$'\t' read -r b is_c is_m up ab wt subj <<<"$r"
        local marker=" "; [[ "$is_c" -eq 1 ]] && marker="●"
        local mrg="[unmerged]"; [[ "$is_m" -eq 1 ]] && mrg="[merged]  "
        local wt_l=""; [[ "$wt" != "-" ]] && wt_l="[wt: $(basename "$wt")]"

        local label
        if [[ "$mode" == "wide" ]]; then
          label="$(printf '%-2s %-24s %-10s %-12s %-16s %s' "$marker" "$(truncate_text "$b" 24)" "$mrg" "$ab" "$wt_l" "$(truncate_text "$subj" 30)")"
        elif [[ "$mode" == "medium" ]]; then
          label="$(printf '%-2s %-20s %-10s %-12s %s' "$marker" "$(truncate_text "$b" 20)" "$mrg" "$ab" "$wt_l")"
        else
          label="$(printf '%-2s %-18s %s' "$marker" "$(truncate_text "$b" 18)" "$mrg")"
        fi
        display_rows+=("$(printf '%s\t%s' "$b" "$label")")
      fi
    done

    local current_b
    current_b="$(git -C "$root" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")"

    local header
    header="$(render_header "GB" "$(basename "$root")" "$current_b" "Filter: [$ACTIVE_BRANCH_FILTER] · Base: $base_branch")"
    local footer
    footer="$(render_footer "gb" "$mode")"
    local full_header="${header}"$'\n'"${footer}"

    local preview_opt="right:45%:wrap"
    [[ "$mode" == "medium" ]] && preview_opt="right:35%:wrap"
    [[ "$mode" == "narrow" ]] && preview_opt="down:40%:wrap:hidden"

    local preview_cmd
    preview_cmd="source '$LIB_DIR/core.sh' 2>/dev/null; source '$LIB_DIR/preview_service.sh' 2>/dev/null; preview_render_branch '$root' {1} '$base_branch'"

    local fzf_out key selected_line selected_branch
    fzf_out="$(printf '%s\n' "${display_rows[@]}" | \
      ui_select "gb> " "$full_header" "enter,s,w,d,p,f,m,R,?,q,esc" "$preview_cmd" $'\t' 2 false "$preview_opt")" || break

    key="$(head -n1 <<<"$fzf_out")"
    selected_line="$(sed -n 2p <<<"$fzf_out")"
    selected_branch="$(cut -f1 <<<"$selected_line")"

    case "$key" in
      q|esc) break ;;
      R) github_cache_invalidate "prs_"; continue ;;
      f) _gb_cycle_filter ;;
      \?) ui_help_modal "gb" ;;
      m) gb_flow_multi_delete "$root" "$base_branch"; ui_pause ;;
      p)
        if [[ -n "$selected_branch" ]]; then
          gb_flow_pr "$root" "$selected_branch"
          ui_pause
        fi
        ;;
      s)
        if [[ -n "$selected_branch" ]]; then
          if [[ "$ACTIVE_BRANCH_FILTER" == "REMOTE" ]]; then
            remote_track_and_switch "$root" "$selected_branch"
          else
            branch_switch "$root" "$selected_branch"
          fi
          ui_pause
        fi
        ;;
      w)
        if [[ -n "$selected_branch" ]]; then
          gb_flow_create_worktree "$root" "$selected_branch"
          ui_pause
        fi
        ;;
      d)
        if [[ -n "$selected_branch" ]]; then
          gb_flow_delete "$root" "$selected_branch" "$base_branch"
          ui_pause
        fi
        ;;
      enter|"")
        if [[ -n "$selected_branch" ]]; then
          if [[ "$ACTIVE_BRANCH_FILTER" == "REMOTE" ]]; then
            remote_track_and_switch "$root" "$selected_branch"
            ui_pause
          else
            show_branch_details "$root" "$selected_branch" "$base_branch"
          fi
        fi
        ;;
    esac
  done
}

_gb_cycle_filter() {
  case "$ACTIVE_BRANCH_FILTER" in
    ALL)          ACTIVE_BRANCH_FILTER="MERGED" ;;
    MERGED)       ACTIVE_BRANCH_FILTER="NOT_MERGED" ;;
    NOT_MERGED)   ACTIVE_BRANCH_FILTER="WITH_CHANGES" ;;
    WITH_CHANGES) ACTIVE_BRANCH_FILTER="REMOTE" ;;
    REMOTE)       ACTIVE_BRANCH_FILTER="ALL" ;;
    *)            ACTIVE_BRANCH_FILTER="ALL" ;;
  esac
}
