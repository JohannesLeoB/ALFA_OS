import importlib.util
import os
import re
import sys

_spec = importlib.util.spec_from_file_location("common", os.path.join(os.path.dirname(os.path.abspath(__file__)), "common.py"))
c = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(c)

cat = c.catalog()
rel_ = c.released()
found = []
for key, entry in cat.items():
    if key.startswith("text.") and entry.get("comment") != "freigegeben":
        official = rel_.get(key, {}).get("de")
        found.append("%s  %s hat comment '%s' im freigegebenen Praefix text.*; Wert '%s', freigegeben '%s'" % (
            c.where(c.CATALOG, '"%s"' % key), key, entry.get("comment"), c.de(entry), official))
c.report("08", "Roher Eintrag im Praefix text.* mit abweichendem Wert", found)
