#!/usr/bin/env python3
"""Guard for the repository: branch, sprawl, language, meta, token, drift and commit rules.

Modes:
  commit            staged files (pre-commit, pre-merge-commit)
  msg <file>        commit message file (commit-msg)
  push <old> <new> [<remote ref>]
                    commits and tree of a push (pre-push); old may be all zeros
  baum              whole working tree (scripts/pruefen.sh)
  ci                tree of HEAD, remote branches and the commits since
                    WAECHTER_FROM (GitHub Action)
  rules             every rule with reason, who, when, origin, scope and threshold,
                    then the tolerations with their state
  status            commits waiting for a push and the findings that hold them back

Exit code 0: nothing blocks. Exit code 1: at least one error.
Word, rule and toleration lists live in scripts/waechter-woerter.txt.
"""
import bisect
import datetime
import fnmatch
import hashlib
import os
import re
import subprocess
import sys

STRENG_SPRACHE_META = True

MAX_BYTES = 2 * 1024 * 1024
MAX_LINES = 800
MAX_SENTENCE_WORDS = 20
MAX_SUBJECT = 72
MAIN_REF = "refs/heads/main"
WARN_SAMPLES = 3
RULE_FIELDS = 7
STATUS_HINT = ("green when the findings above are fixed; a toleration line with end date and issue "
               "turns a path rule yellow until that date")

CODE_EXT = (".swift", ".py", ".sh", ".yml")
NAME_WORDS = re.compile(r"[^\W_]+")
RULE_ID = re.compile(r"R\d+")
ISSUE = re.compile(r"#\d+")
DATE = re.compile(r"\d{4}-\d{2}-\d{2}")
REFS = re.compile(r"Refs #\d+|Refs: none \S.*")
UMLAUT = re.compile("[\u00e4\u00f6\u00fc\u00c4\u00d6\u00dc\u00df]")
LETTERS = re.compile(r"[^\W\d_]+")
IDENT = re.compile(r"[A-Za-z_][A-Za-z0-9_]*")
NAME_PARTS = re.compile(r"[A-Z]+(?![a-z])|[A-Z]?[a-z]+")
NUMBER = re.compile(r"(?<![\w.])-?\d+(?:\.\d+)?")
PRINT = re.compile(r"(?<![\w.])print\s*\(")
SYSTEM_SIZE = re.compile(r"\.system\(\s*size\s*:")
PADDING = re.compile(r"\.padding\s*\(")
SPACING = re.compile(r"\bspacing\s*:\s*(-?\d+(?:\.\d+)?)")
CORNER = re.compile(r"\bcornerRadius\s*[:(]\s*(-?\d+(?:\.\d+)?)")
COLOR_CALL = re.compile(
    r"(?<![\w.])(?:Color|NSColor|UIColor|CGColor)\s*\(\s*(?:\.\w+\s*,\s*)?"
    r"(?:red|green|blue|hue|white|gray|hex|srgbRed|calibratedRed|deviceRed|displayP3Red)\s*:"
    r"|(?<![\w.])Color\s*\(\s*\.(?:sRGB|displayP3|sRGBLinear|extendedSRGB)\s*,"
    r"|#colorLiteral\s*\("
)
COLOR_NAMES = "red|orange|yellow|green|mint|teal|cyan|blue|indigo|purple|pink|brown|white|black|gray|grey"
COLOR_NAMED = re.compile(
    r"(?<![\w.])(?:Color|NSColor|UIColor)\.(?:%s)\b"
    r"|\.(?:foregroundStyle|foregroundColor|tint|fill|stroke|background)\(\s*\.(?:%s)\s*\)" % (COLOR_NAMES, COLOR_NAMES)
)
HEX = re.compile(r"#[0-9A-Fa-f]{6}(?:[0-9A-Fa-f]{2})?(?![0-9A-Fa-f\w])")

ROOT = "."
HERE = os.path.dirname(os.path.abspath(__file__))


class Toleration:
    def __init__(self, line, rules):
        fields = [field.strip() for field in line.split("|", 4)]
        self.line = line
        self.glob = self.rule = self.date = self.issue = self.reason = ""
        self.end = None
        if len(fields) == 5:
            self.glob, self.rule, self.date, self.issue, self.reason = fields
            if DATE.fullmatch(self.date):
                try:
                    self.end = datetime.date.fromisoformat(self.date)
                except ValueError:
                    pass
        self.valid = bool(
            self.end and self.glob and self.rule in rules and ISSUE.fullmatch(self.issue) and self.reason)

    def days_left(self, today):
        return (self.end - today).days


class Words:
    def __init__(self, path):
        sections, current = {}, None
        with open(path, encoding="utf-8") as handle:
            for raw in handle:
                line = raw.strip()
                if not line or line.startswith("#"):
                    continue
                if line.startswith("[") and line.endswith("]"):
                    current = line[1:-1]
                    sections.setdefault(current, [])
                elif current is not None:
                    sections[current].append(line)
        get = lambda name: sections.get(name, [])
        self.roots_dirs = {x.rstrip("/") for x in get("roots") if x.endswith("/")}
        self.roots_files = {x for x in get("roots") if not x.endswith("/")}
        self.code_dirs = tuple(get("code-dirs"))
        self.token_dirs = tuple(get("token-dirs"))
        self.token_exempt = set(get("token-exempt"))
        self.material_dirs = tuple(get("material"))
        self.blocked_words = set(get("blocked-words"))
        self.blocked_tails = set(get("blocked-trailing-words"))
        self.blocked_suffixes = tuple(get("blocked-suffixes"))
        self.fillers = set(get("fillers"))
        self.stems = set(get("stems"))
        self.contract_names = set(get("contract-names"))
        self.meta_words = set(get("meta-words"))
        self.meta_patterns = [re.compile(p) for p in get("meta-patterns")]
        self.verbs = set(get("verbs"))
        trailer = get("trailer")
        self.trailer = trailer[0] if trailer else ""
        self.rules = {}
        for line in get("rules"):
            fields = [field.strip() for field in line.split("|")]
            if len(fields) == RULE_FIELDS and RULE_ID.fullmatch(fields[0]):
                self.rules[fields[0]] = fields
        self.tolerations = [Toleration(line, self.rules) for line in get("tolerations")]


def days(count):
    return "%d day%s" % (count, "" if count == 1 else "s")


class Report:
    def __init__(self, strict, words):
        self.strict, self.words = strict, words
        self.today = datetime.date.today()
        self.items = []

    def check_tolerations(self):
        for toleration in self.words.tolerations:
            if not toleration.valid:
                self.add("toleration", "waechter-woerter.txt",
                         "invalid toleration line '%s', expected: glob | rule | YYYY-MM-DD | #issue | reason"
                         % toleration.line)

    def tolerate(self, rule, where, text):
        path = re.sub(r":\d+$", "", where)
        hits = [t for t in self.words.tolerations
                if t.valid and t.rule == rule and fnmatch.fnmatchcase(path, t.glob)]
        running = [t for t in hits if t.end >= self.today]
        if running:
            best = max(running, key=lambda t: t.end)
            return "%s (tolerated until %s, %s left, %s)" % (
                text, best.date, days(best.days_left(self.today)), best.issue), True
        if hits:
            best = max(hits, key=lambda t: t.end)
            return "%s (toleration expired on %s, %s)" % (text, best.date, best.issue), False
        return text, False

    def add(self, rule, where, text, warn=False):
        soft = warn or (rule in ("R3", "R4") and not self.strict)
        if not soft:
            text, soft = self.tolerate(rule, where, text)
        self.items.append(("warn" if soft else "error", rule, where, text))

    def count(self, severity, rule=None):
        return sum(1 for s, r, _, _ in self.items if s == severity and (rule is None or r == rule))

    def print_out(self, show_all, tail=()):
        shown = {}
        for severity, rule, where, text in self.items:
            if severity == "warn":
                shown[rule] = shown.get(rule, 0) + 1
                if not show_all and shown[rule] > WARN_SAMPLES:
                    continue
                print("warn %s %s: %s" % (rule, where, text))
            else:
                print("%s %s: %s" % (rule, where, text))
        for rule, total in sorted(shown.items()):
            if not show_all and total > WARN_SAMPLES:
                print("warn %s ... %d more warnings (run with --all to list them)" % (rule, total - WARN_SAMPLES))
        fired = {rule for _, rule, _, _ in self.items if rule in self.words.rules}
        for rule in sorted(fired, key=lambda r: int(r[1:])):
            _, reason, who, when, origin, _, threshold = self.words.rules[rule]
            print("  %s: %s" % (rule, reason))
            print("      set by %s on %s; origin: %s; limit: %s" % (who, when, origin, threshold))
        if self.count("error"):
            for line in tail:
                print(line)
        print("waechter: errors=%d warnings=%d R3=%d R4=%d" % (
            self.count("error"), self.count("warn"), self.count("warn", "R3"), self.count("warn", "R4")))


def git(*args, data=None):
    return subprocess.run(["git", *args], cwd=ROOT, input=data, capture_output=True)


def git_text(*args):
    proc = git(*args)
    return proc.stdout.decode("utf-8", errors="replace").strip() if proc.returncode == 0 else ""


def is_zero(sha):
    return bool(sha) and set(sha) == {"0"}


class Entry:
    def __init__(self, path, mode, size, key, read):
        self.path, self.mode, self.size, self.key, self.read = path, mode, size, key, read


def index_entries():
    out = git("ls-files", "-s", "-z").stdout.decode("utf-8", errors="replace")
    rows = []
    for record in out.split("\0"):
        if not record:
            continue
        meta, path = record.split("\t", 1)
        mode, sha, stage = meta.split()
        if stage == "0":
            rows.append((path, mode, sha))
    shas = [sha for _, mode, sha in rows if mode != "160000"]
    sizes = {}
    if shas:
        check = git("cat-file", "--batch-check", data=("\n".join(shas) + "\n").encode()).stdout.decode()
        for line in check.splitlines():
            parts = line.split()
            if len(parts) == 3 and parts[2].isdigit():
                sizes[parts[0]] = int(parts[2])
    return [
        Entry(path, mode, sizes.get(sha, 0), sha, (lambda s=sha: git("cat-file", "blob", s).stdout))
        for path, mode, sha in rows
    ]


def tree_entries(rev):
    out = git("ls-tree", "-r", "-z", "-l", rev).stdout.decode("utf-8", errors="replace")
    entries = []
    for record in out.split("\0"):
        if not record:
            continue
        meta, path = record.split("\t", 1)
        mode, kind, sha, size = meta.split()
        size = int(size) if size.isdigit() else 0
        entries.append(Entry(path, mode, size, sha, (lambda s=sha: git("cat-file", "blob", s).stdout)))
    return entries


def work_entries():
    out = git("ls-files", "-z", "-c", "-o", "--exclude-standard").stdout.decode("utf-8", errors="replace")
    entries, seen = [], set()
    for path in out.split("\0"):
        full = os.path.join(ROOT, path)
        if not path or path in seen or os.path.islink(full):
            continue
        seen.add(path)
        if os.path.isdir(full):
            entries.append(Entry(path, "160000", 0, None, lambda: b""))
            continue
        if not os.path.isfile(full):
            continue

        def read(p=full):
            with open(p, "rb") as handle:
                return handle.read()

        size = os.path.getsize(full)
        key = hashlib.sha1(read()).hexdigest() if size else None
        entries.append(Entry(path, "100644", size, key, read))
    return entries


def _scan(text, i, in_interp):
    n, out, depth, start = len(text), [], 0, i
    while i < n:
        if text.startswith("//", i):
            j = text.find("\n", i)
            j = n if j < 0 else j
            out += [("code", start, i), ("comment", i, j)]
            i = start = j
        elif text.startswith("/*", i):
            j, level = i + 2, 1
            while j < n and level:
                if text.startswith("/*", j):
                    level, j = level + 1, j + 2
                elif text.startswith("*/", j):
                    level, j = level - 1, j + 2
                else:
                    j += 1
            out += [("code", start, i), ("comment", i, j)]
            i = start = j
        elif text[i] == '"':
            quote = '"""' if text.startswith('"""', i) else '"'
            out.append(("code", start, i + len(quote)))
            i, parts, closed = _string(text, i + len(quote), quote)
            out += parts
            start = i
            i += len(quote) if closed else 0
        elif in_interp and text[i] == "(":
            depth, i = depth + 1, i + 1
        elif in_interp and text[i] == ")":
            if depth == 0:
                out.append(("code", start, i))
                return out, i
            depth, i = depth - 1, i + 1
        else:
            i += 1
    out.append(("code", start, n))
    return out, n


def _string(text, i, quote):
    n, parts, start = len(text), [], i
    while i < n:
        if text.startswith(quote, i):
            parts.append(("string", start, i))
            return i, parts, True
        if quote == '"' and text[i] == "\n":
            break
        if text[i] == "\\":
            if text.startswith("\\(", i):
                parts.append(("string", start, i))
                inner, j = _scan(text, i + 2, True)
                parts += inner
                i = start = j + 1
                continue
            i += 2
            continue
        i += 1
    parts.append(("string", start, min(i, n)))
    return min(i, n), parts, False


def swift_segments(text):
    """Return a list of (kind, start, end) that covers the text. Quotes stay in code."""
    segments, _ = _scan(text, 0, False)
    return [s for s in segments if s[2] > s[1]]


def blank(text, segments, keep_strings):
    """Text of the same length with comments (and strings) blanked. Newlines stay."""
    chars = list(text)
    for kind, a, b in segments:
        if kind == "comment" or (kind == "string" and not keep_strings):
            for k in range(a, b):
                if chars[k] != "\n":
                    chars[k] = " "
    return "".join(chars)


class Lines:
    def __init__(self, text):
        self.starts = [m.end() for m in re.finditer("\n", text)]

    def of(self, pos):
        return bisect.bisect_right(self.starts, pos) + 1


def check_local_branches(report):
    head = git_text("symbolic-ref", "-q", "HEAD")
    if head != MAIN_REF:
        report.add("R1", "HEAD", "HEAD is %s, not main" % (head or "detached"))
    for ref in git_text("for-each-ref", "--format=%(refname)", "refs/heads").splitlines():
        if ref != MAIN_REF:
            report.add("R1", ref, "local branch other than main")


def check_remote_heads(report):
    if git("remote", "get-url", "origin").returncode != 0:
        report.add("R1", "origin", "no origin remote, remote branches not checked", warn=True)
        return
    proc = git("ls-remote", "--heads", "origin")
    if proc.returncode != 0:
        report.add("R1", "origin", "cannot list remote branches")
        return
    for line in proc.stdout.decode().splitlines():
        ref = line.split("\t")[-1]
        if ref != MAIN_REF:
            report.add("R1", ref, "remote branch other than main")


def check_push_ref(report, old, new, ref):
    if ref and ref != MAIN_REF:
        report.add("R1", ref, "push target is not refs/heads/main")
    if is_zero(new):
        report.add("R1", ref or "push", "a push must not delete a ref")
        return
    if old and not is_zero(old) and git("merge-base", "--is-ancestor", old, new).returncode != 0:
        report.add("R1", ref or "push", "not a fast-forward, old remote tip is not an ancestor")


def in_material(words, path):
    return path.startswith(words.material_dirs)


def blocked_name(words, part):
    low = part.lower()
    pieces = NAME_WORDS.findall(low)
    return (part == ".DS_Store" or low.endswith(words.blocked_suffixes)
            or any(piece in words.blocked_words for piece in pieces)
            or any(piece in words.blocked_tails for piece in pieces[1:]))


def check_files(report, words, entries, focus, new_paths):
    for entry in entries:
        if focus is not None and entry.path not in focus:
            continue
        parts = entry.path.split("/")
        if entry.mode == "160000" or ".git" in parts:
            report.add("R2", entry.path, "nested git repository")
        for part in parts:
            if blocked_name(words, part):
                report.add("R2", entry.path, "blocked file name '%s'" % part)
                break
        if entry.size > MAX_BYTES:
            report.add("R2", entry.path, "file larger than 2 MB (%d bytes)" % entry.size)
        if new_paths is None or entry.path in new_paths:
            allowed = parts[0] in (words.roots_dirs if len(parts) > 1 else words.roots_files)
            if not allowed:
                report.add("R2", entry.path, "new file outside the allowed root entries")
    groups = {}
    for entry in entries:
        if entry.key and entry.size > 0:
            groups.setdefault(entry.key, []).append(entry.path)
    for paths in groups.values():
        if len(paths) > 1:
            for path in paths:
                if focus is None or path in focus:
                    others = [p for p in paths if p != path]
                    report.add("R2", path, "same content as %s" % others[0])


def is_code_file(words, path):
    if any("fixture" in part.lower() for part in path.split("/")[:-1]):
        return False
    if not path.startswith(words.code_dirs):
        return False
    return path.endswith(CODE_EXT) or path.startswith(".githooks/")


def german_words(words, line):
    found = []
    for token in LETTERS.findall(line):
        if token == token.lower() or (token[0].isupper() and token[1:] == token[1:].lower()):
            if token.lower() in words.contract_names:
                continue
            if token.lower() in words.fillers and token.lower() not in found:
                found.append(token.lower())
    return found


def german_names(words, line):
    found = []
    for ident in IDENT.findall(line):
        for part in NAME_PARTS.findall(ident):
            low = part.lower()
            if low in words.contract_names:
                continue
            hit = low in words.stems or any(len(s) >= 8 and low.startswith(s) for s in words.stems)
            if hit and ident not in found:
                found.append(ident)
    return found


def meta_hits(words, line):
    found = [w for w in LETTERS.findall(line) if w in words.meta_words]
    for pattern in words.meta_patterns:
        found += [m.group(0) for m in pattern.finditer(line)]
    return list(dict.fromkeys(found))


def check_language(report, words, path, text, segments):
    for number, line in enumerate(text.split("\n"), 1):
        if UMLAUT.search(line):
            report.add("R3", "%s:%d" % (path, number), "umlaut or sharp s in code")
    if segments is None:
        text_parts, code_parts = [(0, text)], [(0, text)]
    else:
        text_parts = [(a, text[a:b]) for kind, a, b in segments if kind != "code"]
        code_parts = [(a, text[a:b]) for kind, a, b in segments if kind == "code"]
    lines = Lines(text)
    for start, chunk in text_parts:
        base = lines.of(start)
        for offset, line in enumerate(chunk.split("\n")):
            where = "%s:%d" % (path, base + offset)
            hits = german_words(words, line)
            if hits:
                report.add("R3", where, "German words in text: %s" % ", ".join(hits[:4]))
            meta = meta_hits(words, line)
            if meta:
                report.add("R4", where, "meta reference in text: %s" % ", ".join(meta[:4]))
    for start, chunk in code_parts:
        base = lines.of(start)
        for offset, line in enumerate(chunk.split("\n")):
            hits = german_names(words, line)
            if hits:
                report.add("R3", "%s:%d" % (path, base + offset), "German name: %s" % ", ".join(hits[:4]))


def call_args(code, open_index):
    depth = 0
    for k in range(open_index, len(code)):
        if code[k] == "(":
            depth += 1
        elif code[k] == ")":
            depth -= 1
            if depth == 0:
                return code[open_index + 1:k]
    return code[open_index + 1:]


def nonzero(literal):
    return float(literal) != 0.0


def check_tokens(report, path, text, segments):
    code = blank(text, segments, keep_strings=False)
    with_strings = blank(text, segments, keep_strings=True)
    lines = Lines(text)

    def add(pos, what):
        report.add("R5", "%s:%d" % (path, lines.of(pos)), "%s, take the value from the theme" % what)

    for m in COLOR_CALL.finditer(code):
        add(m.start(), "fixed colour %s" % m.group(0).strip())
    for m in COLOR_NAMED.finditer(code):
        add(m.start(), "fixed colour %s" % m.group(0).strip())
    for m in HEX.finditer(with_strings):
        add(m.start(), "fixed colour %s" % m.group(0))
    for m in SYSTEM_SIZE.finditer(code):
        add(m.start(), "fixed font size")
    for m in PADDING.finditer(code):
        args = call_args(code, m.end() - 1)
        if any(nonzero(n) for n in NUMBER.findall(args)):
            add(m.start(), "number in .padding")
    for m in SPACING.finditer(code):
        if nonzero(m.group(1)):
            add(m.start(), "number in spacing")
    for m in CORNER.finditer(code):
        if nonzero(m.group(1)):
            add(m.start(), "number in cornerRadius")


def check_drift(report, path, text, segments, token_dir):
    count = len(text.splitlines())
    if count > MAX_LINES:
        report.add("R6", path, "%d lines, limit is %d" % (count, MAX_LINES))
    if segments is not None and token_dir:
        lines = Lines(text)
        for m in PRINT.finditer(blank(text, segments, keep_strings=False)):
            report.add("R6", "%s:%d" % (path, lines.of(m.start())), "print( in app code")


def check_content(report, words, entries, focus):
    for entry in entries:
        if focus is not None and entry.path not in focus:
            continue
        if in_material(words, entry.path):
            continue
        if not is_code_file(words, entry.path) and not entry.path.endswith(CODE_EXT):
            continue
        if entry.mode == "160000" or entry.size > MAX_BYTES:
            continue
        text = entry.read().decode("utf-8", errors="replace")
        is_swift = entry.path.endswith(".swift")
        segments = swift_segments(text) if is_swift else None
        if is_code_file(words, entry.path):
            check_language(report, words, entry.path, text, segments)
        in_token_dir = is_swift and entry.path.startswith(words.token_dirs) and "Tests" not in entry.path.split("/")
        if in_token_dir:
            parts = entry.path.split("/")
            exempt = len(parts) > 2 and parts[0] == "app" and parts[1] == "Sources" and parts[2] in words.token_exempt
            if not exempt:
                check_tokens(report, entry.path, text, segments)
        check_drift(report, entry.path, text, segments, in_token_dir)


def check_message(report, words, text, label, files=()):
    lines = [l.rstrip() for l in text.splitlines() if not l.startswith("#")]
    while lines and not lines[-1].strip():
        lines.pop()
    while lines and not lines[0].strip():
        lines.pop(0)
    if not lines:
        report.add("R7", label, "empty commit message")
        return
    subject = lines[0]
    if len(subject) > MAX_SUBJECT:
        report.add("R7", label, "subject longer than %d characters (%d)" % (MAX_SUBJECT, len(subject)))
    if subject.endswith("."):
        report.add("R7", label, "subject ends with a period")
    if (subject.split() or [""])[0] not in words.verbs:
        material_only = bool(files) and all(in_material(words, path) for path in files)
        report.add("R7", label, "subject must start with an imperative verb: %s" % ", ".join(sorted(words.verbs)),
                   warn=material_only)
    if lines[-1] != words.trailer:
        report.add("R7", label, "last line must be exactly the trailer line")
    body_lines = lines[1:-1] if lines[-1] == words.trailer else lines[1:]
    code_files = [path for path in files if path.endswith(CODE_EXT) and not in_material(words, path)]
    if code_files and not any(REFS.fullmatch(line.strip()) for line in body_lines):
        report.add("R7", label, "code commit without a body line 'Refs #<N>' (or 'Refs: none <reason>')", warn=True)
    for line in lines:
        if re.match(r"(?i)co-authored-by:", line.strip()):
            report.add("R7", label, "Co-Authored-By line is not allowed")
    full = "\n".join([subject] + body_lines)
    if UMLAUT.search(full):
        report.add("R7", label, "umlaut or sharp s in message")
    hits = german_words(words, full)
    if hits:
        report.add("R7", label, "German words in message: %s" % ", ".join(hits[:4]))
    units, current = [], []
    for line in body_lines:
        stripped = line.strip()
        bullet = re.match(r"([-*]|\d+[.)])\s+", stripped)
        if not stripped or bullet:
            if current:
                units.append(" ".join(current))
            current = [stripped[bullet.end():]] if bullet else []
        else:
            current.append(stripped)
    if current:
        units.append(" ".join(current))
    for unit in units:
        for sentence in re.split(r"(?<=[.!?])\s+", unit):
            count = len([w for w in sentence.split() if re.search(r"[A-Za-z0-9]", w)])
            if count > MAX_SENTENCE_WORDS:
                report.add("R7", label, "sentence with %d words, limit is %d: %s..." % (
                    count, MAX_SENTENCE_WORDS, sentence[:30]))


def changed_paths(*args):
    out = git(*args).stdout.decode("utf-8", errors="replace")
    return [path for path in out.split("\0") if path]


def staged(*flags):
    return changed_paths("diff", "--cached", "--name-only", "-z", "--no-renames", *flags)


def check_commits(report, words, revs):
    proc = git("rev-list", "--reverse", *revs)
    for sha in proc.stdout.decode().split():
        body = git("log", "-1", "--format=%B", sha).stdout.decode("utf-8", errors="replace")
        files = changed_paths("diff-tree", "--no-commit-id", "--name-only", "-r", "-z", "--no-renames", "--root", sha)
        check_message(report, words, body, sha[:7], files)


def check_push(report, words, old, new, ref):
    check_local_branches(report)
    check_push_ref(report, old, new, ref)
    if not is_zero(new):
        entries = tree_entries(new)
        check_files(report, words, entries, None, None)
        check_content(report, words, entries, None)
        if is_zero(old):
            check_commits(report, words, [new, "--not", "--remotes"])
        else:
            check_commits(report, words, ["%s..%s" % (old, new)])


def show_status(report, words):
    head = git_text("rev-parse", "--verify", "-q", "HEAD")
    upstream = (git_text("rev-parse", "--verify", "-q", "@{upstream}")
                or git_text("rev-parse", "--verify", "-q", "origin/main"))
    if upstream and head:
        waiting = git_text("log", "--reverse", "--format=%h %s", "%s..HEAD" % upstream).splitlines()
        print("waiting commits: %d" % len(waiting))
        for line in waiting:
            print("  " + line)
    else:
        print("waiting commits: unknown, no upstream branch")
    if head:
        check_push(report, words, upstream or "0" * 40, head, MAIN_REF)


def print_rules(words):
    today = datetime.date.today()
    for fields in sorted(words.rules.values(), key=lambda f: int(f[0][1:])):
        print(" | ".join(fields))
    for item in words.tolerations:
        if not item.valid:
            print("toleration invalid | %s" % item.line)
            continue
        left = item.days_left(today)
        state = "running, %s left" % days(left) if left >= 0 else "expired %s ago" % days(-left)
        print("toleration %s | %s | %s | %s | %s | %s" % (item.glob, item.rule, item.date, item.issue, state, item.reason))
    return 0


def run(argv):
    global ROOT
    args = [a for a in argv if a != "--all"]
    show_all = "--all" in argv
    if not args:
        print(__doc__)
        return 2
    words = Words(os.path.join(HERE, "waechter-woerter.txt"))
    mode = args[0]
    if mode == "rules":
        return print_rules(words)
    top = subprocess.run(["git", "rev-parse", "--show-toplevel"], capture_output=True)
    if top.returncode != 0:
        print("waechter: not inside a git repository")
        return 1 if mode == "status" else 2
    ROOT = top.stdout.decode().strip()
    report = Report(STRENG_SPRACHE_META or os.environ.get("WAECHTER_STRICT") == "1", words)
    if mode != "msg":
        report.check_tolerations()

    if mode == "commit":
        check_local_branches(report)
        changed, added = set(staged("--diff-filter=ACM")), set(staged("--diff-filter=A"))
        entries = index_entries()
        check_files(report, words, entries, changed, added)
        check_content(report, words, entries, changed)
    elif mode == "msg":
        if len(args) < 2:
            print("waechter: msg needs a file")
            return 2
        with open(args[1], encoding="utf-8", errors="replace") as handle:
            check_message(report, words, handle.read(), "message", staged())
    elif mode == "push":
        if len(args) < 3:
            print("waechter: push needs <old> <new>")
            return 2
        check_push(report, words, args[1], args[2], args[3] if len(args) > 3 else None)
    elif mode == "baum":
        check_local_branches(report)
        entries = work_entries()
        check_files(report, words, entries, None, None)
        check_content(report, words, entries, None)
    elif mode == "ci":
        check_remote_heads(report)
        entries = tree_entries("HEAD")
        check_files(report, words, entries, None, None)
        check_content(report, words, entries, None)
        base = os.environ.get("WAECHTER_FROM", "")
        if base and not is_zero(base) and git("cat-file", "-e", base + "^{commit}").returncode == 0:
            check_commits(report, words, ["%s..HEAD" % base])
        else:
            check_commits(report, words, ["-1", "HEAD"])
    elif mode == "status":
        show_status(report, words)
    else:
        print("waechter: unknown mode %s" % mode)
        return 2

    report.print_out(show_all, (STATUS_HINT,) if mode == "status" else ())
    return 1 if report.count("error") else 0


if __name__ == "__main__":
    sys.exit(run(sys.argv[1:]))
