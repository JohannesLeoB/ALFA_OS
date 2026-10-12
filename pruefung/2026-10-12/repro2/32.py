import importlib.util
import json
import os
import re
import sys

_spec = importlib.util.spec_from_file_location("common", os.path.join(os.path.dirname(os.path.abspath(__file__)), "common.py"))
c = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(c)

found = []
theme = os.path.join(c.APP, "Theme", "Theme.swift")
app = c.swift_files(c.APP)
if not c.grep(r"\.lineHeight", app):
    found.append("TextStyle.lineHeight (%s) wird in alfaos/App nie gelesen; alle Zeilenhoehen aus tokens.json sind wirkungslos" % c.where(os.path.join(c.KIT, "ShellCore", "TokenTypes.swift"), "lineHeight"))
for path, number, text in c.grep(r'style\.family == "mono"|NSFont\.systemFont|Font\.body', [theme]):
    found.append("%s:%d  Schrift: %s" % (path, number, text))
if not c.grep(r"fontSans|fontDisplay|fontMono|font-sans", app):
    found.append("Schriftfamilien font-sans, font-display, font-mono aus tokens.json haben keinen Leser; Geist wird nie geladen")
for path, number, text in c.grep(r"case \.\.<\d+", [theme]):
    found.append("%s:%d  Gewichtsschwelle im Code: %s" % (path, number, text))
c.report("32", "Theme ignoriert Zeilenhoehe und Schriftfamilie der Token und rundet Gewichte mit festen Schwellen", found)
