#!/bin/zsh
# Misst ALFA_OS main neu mit graphify und baut den Schaltschrank. Aufruf: zsh aktualisieren.sh <Arbeitsordner> [--force]
set -e
W=${1:?Arbeitsordner fehlt}; FORCE=$2
HERE=${0:A:h}
REPO=https://github.com/JohannesLeoB/ALFA_OS.git
ZIP=/Users/johannesleoberger/Developer/SKILLS/TECH/graphify-8.zip
mkdir -p $W && cd $W
SHA=$(git ls-remote $REPO refs/heads/main | cut -f1)
LAST=$(cat letzter-stand.txt 2>/dev/null || true)
if [[ "$SHA" == "$LAST" && "$FORCE" != "--force" ]]; then echo "UNVERAENDERT $SHA"; exit 0; fi
if [[ ! -x venv/bin/graphify ]]; then
  python3 -m venv venv
  rm -rf src && mkdir src && unzip -qo $ZIP -d src
  PIP_USE_DEPRECATED=legacy-certs PIP_NO_CACHE_DIR=1 venv/bin/python -m pip install -q src/graphify-8
fi
rm -rf repo && git clone -q --filter=blob:none --no-checkout $REPO repo
git -C repo fetch -q origin DESIGNCHANNEL
git -C repo sparse-checkout set --no-cone "/App/**" "/Sources/**"
git -C repo checkout -q $SHA
E1="Design Vollexport 2910 Transfer - Etappe I"
rm -rf alfa && mkdir -p alfa/code alfa/design
cp -R repo/App repo/Sources alfa/code/
git -C repo show "origin/DESIGNCHANNEL:$E1/alfa-shell.js" > alfa/design/alfa-shell.js
git -C repo show "origin/DESIGNCHANNEL:$E1/alfa-bausteine.js" > alfa/design/alfa-bausteine.js
FILES=$(find alfa/code -name '*.swift' | wc -l | tr -d ' ')
(cd alfa && GRAPHIFY_BACKEND=none HOME=$W ../venv/bin/graphify update . > ../graphify.log 2>&1)
mkdir -p gv
venv/bin/python -I $HERE/bereiche.py alfa/graphify-out/graph.json gv
CDATE=$(git -C repo show -s --format=%cd --date=format:%d.%m.%Y $SHA)
META="{\"sha\":\"$SHA\",\"commitDate\":\"$CDATE\",\"measured\":\"$(date +%d.%m.%Y)\",\"files\":$FILES}"
venv/bin/python -I $HERE/paare.py gv/graph.json pairs.json "$META" meta.json
node $HERE/build.mjs --pairs pairs.json --meta meta.json --out $W/alfa-maschine.html
echo $SHA > letzter-stand.txt
echo "NEU $SHA -> $W/alfa-maschine.html"
