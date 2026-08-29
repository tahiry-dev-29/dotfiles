#!/usr/bin/env bash
# gwt manager — context-aware fzf pane listing worktrees for the current repo:
# enter=open(cd) · n=new · d=delete(+branch) · c=cleanup(PR) · p=PR flow · r=refresh · q=quit · esc=cancel
set -uo pipefail

ROOT=${PWD:?}
GWT_SCRIPT="$HOME/dotfiles/scripts/git-worktree-auto.sh"
PROTECTED_RE='^(main|master|trunk)$'

# Determine the protected main branch of this repo once.
MAIN_BRANCH=""
for _b in main master trunk; do
  if git -C "$ROOT" show-ref --verify --quiet "refs/heads/$_b" 2>/dev/null; then
    MAIN_BRANCH="$_b"
    break
  fi
done

# ── Colors & toast ──────────────────────────────────────────────────────
C_RESET=$'\033[0m'
C_GREEN=$'\033[32m'
C_RED=$'\033[31m'
C_CYAN=$'\033[36m'
C_YELLOW=$'\033[33m'

ok()   { printf '%s✓ %s%s\n'   "$C_GREEN"  "$*" "$C_RESET"; }
err()  { printf '%s✗ %s%s\n'   "$C_RED"    "$*" "$C_RESET"; }
info() { printf '%s→ %s%s\n'   "$C_CYAN"  "$*" "$C_RESET"; }
warn() { printf '%s! %s%s\n'   "$C_YELLOW" "$*" "$C_RESET"; }
say()  { printf '%s\n' "$*"; }

toast() {
  herdr notification show "$1" --body "${2:-}" --sound done --position bottom-right \
    >/dev/null 2>&1 || true
}

pause()    { read -rp "— Press Enter to continue —"; }
feedback() { say ""; read -rp "  press Enter to go back… "; }

require() { command -v "$1" >/dev/null 2>&1 || { err "'$1' is required but not found"; pause; exit 1; }; }
require fzf
require herdr
require jq
[[ -x "$GWT_SCRIPT" ]] || GWT_SCRIPT="bash $HOME/dotfiles/scripts/git-worktree-auto.sh"

# Build the rows. Each row carries 7 tab-separated fields:
#   path \t branch \t wslabel \t status \t kind(source|worktree) \t has_diff(0|1) \t has_pr(0|1)
# The fzf preview only displays columns 2-4 (branch, wslabel, status).
build_rows() {
  local line path branch wsid linked st d up cnt src_line="" kind has_diff has_pr
  local -a rest=()
  while IFS=$'\t' read -r path branch wsid linked; do
    [[ -z "$path" ]] && continue
    kind="worktree"
    has_diff="0"
    has_pr="0"
    # Main worktree has .git as a directory; worktrees have .git as a file
    if [[ -d "$path/.git" ]]; then
      kind="source"
    fi

    d=$(git -C "$path" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
    st="clean"
    [[ "$d" != 0 ]] && st="dirty×$d"
    up=$(git -C "$path" rev-list --left-right --count '@{upstream}'...HEAD 2>/dev/null || true)
    if [[ -n "$up" ]]; then
      cnt=$(awk '{print "↓"$1"/↑"$2}' <<<"$up")
      st="$st $cnt"
    fi
    [[ "$linked" == "true" && "$wsid" != "-" ]] && wslabel="linked $wsid" || wslabel="free"

    if [[ "$kind" == "worktree" && -n "$MAIN_BRANCH" ]]; then
      git -C "$path" diff --quiet "$MAIN_BRANCH" 2>/dev/null
      if [[ $? -eq 1 ]]; then
        has_diff="1"
        st="$st diff"
      fi
      # Check if an open PR exists for this branch
      if command -v gh >/dev/null 2>&1 && [[ -n "$branch" && "$branch" != "-" ]]; then
        local pr_count
        pr_count=$(gh pr list --head "$branch" --state open --json number --jq 'length' 2>/dev/null || echo "0")
        [[ "$pr_count" != "0" ]] && has_pr="1"
      fi
    fi

    line="$(printf '%s\t%s\t%s\t%s\t%s\t%s\t%s' "$path" "$branch" "$wslabel" "$st" "$kind" "$has_diff" "$has_pr")"
    if [[ "$kind" == "source" ]]; then
      src_line="$line"                 # pin the source checkout on top
    else
      rest+=("$line")
    fi
  done < <(herdr worktree list --cwd "$ROOT" 2>/dev/null |
    jq -r '.result.worktrees[]? | [.path, (.branch // "-"), (.open_workspace_id // "-"), (.is_linked_worktree // false)] | @tsv')
  [[ -n "${src_line:-}" ]] && printf '%s\n' "$src_line"
  if (( ${#rest[@]} )); then
    printf '%s\n' "${rest[@]}" | LC_ALL=C sort -t$'\t' -k2,2
  fi
}

confirm() {
  local a
  read -rp "$1 [y/N] " a
  [[ "$a" == y* ]]
}

go_to() {
  local target=$1
  local label="${MAIN_BRANCH:-main}"
  if herdr worktree open --path "$target" --branch "$MAIN_BRANCH" --label "$label" --focus >/dev/null 2>&1; then
    return
  fi
  # Fallback: focus existing tab or create one
  local existing_tab
  existing_tab=$(herdr tab list 2>/dev/null |
    jq -r --arg cwd "$target" '.result.tabs[]? | select(.cwd == $cwd) | .tab_id' 2>/dev/null | head -1 || true)
  if [[ -n "$existing_tab" ]]; then
    herdr tab focus "$existing_tab" >/dev/null 2>&1 || true
  else
    herdr tab create --cwd "$target" --label "$label" --focus >/dev/null 2>&1 || true
  fi
}

open_wt() {
  local path=$1 br=${2:-}
  local label="${br:-$(basename "$path")}"
  if herdr worktree open --path "$path" --branch "$br" --label "$label" --focus >/dev/null 2>&1; then
    ok "opened $path"
    toast "Opened" "$path"
  else
    err "failed to open $path"
    toast "Open failed" "$path"
  fi
}

remove_core() {
  local path=$1 br=$2 ws=$3
  bash "$GWT_SCRIPT" remove "$path" -y || return 1
}

del_wt() {
  local path=$1 br=$2 ws=$3 has_diff=${4:-0}
  # Guard: block delete if branch has no PR and has diff with main
  if [[ "$has_diff" == "1" && -n "$br" ]]; then
    local pr_count
    pr_count=$(gh pr list --head "$br" --state open --json number --jq 'length' 2>/dev/null || echo "0")
    if [[ "$pr_count" == "0" ]]; then
      err "branch '$br' has no PR — push & create a PR first"
      toast "Delete blocked" "$br has no PR"
      return 1
    fi
  fi
  confirm "delete '$path' ($br)?" || return 0
  if [[ -n $(git -C "$path" status --porcelain 2>/dev/null) ]]; then
    confirm "dirty worktree — force delete?" || return 0
  fi
  # Remove worktree
  if ! bash "$GWT_SCRIPT" remove "$path" -y; then
    err "worktree remove failed"
    toast "Delete failed" "$path ($br)"
    return
  fi
  # Delete branch explicitly (script may fail in subshell)
  if [[ -n "$br" && ! "$br" =~ $PROTECTED_RE ]]; then
    if git -C "$ROOT" show-ref --verify -q "refs/heads/$br" 2>/dev/null; then
      if git -C "$ROOT" branch -D "$br" >/dev/null 2>&1; then
        ok "branch '$br' deleted"
      else
        warn "failed to delete branch '$br'"
      fi
    fi
  fi
  toast "Worktree deleted" "$path ($br)"
  go_to "$ROOT"
}

cleanup_wt() {
  local path=$1 br=$2 ws=$3 strategy="squash" a
  read -rp "PR merge strategy [squash]: " a
  [[ -n "$a" ]] && strategy="$a"
  info "cleanup: merge PR (--$strategy) then remove…"
  if bash "$GWT_SCRIPT" cleanup "$path" "$strategy" -y; then
    toast "Cleanup done" "$path"
    go_to "$ROOT"
  else
    err "cleanup failed"
    toast "Cleanup failed" "$path"
  fi
}

new_wt() {
  local br base slug target main_root
  read -rp "new branch (e.g. feature/x): " br
  [[ -n "$br" ]] || return 0
  read -rp "base [HEAD] : " base
  slug=${br//\//-}
  target="$(dirname "$ROOT")/$slug"
  if [[ -e "$target" ]] || git -C "$ROOT" show-ref --verify -q "refs/heads/$br"; then
    err "'$br' already exists (folder or branch)"
    return 0
  fi
  # Resolve base branch
  if [[ -z "$base" ]]; then
    if git -C "$ROOT" show-ref --verify --quiet refs/heads/main; then base="main"
    elif git -C "$ROOT" show-ref --verify --quiet refs/heads/master; then base="master"
    else base=$(git -C "$ROOT" config --get init.defaultBranch || echo "main"); fi
  fi
  local out
  if out=$(git -C "$ROOT" worktree add "$target" -b "$br" "$base" 2>&1); then
    ok "created: $target ($br)"
    # Copy .env files from main checkout
    main_root=$(git -C "$ROOT" worktree list --porcelain | sed -n 's/^worktree //p' | head -n1)
    if [[ "$main_root" != "$target" && -d "$main_root" ]]; then
      for f in "$main_root"/.env*; do
        [[ -f "$f" ]] || continue
        if [[ ! -e "$target/$(basename "$f")" ]]; then
          cp "$f" "$target/$(basename "$f")" && info "copied $(basename "$f") from main"
        fi
      done
    fi
    # pnpm install if package.json exists
    if [[ -f "$target/package.json" ]]; then
      info "running pnpm install --frozen-lockfile..."
      (cd "$target" && pnpm install --frozen-lockfile) && ok "pnpm install done" || warn "pnpm install had issues"
    fi
    toast "Worktree created" "$br → $target"
    if confirm "cd into $target?"; then
      open_wt "$target" "$br"
    fi
  else
    err "creation failed: $(head -n1 <<<"${out:-unknown error}")"
    toast "Create failed" "$br"
  fi
}

pr_wt() {
  local path=$1 br=$2 ws=$3 msg
  read -rp "commit message [wip: worktree changes]: " msg
  [[ -z "$msg" ]] && msg="wip: worktree changes"
  info "running PR flow for '$br'…"
  if bash "$GWT_SCRIPT" pr-flow "$path" "$msg" -y; then
    ok "PR created: $br"
    toast "PR created" "$br — $msg"
  else
    err "PR flow failed"
    toast "PR failed" "$br"
  fi
}

while :; do
  mapfile -t rows < <(build_rows)
  if [[ ${#rows[@]} -eq 0 ]]; then
    say ""
    say "  ⚠ no worktrees found in $ROOT"
    say "  (n=new · r=refresh · q/esc=quit)"
    read -rp "  press Enter to refresh… " _
    continue
  fi
  # Add PR symbol to status field: ● = has PR, ○ = no PR
  local -a display_rows=()
  for r in "${rows[@]}"; do
    local has_pr_field status_field
    has_pr_field=$(cut -f7 <<<"$r")
    status_field=$(cut -f4 <<<"$r")
    if [[ "$has_pr_field" == "1" ]]; then
      r=$(printf '%s' "$r" | awk -F'\t' -v OFS='\t' '{$4="● "$4; print}')
    else
      r=$(printf '%s' "$r" | awk -F'\t' -v OFS='\t' '{$4="○ "$4; print}')
    fi
    display_rows+=("$r")
  done
  sel=$(printf '%s\n' "${display_rows[@]}" |
    fzf --ansi --reverse --height=100% \
      --header='enter=open   n=new   d=delete   c=cleanup(PR)   p=PR flow   r=refresh   q=quit   esc=cancel' \
      --prompt="gwt [${#rows[@]}]> " --delimiter=$'\t' --with-nth=2,3,4 \
      --expect=enter,n,d,c,p,r,q,esc \
      --preview="git -C \"{1}\" log --oneline -7 --decorate 2>/dev/null; echo; git -C \"{1}\" status --short --branch 2>/dev/null | head -25" \
      --preview-window=right:45%:wrap) || continue
  key=$(sed -n 1p <<<"$sel")
  line=$(sed -n 2p <<<"$sel")
  # q/esc quit even when a row is selected
  [[ "$key" == q || "$key" == esc ]] && break
  if [[ -z "$line" ]]; then
    continue
  fi
  # path \t branch \t wslabel \t status \t kind \t has_diff \t has_pr
  IFS=$'\t' read -r path br wslabel _ kind has_diff has_pr <<<"$line"
  ws="-"
  if [[ "$wslabel" =~ ^linked[[:space:]]([A-Za-z0-9:_-]+)$ ]]; then
    ws="${BASH_REMATCH[1]}"
  fi
  case "$key" in
    r) ;;
    n) new_wt; feedback ;;
    d)
      if [[ "$kind" == "source" ]]; then
        info "cannot delete the main checkout"
      else
        del_wt "$path" "$br" "$ws" "$has_diff"
      fi
      feedback ;;
    c)
      if [[ "$kind" == "source" ]]; then
        info "no cleanup on the main checkout"
      else
        cleanup_wt "$path" "$br" "$ws"
      fi
      feedback ;;
    p)
      if [[ "$kind" == "source" || "$has_diff" == "0" ]]; then
        info "no diff with main — PR not available"
      else
        pr_wt "$path" "$br" "$ws"
      fi
      feedback ;;
    *) open_wt "$path" "$br"; break ;;
  esac
done
say "bye 👋"
