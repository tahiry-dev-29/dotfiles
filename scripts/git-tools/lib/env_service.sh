#!/usr/bin/env bash
# Git Tools - Safe Environment File Bootstrap Service
set -euo pipefail

# Default allowed environment file basenames
DEFAULT_ENV_ALLOWLIST=(".env" ".env.local" ".env.development" ".env.development.local")
DEFAULT_ENV_DENYLIST=(".env.production" ".env.production.local" ".env.prod")

# Find environment files in primary worktree matching allowlist
# Usage: env_find_allowed_files "$primary_root"
env_find_allowed_files() {
  local src_root="$1"
  local -a found=()

  for name in "${DEFAULT_ENV_ALLOWLIST[@]}"; do
    local src_file="$src_root/$name"
    # Regular file only, no symlinks outside source
    if [[ -f "$src_file" && ! -L "$src_file" ]]; then
      found+=("$name")
    fi
  done
  printf '%s\n' "${found[@]:-}"
}

# Preview environment file copy action
# Output: list of files to copy and files skipped
env_preview_copy() {
  local src_root="$1"
  local dst_root="$2"

  printf '%sEnvironment Bootstrap Preview:%s\n' "$C_BOLD" "$C_RESET"
  printf '  Source: %s\n' "$src_root"
  printf '  Target: %s\n' "$dst_root"
  printf '  Allowed files:\n'

  local count=0
  for name in "${DEFAULT_ENV_ALLOWLIST[@]}"; do
    local src_file="$src_root/$name"
    local dst_file="$dst_root/$name"
    if [[ -f "$src_file" && ! -L "$src_file" ]]; then
      if [[ -e "$dst_file" ]]; then
        printf '    %s⚠ %-25s (exists in target - will skip by default)%s\n' "$C_YELLOW" "$name" "$C_RESET"
      else
        printf '    %s✓ %-25s (ready to copy)%s\n' "$C_GREEN" "$name" "$C_RESET"
        count=$((count + 1))
      fi
    fi
  done

  for name in "${DEFAULT_ENV_DENYLIST[@]}"; do
    local src_file="$src_root/$name"
    if [[ -e "$src_file" ]]; then
      printf '    %s- %-25s (denied: production secret protected)%s\n' "$C_DIM" "$name" "$C_RESET"
    fi
  done
  printf '  Total ready to copy: %d\n' "$count"
}

# Copy allowed environment files from primary worktree to target worktree
# Usage: env_copy_files "$src_root" "$dst_root" [overwrite_bool]
env_copy_files() {
  local src_root="$1"
  local dst_root="$2"
  local overwrite="${3:-false}"

  local copied=0 skipped=0 failed=0

  # Ensure destination path does not escape dst_root (prevent path traversal)
  local real_dst
  real_dst="$(cd "$dst_root" 2>/dev/null && pwd -P)" || {
    log_err "Destination directory does not exist: $dst_root"
    return 1
  }

  for name in "${DEFAULT_ENV_ALLOWLIST[@]}"; do
    local src_file="$src_root/$name"
    local dst_file="$real_dst/$name"

    [[ -f "$src_file" && ! -L "$src_file" ]] || continue

    if [[ -e "$dst_file" && "$overwrite" != "true" ]]; then
      log_warn "Skipped existing: $name"
      skipped=$((skipped + 1))
      continue
    fi

    if cp -p "$src_file" "$dst_file" 2>/dev/null; then
      log_ok "Copied $name"
      copied=$((copied + 1))
    else
      log_err "Failed to copy $name"
      failed=$((failed + 1))
    fi
  done

  printf '%d copied, %d skipped, %d failed\n' "$copied" "$skipped" "$failed"
  return "$failed"
}
