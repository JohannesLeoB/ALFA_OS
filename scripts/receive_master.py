#!/usr/bin/env python3
"""Receive a design master: write or check DESIGN/MANIFEST.json and the derivable stamp fields.

Usage: receive_master.py [ZIP] [--check] [--adopt] [--prune] [--root DIR]
  ZIP      the new latest master, a file in DESIGN/ (with --check: default is the manifest's latest)
  write    sets rank latest for ZIP and previous for the master that was latest before, lists every
           file (path, bytes, sha256) and updates zipSha256 and content in design.stamp.json.
           For a new delivery it also sets delivery and deliveredAt from the ZIP name and the
           newest entry time inside the ZIP. adoptedAt and state stay as they are.
  --adopt  also sets adoptedAt to now (state stays: renew it by hand)
  --prune  delete ZIPs in DESIGN/ that are neither latest nor previous (L7)
  --check  write nothing; exit 1 on any mismatch between ZIPs, manifest and stamp
Rules checked (L7): DESIGN/ holds at most two masters; latest is newer than previous; zipDate is
the newest entry time inside the ZIP, not the file time. content is the SHA-256 of TOKENBOGEN.json,
or of the contract files when the master has contract/ (see design_generate.contract_content).
Exit 0 = done or no mismatch, 1 = mismatch or rule broken, 2 = usage or unreadable input.
"""
import argparse
import datetime
import json
import os
import sys
import zipfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import design_generate as dg  # noqa: E402

RULE = "L7: DESIGN holds only the latest and the previous design master, as original ZIP. Unpack only in dist/."


def describe(path):
    """Return (manifest entry without rank, newest entry time, stamp content) of one ZIP."""
    with zipfile.ZipFile(path) as archive:
        infos = [i for i in archive.infolist() if not i.is_dir()]
        names = [i.filename for i in infos]
        newest = max(datetime.datetime(*i.date_time) for i in archive.infolist())
        files = []
        for info in sorted(infos, key=lambda i: i.filename):
            data = archive.read(info.filename)
            files.append({"path": info.filename, "bytes": len(data), "sha256": dg.sha256(data)})
        prefix = dg.contract_prefix(names)
        if prefix:
            content = dg.contract_content({n[len(prefix):]: archive.read(n) for n in names if n.startswith(prefix)})
        else:
            sheets = [n for n in names if n == dg.SHEET or n.endswith("/" + dg.SHEET)]
            if len(sheets) != 1:
                raise ValueError("%s: expected exactly one %s, found %d" % (os.path.basename(path), dg.SHEET, len(sheets)))
            content = dg.sha256(archive.read(sheets[0]))
    entry = {"zip": os.path.basename(path), "zipDate": newest.strftime("%Y-%m-%d"), "zipBytes": os.path.getsize(path),
             "zipSha256": dg.sha256(dg.read(path)), "count": len(files), "files": files}
    return entry, newest, content


def ranked(rank, entry, notes):
    out = {"rank": rank}
    for key in ("zip", "zipDate", "zipBytes", "zipSha256", "count"):
        out[key] = entry[key]
    out["files"] = entry["files"]
    if entry["zip"] in notes:
        out["note"] = notes[entry["zip"]]
    return out


def main(argv):
    parser = argparse.ArgumentParser()
    parser.add_argument("zip", nargs="?")
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--adopt", action="store_true")
    parser.add_argument("--prune", action="store_true")
    parser.add_argument("--root")
    args = parser.parse_args(argv)
    if args.root:
        dg.set_root(args.root)
    design = os.path.dirname(dg.MANIFEST)
    problems = []
    try:
        old = json.loads(dg.read(dg.MANIFEST).decode("utf-8")) if os.path.exists(dg.MANIFEST) else {"masters": []}
        masters = old["masters"]
        old_latest = next((m for m in masters if m.get("rank") == "latest"), None)
        old_previous = next((m for m in masters if m.get("rank") == "previous"), None)
        name = os.path.basename(args.zip) if args.zip else (old_latest or {}).get("zip")
        if not name:
            raise ValueError("no ZIP given and no latest master in the manifest")
        if args.zip and os.path.abspath(os.path.dirname(args.zip) or ".") != os.path.abspath(design):
            raise ValueError("%s is not in %s: put the ZIP there first" % (args.zip, design))
        if old_latest and old_latest["zip"] == name:
            previous_name = (old_previous or {}).get("zip")
        else:
            previous_name = (old_latest or {}).get("zip")
        notes = {m["zip"]: m["note"] for m in masters if "note" in m}
        latest, latest_time, content = describe(os.path.join(design, name))
        entries = [ranked("latest", latest, notes)]
        if previous_name:
            previous, previous_time, _ = describe(os.path.join(design, previous_name))
            entries.append(ranked("previous", previous, notes))
            if latest_time <= previous_time:
                problems.append("latest %s (%s) is not newer than previous %s (%s)" % (name, latest_time, previous_name, previous_time))
        kept = {e["zip"] for e in entries}
        extra = sorted(f for f in os.listdir(design) if f.lower().endswith(".zip") and f not in kept)
        manifest = json.dumps({"rule": old.get("rule", RULE), "masters": entries}, indent=1, ensure_ascii=False)

        stamp = json.loads(dg.read(dg.STAMP).decode("utf-8"))
        wanted = dict(stamp)
        wanted["zipSha256"] = latest["zipSha256"]
        wanted["content"] = content
        if stamp.get("zipSha256") != latest["zipSha256"]:
            wanted["delivery"] = "%s, dated %s in DESIGN/MANIFEST.json (rank latest)" % (name, latest["zipDate"])
            wanted["deliveredAt"] = latest_time.strftime("%Y-%m-%dT%H:%M")
        if args.adopt:
            wanted["adoptedAt"] = datetime.datetime.now().strftime("%Y-%m-%dT%H:%M")
        stamp_text = json.dumps(wanted, indent=1, ensure_ascii=False) + "\n"
    except (OSError, ValueError, KeyError, zipfile.BadZipFile) as error:
        print("receive_master: %s" % error, file=sys.stderr)
        return 2

    if args.check:
        if args.adopt or args.prune:
            print("receive_master: --check writes nothing; leave out --adopt and --prune", file=sys.stderr)
            return 2
        if extra:
            problems.append("DESIGN/ holds more than two masters: %s" % ", ".join(extra))
        if dg.read(dg.MANIFEST).decode("utf-8") != manifest:
            problems.append("DESIGN/MANIFEST.json differs from the ZIPs (rank, date, size, checksum or file list)")
        if stamp.get("delivery", "").find(name) < 0 or not stamp.get("deliveredAt", "").startswith(latest["zipDate"]):
            problems.append("design.stamp.json: delivery or deliveredAt does not match %s dated %s" % (name, latest["zipDate"]))
        if stamp.get("zipSha256") != latest["zipSha256"]:
            problems.append("design.stamp.json: zipSha256 is not %s" % latest["zipSha256"])
        if stamp.get("content") != content:
            problems.append("design.stamp.json: content is not %s" % content)
        for line in problems:
            print("receive_master: " + line)
        print("receive_master: %d mismatch(es)" % len(problems) if problems else "receive_master: manifest and stamp match the ZIPs")
        return 1 if problems else 0

    if problems:
        for line in problems:
            print("receive_master: " + line, file=sys.stderr)
        return 1
    if extra and not args.prune:
        print("receive_master: DESIGN/ holds more than two masters (%s): rerun with --prune to delete them" % ", ".join(extra), file=sys.stderr)
        return 1
    for f in extra:
        os.remove(os.path.join(design, f))
        print("deleted %s" % f)
    for path, text in ((dg.MANIFEST, manifest), (dg.STAMP, stamp_text)):
        if not os.path.exists(path) or dg.read(path).decode("utf-8") != text:
            with open(path, "w", encoding="utf-8", newline="") as handle:
                handle.write(text)
            print("wrote %s" % path)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
