#!/usr/bin/env bash
# Git Tools - Branch Details Screen
set -euo pipefail

show_branch_details() {
  local root="$1"
  local branch="$2"
  local base_branch="$3"

  local current_branch
  current_branch="$(git -C "$root" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")"

  local is_current="No"
  [[ "$branch" == "$current_branch" ]] && is_current="YES (Active HEAD)"

  local upstream
  upstream="$(git -C "$root" rev-parse --abbrev-ref --symbolic-full-name "$branch@{upstream}" 2>/dev/null || echo "None")"

  local is_merged="No (Unmerged)"
  if git -C "$root" branch --merged "$base_branch" --format="%(refname:short)" 2>/dev/null | grep -qx "$branch"; then
    is_merged="Yes (Merged into $base_branch)"
  fi

  # Worktree
  local wt_path
  wt_path="$(git -C "$root" worktree list --porcelain 2>/dev/null | awk -v br="refs/heads/$branch" '
    /^worktree / { p=$2 }
    /^branch / && $2 == br { print p; exit }
  ')"
  [[ -z "$wt_path" ]] && wt_path="None"

  # PR info if GitHub is available
  local pr_info="None"
  if github_is_available "$root"; then
    local pr_record
    pr_record="$(github_get_pr_for_branch "$root" "$branch" || true)"
    if [[ -n "$pr_record" ]]; then
      local pr_num pr_title pr_author pr_ci
      IFS=$'\t' read -r pr_num pr_title pr_author pr_ci <<<"$pr_record"
      pr_info="#$pr_num: $pr_title (by @$pr_author, CI:$pr_ci)"
    fi
  fi

  clear || true
  printf '%s╔══════════════════════════════════════════════════════════════════════╗%s\n' "$C_BLUE" "$C_RESET"
  printf '%s║ Branch Details: %-52s ║%s\n' "$C_BOLD" "$branch" "$C_RESET"
  printf '%s╠══════════════════════════════════════════════════════════════════════╣%s\n' "$C_BLUE" "$C_RESET"
  printf '║ Current HEAD:    %-51s ║\n' "$is_current"
  printf '║ Upstream:        %-51s ║\n' "$upstream"
  printf '║ Merged Status:   %-51s ║\n' "$is_merged"
  printf '║ Worktree:        %-51s ║\n' "$wt_path"
  printf '║ Pull Request:    %-51s ║\n' "$pr_info"
  printf '%s╠══════════════════════════════════════════════════════════════════════╣%s\n' "$C_BLUE" "$C_RESET"
  printf '%s║ Recent Commits (Last 5):                                             ║%s\n' "$C_CYAN" "$C_RESET"

  local commit_lines
  commit_lines="$(git -C "$root" log "$branch" -n 5 --oneline 2>/dev/null || echo "No commits found")"
  while IFS= read -r cline; do
    printf '║   %-66s ║\n' "${cline:0:66}"
  done <<<"$commit_lines"

  printf '%s╠══════════════════════════════════════════════════════════════════════╣%s\n' "$C_BLUE" "$C_RESET"
  printf '%s║ Diff with Base (%s):                                              ║%s\n' "$C_CYAN" "$base_branch" "$C_RESET"

  local diff_stat
  diff_stat="$(git -C "$root" diff --stat "$base_branch...$branch" 2>/dev/null | tail -n 5 || echo "No diff")"
  while IFS= read -r dline; do
    printf '║   %-66s ║\n' "${dline:0:66}"
  done <<<"$diff_stat"

  printf '%s╠══════════════════════════════════════════════════════════════════════╣%s\n' "$C_BLUE" "$C_RESET"
  printf '%s║ Actions: [s] Switch  [w] Worktree  [p] PR  [d] Delete  [b/Esc] Back    ║%s\n' "$C_YELLOW" "$C_RESET"
  printf '%s╚══════════════════════════════════════════════════════════════════════╝%s\n' "$C_BLUE" "$C_RESET"

  printf '%sChoice: %s' "$C_BOLD" "$C_RESET"
  local action
  read -r -n 1 action </dev/tty || action=""
  printf '\n'

  case "$action" in
    s|S) _gb_flow_checkout "$root" "$branch" ;;
    w|W) _gb_flow_create_worktree "$root" "$branch" ;;
    p|P)
      if [[ "$pr_info" != "None" ]]; then
        local pr_n
        pr_n="$(cut -d':' -f1 <<<"${pr_info#"#"}")"
        if confirm "Open PR #$pr_n in browser?"; then
          pr_open_web "$root" "$pr_n"
        fi
      else
        pr_create_interactive "$root"
      fi
      ;;
    d|D) _gb_flow_delete "$root" "$branch" "$base_branch" ;;
    *) return 0 ;;
  esac
  ui_pause
}
