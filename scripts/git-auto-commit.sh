#!/usr/bin/env bash
# ==============================================================================
# git-auto-commit.sh - Generate a Conventional Commit from a structural diff,
# then commit and push.
# ==============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

AUTO_YES=false
DRY_RUN=false
NO_PUSH=false
NO_VERIFY=false
MESSAGE=""

log_info() { printf "${CYAN}[info]${RESET} %s\n" "$*"; }
log_step() { printf "${BLUE}[step]${RESET} %s\n" "$*"; }
log_success() { printf "${GREEN}[ok]${RESET} %s\n" "$*"; }
log_warn() { printf "${YELLOW}[warn]${RESET} %s\n" "$*"; }
log_error() { printf "${RED}[error]${RESET} %s\n" "$*" >&2; }

usage() {
  cat <<EOF
${BOLD}git-auto-commit.sh${RESET} - structural Conventional Commit automation

Usage:
  $0 [options]

Options:
  -m, --message <msg>  Use an explicit Conventional Commit message
  -y, --yes            Skip confirmation prompts
      --dry-run        Print the generated message and stop before commit
      --no-push        Commit without pushing
      --no-verify      Pass --no-verify to git commit
  -h, --help           Show this help

Optional AI integration:
  GAC_AI_CMD='your-command' $0

GAC_AI_CMD receives a security-redacted structural diff on stdin and must output
only the final Conventional Commit message.
EOF
}

confirm() {
  local prompt="$1"
  if [[ "$AUTO_YES" == "true" ]]; then
    log_info "$prompt yes (auto)"
    return 0
  fi

  printf "${YELLOW}%s [y/N] ${RESET}" "$prompt"
  local reply
  read -r reply
  [[ "$reply" =~ ^[yY]$ ]]
}

require_git_root() {
  git rev-parse --show-toplevel 2>/dev/null || {
    log_error "Not inside a git repository."
    exit 1
  }
}

redact_sensitive() {
  sed -E \
    -e 's/([A-Za-z0-9_]*(SECRET|TOKEN|PASSWORD|PASSWD|API[_-]?KEY|PRIVATE[_-]?KEY|ACCESS[_-]?KEY|AUTH)[A-Za-z0-9_]*[[:space:]]*[:=][[:space:]]*)[^[:space:]",;]+/\1[REDACTED_BY_SECURITY]/Ig' \
    -e 's/(Bearer[[:space:]]+)[A-Za-z0-9._~+\/=-]+/\1[REDACTED_BY_SECURITY]/Ig' \
    -e 's/(gh[pousr]_[A-Za-z0-9_]+)/[REDACTED_BY_SECURITY]/g' \
    -e 's/(sk-[A-Za-z0-9_-]{20,})/[REDACTED_BY_SECURITY]/g' \
    -e 's/(xox[baprs]-[A-Za-z0-9-]+)/[REDACTED_BY_SECURITY]/g' \
    -e 's/-----BEGIN [A-Z ]*PRIVATE KEY-----/[REDACTED_BY_SECURITY]/g'
}

build_structural_diff() {
  {
    echo "## git diff --cached --stat"
    git diff --cached --stat || true
    echo
    echo "## git diff --cached --name-status"
    git diff --cached --name-status || true
    echo
    echo "## git diff --cached --numstat"
    git diff --cached --numstat || true
    echo
    echo "## structural signatures"
    git diff --cached --unified=0 --no-ext-diff -- \
      '*.ts' '*.tsx' '*.js' '*.jsx' '*.mjs' '*.cjs' \
      '*.sh' '*.zsh' '*.ps1' '*.py' '*.go' '*.rs' \
      '*.java' '*.kt' '*.swift' '*.php' '*.rb' \
      2>/dev/null |
      awk '
        /^diff --git / { print; next }
        /^@@/ { print; next }
        /^[+-][[:space:]]*(import|export|class|interface|type|enum|function|async function|const .*=>|let .*=>|var .*=>|def |func |struct |trait |impl |public |private |protected )/ { print; next }
        /^[+-][[:space:]]*(alias|function)[[:space:]]/ { print; next }
      ' || true
  } | redact_sensitive | head -c 32000
}

validate_message() {
  local msg="$1"
  [[ "$msg" =~ ^(feat|fix|update|docs|chore|refactor|test|perf|revert)(\([a-z0-9._-]+\))?:[[:space:]][a-z0-9].+ ]]
}

truncate_subject() {
  local msg="$1"
  if ((${#msg} <= 72)); then
    printf '%s\n' "$msg"
    return
  fi

  printf '%s\n' "${msg:0:69}..."
}

common_prefix_scope() {
  local files="$1"
  local first_file first_dir
  first_file=$(printf '%s\n' "$files" | head -n 1)
  first_dir="${first_file%%/*}"

  if [[ -z "$first_dir" || "$first_dir" == "$first_file" ]]; then
    case "$first_file" in
      README.md|*.md) echo "docs" ;;
      .gitignore|.gitattributes) echo "git" ;;
      *) echo "repo" ;;
    esac
    return
  fi

  if printf '%s\n' "$files" | awk -F/ -v dir="$first_dir" 'NF && $1 != dir { exit 1 }'; then
    case "$first_dir" in
      scripts) echo "scripts" ;;
      stow) echo "dotfiles" ;;
      *) echo "$first_dir" ;;
    esac
  else
    echo "repo"
  fi
}

infer_type() {
  local files="$1"
  local statuses="$2"

  if printf '%s\n' "$files" | grep -Eq '(^|/)(test|tests|spec|__tests__)/|(\.spec|\.test)\.'; then
    echo "test"
  elif printf '%s\n' "$files" | grep -Eq '(\.md$|^docs/)'; then
    echo "docs"
  elif printf '%s\n' "$files" | grep -Eq '(^|/)(package-lock|pnpm-lock|yarn.lock|bun.lockb|\.github|\.gitignore|\.gitattributes)'; then
    echo "chore"
  elif printf '%s\n' "$statuses" | grep -Eq '^A[[:space:]]'; then
    echo "feat"
  else
    echo "update"
  fi
}

infer_scope() {
  local files="$1"

  if printf '%s\n' "$files" | grep -Eq '(^|/)git-auto-commit\.sh$|(^|/)git-.*\.sh$|\.git_aliases\.zsh$'; then
    echo "git"
  elif printf '%s\n' "$files" | grep -Eq 'check-architecture'; then
    echo "architecture"
  elif printf '%s\n' "$files" | grep -Eq '(^|/)zsh|\.zsh'; then
    echo "zsh"
  else
    common_prefix_scope "$files"
  fi
}

infer_description() {
  local type="$1"
  local scope="$2"
  local files="$3"
  local statuses="$4"

  if printf '%s\n' "$files" | grep -q 'scripts/git-auto-commit.sh'; then
    echo "add structural auto commit script"
  elif [[ "$scope" == "git" ]] && printf '%s\n' "$statuses" | grep -Eq '^A[[:space:]]'; then
    echo "add commit and push automation"
  elif [[ "$scope" == "architecture" ]]; then
    echo "extend structural validation checks"
  elif [[ "$type" == "docs" ]]; then
    echo "update documentation"
  elif [[ "$type" == "test" ]]; then
    echo "update test coverage"
  elif [[ "$type" == "chore" ]]; then
    echo "update repository configuration"
  else
    echo "update ${scope} workflow"
  fi
}

generate_fallback_message() {
  local statuses files type scope description
  statuses=$(git diff --cached --name-status)
  files=$(printf '%s\n' "$statuses" | awk '{ print $NF }' | sed '/^$/d')

  type=$(infer_type "$files" "$statuses")
  scope=$(infer_scope "$files")
  description=$(infer_description "$type" "$scope" "$files" "$statuses")

  truncate_subject "${type}(${scope}): ${description}"
}

generate_ai_message() {
  local context="$1"
  local prompt
  prompt=$(cat <<'EOF'
Generate a Conventional Commit message from this structural diff.

Security rules:
- Never include secret values, API keys, passwords, tokens, private keys, or credentials.
- If sensitive data appears, replace it with [REDACTED_BY_SECURITY].

Output rules:
- Return only the final commit message.
- No Markdown fences, no backticks, no explanations.
- Format: <type>(<scope>): <short description>
- Use one of: feat, fix, update, docs, chore, refactor, test, perf, revert.
- Keep the first line under 72 characters.

Structural diff:
EOF
)

  {
    printf '%s\n\n' "$prompt"
    printf '%s\n' "$context"
  } | bash -c "$GAC_AI_CMD" 2>/dev/null | redact_sensitive | sed '/^[[:space:]]*$/d' | head -n 5
}

generate_message() {
  local context candidate
  context=$(build_structural_diff)

  if [[ -n "${GAC_AI_CMD:-}" ]]; then
    candidate=$(generate_ai_message "$context" | head -n 1 | tr -d '\r' || true)
    if validate_message "$candidate"; then
      truncate_subject "$candidate"
      return
    fi
    log_warn "GAC_AI_CMD did not return a valid Conventional Commit. Falling back to local inference."
  fi

  generate_fallback_message
}

stage_changes_if_needed() {
  if git diff --cached --quiet; then
    if [[ -z "$(git status --porcelain)" ]]; then
      log_error "Nothing to commit."
      exit 1
    fi

    log_step "No staged changes found. Staging all changes."
    git add -A
  fi
}

commit_changes() {
  local message="$1"
  local commit_args=(-m "$message")

  if [[ "$NO_VERIFY" == "true" ]]; then
    commit_args+=(--no-verify)
  fi

  git commit "${commit_args[@]}"
}

push_changes() {
  local branch upstream
  branch=$(git rev-parse --abbrev-ref HEAD)
  upstream=$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || true)

  if [[ -n "$upstream" ]]; then
    git push
  else
    git push -u origin "$branch"
  fi
}

while (($#)); do
  case "$1" in
    -m|--message)
      MESSAGE="${2:-}"
      shift 2
      ;;
    -y|--yes)
      AUTO_YES=true
      shift
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --no-push)
      NO_PUSH=true
      shift
      ;;
    --no-verify)
      NO_VERIFY=true
      shift
      ;;
    -h|--help|help)
      usage
      exit 0
      ;;
    *)
      log_error "Unknown option: $1"
      usage
      exit 1
      ;;
  esac
done

repo_root=$(require_git_root)
cd "$repo_root"

stage_changes_if_needed

if [[ -z "$MESSAGE" ]]; then
  MESSAGE=$(generate_message)
fi

if ! validate_message "$MESSAGE"; then
  log_error "Invalid Conventional Commit message: $MESSAGE"
  exit 1
fi

MESSAGE=$(truncate_subject "$MESSAGE")

log_info "Commit message: $MESSAGE"

if [[ "$DRY_RUN" == "true" ]]; then
  log_success "Dry run complete. No commit created."
  exit 0
fi

confirm "Create commit with this message?" || {
  log_warn "Aborted before commit."
  exit 0
}

log_step "Creating commit."
commit_changes "$MESSAGE"
log_success "Commit created."

if [[ "$NO_PUSH" == "true" ]]; then
  log_warn "Skipping push because --no-push was provided."
  exit 0
fi

log_step "Pushing branch."
push_changes
log_success "Branch pushed."
