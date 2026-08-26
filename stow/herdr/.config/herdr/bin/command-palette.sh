#!/bin/sh
# Stable launcher for the herdr command-palette plugin (hash dir-safe).
script=$(ls -d "$HOME/.config/herdr/plugins/github"/command-palette-*/bin/herdr-command-palette 2>/dev/null | head -n1)
[ -n "$script" ] && exec python3 "$script" "$@"
echo "command-palette plugin script not found" >&2
exit 1
