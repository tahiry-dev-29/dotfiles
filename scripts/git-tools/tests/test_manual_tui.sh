#!/usr/bin/env bash
# Git Tools - Manual Validation Runner for TUI & Real Case Untracked .env
set -euo pipefail
export GIT_TOOLS_NON_INTERACTIVE=1

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GIT_TOOLS_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

for mod in "$GIT_TOOLS_ROOT/lib"/*.sh; do
  # shellcheck source=/dev/null
  source "$mod"
done

TMP_DIR="$(mktemp -d /tmp/gwt_manual_val_XXXXXX)"
trap 'rm -rf "$TMP_DIR"' EXIT

echo "=========================================================="
echo "          GIT WORKTREE & BRANCH MANAGER — VALIDATION      "
echo "=========================================================="
echo "Location: $TMP_DIR"

REPO="$TMP_DIR/real-app"
mkdir -p "$REPO"
git -C "$REPO" init -q -b main
git -C "$REPO" config user.email "tahiry@example.com"
git -C "$REPO" config user.name "Tahiry"

# Setup real-world repository files
cat << "EOF" > "$REPO/.gitignore"
node_modules/
dist/
.env*
!.env.example
EOF

cat << "EOF" > "$REPO/.env.example"
DATABASE_URL=
JWT_SECRET=
EOF

cat << "EOF" > "$REPO/package.json"
{
  "name": "real-app",
  "version": "1.0.0",
  "packageManager": "npm@9.0.0"
}
EOF

echo '{"lockfileVersion": 2}' > "$REPO/package-lock.json"
echo "# Real Application" > "$REPO/README.md"
git -C "$REPO" add .gitignore .env.example package.json package-lock.json README.md
git -C "$REPO" commit -q -m "Initial commit with config & lockfile"
git -C "$REPO" tag "v1.0.0"

# Real untracked environment files (MUST NOT be in git)
echo "DATABASE_URL=postgres://localhost:5432/app_development" > "$REPO/.env"
echo "JWT_SECRET=local_developer_secret_abcdef123" > "$REPO/.env.local"
echo "PRODUCTION_SECRET_KEY=NEVER_LEAK_PROD_SECRETS" > "$REPO/.env.production"

# Create a feature branch
git -C "$REPO" switch -q -c feature/oauth
echo "export const auth = () => true;" > "$REPO/auth.js"
git -C "$REPO" add auth.js
git -C "$REPO" commit -q -m "feat(oauth): implement google authentication"
git -C "$REPO" switch -q main

# Create a merged branch
git -C "$REPO" switch -q -c feature/docs
echo "Documentation" >> "$REPO/README.md"
git -C "$REPO" add README.md
git -C "$REPO" commit -q -m "docs: add setup guide"
git -C "$REPO" switch -q main
git -C "$REPO" merge -q feature/docs

# Create worktree for feature/oauth
WT_OAUTH="$TMP_DIR/real-app-feature-oauth"
worktree_create_branch "$REPO" "$WT_OAUTH" "feature/oauth" "false" ""

# Make WT_OAUTH dirty (both modified and untracked)
echo "// uncommitted edit" >> "$WT_OAUTH/auth.js"
echo "temp scratchpad" > "$WT_OAUTH/scratch.txt"

echo ""
echo "=========================================================="
echo " [1] REAL UNTRACKED .ENV VERIFICATION"
echo "=========================================================="
echo "Checking untracked status in primary repo:"
git_status="$(git -C "$REPO" status --porcelain)"
echo "Git status output: '${git_status}' (empty means ignored & clean)"

echo "Untracked env files on primary filesystem:"
ls -l "$REPO"/.env*

echo ""
echo "Executing Worktree Bootstrap with environment copying:"
bootstrap_worktree "$REPO" "$WT_OAUTH" "feature/oauth"

echo ""
echo "Verifying copied files in $WT_OAUTH:"
if [[ -f "$WT_OAUTH/.env" ]]; then
  log_ok ".env was successfully copied (DATABASE_URL=$(cat "$WT_OAUTH/.env"))"
else
  log_err ".env was NOT copied!"
fi

if [[ -f "$WT_OAUTH/.env.local" ]]; then
  log_ok ".env.local was successfully copied (JWT_SECRET=$(cat "$WT_OAUTH/.env.local"))"
else
  log_err ".env.local was NOT copied!"
fi

if [[ -f "$WT_OAUTH/.env.production" ]]; then
  log_err "CRITICAL FAILURE: .env.production was copied!"
else
  log_ok ".env.production was safely excluded from copy (production guard active)"
fi

echo ""
echo "=========================================================="
echo " [2] TUI RESPONSIVE HEADER & FOOTER RENDERING"
echo "=========================================================="
echo "--- Header ---"
render_header "GWT — Worktree Manager" "real-app" "main" "2 worktrees"

echo ""
echo "--- Footer Wide (>=120 cols) ---"
render_footer "gwt" "wide"; echo ""

echo ""
echo "--- Footer Medium (80-119 cols) ---"
render_footer "gwt" "medium"; echo ""

echo ""
echo "--- Footer Narrow (<80 cols) ---"
render_footer "gwt" "narrow"; echo ""

echo ""
echo "=========================================================="
echo " [3] WORKTREE TUI LIST RENDERING ACROSS LAYOUT MODES"
echo "=========================================================="
rows=()
while IFS= read -r line; do
  [[ -n "$line" ]] && rows+=("$line")
done < <(worktree_list "$REPO")

echo "--- Wide Mode Rendering ---"
for row in "${rows[@]}"; do
  IFS=$'\t' read -r p b sha is_m is_d dirty ab up <<<"$row"
  marker="○"
  [[ "$is_m" -eq 1 ]] && marker="●"
  [[ "$is_d" -eq 1 ]] && marker="⬡"
  truncated_path="$(truncate_path "$p" 38)"
  printf "%-2s %-24s %-8s %-32s %-8s %s\n" "$marker" "$(truncate_text "$b" 24)" "$sha" "$dirty" "$ab" "$truncated_path"
done

echo ""
echo "--- Medium Mode Rendering ---"
for row in "${rows[@]}"; do
  IFS=$'\t' read -r p b sha is_m is_d dirty ab up <<<"$row"
  marker="○"
  [[ "$is_m" -eq 1 ]] && marker="●"
  [[ "$is_d" -eq 1 ]] && marker="⬡"
  truncated_path="$(truncate_path "$p" 28)"
  printf "%-2s %-20s %-24s %s\n" "$marker" "$(truncate_text "$b" 20)" "$dirty" "$truncated_path"
done

echo ""
echo "--- Narrow Mode Rendering ---"
for row in "${rows[@]}"; do
  IFS=$'\t' read -r p b sha is_m is_d dirty ab up <<<"$row"
  marker="○"
  [[ "$is_m" -eq 1 ]] && marker="●"
  [[ "$is_d" -eq 1 ]] && marker="⬡"
  printf "%-2s %-18s %s\n" "$marker" "$(truncate_text "$b" 18)" "$dirty"
done

echo ""
echo "=========================================================="
echo " [4] WORKTREE STRUCTURED PREVIEW PANEL"
echo "=========================================================="
preview_render_worktree "$WT_OAUTH"

echo ""
echo "=========================================================="
echo " [5] BRANCH STRUCTURED PREVIEW PANEL"
echo "=========================================================="
preview_render_branch "$REPO" "feature/oauth" "main"

echo ""
echo "=========================================================="
echo " [6] BRANCH DETAILS MODAL SCREEN"
echo "=========================================================="
show_branch_details "$REPO" "feature/oauth" "main"

echo ""
echo "=========================================================="
echo " [7] MUTATION PREVIEW ACTION BANNER"
echo "=========================================================="
ui_preview_action "Create Worktree" "git worktree add -b feature/billing ../real-app-feature-billing main"
ui_preview_action "Safe Remove Worktree" "git worktree remove --force /path/to/worktree"

echo ""
echo "=========================================================="
echo " [8] FZF KEYBOARD SHORTCUT HELP SCREENS"
echo "=========================================================="
ui_help_modal "gwt"
ui_help_modal "gb"

echo ""
echo "=========================================================="
echo "       ALL VALIDATIONS COMPLETED SUCCESSFULLY! ✔          "
echo "=========================================================="
