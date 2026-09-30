#!/bin/sh
python3 << 'PY'
import json, os
path = os.path.expanduser("~/.config/BraveSoftware/Brave-Browser/Default/Bookmarks")
out = os.path.expanduser("~/.config/herdr/terminal-browser-bookmarks.txt")
with open(path) as f: d=json.load(f)
lines=[]
for root in ("bookmark_bar","other","synced"):
    for c in d.get("roots",{}).get(root,{}).get("children",[]):
        def e(n,l):
            if n.get("type")=="url" and n.get("url"): l.append(f"{n['name']}\t{n['url']}")
            for x in n.get("children",[]): e(x,l)
        e(c,lines)
with open(out,"w") as f: f.write("# Favoris Brave\n"); [f.write(l+"\n") for l in lines]
print(f"Exporté {len(lines)} favoris -> {out}")
PY
