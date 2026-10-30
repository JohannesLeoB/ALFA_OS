import bisect
import hashlib
import json
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DOCUMENTS = ("README.md", "ARCHITECTURE.md", "AGENTS.md", "CLAUDE.md")
MODULES = {"Core", "Design", "Shell", "Storage", "Hub", "Assistant", "Mail", "Calculation", "Catalog", "Project", "Today", "Survey"}
INTEGRATIONS = {"Airtable", "ClickUp", "Sevdesk", "Clockodo", "Shipping", "Google", "Microsoft"}
FOLDERS = {"Model", "Logic", "Port", "Adapter", "State", "Store", "Tool"}
FORBIDDEN = {"Manager", "Helper", "Helpers", "Util", "Utils", "Utility", "Utilities", "Service", "Services", "Handler",
             "Impl", "Base", "Common", "Misc", "New", "Old"}
FOLDER_SUFFIX = {"Port": ("Port",), "Tool": ("Tool", "Registry"), "Store": ("Store",), "State": ("State",)}
SOURCE_SUFFIX_FOLDERS = {"Client": ("Adapter",), "Engine": ("Logic",), "Failure": ("Model",), "Parser": ("Logic", "Adapter")}
VIEW_SUFFIXES = ("Row", "List", "Detail", "Card", "Lane", "Button", "Editor", "ButtonStyle", "ToggleStyle", "Layout")
APP_FORBIDDEN_SUFFIXES = ("Client", "Store", "Engine", "Router", "Parser", "Registry", "Tool", "Port", "Failure")
SHEET_VALUES = os.path.join("App", "Design", "SheetValues.swift")
BANNED_TEXT = re.compile("m" + "yk", re.IGNORECASE)
DECLARATION = re.compile(
    r"^(?:@[\w.]+(?:\([^)]*\))?\s+)*((?:(?:public|internal|private|fileprivate|open|package|final|indirect|nonisolated)\s+)*)"
    r"(struct|class|enum|protocol|actor|extension|typealias)\s+([A-Za-z_]\w*)")
ANY_TYPE = re.compile(r"\b(?:struct|class|enum|protocol|actor|typealias)\s+([A-Za-z_]\w*)")
WORDS = re.compile(r"[A-Z][a-z]+\d*|[A-Z]+\d*(?![a-z])|[a-z]+\d*|\d+")
NUMBER = re.compile(r"(?<![\w.$])(0[xX][0-9a-fA-F_]+|\d[\d_]*(?:\.\d[\d_]*)?(?:[eE][+-]?\d+)?)")
COLOR = re.compile(r"#colorLiteral|\b(?:Color|NSColor|UIColor)\s*\([^)]*\b(?:red|white|hue|green|blue)\s*:\s*[\d.]")
AVAILABLE = re.compile(r"[#@]available\([^)]*\)")
TICKS = re.compile(r"`([^`\s]+)`")
LINK = re.compile(r"\]\(([^)\s]+)\)")
HEADING = re.compile(r"^#{1,6}\s+(.*?)\s*$", re.MULTILINE)
PATH_ROOTS = {"Sources", "App", "Tests", "Resources", "utils", ".githooks", ".github"}
FILE_TOKEN = re.compile(r"^[\w.\-]+\.(swift|py|sh|json|yml|md|plist|xcstrings|entitlements)$")
SKIPPED_DIRECTORIES = {".build", ".git", "tmp", "dist", "__pycache__", ".claude"}

PROPER = {"Base64"}
findings = []


def report(path, line, message):
    where = path if line is None else "%s:%d" % (path, line)
    findings.append("%s: %s" % (where, message))


def read(path):
    with open(os.path.join(ROOT, path), encoding="utf-8") as handle:
        return handle.read()


def strip(text):
    out = []
    comments = []
    size = len(text)
    state = {"line": 1}

    def emit(chunk):
        out.append(chunk)
        state["line"] += chunk.count("\n")

    def string(i, hashes, multi):
        close = ('"""' if multi else '"') + "#" * hashes
        escape = "\\" + "#" * hashes
        while i < size:
            if text.startswith(escape + "(", i):
                i = code(i + len(escape) + 1, True)
                continue
            if text.startswith(escape, i):
                i += len(escape) + 1
                continue
            if text.startswith(close, i):
                return i + len(close)
            if text[i] == "\n":
                emit("\n")
            i += 1
        return i

    def block(i):
        depth = 0
        while i < size:
            if text.startswith("/*", i):
                depth += 1
                i += 2
            elif text.startswith("*/", i):
                depth -= 1
                i += 2
                if depth == 0:
                    return i
            else:
                if text[i] == "\n":
                    emit("\n")
                i += 1
        return i

    def code(i, nested):
        depth = 0
        while i < size:
            c = text[i]
            if nested:
                if c == "(":
                    depth += 1
                elif c == ")":
                    if depth == 0:
                        return i + 1
                    depth -= 1
            if text.startswith("//", i):
                comments.append(state["line"])
                while i < size and text[i] != "\n":
                    i += 1
                continue
            if text.startswith("/*", i):
                comments.append(state["line"])
                i = block(i)
                continue
            if c in '#"':
                match = re.match(r'(#*)("""|")', text[i:i + 8])
                if match:
                    emit('""')
                    i = string(i + len(match.group(0)), len(match.group(1)), match.group(2) == '"""')
                    continue
            emit(c)
            i += 1
        return i

    code(0, False)
    return "".join(out), comments


def words(name):
    return WORDS.findall(name)


def name_problems(name):
    found = []
    parts = words(name)
    for part in parts:
        if part in FORBIDDEN or re.fullmatch(r"V\d+", part):
            found.append("forbidden word %s in %s" % (part, name))
    if parts and re.search(r"\d$", parts[-1]) and parts[-1] not in PROPER:
        found.append("number suffix in %s" % name)
    return found


def swift_files(top):
    base = os.path.join(ROOT, top)
    for folder, directories, files in os.walk(base):
        directories[:] = sorted(d for d in directories if d not in SKIPPED_DIRECTORIES)
        for name in sorted(files):
            if name.endswith(".swift"):
                yield os.path.relpath(os.path.join(folder, name), ROOT)


def check_layout():
    sources = os.path.join(ROOT, "Sources")
    modules = []
    for name in sorted(os.listdir(sources)):
        full = os.path.join(sources, name)
        if name == ".DS_Store":
            continue
        if not os.path.isdir(full):
            report("Sources/" + name, None, "file outside a module")
        elif name == "Integrations":
            for inner in sorted(os.listdir(full)):
                if inner == ".DS_Store":
                    continue
                if inner not in INTEGRATIONS or not os.path.isdir(os.path.join(full, inner)):
                    report("Sources/Integrations/" + inner, None, "not an allowed integration")
                else:
                    modules.append(("Sources/Integrations/" + inner, inner))
        elif name in MODULES:
            modules.append(("Sources/" + name, name))
        else:
            report("Sources/" + name, None, "not an allowed module")
    for relative, module in modules:
        full = os.path.join(ROOT, relative)
        for name in sorted(os.listdir(full)):
            if name == ".DS_Store":
                continue
            inner = os.path.join(full, name)
            if not os.path.isdir(inner):
                report(relative + "/" + name, None, "file directly in a module")
            elif name not in FOLDERS:
                report(relative + "/" + name, None, "not an allowed module folder")
            elif name == "Tool" and module != "Assistant":
                report(relative + "/" + name, None, "Tool folder only in Assistant")
            else:
                for entry in sorted(os.listdir(inner)):
                    if entry == ".DS_Store":
                        continue
                    if not entry.endswith(".swift") or os.path.isdir(os.path.join(inner, entry)):
                        report(relative + "/" + name + "/" + entry, None, "only Swift files directly in a module folder")
    known = {module for _, module in modules}
    tests = os.path.join(ROOT, "Tests")
    for name in sorted(os.listdir(tests)):
        if name == ".DS_Store":
            continue
        full = os.path.join(tests, name)
        if not os.path.isdir(full) or not name.endswith("Tests") or name[:-5] not in known:
            report("Tests/" + name, None, "not a <Module>Tests folder of an existing module")
            continue
        entries = [e for e in os.listdir(full) if e != ".DS_Store"]
        if entries != [name + ".swift"]:
            report("Tests/" + name, None, "must contain exactly %s.swift" % name)
    app = os.path.join(ROOT, "App")
    for name in sorted(os.listdir(app)):
        if name == ".DS_Store":
            continue
        full = os.path.join(app, name)
        if not os.path.isdir(full) or not re.fullmatch(r"[A-Z][A-Za-z]*", name):
            report("App/" + name, None, "App holds feature folders only")
            continue
        for entry in sorted(os.listdir(full)):
            if entry == ".DS_Store":
                continue
            if not entry.endswith(".swift") or os.path.isdir(os.path.join(full, entry)):
                report("App/%s/%s" % (name, entry), None, "only Swift files directly in a feature folder")
        for problem in name_problems(name):
            report("App/" + name, None, problem)


def declarations(code):
    found = []
    for number, line in enumerate(code.split("\n"), 1):
        if not line or line[0] in " \t":
            continue
        match = DECLARATION.match(line)
        if match:
            private = "private" in match.group(1)
            found.append((match.group(2), match.group(3), private, number))
    return found


def check_names(path, code, top):
    stem = os.path.basename(path)[:-6]
    parent = os.path.basename(os.path.dirname(path))
    base, plus, aspect = stem.partition("+")
    top_level = declarations(code)
    if plus:
        if not any(kind == "extension" and name == base for kind, name, _, _ in top_level):
            report(path, None, "file %s has no top-level extension of %s" % (stem, base))
        if not re.fullmatch(r"[A-Z][A-Za-z]*", aspect):
            report(path, None, "aspect name %s is not CamelCase" % aspect)
        if top == "Sources" and aspect == "":
            report(path, None, "empty aspect")
    elif not any(kind != "extension" and name == stem and not private for kind, name, private, _ in top_level):
        report(path, None, "no top-level type named like the file (%s)" % stem)
    if not re.fullmatch(r"[A-Z][A-Za-z0-9]*(\+[A-Z][A-Za-z0-9]*)?", stem):
        report(path, None, "file name %s is not CamelCase" % stem)
    for problem in name_problems(base) + name_problems(aspect or "X"):
        report(path, None, problem)
    for match in ANY_TYPE.finditer(code):
        for problem in name_problems(match.group(1)):
            report(path, code.count("\n", 0, match.start()) + 1, problem)
    last = words(base)[-1] if words(base) else base
    tail2 = "".join(words(base)[-2:])
    if top == "Sources":
        wanted = FOLDER_SUFFIX.get(parent)
        if wanted and last not in wanted and not plus:
            report(path, None, "%s folder needs a name ending in %s" % (parent, " or ".join(wanted)))
        for suffix in ("Port", "Tool", "Store", "State"):
            if last == suffix and parent != suffix and not (suffix == "State" and parent == "Model"):
                report(path, None, "suffix %s belongs in the %s folder" % (suffix, suffix))
        folders = SOURCE_SUFFIX_FOLDERS.get(last)
        if folders and parent not in folders:
            report(path, None, "suffix %s belongs in %s" % (last, "/".join(folders)))
        if last in VIEW_SUFFIXES or tail2 in VIEW_SUFFIXES:
            report(path, None, "view suffix %s outside App" % last)
    elif top == "App":
        if last in APP_FORBIDDEN_SUFFIXES or (last == "Registry"):
            report(path, None, "non-view suffix %s in App" % last)


def check_code(path, text, top):
    code, comments = strip(text)
    for line in comments:
        report(path, line, "comment")
    for number, line in enumerate(code.split("\n"), 1):
        if any(ord(c) > 127 for c in line):
            report(path, number, "non-ASCII character outside a string")
    if top != "Tests":
        check_names(path, code, top)
    if top == "App" and path != SHEET_VALUES:
        for number, line in enumerate(code.split("\n"), 1):
            line = AVAILABLE.sub("", line)
            if COLOR.search(line):
                report(path, number, "literal colour")
            for match in NUMBER.finditer(line):
                token = match.group(1)
                if token.lower().startswith("0x"):
                    report(path, number, "literal colour or number " + token)
                    continue
                if float(token.replace("_", "")) not in (0.0, 1.0, 2.0):
                    report(path, number, "literal number " + token)


def check_sources():
    for top in ("Sources", "App", "Tests"):
        for path in swift_files(top):
            text = read(path)
            if BANNED_TEXT.search(text):
                report(path, None, "banned word")
            check_code(path, text, top)
    for folder, directories, files in os.walk(os.path.join(ROOT, "utils")):
        directories[:] = [d for d in directories if d != "__pycache__"]
        for name in files:
            path = os.path.relpath(os.path.join(folder, name), ROOT)
            if name.endswith((".py", ".sh", ".plist")) and BANNED_TEXT.search(read(path)):
                report(path, None, "banned word")


def slug(heading):
    text = re.sub(r"[`*_]", "", heading).lower()
    text = re.sub(r"[^\w\- ]", "", text)
    return text.replace(" ", "-")


def repository_files():
    names = {}
    for folder, directories, files in os.walk(ROOT):
        directories[:] = [d for d in directories if d not in SKIPPED_DIRECTORIES]
        for name in files:
            names.setdefault(name, []).append(os.path.relpath(os.path.join(folder, name), ROOT))
    return names


TOP_LEVEL = {"App", "Sources", "Tests", "Resources", "utils", "README.md", "ARCHITECTURE.md", "AGENTS.md", "CLAUDE.md",
             "Package.swift", "Package.resolved", "project.yml", ".githooks", ".github", ".gitignore", ".git",
             "ALFA_OS.xcodeproj", "DESIGN", "dist", ".build", ".swiftpm", ".claude", ".DS_Store"}


def check_top_level():
    for name in sorted(os.listdir(ROOT)):
        if name not in TOP_LEVEL:
            report(name, None, "not in the top-level map of README.md")


def check_design():
    folder = os.path.join(ROOT, "DESIGN")
    if not os.path.isdir(folder):
        report("DESIGN", None, "folder missing")
        return
    names = sorted(n for n in os.listdir(folder) if n != ".DS_Store")
    try:
        manifest = json.load(open(os.path.join(folder, "MANIFEST.json")))
        masters = manifest["masters"]
    except (OSError, ValueError, KeyError):
        report("DESIGN/MANIFEST.json", None, "missing or unreadable")
        return
    expected = sorted(m["zip"] for m in masters) + ["MANIFEST.json"]
    if names != sorted(expected) or [m["rank"] for m in masters] != ["latest", "previous"]:
        report("DESIGN", None, "holds exactly MANIFEST.json and the latest and previous master ZIPs it names, found %s" % ", ".join(names))
    for m in masters:
        path = os.path.join(folder, m["zip"])
        if not os.path.isfile(path):
            continue
        digest = hashlib.sha256(open(path, "rb").read()).hexdigest()
        if digest != m.get("sha256") or os.path.getsize(path) != m.get("bytes"):
            report("DESIGN/" + m["zip"], None, "does not match MANIFEST.json")


def check_distribution():
    folder = os.path.join(ROOT, "dist")
    if not os.path.isdir(folder):
        return
    for name in sorted(os.listdir(folder)):
        if name == ".DS_Store" or name.endswith(".app") or name.endswith(".dmg"):
            continue
        report("dist/" + name, None, "dist holds only .app and .dmg files")


def check_documents():
    names = repository_files()
    found = sorted(path for paths in names.values() for path in paths if path.endswith(".md"))
    if found != sorted(DOCUMENTS):
        report("Markdown", None, "expected exactly %s, found %s" % (", ".join(sorted(DOCUMENTS)), ", ".join(found) or "none"))
    for document in DOCUMENTS:
        if not os.path.exists(os.path.join(ROOT, document)):
            continue
        text = read(document)
        for number, line in enumerate(text.split("\n"), 1):
            for target in LINK.findall(line):
                if re.match(r"[a-z]+:", target):
                    continue
                file_part, _, anchor = target.partition("#")
                resolved = os.path.normpath(os.path.join(ROOT, os.path.dirname(document), file_part)) if file_part else os.path.join(ROOT, document)
                if not os.path.exists(resolved):
                    report(document, number, "link target missing: " + target)
                elif anchor and resolved.endswith(".md"):
                    with open(resolved, encoding="utf-8") as handle:
                        slugs = {slug(h) for h in HEADING.findall(handle.read())}
                    if anchor not in slugs:
                        report(document, number, "anchor missing: " + target)
            for token in TICKS.findall(line):
                if any(c in token for c in "<>*…{}$~") or token.startswith(("http", "-")):
                    continue
                if "/" in token and token.split("/")[0] in PATH_ROOTS:
                    if not os.path.exists(os.path.join(ROOT, token.rstrip("/"))):
                        report(document, number, "path missing: " + token)
                elif "/" not in token and FILE_TOKEN.match(token):
                    if token not in names:
                        report(document, number, "file missing: " + token)


def run_script(arguments):
    result = subprocess.run([sys.executable, "-I"] + arguments, cwd=ROOT, capture_output=True, text=True)
    return result.returncode, [line for line in (result.stdout + result.stderr).split("\n") if line.strip()]


def check_generated():
    code, lines = run_script([os.path.join("utils", "generate_tokens.py"), "--check"])
    for line in lines:
        report("Sources/Design/Model", None, "tokens: " + line)
    if code and not lines:
        report("Sources/Design/Model", None, "tokens: generator failed")
    code, lines = run_script([os.path.join("utils", "merge_strings.py"), "--check"])
    for line in lines:
        report("Resources/Localizable.xcstrings", None, "strings: " + line)
    if code and not lines:
        report("Resources/Localizable.xcstrings", None, "strings: merge failed")


def main():
    check_layout()
    check_sources()
    check_documents()
    check_top_level()
    check_design()
    check_distribution()
    check_generated()
    for line in findings:
        print(line)
    if findings:
        print("check: %d findings" % len(findings))
        return 1
    print("check: ok")
    return 0


if __name__ == "__main__":
    sys.exit(main())
