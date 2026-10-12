import importlib.util
import json
import os
import re
import sys

_spec = importlib.util.spec_from_file_location("common", os.path.join(os.path.dirname(os.path.abspath(__file__)), "common.py"))
c = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(c)

shell = json.loads(c.read(c.SHELL))
source, flat = c.tokens()
by_value = {}
for token in flat:
    if isinstance(token["value"], str) and token["value"].endswith("px"):
        by_value.setdefault(float(token["value"][:-2]), []).append(token["name"])
found = []
def add(name, value):
    twins = [n for n in by_value.get(float(value), []) if n.startswith(("component-", "layout-", "size-"))] if isinstance(value, (int, float)) else []
    found.append("%s  '%s' = %s steht in shell.json statt in tokens.json%s" % (
        c.where(c.SHELL, '"%s"' % name), name, value, "; gleicher Wert in " + ", ".join(twins[:3]) if twins else ""))
for name, value in shell.items():
    if name == "measures":
        for inner, number in value.items():
            add(inner, number)
    else:
        add(name, value)
c.report("22", "shell.json ist eine zweite Wertequelle neben tokens.json", found)
