#!/usr/bin/env python3
"""Compare two ALFA contract folders and check the change log of the new one.

Computes the difference (tokens by file and path with $value, $type and $extensions.alfa status,
source and formerName; components by part, elements by id, texts by key, views by area) and
compares it with the block that NEW/changes.json appends to OLD/changes.json, including the
operation. Checks that all older blocks are unchanged against OLD/changes.json. When NEW appends
no block, the contracts must be identical.
Reports numbered findings: silent change (difference without entry), ghost entry (entry without
difference), wrong op, changed old block, more than one block appended.
A folder without base.tokens.json is no contract: exit 1, no comparison.
Exit 0 = log matches, 1 = findings or no contract, 2 = usage.
Usage: diff_contract.py OLD_DIR NEW_DIR
"""
import json
import os
import sys


def load(folder, name):
    path = os.path.join(folder, name)
    if not os.path.exists(path):
        return None
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def tokens(folder):
    out = {}

    def walk(node, prefix, theme, group_type):
        if isinstance(node, dict):
            if "$value" in node:
                alfa = (node.get("$extensions") or {}).get("alfa") or {}
                out[theme + prefix] = {"$value": node["$value"], "$type": node.get("$type", group_type),
                                       "alfa": {k: alfa.get(k) for k in ("status", "source", "formerName")}}
                return
            for key, sub in node.items():
                if not key.startswith("$"):
                    walk(sub, prefix + "." + key if prefix else key, theme, node.get("$type", group_type))
    for name in sorted(os.listdir(folder)):
        if name.endswith(".tokens.json"):
            theme = name[:-len(".tokens.json")]
            walk(load(folder, name), "", "" if theme == "base" else theme + ":", None)
    return out


def entries(folder):
    comps = (load(folder, "components.json") or {}).get("components", [])
    found = {("token", k): v for k, v in tokens(folder).items()}
    for c in comps:
        body = {k: v for k, v in c.items() if k != "elements"}
        found[("component", c["part"])] = body
        for e in c.get("elements", []):
            found[("element", e["id"])] = e
    for t in (load(folder, "texts.json") or {}).get("texts", []):
        found[("text", t["key"])] = t
    for v in (load(folder, "views.json") or {}).get("views", []):
        found[("view", v["area"])] = v
    return found


def main(argv):
    if len(argv) != 2:
        print(__doc__)
        return 2
    for folder in argv:
        if not os.path.isfile(os.path.join(folder, "base.tokens.json")):
            print("no contract: %s has no base.tokens.json" % folder)
            return 1
    old, new = entries(argv[0]), entries(argv[1])
    diff = {}
    for key in old.keys() | new.keys():
        if key not in new:
            diff[key] = "remove"
        elif key not in old:
            diff[key] = "add"
        elif old[key] != new[key]:
            diff[key] = "change"
    log = load(argv[1], "changes.json")
    old_log = load(argv[0], "changes.json")
    logged = {}
    findings = []
    before = (old_log or {}).get("blocks", [])
    blocks = (log or {}).get("blocks", [])
    if blocks[:len(before)] != before:
        findings.append("changed old block: blocks before the new one differ from %s/changes.json" % argv[0])
    appended = blocks[len(before):]
    if len(appended) > 1:
        findings.append("more than one block appended to %s/changes.json" % argv[0])
    if appended:
        for ch in appended[-1]["changes"]:
            logged[(ch["kind"], ch["id"])] = ch["op"]
            if ch["op"] == "rename" and "from" in ch:
                logged[(ch["kind"], ch["from"])] = "rename"
    for key, op in sorted(diff.items()):
        if key not in logged:
            findings.append("silent change: %s %s (%s)" % (key[0], key[1], op))
        elif logged[key] not in (op, "rename"):
            findings.append("wrong op: %s %s (difference %s, logged %s)" % (key[0], key[1], op, logged[key]))
    for key, op in sorted(logged.items()):
        if key not in diff:
            findings.append("ghost entry: %s %s (%s)" % (key[0], key[1], op))
    findings = ["C-%03d %s" % (i + 1, f) for i, f in enumerate(findings)]
    print("difference: %d, logged: %d" % (len(diff), len(logged)))
    for line in findings:
        print(line)
    print("%d finding(s)" % len(findings) if findings else "log matches")
    return 1 if findings else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
