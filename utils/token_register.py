import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TOKENS = os.path.join(ROOT, "Sources", "Design", "Model", "Tokens.swift")
COLORS = os.path.join(ROOT, "Sources", "Design", "Model", "Colors.swift")
SHEET = os.path.join(ROOT, "App", "Design", "SheetValues.swift")
GENERATED = os.path.join(ROOT, "Sources", "Design", "Model")


def token_names():
    names, stack = [], []
    for line in open(TOKENS, encoding="utf-8"):
        depth = (len(line) - len(line.lstrip(" "))) // 4
        stack = stack[:depth]
        enum = re.match(r"\s*public enum (\w+)", line)
        if enum:
            stack.append(enum.group(1))
            continue
        value = re.match(r"\s*public static let (\w+)", line)
        if value:
            names.append(".".join(stack + [value.group(1)]))
    return [(name, re.compile(re.escape(name) + r"\b")) for name in names]


def color_names():
    names = re.findall(r"public let (\w+): ColorValue", open(COLORS, encoding="utf-8").read())
    return [("Colors." + name, re.compile(r"\\\." + name + r"\b")) for name in names]


def sheet_names():
    names = re.findall(r"static let (\w+)", open(SHEET, encoding="utf-8").read())
    return [("SheetValues." + name, re.compile(r"SheetValues\." + name + r"\b")) for name in names]


def swift_lines():
    for top in ("App", "Sources"):
        for folder, directories, files in os.walk(os.path.join(ROOT, top)):
            if os.path.abspath(folder) == GENERATED:
                continue
            for name in sorted(files):
                if name.endswith(".swift"):
                    path = os.path.join(folder, name)
                    for number, line in enumerate(open(path, encoding="utf-8"), 1):
                        yield os.path.relpath(path, ROOT), number, line


def main(arguments):
    entries = token_names() + color_names() + sheet_names()
    places = {name: [] for name, _ in entries}
    lines = list(swift_lines())
    inner = list(enumerate(open(TOKENS, encoding="utf-8"), 1))
    for name, pattern in entries:
        for path, number, line in lines:
            if pattern.search(line):
                places[name].append("%s:%d" % (path, number))
        if name.startswith("Tokens."):
            group, leaf = name.split(".")[-2:]
            short = re.compile(r"(?<![\w.])" + re.escape(group + "." + leaf) + r"\b")
            for number, line in inner:
                if "=" in line and short.search(line.split("=", 1)[1]):
                    places[name].append("Tokens.swift:%d" % number)
    unused = [name for name, _ in entries if not places[name]]
    if "--unused" not in arguments:
        for name, _ in entries:
            if places[name]:
                print("%s\t%d\t%s" % (name, len(places[name]), ", ".join(places[name])))
    for name in unused:
        print("%s\t0\tunused" % name)
    print("register: %d values, %d read, %d unused" % (len(entries), len(entries) - len(unused), len(unused)), file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
