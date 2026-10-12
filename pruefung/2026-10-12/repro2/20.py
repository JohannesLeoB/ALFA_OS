import importlib.util
import os
import re
import sys

_spec = importlib.util.spec_from_file_location("common", os.path.join(os.path.dirname(os.path.abspath(__file__)), "common.py"))
c = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(c)

found = []
cat = c.catalog()
if "person.initials" in cat and not re.search(r"%@", c.de(cat["person.initials"])):
    found.append("%s  person.initials = '%s' fest im Katalog (freigegeben ist text.global.personInitials = %%@)" % (c.where(c.CATALOG, '"person.initials"'), c.de(cat["person.initials"])))
    for path, number, text in c.grep(r'person\.initials', c.swift_files(c.APP)):
        found.append("%s:%d  %s" % (path, number, text))
for path, number, text in c.grep(r'Person\(id: "[^"]+", name: "[^"]+"\)', c.swift_files(c.APP)):
    found.append("%s:%d  feste Person im Code: %s" % (path, number, text))
c.report("20", "Festes Personenkuerzel im Katalog und feste Person im Code", found)
