import importlib.util
import os
import re
import sys

_spec = importlib.util.spec_from_file_location("common", os.path.join(os.path.dirname(os.path.abspath(__file__)), "common.py"))
c = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(c)

sources = c.swift_files(c.KIT)
found = []
for state in ("orphaned", "locked"):
    producers = [h for h in c.grep(r"\.state = \.%s\b|state: \.%s\b|InletState\.%s\b" % (state, state, state), sources)]
    if not producers:
        defs = c.grep(r"\.%s\b|case %s\b" % (state, state), sources + c.swift_files(c.APP))
        found.append("Zustand .%s wird nirgends gesetzt; nur Definition/Abbildung:" % state)
        found += ["    %s:%d  %s" % h for h in defs]
        found.append("    Katalog: inlet.state.%s=%s, mail.state.%s=%s" % (
            state, c.de(c.catalog()["inlet.state." + state]), state, c.de(c.catalog()["mail.state." + state])))
c.report("04", "Zustaende .orphaned und .locked haben Woerter im Katalog, aber nie einen Erzeuger", found)
