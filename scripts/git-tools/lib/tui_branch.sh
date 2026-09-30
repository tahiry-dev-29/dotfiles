#!/usr/bin/env bash
# Git Tools - Branch TUI Controller
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
        display_rows+=("$(printf '%s\t%-35s %-15s %s' "$rb" "$rb" "$rdate" "$rsubj")")
      else
        local b is_c is_m up ab wt subj
        IFS=$'\t' read -r b is_c is_m up ab wt subj <<<"$r"
        local marker=" "; [[ "$is_c" -eq 1 ]] && marker="●"
        local mrg="[unmerged]"; [[ "$is_m" -eq 1 ]] && mrg="[merged]  "
        local wt_l=""; [[ "$wt" != "-" ]] && wt_l="[wt: $(basename "$wt")]"
        local label; label="$(printf '%-2s %-25s %-10s %-14s %-18s %s' "$marker" "$b" "$mrg" "$ab" "$wt_l" "$subj")"
        display_rows+=("$(printf '%s\t%s' "$b" "$label")")
      fi
    done

    local header
    header="$(printf 'Repo: %s | Base: %s | Filter: [%s]\nEnter=Details | s=Switch | w=Worktree | d=Delete | p=PR | f=Filter | m=Multi | ?=Help | q=Quit' \
      "$(basename "$root")" "$base_branch" "$ACTIVE_BRANCH_FILTER")"
    local preview_cmd
    preview_cmd="git -C '$root' log --oneline -10 --graph '{1}' 2>/dev/null; echo '--- diff with base ---'; git -C '$root' diff --stat '$base_branch...{1}' 2>/dev/null | head -15"

    local fzf_out key selected_line selected_branch
    fzf_out="$(printf '%s\n' "${display_rows[@]}" | \
      ui_select "gb> " "$header" "enter,s,w,d,p,f,m,R,?,q,esc" "$preview_cmd" $'\t' 2 false)" || break

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
