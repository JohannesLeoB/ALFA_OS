"""Prueft Schemata v0.2, Beispiele, Invarianten I1-I8 und Negativbeispiele.

Aufruf: python3 -I pruefe_schema.py schema
Exit 0 = alles wie erwartet; Exit 1 = Abweichung.
"""
import ast, json, math, re, sys, pathlib, datetime, operator
from jsonschema import Draft202012Validator, FormatChecker
from referencing import Registry, Resource

D = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else 'schema')
fc = FormatChecker()
MINDESTSATZ = ['korpus_d', 'korpus_t', 'rueckwand_d', 'rueckwand_einbau', 'rueckwand_einstand', 'front_d',
               'fuge_front', 'sockel_h', 'lochreihe_abstand_vk', 'lochreihe_teilung', 'verbinder']


@fc.checks('date-time', raises=ValueError)
def _datetime(s):
    if not isinstance(s, str):
        return True
    if not re.match(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}(:\d{2}(\.\d+)?)?(Z|[+-]\d{2}:\d{2})$', s):
        raise ValueError('kein RFC-3339-Zeitpunkt')
    datetime.datetime.fromisoformat(s.replace('Z', '+00:00'))
    return True


schemas = {}
for p in sorted(D.glob('*.schema.json')):
    s = json.loads(p.read_text())
    Draft202012Validator.check_schema(s)
    schemas[p.name.split('.')[0]] = s
reg = Registry()
for s in schemas.values():
    reg = reg.with_resource(s['$id'], Resource.from_contents(s))
print('Schemata gueltig:', ', '.join(sorted(schemas)))


def validator_fuer(name):
    art, _, rest = name.partition('.')
    if art == 'werkzeug':
        defname = rest.split('.')[0]
        if defname not in schemas['werkzeuge']['$defs']:
            return None
        s = {'$ref': schemas['werkzeuge']['$id'] + '#/$defs/' + defname}
    elif art in schemas and art not in ('gemeinsam', 'werkzeuge'):
        s = schemas[art]
    else:
        return None
    return Draft202012Validator(s, registry=reg, format_checker=fc)


def schemafehler(name, daten):
    v = validator_fuer(name)
    if v is None:
        return [f'unbekanntes Dateipraefix: {name}']
    return ['/'.join(map(str, e.absolute_path)) + ': ' + e.message[:140]
            for e in sorted(v.iter_errors(daten), key=lambda e: list(e.absolute_path))]


# ---------- Hilfen ----------

_OPS = {ast.Add: operator.add, ast.Sub: operator.sub, ast.Mult: operator.mul, ast.Div: operator.truediv}


def rechne(text):
    """Wertet einen reinen Zahlenausdruck aus (+ - * / Klammern), sonst None."""
    try:
        baum = ast.parse(text.strip(), mode='eval').body
    except SyntaxError:
        return None

    def ev(k):
        if isinstance(k, ast.Constant) and isinstance(k.value, (int, float)):
            return k.value
        if isinstance(k, ast.BinOp) and type(k.op) in _OPS:
            return _OPS[type(k.op)](ev(k.left), ev(k.right))
        if isinstance(k, ast.UnaryOp) and isinstance(k.op, ast.USub):
            return -ev(k.operand)
        raise ValueError
    try:
        return ev(baum)
    except (ValueError, ZeroDivisionError):
        return None


def setup_kette(setup, alle):
    """Konstruktionswerte entlang erbt_von; das naehere Setup gewinnt."""
    kette, s, gesehen = [], setup, set()
    while s and s['id'] not in gesehen:
        gesehen.add(s['id'])
        kette.append(s)
        s = alle.get(s.get('erbt_von'))
    werte = {}
    for s in reversed(kette):
        werte.update({k: v for k, v in s.get('konstruktion', {}).items() if isinstance(v, dict)})
    return werte


def drehe(p, grad):
    r = math.radians(grad)
    c, s = round(math.cos(r), 12), round(math.sin(r), 12)
    return (p[0] * c - p[1] * s, p[0] * s + p[1] * c, p[2])


def elemente_flach(elemente, trafo=((0, 0, 0), 0), eltern=None, aus=None):
    """Liefert (element, absolute Box min, absolute Box max, eltern-id). Drehung um pos, gegen den Uhrzeigersinn."""
    aus = [] if aus is None else aus
    (ox, oy, oz), og = trafo
    for e in elemente:
        p = drehe(e['lage']['pos'], og)
        ursprung = (ox + p[0], oy + p[1], oz + p[2])
        winkel = og + e['lage'].get('rot_z', 0)
        m = e['masse']
        ecken = [drehe((x, y, z), winkel) for x in (0, m['b']) for y in (0, m['t']) for z in (0, m['h'])]
        lo = tuple(min(c[i] for c in ecken) + ursprung[i] for i in range(3))
        hi = tuple(max(c[i] for c in ecken) + ursprung[i] for i in range(3))
        aus.append((e, lo, hi, eltern))
        elemente_flach(e.get('kinder', []), (ursprung, winkel), e['id'], aus)
    return aus


def bibrefs(modell):
    for t in modell.get('teile', []):
        if 'material' in t:
            yield t['material'], t['id']
        for k in (t.get('kanten') or {}).values():
            if k:
                yield k['material'], t['id']
        for b in t.get('beschlaege', []):
            yield b['ref'], t['id']
    for e, _, _, _ in elemente_flach(modell.get('elemente', [])):
        if 'geraet' in e:
            yield e['geraet'], e['id']
        for f in e.get('fronten', []):
            if 'beschlag' in f:
                yield f['beschlag'], e['id']
        for i in e.get('innenausstattung', []):
            if 'beschlag' in i:
                yield i['beschlag'], e['id']


# ---------- Invarianten ----------

def bogen_invarianten(bogen):
    fehler = []
    g = bogen['raum']['grundriss']
    flaeche = sum(g[i][0] * g[(i + 1) % len(g)][1] - g[(i + 1) % len(g)][0] * g[i][1] for i in range(len(g))) / 2
    if flaeche <= 0:
        fehler.append('I7 Grundriss nicht gegen den Uhrzeigersinn (Flaeche <= 0)')
    w = bogen['raum']['waende'][0]
    a, b = g[w['von']] if w['von'] < len(g) else None, g[w['nach']] if w['nach'] < len(g) else None
    if not (a and b and a[0] == 0 and a[1] == 0 and b[1] == 0 and b[0] > 0):
        fehler.append(f"I7 Wand A ({w['id']}) liegt nicht von [0,0] nach [L,0]")
    return fehler


def invarianten(modell, kontext):
    fehler, warnungen = [], []
    werte = modell.get('werte', {})
    bogen = kontext['planungsbogen'].get(modell['planungsbogen']['id'])
    setup = kontext['setup'].get(modell['setup']['id'])

    # I1 Herkunft passt zur Quelle (Wert und Herkunft); Rechenprobe; Mindestsatz
    bw = (bogen or {}).get('vorgaben', {}).get('werte', {})
    sk = setup_kette(setup, kontext['setup']) if setup else {}
    messungen = {m['id']: m['wert'] for m in (bogen or {}).get('raum', {}).get('messungen', [])}
    for k, v in werte.items():
        h = v['herkunft']
        if h == 'projekt' and not (k in bw and bw[k]['herkunft'] == 'projekt' and bw[k]['wert'] == v['wert']):
            fehler.append(f'I1 {k}: herkunft projekt, aber im Bogen nicht als bestaetigte Vorgabe mit gleichem Wert')
        if h == 'setup' and not (k in sk and sk[k].get('herkunft') == 'setup' and sk[k].get('wert') == v['wert']):
            fehler.append(f'I1 {k}: herkunft setup, aber im Setup nicht als bestaetigter Wert mit gleichem Wert')
        if h == 'gemessen':
            q = v.get('beleg', {}).get('quelle')
            if q not in messungen or messungen[q]['wert'] != v['wert']:
                fehler.append(f'I1 {k}: herkunft gemessen ohne passende Messung im Bogen')
        if h == 'kern' and 'beleg' not in v:
            fehler.append(f'I1 {k}: herkunft kern ohne beleg')
        if h != 'annahme' and ((k in bw and bw[k]['herkunft'] == 'annahme') or (k in sk and sk[k].get('herkunft') == 'annahme')):
            fehler.append(f'I1 {k}: Quelle ist annahme, im Modell als {h} gefuehrt')
        abl = v.get('beleg', {}).get('ableitung')
        if abl:
            teile_abl = abl.split('=')
            eingaenge = set(re.findall(r'[a-z][a-z0-9_]*', teile_abl[0])) & set(werte)
            if any(werte[x]['herkunft'] == 'annahme' for x in eingaenge) and h != 'annahme':
                fehler.append(f'I1 {k}: abgeleitet aus Annahme, herkunft muss annahme sein')
            ergebnis = rechne(teile_abl[-1]) if len(teile_abl) > 1 else None
            if ergebnis is not None and isinstance(v['wert'], (int, float)) and abs(ergebnis - v['wert']) > 1e-6:
                fehler.append(f"I1 {k}: Ableitung ergibt {ergebnis}, Wert ist {v['wert']}")
    for k in MINDESTSATZ:
        if k not in werte:
            fehler.append(f'I1 Mindestsatz: {k} fehlt in werte')

    # I2 annahmen[] = Werte mit herkunft annahme
    soll = {k for k, v in werte.items() if v['herkunft'] == 'annahme'}
    ist = set(modell.get('annahmen', []))
    if soll != ist:
        fehler.append(f'I2 annahmen: fehlt {sorted(soll - ist)}, zu viel {sorted(ist - soll)}')

    # I3 IDs eindeutig, Verweise aufloesbar
    flach = elemente_flach(modell.get('elemente', []))
    eids = [e['id'] for e, _, _, _ in flach]
    tids = [t['id'] for t in modell.get('teile', [])]
    aids = [a['id'] for a in modell.get('anschluesse', [])]
    for name, ids in (('Element', eids), ('Teil', tids), ('Anschluss', aids)):
        doppelt = {i for i in ids if ids.count(i) > 1}
        if doppelt:
            fehler.append(f'I3 {name}-IDs doppelt: {sorted(doppelt)}')
    for t in modell.get('teile', []):
        if t['gruppe'] not in eids:
            fehler.append(f"I3 Teil {t['id']}: gruppe {t['gruppe']} unbekannt")
    for e, _, _, _ in flach:
        for tid in e.get('teile', []):
            if tid not in tids:
                fehler.append(f"I3 Element {e['id']}: Teil {tid} unbekannt")
    for a in modell.get('anschluesse', []):
        if 'element' in a and a['element'] not in eids:
            fehler.append(f"I3 Anschluss {a['id']}: element {a['element']} unbekannt")

    # I4 Bearbeitungen im Fertigmass, Tiefe < Materialstaerke in Bohrrichtung ausser Durchgang
    for t in modell.get('teile', []):
        if 'fertig' not in t:
            continue
        L, B, Dk = t['fertig']['l'], t['fertig']['b'], t.get('dicke', 0)
        for i, b in enumerate(t.get('bearbeitungen', [])):
            s = b['seite']
            x, y, z = b.get('x', 0), b.get('y', 0), b.get('z', 0)
            dx = dy = 0
            laenge = b.get('laenge', 0) or (b.get('anzahl', 1) - 1) * b.get('teilung', 0)
            if b.get('richtung') == 'x':
                dx, dy = laenge, b.get('breite', 0)
            elif b.get('richtung') == 'y':
                dx, dy = b.get('breite', 0), laenge
            elif b['art'] in ('tasche', 'ausschnitt', 'griffmulde'):
                dx, dy = b.get('laenge', 0), b.get('breite', 0)
            ort = f"I4 Teil {t['id']} Bearbeitung {i}"
            tiefe, frei = b.get('tiefe', 0), b.get('durchgang')
            if s in ('oben', 'unten'):
                if not (0 <= x and x + dx <= L and 0 <= y and y + dy <= B):
                    fehler.append(f'{ort}: ausserhalb {L} x {B}')
                if tiefe >= Dk and not frei:
                    fehler.append(f'{ort}: Tiefe >= Dicke ohne durchgang')
            elif s in ('l1', 'l2'):
                if not (0 <= x <= L and 0 <= z <= Dk):
                    fehler.append(f'{ort}: ausserhalb Schmalflaeche {s}')
                if tiefe >= B and not frei:
                    fehler.append(f'{ort}: Tiefe >= Teilbreite')
            elif s in ('b1', 'b2'):
                if not (0 <= y <= B and 0 <= z <= Dk):
                    fehler.append(f'{ort}: ausserhalb Schmalflaeche {s}')
                if tiefe >= L and not frei:
                    fehler.append(f'{ort}: Tiefe >= Teillaenge')

    # I5 Bibliotheksverweise aufloesbar; Status passt zur Freigabe
    for ref, wo in bibrefs(modell):
        eintrag = kontext['bib'].get((ref['bibliothek'], ref['id']))
        if eintrag is None:
            fehler.append(f"I5 {wo}: {ref['bibliothek']}/{ref['id']} nicht in der Bibliothek")
            continue
        if eintrag['status'] == 'gesperrt':
            fehler.append(f"I5 {wo}: {ref['id']} ist gesperrt")
        elif eintrag['status'] != 'geprueft':
            if modell.get('freigabe'):
                fehler.append(f"I5 {wo}: {ref['id']} ist {eintrag['status']}, Fertigung verlangt geprueft")
            else:
                warnungen.append(f"I5 {wo}: {ref['id']} ist {eintrag['status']} (Planung erlaubt, Fertigung nicht)")

    # I6 Teil passt ins Lagerformat oder traegt Teilungsvermerk
    formate = {}
    for p in (setup or {}).get('platten', []):
        formate.setdefault(p['material']['id'], []).append((p['laenge'], p['breite']))
    for t in modell.get('teile', []):
        if t.get('art') != 'platte' or 'fertig' not in t or 'teilung' in t:
            continue
        l, b = t['fertig']['l'], t['fertig']['b']
        f = formate.get(t['material']['id'], [])
        if not any((l <= FL and b <= FB) or (t.get('drehbar') and l <= FB and b <= FL) for FL, FB in f):
            fehler.append(f"I6 Teil {t['id']}: {l} x {b} passt in kein Lagerformat {f}")

    # I7 Geometrie: Bogen-Regeln; Elemente (mit Drehung) und Freiraeume im Raum; Freiraum min < max
    if bogen:
        fehler += bogen_invarianten(bogen)
        g = bogen['raum']['grundriss']
        xs, ys = [p[0] for p in g], [p[1] for p in g]
        raum_lo, raum_hi = (min(xs), min(ys), 0), (max(xs), max(ys), bogen['raum']['raumhoehe']['wert'])
        eps = 1e-6
        def drin(lo, hi):
            return all(raum_lo[i] - eps <= lo[i] and hi[i] <= raum_hi[i] + eps for i in range(3))
        for e, lo, hi, _ in flach:
            if not drin(lo, hi):
                fehler.append(f"I7 Element {e['id']} ausserhalb des Raums")
            for fr in e.get('freiraum', []):
                if not all(fr['min'][i] < fr['max'][i] for i in range(3)):
                    fehler.append(f"I7 Freiraum {fr['zweck']} von {e['id']}: min nicht kleiner als max")
                elif not drin(fr['min'], fr['max']):
                    fehler.append(f"I7 Freiraum {fr['zweck']} von {e['id']} ausserhalb des Raums")

    # I8 Revision: Freigabe, Teile und Pruefung gehoeren zur aktuellen Revision
    r = modell['revision']
    if modell.get('freigabe') and modell['freigabe']['revision'] != r:
        fehler.append(f"I8 freigabe gilt fuer Revision {modell['freigabe']['revision']}, Modell ist Revision {r}")
    if modell.get('teile') and modell.get('teile_revision') != r:
        fehler.append(f"I8 teile stammen aus Revision {modell.get('teile_revision')}, Modell ist Revision {r}")
    if modell.get('pruefung') and modell['pruefung']['revision'] != r:
        fehler.append(f"I8 pruefung stammt aus Revision {modell['pruefung']['revision']}, Modell ist Revision {r}")
    return fehler, warnungen


def lade(ordner):
    return {p.name: json.loads(p.read_text()) for p in sorted(ordner.glob('*.json')) if p.name != 'erwartet.json'}


def kontext_aus(daten):
    k = {'planungsbogen': {}, 'setup': {}, 'bib': {}}
    for name, d in daten.items():
        art = name.split('.')[0]
        if art in ('planungsbogen', 'setup') and isinstance(d, dict) and 'id' in d:
            k[art][d['id']] = d
        elif art == 'bibliothekseintrag' and isinstance(d, dict) and 'id' in d:
            k['bib'][(d['bibliothek'], d['id'])] = d
    return k


def pruefe_datei(name, d, kontext):
    befunde, warn = schemafehler(name, d), []
    if not befunde and name.startswith('kuechenmodell.'):
        f, warn = invarianten(d, kontext)
        befunde += f
    elif not befunde and name.startswith('planungsbogen.'):
        befunde += bogen_invarianten(d)
    return befunde, warn


abweichung = 0
beispiele = lade(D / 'beispiel')
kontext = kontext_aus(beispiele)
for name, d in beispiele.items():
    befunde, warn = pruefe_datei(name, d, kontext)
    for w in warn:
        print('  Warnung', name, w)
    for b in befunde:
        print('  FEHLER', name, b)
    abweichung += len(befunde)
    print(name, 'ok' if not befunde else f'{len(befunde)} Fehler')

neg = D / 'beispiel' / 'fehler'
if neg.exists():
    erwartet = json.loads((neg / 'erwartet.json').read_text())
    for name, d in lade(neg).items():
        befunde, _ = pruefe_datei(name, d, kontext)
        fehlt = [m for m in erwartet.get(name, []) if not any(m in b for b in befunde)]
        if not befunde or fehlt or name not in erwartet:
            abweichung += 1
            print(f'NEGATIV {name}: unerwartet; nicht gefunden {fehlt}; gefunden {befunde}')
        else:
            print(f'NEGATIV {name}: scheitert wie erwartet ({len(befunde)} Befunde)')
            for b in befunde:
                print('    ', b)
sys.exit(1 if abweichung else 0)
