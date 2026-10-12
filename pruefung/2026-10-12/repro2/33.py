import importlib.util
import json
import os
import re
import sys

_spec = importlib.util.spec_from_file_location("common", os.path.join(os.path.dirname(os.path.abspath(__file__)), "common.py"))
c = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(c)

found = []
for path, number, text in c.grep(r'currentID == "', c.swift_files(c.APP)):
    found.append("%s:%d  Bahninhalt per Literal gewaehlt: %s" % (path, number, text))
if not c.grep(r"\.symbol\b", c.app_and_kit()):
    apps = json.loads(c.read(c.APPS))
    for entry in apps["apps"]:
        found.append("%s  Feld symbol '%s' der App %s hat keinen Leser" % (c.where(c.APPS, '"symbol": "%s"' % entry["symbol"]), entry["symbol"], entry["id"]))
c.report("33", "Verzeichnis apps.json ist nicht massgebend: Bahninhalt per Literal-Kennung, Feld symbol ohne Leser", found)
