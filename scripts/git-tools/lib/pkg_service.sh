#!/usr/bin/env bash
# Git Tools - Deterministic Package Manager & Dependency Service
set -euo pipefail

# Detect package manager and install command for a directory
# Returns: "<pkg_manager>\t<command_array_str>\t<status_str>"
pkg_detect() {
  local dir="$1"
  local pkg_json="$dir/package.json"

  if [[ ! -f "$pkg_json" ]]; then
    printf 'none\t\tno package.json found\n'
    return 0
  fi

  # Check packageManager field in package.json
  local pm_field=""
  if command -v jq >/dev/null 2>&1; then
    pm_field="$(jq -r '.packageManager // empty' "$pkg_json" 2>/dev/null || true)"
  else
    pm_field="$(sed -n 's/.*"packageManager"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$pkg_json" | head -n1)"
  fi

  # Detect lockfiles
  local has_pnpm=0 has_npm=0 has_yarn=0 has_bun=0
  [[ -f "$dir/pnpm-lock.yaml" ]] && has_pnpm=1
  [[ -f "$dir/package-lock.json" ]] && has_npm=1
  [[ -f "$dir/yarn.lock" ]] && has_yarn=1
  [[ -f "$dir/bun.lock" || -f "$dir/bun.lockb" ]] && has_bun=1

  local lock_count=$(( has_pnpm + has_npm + has_yarn + has_bun ))

  # Check for conflicts
  if (( lock_count > 1 )); then
    if [[ -n "$pm_field" ]]; then
      local pm_name="${pm_field%%@*}"
      _pkg_resolve_command "$pm_name" "warning: multiple lockfiles, resolved via packageManager field ($pm_field)"
      return 0
    else
      # If pnpm-lock is present along with package-lock, prioritize pnpm or warn
      if (( has_pnpm == 1 )); then
        _pkg_resolve_command "pnpm" "warning: conflicting lockfiles (pnpm-lock.yaml selected)"
      else
        _pkg_resolve_command "npm" "warning: conflicting lockfiles (package-lock.json selected)"
      fi
      return 0
    fi
  fi

  # Single lockfile or packageManager field
  if [[ -n "$pm_field" ]]; then
    local pm_name="${pm_field%%@*}"
    _pkg_resolve_command "$pm_name" "ok"
    return 0
  fi

  if (( has_pnpm == 1 )); then
    _pkg_resolve_command "pnpm" "ok"
  elif (( has_npm == 1 )); then
    _pkg_resolve_command "npm" "ok"
  elif (( has_yarn == 1 )); then
    _pkg_resolve_command "yarn" "ok"
  elif (( has_bun == 1 )); then
    _pkg_resolve_command "bun" "ok"
  else
    printf 'none\t\tpackage.json present but no lockfile found\n'
  fi
}

_pkg_resolve_command() {
  local pm="$1"
  local note="$2"

  case "$pm" in
    pnpm) printf 'pnpm\tpnpm install --frozen-lockfile\t%s\n' "$note" ;;
    npm)  printf 'npm\tnpm ci\t%s\n' "$note" ;;
    yarn) printf 'yarn\tyarn install --immutable\t%s\n' "$note" ;;
    bun)  printf 'bun\tbun install --frozen-lockfile\t%s\n' "$note" ;;
    *)    printf '%s\t%s install\t%s\n' "$pm" "$pm" "$note" ;;
  esac
}

# Run deterministic frozen install in target directory
# Returns 0 on success, non-zero on failure. Never falls back to non-frozen install!
pkg_install_frozen() {
  local dir="$1"
  local detect_out
  detect_out="$(pkg_detect "$dir")"

  local pm cmd_str note
  IFS=$'\t' read -r pm cmd_str note <<<"$detect_out"

  if [[ "$pm" == "none" || -z "$cmd_str" ]]; then
    log_info "No supported package manager / lockfile in $dir. Skipping install."
    return 0
  fi

  log_info "Detected $pm ($note). Running: $cmd_str"

  # Verify executable exists
  if ! command -v "$pm" >/dev/null 2>&1; then
    log_err "Package manager '$pm' is required by project but not found in PATH."
    return 1
  fi

  # Execute command safely in subshell without modifying lockfiles
  local exit_code=0
  (
    cd "$dir"
    case "$pm" in
      pnpm) pnpm install --frozen-lockfile ;;
      npm)  npm ci ;;
      yarn) yarn install --immutable ;;
      bun)  bun install --frozen-lockfile ;;
      *)    $cmd_str ;;
    esac
  ) || exit_code=$?

  if [[ $exit_code -ne 0 ]]; then
    log_err "Deterministic dependency installation failed (exit code $exit_code)."
    log_warn "Lockfile may be out of sync with package.json."
    log_warn "Worktree has been PRESERVED for inspection."
    return "$exit_code"
  fi

  log_ok "Dependencies installed successfully using $pm."
  return 0
}
