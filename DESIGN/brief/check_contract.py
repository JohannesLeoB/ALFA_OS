#!/usr/bin/env python3
"""Check the cross-references of an ALFA contract folder.

Checks: resolver $ref files exist; every alias inside the token files and in components.json
resolves; element ids unique; every element id in views.json exists in components.json; every
textKey and feedbackKey exists in texts.json; with --areas: views.json has each named area;
with drafts: every data-id and every data-part name in the drafts has its entry in
components.json, and the reverse.
Exit 0 = no findings, 1 = findings, 2 = usage.
Usage: check_contract.py CONTRACT_DIR [--areas shell,mail,settings] [DRAFT.dc.html ...]
"""
import json
import os
import re
import sys

ALIAS = re.compile(r"^\{([A-Za-z0-9.]+)\}$")


def load(folder, name):
    path = os.path.join(folder, name)
    if not os.path.exists(path):
        return None
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def token_paths(node, prefix, out):
    if isinstance(node, dict):
        if "$value" in node:
            out.add(prefix)
            return
        for key, sub in node.items():
            if not key.startswith("$"):
                token_paths(sub, prefix + "." + key if prefix else key, out)


def main(argv):
    if not argv:
        print(__doc__)
        return 2
    folder, rest = argv[0], argv[1:]
    areas = []
    if "--areas" in rest:
        i = rest.index("--areas")
        areas = rest[i + 1].split(",")
        rest = rest[:i] + rest[i + 2:]
    drafts = rest
    findings = []
    resolver = load(folder, "alfa.resolver.json")
    if resolver:
        refs = []
        for s in resolver.get("sets", {}).values():
            refs += s.get("sources", [])
        for m in resolver.get("modifiers", {}).values():
            for srcs in m.get("contexts", {}).values():
                refs += srcs
        for r in refs:
            if not os.path.exists(os.path.join(folder, r["$ref"])):
                findings.append("resolver source missing: %s" % r["$ref"])
    tokens = set()
    token_aliases = set()
    for name in sorted(os.listdir(folder)):
        if name.endswith(".tokens.json"):
            data = load(folder, name)
            token_paths(data, "", tokens)
            token_aliases |= set(re.findall(r'"(\{[A-Za-z0-9.]+\})"', json.dumps(data)))
    comps = (load(folder, "components.json") or {}).get("components", [])
    views = (load(folder, "views.json") or {}).get("views", [])
    texts = {t["key"] for t in (load(folder, "texts.json") or {}).get("texts", [])}

    ids, keys, aliases = [], set(), set()
    for c in comps:
        for value in list(c.get("measures", {}).values()) + [c.get("layer", "")]:
            aliases.add(value)
        for state in c.get("states", []):
            aliases.update(state.get("tokens", {}).values())
        for mech in c.get("mechanics", []):
            aliases.add(mech.get("transition", ""))
        for e in c.get("elements", []):
            ids.append(e["id"])
            if "textKey" in e:
                keys.add(e["textKey"])
    for dup in sorted({i for i in ids if ids.count(i) > 1}):
        findings.append("element id twice in components.json: %s" % dup)
    idset = set(ids)
    for v in views:
        for lane in v.get("lanes", {}).values():
            for i in lane.get("header", []) + lane.get("footer", []):
                if i not in idset:
                    findings.append("views.json %s: element %s not in components.json" % (v["area"], i))
        for a in v.get("actions", []):
            if a["element"] not in idset:
                findings.append("views.json %s: action %s element %s not in components.json" % (v["area"], a["id"], a["element"]))
            if "feedbackKey" in a:
                keys.add(a["feedbackKey"])
        keys.update(v.get("textKeys", []))
    for k in sorted(keys - texts):
        findings.append("text key not in texts.json: %s" % k)
    found = {v["area"] for v in views}
    for a in areas:
        if a not in found:
            findings.append("views.json: area %s missing" % a)
    if tokens:
        for a in sorted(aliases | token_aliases):
            m = ALIAS.match(a or "")
            if a and (not m or m.group(1) not in tokens):
                findings.append("token alias does not resolve: %s" % a)
    else:
        findings.append("no *.tokens.json in %s" % folder)
    drawn, parts = set(), set()
    for d in drafts:
        with open(d, encoding="utf-8") as f:
            text = f.read()
        drawn |= set(re.findall(r'data-id="([^"{}]+)"', text))
        parts |= set(re.findall(r'data-part="([^"{}]+)"', text)) | set(re.findall(r'part:\s*"([a-z0-9-]+)"', text))
    if drafts:
        known = {c["part"] for c in comps}
        for p in sorted(parts - known):
            findings.append("data-part in drafts not in components.json: %s" % p)
        for p in sorted(known - parts):
            findings.append("component has no data-part in drafts: %s" % p)
        for p in sorted({c["part"] for c in comps if [x["part"] for x in comps].count(c["part"]) > 1}):
            findings.append("part twice in components.json: %s" % p)
        for i in sorted(drawn - idset):
            findings.append("data-id in drafts not in components.json: %s" % i)
        for i in sorted(idset - drawn):
            findings.append("element id has no data-id in drafts: %s" % i)
    for line in findings:
        print(line)
    print("%d finding(s)" % len(findings) if findings else "consistent")
    return 1 if findings else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
