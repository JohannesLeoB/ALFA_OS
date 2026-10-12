import importlib.util
import json
import os
import re
import sys

_spec = importlib.util.spec_from_file_location("common", os.path.join(os.path.dirname(os.path.abspath(__file__)), "common.py"))
c = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(c)

found = []
files = c.swift_files(os.path.join(c.APP, "Settings"), os.path.join(c.APP, "Mail"))
uses = c.grep(r"theme\.", files)
for path, number, text in c.grep(r"\.padding\(\)|\.fontWeight\(|\.font\(\.(headline|body|title)|\.underline\(", files):
    found.append("%s:%d  %s" % (path, number, text))
if not uses:
    found.insert(0, "Kein einziger Zugriff auf theme.* in App/Settings und App/Mail; Abstand, Schrift, Farbe stammen aus Systemvorgaben")
c.report("23", "Einstellungs- und Mail-Ansicht umgehen das Theme: Systemwerte statt benannter Werte", found)
