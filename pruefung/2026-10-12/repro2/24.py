import importlib.util
import json
import os
import re
import sys

_spec = importlib.util.spec_from_file_location("common", os.path.join(os.path.dirname(os.path.abspath(__file__)), "common.py"))
c = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(c)

files = [f for f in c.swift_files(c.APP) if not f.endswith("Theme.swift")]
found = []
for path, number, text in c.grep(r"\.palette[A-Z]\w+|theme\.pick\(", files):
    found.append("%s:%d  %s" % (path, number, text))
source, flat = c.tokens()
semantic = [t["name"] for t in flat if t["name"] in ("color-text-tertiary", "color-line-divider", "color-symbol-muted")]
if found:
    found.append("semantische Namen waeren da: " + ", ".join(semantic))
c.report("24", "Ansichten wuehlen in der Palette und waehlen Hell/Dunkel selbst (Theme.pick)", found)
