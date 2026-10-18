#!/usr/bin/env python3
import argparse
import json
import os
import re
import subprocess
import sys
import urllib.request

ROOT = subprocess.run(["git", "rev-parse", "--show-toplevel"], capture_output=True, text=True).stdout.strip()
LIMITS = os.path.join(ROOT, "scripts", "limits.json")
TEST_FUNC = re.compile(r"^\s*func test", re.M)
URL = re.compile(r"https?://[^\s)>\]\"'`]+")


def out(cmd):
    return subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True)


def tracked():
    return [p for p in out(["git", "ls-files"]).stdout.split("\n") if p and os.path.exists(os.path.join(ROOT, p))]


def counts():
    files = tracked()
    docs = [p for p in files if p.endswith(".md") and not p.startswith("docs/adr/") and not p.startswith(".claude/agents/")]
    adrs = [p for p in files if p.startswith("docs/adr/") and p.endswith(".md")]
    tests = [p for p in files if p.endswith(".swift") and "Tests" in p]
    functions = 0
    lines = 0
    for p in tests:
        text = open(os.path.join(ROOT, p), errors="replace").read()
        functions += len(TEST_FUNC.findall(text))
        lines += text.count("\n")
    return {"docs": len(docs), "adrs": len(adrs), "testFunctions": functions, "testLines": lines, "testFiles": len(tests)}


def limits_of(rev):
    result = out(["git", "show", "%s:scripts/limits.json" % rev])
    if result.returncode != 0:
        return None
    return json.loads(result.stdout)


def check_lint():
    result = out(["swiftlint", "lint", "--strict", "--quiet"])
    text = (result.stdout + result.stderr).strip()
    if result.returncode != 0 or text:
        return False, "swiftlint found violations:\n" + text
    return True, "swiftlint: 0 violations"


def check_generators():
    problems = []
    for script in ("design_generate.py", "tokens_generate.py"):
        result = out([sys.executable, os.path.join("scripts", script), "--check"])
        if result.returncode != 0:
            problems.append("%s: %s" % (script, (result.stdout + result.stderr).strip()))
    if problems:
        return False, "\n".join(problems)
    return True, "generators: outputs match the sources"


def check_limits(base):
    now = counts()
    limit = json.load(open(LIMITS))
    problems = []
    for key, value in now.items():
        if key in limit and value > limit[key]:
            problems.append("%s is %d, limit %d" % (key, value, limit[key]))
    previous = limits_of(base)
    if previous:
        for key, value in limit.items():
            if key in previous and value > previous[key]:
                problems.append("limit %s was raised from %d to %d; limits only fall" % (key, previous[key], value))
    if problems:
        return False, "\n".join(problems)
    return True, "limits: " + ", ".join("%s %d/%d" % (k, v, limit.get(k, -1)) for k, v in now.items())


def check_stray():
    nested = []
    for dirpath, dirnames, _ in os.walk(ROOT):
        dirnames[:] = [d for d in dirnames if d not in (".build", ".build-xcode", "dist", "node_modules", ".swiftpm")]
        if ".git" in dirnames or ".git" in os.listdir(dirpath):
            if os.path.realpath(dirpath) != os.path.realpath(ROOT):
                nested.append(os.path.relpath(dirpath, ROOT))
                dirnames[:] = []
        if ".git" in dirnames:
            dirnames.remove(".git")
    if nested:
        return False, "nested repositories or worktrees: " + ", ".join(nested)
    return True, "no nested repositories"


def check_links():
    bad = []
    seen = set()
    for p in tracked():
        if not p.endswith(".md"):
            continue
        for url in URL.findall(open(os.path.join(ROOT, p), errors="replace").read()):
            url = url.rstrip(".,;:")
            if url in seen:
                continue
            seen.add(url)
            try:
                request = urllib.request.Request(url, method="HEAD", headers={"User-Agent": "alfa-check"})
                code = urllib.request.urlopen(request, timeout=15).status
            except Exception as error:
                code = getattr(error, "code", str(error))
            if not isinstance(code, int) or code >= 400:
                bad.append("%s in %s: %s" % (url, p, code))
    if bad:
        return False, "dead links:\n" + "\n".join(bad)
    return True, "links: %d checked" % len(seen)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--links", action="store_true")
    parser.add_argument("--strict-stray", action="store_true")
    parser.add_argument("--show", action="store_true")
    args = parser.parse_args()
    if args.show:
        print(json.dumps(counts(), indent=2))
        return 0
    base = os.environ.get("LIMITS_BASE", "HEAD")
    results = [check_lint(), check_generators(), check_limits(base)]
    stray_ok, stray_message = check_stray()
    if args.strict_stray:
        results.append((stray_ok, stray_message))
    elif not stray_ok:
        print("warning: " + stray_message)
    if args.links:
        results.append(check_links())
    failed = False
    for ok, message in results:
        print(("ok    " if ok else "RED   ") + message)
        failed = failed or not ok
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
