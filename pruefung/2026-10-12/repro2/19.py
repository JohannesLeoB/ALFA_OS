import importlib.util
import os
import re
import sys

_spec = importlib.util.spec_from_file_location("common", os.path.join(os.path.dirname(os.path.abspath(__file__)), "common.py"))
c = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(c)

keys = c.catalog()
segments = {}
for key in keys:
    for segment in key.split("."):
        segments.setdefault(segment.lower(), set()).add(segment)
found = []
for lower, forms in sorted(segments.items()):
    if len(forms) > 1:
        users = [k for k in keys if any(s in forms for s in k.split("."))]
        found.append("Schreibweisen %s: %s" % (sorted(forms), ", ".join(users)))
if "mail.loadMore" in keys:
    found.append("mail.loadMore steht ausserhalb von mail.list.*, obwohl mail.list.loadingMore dieselbe Liste betrifft")
c.report("19", "Schluesselnamen: gleiches Wort in zwei Schreibweisen und Listenschluessel auf zwei Ebenen", found)
