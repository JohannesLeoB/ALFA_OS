import importlib.util
import os
import re
import sys

_spec = importlib.util.spec_from_file_location("common", os.path.join(os.path.dirname(os.path.abspath(__file__)), "common.py"))
c = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(c)

found = []
for path, number, text in c.grep(r"failed\(String\(describing: error\)\)", c.swift_files(c.APP)):
    found.append("%s:%d  %s" % (path, number, text))
for path, number, text in c.grep(r"Text\(verbatim: description\)", c.swift_files(c.APP)):
    found.append("%s:%d  rohe Beschreibung im Bild: %s" % (path, number, text))
c.report("13", "Roher Fehlertext (String(describing:)) der Einrichtung erscheint in der Mail- und Einstellungsansicht", found)
