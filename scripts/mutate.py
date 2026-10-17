import json
import os
import random
import re
import signal
import subprocess
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PACKAGE = os.path.join(ROOT, "alfaos", "Kit")
SOURCES = [
    "alfaos/Kit/Sources/ShellCore",
    "alfaos/Kit/Sources/Hub",
    "alfaos/Kit/Sources/Mail",
    "fundus/alpha/Sources/MykilosServices/Mail",
]
OUT = os.path.join(ROOT, "dist", ".build-mutation")
OPERATORS = [
    (" == ", " != "),
    (" != ", " == "),
    (" && ", " || "),
    (" || ", " && "),
    (" <= ", " < "),
    (" >= ", " > "),
    (" < ", " <= "),
    (" > ", " >= "),
    ("true", "false"),
    ("false", "true"),
    (" + ", " - "),
    (" - ", " + "),
    ("isEmpty", "isEmpty == false"),
    (".insert(", ".remove("),
    ("return nil", "return nil as Never?"),
    (".first", ".last"),
    (".last", ".first"),
]
SKIP = re.compile(r"^\s*(import |//|///|case |@|\}|\{|public enum|enum |struct |final class |class |protocol |extension )")


def candidates():
    found = []
    for base in SOURCES:
        for folder, _, names in os.walk(os.path.join(ROOT, base)):
            for name in sorted(names):
                if not name.endswith(".swift") or name in ("DesignTokens.swift", "GeneratedTokens.swift"):
                    continue
                path = os.path.join(folder, name)
                with open(path, encoding="utf-8") as handle:
                    lines = handle.read().split("\n")
                for number, line in enumerate(lines):
                    if SKIP.match(line) or '"' in line and line.count('"') % 2:
                        continue
                    for old, new in OPERATORS:
                        index = line.find(old)
                        if index < 0:
                            continue
                        if '"' in line[:index] and line[:index].count('"') % 2:
                            continue
                        found.append((os.path.relpath(path, ROOT), number, old, new))
    return found


FUNDUS = os.path.join(ROOT, "fundus", "alpha")
FUNDUS_FILTER = "MailWireTests|IMAPActionTests|GmailActionTests|MailStoreTests|MailProbeTests|GmailFoldersTests|GmailDetailFetchTests|MailZitatTests"


def run_tests(relative):
    kit = run_package(PACKAGE, ["swift", "test"])
    if kit[0] != "survived" or not relative.startswith("fundus/"):
        return kit
    fundus = run_package(FUNDUS, ["swift", "test", "--filter", FUNDUS_FILTER])
    return fundus[0], kit[1] + fundus[1]


def run_package(cwd, command):
    started = time.time()
    try:
        result = subprocess.run(command, cwd=cwd, capture_output=True, text=True, timeout=900)
    except subprocess.TimeoutExpired:
        return "timeout", time.time() - started
    text = result.stdout + result.stderr
    elapsed = time.time() - started
    executed = re.findall(r"Executed (\d+) tests?, with (\d+) failures?", text)
    if not executed:
        return "invalid", elapsed
    failures = max(int(count) for _, count in executed)
    return ("killed" if failures > 0 or result.returncode != 0 else "survived"), elapsed


def main():
    count = int(sys.argv[1]) if len(sys.argv) > 1 else 200
    seed = int(sys.argv[2]) if len(sys.argv) > 2 else 1
    label = sys.argv[3] if len(sys.argv) > 3 else "baseline"
    pool = candidates()
    random.Random(seed).shuffle(pool)
    if len(sys.argv) > 4:
        with open(sys.argv[4]) as handle:
            kept = {(e["file"], e["line"] - 1, e["from"], e["to"]) for e in json.load(handle) if e["status"] == "survived" and e["file"].startswith("fundus/")}
        pool = [c for c in pool if c in kept]
    os.makedirs(OUT, exist_ok=True)
    report = os.path.join(OUT, label + ".json")
    originals = {}
    done = []

    def restore(*_):
        for path, text in originals.items():
            with open(path, "w", encoding="utf-8") as handle:
                handle.write(text)
        originals.clear()

    def stop(*_):
        restore()
        sys.exit(130)

    signal.signal(signal.SIGINT, stop)
    signal.signal(signal.SIGTERM, stop)
    valid = 0
    try:
        for relative, number, old, new in pool:
            if valid >= count:
                break
            path = os.path.join(ROOT, relative)
            with open(path, encoding="utf-8") as handle:
                original = handle.read()
            lines = original.split("\n")
            lines[number] = lines[number].replace(old, new, 1)
            originals[path] = original
            with open(path, "w", encoding="utf-8") as handle:
                handle.write("\n".join(lines))
            status, elapsed = run_tests(relative)
            restore()
            entry = {"file": relative, "line": number + 1, "from": old, "to": new, "status": status, "seconds": round(elapsed, 1)}
            done.append(entry)
            if status in ("killed", "survived"):
                valid += 1
            with open(report, "w") as handle:
                json.dump(done, handle, indent=1)
            print(valid, status, relative, number + 1, old.strip(), "->", new.strip(), flush=True)
    finally:
        restore()
    killed = sum(1 for e in done if e["status"] == "killed")
    survived = sum(1 for e in done if e["status"] == "survived")
    invalid = sum(1 for e in done if e["status"] in ("invalid", "timeout"))
    print("killed", killed, "survived", survived, "invalid", invalid)


if __name__ == "__main__":
    main()
