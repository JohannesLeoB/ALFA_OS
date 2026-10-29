#!/usr/bin/env python3
"""Check the cross-references of an ALFA contract folder.

Checks: resolver $ref files exist; every alias inside the token files and in components.json
resolves in each theme on its own (base, then that theme, as alfa.resolver.json orders it; an
alias that exists in one theme only is a finding); element ids unique; every element id in views.json exists in components.json; every
textKey and feedbackKey exists in texts.json; with --areas: views.json has each named area;
with drafts: every data-id and every data-part name in the drafts has its entry in
components.json, and the reverse. A data-id or data-part value with {{ }} in a draft is a finding.
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


def ref_files(sources):
    return [r["$ref"] for r in sources]


def theme_files(resolver, folder):
    """Return {theme: [token files in resolution order]} as the resolver orders them."""
    if resolver:
        order = resolver.get("resolutionOrder", [])
        themes = {}
        names = []
        for step in order:
            kind, _, name = step["$ref"].lstrip("#/").partition("/")
            if kind == "modifiers":
                names = list(resolver.get("modifiers", {}).get(name, {}).get("contexts", {}))
        for theme in names:
            files = []
            for step in order:
                kind, _, name = step["$ref"].lstrip("#/").partition("/")
                if kind == "sets":
                    files += ref_files(resolver.get("sets", {}).get(name, {}).get("sources", []))
                elif kind == "modifiers":
                    files += ref_files(resolver["modifiers"].get(name, {}).get("contexts", {}).get(theme, []))
            themes[theme] = files
        return themes
    return {}


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
    themes = theme_files(resolver, folder)
    if not themes:
        findings.append("no themes resolved: alfa.resolver.json missing or without a theme modifier")
    tokens, token_aliases = {}, {}
    for theme, files in themes.items():
        tokens[theme], token_aliases[theme] = set(), set()
        for name in files:
            data = load(folder, name)
            if data is None:
                continue
            token_paths(data, "", tokens[theme])
            token_aliases[theme] |= set(re.findall(r'"(\{[A-Za-z0-9.]+\})"', json.dumps(data)))
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
    for theme in themes:
        if not tokens[theme]:
            findings.append("no tokens in theme %s" % theme)
        for a in sorted(aliases | token_aliases[theme]):
            m = ALIAS.match(a or "")
            if a and (not m or m.group(1) not in tokens[theme]):
                findings.append("token alias does not resolve in %s: %s" % (theme, a))
    drawn, parts = set(), set()
    for d in drafts:
        with open(d, encoding="utf-8") as f:
            text = f.read()
        for kind, found in (("data-id", re.findall(r'data-id="([^"]+)"', text)),
                            ("data-part", re.findall(r'data-part="([^"]+)"', text))):
            for value in sorted(set(found)):
                if "{{" in value or "}}" in value:
                    findings.append("%s with {{ }} in %s cannot be checked: %s" % (kind, d, value))
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
