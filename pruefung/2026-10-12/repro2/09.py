import importlib.util
import os
import re
import sys

_spec = importlib.util.spec_from_file_location("common", os.path.join(os.path.dirname(os.path.abspath(__file__)), "common.py"))
c = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(c)

cat = c.catalog()
rel_ = c.released()
by_value = {}
for key, value in rel_.items():
    if isinstance(value.get("de"), str):
        by_value.setdefault(value["de"], []).append(key)
found = []
for key, entry in cat.items():
    if entry.get("comment") is None:
        twin = sorted(by_value.get(c.de(entry), []), key=lambda k: (0 if re.search(r"global\.area|blob\.|mail\.folder|settings\.connection|help\.", k) else 1, len(k)))
        found.append("%s  %s='%s' ohne comment (weder roh noch freigegeben)%s" % (
            c.where(c.CATALOG, '"%s"' % key), key, c.de(entry), "; freigegeben vorhanden: " + twin[0] if twin else ""))
c.report("09", "Altbestand ohne comment: weder als roh noch als freigegeben gekennzeichnet", found)
