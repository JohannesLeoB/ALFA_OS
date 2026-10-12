import importlib.util
import json
import os
import re
import sys

_spec = importlib.util.spec_from_file_location("common", os.path.join(os.path.dirname(os.path.abspath(__file__)), "common.py"))
c = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(c)

source, flat = c.tokens()
twelve = [t for t in flat if t.get("value") == "12px" and t["family"] in ("spacing", "layout")]
found = []
for token in twelve:
    found.append("%s  %s = 12px, Beschreibung: %s" % (c.where(c.TOKENS, '"%s"' % token["name"]), token["name"], token.get("usage")))
geometry = os.path.join(c.KIT, "ShellCore", "ShellMetrics.swift")
use = c.grep(r"gap = theme\.length\(\.layoutRegionGap\)", [geometry])
lanes = c.grep(r"g\.gap", [os.path.join(c.APP, "Shell", "ShellView.swift")])
region = next((t for t in twelve if t["name"] == "layout-region-gap"), None)
if region and use and lanes and "BlobBar" in region.get("usage", ""):
    found.append("%s:%d  Code nimmt layout-region-gap als Abstand zwischen Bahnen (z. B. %s:%d), Beschreibung sagt BlobBar zu Bahnen" % (use[0][0], use[0][1], lanes[0][0], lanes[0][1]))
if len(twelve) < 2:
    found = []
c.report("26", "Derselbe Abstand 12px ist dreifach benannt, und die Beschreibung von layout-region-gap widerspricht dem Code", found)
