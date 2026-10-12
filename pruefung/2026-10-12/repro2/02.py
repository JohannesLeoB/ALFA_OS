import importlib.util
import os
import re
import sys

_spec = importlib.util.spec_from_file_location("common", os.path.join(os.path.dirname(os.path.abspath(__file__)), "common.py"))
c = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(c)

keys = c.catalog()
presets = os.path.join(c.ROOT, "fundus", "alpha", "Sources", "MykilosKit", "Domain", "MailAccount.swift")
titles = re.findall(r'kind: \.(\w+), title: \.verbatim\("([^"]+)"\)', c.read(presets))
provider = os.path.join(c.KIT, "Hub", "Providers", "IMAP", "IMAPProvider.swift")
titles += [("fastmail", m) for m in re.findall(r'\("fastmail", "([^"]+)"', c.read(provider))]
password_kinds = {"ionos", "gmx", "webde", "icloud", "fastmail"}
shown = c.grep(r"word\((offer|inlet|account)\.title\)", c.swift_files(c.APP))
found = []
for kind, title in titles:
    if kind in password_kinds and title not in keys:
        found.append("%s  Titel '%s' wird als Katalogschluessel gerendert (word(offer.title)), Eintrag fehlt; angezeigt wird nur der Schluessel selbst" % (c.where(provider if kind == "fastmail" else presets, title), title))
if found:
    found += ["%s:%d  %s" % hit for hit in shown]
c.report("02", "Titel der Mail-Voreinstellungen laufen als Schluessel durch word() ohne Katalogeintrag", found)
