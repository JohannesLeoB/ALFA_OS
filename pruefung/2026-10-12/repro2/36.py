import importlib.util
import json
import os
import re
import sys

_spec = importlib.util.spec_from_file_location("common", os.path.join(os.path.dirname(os.path.abspath(__file__)), "common.py"))
c = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(c)

path = os.path.join(c.APP, "Settings", "SettingsLaneView.swift")
src = c.lines(path)
start = next(i for i, t in enumerate(src) if "struct SettingsGroupsPane" in t)
body = "\n".join(src[start:start + 10])
found = []
if "Button" not in body and "ForEach" not in body:
    found.append("%s:%d  linke Einstellungsbahn zeigt ein einziges festes Wort (text.settings.row.mail.accounts), keine Auswahl, keine Gruppen" % (c.rel(path), start + 1))
apps = json.loads(c.read(c.APPS))
cat = c.catalog()
settings = next(e for e in apps["apps"] if e["id"] == "settings")
if c.de(cat[settings["lanes"]["leadingKey"]]) == c.de(cat[settings["titleKey"]]):
    found.append("%s  linker Bahntitel '%s' wiederholt den Namen der App (%s = %s)" % (
        c.where(c.APPS, settings["lanes"]["leadingKey"]), c.de(cat[settings["lanes"]["leadingKey"]]), settings["lanes"]["leadingKey"], settings["titleKey"]))
c.report("36", "Einstellungen: linke Bahn ist ein totes Wort, Titel doppelt den App-Namen", found)
