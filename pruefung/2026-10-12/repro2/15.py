import importlib.util
import os
import re
import sys

_spec = importlib.util.spec_from_file_location("common", os.path.join(os.path.dirname(os.path.abspath(__file__)), "common.py"))
c = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(c)

path = os.path.join(c.KIT, "Hub", "Providers", "Google", "GoogleProbe.swift")
found = []
src = c.lines(path)
for number, text in enumerate(src, 1):
    if "notConnected" in text and "HTTP 401" in "\n".join(src[number - 1:number + 1]):
        found.append("%s:%d  .notConnected (kein Token, keine Antwort) wird als 'HTTP 401' ausgegeben" % (c.rel(path), number))
c.report("15", "Erfundene Statusangabe: lokaler Fehler wird als HTTP 401 angezeigt", found)
