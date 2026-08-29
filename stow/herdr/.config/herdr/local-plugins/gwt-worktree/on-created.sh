#!/usr/bin/env bash
# Hook Herdr worktree.created — copies root .env* files from the main
# checkout then runs pnpm install --frozen-lockfile in each directory
# containing a package.json. Headless, never interactive, never fatal.
set -uo pipefail

STATE_LOG="${GWT_SETUP_LOG:-$HOME/.cache/gwt-worktree/setup.log}"
mkdir -p "$(dirname "$STATE_LOG")" 2>/dev/null || true
exec > >(tee -a "$STATE_LOG") 2>&1

log() { printf '[gwt-setup %s] %s\n' "$(date '+%H:%M:%S')" "$*"; }

wt=""
if [[ -n "${HERDR_PLUGIN_EVENT_JSON:-}" ]] && command -v jq >/dev/null 2>&1; then
  wt=$(printf '%s' "$HERDR_PLUGIN_EVENT_JSON" |
    jq -r '.worktree.path // .data.worktree.path // .workspace.cwd // .data.workspace.cwd // empty' 2>/dev/null ||
    true)
fi
if [[ -z "$wt" || ! -d "$wt" ]]; then
  log "skip: worktree path not found in event"
  exit 0
fi
log "new worktree: $wt"

main_root=$(git -C "$wt" worktree list --porcelain 2>/dev/null | sed -n 's/^worktree //p' | head -n1)
if [[ "$main_root" == "$wt" ]]; then
  main_root=""
fi

copied=0
if [[ -n "$main_root" ]]; then
  for f in "$main_root"/.env*; do
    [[ -f "$f" ]] || continue
    dest="$wt/$(basename "$f")"
    if [[ ! -e "$dest" ]]; then
      cp "$f" "$dest" && { log "env copied: $(basename "$f")"; copied=$((copied + 1)); }
    fi
  done
else
  log "main checkout not found → skipping env copy"
fi
log "envs copied: $copied"

if ! find "$wt" -maxdepth 3 -name pnpm-lock.yaml -print -quit 2>/dev/null | grep -q .; then
  log "no pnpm-lock.yaml → skipping pnpm"
  log "done"
  exit 0
fi

mapfile -t dirs < <(find "$wt" -name package.json -not -path '*/node_modules/*' -exec dirname {} \; 2>/dev/null | sort -u)
if [[ ${#dirs[@]} -eq 0 ]]; then
  log "no package.json → nothing to install"
  log "done"
  exit 0
fi

failed=0
for d in "${dirs[@]}"; do
  rel=${d#"$wt"/}
  [[ -z "$rel" || "$rel" == "$d" ]] && rel="."
  log "pnpm install --frozen-lockfile → $rel"
  if (cd "$d" && pnpm install --frozen-lockfile); then
    log "OK: $rel"
  else
    log "FAILED: $rel (lockfile out of sync?)"
    failed=$((failed + 1))
  fi
done
log "done (${#dirs[@]} installs, failed: $failed)"
