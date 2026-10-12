import importlib.util
import os
import re
import sys

_spec = importlib.util.spec_from_file_location("common", os.path.join(os.path.dirname(os.path.abspath(__file__)), "common.py"))
c = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(c)

found = []
for path, number, text in c.grep(r"func word\(|func hintWords\(", c.swift_files(c.APP)):
    found.append("%s:%d  eigener Schluesselweg ausserhalb des Themes: %s" % (path, number, text))
for path, number, text in c.grep(r"func text\(_ key: String\)|func string\(_ key: String\)", c.swift_files(c.APP)):
    found.append("%s:%d  Theme-Weg daneben: %s" % (path, number, text))
for path, number, text in c.grep(r'rawValue == "other"', c.swift_files(c.APP)):
    found.append("%s:%d  Ordnerrolle als Zeichenkette verglichen: %s" % (path, number, text))
if len([f for f in found if "eigener" in f]) == 0:
    found = []
c.report("21", "Zwei Wege, einen Katalogschluessel zu zeigen, und Rollenvergleich per Zeichenkette", found)
