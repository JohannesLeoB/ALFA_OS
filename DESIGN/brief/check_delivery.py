#!/usr/bin/env python3
"""Check the delivery note of an ALFA export against the brief.

EXPORT_DIR holds contract/ and project/ (the drafts). Checks: contract/LIEFERUNG.json is valid
against delivery.schema.json; every item of BRIEF.txt (lines that start with T<n> or N<n>, without
"(entfällt)") has exactly one entry, and no entry names an item the brief does not have; every
"where" points to a draft listed in "drafts" and to a line that exists; every id of a done item
is an element id in contract/components.json; every .dc.html in project/ is in "drafts", and
every draft in "drafts" exists in project/ and has the given sha256; contract/PRUEFUNG.txt
exists and is not empty.
Exit 0 = no findings, 1 = findings, 2 = usage.
Usage: check_delivery.py EXPORT_DIR
"""
import hashlib
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.dont_write_bytecode = True
sys.path.insert(0, HERE)
from validate import Validator, read_json  # noqa: E402

ITEM = re.compile(r"^(T\d+|N\d+)\s")


def brief_items():
    with open(os.path.join(HERE, "BRIEF.txt"), encoding="utf-8") as f:
        return [m.group(1) for line in f if (m := ITEM.match(line)) and "(entfällt)" not in line]


def sha256(path):
    with open(path, "rb") as f:
        return hashlib.sha256(f.read()).hexdigest()


def main(argv):
    if len(argv) != 1 or not os.path.isdir(argv[0]):
        print(__doc__)
        return 2
    contract = os.path.join(argv[0], "contract")
    project = os.path.join(argv[0], "project")
    findings = []
    note, problem = read_json(os.path.join(contract, "LIEFERUNG.json"))
    if problem:
        print("LIEFERUNG.json: %s" % problem)
        print("1 finding(s)")
        return 1
    schema, problem = read_json(os.path.join(HERE, "delivery.schema.json"))
    if problem:
        print("delivery.schema.json: %s" % problem)
        return 2
    errors = Validator(schema).errors(schema, note, "#")
    if errors:
        for e in errors[:20]:
            print("LIEFERUNG.json: " + e)
        print("%d finding(s)" % len(errors))
        return 1
    wanted = brief_items()
    given = [i["id"] for i in note["items"]]
    for i in wanted:
        if given.count(i) == 0:
            findings.append("item missing in delivery note: %s" % i)
    for i in sorted({i for i in given if given.count(i) > 1}):
        findings.append("item twice in delivery note: %s" % i)
    for i in sorted(set(given) - set(wanted)):
        findings.append("item not in the brief: %s" % i)
    drafts = {d["file"]: d["sha256"] for d in note["drafts"]}
    if os.path.isdir(project):
        for name in sorted(os.listdir(project)):
            if name.endswith(".dc.html") and name not in drafts:
                findings.append("draft not in delivery note: %s" % name)
    lines = {}
    for name, digest in sorted(drafts.items()):
        path = os.path.join(project, name)
        if not os.path.isfile(path):
            findings.append("draft missing in project/: %s" % name)
            continue
        if sha256(path) != digest:
            findings.append("draft changed after the delivery note: %s" % name)
        with open(path, encoding="utf-8") as f:
            lines[name] = f.read().count("\n") + 1
    comps = (read_json(os.path.join(contract, "components.json"))[0] or {}).get("components", [])
    ids = {e["id"] for c in comps for e in c.get("elements", [])}
    for item in note["items"]:
        for ref in item.get("where", []):
            name, _, line = ref.rpartition(":")
            if name not in drafts:
                findings.append("%s: %s is not in drafts" % (item["id"], name))
            elif name in lines and not 1 <= int(line) <= lines[name]:
                findings.append("%s: line %s does not exist in %s" % (item["id"], line, name))
        if item["status"] == "done":
            for i in item.get("ids", []):
                if i not in ids:
                    findings.append("%s: element id %s not in components.json" % (item["id"], i))
    check = os.path.join(contract, "PRUEFUNG.txt")
    if not os.path.isfile(check) or not open(check, encoding="utf-8").read().strip():
        findings.append("contract/PRUEFUNG.txt missing or empty")
    for line in findings:
        print(line)
    done = len({i["id"] for i in note["items"] if i["status"] == "done"} & set(wanted))
    print("items: %d of %d done" % (done, len(wanted)))
    print("%d finding(s)" % len(findings) if findings else "delivery: complete")
    return 1 if findings else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
