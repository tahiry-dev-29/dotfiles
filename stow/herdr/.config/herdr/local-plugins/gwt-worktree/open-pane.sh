#!/usr/bin/env bash
# Resolves the current repo from the Herdr context, then opens the manager pane.
set -euo pipefail

cwd="${HERDR_ACTIVE_PANE_CWD:-$PWD}"
if [[ -n "${HERDR_PLUGIN_CONTEXT_JSON:-}" ]] && command -v jq >/dev/null 2>&1; then
  c=$(printf '%s' "$HERDR_PLUGIN_CONTEXT_JSON" |
    jq -r '.cwd // .pane_cwd // .workspace_cwd // empty' 2>/dev/null || true)
  [[ -n "$c" && -d "$c" ]] && cwd="$c"
fi

root=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null || true)
if [[ -z "$root" ]]; then
  printf 'gwt: %s is not in a git repository\n' "$cwd" >&2
  exit 1
fi

bin="${HERDR_BIN_PATH:-$(command -v herdr)}"

# Target workspace = the one from the invocation context (UI focus),
# otherwise the caller's own.
ws=$(printf '%s' "${HERDR_PLUGIN_CONTEXT_JSON:-}" |
  jq -r '.workspace_id // .tab.workspace_id // .workspace.id // empty' 2>/dev/null || true)
[[ -z "$ws" ]] && ws="${HERDR_WORKSPACE_ID:-}"

# Reuse an already-open manager pane in this workspace instead of stacking a
# new zoomed pane on every keypress.
if [[ -n "$ws" ]]; then
  old=$("$bin" pane list --workspace "$ws" 2>/dev/null |
    jq -r '[.result.panes[]? | select(.label == "gwt worktrees") | .pane_id] | first // empty' 2>/dev/null || true)
  if [[ -n "$old" ]] && "$bin" plugin pane focus "$old" >/dev/null 2>&1; then
    exit 0
  fi
fi

exec "$bin" plugin pane open --plugin gwt-worktree --entrypoint manager --placement zoomed --cwd "$root"
