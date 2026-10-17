#!/usr/bin/env python3
import subprocess
import sys

ATTRIBUTION = "Designed by Johannes Leo Berger, made with help of Claude"


def problems(message):
    lines = message.rstrip("\n").split("\n")
    found = []
    if not lines or not lines[0].strip():
        return ["empty subject"]
    if len(lines[0]) > 72:
        found.append("subject has %d characters, limit 72" % len(lines[0]))
    if lines[-1].strip() != ATTRIBUTION:
        found.append("last line must be: " + ATTRIBUTION)
    body = [line for line in lines[1:-1] if line.strip()]
    if len(body) > 3:
        found.append("body has %d lines, limit 3" % len(body))
    if any("Co-Authored-By" in line for line in lines):
        found.append("no Co-Authored-By line")
    return found


def main():
    args = sys.argv[1:]
    if len(args) == 2 and args[0] == "--rev":
        message = subprocess.run(["git", "log", "-1", "--format=%B", args[1]], capture_output=True, text=True).stdout
    elif len(args) == 1:
        message = "".join(line for line in open(args[0]) if not line.startswith("#"))
    else:
        print("usage: commit_check.py <message-file> | --rev <rev>", file=sys.stderr)
        return 2
    found = problems(message)
    for item in found:
        print("commit message: " + item, file=sys.stderr)
    return 1 if found else 0


if __name__ == "__main__":
    sys.exit(main())
