import importlib.util
import os
import re
import sys

_spec = importlib.util.spec_from_file_location("common", os.path.join(os.path.dirname(os.path.abspath(__file__)), "common.py"))
c = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(c)

rel_ = c.released()
cat = c.catalog()
pairs = {
    "field.imap.address": "text.settings.row.accountCard.email",
    "field.imap.username": "text.settings.row.accountCard.user",
    "field.imap.password": "text.settings.row.accountCard.password",
    "field.imap.incomingHost": "text.settings.mail.incomingHost",
    "field.imap.incomingPort": "text.settings.mail.incomingPort",
    "field.imap.incomingSecurity": "text.settings.mail.incomingSecurity",
    "field.imap.outgoingHost": "text.settings.mail.outgoingHost",
    "field.imap.outgoingPort": "text.settings.mail.outgoingPort",
    "field.imap.outgoingSecurity": "text.settings.mail.outgoingSecurity",
}
found = []
for key, official in pairs.items():
    if official in rel_ and c.de(cat[key]) != rel_[official]["de"]:
        found.append("%s  roh '%s' (comment %s) statt freigegeben %s = '%s'" % (
            c.where(c.CATALOG, '"%s"' % key), c.de(cat[key]), cat[key].get("comment"), official, rel_[official]["de"]))
c.report("07", "field.imap.* weichen im Wortlaut von den freigegebenen Mail-Feldtexten ab", found)
