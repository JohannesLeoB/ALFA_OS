import subprocess
import sys

ATTRIBUTION = "Designed by Johannes Leo Berger, made with help of Claude"
SUBJECT_LIMIT = 72
BODY_LIMIT = 3


def problems(message):
    lines = message.rstrip("\n").split("\n")
    if not lines[0].strip():
        return ["empty subject"]
    found = []
    if len(lines[0]) > SUBJECT_LIMIT:
        found.append("subject has %d characters, limit %d" % (len(lines[0]), SUBJECT_LIMIT))
    if len(lines) < 3 or lines[1].strip():
        found.append("line 2 must be blank")
    if lines[-1] != ATTRIBUTION:
        found.append("last line must be exactly: " + ATTRIBUTION)
    body = [line for line in lines[2:-1] if line.strip()]
    if len(body) > BODY_LIMIT:
        found.append("body has %d lines, limit %d" % (len(body), BODY_LIMIT))
    if any("co-authored-by" in line.lower() for line in lines):
        found.append("no Co-Authored-By line")
    return found


def main(arguments):
    if len(arguments) == 2 and arguments[0] == "--rev":
        message = subprocess.run(["git", "log", "-1", "--format=%B", arguments[1]], capture_output=True, text=True).stdout
    elif len(arguments) == 1:
        with open(arguments[0], encoding="utf-8") as handle:
            message = "".join(line for line in handle if not line.startswith("#"))
    else:
        print("usage: commit_check.py <message-file> | --rev <rev>", file=sys.stderr)
        return 2
    found = problems(message)
    for item in found:
        print("commit message: " + item, file=sys.stderr)
    return 1 if found else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
