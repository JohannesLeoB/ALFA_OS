import importlib.util
import json
import os
import re
import sys

_spec = importlib.util.spec_from_file_location("common", os.path.join(os.path.dirname(os.path.abspath(__file__)), "common.py"))
c = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(c)

apps = json.loads(c.read(c.APPS))
cat = c.catalog()
groups = [(g["id"], c.de(cat[g["titleKey"]])) for g in apps["groups"]]
tree = c.lines(os.path.join(c.ROOT, "ausgang", "design-handoff", "01-funktionsbaum.md"))
start = next(i for i, t in enumerate(tree) if t.startswith("## B."))
end = next(i for i, t in enumerate(tree) if t.startswith("## C."))
families = [t[4:].strip() for t in tree[start:end] if t.startswith("### ")]
rules = c.read(os.path.join(c.ROOT, "AGENTS.md"))
areas = re.search(r"Apps und Bereiche: ([^;.]+)[;.]", rules).group(1)
areas = [a.strip() for a in re.split(r",| und ", areas) if a.strip()]
titles = [t for _, t in groups]
found = []
found.append("apps.json (%s:%d) kennt Gruppen %s" % (c.rel(c.APPS), 2, titles))
found.append("Funktionsbaum Abschnitt B nennt Familien %s" % families)
found.append("AGENTS.md nennt Bereiche %s" % areas)
if set(titles) == set(families) or set(titles) >= set(areas):
    found = []
settings_group = next(e["group"] for e in apps["apps"] if e["id"] == "settings")
if found:
    found.append("%s  Einstellungen haengen in Gruppe '%s', die in keiner der beiden Aufzaehlungen vorkommt" % (c.where(c.APPS, '"id": "settings"'), settings_group))
c.report("34", "Gruppierung in apps.json deckt sich weder mit dem Funktionsbaum noch mit den Bereichen der Regeldatei", found)
