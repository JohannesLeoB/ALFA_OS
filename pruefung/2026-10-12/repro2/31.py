import importlib.util
import json
import os
import re
import sys

_spec = importlib.util.spec_from_file_location("common", os.path.join(os.path.dirname(os.path.abspath(__file__)), "common.py"))
c = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(c)

source, flat = c.tokens()
found = []
def prefixes(names):
    result = {}
    for name in names:
        result.setdefault(name.split("-")[0], []).append(name)
    return result
radius = [t["name"] for t in flat if t["family"] == "radius"]
if len(prefixes(radius)) > 1:
    found.append("Radien mit zwei Praefixen %s: %s" % (sorted(prefixes(radius)), ", ".join(radius)))
timing = [t["name"] for t in flat if t["family"] == "timing" and "duration" in t["name"]]
if len(prefixes(timing)) > 1:
    found.append("Dauern mit zwei Praefixen %s: %s" % (sorted(prefixes(timing)), ", ".join(timing)))
layout = [t["name"] for t in flat if t["family"] == "layout"]
if len(prefixes(layout)) > 2:
    found.append("Abschnitt layout mit drei Praefixen %s" % sorted(prefixes(layout)))
colour = [t["name"] for t in flat if t["family"] == "color" and not t["name"].startswith(("color-", "palette-"))]
if colour:
    found.append("Farbtoken ausserhalb color-/palette-: %s" % ", ".join(colour))
styles = [s["name"] for g in source["type"]["groups"] for s in g["styles"]]
if sum(1 for s in styles if s.startswith("text-")) == 1:
    found.append("Textstile ohne Praefix %s; nur text-button traegt eines" % ", ".join(s for s in styles if not s.startswith("text-")))
c.report("31", "Token-Systematik: gleiche Art, mehrere Praefixe; Textstile ohne Praefix", found)
