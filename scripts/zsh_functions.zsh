# ==============================================================================
# ZSH COMPLEX FUNCTIONS
# ==============================================================================

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
CLIP_HISTORY_MAX=500

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
  if pgrep -f "wl-paste --watch" >/dev/null 2>&1; then
    echo "✅ Clipboard watcher is already running."
    return 0
  fi
  mkdir -p "$(dirname "$CLIP_HISTORY_FILE")"
  wl-paste --watch bash -c 'printf "[%s] %s\n" "$(date +"%Y-%m-%d %H:%M:%S")" "$(wl-paste 2>/dev/null)" >> '"$CLIP_HISTORY_FILE" &!
  echo "👁️  Clipboard watcher started in background."
}

# Code size audit
count-code() {
  local ext=${1:-ts}
  local limit=${2:-200}
  local ignore="node_modules|dist|prisma|.prisma|.next|.angular|.nx|.git|.dart_tool|build|out|.firebase|coverage|.cache"
  local total=0
  local flagged=0
  echo "╔══════════════════════════════════════════"
  echo "║  🔍 Audit .$ext  │  Limite: $limit lignes"
  echo "╚══════════════════════════════════════════"
  while IFS= read -r file; do
    local loc=$(wc -l < "$file")
    total=$((total + 1))
    if [ "$loc" -gt "$limit" ]; then
      flagged=$((flagged + 1))
      echo -e "  \033[1;31m🚨 ($loc)\033[0m  $file"
    else
      echo -e "  \033[0;32m✓  ($loc)\033[0m  $file"
    fi
  done < <(fd --extension "$ext" --exclude "{$ignore}" .)
  echo "──────────────────────────────────────────"
  echo "  📊 Total: $total fichiers │ 🚨 To refactor: $flagged"
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
  local tools=("bun" "pnpm" "node" "nvm" "docker" "nx" "ng" "flutter" "rg" "fd" "gh" "git" "tree" "zoxide" "fzf")
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
