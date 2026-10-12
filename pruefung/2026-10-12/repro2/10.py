import importlib.util
import os
import re
import sys

_spec = importlib.util.spec_from_file_location("common", os.path.join(os.path.dirname(os.path.abspath(__file__)), "common.py"))
c = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(c)

cat = c.catalog()
found = []
for key, entry in cat.items():
    value = c.de(entry)
    words = len(re.findall(r"\w+", value))
    if value.rstrip().endswith(".") or words >= 5 or key.endswith(".hint"):
        found.append("%s  %s = '%s' (Satz oder Erklaerung, %d Woerter)" % (c.where(c.CATALOG, '"%s"' % key), key, value, words))
c.report("10", "Katalogwerte, die ganze Saetze oder Erklaertext sind", found)
