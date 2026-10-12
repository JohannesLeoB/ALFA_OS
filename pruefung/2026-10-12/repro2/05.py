import importlib.util
import os
import re
import sys

_spec = importlib.util.spec_from_file_location("common", os.path.join(os.path.dirname(os.path.abspath(__file__)), "common.py"))
c = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(c)

sources = c.swift_files(c.KIT)
found = []
for case in ("conversation", "draftNotice"):
    made = [h for h in c.grep(r"content: \.%s|content = \.%s|\.%s\(" % (case, case, case), sources)
            if "MailKeys.swift" not in h[0] and "MailStates.swift" not in h[0]]
    if not made:
        found.append("MailCardContent.%s wird nirgends erzeugt; Schluessel mail.card.%s im Katalog: %s (%s)" % (
            case, case, "ja" if "mail.card." + case in c.catalog() else "nein", c.where(os.path.join(c.KIT, "Mail", "Model", "MailKeys.swift"), "mail.card." + case)))
view = os.path.join(c.APP, "Mail", "MailPanes.swift")
shown = c.grep(r"row\.states\.first", [view])
if found and shown:
    found.append("%s:%d  Zeile zeigt nur den ersten Zustand und nur bei ungelesen; starred, selected, hasAttachments, threadCount erreichen das Bild nie" % shown[0][:2])
c.report("05", "Kartenzustaende ohne Erzeuger und Zeilenzustaende ohne Anzeige", found)
