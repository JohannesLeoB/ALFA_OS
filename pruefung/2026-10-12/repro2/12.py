import importlib.util
import os
import re
import sys

_spec = importlib.util.spec_from_file_location("common", os.path.join(os.path.dirname(os.path.abspath(__file__)), "common.py"))
c = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(c)

found = []
for path in (os.path.join(c.KIT, "Mail", "Core", "MailFailure.swift"), os.path.join(c.KIT, "Mail", "Core", "MailCore.swift")):
    src = c.lines(path)
    for number, text in enumerate(src, 1):
        if "MailHintKey.offline" in text:
            previous = next((src[i].strip() for i in range(number - 2, max(number - 6, 0), -1)
                             if re.search(r"case |if |else|catch", src[i])), "")
            found.append("%s:%d  Offline gesetzt bei: %s" % (c.rel(path), number, previous))
c.report("12", "Das Wort 'Offline' wird fuer Fehler gesetzt, die keinen Dienstzustand beschreiben", found)
