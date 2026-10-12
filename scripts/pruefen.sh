#!/usr/bin/env bash
# pruefen.sh: the three greens from plan/BAUZEITENPLAN.md.
#   1. the test suites exit 0
#   2. every row of the plan carries a source line
#   3. every commit touches only files listed in its row
# Usage: bash scripts/pruefen.sh [<rev-range>]   (default: HEAD only)
# Exit 0: all green. Exit 1: the offending line or file is printed.
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)" || exit 2
cd "$ROOT" || exit 2
RANGE="${1:-HEAD^!}"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/pruefen.XXXXXX")" || exit 2
trap 'rm -rf "$TMP"' EXIT
RC=0

for pkg in fundus/alpha alfaos/Kit; do
  log="$TMP/$(echo "$pkg" | tr / _).log"
  if swift test --package-path "$pkg" > "$log" 2>&1; then
    echo "GREEN tests     $pkg · $(grep -E 'Executed [0-9]+ tests' "$log" | tail -n 1 | sed 's/^[^A-Za-z]*//')"
  else
    echo "RED   tests     $pkg"
    grep -E 'error:|failed' "$log" | head -n 20
    RC=1
  fi
done

python3 -I - "$RANGE" <<'PY' || RC=1
import fnmatch
import re
import subprocess
import sys

RANGE = sys.argv[1]
PLAN = "plan/BAUZEITENPLAN.md"
STATES = {"geplant", "läuft", "erledigt", "wartet auf Johannes", "wartet auf Design"}
ALWAYS = ["plan/BAUZEITENPLAN.md", "plan/STATUS.md", "uebergabe/*"]
ISSUE = re.compile(r"^https://github\.com/JohannesLeoB/ALFA_OS/issues/\d+(#issuecomment-\d+)?$")
HASH = re.compile(r"^[0-9a-f]{7,40}$")
COMMAND = re.compile(r"^`[^`]+` \d{4}-\d{2}-\d{2}( \d{2}:\d{2})?$")
STAMP = re.compile(r"^\d{4}-\d{2}-\d{2} \d{2}:\d{2}$")
MAX_LINES = 120


def git(*args):
    return subprocess.run(["git", *args], capture_output=True, text=True)


def is_commit(token):
    return git("cat-file", "-e", token + "^{commit}").returncode == 0


def rows(text):
    found = []
    for number, line in enumerate(text.splitlines(), 1):
        if not line.startswith("|") or line.startswith("|---") or line.startswith("| Kennung"):
            continue
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        found.append((number, cells))
    return found


red = []

# 2. every row carries a source line
text = open(PLAN, encoding="utf-8").read()
if len(text.splitlines()) > MAX_LINES:
    red.append(f"{PLAN} has {len(text.splitlines())} lines (limit {MAX_LINES})")
seen = set()
for number, cells in rows(text):
    where = f"{PLAN}:{number}"
    if len(cells) != 10:
        red.append(f"{where} · {len(cells)} columns, expected 10")
        continue
    key, _, _, _, paths, state, _, source, checked, session = cells
    if key in seen:
        red.append(f"{where} · {key} appears twice")
    seen.add(key)
    if state not in STATES:
        red.append(f"{where} · {key} · unknown state „{state}“")
    tokens = [t.strip() for t in source.split(",") if t.strip()]
    if not tokens:
        red.append(f"{where} · {key} · no source")
    for token in tokens:
        if HASH.match(token):
            if not is_commit(token):
                red.append(f"{where} · {key} · commit {token} does not exist")
        elif not (ISSUE.match(token) or COMMAND.match(token)):
            red.append(f"{where} · {key} · source „{token}“ is no commit, issue link or `command` date")
    if state == "erledigt" and paths != "-" and not any(HASH.match(t) and is_commit(t) for t in tokens):
        red.append(f"{where} · {key} · erledigt without an existing commit")
    if state == "erledigt" and paths == "-" and not tokens:
        red.append(f"{where} · {key} · erledigt without a source")
    if state in {"läuft", "erledigt"}:
        if not STAMP.match(checked):
            red.append(f"{where} · {key} · {state} without „geprüft am“ (JJJJ-MM-TT HH:MM)")
        if not session:
            red.append(f"{where} · {key} · {state} without session")

# 3. every commit touches only files listed in its row
listed = git("rev-list", "--no-merges", RANGE)
if listed.returncode != 0:
    red.append(f"rev-list {RANGE} failed: {listed.stderr.strip()}")
commits = listed.stdout.split()
for commit in commits:
    short = commit[:7]
    subject = git("log", "-1", "--format=%s", commit).stdout.strip()
    match = re.match(r"^([A-Z][0-9]+): ", subject)
    if not match:
        red.append(f"{short} · subject „{subject}“ does not start with a plan key like „A2: “")
        continue
    key = match.group(1)
    shown = git("show", f"{commit}:{PLAN}")
    if shown.returncode != 0:
        red.append(f"{short} · {PLAN} is missing in this commit")
        continue
    row = next((cells for _, cells in rows(shown.stdout) if cells and cells[0] == key), None)
    if row is None or len(row) != 10:
        red.append(f"{short} · {key} has no row in {PLAN}")
        continue
    globs = [g.strip() for g in row[4].split(",") if g.strip() and g.strip() != "-"] + ALWAYS
    files = git("diff-tree", "--no-commit-id", "--name-only", "-r", "--root", commit).stdout.split()
    for path in files:
        if not any(fnmatch.fnmatchcase(path, g) or path == g for g in globs):
            red.append(f"{short} · {key} · {path} is not in the row's paths")

if red:
    for line in red:
        print(f"RED   {line}")
    sys.exit(1)
print(f"GREEN sources   {PLAN} · {len(seen)} rows")
print(f"GREEN paths     {RANGE} · {len(commits)} commits")
PY

exit "$RC"
