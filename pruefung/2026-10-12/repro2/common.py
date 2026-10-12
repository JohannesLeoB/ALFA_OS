import glob
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
APP = os.path.join(ROOT, "alfaos", "App")
KIT = os.path.join(ROOT, "alfaos", "Kit", "Sources")
CATALOG = os.path.join(APP, "Localizable.xcstrings")
TOKENS = os.path.join(ROOT, "gestaltung", "alfa-interface", "tokens.json")
SHELL = os.path.join(APP, "Resources", "shell.json")
APPS = os.path.join(APP, "Resources", "apps.json")
GENERATED = os.path.join(KIT, "ShellCore", "GeneratedTokens.swift")
DESIGN = os.path.expanduser("~/ALPHA/Design")


def rel(path):
    return os.path.relpath(path, ROOT)


def read(path):
    with open(path, encoding="utf-8") as handle:
        return handle.read()


def lines(path):
    return read(path).split("\n")


def swift_files(*roots, skip_generated=True):
    found = []
    for root in roots:
        found += glob.glob(os.path.join(root, "**", "*.swift"), recursive=True)
    if skip_generated:
        found = [f for f in found if not f.endswith("GeneratedTokens.swift")]
    return sorted(found)


def app_and_kit():
    return swift_files(APP, KIT)


def grep(pattern, files, flags=0):
    regex = re.compile(pattern, flags)
    hits = []
    for path in files:
        for number, text in enumerate(lines(path), 1):
            if regex.search(text):
                hits.append((rel(path), number, text.strip()))
    return hits


def where(path, needle):
    for number, text in enumerate(lines(path), 1):
        if needle in text:
            return "%s:%d" % (rel(path), number)
    return "%s:?" % rel(path)


def catalog():
    return json.loads(read(CATALOG))["strings"]


def de(entry):
    return entry["localizations"]["de"]["stringUnit"]["value"]


def tokens():
    source = json.loads(read(TOKENS))
    flat = []
    for family, content in source.items():
        if isinstance(content, dict) and isinstance(content.get("tokens"), list):
            for token in content["tokens"]:
                flat.append(dict(token, family=family))
    return source, flat


def released():
    found = {}
    for name in ("TEXTE-EINSTELLUNGEN", "TEXTE-EINSTELLUNGEN-ERGAENZUNG", "TEXTE-MAIL", "TEXTE-MAIL-ERGAENZUNG",
                 "TEXTE-GLOBAL", "TEXTE-HEUTE", "TEXTE-KATALOG"):
        path = os.path.join(DESIGN, name + ".json")
        if os.path.exists(path):
            for key, value in json.loads(read(path))["strings"].items():
                found.setdefault(key, value)
    return found


def report(number, title, findings):
    if findings:
        print("FEHLER %s: %s (%d Fundstellen)" % (number, title, len(findings)))
        for item in findings:
            print("  " + item)
        sys.exit(1)
    print("BEHOBEN %s: %s" % (number, title))
    sys.exit(0)
