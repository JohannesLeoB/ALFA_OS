#!/bin/zsh
# Misst ALFA_OS main und den Design-Vertrag neu und baut die Werkbank. Aufruf: zsh aktualisieren.sh <Arbeitsordner> [--force]
set -e
W=${1:?Arbeitsordner fehlt}; FORCE=$2
HERE=${0:A:h}
REPO=https://github.com/JohannesLeoB/ALFA_OS.git
ZIP=/Users/johannesleoberger/Developer/SKILLS/TECH/graphify-8.zip
E1="Design Vollexport 2910 Transfer - Etappe I"
E2="Design Vollexport EDITOREN 2910 Transfer - Zulieferer"
mkdir -p $W && cd $W
SHA=$(git ls-remote $REPO refs/heads/main | cut -f1)
if [[ "$SHA" == "$(cat letzter-stand.txt 2>/dev/null)" && "$FORCE" != "--force" ]]; then echo "UNVERAENDERT $SHA"; exit 0; fi
if [[ ! -x venv/bin/graphify ]]; then
  python3 -m venv venv
  rm -rf src && mkdir src && unzip -qo $ZIP -d src
  PIP_USE_DEPRECATED=legacy-certs PIP_NO_CACHE_DIR=1 venv/bin/python -m pip install -q src/graphify-8
fi
rm -rf repo && git clone -q --filter=blob:none --no-checkout $REPO repo
git -C repo fetch -q origin DESIGNCHANNEL
git -C repo sparse-checkout set --no-cone "/App/**" "/Sources/**" "/Resources/*.json" "/Resources/Localizable.xcstrings" "/Package.swift"
git -C repo checkout -q $SHA
DSHA=$(git -C repo rev-parse origin/DESIGNCHANNEL)
rm -rf alfa design && mkdir -p alfa/code design/contract
cp -R repo/App repo/Sources repo/Resources repo/Package.swift alfa/code/
for f in texts.json components.json base.tokens.json theme-light.tokens.json; do git -C repo show "origin/DESIGNCHANNEL:$E1/contract/$f" > design/contract/$f; done
python3 -I - "$W/repo" "$E1" "$E2" "$W/bogen.json" <<'PY'
import subprocess, json, sys
repo, e1, e2, out = sys.argv[1:]
res = []
for src, folder, skip in [("E1", e1, ()), ("E2", e2, ("v1", "v2", "Entwurf", "Shell", "Bestaetigen", "Bausteinbibliothek"))]:
    for p in subprocess.run(["git", "-C", repo, "ls-tree", "--name-only", "origin/DESIGNCHANNEL", folder + "/"], capture_output=True, text=True).stdout.split("\n"):
        n = p.rsplit("/", 1)[-1]
        if not n.endswith(".dc.html") or any(s in n for s in skip): continue
        lines = subprocess.run(["git", "-C", repo, "show", f"origin/DESIGNCHANNEL:{p}"], capture_output=True, text=True).stdout.count("\n")
        res.append(dict(name=n[:-8], source=src, lines=lines))
json.dump(res, open(out, "w"), ensure_ascii=False)
PY
(cd alfa && GRAPHIFY_BACKEND=none HOME=$W ../venv/bin/graphify update . > ../graphify.log 2>&1)
GRAPH=alfa/graphify-out/graph.json
CDATE=$(git -C repo show -s --format=%cd --date=format:%d.%m.%Y $SHA)
META="{\"sha\":\"$SHA\",\"commitDate\":\"$CDATE\",\"measured\":\"$(date +%d.%m.%Y)\",\"designSha\":\"$DSHA\"}"
python3 -I $HERE/model.py $GRAPH alfa/code design bogen.json "$META" model.json
node $HERE/build.mjs --model model.json --out $W/alfa-maschine.html
echo $SHA > letzter-stand.txt
echo "NEU $SHA -> $W/alfa-maschine.html"
