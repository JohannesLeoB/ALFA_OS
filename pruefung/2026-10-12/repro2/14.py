import importlib.util
import os
import re
import sys

_spec = importlib.util.spec_from_file_location("common", os.path.join(os.path.dirname(os.path.abspath(__file__)), "common.py"))
c = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(c)

found = []
shown = c.grep(r"Text\(verbatim: detail\)", c.swift_files(c.APP))
for path, number, text in c.grep(r"detail: .*String\(describing: |let detail = String\(describing", c.swift_files(c.KIT)):
    found.append("%s:%d  Hint.detail aus String(describing:): %s" % (path, number, text))
if found:
    for path, number, text in shown:
        found.append("%s:%d  Detail wird woertlich angezeigt: %s" % (path, number, text))
c.report("14", "Hint.detail traegt rohe Fehlerbeschreibungen bis in die Ansicht", found)
