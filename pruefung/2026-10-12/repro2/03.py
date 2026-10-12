import importlib.util
import os
import re
import sys

_spec = importlib.util.spec_from_file_location("common", os.path.join(os.path.dirname(os.path.abspath(__file__)), "common.py"))
c = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(c)

path = os.path.join(c.KIT, "Hub", "Providers", "IMAP", "IMAPProvider.swift")
found = []
for number, text in enumerate(c.lines(path), 1):
    if re.search(r'"(imap|smtp)\.[a-z.]+"|port: \d{2,3}', text):
        found.append("%s:%d  fester Anbieterwert im Code: %s" % (c.rel(path), number, text.strip()))
c.report("03", "Fastmail-Server und Ports stehen fest im Code statt in der Einrichtung der Firma", found)
