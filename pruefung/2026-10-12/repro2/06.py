import importlib.util
import os
import re
import sys

_spec = importlib.util.spec_from_file_location("common", os.path.join(os.path.dirname(os.path.abspath(__file__)), "common.py"))
c = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(c)

rel_ = c.released()
view = os.path.join(c.APP, "Settings", "SettingsLaneView.swift")
words = os.path.join(c.KIT, "Hub", "InletWords.swift")
wanted = [
    (view, '"mail.state.loading"', "text.settings.connection.connecting"),
    (view, '"mail.state.failed"', "text.settings.connection.error"),
    (view, '"settings.inlets.none"', "text.settings.empty.noAccount"),
    (view, '"settings.signin"', "text.settings.action.connect"),
    (words, '"inlet.state.connecting"', "text.settings.connection.connecting"),
    (words, '"inlet.state.working"', "text.settings.sync.running"),
    (os.path.join(c.APP, "Resources", "apps.json"), '"app.settings.lane.trailing"', "text.settings.action.add"),
    (os.path.join(c.APP, "Resources", "apps.json"), '"app.settings.lane.center"', "text.settings.mail.accounts"),
    (os.path.join(c.APP, "Resources", "apps.json"), '"app.settings.lane.leading"', "text.global.area.settings"),
    (os.path.join(c.KIT, "Hub", "Providers", "IMAP", "IMAPProvider.swift"), '"field.imap.incomingHost"', "text.settings.mail.incomingHost"),
]
found = []
for path, needle, key in wanted:
    if key in rel_:
        for number, text in enumerate(c.lines(path), 1):
            if needle in text:
                found.append("%s:%d  nutzt %s; freigegeben ist %s = '%s'" % (c.rel(path), number, needle.strip('"'), key, rel_[key].get("de")))
c.report("06", "Einstellungs-Ansicht nutzt rohe Schluessel, wo freigegebene text.settings.*/text.global.* bestehen", found)
