#!/usr/bin/env python3
import argparse
import hashlib
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
DEFAULT_SOURCE = os.path.join(REPO, "gestaltung", "alfa-interface", "tokens.json")
DEFAULT_WEB = os.path.join(REPO, "gestaltung", "alfa-interface", "tokens.css")
DEFAULT_SWIFT = os.path.join(REPO, "alfaos", "Kit", "Sources", "ShellCore", "GeneratedTokens.swift")
WEB_HEAD = "/* ALFA Interface — generated from tokens.json */\n"
INDENT = "    "
VARIABLE = re.compile(r"^\s*--([a-z0-9-]+):", re.M)
STYLE_FIELDS = (("fontSize", "font-size"), ("lineHeight", "line-height"),
                ("fontWeight", "font-weight"), ("letterSpacing", "letter-spacing"))


def alias(value):
    if isinstance(value, str) and value.startswith("{") and value.endswith("}"):
        return "var(--" + value[1:-1] + ")"
    return value


def web_output(source):
    themes = [t["id"] for t in source["color"]["themes"]]
    first = themes[0]
    out = [':root, [data-theme="' + first + '"] {']
    per = {t: [] for t in themes[1:]}

    def emit(token):
        value = token["value"]
        if isinstance(value, dict):
            out.append("  --%s: %s;" % (token["name"], alias(value.get(first, next(iter(value.values()))))))
            for theme in themes[1:]:
                if theme in value:
                    per[theme].append("  --%s: %s;" % (token["name"], alias(value[theme])))
        else:
            out.append("  --%s: %s;" % (token["name"], alias(value)))
            if isinstance(value, str) and value.startswith("{"):
                for theme in themes[1:]:
                    per[theme].append("  --%s: %s;" % (token["name"], alias(value)))

    for token in source["color"]["tokens"]:
        emit(token)
    for token in source.get("shadow", {}).get("tokens", []):
        emit(token)
    out.append("}")
    for theme in themes[1:]:
        out.append('[data-theme="%s"] {' % theme)
        out += per[theme]
        out.append("}")
    out.append(":root {")
    for family, value in source.items():
        if family in ("color", "shadow", "type") or not (isinstance(value, dict) and isinstance(value.get("tokens"), list)):
            continue
        for token in value["tokens"]:
            out.append("  --%s: %s;" % (token["name"], alias(token["value"])))
    for key, stack in source["type"].get("families", {}).items():
        out.append("  --font-%s: %s;" % (key, stack))
    out.append("}")
    for group in source["type"]["groups"]:
        group_family = group.get("family")
        for style in group["styles"]:
            out.append("." + style["name"] + " {")
            family = style.get("family", group_family)
            if family:
                out.append("  font-family: var(--font-%s);" % family)
            for key, css in STYLE_FIELDS:
                if key in style:
                    value = style[key]
                    if isinstance(value, (int, float)) and key in ("fontSize", "letterSpacing"):
                        value = "%spx" % value
                    out.append("  %s: %s;" % (css, value))
            out.append("}")
    return (WEB_HEAD + "\n".join(out) + "\n").encode("utf-8")


def camel(name):
    first, *rest = name.split("-")
    return first + "".join(part[:1].upper() + part[1:] for part in rest)


def unique(names):
    seen = []
    for name in names:
        if name not in seen:
            seen.append(name)
    return seen


def swift_block(type_name, names):
    lines = ["public extension %s {" % type_name]
    for name in names:
        lines.append('%sstatic let %s = %s("%s")' % (INDENT, camel(name), type_name, name))
    lines.append("")
    lines.append("%sstatic let all: [%s] = [" % (INDENT, type_name))
    for name in names:
        lines.append("%s%s%s," % (INDENT, INDENT, camel(name)))
    lines.append("%s]" % INDENT)
    lines.append("}")
    return "\n".join(lines)


def swift_output(source, source_bytes, web_bytes):
    names = unique(VARIABLE.findall(web_bytes.decode("utf-8")))
    styles = unique(s["name"] for g in source["type"]["groups"] for s in g["styles"])
    head = "// tokens.json version %s sha256 %s" % (source["version"], hashlib.sha256(source_bytes).hexdigest())
    text = head + "\n\n" + swift_block("ThemeKey", names) + "\n\n" + swift_block("TextKey", styles) + "\n"
    return text.encode("utf-8")


def build(source_path):
    with open(source_path, "rb") as handle:
        source_bytes = handle.read()
    source = json.loads(source_bytes.decode("utf-8"))
    web = web_output(source)
    return web, swift_output(source, source_bytes, web)


def read_or_none(path):
    try:
        with open(path, "rb") as handle:
            return handle.read()
    except OSError:
        return None


def write(path, data):
    os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
    with open(path, "wb") as handle:
        handle.write(data)


def main(argv):
    parser = argparse.ArgumentParser(description="Generate web variables and Swift keys from tokens.json")
    parser.add_argument("--source", default=DEFAULT_SOURCE)
    parser.add_argument("--web", default=DEFAULT_WEB)
    parser.add_argument("--swift", default=DEFAULT_SWIFT)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args(argv)
    try:
        web, swift = build(args.source)
    except (OSError, ValueError, KeyError) as error:
        print("tokens_generate: cannot read the source: %s" % error, file=sys.stderr)
        return 2
    outputs = ((args.web, web), (args.swift, swift))
    if args.check:
        stale = [path for path, data in outputs if read_or_none(path) != data]
        for path in stale:
            print("stale or missing: %s (run scripts/tokens_generate.py)" % os.path.basename(path), file=sys.stderr)
        if not stale:
            print("tokens_generate: outputs match the source")
        return 1 if stale else 0
    for path, data in outputs:
        write(path, data)
        print("wrote %s" % path)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
