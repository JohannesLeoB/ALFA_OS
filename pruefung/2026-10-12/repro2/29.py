import importlib.util
import json
import os
import re
import sys

_spec = importlib.util.spec_from_file_location("common", os.path.join(os.path.dirname(os.path.abspath(__file__)), "common.py"))
c = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(c)

source, flat = c.tokens()
words = ["pill", "ring", "hairline", "blink", "roll", "spin", "floating", "raised", "inset", "glow"]
names = [t["name"] for t in flat] + [s["name"] for g in source["type"]["groups"] for s in g["styles"]]
found = []
for name in names:
    hit = [w for w in words if re.search(r"(^|-)%s(-|$)" % w, name)]
    if hit:
        found.append("%s  %s enthaelt Bildwort %s" % (c.where(c.TOKENS, '"%s"' % name), name, "/".join(hit)))
c.report("29", "Token-Namen mit Bildwoertern (Haarlinie, Ring, Pille, Blinzeln, Rollen, Drehen, schwebend, erhoben)", found)
