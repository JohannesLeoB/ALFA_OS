import importlib.util
import json
import os
import re
import sys

_spec = importlib.util.spec_from_file_location("common", os.path.join(os.path.dirname(os.path.abspath(__file__)), "common.py"))
c = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(c)

gen = c.read(c.GENERATED)
names = re.findall(r"static let (\w+) = (?:ThemeKey|TextKey)\(\"([^\"]+)\"\)", gen)
src = "\n".join(c.read(f) for f in c.app_and_kit())
unused = []
for camel, name in names:
    if not re.search(r"(?<![\w])\.%s\b" % camel, src) and ('"%s"' % name) not in src:
        unused.append(name)
found = ["%d von %d Token haben keinen Nutzer in alfaos/App oder alfaos/Kit/Sources" % (len(unused), len(names))]
groups = {}
for name in unused:
    groups.setdefault(name.split("-")[0], []).append(name)
for group, members in sorted(groups.items()):
    found.append("%s (%d): %s" % (group, len(members), ", ".join(members)))
source, flat = c.tokens()
for token in flat:
    if re.search(r"Fassung vom|Rohwert", token.get("usage", "")):
        found.append("%s  %s: '%s'" % (c.where(c.TOKENS, '"%s"' % token["name"]), token["name"], token["usage"]))
c.report("28", "Ungenutzte Token auf Vorrat, darunter Rohwerte mit Fassungsvermerk", found)
