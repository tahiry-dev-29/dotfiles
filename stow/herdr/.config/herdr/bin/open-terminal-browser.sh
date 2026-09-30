#!/bin/sh
# Crée un nouvel onglet et lance terminal-browser dedans
TAB_RESULT=$(herdr tab create --focus --label "terminal-browser" 2>/dev/null)
PANE_ID=$(echo "$TAB_RESULT" | python3 -c 'import sys,json; d=json.load(sys.stdin); rp=d.get("result",{}).get("root_pane",{}); print(rp.get("pane_id",""))')
if [ -n "$PANE_ID" ]; then
  herdr pane run "$PANE_ID" terminal-browser
else
  terminal-browser
fi
