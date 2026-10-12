import importlib.util
import json
import os
import re
import sys

_spec = importlib.util.spec_from_file_location("common", os.path.join(os.path.dirname(os.path.abspath(__file__)), "common.py"))
c = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(c)

found = []
for path, number, text in c.grep(r"measures\[name\] \?\? 0|text\(key\)\.flatMap\(ValueParsing\.(length|duration|number)\) \?\? 0|tokens\.textStyle\(key\)\?\.tracking \?\? 0|guard let style = tokens\.textStyle\(key\) else \{ return Font\.body", c.app_and_kit()):
    found.append("%s:%d  stiller Ersatzwert: %s" % (path, number, text))
colour = c.grep(r"static let missing = RGB\(1, 0, 1, 1\)", c.app_and_kit())
if found and colour:
    found.append("%s:%d  nur Farben haben einen lauten Ersatz (Magenta); Laengen, Dauern, Masse, Schrift werden still 0 oder Systemschrift" % colour[0][:2])
c.report("37", "Fehlende Werte werden still durch 0 oder Systemschrift ersetzt, nur Farben fallen auf", found)
