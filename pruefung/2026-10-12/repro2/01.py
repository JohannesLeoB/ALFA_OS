import importlib.util
import os
import re
import sys

_spec = importlib.util.spec_from_file_location("common", os.path.join(os.path.dirname(os.path.abspath(__file__)), "common.py"))
c = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(c)

keys = c.catalog()
path = os.path.join(c.KIT, "Mail", "Model", "MailKeys.swift")
found = []
for number, text in enumerate(c.lines(path), 1):
    for key in re.findall(r'"((?:mail|hint)\.[A-Za-z0-9_.]+)"', text):
        if key not in keys:
            found.append("%s:%d  Schluessel %s steht nicht im Katalog" % (c.rel(path), number, key))
c.report("01", "Schluessel im Code ohne Katalogeintrag", found)
