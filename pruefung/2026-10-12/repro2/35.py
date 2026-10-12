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
mail = next(e for e in apps["apps"] if e["id"] == "mail")
panes = os.path.join(c.APP, "Mail", "MailPanes.swift")
found = []
title = c.de(cat[mail["lanes"]["centerKey"]])
select = c.grep(r"selectFolder\(", [panes])
if select:
    found.append("%s  Mittelbahn heisst fest '%s' (%s), obwohl %s:%d jeden anderen Ordner waehlen laesst (Spam, Papierkorb, ...)" % (
        c.where(c.APPS, mail["lanes"]["centerKey"]), title, mail["lanes"]["centerKey"], select[0][0], select[0][1]))
c.report("35", "Bahntitel 'Eingang' ist fest, der gezeigte Ordner nicht", found)
