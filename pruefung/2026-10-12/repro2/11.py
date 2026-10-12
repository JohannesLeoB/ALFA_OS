import importlib.util
import os
import re
import sys

_spec = importlib.util.spec_from_file_location("common", os.path.join(os.path.dirname(os.path.abspath(__file__)), "common.py"))
c = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(c)

path = os.path.join(c.APP, "Shell", "AssistantView.swift")
src = c.lines(path)
found = []
for number, text in enumerate(src, 1):
    if '"assistant.state"' in text:
        context = "\n".join(src[max(0, number - 4):number - 1])
        guarded = re.search(r"\b(if|switch|case)\b", context) is not None
        has_input = re.search(r"let (state|status|connection|inlet)\w*:", c.read(path)) is not None
        if not guarded and not has_input:
            found.append("%s:%d  Katalogwert '%s' wird immer gezeigt; AssistantView hat keinen Dienstzustand als Eingabe" % (
                c.rel(path), number, c.de(c.catalog()["assistant.state"])))
c.report("11", "Zustandswort ohne Zustand dahinter: Assistent zeigt immer 'Nicht verbunden'", found)
