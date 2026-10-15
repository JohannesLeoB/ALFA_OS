#!/usr/bin/env python3
"""Entwurf (Design-Sitzung, *.dc.html) -> Vertrag gestaltung/alfa-interface/alfa.tokens.json (DTCG: $type, $value).

Grundsatz (AGENTS.md "Entwurf ist Wahrheit", ausgang/werkzeuge/DESIGN-ZU-SWIFT-ANKER.md):
  * Der Erzeuger liest die Entwurfsdateien als Text (nie ausgefuehrt) und schreibt nur Werte, die dort stehen.
  * Neue Werte erfindet niemand. Wo der Entwurf zwei Werte fuer dasselbe hat, stehen beide im Vertrag
    (Variante -2, -3 ...) und die Stelle steht in $extensions.alfa.mehrdeutig. Es wird nicht gewaehlt.
  * Namen: CSS-Variable --x-y = Vertrag x.y (Hell ohne Vorsatz, Dunkel und Hellgrau mit Vorsatz dunkel./hellgrau.).
    Werte ohne CSS-Variable bekommen ihren Namen aus dem Entwurf selbst: data-teil (part.<teil>.<zustand>.<eigenschaft>),
    K/AREA (layout.*), Schluessel im Skript (logik.*, motion.*). Diese Namen sind mechanisch, nicht gestaltet.
  * Ausgabe ist deterministisch: gleiche Dateien, gleiche Bytes (kein Datum, kein Pfad).

Aufruf:
  python3 scripts/vertrag_aus_entwurf.py <Ordner mit den .dc.html> [--out PFAD] [--check] [--bericht]
"""
import argparse
import bisect
import hashlib
import json
import re
import sys
from collections import OrderedDict, defaultdict
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
STANDARD_OUT = REPO / "gestaltung" / "alfa-interface" / "alfa.tokens.json"

# Reihenfolge ist Teil des Ergebnisses (Variante 1 = erster Fund).
DATEIEN = [
    ("mail", "ALFA Mail.dc.html"),
    ("inhalt", "ALFA Einstellungen Inhalt.dc.html"),
    ("dienste", "ALFA Dienste.dc.html"),
    ("einst", "ALFA Einstellungen.dc.html"),
]
KUERZEL = {"mail": "Mail", "inhalt": "Inhalt", "dienste": "Dienste", "einst": "Einstellungen"}
RUNTIME = "support.js"  # Laufzeit, enthaelt keine App-Werte (Editor-Oberflaeche); nur gehasht.

# ------------------------------------------------------------------ Johannes' Worte (Anker)
WORTE = {
    "ruhe": "Ruhe reiten 280 - 56er Raster, 4er Leiter 1 und 2 als Minima .",
    "blob": "Blob 40 mit Radius 20",
    "radius": "Radien konzentrisch: innen = aussen - Einzug",
    "falt": "Faltschwelle 112",
}
RASTER = 56


class Fehler(Exception):
    pass


# ------------------------------------------------------------------ Textwerkzeuge
def zeilen_index(text):
    return [m.start() for m in re.finditer(r"\n", text)]


def zeile_von(idx, pos):
    return bisect.bisect_right(idx, pos - 1) + 1 if pos > 0 else 1


def split_top(s, trenner_ws=True, trenner_komma=False):
    """Teilt s auf oberster Ebene (ausserhalb von (), {{ }}, Anfuehrungszeichen) an Leerraum und/oder Komma."""
    out, cur, depth, quote, i = [], [], 0, None, 0
    while i < len(s):
        c = s[i]
        if quote:
            cur.append(c)
            if c == quote:
                quote = None
        elif c in "\"'":
            quote = c
            cur.append(c)
        elif s.startswith("{{", i):
            j = s.find("}}", i)
            j = len(s) if j < 0 else j + 2
            cur.append(s[i:j])
            i = j
            continue
        elif c == "(":
            depth += 1
            cur.append(c)
        elif c == ")":
            depth -= 1
            cur.append(c)
        elif depth == 0 and ((trenner_ws and c.isspace()) or (trenner_komma and c == ",")):
            if cur:
                out.append("".join(cur))
                cur = []
        else:
            cur.append(c)
        i += 1
    if cur:
        out.append("".join(cur))
    return out


def zahl_fmt(x):
    s = f"{float(x):.6f}".rstrip("0").rstrip(".")
    return "0" if s in ("", "-0") else s


def slug(s):
    s = re.sub(r"[^A-Za-z0-9]+", "-", s).strip("-")
    return s or "leer"


# ------------------------------------------------------------------ Wertelesen
HEX = re.compile(r"^#([0-9a-fA-F]{3,4}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$")
RGBA = re.compile(r"^rgba?\(\s*([\d.]+)\s*,\s*([\d.]+)\s*,\s*([\d.]+)\s*(?:,\s*([\d.]+)\s*)?\)$")
PX = re.compile(r"^(-?\d*\.?\d+)px$")
MS = re.compile(r"^(-?\d*\.?\d+)(ms|s)$")
NUM = re.compile(r"^-?\d*\.?\d+$")
VAR = re.compile(r"^var\(\s*(--[\w-]+)\s*\)$")
BEZ = re.compile(r"^cubic-bezier\(\s*([-\d.]+)\s*,\s*([-\d.]+)\s*,\s*([-\d.]+)\s*,\s*([-\d.]+)\s*\)$")
FARBNAMEN = {"white": "#ffffff", "black": "#000000"}


def farbe_wert(tok):
    """-> ('wert', dtcg) | ('var', name) | ('bound'|'skip', None) | ('nein', None)"""
    t = tok.strip()
    if "{{" in t:
        return "bound", None
    m = VAR.match(t)
    if m:
        return "var", m.group(1)
    if HEX.match(t):
        return "wert", t.lower()
    m = RGBA.match(t)
    if m:
        r, g, b = (float(m.group(i)) / 255 for i in (1, 2, 3))
        a = float(m.group(4)) if m.group(4) is not None else 1.0
        return "wert", {"colorSpace": "srgb", "components": [float(zahl_fmt(r)), float(zahl_fmt(g)), float(zahl_fmt(b))],
                        "alpha": float(zahl_fmt(a))}
    if t.lower() in FARBNAMEN:
        return "wert", FARBNAMEN[t.lower()]
    if t.lower() in ("transparent", "inherit", "currentcolor", "none", "initial", "unset"):
        return "skip", None
    return "nein", None


def px_wert(tok):
    t = tok.strip()
    m = PX.match(t)
    if m:
        return f"{zahl_fmt(m.group(1))}px"
    if t in ("0", "-0", "0.0"):
        return "0px"
    return None


def dauer_wert(tok):
    m = MS.match(tok.strip())
    if m:
        return f"{zahl_fmt(m.group(1))}{m.group(2)}"
    return None


def bez_wert(tok):
    m = BEZ.match(tok.strip())
    if m:
        return [float(zahl_fmt(m.group(i))) for i in (1, 2, 3, 4)]
    return None


# ------------------------------------------------------------------ Vertragsbaum
class Baum:
    def __init__(self):
        self.tokens = OrderedDict()      # pfad(tuple) -> dict(type, value, quellen[])
        self.varianten = defaultdict(list)  # basis(tuple) -> [(normwert, pfad)]
        self.mehrdeutig = []             # Eintraege fuer $extensions
        self.abgedeckt = defaultdict(list)  # datei -> [(start, ende)]
        self.log = []                    # jeder setze()-Aufruf (typ, wert), auch Wiederholungen

    def setze(self, basis, typ, wert, quelle, beschreibung=None, variante=True):
        norm = json.dumps([typ, wert], sort_keys=True)
        self.log.append((typ, wert))
        liste = self.varianten[basis]
        for n, p in liste:
            if n == norm:
                self.tokens[p]["quellen"].append(quelle)
                return p
        if not variante and liste:
            raise Fehler(f"Doppelter Name {basis} mit anderem Wert")
        pfad = basis if not liste else basis[:-1] + (f"{basis[-1]}-v{len(liste) + 1}",)
        if pfad in self.tokens:
            raise Fehler(f"Namenskollision {pfad}")
        liste.append((norm, pfad))
        self.tokens[pfad] = {"type": typ, "value": wert, "quellen": [quelle], "beschreibung": beschreibung}
        return pfad

    def als_dtcg(self):
        wurzel = OrderedDict()
        for pfad, t in self.tokens.items():
            knoten = wurzel
            for teil in pfad[:-1]:
                nxt = knoten.setdefault(teil, OrderedDict())
                if "$value" in nxt:
                    raise Fehler(f"Blatt und Gruppe zugleich: {'.'.join(pfad)}")
                knoten = nxt
            if pfad[-1] in knoten:
                raise Fehler(f"Blatt und Gruppe zugleich: {'.'.join(pfad)}")
            q = t["quellen"]
            ort = ", ".join(q[:3]) + (f" (+{len(q) - 3})" if len(q) > 3 else "")
            d = (t["beschreibung"] + " | " if t["beschreibung"] else "") + ort
            knoten[pfad[-1]] = OrderedDict([("$type", t["type"]), ("$value", t["value"]), ("$description", d)])
        return wurzel


# ------------------------------------------------------------------ CSS lesen
def css_deklarationen(text):
    """'a:b;c:d' -> [(prop, wert)] (Wert unveraendert, ohne !important)."""
    out = []
    for teil in split_decl(text):
        if ":" not in teil:
            continue
        p, v = teil.split(":", 1)
        p, v = p.strip(), re.sub(r"\s*!important\s*$", "", v.strip())
        if p and v:
            out.append((p, v))
    return out


def split_decl(text):
    out, cur, depth, quote, i = [], [], 0, None, 0
    while i < len(text):
        c = text[i]
        if quote:
            cur.append(c)
            if c == quote:
                quote = None
        elif c in "\"'":
            quote = c
            cur.append(c)
        elif text.startswith("{{", i):
            j = text.find("}}", i)
            j = len(text) if j < 0 else j + 2
            cur.append(text[i:j])
            i = j
            continue
        elif c == "(":
            depth += 1
            cur.append(c)
        elif c == ")":
            depth -= 1
            cur.append(c)
        elif c == ";" and depth == 0:
            out.append("".join(cur))
            cur = []
        else:
            cur.append(c)
        i += 1
    if cur:
        out.append("".join(cur))
    return out


def css_regeln(text, vor="", basis=0):
    """Zerlegt <style>-Text in [(selektor, koerper, offset_des_koerpers)] (at-Regeln werden in den Selektor gefaltet)."""
    text = re.sub(r"/\*.*?\*/", lambda m: re.sub(r"[^\n]", " ", m.group(0)), text, flags=re.S)
    out, i = [], 0
    while i < len(text):
        j = text.find("{", i)
        if j < 0:
            break
        sel = text[i:j].strip()
        depth, k = 1, j + 1
        while k < len(text) and depth:
            depth += {"{": 1, "}": -1}.get(text[k], 0)
            k += 1
        koerper = text[j + 1:k - 1]
        if sel.startswith("@"):
            out += css_regeln(koerper, vor + sel + " ", basis + j + 1)
        else:
            out.append((vor + sel, koerper, basis + j + 1))
        i = k
    return out


MODUS = {
    '[data-licht="hell"]': "hell",
    '[data-licht="hell"][data-grund="hellgrau"]': "hellgrau",
    '[data-licht="dunkel"]': "dunkel",
}


# ------------------------------------------------------------------ Hauptarbeit
class Erzeuger:
    def __init__(self, ordner):
        self.ordner = Path(ordner)
        self.baum = Baum()
        self.texte = {}
        self.idx = {}
        self.hashes = OrderedDict()
        self.vars = OrderedDict()           # (modus, name) -> (wert-roh, quelle)
        self.nicht_erfasst = defaultdict(list)   # grund -> [(quelle, text)]
        self.lit_gesamt = defaultdict(int)
        self.lit_erfasst = defaultdict(int)
        self.ketten = []                    # fuer Radius-Pruefung
        self.abweichungen = []
        self.worte = []
        self.fehlt = []
        self.knoten = []                    # alle Elemente (fuer Radius-Pruefung)
        self.k = {}
        self.area = {}

    # ---- Einlesen
    def lese(self):
        for key, name in DATEIEN:
            p = self.ordner / name
            if not p.exists():
                raise Fehler(f"Entwurfsdatei fehlt: {p}")
            roh = p.read_bytes()
            self.hashes[name] = hashlib.sha256(roh).hexdigest()
            self.texte[key] = roh.decode("utf-8")
            self.idx[key] = zeilen_index(self.texte[key])
        p = self.ordner / RUNTIME
        if p.exists():
            self.hashes[RUNTIME] = hashlib.sha256(p.read_bytes()).hexdigest()

    def q(self, key, pos):
        return f"{KUERZEL[key]}:{zeile_von(self.idx[key], pos)}"

    def decke(self, key, start, ende):
        self.baum.abgedeckt[key].append((start, ende))

    # ---- Variablennamen: --x-y -> x.y, Blatt/Gruppe-Konflikte falten den Rest zu einem Segment
    def var_pfad(self, name):
        teile = name[2:].split("-")
        for i in range(len(teile) - 1):
            if "--" + "-".join(teile[:i + 1]) in self.alle_var_namen:
                return tuple(teile[:i]) + ("-".join(teile[i:]),)
        return tuple(teile)

    # ---- Stufe 1: <style>-Bloecke, CSS-Variablen
    def stufe_styleblock(self):
        self.blocks = {}
        for key, _ in DATEIEN:
            t = self.texte[key]
            for m in re.finditer(r"<style[^>]*>(.*?)</style>", t, re.S | re.I):
                for sel, koerper, off in css_regeln(m.group(1), "", m.start(1)):
                    self.blocks.setdefault(key, []).append((sel.strip(), koerper, off))
        namen = set()
        for key, liste in self.blocks.items():
            for sel, koerper, off in liste:
                if sel in MODUS:
                    for p, v in css_deklarationen(koerper):
                        if p.startswith("--"):
                            namen.add(p)
        self.alle_var_namen = namen

    def stufe_variablen(self):
        b = self.baum
        for key, liste in self.blocks.items():
            for sel, koerper, off in liste:
                modus = MODUS.get(sel.strip())
                if modus is None:
                    continue
                for p, v in css_deklarationen(koerper):
                    if not p.startswith("--"):
                        continue
                    pos = off + koerper.find(p)
                    quelle = self.q(key, pos)
                    self.decke(key, pos, pos + len(p) + len(v) + 1)
                    kennung = (modus, p)
                    if kennung in self.vars and self.vars[kennung][0] != v:
                        self.abweichungen.append(("CSS-Variable in zwei Dateien verschieden", f"{p} [{modus}]",
                                                  f"{self.vars[kennung][1]}: {self.vars[kennung][0]} / {quelle}: {v}"))
                        self.mehrdeutig_var.append((p, modus, self.vars[kennung][0], v))
                        continue
                    self.vars.setdefault(kennung, (v, quelle))
                    self.var_token(modus, p, v, quelle)

    def praefix(self, modus):
        return () if modus == "hell" else (modus,)

    def var_token(self, modus, name, wert, quelle):
        b = self.baum
        pfad = self.praefix(modus) + self.var_pfad(name)
        if name.startswith("--sh-"):
            self.schatten(pfad, wert, quelle, modus)
            return
        art, w = farbe_wert(wert)
        if art == "wert":
            b.setze(pfad, "color", w, quelle, f"CSS-Variable {name}", variante=False)
        else:
            self.nicht_erfasst["Variable weder Farbe noch Schatten"].append((quelle, f"{name}: {wert}"))

    # ---- Schatten
    def schatten_schichten(self, wert):
        out = []
        for lage in split_top(wert, trenner_ws=False, trenner_komma=True):
            toks = split_top(lage)
            inset = False
            zahlen, farbe = [], None
            for t in toks:
                if t == "inset":
                    inset = True
                    continue
                px = px_wert(t)
                if px is not None and farbe is None:
                    zahlen.append(px)
                    continue
                a, w = farbe_wert(t)
                if a in ("wert", "var", "bound"):
                    farbe = (a, w)
                else:
                    return None
            if len(zahlen) not in (2, 3, 4):
                return None
            zahlen += ["0px"] * (4 - len(zahlen))
            out.append({"inset": inset, "x": zahlen[0], "y": zahlen[1], "blur": zahlen[2], "spread": zahlen[3], "farbe": farbe})
        return out

    def alias_pfad(self, modus, name):
        # var(--x) im Modus: dunkel/hellgrau zeigen auf den eigenen Vorsatz, wenn der Modus die Variable selbst setzt
        eigen = (modus, name) in self.vars
        basis = self.var_pfad(name) if name in self.alle_var_namen else None
        if basis is None:
            return None
        pre = self.praefix(modus) if eigen else ()
        return "{" + ".".join(pre + basis) + "}"

    def schatten(self, pfad, wert, quelle, modus, nur_wert=False):
        """Schreibt einen box-shadow. Darstellbar als DTCG-shadow nur ohne Spread, ohne inset, mit Farbliteral;
        sonst in Bestandteile zerlegt (dimension/color), nichts geht verloren."""
        b = self.baum
        s = wert.strip()
        if s == "none":
            return True
        if "{{" in s and not re.search(r"\d", re.sub(r"\{\{.*?\}\}", "", s)):
            return True  # rein gebunden
        schichten = self.schatten_schichten(s)
        if schichten is None:
            self.nicht_erfasst["Schatten nicht lesbar"].append((quelle, wert))
            return False
        einfach = all((not l["inset"]) and l["spread"] == "0px" and l["farbe"] and l["farbe"][0] == "wert" for l in schichten)
        if einfach:
            werte = [OrderedDict([("color", l["farbe"][1]), ("offsetX", l["x"]), ("offsetY", l["y"]),
                                  ("blur", l["blur"]), ("spread", l["spread"])]) for l in schichten]
            b.setze(pfad, "shadow", werte if len(werte) > 1 else werte[0], quelle)
            return True
        for i, l in enumerate(schichten, 1):
            g = pfad + (str(i),)
            hinweis = "inset (Innenschatten)" if l["inset"] else None
            for nm in ("x", "y", "blur", "spread"):
                b.setze(g + (nm,), "dimension", l[nm], quelle, hinweis)
            if l["farbe"] and l["farbe"][0] == "wert":
                b.setze(g + ("color",), "color", l["farbe"][1], quelle, hinweis)
            elif l["farbe"] and l["farbe"][0] == "var":
                al = self.alias_pfad(modus, l["farbe"][1])
                if al:
                    b.setze(g + ("color",), "color", al, quelle, hinweis)
                else:
                    self.nicht_erfasst["Schattenfarbe: Variable ohne Definition"].append((quelle, wert))
        self.zerlegt.append((".".join(pfad), quelle, wert))
        return True

    # ---- Stufe 2: Elemente der Vorlage
    TAG = re.compile(r"<(/?)([A-Za-z][\w:-]*)((?:\s+[^\s>=/]+(?:\s*=\s*(?:\"[^\"]*\"|'[^']*'|[^\s>\"']+))?)*)\s*(/?)>", re.S)
    ATTR = re.compile(r"([^\s=/>]+)(?:\s*=\s*(?:\"([^\"]*)\"|'([^']*)'|([^\s>\"']+)))?", re.S)
    VOID = {"meta", "link", "input", "img", "br", "hr", "source", "col", "wbr", "base"}

    def maskiert(self, key):
        t = self.texte[key]
        for rx in (r"<script[^>]*>.*?</script>", r"<style[^>]*>.*?</style>", r"<!--.*?-->"):
            t = re.sub(rx, lambda m: re.sub(r"[^\n]", " ", m.group(0)), t, flags=re.S | re.I)
        return t

    def stufe_vorlage(self):
        for key, _ in DATEIEN:
            t = self.maskiert(key)
            stack = []   # (tag, teil, knoten)
            for m in self.TAG.finditer(t):
                schluss, tag, attrtext, selbst = m.group(1), m.group(2).lower(), m.group(3), m.group(4)
                if schluss:
                    for i in range(len(stack) - 1, -1, -1):
                        if stack[i][0] == tag:
                            del stack[i:]
                            break
                    continue
                attrs = OrderedDict()
                for am in self.ATTR.finditer(attrtext):
                    val = am.group(2) if am.group(2) is not None else am.group(3) if am.group(3) is not None else am.group(4)
                    attrs[am.group(1)] = val
                teil = attrs.get("data-teil")
                if teil is not None and "{{" in teil:
                    teil = None
                vorfahr = next((s[1] for s in reversed(stack) if s[1]), None)
                if teil:
                    eigner = ("part", teil)
                elif vorfahr:
                    eigner = ("part", vorfahr, tag)
                else:
                    eigner = ("free", KUERZEL[key].lower(), tag)
                knoten = {"tag": tag, "teil": teil, "eigner": eigner, "radius": None, "pad": None, "pos": m.start(),
                          "key": key, "eltern": stack[-1][2] if stack else None, "absolut": False}
                self.knoten.append(knoten)
                for an, av in attrs.items():
                    if av is None:
                        continue
                    if an == "style" or an.startswith("style-"):
                        zustand = "base" if an == "style" else an[6:]
                        off = m.start() + m.group(0).find(av, m.group(0).find(an))
                        self.element_stil(key, eigner, zustand, av, off, knoten)
                    elif tag == "svg" and an in ("width", "height", "stroke-width"):
                        px = av.strip()
                        if "{{" not in px and NUM.match(px):
                            self.baum.setze(eigner + ("base", "svg-" + an), "dimension" if an != "stroke-width" else "number",
                                            f"{zahl_fmt(px)}px" if an != "stroke-width" else float(px), self.q(key, m.start()),
                                            "SVG-Attribut (Einheit px, Linienstaerke ohne Einheit)" if an == "stroke-width" else "SVG-Attribut, px")
                if not selbst and tag not in self.VOID:
                    stack.append((tag, teil or (stack[-1][1] if stack else None), knoten))

    # ---- einzelne Deklaration
    def element_stil(self, key, eigner, zustand, text, off, knoten):
        for prop, wert in css_deklarationen(text):
            pos = off + text.find(prop)
            quelle = self.q(key, pos)
            self.deklaration(key, eigner + (zustand,), prop, wert, quelle, pos, pos + len(prop) + 1 + len(wert), knoten if zustand == "base" else None)

    SEITEN = {
        "padding": ["padding-top", "padding-right", "padding-bottom", "padding-left"],
        "margin": ["margin-top", "margin-right", "margin-bottom", "margin-left"],
        "inset": ["top", "right", "bottom", "left"],
        "border-radius": ["border-top-left-radius", "border-top-right-radius", "border-bottom-right-radius", "border-bottom-left-radius"],
    }
    LAENGEN = {"width", "height", "min-width", "min-height", "max-width", "max-height", "top", "right", "bottom", "left", "gap", "row-gap",
               "column-gap", "padding", "padding-top", "padding-right", "padding-bottom", "padding-left", "margin", "margin-top",
               "margin-right", "margin-bottom", "margin-left", "inset", "border-radius", "outline-offset", "font-size", "letter-spacing",
               "text-indent", "stroke-width"}
    FARBEN = {"color", "background", "background-color", "border-color", "fill", "stroke", "outline-color", "text-decoration-color"}
    ZAHLEN = {"opacity", "z-index", "line-height", "font-weight"}

    LITERAL = re.compile(r"#[0-9a-fA-F]{3,8}\b|rgba?\([^)]*\)|cubic-bezier\([^)]*\)|(?<![\w.#-])-?\d*\.?\d+(?:px|ms|s|em|rem|vh|vw|pt|deg|%)(?![\w%])")

    @staticmethod
    def kanon_literal(tok):
        t = tok.strip()
        if t.startswith("#"):
            h = t[1:].lower()
            h = "".join(c * 2 for c in h) if len(h) in (3, 4) else h
            return "#" + h
        m = RGBA.match(t)
        if m:
            a = m.group(4) if m.group(4) is not None else "1"
            return f"rgba({zahl_fmt(m.group(1))},{zahl_fmt(m.group(2))},{zahl_fmt(m.group(3))},{zahl_fmt(a)})"
        m = BEZ.match(t)
        if m:
            return "bez:" + ",".join(zahl_fmt(m.group(i)) for i in (1, 2, 3, 4))
        m = re.match(r"^(-?\d*\.?\d+)(px|ms|s|em|rem|vh|vw|pt|deg|%)$", t)
        if m:
            return zahl_fmt(m.group(1)) + m.group(2)
        return t

    @staticmethod
    def kanon_wert(typ, w, aus):
        if typ == "color":
            if isinstance(w, dict):
                r, g, b = (round(c * 255) for c in w["components"])
                return [f"rgba({r},{g},{b},{zahl_fmt(w.get('alpha', 1))})"]
            return [w] if isinstance(w, str) and w.startswith("#") else []
        if typ in ("dimension", "duration"):
            return [w]
        if typ == "cubicBezier":
            return ["bez:" + ",".join(zahl_fmt(x) for x in w)]
        if typ == "number":
            n = zahl_fmt(w)
            return [n + "em", n + "%", n + "deg", n + "px"]
        if typ == "shadow":
            teile = []
            for l in (w if isinstance(w, list) else [w]):
                teile += Erzeuger.kanon_wert("color", l["color"], aus)
                teile += [l["offsetX"], l["offsetY"], l["blur"], l["spread"]]
            return teile
        return []

    def literal_pruefen(self, key, text, quelle, klartext, neu, g0):
        """Wert gegen Wert: jedes Literal der Deklaration muss unter den erzeugten Werten sein (oder bewusst unter nicht erfasst stehen)."""
        lit = [self.kanon_literal(m.group(0)) for m in self.LITERAL.finditer(text)]
        if not lit:
            return
        self.lit_gesamt[key] += len(lit)
        if sum(len(v) for v in self.nicht_erfasst.values()) > g0:
            return  # bewusst gemeldet
        erzeugt = set()
        for typ, w in neu:
            erzeugt.update(self.kanon_wert(typ, w, None))
        fehlt = [l for l in lit if l not in erzeugt]
        self.lit_erfasst[key] += len(lit) - len(fehlt)
        for l in fehlt:
            self.nicht("Literal ohne Vertragswert (Erzeuger)", quelle, f"{l} in {klartext[:100]}")

    def erfasst(self, *a):
        pass

    def nicht(self, grund, quelle, text):
        self.nicht_erfasst[grund].append((quelle, text))

    def deklaration(self, key, basis, prop, wert, quelle, pos, ende, knoten):
        n0, g0 = len(self.baum.log), sum(len(v) for v in self.nicht_erfasst.values())
        self.decke(key, pos, ende)
        if prop == "position" and wert.strip() == "absolute" and knoten is not None:
            knoten["absolut"] = True
        self._deklaration(key, basis, prop, wert, quelle, pos, ende, knoten)
        self.literal_pruefen(key, wert, quelle, f"{prop}:{wert}", self.baum.log[n0:], g0)

    def _deklaration(self, key, basis, prop, wert, quelle, pos, ende, knoten):
        b = self.baum
        v = wert.strip()
        if v.startswith("var(") and prop.startswith("--"):
            return
        # --- Schatten
        if prop == "box-shadow":
            self.schatten(basis + ("box-shadow",), v, quelle, "hell")
            self.erfasst(key, pos, ende, len(re.findall(r"(?<![\w.#-])-?\d*\.?\d+px|rgba?\(|#[0-9a-fA-F]{3,8}\b", v)))
            return
        # --- Uebergang
        if prop in ("transition", "transition-duration"):
            self.uebergang(key, basis, prop, v, quelle)
            return
        # --- Schrift
        if prop == "font":
            self.font_kurz(key, basis, v, quelle)
            return
        if prop == "font-family":
            if "{{" in v:
                return
            fam = [f.strip().strip("'\"") for f in split_top(v, trenner_ws=False, trenner_komma=True)]
            if fam:
                b.setze(basis + ("font-family",), "fontFamily", fam, quelle)
            return
        if prop == "font-weight":
            if NUM.match(v):
                b.setze(basis + ("font-weight",), "fontWeight", int(float(v)), quelle)
                self.erfasst(key, pos, ende, 0)
            return
        if prop == "line-height":
            self.linie_hoehe(key, basis, v, quelle, pos, ende)
            return
        if prop == "letter-spacing":
            m = re.match(r"^(-?\d*\.?\d+)em$", v)
            if m:
                b.setze(basis + ("letter-spacing-em",), "number", float(zahl_fmt(m.group(1))), quelle, "em, ohne Umrechnung")
                self.erfasst(key, pos, ende)
                return
        # --- Rand und Kontur
        if prop in ("border", "border-top", "border-bottom", "border-left", "border-right", "outline"):
            self.rand(key, basis, prop, v, quelle, pos, ende)
            return
        # --- Farben
        if prop in self.FARBEN:
            self.farbe_prop(key, basis, prop, v, quelle, pos, ende)
            return
        # --- Zahlen
        if prop in self.ZAHLEN and NUM.match(v):
            b.setze(basis + (prop,), "number", float(zahl_fmt(v)), quelle)
            return
        # --- Laengen
        if prop in self.LAENGEN:
            self.laengen(key, basis, prop, v, quelle, pos, ende, knoten)
            return
        if prop == "transform":
            self.transform(key, basis, v, quelle, pos, ende)
            return
        if prop in ("filter", "backdrop-filter", "-webkit-backdrop-filter"):
            for f, a in re.findall(r"([\w-]+)\(([^)]*)\)", v):
                px = px_wert(a)
                if px is not None:
                    b.setze(basis + (f"{prop}-{f}",), "dimension", px, quelle)
                    self.erfasst(key, pos, ende)
                elif NUM.match(a.strip()):
                    b.setze(basis + (f"{prop}-{f}",), "number", float(zahl_fmt(a)), quelle)
            return
        # --- sonst: Literale melden, nicht raten
        if re.search(r"#[0-9a-fA-F]{3,8}\b|rgba?\(|gradient\(|cubic-bezier\(|-?\d*\.?\d+(?:px|ms|s|em|rem|vh|vw|%)(?![\w])", v) and "{{" not in v:
            self.nicht(f"{prop}: nicht als Vertragswert darstellbar (Typ)", quelle, f"{prop}:{v}")

    def linie_hoehe(self, key, basis, v, quelle, pos, ende):
        if NUM.match(v):
            self.baum.setze(basis + ("line-height",), "number", float(zahl_fmt(v)), quelle, "Faktor wie CSS line-height")
        else:
            px = px_wert(v)
            if px:
                self.baum.setze(basis + ("line-height-px",), "dimension", px, quelle)
                self.erfasst(key, pos, ende)

    def font_kurz(self, key, basis, v, quelle):
        if "{{" in v or v in ("inherit", "initial"):
            return
        m = re.match(r"^(?:(italic|oblique)\s+)?(\d{3})\s+(-?\d*\.?\d+)px(?:\s*/\s*(\d*\.?\d+(?:px)?))?\s+(.+)$", v)
        if not m:
            self.nicht("font-Kurzform nicht lesbar", quelle, v)
            return
        b = self.baum
        b.setze(basis + ("font-weight",), "fontWeight", int(m.group(2)), quelle)
        b.setze(basis + ("font-size",), "dimension", f"{zahl_fmt(m.group(3))}px", quelle)
        if m.group(4):
            if m.group(4).endswith("px"):
                b.setze(basis + ("line-height-px",), "dimension", f"{zahl_fmt(m.group(4)[:-2])}px", quelle)
            else:
                b.setze(basis + ("line-height",), "number", float(zahl_fmt(m.group(4))), quelle, "Faktor wie CSS line-height")
        fam = [f.strip().strip("'\"") for f in split_top(m.group(5), trenner_ws=False, trenner_komma=True)]
        b.setze(basis + ("font-family",), "fontFamily", fam, quelle)
        self.zaehler_gut(key, 1)

    def zaehler_gut(self, key, n):
        pass

    def rand(self, key, basis, prop, v, quelle, pos, ende):
        b = self.baum
        if v in ("0", "none") or "{{" in v and not re.search(r"\d", re.sub(r"\{\{.*?\}\}", "", v)):
            return
        for t in split_top(v):
            px = px_wert(t)
            if px is not None and t not in ("0",):
                b.setze(basis + (f"{prop}-width",), "dimension", px, quelle)
                self.erfasst(key, pos, ende)
                continue
            a, w = farbe_wert(t)
            if a == "wert":
                b.setze(basis + (f"{prop}-color",), "color", w, quelle)
                self.erfasst(key, pos, ende)
            elif a == "var":
                al = self.alias_pfad("hell", w)
                if al:
                    b.setze(basis + (f"{prop}-color",), "color", al, quelle)
                    self.erfasst(key, pos, ende)
            # solid, dashed, bound: kein Wert

    def farbe_prop(self, key, basis, prop, v, quelle, pos, ende):
        if "gradient(" in v or "url(" in v:
            self.nicht("Verlauf/Bild (kein DTCG-Typ im Generator)", quelle, f"{prop}:{v}")
            return
        a, w = farbe_wert(v)
        if a == "wert":
            self.baum.setze(basis + (prop,), "color", w, quelle)
            self.erfasst(key, pos, ende)
        elif a == "var":
            al = self.alias_pfad("hell", w)
            if al:
                self.baum.setze(basis + (prop,), "color", al, quelle, "Verweis auf CSS-Variable")
        elif a == "nein":
            self.nicht(f"{prop}: Farbwert nicht lesbar", quelle, f"{prop}:{v}")

    def laengen(self, key, basis, prop, v, quelle, pos, ende, knoten):
        b = self.baum
        if "{{" in v:
            return
        toks = split_top(v)
        namen = None
        if prop in self.SEITEN and len(toks) > 1:
            n_ = len(toks)
            t4 = (toks * 4 if n_ == 1 else [toks[0], toks[1], toks[0], toks[1]] if n_ == 2
                  else [toks[0], toks[1], toks[2], toks[1]] if n_ == 3 else toks if n_ == 4 else None)
            if t4 is None:
                self.nicht(f"{prop}: Wertzahl", quelle, v)
                return
            toks, namen = t4, self.SEITEN[prop]
        elif prop == "gap" and len(toks) == 2:
            namen = ["row-gap", "column-gap"]
        else:
            namen = [prop]
        if prop == "border-radius" and len(toks) == 1 and namen == [prop]:
            m = re.match(r"^(-?\d*\.?\d+)%$", toks[0])
            if m:
                b.setze(basis + ("border-radius-percent",), "number", float(zahl_fmt(m.group(1))), quelle, "Prozent der Kantenlaenge (50 = Kreis)")
                self.erfasst(key, pos, ende)
                return
        for n, t in zip(namen, toks):
            px = px_wert(t)
            if px is not None:
                b.setze(basis + (n,), "dimension", px, quelle)
                self.erfasst(key, pos, ende)
                if knoten is not None:
                    self.merke(knoten, n, px)
            elif re.match(r"^[a-z-]+$", t):
                pass  # auto, none, ...
            else:
                self.nicht(f"{n}: Einheit/Ausdruck ohne px (Prozent, calc, vh, em ...)", quelle, f"{prop}:{v}")
                break

    def merke(self, knoten, name, px):
        w = float(px[:-2])
        if name == "border-radius":
            knoten["radius"] = w
        elif name.startswith("padding"):
            knoten.setdefault("padseiten", {})[name] = w
        elif name in ("position",):
            pass

    def transform(self, key, basis, v, quelle, pos, ende):
        b = self.baum
        for f, a in re.findall(r"([\w-]+)\(([^)]*)\)", v):
            a = a.strip()
            if "{{" in a:
                continue
            if f in ("scale", "scalex", "scaley") and NUM.match(a):
                b.setze(basis + (f"transform-{f.lower()}",), "number", float(zahl_fmt(a)), quelle)
                self.erfasst(key, pos, ende)
            elif f in ("translatex", "translatey", "translate", "perspective") and px_wert(a):
                b.setze(basis + (f"transform-{f.lower()}",), "dimension", px_wert(a), quelle)
                self.erfasst(key, pos, ende)
            elif f == "rotate" and re.match(r"^-?\d*\.?\d+deg$", a):
                b.setze(basis + ("transform-rotate-deg",), "number", float(zahl_fmt(a[:-3])), quelle, "Grad")
                self.erfasst(key, pos, ende)
            elif f.lower() in ("translatex", "translatey", "translate") and a.endswith("%"):
                self.nicht("transform: Prozentwert", quelle, f"{f}({a})")
            elif f.lower() not in ("none",):
                self.nicht(f"transform: {f}() nicht erfasst", quelle, f"{f}({a})")

    def uebergang(self, key, basis, prop, v, quelle):
        b = self.baum
        if "{{" in v or v in ("none", "inherit"):
            return
        for teil in split_top(v, trenner_ws=False, trenner_komma=True):
            toks = split_top(teil)
            eig = toks[0] if toks and not dauer_wert(toks[0]) else "all"
            dauern = [dauer_wert(t) for t in toks if dauer_wert(t)]
            kurve = next((bez_wert(t) for t in toks if bez_wert(t)), None)
            for t in toks:
                if re.match(r"^(ease|ease-in|ease-out|ease-in-out|linear)$", t):
                    self.nicht("Uebergang: Schluesselwort-Kurve statt cubic-bezier", quelle, teil)
            if dauern:
                b.setze(basis + ("transition", slug(eig), "duration"), "duration", dauern[0], quelle)
                if len(dauern) > 1:
                    b.setze(basis + ("transition", slug(eig), "delay"), "duration", dauern[1], quelle)
            if kurve:
                b.setze(basis + ("transition", slug(eig), "curve"), "cubicBezier", kurve, quelle)

    # ---- Stufe 3: <style>-Bloecke ausser Variablen
    def stufe_stylebloecke(self):
        for key, liste in self.blocks.items():
            for sel, koerper, off in liste:
                if sel.strip() in MODUS:
                    continue
                basis = ("base", key, slug(sel))
                for prop, wert in css_deklarationen(koerper):
                    pos = off + koerper.find(prop)
                    self.deklaration(key, basis, prop, wert, self.q(key, pos), pos, pos + len(prop) + len(wert) + 1, None)

    # ---- Stufe 4: Skript (K, AREA, Zeichenketten, Bewegung)
    def stufe_skript(self):
        for key, _ in DATEIEN:
            t = self.texte[key]
            m = re.search(r"<script[^>]*data-dc-script[^>]*>(.*?)</script>", t, re.S)
            if not m:
                continue
            js, off = m.group(1), m.start(1)
            self.skript(key, js, off)

    def js_objekt(self, js, name):
        m = re.search(r"(?<![\w.])" + name + r"\s*=\s*\{", js)
        if not m:
            return None, None
        i = m.end() - 1
        depth, k = 0, i
        while k < len(js):
            depth += {"{": 1, "}": -1}.get(js[k], 0)
            k += 1
            if depth == 0:
                break
        roh = js[i:k]
        j = re.sub(r"([{,]\s*)([A-Za-z_]\w*)\s*:", r'\1"\2":', roh)
        try:
            return json.loads(j), (m.start(), k)
        except json.JSONDecodeError:
            raise Fehler(f"{name}: Objektliteral nicht als JSON lesbar: {roh[:80]}")

    def skript(self, key, js, off):
        b = self.baum
        # K und AREA
        for name in ("K", "AREA"):
            obj, span = self.js_objekt(js, name)
            if obj is None:
                continue
            zeile = self.q(key, off + span[0])
            if name == "K":
                self.k[key] = obj
                for kk, vv in obj.items():
                    n = len(re.findall(r"\bK\.%s\b" % re.escape(kk), js))
                    b.setze(("layout", "k", kk), "dimension", f"{zahl_fmt(vv)}px", f"{zeile} K.{kk}",
                            f"Skript-Konstante K.{kk}, im Skript {n}x gelesen", variante=False)
                    self.decke(key, off + span[0], off + span[1])
            else:
                self.area[key] = obj
                for bereich, d in obj.items():
                    for kk, vv in d.items():
                        if kk == "yield":
                            for i, x in enumerate(vv):
                                b.setze(("layout", "area", bereich.lower(), "yield", str(i + 1)), "number", int(x), f"{zeile} AREA.{bereich}.yield[{i}]",
                                        "Nachgebe-Rang je Bahn (0 = links)", variante=False)
                        else:
                            for i, x in enumerate(vv):
                                b.setze(("layout", "area", bereich.lower(), kk.lower() + ("" if len(vv) == 1 else f"-{i + 1}")), "dimension",
                                        f"{zahl_fmt(x)}px", f"{zeile} AREA.{bereich}.{kk}[{i}]", None, variante=False)
                    self.decke(key, off + span[0], off + span[1])
        # Zeichenketten mit CSS-Werten
        konst = {}
        for m in re.finditer(r"\b(\w+)\s*=\s*\"(cubic-bezier\([^\"]*\))\"", js):
            konst[m.group(1)] = bez_wert(m.group(2))
        for m in re.finditer(r"\"((?:[^\"\\\n]|\\.)*)\"|'((?:[^'\\\n]|\\.)*)'", js):
            s = m.group(1) if m.group(1) is not None else m.group(2)
            if not re.search(r"cubic-bezier\(|#[0-9a-fA-F]{3,8}\b|rgba?\(|-?\d*\.?\d+(?:px|ms)\b", s):
                continue
            if re.match(r"^\s*M[\d.\- ]", s):
                continue
            if re.search(r"[A-Za-zÄÖÜäöüß]{4,} [A-Za-zÄÖÜäöüß]{3,} [A-Za-zÄÖÜäöüß]{3,}", s) and not re.search(r"cubic-bezier|rgba?\(|\d(px|ms)\b", s):
                continue
            start = off + m.start()
            ctx = js[max(0, m.start() - 220):m.start()]
            ids = re.findall(r"([A-Za-z_$][\w$]*)\s*(?::|=(?![=>]))", ctx)
            ident = ids[-1] if ids else "ohne-name"
            quelle = self.q(key, start)
            nach = js[m.end():m.end() + 24]
            kv = re.match(r"\s*\+\s*(\w+)", nach)
            n0, g0 = len(self.baum.log), sum(len(v) for v in self.nicht_erfasst.values())
            self.js_string(key, ident, s, quelle, start, off + m.end(), konst.get(kv.group(1)) if kv else None, kv.group(1) if kv else None)
            # Kurve aus Konstante (ease/fly) gehoert zur Zeichenkette davor, nicht zum Literal
            self.literal_pruefen(key, s, quelle, f"{ident}: {s}", self.baum.log[n0:], g0)
        # Dauern und Zeitgeber
        for m in re.finditer(r"duration:\s*(\d+)", js):
            start = off + m.start()
            ctx_ref = re.findall(r"(this\.\w+Ref|\w+)\.animate\(", js[max(0, m.start() - 600):m.start()])
            nm = f"anim-{slug(ctx_ref[-1]) if ctx_ref else 'l' + str(zeile_von(self.idx[key], start))}"
            self.baum.setze(("motion", KUERZEL[key].lower(), nm, "duration"), "duration", f"{int(m.group(1))}ms", self.q(key, start), "animate(..., duration)")
            self.decke(key, start, off + m.end())
        for m in re.finditer(r"setTimeout\(([^;\n]*?),\s*(?:undo \? )?(\d+)(?: : (\d+))?\)", js):
            start = off + m.start()
            ln = zeile_von(self.idx[key], start)
            for i, g in enumerate((m.group(2), m.group(3))):
                if g and int(g) > 0:
                    self.baum.setze(("motion", KUERZEL[key].lower(), f"timer-l{ln}" + ("" if i == 0 else "-alt"), "delay"), "duration",
                                    f"{int(g)}ms", self.q(key, start), "setTimeout")
            self.decke(key, start, off + m.end())
        # Farbleiter (LEVELS): Paare aus Hex
        # (werden durch js_string erfasst: ident 'hell'/'dunkel' liegt im Entwurf)

    def js_string(self, key, ident, s, quelle, start, ende, kurve_nach, kurve_name):
        b = self.baum
        basis = ("logik", ident)
        gefunden = 0
        # Uebergangsliste?
        uebergang = re.findall(r"(?:^|,\s*|\s)([a-z][\w-]*)\s+(\d+)ms(?:\s+(cubic-bezier\([^)]*\)))?(?:\s+(\d+)ms)?", s)
        if uebergang and re.search(r"\d+ms", s):
            for eig, d, c, dl in uebergang:
                if eig in ("ms",):
                    continue
                b.setze(basis + (slug(eig), "duration"), "duration", f"{d}ms", quelle)
                gefunden += 1
                kv = bez_wert(c) if c else None
                if kv is None and kurve_nach is not None and s.rstrip().endswith(f"{d}ms"):
                    kv = kurve_nach
                if kv:
                    b.setze(basis + (slug(eig), "curve"), "cubicBezier", kv, quelle,
                            f"Name im Entwurf: {kurve_name}" if (not c and kurve_name) else None)
                    gefunden += 1
                if dl:
                    b.setze(basis + (slug(eig), "delay"), "duration", f"{dl}ms", quelle)
                    gefunden += 1
            self.decke(key, start, ende)
            return
        i_px = i_ms = i_c = i_bez = 0
        for t in re.finditer(r"cubic-bezier\([^)]*\)|#[0-9a-fA-F]{3,8}\b|rgba?\([^)]*\)|(?<![\w.#-])-?\d*\.?\d+(?:px|ms)(?![\w])", s):
            tok = t.group(0)
            if tok.startswith("cubic"):
                i_bez += 1
                b.setze(basis + (f"curve-{i_bez}",) if i_bez > 1 else basis + ("curve",), "cubicBezier", bez_wert(tok), quelle)
            elif tok.startswith("#") or tok.startswith("rgb"):
                i_c += 1
                a, w = farbe_wert(tok)
                b.setze(basis + (f"color-{i_c}",) if i_c > 1 or len(re.findall(r"#|rgb", s)) > 1 else basis + ("color",), "color", w, quelle)
            elif tok.endswith("ms"):
                i_ms += 1
                b.setze(basis + (f"duration-{i_ms}",) if i_ms > 1 else basis + ("duration",), "duration", dauer_wert(tok), quelle)
            else:
                i_px += 1
                b.setze(basis + (f"px-{i_px}",) if i_px > 1 or len(re.findall(r"px", s)) > 1 else basis + ("px",), "dimension", px_wert(tok), quelle)
        # Rest der Zeichenkette (z. B. translateY(1.4px), Prozent, deg) meldet sich unter nicht erfasst
        rest = re.sub(r"cubic-bezier\([^)]*\)|#[0-9a-fA-F]{3,8}\b|rgba?\([^)]*\)|(?<![\w.#-])-?\d*\.?\d+(?:px|ms)(?![\w])", "", s)
        if re.search(r"\d", rest) and re.search(r"[a-z]+\(|%|deg|em\b", rest):
            self.nicht("Zeichenkette im Skript: Funktion/Prozent/Winkel nicht erfasst", quelle, s[:90])
        self.decke(key, start, ende)

    # ---- Pruefungen gegen Johannes' Wort
    def worte_pruefen(self):
        k = self.k.get("mail", {})
        ar = self.area.get("mail", {}).get("Mail", {})
        ar2 = self.area.get("mail", {}).get("Einstellungen", {})
        def eintrag(wort, soll, ist, ok, anmerkung=""):
            self.worte.append({"wort": wort, "soll": soll, "ist": ist, "ok": ok, "anmerkung": anmerkung})
        for name, a in (("Mail", ar), ("Einstellungen", ar2)):
            L, R = a.get("L", [None])[0], a.get("R", [None])[0]
            eintrag(WORTE["ruhe"], f"{name}: Ruhebreite links 280", f"AREA.{name}.L = {L}", L == 280)
            eintrag(WORTE["ruhe"], f"{name}: Ruhebreiten im {RASTER}er-Raster", f"L={L}, R={R}",
                    all(x is not None and x % RASTER == 0 for x in (L, R)))
            mn = a.get("min", [])
            eintrag(WORTE["ruhe"], f"{name}: Minima Bahn 1 und 2 im {RASTER}er-Raster (224 = 4x56, 280 = 5x56)", f"min = {mn}",
                    len(mn) >= 2 and all(x % RASTER == 0 for x in mn[:2]),
                    "Lesart von 'Leiter 1 und 2' nicht eindeutig; Bahn 3 (min " + str(mn[2] if len(mn) > 2 else '?') + ") steht nicht im Wort")
        eintrag(WORTE["blob"], "K.bh = 40", f"K.bh = {k.get('bh')}", k.get("bh") == 40)
        rad = [t for p, t in self.baum.tokens.items() if p[:2] == ("logik", "bRad")]
        eintrag(WORTE["blob"], "Blob-Radius 20px", "logik.bRad: " + ", ".join(str(t["value"]) for t in rad), any(t["value"] == "20px" for t in rad))
        eintrag(WORTE["falt"], "K.foldAt = 112", f"K.foldAt = {k.get('foldAt')}", k.get("foldAt") == 112)
        # Inline-Werte der Einstellungsbahnen gegen Wort
        t = self.texte["inhalt"]
        m = re.search(r"navW = shared \? bp\[0\] : small \? 56 : (\d+), detW = shared \? bp\[2\] : small \? (\d+) : (\d+)", t)
        if m:
            nav, dsmall, det = int(m.group(1)), int(m.group(2)), int(m.group(3))
            qz = self.q("inhalt", m.start())
            eintrag(WORTE["ruhe"], "Einstellungen Inhalt: Navigationsbahn in Ruhe 280", f"{qz}: navW = {nav}", nav == 280,
                    "Entwurf weicht ab, das Wort gilt: layout.area.einstellungen.l = 280px")
            eintrag(WORTE["ruhe"], "Einstellungen Inhalt: Detailbahn in Ruhe 560", f"{qz}: detW = {det} (klein {dsmall})", det == 560,
                    "Entwurf weicht ab, das Wort gilt: layout.area.einstellungen.r = 560px")
            if nav != 280 or det != 560:
                self.abweichungen.append(("Entwurf weicht vom Wort ab", f"{qz} navW {nav}, detW {det} (klein {dsmall})",
                                          "Wort: Ruhebreite 280 im 56er-Raster (AREA 280/560); im Vertrag steht nur AREA, die Inline-Zahlen sind nicht uebernommen"))

    def radien_pruefen(self):
        """innen = aussen - Einzug (Einzug = kleinste Innenabstaende der Kette vom Aussenelement bis zum Eltern des Innenelements)."""
        for kn in self.knoten:
            r = kn.get("radius")
            if not r or r >= 100 or kn["absolut"]:
                continue
            kette, e = [], kn["eltern"]
            ok, aussen = True, None
            while e is not None:
                if e.get("radius") and e["radius"] < 100 and e["radius"] > r:
                    aussen = e
                    kette.append(e)
                    break
                kette.append(e)
                e = e["eltern"]
            if aussen is None:
                continue
            einzug = 0.0
            for e in kette:
                seiten = e.get("padseiten", {})
                if not seiten:
                    continue
                w = [seiten.get(s) for s in ("padding", "padding-top", "padding-right", "padding-bottom", "padding-left")]
                gesetzt = [x for x in w if x is not None]
                einzug += min(gesetzt) if len(gesetzt) == 1 else min(x for x in gesetzt) if gesetzt else 0
            soll = aussen["radius"] - einzug
            # nur eindeutige Faelle: direkte Eltern-Kette mit bekannten Abstaenden und Differenz != 0
            if abs(soll - r) > 0.01:
                self.konz.append((self.q(kn["key"], kn["pos"]), kn["eigner"], aussen["radius"], einzug, r, soll))

    # ---- Zusammenbau
    def erzeuge(self):
        self.mehrdeutig_var = []
        self.zerlegt = []
        self.konz = []
        self.lese()
        self.stufe_styleblock()
        self.stufe_variablen()
        self.stufe_vorlage()
        self.stufe_stylebloecke()
        self.stufe_skript()
        self.worte_pruefen()
        self.radien_pruefen()
        self.weitere_mehrdeutig()
        return self.dokument()

    def weitere_mehrdeutig(self):
        t = self.texte["einst"]
        m = re.search(r'"dunkel" \? "(#[0-9a-fA-F]{3,8})" : "(#[0-9a-fA-F]{3,8})"', t)
        dunkel = self.vars.get(("dunkel", "--c-ground"))
        if m and dunkel and dunkel[0].lower() != m.group(1).lower():
            self.mehr_extra = [("dunkler Grund", f"{dunkel[1]} --c-ground dunkel {dunkel[0]}", f"{self.q('einst', m.start())} {m.group(1)}")]
            self.abweichungen.append(("zwei Werte fuer den dunklen Grund", f"--c-ground {dunkel[0]}", f"ALFA Einstellungen.dc.html {m.group(1)}"))
        else:
            self.mehr_extra = []
        k = self.k.get("mail", {})
        ar = self.area.get("mail", {}).get("Mail", {})
        if k.get("center") is not None and ar.get("min"):
            self.mehr_extra.append(("Mindestbreite Mitte", f"K.center = {k['center']}px (im Skript {len(re.findall(r'K\\.center', self.texte['mail']))}x gelesen)",
                                    f"AREA.Mail.min[1] = {ar['min'][1]}px"))
        n = len(re.findall(r"K\.menu\b", self.texte["mail"]))
        if k.get("menu") is not None:
            self.mehr_extra.append(("Menuebreite", f"K.menu = {k['menu']}px (im Skript {n}x gelesen)", "Menuebreiten stehen inline (240, 260, 300 ...)"))

    def dokument(self):
        b = self.baum
        wurzel = b.als_dtcg()
        # mehrdeutig (Varianten desselben Namens)
        varianten = []
        for basis, liste in b.varianten.items():
            if len(liste) > 1:
                teile = []
                for n, p in liste:
                    t = b.tokens[p]
                    teile.append({"name": ".".join(p), "wert": t["value"], "stellen": t["quellen"][:2]})
                varianten.append({"name": ".".join(basis), "werte": teile})
        ext = OrderedDict()
        ext["quelle"] = OrderedDict((n, h) for n, h in self.hashes.items())
        ext["werte"] = len(b.tokens)
        ext["worte"] = self.worte
        ext["mehrdeutig"] = OrderedDict([
            ("zwei_werte_fuer_dasselbe", [{"gegenstand": a, "wert_1": c, "wert_2": d} for a, c, d in self.mehr_extra]),
            ("variablen_in_zwei_dateien_verschieden", [{"name": n, "modus": m, "wert_1": a, "wert_2": c} for n, m, a, c in self.mehrdeutig_var]),
            ("teil_und_eigenschaft_mit_mehreren_werten", varianten),
        ])
        ext["abweichung_vom_wort"] = [{"art": a, "stelle": s, "anmerkung": c} for a, s, c in self.abweichungen]
        ext["radius_nicht_konzentrisch"] = [{"stelle": q, "teil": ".".join(e), "aussen": a, "einzug": z, "innen": i, "soll": s}
                                            for q, e, a, z, i, s in self.konz]
        ext["schatten_zerlegt"] = [{"name": n, "stelle": q, "css": c} for n, q, c in self.zerlegt]
        ext["nicht_erfasst"] = OrderedDict((g, [{"stelle": q, "text": t} for q, t in l]) for g, l in sorted(self.nicht_erfasst.items()))
        ext["literale"] = OrderedDict((KUERZEL[k], {"gesamt": self.lit_gesamt[k], "erfasst": self.lit_erfasst[k]}) for k, _ in DATEIEN)
        doc = OrderedDict()
        doc["$description"] = "Vertrag aus dem Entwurf (scripts/vertrag_aus_entwurf.py). Nicht von Hand aendern; Aenderungen im Entwurf, dann neu erzeugen."
        doc["$extensions"] = OrderedDict([("alfa", ext)])
        for k_, v_ in wurzel.items():
            doc[k_] = v_
        return doc


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("entwurf", help="Ordner mit ALFA Mail.dc.html, ALFA Einstellungen Inhalt.dc.html, ALFA Dienste.dc.html, ALFA Einstellungen.dc.html, support.js")
    ap.add_argument("--out", default=str(STANDARD_OUT))
    ap.add_argument("--check", action="store_true", help="erzeugen und mit der vorhandenen Datei vergleichen (Exit 1 = ROT)")
    ap.add_argument("--bericht", action="store_true", help="Zusammenfassung ausgeben")
    a = ap.parse_args()
    try:
        e = Erzeuger(a.entwurf)
        doc = e.erzeuge()
    except Fehler as f:
        print(f"FEHLER: {f}", file=sys.stderr)
        return 2
    text = json.dumps(doc, indent=2, ensure_ascii=False) + "\n"
    out = Path(a.out)
    if a.check:
        ok = out.exists() and out.read_text(encoding="utf-8") == text
        print("GRUEN: alfa.tokens.json entspricht dem Entwurf" if ok else "ROT: alfa.tokens.json weicht vom Entwurf ab, neu erzeugen")
        return 0 if ok else 1
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(text, encoding="utf-8")
    print(f"{len(e.baum.tokens)} Werte -> {out}")
    if a.bericht:
        zweige = defaultdict(int)
        for p in e.baum.tokens:
            zweige[p[0]] += 1
        for z, n in sorted(zweige.items()):
            print(f"  {z}: {n}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
