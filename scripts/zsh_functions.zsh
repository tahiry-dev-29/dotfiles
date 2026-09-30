# ==============================================================================
# ZSH COMPLEX FUNCTIONS
# ==============================================================================
# OS Agnostic System Functions
sys-update() {
  echo "🔄 System Update..."
  if command -v apt-get >/dev/null 2>&1 && ! grep -qi microsoft /proc/version 2>/dev/null; then
    sudo apt update
  elif command -v pacman >/dev/null 2>&1; then
    sudo pacman -Sy
  elif command -v brew >/dev/null 2>&1; then
    brew update
  elif grep -qi microsoft /proc/version 2>/dev/null; then
    echo "🪟 Windows WSL detected. Running apt update..."
    sudo apt update
  else
    echo "❌ Package manager not supported."
  fi
}

sys-upgrade() {
  echo "🚀 System Upgrade..."
  if command -v apt-get >/dev/null 2>&1 && ! grep -qi microsoft /proc/version 2>/dev/null; then
    sudo apt upgrade -y
    if [[ "$1" == "--all" ]]; then flatpak update -y 2>/dev/null || true; fi
  elif command -v pacman >/dev/null 2>&1; then
    sudo pacman -Su --noconfirm
  elif command -v brew >/dev/null 2>&1; then
    brew upgrade
  elif grep -qi microsoft /proc/version 2>/dev/null; then
    echo "🪟 Windows WSL detected. Running apt upgrade..."
    sudo apt upgrade -y
  else
    echo "❌ Package manager not supported."
  fi
}

sys-clean() {
  echo "🧹 System Clean..."
  if command -v apt-get >/dev/null 2>&1 && ! grep -qi microsoft /proc/version 2>/dev/null; then
    sudo apt autoremove -y && sudo apt clean && sudo journalctl --vacuum-time=3d 2>/dev/null || true
  elif command -v pacman >/dev/null 2>&1; then
    sudo pacman -Sc --noconfirm
  elif command -v brew >/dev/null 2>&1; then
    brew cleanup
  elif grep -qi microsoft /proc/version 2>/dev/null; then
    echo "🪟 Windows WSL detected. Running apt autoremove and clean..."
    sudo apt autoremove -y && sudo apt clean
  else
    echo "❌ Package manager not supported."
  fi
}


unalias ports 2>/dev/null
function ports() {
  echo "📡 Open Ports:"
  echo "╔══════╦═══════╦══════════════════════════╦═════════════════════╗"
  printf "║ %-4s ║ %-5s ║ %-24s ║ %-19s ║\n" "Port" "Proto" "Program" "Local Address"
  echo "╠══════╬═══════╬══════════════════════════╬═════════════════════╣"
  local _p_port _p_prog
  netstat -tulnp 2>/dev/null | awk 'NR>2 {print $1, $4, $7}' | while read -r proto addr prog_info; do
    _p_port="${addr##*:}"
    _p_prog="${prog_info#*/}"
    if [[ "$_p_prog" == "-" || -z "$_p_prog" ]]; then _p_prog="N/A (needs sudo)"; fi
    if [[ "$_p_port" != "" && "$_p_port" =~ ^[0-9]+$ ]]; then
      printf "║ %-4s ║ %-5s ║ %-24s ║ %-19s ║\n" "$_p_port" "$proto" "${_p_prog:0:24}" "${addr:0:19}"
    fi
  done
  echo "╚══════╩═══════╩══════════════════════════╩═════════════════════╝"
}

unalias dev-status 2>/dev/null
function dev-status() {
  echo ""
  echo "╔════════════════════════════════════════╗"
  echo "║         Dev Stack Status               ║"
  echo "╠═════════════╦══════════╦══════════════╣"
  printf "║ %-11s ║ %-8s ║ %-12s ║\n" "Service" "Status" "Port"
  echo "╠═════════════╬══════════╬══════════════╣"
  _svc_row() {
    local name="$1" unit="$2" port="$3"
    local svc_status
    if systemctl is-active --quiet "$unit" 2>/dev/null; then
      svc_status="✅ active"
    else
      svc_status="❌ stopped"
    fi
    printf "║ %-11s ║ %-8s ║ %-12s ║\n" "$name" "$svc_status" "$port"
  }
  _svc_row "PostgreSQL" "postgresql" "5432"
  _svc_row "MySQL" "mysql" "3306"
  _svc_row "MongoDB" "mongod" "27017"
  _svc_row "Docker" "docker" "daemon"
  _svc_row "Redis" "redis-server" "6379"
  echo "╠═════════════╩══════════╩══════════════╣"
  echo "║    Active Ports (dev range)           ║"
  echo "╠═══════════════════════════════════════╣"
  local _ds_pid _ds_prog
  for port in 3000 4200 8080 5173 3001; do
    _ds_pid=$(fuser "$port/tcp" 2>/dev/null | awk '{print $1}')
    if [[ -n "$_ds_pid" ]]; then
      _ds_prog=$(ps -p "$_ds_pid" -o comm= 2>/dev/null | head -n 1)
      if [[ -z "$_ds_prog" ]]; then _ds_prog="?"; fi
      printf "║  ✅ %-5s → PID %-6s %-15s ║\n" ":$port" "$_ds_pid" "($_ds_prog)"
    fi
  done
  echo "╚═══════════════════════════════════════╝"
  echo ""
}

# 📋 CLIPBOARD HISTORY (Wayland — wl-clipboard)
CLIP_HISTORY_FILE="$HOME/.cache/clipboard_history.log"
CLIP_HISTORY_MAX=5000

function clip-save() {
  local content
  content=$(wl-paste 2>/dev/null)
  if [[ -n "$content" ]]; then
    mkdir -p "$(dirname "$CLIP_HISTORY_FILE")"
    local ts
    ts=$(date +"%Y-%m-%d %H:%M:%S")
    printf "[%s] %s\n" "$ts" "$content" >> "$CLIP_HISTORY_FILE"
    if [[ -f "$CLIP_HISTORY_FILE" ]]; then
      tail -n "$CLIP_HISTORY_MAX" "$CLIP_HISTORY_FILE" > "${CLIP_HISTORY_FILE}.tmp" && mv "${CLIP_HISTORY_FILE}.tmp" "$CLIP_HISTORY_FILE"
    fi
    echo "📋 Saved to clipboard history."
  else
    echo "❌ Clipboard is empty."
  fi
}

function clip-list() {
  local count="${1:-20}"
  if [[ ! -f "$CLIP_HISTORY_FILE" ]]; then
    echo "❌ No clipboard history found."
    return 1
  fi
  echo "📋 Clipboard History (last $count):"
  echo "╔══════════════════════════════════════════════════════════════╗"
  tail -n "$count" "$CLIP_HISTORY_FILE" | nl -ba | while IFS= read -r line; do
    printf "║  %-60s║\n" "${line:0:60}"
  done
  echo "╚══════════════════════════════════════════════════════════════╝"
}

function clip-search() {
  if [[ ! -f "$CLIP_HISTORY_FILE" ]]; then
    echo "❌ No clipboard history found."
    return 1
  fi
  if ! command -v fzf >/dev/null 2>&1; then
    echo "❌ fzf is required for clip-search."
    return 1
  fi
  local selected
  selected=$(cat "$CLIP_HISTORY_FILE" | sed 's/^\[[^]]*\] //' | fzf --prompt='📋 Clip: ' --height=50% --reverse --tac)
  if [[ -n "$selected" ]]; then
    echo -n "$selected" | wl-copy
    echo "✅ Copied back to clipboard: ${selected:0:50}..."
  fi
}

function clip-file() {
  if [[ -z "$1" || ! -f "$1" ]]; then
    echo "❌ Usage: clip-file <file>"
    return 1
  fi
  wl-copy < "$1"
  echo "📋 File '$1' copied to clipboard."
}

function clip-watch() {
  if pgrep -f "wl-paste --watch" >/dev/null 2>&1 || pgrep -f "clip-watch-polling" >/dev/null 2>&1; then
    echo "✅ Clipboard watcher is already running."
    return 0
  fi
  mkdir -p "$(dirname "$CLIP_HISTORY_FILE")"
  
  if echo "$XDG_CURRENT_DESKTOP" | grep -iq "GNOME"; then
    # GNOME Wayland doesn't support wlroots data-control needed for wl-paste --watch
    # Using a lightweight polling fallback
    (
      exec -a clip-watch-polling bash -c '
        LAST_CLIP=""
        while true; do
          # Only capture plain text to avoid saving images or binary data
          CURRENT_CLIP=$(wl-paste --type text/plain 2>/dev/null)
          if [[ "$CURRENT_CLIP" != "$LAST_CLIP" && -n "$CURRENT_CLIP" ]]; then
            # Replace newlines with spaces to keep history flat (one line per entry)
            FLAT_CLIP=$(echo "$CURRENT_CLIP" | tr "\n" " ")
            printf "[%s] %s\n" "$(date +"%Y-%m-%d %H:%M:%S")" "$FLAT_CLIP" >> '"$CLIP_HISTORY_FILE"'
            LAST_CLIP="$CURRENT_CLIP"
          fi
          sleep 1
        done
      '
    ) &!
    echo "👁️  Clipboard watcher started in background (GNOME mode)."
  else
    wl-paste --type text/plain --watch bash -c '
      CURRENT_CLIP=$(wl-paste --type text/plain 2>/dev/null)
      FLAT_CLIP=$(echo "$CURRENT_CLIP" | tr "\n" " ")
      printf "[%s] %s\n" "$(date +"%Y-%m-%d %H:%M:%S")" "$FLAT_CLIP" >> '"$CLIP_HISTORY_FILE"'
    ' &!
    echo "👁️  Clipboard watcher started in background."
  fi
}

# Code size audit
count-code() {
  local ext=${1:-ts}
  local limit=${2:-200}
  local show_warnings=${3:-}
  local ignore="node_modules|dist|prisma|.prisma|.next|.angular|.nx|.git|.dart_tool|build|seeds|out|.firebase|coverage|.cache"
  local total=0
  local flagged=0
  local displayed=0
  echo "╔══════════════════════════════════════════"
  echo "║  🔍 Audit .$ext  │  Limit: $limit lines"
  echo "╚══════════════════════════════════════════"
  while IFS= read -r file; do
    local loc=$(wc -l < "$file")
    total=$((total + 1))
    if [ "$loc" -gt "$limit" ]; then
      flagged=$((flagged + 1))
      echo -e "  \033[1;31m🚨 ($loc)\033[0m  $file"
      displayed=$((displayed + 1))
    elif [ -z "$show_warnings" ]; then
      echo -e "  \033[0;32m✓  ($loc)\033[0m  $file"
      displayed=$((displayed + 1))
    fi
  done < <(fd --extension "$ext" --exclude "{$ignore}" .)
  echo "──────────────────────────────────────────"
  if [ -n "$show_warnings" ]; then
    echo "  📊 Displayed: $displayed files │ 🚨 Flagged: $flagged"
  else
    echo "  📊 Total: $total files │ 🚨 To refactor: $flagged"
  fi
}

_extract_log() {
  local log_type="$1"
  local message="$2"
  local timestamp
  timestamp=$(date +"%Y-%m-%d %H:%M:%S")

  case "$log_type" in
    "info")    echo -e "\e[34mℹ️ [$timestamp] [INFO] $message\e[0m" ;;
    "success") echo -e "\e[32m✅ [$timestamp] [SUCCESS] $message\e[0m" ;;
    "error")   echo -e "\e[31m❌ [$timestamp] [ERROR] $message\e[0m" ;;
  esac
}

extract() {
  if [ -z "$1" ]; then
    _extract_log "error" "Usage: extract <archive_file>"
    return 1
  fi
  if [ ! -f "$1" ]; then
    _extract_log "error" "File '$1' not found or invalid"
    return 1
  fi
  local file_lc
  file_lc=$(echo "$1" | tr '[:upper:]' '[:lower:]')
  _extract_log "info" "Starting extraction for: $1"
  case "$file_lc" in
    *.tar.bz2|*.tar.gz|*.tar.xz|*.tar.zst|*.tgz|*.tbz2|*.txz|*.tar) tar -xf "$1" && _extract_log "success" "Successfully extracted tar archive." || _extract_log "error" "Failed to extract tar archive." ;;
    *.bz2) bunzip2 "$1" && _extract_log "success" "Successfully extracted bz2 archive." || _extract_log "error" "Failed to extract bz2 archive." ;;
    *.gz) gunzip "$1" && _extract_log "success" "Successfully extracted gz archive." || _extract_log "error" "Failed to extract gz archive." ;;
    *.xz) unxz "$1" && _extract_log "success" "Successfully extracted xz archive." || _extract_log "error" "Failed to extract xz archive." ;;
    *.zst) unzstd "$1" && _extract_log "success" "Successfully extracted zst archive." || _extract_log "error" "Failed to extract zst archive." ;;
    *.rar) unrar x "$1" && _extract_log "success" "Successfully extracted rar archive." || _extract_log "error" "Failed to extract rar archive." ;;
    *.zip|*.jar|*.war|*.ear) unzip "$1" && _extract_log "success" "Successfully extracted zip archive." || _extract_log "error" "Failed to extract zip archive." ;;
    *.7z) 7z x "$1" && _extract_log "success" "Successfully extracted 7z archive." || _extract_log "error" "Failed to extract 7z archive." ;;
    *.z) uncompress "$1" && _extract_log "success" "Successfully extracted Z archive." || _extract_log "error" "Failed to extract Z archive." ;;
    *) _extract_log "error" "Unsupported format for file: $1"; return 1 ;;
  esac
}

_compress_log() {
  local log_type="$1"
  local message="$2"
  local timestamp
  timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  case "$log_type" in
    "info")    echo -e "\e[34mℹ️ [$timestamp] [INFO] $message\e[0m" ;;
    "success") echo -e "\e[32m✅ [$timestamp] [SUCCESS] $message\e[0m" ;;
    "error")   echo -e "\e[31m❌ [$timestamp] [ERROR] $message\e[0m" ;;
  esac
}

compress() {
  if [[ $# -lt 2 ]]; then
    _compress_log "error" "Usage: compress <output_archive> <file/dir> [file/dir ...]"
    _compress_log "info" "Supported: .tar.gz .tar.bz2 .tar.xz .tar.zst .zip .7z"
    return 1
  fi
  local output="$1"
  shift
  local output_lc
  output_lc=$(echo "$output" | tr '[:upper:]' '[:lower:]')
  _compress_log "info" "Compressing $* → $output"
  case "$output_lc" in
    *.tar.gz|*.tgz) tar -czf "$output" "$@" && _compress_log "success" "Created tar.gz: $output" || _compress_log "error" "Failed to compress." ;;
    *.tar.bz2|*.tbz2) tar -cjf "$output" "$@" && _compress_log "success" "Created tar.bz2: $output" || _compress_log "error" "Failed to compress." ;;
    *.tar.xz|*.txz) tar -cJf "$output" "$@" && _compress_log "success" "Created tar.xz: $output" || _compress_log "error" "Failed to compress." ;;
    *.tar.zst) tar --zstd -cf "$output" "$@" && _compress_log "success" "Created tar.zst: $output" || _compress_log "error" "Failed to compress." ;;
    *.zip) zip -r "$output" "$@" && _compress_log "success" "Created zip: $output" || _compress_log "error" "Failed to compress." ;;
    *.7z) 7z a "$output" "$@" && _compress_log "success" "Created 7z: $output" || _compress_log "error" "Failed to compress." ;;
    *) _compress_log "error" "Unsupported format. Use .tar.gz .tar.bz2 .tar.xz .tar.zst .zip or .7z"; return 1 ;;
  esac
}

dot-health() {
  echo ""
  echo "╔══════════════════════════════════════════╗"
  echo "║       🏥 Dotfiles Health Check           ║"
  echo "╠══════════════════════════════════════════╣"
  local tools=("bun" "pnpm" "node" "nvm" "docker" "nx" "ng" "flutter" "rg" "fd" "gh" "git" "tree" "zoxide" "fzf" "herdr")
  for tool in "${tools[@]}"; do
    if [[ "$tool" == "nvm" ]]; then
      if typeset -f nvm >/dev/null 2>&1 || [[ -s "$NVM_DIR/nvm.sh" ]]; then
        local nvm_v="installed"
        if typeset -f nvm >/dev/null 2>&1; then nvm_v=$(nvm --version 2>/dev/null || echo "installed"); fi
        printf "║  ✅ %-10s  %-28s ║\n" "$tool" "$nvm_v"
      else
        printf "║  ❌ \e[31m%-10s  is missing\e[0m               ║\n" "$tool"
      fi
    elif command -v "$tool" >/dev/null 2>&1; then
      local version
      version=$("$tool" --version 2>/dev/null | head -1 || echo "")
      printf "║  ✅ %-10s  %-28s ║\n" "$tool" "$version"
    else
      printf "║  ❌ \e[31m%-10s  is missing\e[0m\n" "$tool"
    fi
  done
  echo "╚══════════════════════════════════════════╝"
  echo ""
}

wt-new() {
  if [[ $# -lt 2 ]]; then
    echo "Usage: wt-new <worktree-path> <branch-name> [base-branch]"
    echo "  e.g. wt-new ../myapp-feature-auth feature/auth main"
    return 1
  fi
  local wt_path="$1"
  local branch="$2"
  local base="${3:-main}"
  local src_root
  src_root=$(git rev-parse --show-toplevel 2>/dev/null)
  if [[ -z "$src_root" ]]; then
    echo "❌ Not inside a git repository."
    return 1
  fi
  echo ""
  echo "╔══════════════════════════════════════════╗"
  echo "║       🌿 Git Worktree Auto-Setup         ║"
  echo "╠══════════════════════════════════════════╣"
  printf "║  Path   : %-31s║\n" "$wt_path"
  printf "║  Branch : %-31s║\n" "$branch"
  printf "║  Base   : %-31s║\n" "$base"
  echo "╚══════════════════════════════════════════╝"
  read -q "REPLY?  [?] Confirm creation? [y/N] "
  echo ""
  if [[ "$REPLY" != "y" ]]; then
    echo "⏭️  Aborted."
    return 0
  fi
  echo "🌿 Creating worktree → $wt_path on branch: $branch"
  git worktree add "$wt_path" -b "$branch" "$base" || {
    echo "❌ Worktree creation failed."
    return 1
  }
  echo "✅ Worktree created."
  local wt_path_abs
  wt_path_abs=$(realpath -m "$wt_path")
  local envs_copied=0
  while IFS= read -r -d '' env_file; do
    local rel
    rel=$(realpath --relative-to="$src_root" "$env_file")
    local dest="$wt_path_abs/$rel"
    mkdir -p "$(dirname "$dest")"
    cp "$env_file" "$dest"
    echo "📋 Copied: $rel"
    envs_copied=$((envs_copied + 1))
  done < <(find "$src_root" -maxdepth 4 -name '.env' -not -path '*/node_modules/*' -print0 2>/dev/null)
  echo "✅ $envs_copied .env file(s) copied."
  if [[ -f "$wt_path/pnpm-lock.yaml" ]] || [[ -f "$wt_path/package.json" ]]; then
    echo "📦 Running pnpm install in $wt_path..."
    (cd "$wt_path" && pnpm install) && echo "✅ pnpm install complete." || echo "⚠️  pnpm install had issues — check output."
  fi
  echo ""
  echo "🚀 Worktree ready! cd into it with:"
  echo "   cd $wt_path"
  echo ""
}

# ==============================================================================
# 🔐 WT-ENV — Copy .env files between the main checkout and worktrees
# ==============================================================================
# Thin, friendly wrapper over `git-worktree-auto.sh env` (alias: gwt-env).
# The worktree roots are auto-detected from the .git config:
#   • in a linked worktree → copies main → this worktree
#   • in the main checkout → opens fzf to pick the target worktree(s)
# The heavy lifting (fzf picker, edit-distance typo hints, copy core) lives in
# the script so the bash/zsh entrypoints stay in sync.
#
# Usage:
#   wt-env                 auto-detect the direction
#   wt-env up [target...]  main → worktree(s)      (fzf if no target)
#   wt-env down [src...]   worktree → current root  (fzf if no src)
#   wt-env sync <src> <dst>  worktree → worktree
#   wt-env list            inspect worktrees and their .env* count
#
# Any other flag is forwarded as-is (-i, -s, -f, -n, --deep, -y, --help).
wt-env() {
  emulate -L zsh
  local script="$HOME/dotfiles/scripts/git-worktree-auto.sh"

  if [[ ! -f "$script" ]]; then
    echo "❌ $script not found"
    return 1
  fi

  if ! git rev-parse --show-toplevel >/dev/null 2>&1; then
    echo "❌ Not inside a git repository — cd to a project first."
    return 1
  fi

  # Bare call: let the script infer the direction from the current worktree.
  if [[ $# -eq 0 ]]; then
    bash "$script" env
    return $?
  fi

  # Help / no-arg-safe: delegate so there is a single source of truth.
  case "$1" in
    -h|--help|help) bash "$script" env --help; return $? ;;
  esac

  case "$1" in
    up)    shift; bash "$script" env to   "$@" ;;
    down)  shift; bash "$script" env from "$@" ;;
    sync)  shift; bash "$script" env sync "$@" ;;
    list)  shift; bash "$script" env list "$@" ;;
    *)         bash "$script" env "$@" ;;
  esac
}

# ==============================================================================
# ⚡ ALIASRUN — Search, pick and run your zsh aliases with fzf
# ==============================================================================
# You have hundreds of aliases and forget half of them. This picks one (or
# several) with fzf and runs it, instead of trying to remember the name.
#
# Usage:
#   aliasrun                 open the fzf picker over every alias
#   aliasrun <name>          run that alias directly (no picker) — fast path
#   aliasrun -g <group>      restrict to a group (git, docker, bun, …)
#   aliasrun -l              list all aliases grouped, no picker
#   aliasrun -c              copy the selected alias definition
#   aliasrun -h              this help
#
# In the picker: TAB = multi-select · ENTER = run · ESC = cancel
#
# Notes:
#   • Source of truth is `alias` in the CURRENT shell, so optional modules
#     (~/.git_aliases.zsh …) and ~/.zsh_local are included automatically.
#   • Nothing runs at shell startup; this only costs time when you call it.
# ---------------------------------------------------------------------------

# Group an alias by its name so results stay scannable.
_aliasrun_group() {
  case "$1" in
    _*)                        echo "internal" ;;
    gwt*|gs*|ga*|gc*|gp*|gl*|gf*|gb*|gr*|g[a-z]) echo "git" ;;
    ng[a-z]*|nx[a-z]*)         echo "angular/nx" ;;
    ns[a-z]*|pgen*|pmig*|pstu*|pdb*) echo "nestjs/prisma" ;;
    fl[a-z]*)                  echo "flutter" ;;
    d[a-z]*)                   echo "docker" ;;
    pnpm*|pn*|npx*)            echo "pnpm" ;;
    br*|bun*|nxp*)             echo "bun" ;;
    gpt*|claude*|sk*|ai*)       echo "ai" ;;
    ll|la|l|ls*|cat*|cdi|v|nv*) echo "files" ;;
    kill*|port*)               echo "system" ;;
    *)                         echo "other" ;;
  esac
}

# Emit "name<TAB>command<TAB>group" for every alias in the current shell.
#
# Parsing notes:
#   • iterate over ${(@k)aliases} instead of parsing `alias` output: a value can
#     contain newlines/tabs/quotes (path='echo $PATH | tr ":" "\n" | nl'),
#     and reading name+value per key keeps each entry on a single row;
#   • the value is read raw from $aliases, so the outer quotes that `alias`
#     prints are already gone — inner ones are preserved;
#   • a trailing space is meaningful (s='sudo ' → "sudo ").
_aliasrun_collect() {
  local filter_group="$1"
  local name cmd group
  local -a rows=()
  # Iterate over alias NAMES (one per line, never split by the value) and read
  # each value from $aliases — immune to values containing newlines, tabs or
  # quotes (path='echo $PATH | tr ":" "\n" | nl' stays a single row).
  for name in "${(@k)aliases}"; do
    cmd="${aliases[$name]}"
    [[ -z "$name" ]] && continue
    [[ "$name" == _* ]] && continue        # internal helpers
    (( ${#cmd} > 200 )) && continue        # skip huge definitions
    group=$(_aliasrun_group "$name")
    [[ -n "$filter_group" && "$group" != "$filter_group" ]] && continue
    # Keep the row on one physical line: replace real control characters.
    cmd="${cmd//$'\n'/\\n}"
    cmd="${cmd//$'\t'/ }"
    # Row layout is name ⇥ command ⇥ group (group last so a plain sort keys on
    # it). Build it as group ⇥ name ⇥ command so the (o) sort groups properly,
    # then re-order to the canonical layout on output.
    rows+=("${group}"$'\t'"${name}"$'\t'"${cmd}")
  done
  # SORT the rows. ${(@k)aliases} is a hash table → the raw order is random, so
  # pressing ENTER straight away would run an arbitrary alias. Sort by group
  # then name, in zsh (piping through `sort` would split a value containing a
  # literal "\n", e.g. path='… tr ":" "\n" …').
  # Note the "${sorted[@]}" (quoted): an unquoted expansion would re-split values
  # that contain spaces or glob characters.
  local -a sorted=("${(@)rows}")
  sorted=(${(o)sorted})
  local r rest sname scmd sgroup
  for r in "${sorted[@]}"; do
    # sorted rows are "group ⇥ name ⇥ command" → emit "name ⇥ command ⇥ group"
    sgroup="${r%%$'\t'*}"           # group is the first field
    rest="${r#*$'\t'}"              # drop it
    sname="${rest%%$'\t'*}"         # name
    scmd="${rest#*$'\t'}"           # command
    print -r -- "${sname}"$'\t'"${scmd}"$'\t'"${sgroup}"
  done
}

# Copy to the clipboard, detecting the backend like _clipboard_paste does.
_aliasrun_copy() {
  local text="$1"
  if command -v wl-copy >/dev/null 2>&1; then
    printf '%s' "$text" | wl-copy && return 0
  elif command -v xclip >/dev/null 2>&1; then
    printf '%s' "$text" | xclip -selection clipboard && return 0
  elif command -v xsel >/dev/null 2>&1; then
    printf '%s' "$text" | xsel -b && return 0
  elif command -v pbcopy >/dev/null 2>&1; then
    printf '%s' "$text" | pbcopy && return 0
  fi
  return 1
}

# Number of non-empty rows in a TSV blob (wc -l on "$(...)" data is fragile:
# command substitution eats the trailing newline and can report one too many).
_aliasrun_count() {
  local line n=0
  while IFS= read -r line; do
    [[ -n "$line" ]] && n=$((n + 1))
  done <<< "$1"
  print -r -- "$n"
}

# Resolve a single alias name to its command. Prints nothing when unknown.
_aliasrun_lookup() {
  local want="$1" name cmd g
  while IFS=$'\t' read -r name cmd g; do
    if [[ "$name" == "$want" ]]; then
      print -r -- "$cmd"
      return 0
    fi
  done < <(_aliasrun_collect "")
  return 1
}

# List every alias grouped, without any picker.
_aliasrun_list() {
  local group="$1" data name cmd g cur="" total
  data=$(_aliasrun_collect "$group")
  [[ -z "$data" ]] && { echo "❌ No alias found."; return 1; }
  total=$(_aliasrun_count "$data")
  echo ""
  echo "  ⚡ $total alias(es)${group:+ in group '$group'}"
  echo "  ══════════════════════════════════════════════════════════════"
  # Sort in zsh: piping through `sort` splits a literal "\n" inside a value into
  # a real line break (path='… tr ":" "\n" …' was cut in two).
  local -a sorted=()
  local r key g2 name2
  for r in ${(f)data}; do
    [[ -z "$r" ]] && continue
    # key = group <TAB> name, so a plain (o) sort groups then orders by name
    g2="${r##*$'\t'}"          # group is the last field
    name2="${r%%$'\t'*}"       # name is the first field
    sorted+=("${g2}"$'\t'"${name2}")
  done
  sorted=(${(o)sorted})
  for r in $sorted; do
    [[ -z "$r" ]] && continue
    g2="${r%%$'\t'*}"
    name2="${r#*$'\t'}"
    cmd="${aliases[$name2]}"
    if [[ "$g2" != "$cur" ]]; then
      cur="$g2"
      printf '\n  %s\n' "${(U)cur}"
    fi
    printf '    %-14s %s\n' "$name2" "$cmd"
  done
  echo ""
  return 0
}

# No-fzf fallback: numbered list, accepts "2", "1 3 5" and "1-4".
# The chosen alias NAMES go to stdout (one per line); the list and the prompt
# go to stderr so the caller can capture stdout cleanly.
_aliasrun_fallback() {
  local data="$1"
  local -a names=() cmds=()
  local name cmd g i answer tok a b k
  while IFS=$'\t' read -r name cmd g; do
    [[ -n "$name" ]] || continue
    names+=("$name"); cmds+=("$cmd")
  done <<< "$data"

  {
    print ""
    print "  ⚠️  fzf not found — numbered selection"
    for ((i = 1; i <= ${#names[@]}; i++)); do
      printf '  %3d) %-14s %s\n' "$i" "${names[i]}" "${cmds[i]}"
    done
    # NOTE: no `read -p` — it needs a coprocess and fails with "no coprocess"
    # when stdin is not a terminal (piped input, scripts, CI).
    print -n "  number(s) or ranges [1-3 5], 0 = cancel: "
  } >&2
  read -r answer
  if [[ -z "$answer" || "$answer" == 0 ]]; then
    return 1
  fi

  local -a chosen=()
  for tok in ${=answer}; do
    if [[ "$tok" == *-* ]]; then
      a="${tok%-*}"; b="${tok#*-}"
      if [[ "$a" =~ ^[0-9]+$ && "$b" =~ ^[0-9]+$ ]]; then
        (( b > ${#names[@]} )) && b=${#names[@]}
        for ((k = a; k <= b; k++)); do
          (( k >= 1 )) && chosen+=("${names[k]}")
        done
      else
        echo "  ⚠️  bad range: $tok"
      fi
    elif [[ "$tok" =~ ^[0-9]+$ ]]; then
      if (( tok >= 1 && tok <= ${#names[@]} )); then
        chosen+=("${names[tok]}")
      else
        echo "  ⚠️  out of range: $tok"
      fi
    else
      echo "  ⚠️  not a number: $tok"
    fi
  done
  (( ${#chosen[@]} )) || return 1
  printf '%s\n' "${chosen[@]}"
  return 0
}

aliasrun_help() {
  cat <<'EOF'
  ⚡ aliasrun — find and run any of your zsh aliases with fzf

  Usage:
    aliasrun                 picker over every alias
    aliasrun <name>          run that alias directly (no picker)
    aliasrun -g <group>      restrict to a group
    aliasrun -l              list all aliases grouped (no picker)
    aliasrun -c              copy the selected alias definition

  Picker keys:
    TAB    multi-select      ENTER  run the selection      ESC  cancel

  Groups: git · angular/nx · nestjs/prisma · flutter · docker · pnpm ·
          bun · ai · files · system · other
EOF
}

aliasrun() {
  emulate -L zsh
  setopt local_options no_unset

  local group="" list_mode="false" copy_mode="false" direct=""
  local -a extra=()

  # ---- flags ----
  # Everything after the alias NAME is forwarded to the alias itself, so
  # `aliasrun gcm "my message"` runs `gcm "my message"`.
  while (( $# > 0 )); do
    case "$1" in
      -g|--group) group="${2:-}"; shift 2 ;;
      -l|--list)  list_mode="true"; shift ;;
      -c|--copy)  copy_mode="true"; shift ;;
      -h|--help)  aliasrun_help; return 0 ;;
      -*)         echo "❌ Unknown option: $1"; echo ""; aliasrun_help; return 1 ;;
      *)
        if [[ -z "$direct" ]]; then
          direct="$1"
        else
          extra+=("$1")
        fi
        shift
        ;;
    esac
  done

  # ---- list mode ----
  [[ "$list_mode" == "true" ]] && { _aliasrun_list "$group"; return $?; }

  # ---- fast path: run a known alias directly ----
  if [[ -n "$direct" ]]; then
    local cmd
    if ! cmd=$(_aliasrun_lookup "$direct"); then
      echo "❌ Unknown alias: '$direct'"
      echo "💡 'aliasrun -l' lists them all · 'aliasrun' opens the fzf picker."
      return 1
    fi
    if [[ "$copy_mode" == "true" ]]; then
      local text="$direct='$cmd'"
      if _aliasrun_copy "$text"; then echo "📋 Copied: $text"
      else echo "📋 $text"; echo "⚠️  No clipboard tool (wl-copy/xclip/xsel/pbcopy)."; fi
      return 0
    fi
    echo "⚡ $direct → $cmd${extra:+ $*}"
    if (( ${#extra[@]} > 0 )); then
      eval "$cmd ${(q)extra}"
    else
      eval "$cmd"
    fi
    return $?
  fi

  # ---- collect ----
  local data total
  data=$(_aliasrun_collect "$group")
  if [[ -z "$data" ]]; then
    echo "❌ No alias found${group:+ in group '$group'}."
    return 1
  fi
  total=$(_aliasrun_count "$data")

  # ---- pick: fzf, or numbered fallback when fzf is missing ----
  local -a selected=()
  if command -v fzf >/dev/null 2>&1; then
    local out row
    # Feed rows to fzf WITHOUT `print -l`: it interprets escape sequences and
    # would turn the literal "\n" of path='… tr ":" "\n" …' into a real newline,
    # splitting that alias across two rows. printf '%s\n' is literal-safe.
    # `--with-nth` reorders the DISPLAY only, so {1} still refers to the name.
    # NOTE: no `start:down` bind — fzf already makes the first row the current
    # one, so ENTER with an empty query runs it (verified with tmux). Adding
    # start:down would move the cursor OFF the first row.
    if ! out=$(printf '%s\n' "$data" | fzf \
          --multi --reverse --height=60% --border \
          --delimiter=$'\t' --with-nth=1,3,2 --tiebreak=index \
          --prompt='⚡ alias > ' \
          --header="TAB = multi-select │ ENTER = run │ ESC = cancel  (${total} aliases)" \
          --preview='printf "  \033[1m%s\033[0m\n\n  %s\n\n  group: %s\n" {1} {2} {3}' \
          --preview-window='down:5:wrap'); then
      echo "  ✋ cancelled."
      return 0
    fi
    # fzf exits 0 with an EMPTY output when ENTER is pressed with no query and
    # no current line (fzf < 0.50 has no --highlight-line): treat it as a
    # cancel instead of falling through and doing nothing visible.
    if [[ -z "$out" ]]; then
      echo "  ✋ nothing selected (type to search, then ENTER)."
      return 0
    fi
    # Only the NAME (field 1) is needed, so read it literally.
    while IFS= read -r row; do
      [[ -n "$row" ]] && selected+=("${row%%$'\t'*}")
    done <<< "$out"
  else
    local picked n
    if ! picked=$(_aliasrun_fallback "$data"); then
      echo "  ✋ nothing selected."
      return 0
    fi
    for n in ${(f)picked}; do
      [[ -n "$n" ]] && selected+=("$n")
    done
  fi

  (( ${#selected[@]} )) || { echo "  ✋ nothing selected."; return 0; }

  # ---- resolve the selection to commands ----
  local -a cmds=() labels=()
  local name cmd
  for name in "${selected[@]}"; do
    if cmd=$(_aliasrun_lookup "$name"); then
      cmds+=("$cmd"); labels+=("$name")
    else
      echo "⚠️  '$name' is not an alias anymore — skipped."
    fi
  done
  (( ${#cmds[@]} )) || { echo "❌ Nothing to run."; return 1; }

  # ---- copy mode ----
  if [[ "$copy_mode" == "true" ]]; then
    local i text
    for ((i = 1; i <= ${#labels[@]}; i++)); do
      text="${labels[i]}='${cmds[i]}'"
      if _aliasrun_copy "$text"; then echo "📋 Copied: $text"
      else echo "📋 $text"; fi
    done
    return 0
  fi

  # ---- confirm when several aliases will run ----
  if (( ${#cmds[@]} > 1 )); then
    echo ""
    echo "  ⚡ Running ${#cmds[@]} aliases in order:"
    local i=1
    for name in "${labels[@]}"; do
      printf '     %d. %-14s %s\n' "$i" "$name" "${cmds[i]}"
      i=$((i + 1))
    done
    local reply
    # See the note in _aliasrun_fallback: `read -p` needs a coprocess and
    # errors out when stdin is piped instead of a terminal.
    print -n "  Proceed? [y/N] "
    read -r reply
    if [[ "$reply" != [yY]* ]]; then
      echo "  ✋ aborted."
      return 0
    fi
  fi

  # ---- run sequentially, with a final report ----
  local idx failed=0
  for ((idx = 1; idx <= ${#cmds[@]}; idx++)); do
    echo ""
    if (( ${#cmds[@]} > 1 )); then
      echo "═══════ [$idx/${#cmds[@]}] ⚡ ${labels[idx]} ═══════"
    else
      echo "⚡ ${labels[idx]}"
    fi
    eval "${cmds[idx]}"
    if (( $? != 0 )); then
      failed=$((failed + 1))
      echo "❌ Failed: ${labels[idx]}"
    fi
  done

  echo ""
  if (( failed > 0 )); then
    echo "📋 Done: $(( ${#cmds[@]} - failed ))/${#cmds[@]} succeeded, ❌ $failed failed"
    return 1
  fi
  echo "✅ Done: ${#cmds[@]}/${#cmds[@]} succeeded"
  return 0
}

# ==============================================================================
# 📦 BRS — Multi-package.json Script Runner (monorepo aware, bun-first)
# ==============================================================================
# Scans ALL package.json files in the repo (root, backend/, frontend/, apps/...),
# groups scripts BY PROJECT in fzf, then runs the selected scripts
# ONE BY ONE with the correct package manager:
#   bun.lock / bun.lockb  -> bun
#   pnpm-lock.yaml        -> pnpm
#   yarn.lock             -> yarn
#   package-lock.json     -> npm
#   (none)                -> bun (default)
#
# Usage:  brs [dir]     (dir = repo root or subdirectory)
# Multi-select: TAB to select multiple scripts, Enter to run all
# sequentially. Final success/failure report at the end.
# Variables: BRS_DEPTH=3          (package.json search depth)
#            BRS_STOP_ON_ERROR=1  (stop on first failure instead of continuing)
brs() {
  emulate -L zsh
  if ! command -v fzf >/dev/null 2>&1; then echo "❌ fzf is required for brs"; return 1; fi
  if ! command -v bun >/dev/null 2>&1; then echo "❌ bun is required for brs"; return 1; fi

  local root="${1:-$PWD}"
  root=$(cd "$root" 2>/dev/null && git rev-parse --show-toplevel 2>/dev/null || echo "$PWD")

  local list_file=$(mktemp)
  local pkg dir name pm pkgs script cmd total i failed pm_sel dir_sel

  pkgs=$(find "$root" -maxdepth ${BRS_DEPTH:-3} -name package.json \
    -not -path '*/node_modules/*' -not -path '*/.angular/*' \
    -not -path '*/dist/*' -not -path '*/.next/*' -not -path '*/.nitro/*')

  for pkg in ${(f)pkgs}; do
    dir=${pkg:A:h}
    if [[ "$dir" == "${root:A}" ]]; then name="🏠 root"; else name="📦 ${dir:t}"; fi
    if   [[ -f "$dir/bun.lock" || -f "$dir/bun.lockb" ]]; then pm="bun"
    elif [[ -f "$dir/pnpm-lock.yaml" ]]; then pm="pnpm"
    elif [[ -f "$dir/yarn.lock" ]]; then pm="yarn"
    elif [[ -f "$dir/package-lock.json" ]]; then pm="npm"
    else pm="bun"
    fi
    # List: "project<TAB>script<TAB>command<TAB>manager<TAB>directory"
    bun -e "const p=require('${pkg}');const s=p.scripts||{};for(const k of Object.keys(s))console.log('${name}\t'+k+'\t'+String(s[k]).replace(/\\n/g,' ')+'\t${pm}\t${dir}')" >> "$list_file"
  done

  if [[ ! -s "$list_file" ]]; then
    rm -f "$list_file"
    echo "⚠️  No scripts found in $root"
    return 1
  fi

  local choice
  choice=$(fzf --multi --delimiter=$'\t' --with-nth=1,2,3 \
    --prompt='🚀 scripts (TAB = multi-select) > ' \
    --header=$'project │ script │ command' \
    --preview='awk -F"\t" "{print \"Project  : \"\$1; print \"Script   : \"\$2; print \"Command  : \"\$3; print \"Manager  : \"\$4; print \"Directory: \"\$5}"' \
    --preview-window=down:6 < "$list_file")
  local rc_fzf=$?
  rm -f "$list_file"
  [[ $rc_fzf -ne 0 || -z "$choice" ]] && return 0   # Esc / Ctrl-C

  # ── SEQUENTIAL execution of all selected scripts ──
  total=$(printf '%s\n' "$choice" | grep -c .)
  i=0
  failed=0

  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    (( i++ ))
    unset name script cmd pm_sel dir_sel
    IFS=$'\t' read -r name script cmd pm_sel dir_sel <<< "$line"
    echo ""
    echo "═══════ [$i/$total] 🚀 [$pm_sel] $name › $script ═══════"
    if [[ "$script" =~ ^(dev|serve|server|watch|preview|start)$ ]]; then
      echo "ℹ️  Long-running script detected (server/dev) — runs until Ctrl-C."
    fi
    if ! pushd "$dir_sel" >/dev/null 2>&1; then
      echo "❌ Directory not found: $dir_sel"; (( failed++ )); continue
    fi
    "$pm_sel" run "$script"
    if (( $? != 0 )); then
      (( failed++ ))
      echo "❌ Failed: [$name] $script"
      if [[ "${BRS_STOP_ON_ERROR:-0}" == 1 ]]; then
        popd >/dev/null
        echo "⏹️  Stopped (BRS_STOP_ON_ERROR=1)"
        return 1
      fi
    fi
    popd >/dev/null
  done <<< "$choice"

  echo ""
  if (( failed > 0 )); then
    echo "📋 Done: $((total - failed))/$total succeeded, ❌ $failed failed"
    return 1
  fi
  echo "✅ Done: $total/$total succeeded"
  return 0
}
