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
DIM='\033[2m'
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

# Run project-local verification checks (e.g. trunk.io, shucky) after a PR is
# opened, so their output is visible in the streamed log.
run_gwt_local_checks() {
  if command -v trunk >/dev/null 2>&1; then
    log_step "Running local checks: trunk check"
    trunk check 2>&1 || log_warn "trunk check reported issues"
  fi
  if command -v shucky >/dev/null 2>&1; then
    log_step "Running local checks: shucky"
    shucky 2>&1 || log_warn "shucky reported issues"
  fi
}

_divider() { echo -e "${CYAN}╔══════════════════════════════════════════════════════╗${RESET}"; }
_divider_end() { echo -e "${CYAN}╚══════════════════════════════════════════════════════╝${RESET}"; }

# Memoized response: the first y/n applies to ALL subsequent prompts
# in the session (answer-once behavior).
GWT_CONFIRM_CHOICE=""

_confirm() {
  local prompt="$1"
  if [[ "${GWT_AUTO_YES:-false}" == "true" ]]; then
    printf "${YELLOW}❓ ${prompt} [y/N] ${RESET}y (auto)\n"
    return 0
  fi
  # A response was already given in this session → reuse it
  if [[ -n "$GWT_CONFIRM_CHOICE" ]]; then
    printf "${YELLOW}❓ ${prompt} [y/N] ${RESET}${GWT_CONFIRM_CHOICE} (memo)\n"
    [[ "$GWT_CONFIRM_CHOICE" == "y" ]]
    return $?
  fi
  printf "${YELLOW}❓ ${prompt} [y/N/a] ${RESET}"
  local reply
  read -r reply
  case "$reply" in
    a|A)
      # 'a' = apply YES to all remaining prompts
      GWT_CONFIRM_CHOICE="y"
      printf "${CYAN}   ↳ 'a' = yes for all remaining prompts in this session${RESET}\n"
      return 0
      ;;
    y|Y)
      GWT_CONFIRM_CHOICE="y"
      return 0
      ;;
    *)
      GWT_CONFIRM_CHOICE="n"
      return 1
      ;;
  esac
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

# ── Worktree introspection helpers ───────────────────────────────────────────
# All of them take a repo/worktree path and work from any cwd.

# Root of the MAIN checkout (the one holding the real .git directory), resolved
# from the .git config: in a linked worktree `git rev-parse --git-common-dir`
# points to <main>/.git, so its dirname IS the main project root.
_wt_main_root() {
  local root="$1" common
  common=$(git -C "$root" rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)
  if [[ -z "$common" ]]; then
    # git < 2.31 has no --path-format=absolute → resolve manually
    common=$(git -C "$root" rev-parse --git-common-dir 2>/dev/null || true)
    [[ "$common" == /* ]] || common="$root/${common#./}"
  fi
  if [[ -n "$common" && "$(basename "$common")" == ".git" ]]; then
    dirname "$common"
    return 0
  fi
  # Fallback: first entry of `git worktree list` is always the main worktree
  git -C "$root" worktree list --porcelain 2>/dev/null | sed -n 's/^worktree //p' | head -n1
}

# A linked worktree has a .git FILE; the main checkout has a .git DIRECTORY.
_wt_is_linked() {
  [[ -f "$1/.git" ]]
}

# Count .env* files in a root (depth 1 = root only, 4 = monorepo deep).
_wt_env_count() {
  local root="$1" depth="${2:-1}"
  find "$root" -maxdepth "$depth" -name '.env*' \
    -not -path '*/node_modules/*' 2>/dev/null | wc -l | tr -d ' '
}

# One TSV row per worktree: path ⇥ branch ⇥ kind ⇥ env_count ⇥ dirty
_wt_row() {
  local path="$1" branch="${2:--}" kind envs dirty
  if [[ -d "$path/.git" ]]; then kind="main"; else kind="worktree"; fi
  envs=$(_wt_env_count "$path")
  if [[ -n "$(git -C "$path" status --porcelain 2>/dev/null)" ]]; then dirty="dirty"; else dirty="clean"; fi
  printf '%s\t%s\t%s\t%s\t%s\n' "$path" "$branch" "$kind" "$envs" "$dirty"
}

_wt_rows() {
  local root="$1" line path="" branch="" out=""
  while IFS= read -r line; do
    case "$line" in
      worktree\ *) path="${line#worktree }" ;;
      branch\ *)   branch="${line#branch }"; branch="${branch#refs/heads/}" ;;
      detached)   branch="(detached)" ;;
      bare)       branch="(bare)" ;;
      "")
        if [[ -n "$path" ]]; then out+="$(_wt_row "$path" "$branch")"$'\n'; path=""; branch=""; fi
        ;;
    esac
  done < <(git -C "$root" worktree list --porcelain 2>/dev/null)
  [[ -n "$path" ]] && out+="$(_wt_row "$path" "$branch")"$'\n'
  printf '%s' "$out"
  return 0
}

# Resolve a user token (absolute/relative path OR branch name) to a worktree path.
_wt_resolve() {
  local root="$1" token="$2" path branch
  [[ -n "$token" ]] || return 1
  if [[ -d "$token" ]]; then (cd "$token" 2>/dev/null && pwd -P); return 0; fi
  while IFS=$'\t' read -r path branch _; do
    if [[ "$branch" == "$token" ]]; then printf '%s\n' "$path"; return 0; fi
  done < <(_wt_rows "$root")
  return 1
}

# fzf picker over the worktree list (same shape as `brs` and the herdr gwt
# manager). Multi-select by default; $3=true forces a single choice.
# Echoes the selected paths, one per line. Returns 1 if cancelled.
_pick_worktrees() {
  local root="$1" prompt="$2" single="${3:-false}" rows selection header
  rows=$(_wt_rows "$root")
  if [[ -z "$rows" ]]; then
    log_error "No worktree found from $root"
    return 1
  fi
  if ! command -v fzf >/dev/null 2>&1; then
    _pick_worktrees_fallback "$rows" "$single"
    return $?
  fi
  header='TAB = multi-select │ ENTER = validate │ ESC = cancel'
  [[ "$single" == "true" ]] && header='single choice │ ENTER = validate │ ESC = cancel'
  local -a fzf_args=(
    --reverse --height=100% --delimiter=$'\t' --with-nth=2,3,4,5
    --prompt="$prompt " --header="$header"
    --preview='ls -1 {1}/.env* 2>/dev/null | head -20; echo "── git ──"; git -C {1} status --short --branch 2>/dev/null | head -15'
    --preview-window=right:40%:wrap
  )
  [[ "$single" == "true" ]] || fzf_args+=(--multi)
  if selection=$(printf '%s\n' "$rows" | fzf "${fzf_args[@]}"); then
    :
  else
    log_warn "Selection cancelled (fzf)."
    return 1
  fi
  [[ -n "$selection" ]] || { log_warn "Nothing selected."; return 1; }
  if [[ "$single" == "true" ]]; then
    selection=$(printf '%s\n' "$selection" | head -n1)
  fi
  printf '%s\n' "$selection" | cut -f1
  return 0
}

# No-fzf fallback: numbered list + read.
_pick_worktrees_fallback() {
  local rows="$1" single="$2" i=0 n answer line
  echo -e "${YELLOW}⚠️  fzf not found — numbered selection:${RESET}"
  while IFS=$'\t' read -r line; do
    i=$((i + 1))
    printf '  %2d) %s\n' "$i" "$(printf '%s' "$line" | tr '\t' ' ')"
  done <<< "$rows"
  read -rp "  number${single:+ (single)} [1-${i}, 0=cancel]: " answer
  [[ "$answer" =~ ^[0-9]+$ ]] || { log_warn "Invalid selection: '$answer'"; return 1; }
  [[ "$answer" -ge 1 && "$answer" -le "$i" ]] || { log_warn "Out of range: '$answer' (1-${i})"; return 1; }
  sed -n "${answer}p" <<< "$rows" | cut -f1
  return 0
}

# Optional second picker: choose WHICH .env files to copy (fzf multi-select).
_pick_env_files() {
  local src="$1" depth="$2" list_file choice f
  list_file=$(mktemp)
  while IFS= read -r -d '' f; do
    printf '%s\t%s\n' "${f#$src/}" "$(du -h "$f" 2>/dev/null | cut -f1)" >> "$list_file"
  done < <(find "$src" -maxdepth "$depth" -name '.env*' -not -path '*/node_modules/*' -print0 2>/dev/null)
  if [[ ! -s "$list_file" ]]; then rm -f "$list_file"; log_warn "No .env* file found in $src"; return 1; fi
  if ! command -v fzf >/dev/null 2>&1; then
    log_warn "fzf not found — copying every .env* file."
    cat "$list_file"
    rm -f "$list_file"
    return 0
  fi
  if choice=$(fzf --multi --reverse --height=60% --delimiter=$'\t' --with-nth=1,2 \
      --prompt='🔑 .env files > ' --header='TAB = multi-select │ ENTER = validate │ ESC = cancel' \
      --preview='head -c 400 {1} 2>/dev/null' \
      < "$list_file"); then
    :
  else
    rm -f "$list_file"
    log_warn "Selection cancelled (fzf)."
    return 1
  fi
  rm -f "$list_file"
  [[ -n "$choice" ]] || { log_warn "No .env file selected."; return 1; }
  printf '%s\n' "$choice" | cut -f1
  return 0
}

# ── Core: copy .env* files from one root to another ───────────────────────────
# Sets COPY_COUNT / COPY_SKIPPED / COPY_FAILED. Shared by `create` and `env`.
#   $1 src_root  $2 dest_root  $3 maxdepth (1=root only, 4=monorepo deep)
#   $4 force (overwrite existing)  $5 dry_run
#   extra args  = explicit list of relative files to copy
_copy_env_files() {
  local src="$1" dst="$2" depth="${3:-1}" force="${4:-false}" dry="${5:-false}"
  shift 5 2>/dev/null || shift $#
  local -a wanted=("$@") files=()
  local env_file rel target
  COPY_COUNT=0; COPY_SKIPPED=0; COPY_FAILED=0

  if [[ "${#wanted[@]}" -gt 0 ]]; then
    for rel in "${wanted[@]}"; do files+=("$src/$rel"); done
  else
    while IFS= read -r -d '' env_file; do files+=("$env_file"); done < <(
      find "$src" -maxdepth "$depth" -name '.env*' \
        -not -path '*/node_modules/*' -not -path '*/.git/*' -print0 2>/dev/null
    )
  fi

  if [[ "${#files[@]}" -eq 0 ]]; then
    log_warn "No .env* file found in $src (maxdepth $depth)."
    return 0
  fi

  for env_file in "${files[@]}"; do
    [[ -f "$env_file" ]] || { log_warn "Missing source file: $env_file"; COPY_FAILED=$((COPY_FAILED + 1)); continue; }
    rel="${env_file#$src/}"
    target="$dst/$rel"
    if [[ -e "$target" && "$force" != "true" ]]; then
      log_info "Skipped (already exists): $rel"
      COPY_SKIPPED=$((COPY_SKIPPED + 1))
      continue
    fi
    if [[ "$dry" == "true" ]]; then
      log_info "[dry-run] would copy: $rel"
      COPY_COUNT=$((COPY_COUNT + 1))
      continue
    fi
    if mkdir -p "$(dirname "$target")" && cp -d "$env_file" "$target" 2>/dev/null; then
      log_info "Copied: $rel"
      COPY_COUNT=$((COPY_COUNT + 1))
    else
      log_error "Failed to copy: $rel"
      COPY_FAILED=$((COPY_FAILED + 1))
    fi
  done
  return 0
}

# ── Tutorial / help shown when the user mistypes ──────────────────────────────
# Closest match among the env actions, using edit distance. Echoes nothing when
# the token is too far from every action (then it is probably a branch name).
#
# Score = distance relative to the action length + a penalty when the input and
# the action differ in length. Both matter: plain distance alone ties "to" with
# "list" for "tp", and length alone ties "to" with "from" for "fro".
_env_suggest_action() {
  local input="$1" action best="" best_score=999 best_dist=99
  local -a actions=("to" "from" "sync" "list" "auto")
  [[ -n "$input" ]] || return 0
  for action in "${actions[@]}"; do
    local dist len diff score
    dist=$(_env_edit_distance "$input" "$action")
    len=${#action}
    diff=${#input}
    (( diff > len )) && diff=$(( diff - len )) || diff=$(( len - diff ))
    score=$(( dist * 100 / len + diff * 30 ))
    # Strictly-less keeps the first action on ties; the list is ordered by
    # usefulness so the most common typo wins.
    if (( score < best_score )); then
      best_dist="$dist"; best_score="$score"; best="$action"
    fi
  done
  # Require a single edit on a meaningful word, else stay silent.
  if [[ "$best_dist" -le 1 ]]; then
    printf '%s\n' "$best"
  fi
  return 0
}

# Levenshtein distance, pure bash (short strings only).
# NOTE: indexed arrays (-a), NOT associative (-A): a subscript like prev[i]
# would be taken as the literal string "i" in an associative array.
_env_edit_distance() {
  local a="$1" b="$2" i j la lb ca cb cost del ins sub min
  la=${#a}; lb=${#b}
  local -a prev curr
  for ((i = 0; i <= la; i++)); do prev[i]=$i; done
  for ((j = 0; j <= lb; j++)); do curr[j]=$j; done
  for ((i = 1; i <= la; i++)); do
    ca="${a:i-1:1}"
    for ((j = 1; j <= lb; j++)); do
      cb="${b:j-1:1}"
      cost=1
      [[ "$ca" == "$cb" ]] && cost=0
      del=$(( prev[j] + 1 ))
      ins=$(( curr[j-1] + 1 ))
      sub=$(( prev[j-1] + cost ))
      min=$del
      [[ $ins -lt $min ]] && min=$ins
      [[ $sub -lt $min ]] && min=$sub
      curr[j]=$min
    done
    for ((j = 0; j <= lb; j++)); do prev[j]=${curr[j]}; done
  done
  printf '%s\n' "${prev[lb]}"
}

_env_tutorial() {
  local reason="${1:-}"
  echo ""
  log_error "Wrong usage${reason:+: $reason}"
  echo -e "${YELLOW}💡 Tutorial: How to copy .env files across worktrees?${RESET}"
  echo ""
  echo -e "  ${BOLD}1. Auto-detect (most common)${RESET}"
  echo -e "     ${CYAN}gwt-env${RESET}"
  echo -e "     • inside a worktree  → copies ${BOLD}main → this worktree${RESET}"
  echo -e "     • inside the main    → opens ${BOLD}fzf${RESET} to pick the target worktree(s)"
  echo ""
  echo -e "  ${BOLD}2. main → worktree(s)${RESET}"
  echo -e "     ${CYAN}gwt-env-up${RESET}                       ${DIM}# fzf picker${RESET}"
  echo -e "     ${CYAN}gwt-env-up feature/auth ../wt-auth${RESET}   ${DIM}# by branch or path${RESET}"
  echo ""
  echo -e "  ${BOLD}3. worktree → current terminal root${RESET}"
  echo -e "     ${CYAN}gwt-env-down feature/auth${RESET}          ${DIM}# → \$PWD${RESET}"
  echo ""
  echo -e "  ${BOLD}4. worktree ↔ worktree${RESET}"
  echo -e "     ${CYAN}gwt-env-sync feature/auth ../wt-auth${RESET}"
  echo ""
  echo -e "  ${BOLD}5. Inspect without copying${RESET}"
  echo -e "     ${CYAN}gwt-env-list${RESET}                    ${DIM}# worktrees + .env* count${RESET}"
  echo ""
  echo -e "  ${CYAN}Options:${RESET}"
  echo -e "    -i, --interactive     fzf to pick WHICH .env files to copy"
  echo -e "    -s, --single          force a single worktree instead of multi-select"
  echo -e "    -f, --force           overwrite existing .env files (default: skip)"
  echo -e "    -n, --dry-run         show what would be copied, write nothing"
  echo -e "        --deep            search sub-packages too (maxdepth 4)"
  echo -e "        --root-only       only root .env* files (default)"
  echo -e "    -y, --yes             skip confirmations"
  echo ""
  echo -e "  ${CYAN}Examples:${RESET}"
  echo -e "    gwt-env                            # main → current worktree"
  echo -e "    gwt-env-up                         # main → fzf-picked worktrees"
  echo -e "    gwt-env-up -i --single             # pick 1 worktree, then 1 .env file"
  echo -e "    gwt-env-down feature/auth          # that worktree → here"
  echo -e "    gwt-env sync feature/auth ../wt-x  # worktree → worktree"
  echo -e "    gwt-env -n --deep                  # dry-run, monorepo-wide"
  echo ""
  echo -e "  ${DIM}Full help: gwt-env --help${RESET}"
  echo ""
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
  echo -e "  ${GREEN}env${RESET}     [to|from|sync|list]      Copy .env* across worktrees (fzf picker)"
  echo ""
  echo -e "  ${CYAN}Options:${RESET}"
  echo -e "    -y, --yes             Skip all confirmation prompts (auto-yes)"
  echo -e "    Answer 'a' at any prompt = yes to ALL remaining prompts of this run"
  echo -e "    GWT_LOG_FILE=<path>   Custom log file (default: ~/.cache/git-worktree-auto.log)"
  echo ""
  echo -e "  ${CYAN}Examples:${RESET}"
  echo -e "    $0 create ../myapp-feature-auth feature/auth main"
  echo -e "    $0 pr-flow ../myapp-feature-auth \"feat(auth): add login guard\""
  echo -e "    $0 cleanup ../myapp-feature-auth squash"
  echo -e "    $0 env                              # main → current worktree"
  echo -e "    $0 env list                         # worktrees + .env* count"
  echo -e "    $0 env --help                       # full .env tutorial"
  echo ""
}

# ── CMD: create ───────────────────────────────────────────────────────────────
cmd_create() {
  local wt_path="${1:-}" branch="${2:-}" base="${3:-}"
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

  if [[ -z "$base" ]]; then
    if git show-ref --verify --quiet refs/heads/main; then base="main"
    elif git show-ref --verify --quiet refs/heads/master; then base="master"
    else base=$(git config --get init.defaultBranch || echo "main"); fi
  fi

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
  git checkout "$base" 2>/dev/null || log_warn "Base branch '$base' not checked out properly."
  git pull origin "$base" 2>/dev/null || log_warn "Could not pull from origin (offline or no remote). Continuing..."

  # Step 2: Create worktree
  log_step "Creating worktree at $wt_path on branch $branch..."
  if git show-ref --verify --quiet "refs/heads/$branch"; then
    log_warn "Branch '$branch' already exists. Using existing branch."
    git worktree add "$wt_path" "$branch"
  else
    git worktree add "$wt_path" -b "$branch" "$base"
  fi
  log_success "Worktree created."

  # Step 3: Copy .env files (shared core with `env`)
  log_step "Copying .env files..."
  _copy_env_files "$src_root" "$wt_path" 4 "false" "false"
  log_success "$COPY_COUNT .env file(s) copied."

  # Step 4: pnpm install
  if [[ -f "$wt_path/package.json" ]]; then
    _confirm "Run pnpm install in $wt_path?" && {
      log_step "Running pnpm install..."
      (cd "$wt_path" && pnpm install --frozen-lockfile) && log_success "pnpm install complete." || log_warn "pnpm install had issues."
    }
  fi

  log_success "Worktree ready → cd $wt_path"

  if _confirm "cd into $wt_path now? (Will start a nested shell)"; then
    cd "$wt_path" || exit 1
    log_info "Type 'exit' when done to return to your previous directory."
    exec "${SHELL:-zsh}"
  fi
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

# ── CMD: env ──────────────────────────────────────────────────────────────────
# Resolve the source root, then the destination root(s), then copy.
_env_header() {
  local src="$1" depth="$2" dry="$3" force="$4"
  shift 4
  local i=0 t
  _divider
  echo -e "${CYAN}║  🔐 Git Worktree — Copy .env files                  ║${RESET}"
  echo -e "${CYAN}╠══════════════════════════════════════════════════════╣${RESET}"
  printf "${CYAN}║${RESET}  From   : %-43s${CYAN}║${RESET}\n" "$src"
  printf "${CYAN}║${RESET}  Scope  : %-43s${CYAN}║${RESET}\n" "$([[ $depth -le 1 ]] && echo 'root .env* only' || echo "maxdepth $depth")"
  printf "${CYAN}║${RESET}  Mode   : %-43s${CYAN}║${RESET}\n" "$([[ $dry == true ]] && echo 'dry-run (no write)' || ([[ $force == true ]] && echo 'force (overwrite)' || echo 'safe (skip existing)'))"
  echo -e "${CYAN}╠══════════════════════════════════════════════════════╣${RESET}"
  echo -e "${CYAN}║${RESET}  ${BOLD}To${RESET}:"
  for t in "$@"; do
    i=$((i + 1))
    printf "${CYAN}║${RESET}    %d. %-41s${CYAN}║${RESET}\n" "$i" "$t"
  done
  _divider_end
}

# $1 src_root  $2 depth  $3 dry  $4 force  $@ destination roots
_env_copy_all() {
  local src="$1" depth="$2" dry="$3" force="$4"
  shift 4
  local -a dests=("$@") files=()
  local d f total_c=0 total_s=0 total_f=0

  if [[ "$ENV_INTERACTIVE" == "true" ]]; then
    while IFS= read -r f; do [[ -n "$f" ]] && files+=("$f"); done < <(_pick_env_files "$src" "$depth" || true)
    if [[ "${#files[@]}" -eq 0 ]]; then
      log_warn "No .env file selected — nothing copied."
      return 0
    fi
  fi

  for d in "${dests[@]}"; do
    log_step "Copying .env* → $d"
    _copy_env_files "$src" "$d" "$depth" "$force" "$dry" "${files[@]}"
    total_c=$((total_c + COPY_COUNT))
    total_s=$((total_s + COPY_SKIPPED))
    total_f=$((total_f + COPY_FAILED))
  done

  echo ""
  if [[ "$dry" == "true" ]]; then
    log_success "[dry-run] $total_c file(s) would be copied to ${#dests[@]} destination(s)."
  else
    log_success "$total_c file(s) copied to ${#dests[@]} destination(s)."
  fi
  [[ "$total_s" -gt 0 ]] && log_info "$total_s already existed (skipped — use --force to overwrite)."
  [[ "$total_f" -gt 0 ]] && log_error "$total_f file(s) failed."
  [[ "$total_f" -gt 0 ]] && return 1
  return 0
}

cmd_env() {
  local action="auto"
  local depth=1 force="false" dry="false"
  ENV_INTERACTIVE="false"; ENV_SINGLE="false"
  local -a rest=()

  local arg
  for arg in "$@"; do
    case "$arg" in
      -i|--interactive) ENV_INTERACTIVE="true" ;;
      -s|--single)      ENV_SINGLE="true" ;;
      -f|--force)       force="true" ;;
      -n|--dry-run)     dry="true" ;;
      --deep)           depth=4 ;;
      --root-only)      depth=1 ;;
      -h|--help)        _env_tutorial ""; return 0 ;;
      -*)               _env_tutorial "unknown option '$arg'"; return 1 ;;
      *)                rest+=("$arg") ;;
    esac
  done

  local cur_root main_root
  cur_root=$(git rev-parse --show-toplevel 2>/dev/null) || cur_root=""
  if [[ -z "$cur_root" ]]; then
    log_error "Not inside a git repository."
    _env_tutorial "no git repository in \$PWD"
    return 1
  fi
  main_root=$(_wt_main_root "$cur_root")
  if [[ -z "$main_root" || ! -d "$main_root" ]]; then
    log_error "Could not resolve the main checkout root from $cur_root"
    return 1
  fi

  if [[ "${#rest[@]}" -gt 0 ]]; then
    case "${rest[0]}" in
      auto|to|from|sync|list) action="${rest[0]}"; rest=("${rest[@]:1}") ;;
      *)
        # A real worktree/branch name must stay a target, never become a
        # "did you mean" warning. Only unknown tokens get a suggestion.
        local suggest="" resolved_path
        if ! resolved_path=$(_wt_resolve "$cur_root" "${rest[0]}"); then
          suggest=$(_env_suggest_action "${rest[0]}")
        fi
        if [[ -n "$suggest" ]]; then
          _env_tutorial "unknown action '${rest[0]}' — did you mean '$suggest'?"
          return 1
        fi
        action="auto"   # bare target(s) → treated as main → target(s)
        ;;
    esac
  fi

  if [[ "$action" == "list" ]]; then
    log_step "Worktrees and their .env* files:"
    echo ""
    printf "${CYAN}  %-46s %-24s %-10s %5s %6s${RESET}\n" "PATH" "BRANCH" "KIND" "ENV" "STATE"
    local line p b k e s
    while IFS=$'\t' read -r p b k e s; do
      [[ -n "$p" ]] || continue
      printf "  %-46s %-24s %-10s %5s %6s\n" "$p" "$b" "$k" "$e" "$s"
    done < <(_wt_rows "$cur_root")
    echo ""
    log_info "Main checkout: $main_root"
    echo ""
    return 0
  fi

  local -a dests=() srcs=()
  local t r resolved picked

  case "$action" in
    auto|to)
      if [[ "$action" == "auto" && "${#rest[@]}" -eq 0 && "$cur_root" != "$main_root" ]]; then
        dests=("$cur_root")
        log_info "Linked worktree detected → main → current worktree."
      elif [[ "${#rest[@]}" -gt 0 ]]; then
        for t in "${rest[@]}"; do
          if resolved=$(_wt_resolve "$cur_root" "$t"); then dests+=("$resolved")
          else log_error "Unknown worktree: '$t'"; _env_tutorial "no worktree or branch named '$t'"; return 1; fi
        done
      else
        if ! picked=$(_pick_worktrees "$cur_root" "🌿 target worktree" "$ENV_SINGLE"); then
          log_warn "Aborted by user."; return 0
        fi
        while IFS= read -r t; do
          [[ -n "$t" ]] || continue
          if [[ "$t" == "$main_root" ]]; then
            log_warn "Main checkout skipped as a destination."
          else
            dests+=("$t")
          fi
        done <<< "$picked"
      fi
      [[ "${#dests[@]}" -eq 0 ]] && { log_warn "No destination worktree."; return 0; }
      _env_header "$main_root" "$depth" "$dry" "$force" "${dests[@]}"
      _confirm "Copy .env* from main to ${#dests[@]} worktree(s)?" || { log_warn "Aborted by user."; return 0; }
      _env_copy_all "$main_root" "$depth" "$dry" "$force" "${dests[@]}"
      ;;

    from)
      if [[ "${#rest[@]}" -gt 0 ]]; then
        for t in "${rest[@]}"; do
          if resolved=$(_wt_resolve "$cur_root" "$t"); then srcs+=("$resolved")
          else log_error "Unknown worktree: '$t'"; _env_tutorial "no worktree or branch named '$t'"; return 1; fi
        done
      else
        if ! picked=$(_pick_worktrees "$cur_root" "🌿 source worktree" "$ENV_SINGLE"); then
          log_warn "Aborted by user."; return 0
        fi
        while IFS= read -r t; do [[ -n "$t" ]] && srcs+=("$t"); done <<< "$picked"
      fi
      [[ "${#srcs[@]}" -eq 0 ]] && { log_warn "No source worktree."; return 0; }
      local s
      for s in "${srcs[@]}"; do
        [[ "$s" == "$cur_root" ]] && { log_warn "Source is the current root — nothing to do."; continue; }
        _env_header "$s" "$depth" "$dry" "$force" "$cur_root"
        _confirm "Copy .env* from $s → $cur_root?" || { log_warn "Aborted by user."; continue; }
        _env_copy_all "$s" "$depth" "$dry" "$force" "$cur_root"
      done
      ;;

    sync)
      if [[ "${#rest[@]}" -gt 0 ]]; then
        t="${rest[0]}"
        if resolved=$(_wt_resolve "$cur_root" "$t"); then srcs+=("$resolved")
        else log_error "Unknown worktree: '$t'"; _env_tutorial "no worktree or branch named '$t'"; return 1; fi
        rest=("${rest[@]:1}")
      else
        if ! picked=$(_pick_worktrees "$cur_root" "🌿 source worktree" "$ENV_SINGLE"); then
          log_warn "Aborted by user."; return 0
        fi
        while IFS= read -r r; do [[ -n "$r" ]] && srcs+=("$r"); done <<< "$picked"
      fi
      if [[ "${#rest[@]}" -gt 0 ]]; then
        for t in "${rest[@]}"; do
          if resolved=$(_wt_resolve "$cur_root" "$t"); then dests+=("$resolved")
          else log_error "Unknown worktree: '$t'"; _env_tutorial "no worktree or branch named '$t'"; return 1; fi
        done
      else
        if ! picked=$(_pick_worktrees "$cur_root" "🌿 destination worktree" "$ENV_SINGLE"); then
          log_warn "Aborted by user."; return 0
        fi
        while IFS= read -r t; do [[ -n "$t" ]] && dests+=("$t"); done <<< "$picked"
      fi
      [[ "${#srcs[@]}" -eq 0 || "${#dests[@]}" -eq 0 ]] && { log_warn "Source or destination missing."; return 0; }
      local s
      for s in "${srcs[@]}"; do
        [[ "$s" == "${dests[0]}" ]] && { log_warn "Source and destination are the same — skipped."; continue; }
        _env_header "$s" "$depth" "$dry" "$force" "${dests[@]}"
        _confirm "Copy .env* from $s → ${#dests[@]} destination(s)?" || { log_warn "Aborted by user."; continue; }
        _env_copy_all "$s" "$depth" "$dry" "$force" "${dests[@]}"
      done
      ;;
  esac
  return 0
}

# ── CMD: remove ──────────────────────────────────────────────────────────────
cmd_remove() {
  local wt_path="${1:-}"
  if [[ -z "$wt_path" ]]; then
    log_error "Usage: $0 remove <path_or_branch>"
    exit 1
  fi
  _require_git_root > /dev/null

  # Resolve branch name to path if it's not a directory
  if [[ ! -d "$wt_path" ]]; then
    local branch_path
    branch_path=$(git worktree list --porcelain | awk -v br="refs/heads/$wt_path" '
      /^worktree/ { wt=$2 }
      /^branch/ { if ($2 == br) print wt }
    ')
    if [[ -n "$branch_path" ]]; then
      log_info "Resolved branch '$wt_path' to worktree path: $branch_path"
      wt_path="$branch_path"
    fi
  fi

  local wt_branch
  wt_branch=$(git -C "$wt_path" rev-parse --abbrev-ref HEAD 2>/dev/null || true)

  log_warn "This will remove worktree: $wt_path"
  _confirm "Confirm removal?" || { log_warn "Aborted."; exit 0; }

  log_step "Removing worktree $wt_path..."
  git worktree remove "$wt_path" --force && log_success "Worktree removed." || { log_error "Failed to remove worktree."; exit 1; }

  if [[ -n "$wt_branch" && "$wt_branch" != "main" && "$wt_branch" != "master" ]]; then
    log_step "Deleting associated branch '$wt_branch'..."
    git branch -D "$wt_branch" && log_success "Branch $wt_branch deleted." || log_warn "Failed to delete branch."
  fi
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

    run_gwt_local_checks
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

GWT_AUTO_YES=false
new_args=()
for arg in "$@"; do
  if [[ "$arg" == "-y" || "$arg" == "--yes" ]]; then
    GWT_AUTO_YES=true
  else
    new_args+=("$arg")
  fi
done
set -- "${new_args[@]}"

case "${1:-}" in
  create)   shift; cmd_create  "$@" ;;
  list)     shift; cmd_list    "$@" ;;
  remove)   shift; cmd_remove  "$@" ;;
  pr-flow)  shift; cmd_pr_flow "$@" ;;
  cleanup)  shift; cmd_cleanup "$@" ;;
  env)      shift; cmd_env     "$@" ;;
  -h|--help|help|"") usage; exit 0 ;;
  *)
    log_error "Unknown command: $1"
    usage
    exit 1
    ;;
esac
