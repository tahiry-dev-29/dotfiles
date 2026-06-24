#!/usr/bin/env bash
# ==============================================================================
# git-worktree-auto.sh — Automated Git Worktree Workflow
# Based on ~/Documents/Packages_note/Tools/Git/WorkTree.md
# Supports: create, list, remove, full PR flow
# ==============================================================================

set -euo pipefail

# ── Colors & Logging ──────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

LOG_FILE="${GWT_LOG_FILE:-$HOME/.cache/git-worktree-auto.log}"
mkdir -p "$(dirname "$LOG_FILE")"

_log() {
  local level="$1" color="$2" icon="$3"
  shift 3
  local message="$*"
  local timestamp
  timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  printf "${color}${icon} [${timestamp}] [${level}] ${message}${RESET}\n"
  printf "[${timestamp}] [${level}] ${message}\n" >> "$LOG_FILE"
}

log_info()    { _log "INFO"    "$CYAN"   "ℹ️ " "$@"; }
log_success() { _log "SUCCESS" "$GREEN"  "✅" "$@"; }
log_warn()    { _log "WARN"    "$YELLOW" "⚠️ " "$@"; }
log_error()   { _log "ERROR"   "$RED"    "❌" "$@"; }
log_step()    { _log "STEP"    "$BLUE"   "▶" "$@"; }

_divider() { echo -e "${CYAN}╔══════════════════════════════════════════════════════╗${RESET}"; }
_divider_end() { echo -e "${CYAN}╚══════════════════════════════════════════════════════╝${RESET}"; }

_confirm() {
  local prompt="$1"
  printf "${YELLOW}❓ ${prompt} [y/N] ${RESET}"
  read -r reply
  [[ "$reply" =~ ^[yY]$ ]]
}

# ── Guard: must be inside a git repo ─────────────────────────────────────────
_require_git_root() {
  local root
  root=$(git rev-parse --show-toplevel 2>/dev/null) || {
    log_error "Not inside a git repository."
    exit 1
  }
  echo "$root"
}

# ── Usage ─────────────────────────────────────────────────────────────────────
usage() {
  echo ""
  echo -e "${BOLD}git-worktree-auto.sh${RESET} — Git Worktree Automation"
  echo ""
  echo -e "  ${GREEN}create${RESET}  <path> <branch> [base]   Create worktree + copy .env + pnpm install"
  echo -e "  ${GREEN}list${RESET}                             List all active worktrees"
  echo -e "  ${GREEN}remove${RESET}  <path>                   Remove a worktree with confirmation"
  echo -e "  ${GREEN}pr-flow${RESET} <path> [message]         Commit, push, create PR from a worktree"
  echo -e "  ${GREEN}cleanup${RESET} <path> [merge-strategy]  Merge PR, remove worktree, pull main"
  echo ""
  echo -e "  ${CYAN}Options:${RESET}"
  echo -e "    GWT_LOG_FILE=<path>   Custom log file (default: ~/.cache/git-worktree-auto.log)"
  echo ""
  echo -e "  ${CYAN}Examples:${RESET}"
  echo -e "    $0 create ../myapp-feature-auth feature/auth main"
  echo -e "    $0 pr-flow ../myapp-feature-auth \"feat(auth): add login guard\""
  echo -e "    $0 cleanup ../myapp-feature-auth squash"
  echo ""
}

# ── CMD: create ───────────────────────────────────────────────────────────────
cmd_create() {
  local wt_path="${1:-}" branch="${2:-}" base="${3:-main}"
  if [[ -z "$wt_path" || -z "$branch" ]]; then
    log_error "Missing parameters for worktree creation."
    echo -e "${YELLOW}💡 Tutorial: How to create a worktree?${RESET}"
    echo -e "You must provide the ${BOLD}directory path${RESET} (where to create it) AND the ${BOLD}branch name${RESET}."
    echo ""
    echo -e "👉 ${CYAN}Example using the alias:${RESET}"
    echo -e "   gwt-new ../pricing-engine feature/pricing_engine"
    echo ""
    echo -e "👉 ${CYAN}Example using the full script:${RESET}"
    echo -e "   $0 create ../pricing-engine feature/pricing_engine [base]"
    echo ""
    exit 1
  fi

  local src_root
  src_root=$(_require_git_root)

  _divider
  echo -e "${CYAN}║  🌿 Git Worktree — Create                          ║${RESET}"
  echo -e "${CYAN}╠══════════════════════════════════════════════════════╣${RESET}"
  printf "${CYAN}║${RESET}  Path   : %-43s${CYAN}║${RESET}\n" "$wt_path"
  printf "${CYAN}║${RESET}  Branch : %-43s${CYAN}║${RESET}\n" "$branch"
  printf "${CYAN}║${RESET}  Base   : %-43s${CYAN}║${RESET}\n" "$base"
  printf "${CYAN}║${RESET}  Log    : %-43s${CYAN}║${RESET}\n" "$LOG_FILE"
  _divider_end

  _confirm "Create this worktree?" || { log_warn "Aborted by user."; exit 0; }

  # Step 1: Sync base branch
  log_step "Syncing base branch: $base"
  git checkout "$base" && git pull origin "$base"
  log_success "Base branch up to date."

  # Step 2: Create worktree
  log_step "Creating worktree at $wt_path on branch $branch..."
  git worktree add "$wt_path" -b "$branch" "$base"
  log_success "Worktree created."

  # Step 3: Copy .env files
  log_step "Copying .env files..."
  local envs_copied=0
  while IFS= read -r -d '' env_file; do
    local rel dest
    rel=$(realpath --relative-to="$src_root" "$env_file")
    dest="$wt_path/$rel"
    mkdir -p "$(dirname "$dest")"
    cp "$env_file" "$dest"
    log_info "Copied: $rel"
    envs_copied=$((envs_copied + 1))
  done < <(find "$src_root" -maxdepth 4 -name '.env' -not -path '*/node_modules/*' -print0 2>/dev/null)
  log_success "$envs_copied .env file(s) copied."

  # Step 4: pnpm install
  if [[ -f "$wt_path/package.json" ]]; then
    _confirm "Run pnpm install in $wt_path?" && {
      log_step "Running pnpm install..."
      (cd "$wt_path" && pnpm install) && log_success "pnpm install complete." || log_warn "pnpm install had issues."
    }
  fi

  log_success "Worktree ready → cd $wt_path"
}

# ── CMD: list ─────────────────────────────────────────────────────────────────
cmd_list() {
  log_step "Active git worktrees:"
  echo ""
  git worktree list --porcelain | awk '
    /^worktree/ { wt=$2 }
    /^branch/   { br=$2 }
    /^HEAD/     { hd=$2 }
    /^$/ && wt  {
      printf "  \033[0;32m%-50s\033[0m  branch: \033[0;36m%-30s\033[0m  HEAD: %s\n", wt, br, substr(hd,1,8)
      wt=""; br=""; hd=""
    }
  '
  echo ""
}

# ── CMD: remove ───────────────────────────────────────────────────────────────
cmd_remove() {
  local wt_path="${1:-}"
  if [[ -z "$wt_path" ]]; then
    log_error "Usage: $0 remove <path>"
    exit 1
  fi
  _require_git_root > /dev/null

  log_warn "This will remove worktree: $wt_path"
  _confirm "Confirm removal?" || { log_warn "Aborted."; exit 0; }

  log_step "Removing worktree $wt_path..."
  git worktree remove "$wt_path" --force && log_success "Worktree removed." || log_error "Failed to remove worktree."
}

# ── CMD: pr-flow ──────────────────────────────────────────────────────────────
cmd_pr_flow() {
  local wt_path="${1:-}" commit_msg="${2:-wip: worktree changes}"
  if [[ -z "$wt_path" ]]; then
    log_error "Usage: $0 pr-flow <worktree-path> [commit-message]"
    exit 1
  fi
  if [[ ! -d "$wt_path/.git" && ! -f "$wt_path/.git" ]]; then
    log_error "Path does not appear to be a worktree: $wt_path"
    exit 1
  fi

  _divider
  echo -e "${CYAN}║  🚀 PR Flow — Commit → Push → PR                   ║${RESET}"
  printf "${CYAN}║${RESET}  Path    : %-43s${CYAN}║${RESET}\n" "$wt_path"
  printf "${CYAN}║${RESET}  Message : %-43s${CYAN}║${RESET}\n" "$commit_msg"
  _divider_end

  _confirm "Proceed with PR flow?" || { log_warn "Aborted."; exit 0; }

  (
    cd "$wt_path"
    local current_branch
    current_branch=$(git rev-parse --abbrev-ref HEAD)

    log_step "Stage all changes..."
    git add .
    log_step "Commit: $commit_msg"
    git commit -m "$commit_msg"
    log_step "Push branch $current_branch to origin..."
    git push -u origin "$current_branch"
    log_success "Branch pushed."

    if command -v gh > /dev/null 2>&1; then
      log_step "Creating PR via gh CLI..."
      gh pr create --fill && log_success "PR created!" || log_warn "gh pr create failed — open GitHub to create PR manually."
    else
      log_warn "gh CLI not found. Open GitHub to create your PR for branch: $current_branch"
    fi
  )
}

# ── CMD: cleanup ──────────────────────────────────────────────────────────────
cmd_cleanup() {
  local wt_path="${1:-}" strategy="${2:-squash}"
  if [[ -z "$wt_path" ]]; then
    log_error "Usage: $0 cleanup <worktree-path> [squash|merge|rebase]"
    exit 1
  fi

  local src_root
  src_root=$(_require_git_root)
  local main_branch
  main_branch=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo "main")

  _divider
  echo -e "${CYAN}║  🧹 Cleanup — Merge PR + Remove Worktree           ║${RESET}"
  printf "${CYAN}║${RESET}  Worktree : %-42s${CYAN}║${RESET}\n" "$wt_path"
  printf "${CYAN}║${RESET}  Strategy : %-42s${CYAN}║${RESET}\n" "$strategy"
  printf "${CYAN}║${RESET}  Main     : %-42s${CYAN}║${RESET}\n" "$main_branch"
  _divider_end

  _confirm "Merge PR and clean up?" || { log_warn "Aborted."; exit 0; }

  if command -v gh > /dev/null 2>&1; then
    log_step "Merging PR via gh CLI (--${strategy} --delete-branch)..."
    (cd "$wt_path" && gh pr merge "--${strategy}" --delete-branch) && log_success "PR merged." || log_warn "gh pr merge failed."
  else
    log_warn "gh CLI not found. Merge the PR on GitHub first, then re-run cleanup."
    _confirm "Worktree already merged? Continue cleanup?" || exit 0
  fi

  log_step "Removing worktree $wt_path..."
  git worktree remove "$wt_path" --force && log_success "Worktree removed."

  log_step "Pulling latest $main_branch..."
  git checkout "$main_branch" && git pull origin "$main_branch"
  log_success "Back on $main_branch, fully up to date."

  echo ""
  log_success "Cleanup complete. Check log: $LOG_FILE"
}

# ── Main dispatch ─────────────────────────────────────────────────────────────
case "${1:-}" in
  create)   shift; cmd_create  "$@" ;;
  list)     shift; cmd_list    "$@" ;;
  remove)   shift; cmd_remove  "$@" ;;
  pr-flow)  shift; cmd_pr_flow "$@" ;;
  cleanup)  shift; cmd_cleanup "$@" ;;
  -h|--help|help|"") usage; exit 0 ;;
  *)
    log_error "Unknown command: $1"
    usage
    exit 1
    ;;
esac
