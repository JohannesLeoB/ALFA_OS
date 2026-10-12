import importlib.util
import json
import os
import re
import sys

_spec = importlib.util.spec_from_file_location("common", os.path.join(os.path.dirname(os.path.abspath(__file__)), "common.py"))
c = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(c)

found = []
for path, number, text in c.grep(r"layoutReadingMaxWidth\) / \d|spaceXs\) \* 3|sizeControlM\) \* 2", c.swift_files(c.APP)):
    found.append("%s:%d  abgeleitetes Mass aus fremdem Token: %s" % (path, number, text))
c.report("25", "Massannahmen: Lesebreite durch 3 oder 2 als Hoehe/Versatz, Pillenbreite aus Summe nachgerechnet", found)
