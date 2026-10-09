#!/usr/bin/env bash
# pruefen.sh: full check of the repository.
#
# Runs the guard, the guard tests, build, tests, seam rules and licenses.
# Call from anywhere inside the repo:   bash scripts/pruefen.sh
#
# Exit 0: no ERROR (SKIPPED and WARNING do not count as errors).
# Exit 1: at least one ERROR.
#
# Writes only to app/.build (SwiftPM), to ALFAcolor/*.xcodeproj (XcodeGen, ignored by git)
# and to a temporary folder that is removed at the end. The Xcode build runs in the temporary folder.
# The seam rules are the table SEAM_RULES in the Python part below.
# Assumption: the Xcode scheme has the name of the target, "ALFAcolor".
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)" || exit 2
cd "$ROOT" || exit 2

TMP="$(mktemp -d "${TMPDIR:-/tmp}/pruefen.XXXXXX")" || exit 2
trap 'rm -rf "$TMP"' EXIT
RESULTS="$TMP/results.tsv"
: > "$RESULTS"

row() { printf '%s\t%s\t%s\n' "$1" "$2" "$3" >> "$RESULTS"; }
excerpt() { echo "--- log excerpt: $1 ---"; tail -n 30 "$2"; echo "--- end of excerpt ---"; }
first_error() { grep -m1 'error:' "$1" | cut -c1-200; }

echo "pruefen.sh · repo: $ROOT · head: $(git rev-parse --short HEAD 2>/dev/null)"
echo

# 1. Guard: branch, sprawl, language, meta, tokens, drift (tree mode)
if python3 scripts/waechter.py baum --all > "$TMP/guard.log" 2>&1; then
  SUMMARY="$(tail -n 1 "$TMP/guard.log")"
  row "guard: tree" "OK" "$SUMMARY"
else
  row "guard: tree" "ERROR" "$(grep -m1 -E '^R[0-9] ' "$TMP/guard.log")"
  excerpt "guard" "$TMP/guard.log"
fi

# 2. Guard tests
if python3 scripts/waechter_test.py > "$TMP/guard-test.log" 2>&1; then
  row "guard: tests" "OK" "scripts/waechter_test.py · $(grep -E '^Ran ' "$TMP/guard-test.log" | tail -n 1)"
else
  row "guard: tests" "ERROR" "scripts/waechter_test.py · $(grep -m1 -E '^(FAIL|ERROR):' "$TMP/guard-test.log")"
  excerpt "guard tests" "$TMP/guard-test.log"
fi

# 3. Swift package app/: build and test
if [ -f app/Package.swift ]; then
  if (cd app && swift build) > "$TMP/build.log" 2>&1; then
    row "swift build" "OK" "app/"
  else
    row "swift build" "ERROR" "app/ · $(first_error "$TMP/build.log")"
    excerpt "swift build" "$TMP/build.log"
  fi
  if (cd app && swift test) > "$TMP/test.log" 2>&1; then
    row "swift test" "OK" "app/ · $(grep -E 'Test run with|Executed [0-9]+ test' "$TMP/test.log" | tail -n 1 | sed 's/^[^A-Za-z]*//')"
  else
    row "swift test" "ERROR" "app/ · $(first_error "$TMP/test.log")"
    excerpt "swift test" "$TMP/test.log"
  fi
else
  row "swift build" "ERROR" "app/Package.swift is missing"
fi

# 4. Xcode target: only when ALFAcolor/ exists, otherwise skipped
if [ -f ALFAcolor/project.yml ]; then
  XG="$(command -v xcodegen 2>/dev/null)"
  [ -n "$XG" ] || XG=/opt/homebrew/bin/xcodegen
  if [ -x "$XG" ] && (cd ALFAcolor && "$XG" generate) > "$TMP/xcodegen.log" 2>&1; then
    row "xcodegen generate" "OK" "ALFAcolor/project.yml"
  else
    row "xcodegen generate" "ERROR" "ALFAcolor/project.yml (xcodegen is missing or failed)"
    excerpt "xcodegen generate" "$TMP/xcodegen.log"
  fi
  PROJ="$(find ALFAcolor -maxdepth 1 -name '*.xcodeproj' | head -n 1)"
  if [ -n "$PROJ" ] && xcodebuild -project "$PROJ" -scheme ALFAcolor -derivedDataPath "$ROOT/.build-xcode/pruefen" CODE_SIGNING_ALLOWED=NO build > "$TMP/xcodebuild.log" 2>&1; then
    row "xcodebuild build" "OK" "$PROJ · scheme ALFAcolor"
  else
    row "xcodebuild build" "ERROR" "${PROJ:-no .xcodeproj} · $(first_error "$TMP/xcodebuild.log")"
    excerpt "xcodebuild build" "$TMP/xcodebuild.log"
  fi
  # App tests (no test host: the app is not launched, nothing is shown or played)
  if [ -n "$PROJ" ] && xcodebuild -project "$PROJ" -scheme ALFAcolorAppTests -destination 'platform=macOS' -derivedDataPath "$ROOT/.build-xcode/pruefen" CODE_SIGNING_ALLOWED=NO test > "$TMP/xctest.log" 2>&1; then
    row "xcodebuild test" "OK" "$PROJ · scheme ALFAcolorAppTests · $(grep -E 'Test run with' "$TMP/xctest.log" | tail -n 1 | sed 's/^[^A-Za-z]*//')"
  else
    row "xcodebuild test" "ERROR" "${PROJ:-no .xcodeproj} · $(grep -m1 -E 'error:|recorded an issue' "$TMP/xctest.log" | cut -c1-200)"
    excerpt "xcodebuild test" "$TMP/xctest.log"
  fi
else
  row "xcodegen generate" "SKIPPED" "ALFAcolor/project.yml is missing, no Xcode target yet"
  row "xcodebuild build" "SKIPPED" "ALFAcolor/ is missing, no Xcode target to build"
fi

# 5. Seam rules and licenses (python3, rules in the Python part)
python3 - "$ROOT" "$RESULTS" <<'PY'
import json
import os
import re
import sys

ROOT, RESULTS = sys.argv[1], sys.argv[2]
os.chdir(ROOT)

# ---------------------------------------------------------------------------
# SEAM_RULES: import rules per module (plan/CODEBASE.md, section on seam rules). Add rules here.
#   mode "only":   allowed are Foundation, the Apple frameworks in "frameworks"
#                  and the package modules in "packages". Everything else is a finding.
#   mode "except": forbidden are only the Apple frameworks in "frameworks".
#                  Package modules are free (the compiler checks the dependencies).
# Modules without an entry follow DEFAULT_RULE (forbidden: SwiftUI, AppKit).
# Reading of "only Foundation": Foundation plus the package modules declared
# in app/Package.swift. Otherwise today's code would be a finding (Geometry and Tokens
# import ALFAcolorCore, ColorLab imports Tokens).
# ---------------------------------------------------------------------------
ALWAYS_ALLOWED = {"Foundation", "Swift", "_Concurrency"}
SEAM_RULES = {
    "ALFAcolorCore": {"mode": "only", "frameworks": set(), "packages": set()},
    "Geometry": {"mode": "only", "frameworks": set(), "packages": {"ALFAcolorCore"}},
    "Tokens": {"mode": "only", "frameworks": set(), "packages": {"ALFAcolorCore"}},
    "ColorLab": {"mode": "only", "frameworks": {"CoreGraphics"}, "packages": {"Tokens"}},
    "AppTheme": {"mode": "except", "frameworks": {"AppKit"}},   # SwiftUI and WebKit allowed
    "CodePlayer": {"mode": "except", "frameworks": {"AppKit"}},  # SwiftUI and WebKit allowed
    "Motion": {"mode": "only", "frameworks": {"CoreGraphics"}, "packages": set()},
    "BoardModel": {"mode": "only", "frameworks": {"Observation"}, "packages": {"ALFAcolorCore", "Geometry", "Document", "Tokens"}},
}
DEFAULT_RULE = {"mode": "except", "frameworks": {"SwiftUI", "AppKit"}}
# Fixed colour values: these folders under app/Sources are exempt. Tests are always exempt.
COLOR_FREE = {"AppTheme", "Tokens", "ColorLab"}
MAX_LINES = 800

SWIFT_ROOTS = ["app", "ALFAcolor"]
TEST_DIR = re.compile(r"(Tests?|UITests)$")
IMPORT = re.compile(
    r"^[ \t]*(?:@\w+[ \t]+)*import[ \t]+(?:(?:struct|class|enum|protocol|typealias|func|var|let)[ \t]+)?([A-Za-z_]\w*)",
    re.M,
)
PRINT = re.compile(r"(?<![\w.])print\s*\(")
COLOR_CALL = re.compile(
    r"(?<![\w.])(?:Color|NSColor|UIColor|CGColor)\s*\(\s*(?:\.\w+\s*,\s*)?"
    r"(?:red|green|blue|hue|white|gray|hex|srgbRed|calibratedRed|deviceRed|displayP3Red)\s*:"
    r"|(?<![\w.])Color\s*\(\s*\.(?:sRGB|displayP3|sRGBLinear|extendedSRGB)\s*,"
    r"|#colorLiteral\s*\("
)
HEX = re.compile(r"#[0-9A-Fa-f]{6}(?:[0-9A-Fa-f]{2})?(?![0-9A-Fa-f\w])")
LICENSES = "scripts/lizenzen.txt"


def files_under(roots, swift_only=True):
    for root in roots:
        if not os.path.isdir(root):
            continue
        for dirpath, dirnames, filenames in os.walk(root):
            dirnames[:] = [d for d in dirnames if not d.startswith(".") and d != "DerivedData"]
            for name in sorted(filenames):
                if (name.endswith(".swift") if swift_only else name == "Package.resolved"):
                    yield os.path.join(dirpath, name)


def is_test(path):
    return any(TEST_DIR.search(part) for part in path.split("/")[:-1])


def strip(text, blank_strings):
    """Remove comments; with blank_strings also blank the string contents. Positions and lines stay."""
    def blank_out(s):
        return "".join("\n" if c == "\n" else " " for c in s)
    out, i, n = [], 0, len(text)
    while i < n:
        if text.startswith("//", i):
            j = text.find("\n", i)
            j = n if j < 0 else j
            out.append(blank_out(text[i:j]))
            i = j
        elif text.startswith("/*", i):
            j, depth = i + 2, 1
            while j < n and depth:
                if text.startswith("/*", j):
                    depth, j = depth + 1, j + 2
                elif text.startswith("*/", j):
                    depth, j = depth - 1, j + 2
                else:
                    j += 1
            out.append(blank_out(text[i:j]))
            i = j
        elif text.startswith('"', i):
            quote = '"""' if text.startswith('"""', i) else '"'
            j = i + len(quote)
            while j < n and not text.startswith(quote, j):
                if text[j] == "\\":
                    j += 2
                elif quote == '"' and text[j] == "\n":
                    break
                else:
                    j += 1
            j = min(j, n)
            end = j + len(quote) if text.startswith(quote, j) else j
            inner = text[i + len(quote):j]
            out.append(text[i:i + len(quote)] + (blank_out(inner) if blank_strings else inner) + text[j:end])
            i = end
        else:
            out.append(text[i])
            i += 1
    return "".join(out)


def line_of(text, pos):
    return text.count("\n", 0, pos) + 1


def package_modules():
    text = open("app/Package.swift", encoding="utf-8").read() if os.path.isfile("app/Package.swift") else ""
    return set(re.findall(r'\.(?:target|testTarget|executableTarget|systemLibrary)\(\s*name:\s*"([^"]+)"', text))


rows = []


def finish(name, findings, ok_text):
    if findings:
        rows.extend((name, "ERROR", f) for f in findings)
    else:
        rows.append((name, "OK", ok_text))


swift_files = list(files_under(SWIFT_ROOTS))
sources = {p: open(p, encoding="utf-8", errors="replace").read() for p in swift_files}
TARGETS = package_modules()

# Seam rule: imports per module (app/Sources only, no tests)
findings, checked = [], 0
for path in swift_files:
    parts = path.split("/")
    if parts[0] != "app" or len(parts) < 4 or parts[1] != "Sources" or is_test(path):
        continue
    checked += 1
    module = parts[2]
    rule = SEAM_RULES.get(module, DEFAULT_RULE)
    code = strip(sources[path], blank_strings=True)
    for m in IMPORT.finditer(code):
        name, number = m.group(1), line_of(code, m.start(1))
        if name in ALWAYS_ALLOWED:
            reason = None
        elif name in TARGETS:
            reason = (f"package module {name} is not declared for {module}"
                      if rule["mode"] == "only" and name not in rule["packages"] else None)
        elif rule["mode"] == "only":
            allowed = ", ".join(["Foundation"] + sorted(rule["frameworks"]))
            reason = f"{name} is not allowed in {module} (allowed: {allowed})" if name not in rule["frameworks"] else None
        else:
            reason = f"{name} is forbidden in {module}" if name in rule["frameworks"] else None
        if reason:
            findings.append(f"{path}:{number} · import {name} · {reason}")
finish("seams: imports", findings, f"{checked} files in app/Sources checked")

# Seam rule: fixed colour values (not in AppTheme, Tokens, ColorLab and tests)
findings, checked = [], 0
for path in swift_files:
    parts = path.split("/")
    if is_test(path) or (len(parts) > 2 and parts[0] == "app" and parts[1] == "Sources" and parts[2] in COLOR_FREE):
        continue
    checked += 1
    text = sources[path]
    blanked = strip(text, blank_strings=True)
    for m in COLOR_CALL.finditer(blanked):
        findings.append(f"{path}:{line_of(blanked, m.start())} · {m.group(0).strip()} · fixed colour value outside AppTheme")
    kept = strip(text, blank_strings=False)
    for m in HEX.finditer(kept):
        findings.append(f"{path}:{line_of(kept, m.start())} · {m.group(0)} · fixed hex colour outside AppTheme")
finish("seams: colour values", findings, f"{checked} files checked (AppTheme, Tokens, ColorLab, tests exempt)")

# Seam rule: no print( in code (all Swift files in app/ and ALFAcolor/)
findings = []
for path in swift_files:
    code = strip(sources[path], blank_strings=True)
    for m in PRINT.finditer(code):
        findings.append(f"{path}:{line_of(code, m.start())} · print( · log output does not belong in the code")
finish("seams: print(", findings, f"{len(swift_files)} Swift files without print(")

# Seam rule: files over 800 lines
findings = []
for path in swift_files:
    count = len(sources[path].splitlines())
    if count > MAX_LINES:
        findings.append(f"{path} · {count} lines (limit {MAX_LINES})")
if swift_files:
    biggest = max(swift_files, key=lambda p: len(sources[p].splitlines()))
    biggest_ok = f"largest: {biggest} with {len(sources[biggest].splitlines())} lines (limit {MAX_LINES})"
else:
    biggest_ok = "no Swift files found"
finish("seams: file length", findings, biggest_ok)

# Licenses: every pin from a Package.resolved needs a line with a license in scripts/lizenzen.txt
findings, entries, names = [], {}, []
if not os.path.isfile(LICENSES):
    findings.append(f"{LICENSES} is missing")
else:
    for raw in open(LICENSES, encoding="utf-8"):
        stripped = raw.strip()
        if stripped and not stripped.startswith("#"):
            columns = [x.strip() for x in stripped.split("|")]
            entries[columns[0].lower()] = columns
for path in files_under(SWIFT_ROOTS, swift_only=False):
    try:
        data = json.load(open(path, encoding="utf-8"))
        found = [p.get("identity") or p.get("package") or p.get("location", "?") for p in data.get("pins", [])]
        found += [p.get("package") or p.get("repositoryURL", "?").rstrip("/").rsplit("/", 1)[-1].removesuffix(".git")
                  for p in data.get("object", {}).get("pins", [])]
    except (OSError, ValueError) as e:
        findings.append(f"{path} is not readable ({e})")
        continue
    for name in found:
        names.append(name)
        columns = entries.get(name.lower(), [])
        license_name = columns[1] if len(columns) > 1 else ""
        if not license_name or re.search(r"\?|unknown|pending", license_name, re.I):
            findings.append(f"{path} · {name} has no checked license in {LICENSES}")
if names:
    license_ok = f"{len(names)} dependencies with a license in {LICENSES}"
else:
    license_ok = f"no third-party dependencies (no Package.resolved with pins), {LICENSES} present"
finish("licenses", findings, license_ok)

# Output: table (shell rows first, then these)
shell_rows = []
with open(RESULTS, encoding="utf-8") as handle:
    for line in handle:
        line = line.rstrip("\n")
        if line:
            shell_rows.append(tuple(line.split("\t", 2)))
all_rows = shell_rows + rows
head = ("Check", "Result", "Where")
w1 = max(len(r[0]) for r in [head] + all_rows)
w2 = max(len(r[1]) for r in [head] + all_rows)
print(f"{head[0]:<{w1}}  {head[1]:<{w2}}  {head[2]}")
print("-" * (w1 + w2 + 4 + 60))
for r in all_rows:
    print(f"{r[0]:<{w1}}  {r[1]:<{w2}}  {r[2]}")
errors = sum(1 for r in all_rows if r[1] == "ERROR")
skipped = sum(1 for r in all_rows if r[1] == "SKIPPED")
warnings = sum(1 for r in all_rows if r[1] == "WARNING")
print()
print(f"Result: {errors} errors, {skipped} skipped, {warnings} warnings.")
sys.exit(1 if errors else 0)
PY
RC=$?
exit "$RC"
