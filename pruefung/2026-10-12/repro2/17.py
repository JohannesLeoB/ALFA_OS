import importlib.util
import os
import re
import sys

_spec = importlib.util.spec_from_file_location("common", os.path.join(os.path.dirname(os.path.abspath(__file__)), "common.py"))
c = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(c)

cat = c.catalog()
words = os.path.join(c.KIT, "Hub", "InletWords.swift")
panes = os.path.join(c.APP, "Mail", "MailPanes.swift")
hub = {}
for text in c.lines(words)[2:17]:
    m = re.match(r'\s*case \.(\w+)(?:\(\w+\))?: "([^"]+)"', text)
    if m:
        hub[m.group(1)] = m.group(2)
mail = {}
for number, text in enumerate(c.lines(panes), 1):
    m = re.match(r'\s*case ((?:\.\w+(?:\(let \w+\))?(?:, )?)+): word\("([^"]+)"\)', text)
    if m:
        for case in re.findall(r"\.(\w+)", m.group(1)):
            mail[case] = (m.group(2), number)
found = []
for case, key in hub.items():
    other = mail.get(case)
    if other and c.de(cat[key]) != c.de(cat[other[0]]):
        found.append("InletState.%s: Einstellungen '%s' (%s) gegen Mail-Konten '%s' (%s, %s:%d)" % (
            case, c.de(cat[key]), key, c.de(cat[other[0]]), other[0], c.rel(panes), other[1]))
c.report("17", "Ein InletState hat in zwei Ansichten zwei Woerter, weil zwei Abbildungen bestehen", found)
