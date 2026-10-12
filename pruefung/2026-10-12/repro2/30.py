import importlib.util
import json
import os
import re
import sys

_spec = importlib.util.spec_from_file_location("common", os.path.join(os.path.dirname(os.path.abspath(__file__)), "common.py"))
c = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(c)

pattern = re.compile(r"Stein|stein|Stone|Paper|Papier|Stahl|Ziegel|Glas\b|Holz|Leder|\\bBeton\\b|Umbra|Aprikose|Petrol|\bRose\b")
found = []
for number, text in enumerate(c.lines(c.TOKENS), 1):
    seen = set()
    for match in pattern.finditer(text):
        if match.group(0).lower() in seen:
            continue
        seen.add(match.group(0).lower())
        found.append("%s:%d  Materialwort '%s': %s" % (c.rel(c.TOKENS), number, match.group(0), text.strip()[:150]))
c.report("30", "Material- und Bildwoerter in tokens.json (meta und usage)", found)
