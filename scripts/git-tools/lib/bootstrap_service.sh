#!/usr/bin/env bash
# Git Tools - Worktree Post-Creation Bootstrap Pipeline
set -euo pipefail

# Execute the complete bootstrap pipeline for a newly created worktree
# Usage: bootstrap_worktree "$root" "$target_worktree_path" "$branch_or_ref"
bootstrap_worktree() {
  local root="$1"
  local target_path="$2"
  local ref_label="$3"

  local primary_root
  primary_root="$(get_main_repo_root "$root")"

  printf '\n%s╔══════════════════════════════════════════════════════╗%s\n' "$C_CYAN" "$C_RESET"
  printf '%s║          Worktree Post-Creation Bootstrap            ║%s\n' "$C_BOLD" "$C_RESET"
  printf '%s╚══════════════════════════════════════════════════════╝%s\n' "$C_CYAN" "$C_RESET"
  printf 'Target: %s (%s)\n' "$target_path" "$ref_label"

  # Step 1: Environment files
  printf '\n%s▶ [1/3] Copying environment files from primary worktree...%s\n' "$C_CYAN" "$C_RESET"
  if [[ -d "$primary_root" && "$primary_root" != "$target_path" ]]; then
    env_copy_files "$primary_root" "$target_path" "false" || true
  else
    log_info "No separate primary worktree to copy environment files from."
  fi

  # Step 2: Dependency installation
  printf '\n%s▶ [2/3] Installing dependencies (deterministic frozen install)...%s\n' "$C_CYAN" "$C_RESET"
  local install_failed=0
  if [[ -f "$target_path/package.json" ]]; then
    pkg_install_frozen "$target_path" || install_failed=$?
  else
    log_info "No package.json in worktree. Skipping dependency install."
  fi

  # Step 3: Verification
  printf '\n%s▶ [3/3] Verifying worktree health...%s\n' "$C_CYAN" "$C_RESET"
  if [[ -d "$target_path" && ( -f "$target_path/.git" || -d "$target_path/.git" ) ]]; then
    local current_sha
    current_sha="$(git -C "$target_path" rev-parse --short HEAD 2>/dev/null || echo "unknown")"
    log_ok "Git worktree verified at commit $current_sha."
  else
    log_err "Worktree directory verification failed."
    return 1
  fi

  # Final Summary
  printf '\n%s────────────────────────────────────────────────────────%s\n' "$C_DIM" "$C_RESET"
  if [[ $install_failed -eq 0 ]]; then
    log_ok "Bootstrap completed successfully!"
    printf 'Worktree is ready at: %s%s%s\n' "$C_BOLD" "$target_path" "$C_RESET"
  else
    log_warn "Bootstrap finished with dependency warnings."
    printf 'Worktree was %sPRESERVED%s at: %s\n' "$C_YELLOW" "$C_RESET" "$target_path"
    printf 'Inspect and run your package manager manually inside %s.\n' "$target_path"
  fi
  printf '%s────────────────────────────────────────────────────────%s\n' "$C_DIM" "$C_RESET"
  return 0
}
