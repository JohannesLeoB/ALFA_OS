#!/usr/bin/env bash
# pruefen.sh · Setzkasten (Brief B-105)
#
# Prüft, was eine Maschine prüfen kann: Build, Tests, Nahtregeln, Lizenzen.
# Aufruf aus dem Repo-Wurzelordner:   bash scripts/pruefen.sh
#
# Rückgabe 0: kein FEHLER (ÜBERSPRUNGEN zählt nicht als Fehler).
# Rückgabe 1: mindestens ein FEHLER.
#
# Schreibt nur in app/.build (SwiftPM), in Setzkasten/*.xcodeproj (XcodeGen, in .gitignore)
# und in einen temporären Ordner, der am Ende gelöscht wird. Der Xcode-Build läuft im Temporärordner.
# Die Nahtregeln stehen als Tabelle REGELN im Python-Teil unten.
# Annahme: das Xcode-Schema heißt wie das Ziel, "Setzkasten" (B-101).
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)" || exit 2
cd "$ROOT" || exit 2

TMP="$(mktemp -d "${TMPDIR:-/tmp}/pruefen.XXXXXX")" || exit 2
trap 'rm -rf "$TMP"' EXIT
ERG="$TMP/ergebnisse.tsv"
: > "$ERG"

zeile() { printf '%s\t%s\t%s\n' "$1" "$2" "$3" >> "$ERG"; }
auszug() { echo "--- Log-Auszug: $1 ---"; tail -n 30 "$2"; echo "--- Ende Auszug ---"; }
erste_fehlerzeile() { grep -m1 'error:' "$1" | cut -c1-200; }

echo "pruefen.sh · Repo: $ROOT · Kopf: $(git rev-parse --short HEAD 2>/dev/null)"
echo

# 1. Swift-Paket app/: bauen und testen
if [ -f app/Package.swift ]; then
  if (cd app && swift build) > "$TMP/build.log" 2>&1; then
    zeile "swift build" "OK" "app/"
  else
    zeile "swift build" "FEHLER" "app/ · $(erste_fehlerzeile "$TMP/build.log")"
    auszug "swift build" "$TMP/build.log"
  fi
  if (cd app && swift test) > "$TMP/test.log" 2>&1; then
    zeile "swift test" "OK" "app/ · $(grep -E 'Test run with|Executed [0-9]+ test' "$TMP/test.log" | tail -n 1 | sed 's/^[^A-Za-z]*//')"
  else
    zeile "swift test" "FEHLER" "app/ · $(erste_fehlerzeile "$TMP/test.log")"
    auszug "swift test" "$TMP/test.log"
  fi
else
  zeile "swift build" "FEHLER" "app/Package.swift fehlt"
fi

# 2. Xcode-Ziel: nur wenn Setzkasten/ existiert (B-101), sonst überspringen
if [ -f Setzkasten/project.yml ]; then
  XG="$(command -v xcodegen 2>/dev/null)"
  [ -n "$XG" ] || XG=/opt/homebrew/bin/xcodegen
  if [ -x "$XG" ] && (cd Setzkasten && "$XG" generate) > "$TMP/xcodegen.log" 2>&1; then
    zeile "xcodegen generate" "OK" "Setzkasten/project.yml"
  else
    zeile "xcodegen generate" "FEHLER" "Setzkasten/project.yml (xcodegen fehlt oder schlug fehl)"
    auszug "xcodegen generate" "$TMP/xcodegen.log"
  fi
  PROJ="$(find Setzkasten -maxdepth 1 -name '*.xcodeproj' | head -n 1)"
  if [ -n "$PROJ" ] && xcodebuild -project "$PROJ" -scheme Setzkasten -derivedDataPath "$TMP/dd" CODE_SIGNING_ALLOWED=NO build > "$TMP/xcodebuild.log" 2>&1; then
    zeile "xcodebuild build" "OK" "$PROJ · Schema Setzkasten"
  else
    zeile "xcodebuild build" "FEHLER" "${PROJ:-kein .xcodeproj} · $(erste_fehlerzeile "$TMP/xcodebuild.log")"
    auszug "xcodebuild build" "$TMP/xcodebuild.log"
  fi
else
  zeile "xcodegen generate" "ÜBERSPRUNGEN" "Setzkasten/project.yml fehlt, Xcode-Ziel noch nicht angelegt (B-101)"
  zeile "xcodebuild build" "ÜBERSPRUNGEN" "Setzkasten/ fehlt, kein Xcode-Ziel zu bauen (B-101)"
fi

# 3. Nahtregeln und Lizenzen (python3, Regeln im Python-Teil)
python3 - "$ROOT" "$ERG" <<'PY'
import json
import os
import re
import sys

ROOT, ERG = sys.argv[1], sys.argv[2]
os.chdir(ROOT)

# ---------------------------------------------------------------------------
# REGELN · Nahtregeln je Modul (plan/CODEBASE.md, Abschnitt Naht-Regeln). Hier ergänzen.
#   modus "nur":    erlaubt sind Foundation, die Apple-Frameworks in "frameworks"
#                   und die Paketmodule in "pakete". Alles andere ist ein Befund.
#   modus "ausser": verboten sind nur die Apple-Frameworks in "frameworks".
#                   Paketmodule sind frei (der Compiler prüft die Abhängigkeiten).
# Module ohne Eintrag gelten wie STANDARD (verboten: SwiftUI, AppKit).
# Auslegung von "nur Foundation": Foundation plus die in app/Package.swift
# deklarierten Paketmodule. Sonst wäre der heutige Code (Geometry und Tokens
# importieren SetzkastenCore, ColorLab importiert Tokens) ein Befund.
# Entscheidung offen, siehe Übergabe in plan/briefe/B-105.md.
# ---------------------------------------------------------------------------
IMMER_ERLAUBT = {"Foundation", "Swift", "_Concurrency"}
REGELN = {
    "SetzkastenCore": {"modus": "nur", "frameworks": set(), "pakete": set()},
    "Geometry": {"modus": "nur", "frameworks": set(), "pakete": {"SetzkastenCore"}},
    "Tokens": {"modus": "nur", "frameworks": set(), "pakete": {"SetzkastenCore"}},
    "ColorLab": {"modus": "nur", "frameworks": {"CoreGraphics"}, "pakete": {"Tokens"}},
    "AppTheme": {"modus": "ausser", "frameworks": {"AppKit"}},   # SwiftUI und WebKit erlaubt
    "Renderers": {"modus": "ausser", "frameworks": {"AppKit"}},  # SwiftUI und WebKit erlaubt
}
STANDARD = {"modus": "ausser", "frameworks": {"SwiftUI", "AppKit"}}
# Feste Farbwerte: diese Ordner unter app/Sources sind ausgenommen (Vorgabe B-105). Tests sind immer ausgenommen.
FARBE_FREI = {"AppTheme", "Tokens", "ColorLab"}
MAX_ZEILEN = 800

SWIFT_WURZELN = ["app", "Setzkasten"]
TEST_ORDNER = re.compile(r"(Tests?|UITests)$")
IMPORT = re.compile(
    r"^[ \t]*(?:@\w+[ \t]+)*import[ \t]+(?:(?:struct|class|enum|protocol|typealias|func|var|let)[ \t]+)?([A-Za-z_]\w*)",
    re.M,
)
PRINT = re.compile(r"(?<![\w.])print\s*\(")
FARBAUFRUF = re.compile(
    r"(?<![\w.])(?:Color|NSColor|UIColor|CGColor)\s*\(\s*(?:\.\w+\s*,\s*)?"
    r"(?:red|green|blue|hue|white|gray|hex|srgbRed|calibratedRed|deviceRed|displayP3Red)\s*:"
    r"|(?<![\w.])Color\s*\(\s*\.(?:sRGB|displayP3|sRGBLinear|extendedSRGB)\s*,"
    r"|#colorLiteral\s*\("
)
HEX = re.compile(r"#[0-9A-Fa-f]{6}(?:[0-9A-Fa-f]{2})?(?![0-9A-Fa-f\w])")
LIZENZ = "scripts/lizenzen.txt"


def dateien(wurzeln, nur_swift=True):
    for wurzel in wurzeln:
        if not os.path.isdir(wurzel):
            continue
        for dp, dn, fn in os.walk(wurzel):
            dn[:] = [d for d in dn if not d.startswith(".") and d != "DerivedData"]
            for f in sorted(fn):
                if (f.endswith(".swift") if nur_swift else f == "Package.resolved"):
                    yield os.path.join(dp, f)


def ist_test(pfad):
    return any(TEST_ORDNER.search(teil) for teil in pfad.split("/")[:-1])


def ohne(text, leeren):
    """Entfernt Kommentare; leeren=True leert zusätzlich den Inhalt von Strings. Positionen und Zeilen bleiben."""
    def leer(s):
        return "".join("\n" if c == "\n" else " " for c in s)
    out, i, n = [], 0, len(text)
    while i < n:
        if text.startswith("//", i):
            j = text.find("\n", i)
            j = n if j < 0 else j
            out.append(leer(text[i:j]))
            i = j
        elif text.startswith("/*", i):
            j, tiefe = i + 2, 1
            while j < n and tiefe:
                if text.startswith("/*", j):
                    tiefe, j = tiefe + 1, j + 2
                elif text.startswith("*/", j):
                    tiefe, j = tiefe - 1, j + 2
                else:
                    j += 1
            out.append(leer(text[i:j]))
            i = j
        elif text.startswith('"', i):
            q = '"""' if text.startswith('"""', i) else '"'
            j = i + len(q)
            while j < n and not text.startswith(q, j):
                if text[j] == "\\":
                    j += 2
                elif q == '"' and text[j] == "\n":
                    break
                else:
                    j += 1
            j = min(j, n)
            ende = j + len(q) if text.startswith(q, j) else j
            inhalt = text[i + len(q):j]
            out.append(text[i:i + len(q)] + (leer(inhalt) if leeren else inhalt) + text[j:ende])
            i = ende
        else:
            out.append(text[i])
            i += 1
    return "".join(out)


def zeilen_nr(text, pos):
    return text.count("\n", 0, pos) + 1


def paketmodule():
    text = open("app/Package.swift", encoding="utf-8").read() if os.path.isfile("app/Package.swift") else ""
    return set(re.findall(r'\.(?:target|testTarget|executableTarget|systemLibrary)\(\s*name:\s*"([^"]+)"', text))


rows = []


def abschliessen(name, funde, ok):
    if funde:
        rows.extend((name, "FEHLER", f) for f in funde)
    else:
        rows.append((name, "OK", ok))


alle = list(dateien(SWIFT_WURZELN))
texte = {p: open(p, encoding="utf-8", errors="replace").read() for p in alle}
TARGETS = paketmodule()

# Nahtregel: Importe je Modul (nur app/Sources, ohne Tests)
funde, geprueft = [], 0
for pfad in alle:
    teile = pfad.split("/")
    if teile[0] != "app" or len(teile) < 4 or teile[1] != "Sources" or ist_test(pfad):
        continue
    geprueft += 1
    modul = teile[2]
    regel = REGELN.get(modul, STANDARD)
    code = ohne(texte[pfad], leeren=True)
    for m in IMPORT.finditer(code):
        imp, nr = m.group(1), zeilen_nr(code, m.start(1))
        if imp in IMMER_ERLAUBT:
            grund = None
        elif imp in TARGETS:
            grund = (f"Paketmodul {imp} in {modul} nicht deklariert"
                     if regel["modus"] == "nur" and imp not in regel["pakete"] else None)
        elif regel["modus"] == "nur":
            erlaubt = ", ".join(["Foundation"] + sorted(regel["frameworks"]))
            grund = f"{imp} in {modul} nicht erlaubt (erlaubt: {erlaubt})" if imp not in regel["frameworks"] else None
        else:
            grund = f"{imp} in {modul} verboten" if imp in regel["frameworks"] else None
        if grund:
            funde.append(f"{pfad}:{nr} · import {imp} · {grund}")
abschliessen("Naht: Importe", funde, f"{geprueft} Dateien in app/Sources geprüft")

# Nahtregel: feste Farbwerte (ohne AppTheme, Tokens, ColorLab und Tests)
funde, geprueft = [], 0
for pfad in alle:
    teile = pfad.split("/")
    if ist_test(pfad) or (len(teile) > 2 and teile[0] == "app" and teile[1] == "Sources" and teile[2] in FARBE_FREI):
        continue
    geprueft += 1
    text = texte[pfad]
    ohne_str = ohne(text, leeren=True)
    for m in FARBAUFRUF.finditer(ohne_str):
        funde.append(f"{pfad}:{zeilen_nr(ohne_str, m.start())} · {m.group(0).strip()} · fester Farbwert außerhalb AppTheme")
    mit_str = ohne(text, leeren=False)
    for m in HEX.finditer(mit_str):
        funde.append(f"{pfad}:{zeilen_nr(mit_str, m.start())} · {m.group(0)} · fester Hex-Farbwert außerhalb AppTheme")
abschliessen("Naht: Farbwerte", funde, f"{geprueft} Dateien geprüft (AppTheme, Tokens, ColorLab, Tests ausgenommen)")

# Nahtregel: kein print( im Code (alle Swift-Dateien in app/ und Setzkasten/)
funde = []
for pfad in alle:
    code = ohne(texte[pfad], leeren=True)
    for m in PRINT.finditer(code):
        funde.append(f"{pfad}:{zeilen_nr(code, m.start())} · print( · Logausgabe gehört nicht in den Code")
abschliessen("Naht: print(", funde, f"{len(alle)} Swift-Dateien ohne print(")

# Nahtregel: Dateien über 800 Zeilen
funde = []
for pfad in alle:
    n = len(texte[pfad].splitlines())
    if n > MAX_ZEILEN:
        funde.append(f"{pfad} · {n} Zeilen (Grenze {MAX_ZEILEN})")
if alle:
    gross = max(alle, key=lambda p: len(texte[p].splitlines()))
    gross_ok = f"größte: {gross} mit {len(texte[gross].splitlines())} Zeilen (Grenze {MAX_ZEILEN})"
else:
    gross_ok = "keine Swift-Dateien gefunden"
abschliessen("Naht: Dateilänge", funde, gross_ok)

# Lizenzen: jeder Pin aus einem Package.resolved braucht eine Zeile mit Lizenz in scripts/lizenzen.txt
funde, eintraege, namen = [], {}, []
if not os.path.isfile(LIZENZ):
    funde.append(f"{LIZENZ} fehlt")
else:
    for zeile_txt in open(LIZENZ, encoding="utf-8"):
        s = zeile_txt.strip()
        if s and not s.startswith("#"):
            spalten = [x.strip() for x in s.split("|")]
            eintraege[spalten[0].lower()] = spalten
for pfad in dateien(SWIFT_WURZELN, nur_swift=False):
    try:
        daten = json.load(open(pfad, encoding="utf-8"))
        gefunden = [p.get("identity") or p.get("package") or p.get("location", "?") for p in daten.get("pins", [])]
        gefunden += [p.get("package") or p.get("repositoryURL", "?").rstrip("/").rsplit("/", 1)[-1].removesuffix(".git")
                     for p in daten.get("object", {}).get("pins", [])]
    except (OSError, ValueError) as e:
        funde.append(f"{pfad} nicht lesbar ({e})")
        continue
    for name in gefunden:
        namen.append(name)
        spalten = eintraege.get(name.lower(), [])
        lizenz = spalten[1] if len(spalten) > 1 else ""
        if not lizenz or re.search(r"\?|TODO|unbekannt", lizenz, re.I):
            funde.append(f"{pfad} · {name} ohne geprüfte Lizenz in {LIZENZ}")
if namen:
    lizenz_ok = f"{len(namen)} Abhängigkeit(en) mit Lizenz in {LIZENZ}"
else:
    lizenz_ok = f"keine fremden Abhängigkeiten (kein Package.resolved mit Pins), {LIZENZ} vorhanden"
abschliessen("Lizenzen", funde, lizenz_ok)

# Ausgabe: Tabelle (Bash-Zeilen zuerst, dann diese)
bash_zeilen = []
with open(ERG, encoding="utf-8") as f:
    for z in f:
        z = z.rstrip("\n")
        if z:
            bash_zeilen.append(tuple(z.split("\t", 2)))
alle_zeilen = bash_zeilen + rows
kopf = ("Prüfung", "Ergebnis", "Fundstelle")
b1 = max(len(r[0]) for r in [kopf] + alle_zeilen)
b2 = max(len(r[1]) for r in [kopf] + alle_zeilen)
print(f"{kopf[0]:<{b1}}  {kopf[1]:<{b2}}  {kopf[2]}")
print("-" * (b1 + b2 + 4 + 60))
for r in alle_zeilen:
    print(f"{r[0]:<{b1}}  {r[1]:<{b2}}  {r[2]}")
fehler = sum(1 for r in alle_zeilen if r[1] == "FEHLER")
uebersprungen = sum(1 for r in alle_zeilen if r[1] == "ÜBERSPRUNGEN")
print()
print(f"Ergebnis: {fehler} Fehler, {uebersprungen} übersprungen.")
sys.exit(1 if fehler else 0)
PY
RC=$?
exit "$RC"
