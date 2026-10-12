import importlib.util
import os
import re
import sys

_spec = importlib.util.spec_from_file_location("common", os.path.join(os.path.dirname(os.path.abspath(__file__)), "common.py"))
c = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(c)

cat = c.catalog()
groups = {}
for key, entry in cat.items():
    groups.setdefault(c.de(entry), []).append(key)
found = []
for value, keys in sorted(groups.items()):
    if len(keys) > 1:
        found.append("'%s' = %s" % (value, ", ".join(keys)))
c.report("16", "Mehrere Schluessel mit demselben Wort", found)
