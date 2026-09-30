#!/usr/bin/env bash
# Git Tools - Core Utilities
set -euo pipefail

# ANSI Color Codes
C_RESET=$'\033[0m'
C_BOLD=$'\033[1m'
C_DIM=$'\033[2m'
C_RED=$'\033[31m'
C_GREEN=$'\033[32m'
C_YELLOW=$'\033[33m'
C_BLUE=$'\033[34m'
C_MAGENTA=$'\033[35m'
C_CYAN=$'\033[36m'

log_info()    { printf '%sℹ %s%s\n' "$C_CYAN" "$*" "$C_RESET"; }
log_ok()      { printf '%s✔ %s%s\n' "$C_GREEN" "$*" "$C_RESET"; }
log_warn()    { printf '%s⚠ %s%s\n' "$C_YELLOW" "$*" "$C_RESET"; }
log_err()     { printf '%s✘ %s%s\n' "$C_RED" "$*" "$C_RESET" >&2; }

# Safe string trim
trim() {
  local var="$*"
  var="${var#"${var%%[![:space:]]*}"}"
  var="${var%"${var##*[![:space:]]}"}"
  printf '%s' "$var"
}

# Prompt confirmation (y/N)
confirm() {
  local prompt="${1:-Are you sure?}"
  local default="${2:-n}"
  local reply

  if [[ "$default" == "y" ]]; then
    printf '%s%s [Y/n]: %s' "$C_YELLOW" "$prompt" "$C_RESET"
  else
    printf '%s%s [y/N]: %s' "$C_YELLOW" "$prompt" "$C_RESET"
  fi

  read -r reply </dev/tty || reply="$default"
  reply="$(trim "$reply")"
  reply="${reply,,}" # lowercase

  if [[ -z "$reply" ]]; then
    reply="$default"
  fi

  [[ "$reply" == "y" || "$reply" == "yes" ]]
}

# Prompt text input with default
prompt_input() {
  local prompt="$1"
  local default="${2:-}"
  local value

  if [[ -n "$default" ]]; then
    printf '%s%s [%s]: %s' "$C_CYAN" "$prompt" "$default" "$C_RESET"
  else
    printf '%s%s: %s' "$C_CYAN" "$prompt" "$C_RESET"
  fi

  read -r value </dev/tty || value=""
  value="$(trim "$value")"
  if [[ -z "$value" ]]; then
    printf '%s\n' "$default"
  else
    printf '%s\n' "$value"
  fi
}
