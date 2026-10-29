import json, sys, collections
g = json.load(open(sys.argv[1])); n = {x["id"]: x for x in g["nodes"]}
P = collections.defaultdict(list)
for e in g["links"]:
    s, t = n[e["source"]], n[e["target"]]
    a, b = s["community_name"], t["community_name"]
    if a == b: continue
    P[(a, b)].append(dict(von=s["label"], an=t["label"], w=e["weight"], art=e["context"], ort=f'{e["source_file"]}:{(e["source_location"] or "").lstrip("L")}'))
fix = lambda x: "Design-Skripte" if x.startswith("Design-Laufzeit") else x
out = [dict(von=fix(a), an=fix(b), n=len(L), bsp=sorted(L, key=lambda x: -x["w"])[:15]) for (a, b), L in P.items()]
json.dump(out, open(sys.argv[2], "w"), ensure_ascii=False)
c = collections.Counter(fix(x["community_name"]) for x in g["nodes"])
meta = json.loads(sys.argv[3]); meta["types"] = dict(c); meta["typesTotal"] = sum(v for k, v in c.items() if k != "Design-Skripte")
json.dump(meta, open(sys.argv[4], "w"), ensure_ascii=False)
print(len(out), "Paare", meta["typesTotal"], "Typen")
