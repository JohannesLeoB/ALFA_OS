import importlib.util
import os
import re
import sys

_spec = importlib.util.spec_from_file_location("common", os.path.join(os.path.dirname(os.path.abspath(__file__)), "common.py"))
c = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(c)

found = []
for path, number, text in c.grep(r'"mail\.[a-z]+\.', c.swift_files(os.path.join(c.KIT, "Hub"))):
    found.append("%s:%d  Hub (Kern) nutzt Mail-Praefix: %s" % (path, number, text))
for path, number, text in c.grep(r'word\("mail\.', c.swift_files(os.path.join(c.APP, "Settings"))):
    found.append("%s:%d  Einstellungen nutzt Mail-Praefix: %s" % (path, number, text))
keys = c.catalog()
families = sorted({k.split(".")[0] if not k.startswith("mail.hint") else "mail.hint" for k in keys if "hint" in k.split(".")[:2]})
if len(families) > 1:
    found.append("zwei Praefixe fuer Hinweise: %s (z. B. %s und %s)" % (families, "hint.signin.expired", "mail.hint.signIn"))
if any(k.startswith("settings.") for k in keys) and any(k.startswith("text.settings.") for k in keys):
    found.append("zwei Praefixe fuer Einstellungen: settings.* (%s) und text.settings.* (%s)" % (
        ", ".join(k for k in keys if k.startswith("settings.")), "freigegeben/roh gemischt"))
c.report("18", "Praefix-Systematik bricht: Kern nutzt mail.*, Einstellungen nutzen mail.*, zwei Praefixe je Zweck", found)
