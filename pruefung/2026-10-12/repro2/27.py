import importlib.util
import json
import os
import re
import sys

_spec = importlib.util.spec_from_file_location("common", os.path.join(os.path.dirname(os.path.abspath(__file__)), "common.py"))
c = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(c)

source, flat = c.tokens()
hexre = re.compile(r"#[0-9a-fA-F]{3,8}\b")
palette = {}
for token in flat:
    if token["name"].startswith("palette-") and isinstance(token["value"], dict):
        for mode, value in token["value"].items():
            palette.setdefault(value.lower(), token["name"])
found = []
for token in flat:
    if token["name"].startswith("palette-"):
        continue
    values = token["value"].items() if isinstance(token["value"], dict) else [("-", token["value"])]
    for mode, value in values:
        if not isinstance(value, str) or value.startswith("{"):
            continue
        for literal in hexre.findall(value):
            if literal.lower() in palette:
                found.append("%s  %s (%s) traegt Literal %s, gleich %s; kein Alias" % (
                    c.where(c.TOKENS, '"%s"' % token["name"]), token["name"], mode, literal, palette[literal.lower()]))
c.report("27", "Farbliterale in Namenstoken, die einen Paletteneintrag doppeln statt ihn zu nennen", found)
