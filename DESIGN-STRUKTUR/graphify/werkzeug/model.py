import json, re, sys, os, collections

graph_path, code_root, design_root, bogen_list, meta_json, out_path = sys.argv[1:7]

pkg = open(os.path.join(code_root, "Package.swift")).read()
targets = []
parts = re.split(r"\.(target|testTarget)\(", pkg)
for kind, block in zip(parts[1::2], parts[2::2]):
    if kind != "target": continue
    name = re.search(r'name:\s*"([^"]+)"', block).group(1)
    path = re.search(r'path:\s*"([^"]+)"', block).group(1)
    db = re.search(r"dependencies:\s*\[(.*?)\]\s*,\s*path", block, re.S)
    deps = re.findall(r'(?<![\w.])"([A-Za-z]+)"(?!\s*,\s*package)', re.sub(r"\.product\([^)]*\)", "", db.group(1))) if db else []
    targets.append(dict(name=name, path=path, deps=[d for d in deps if d != name]))
tnames = {t["name"] for t in targets}

modules = {t["name"]: dict(name=t["name"], paths=[t["path"]], deps=list(t["deps"]), kind="integration" if "Integrations" in t["path"] else "module", view=None) for t in targets}
app_root = os.path.join(code_root, "App")
for f in sorted(os.listdir(app_root)) if os.path.isdir(app_root) else []:
    if not os.path.isdir(os.path.join(app_root, f)): continue
    if f in modules:
        modules[f]["paths"].append(f"App/{f}"); modules[f]["view"] = f"App/{f}"
    else:
        imports = set()
        for root, _, files in os.walk(os.path.join(app_root, f)):
            for fn in files:
                if fn.endswith(".swift"):
                    imports |= set(re.findall(r"^import (\w+)", open(os.path.join(root, fn)).read(), re.M))
        modules[f] = dict(name=f, paths=[f"App/{f}"], deps=sorted(imports & tnames), kind="view", view=f"App/{f}")

def module_of(rel):
    best = None
    for m in modules.values():
        for p in m["paths"]:
            if rel == p or rel.startswith(p + "/"):
                if not best or len(p) > best[1]: best = (m["name"], len(p))
    return best[0] if best else None

depth = {}
def depth_of(n, seen=()):
    if n in depth: return depth[n]
    ds = [depth_of(d, seen + (n,)) for d in modules[n]["deps"] if d in modules and d not in seen]
    depth[n] = 1 + max(ds) if ds else 0
    return depth[n]
for n in modules: modules[n]["depth"] = depth_of(n)

g = json.load(open(graph_path)); nodes = {x["id"]: x for x in g["nodes"]}; E = g["links"]
owner = {}
for e in E:
    if e["relation"] in ("method", "contains", "case_of") and e["target"] not in owner: owner[e["target"]] = e["source"]
files = {i for i, x in nodes.items() if x.get("source_file") and i not in owner}
def typ(i):
    k = 0
    while i in owner and owner[i] not in files and k < 20: i = owner[i]; k += 1
    return i
types, unplaced = {}, collections.Counter()
for i, x in nodes.items():
    sf = x.get("source_file") or ""
    if not sf.startswith("code/") or i in files or typ(i) != i: continue
    m = module_of(sf[5:])
    if m: types[i] = m
    else: unplaced[sf[5:].split("/")[0] + "/" + (sf[5:].split("/")[1] if "/" in sf[5:] else "")] += 1
counts = collections.Counter(types.values())
pairs = collections.defaultdict(lambda: dict(n=0, ex=[]))
seen = set()
for e in E:
    if e["relation"] in ("method", "contains", "case_of"): continue
    s, t = typ(e["source"]), typ(e["target"])
    if s == t or s not in types or t not in types or types[s] == types[t]: continue
    if (s, t) in seen: continue
    seen.add((s, t))
    p = pairs[(types[s], types[t])]; p["n"] += 1
    p["ex"].append(dict(von=nodes[s]["label"], an=nodes[t]["label"], ort=f'{(e.get("source_file") or "")[5:]}:{(e.get("source_location") or "").lstrip("L")}', art=e["relation"]))

swift = []
for root, _, fs in os.walk(code_root):
    for fn in fs:
        if fn.endswith(".swift"):
            full = os.path.join(root, fn); rel = os.path.relpath(full, code_root)
            if rel.startswith(("App/", "Sources/")): swift.append((rel, open(full).read().split("\n")))
def uses(pattern):
    hits = []
    rx = re.compile(pattern)
    for rel, lines in swift:
        for n, line in enumerate(lines, 1):
            if rx.search(line): hits.append((rel, n)); break
    return hits

con = lambda f: json.load(open(os.path.join(design_root, "contract", f)))
texts = con("texts.json")["texts"]; comps = con("components.json")["components"]
def tok_walk(o, p, out):
    if isinstance(o, dict):
        if "$value" in o: out.append((p, o)); return
        for k, v in o.items():
            if not k.startswith("$"): tok_walk(v, p + "." + k if p else k, out)
tokens = []
for f in ["base.tokens.json", "theme-light.tokens.json"]:
    tok_walk(con(f), "", tokens)
BOGEN = json.load(open(bogen_list))
def bogens_of(w):
    return {b for part in re.split(r",\s*", w) for b in [bogen_of_file(part)] if b}
def bogen_of_file(w):
    f = re.sub(r"\s*\(.*$", "", w).rsplit(":", 1)[0].strip() if ".dc.html" in w or w.strip().endswith(".js") or ".js:" in w else w.strip()
    if f.endswith(".dc.html"): return f[:-8]
    if f == "alfa-shell.js": return "ALFA Shell"
    if f == "alfa-bausteine.js": return "alfa-bausteine.js"
    return None
AREA = {"mail": "ALFA Mail", "settings": "ALFA Einstellungen", "shell": "ALFA Shell"}
entries = []
import glob
catalog = {}
for f in glob.glob(os.path.join(code_root, "Resources", "*.localizable.json")):
    k = json.load(open(f)).get("keys", {})
    catalog.update(k if isinstance(k, dict) else {x["key"]: x for x in k})
xc = os.path.join(code_root, "Resources", "Localizable.xcstrings")
if os.path.exists(xc):
    for key, v in json.load(open(xc)).get("strings", {}).items():
        de = (((v.get("localizations") or {}).get("de") or {}).get("stringUnit") or {}).get("value")
        catalog.setdefault(key, {"de": de or ""})
by_de = collections.defaultdict(list)
for key, v in catalog.items():
    de = (v.get("de") if isinstance(v, dict) else v) or ""
    if de: by_de[de.strip()].append(key)
text_match = collections.Counter()
for t in texts:
    b = "ALFA Bestaetigen" if (t.get("element") or "").startswith("confirm.") else AREA.get(t.get("area"), "ALFA Shell")
    if t["key"] in catalog: code_keys, how = [t["key"]], "Schlüssel"
    elif by_de.get((t.get("de") or "").strip()): code_keys, how = by_de[t["de"].strip()], "Wortlaut"
    else: code_keys, how = [], "fehlt im Katalog"
    text_match[how] += 1
    rx = "|".join(r'"' + re.escape(k) + r'"' for k in code_keys) or r"(?!x)x"
    entries.append(dict(kind="Text", id=t["key"] + ("" if how == "Schlüssel" else (" → " + code_keys[0] if code_keys else "")), bogen=[b], rx=rx, how=how))
for c in comps:
    bs = sorted(set().union(*[bogens_of(w) for w in c.get("where", [])] or [set()])) or ["ALFA Shell"]
    entries.append(dict(kind="Bauteil", id=c["name"], bogen=bs, typ=c["name"]))
seen_tok = set()
for p, o in tokens:
    name = p.split(".")[-1]
    if (name, p.split(".")[0]) in seen_tok: continue
    seen_tok.add((name, p.split(".")[0]))
    w = ((o.get("$extensions") or {}).get("alfa") or {}).get("where")
    ws = w if isinstance(w, list) else ([w] if w else [])
    bs = sorted(set().union(*[bogens_of(x) for x in ws if isinstance(x, str)] or [set()])) or ["TOKENBOGEN.json"]
    entries.append(dict(kind="Token", id=p, bogen=bs, rx=r"\b(?:Tokens\.\w+|Colors|Moods|Shadows|Surface|InkSet)\." + re.escape(name) + r"\b"))

design = {b["name"]: dict(name=b["name"], source=b["source"], lines=b.get("lines", 0), entries=collections.Counter(), unused=collections.Counter(), unusedEx=[]) for b in BOGEN}
for extra in ["TOKENBOGEN.json", "alfa-bausteine.js"]:
    design.setdefault(extra, dict(name=extra, source="E1", lines=0, entries=collections.Counter(), unused=collections.Counter(), unusedEx=[]))
bridges = collections.defaultdict(lambda: dict(n=0, kinds=collections.Counter(), ex=[]))
typ_at = {}
for i, m in types.items():
    typ_at.setdefault(nodes[i]["label"], (m, f'{nodes[i]["source_file"][5:]}:{(nodes[i].get("source_location") or "").lstrip("L")}'))
known = set(design_names := [b["name"] for b in BOGEN] + ["TOKENBOGEN.json", "alfa-bausteine.js"])
for en in entries:
    en["bogen"] = [b if b in known else "TOKENBOGEN.json" for b in en["bogen"]]
    if en["kind"] == "Bauteil":
        hits = [(typ_at[en["typ"]][1].rsplit(":", 1)[0], int(typ_at[en["typ"]][1].rsplit(":", 1)[1] or 0))] if en["typ"] in typ_at else []
    else:
        hits = uses(en["rx"])
    mods = sorted({module_of(r) for r, _ in hits if module_of(r)})
    for b in en["bogen"]:
        d = design.setdefault(b, dict(name=b, source="E1", lines=0, entries=collections.Counter(), unused=collections.Counter(), unusedEx=[]))
        d["entries"][en["kind"]] += 1
        if not mods:
            d["unused"][en["kind"]] += 1
            if len(d["unusedEx"]) < 24: d["unusedEx"].append(dict(kind=en["kind"], id=en["id"]))
        for m in mods:
            first = next((f"{r}:{n}" for r, n in hits if module_of(r) == m), "")
            br = bridges[(b, m)]; br["n"] += 1; br["kinds"][en["kind"]] += 1
            br["ex"].append(dict(kind=en["kind"], id=en["id"], ort=first))

meta = json.loads(meta_json)
model = dict(
    meta=meta,
    code=[dict(name=m["name"], kind=m["kind"], view=m["view"], paths=m["paths"], deps=m["deps"], depth=m["depth"], types=counts.get(m["name"], 0)) for m in modules.values()],
    design=[dict(name=d["name"], source=d["source"], lines=d["lines"], entries=dict(d["entries"]), unused=dict(d["unused"]), unusedEx=d["unusedEx"]) for d in design.values()],
    codeLinks=[dict(von=a, an=b, n=p["n"], ex=p["ex"][:14]) for (a, b), p in sorted(pairs.items(), key=lambda kv: -kv[1]["n"])],
    bridges=[dict(von=a, an=b, n=br["n"], kinds=dict(br["kinds"]), ex=br["ex"][:14]) for (a, b), br in sorted(bridges.items(), key=lambda kv: -kv[1]["n"])],
    unplaced=dict(unplaced),
    entriesTotal=len(entries),
    textMatch=dict(text_match),
)
json.dump(model, open(out_path, "w"), ensure_ascii=False)
print("textMatch", dict(text_match)); print("code", len(model["code"]), "types", sum(counts.values()), "codeLinks", len(model["codeLinks"]), "design", len(model["design"]), "bridges", len(model["bridges"]), "entries", len(entries), "unplaced", dict(unplaced))
for c in model["code"]: print(" ", c["name"], c["kind"], c["depth"], c["types"], c["deps"])
for d in model["design"]: print(" D", d["name"], d["entries"], "unused", d["unused"])
