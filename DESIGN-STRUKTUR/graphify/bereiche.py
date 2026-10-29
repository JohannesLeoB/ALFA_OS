import json,collections,sys
src,out=sys.argv[1],sys.argv[2]
g=json.load(open(src)); n={x["id"]:x for x in g["nodes"]}; E=g["links"]
owner={}
for e in E:
  if e["relation"] in ("method","contains","case_of") and e["target"] not in owner: owner[e["target"]]=e["source"]
files={i for i,x in n.items() if x.get("source_file") and i not in owner}
def typ(i):
  k=0
  while i in owner and owner[i] not in files and k<20: i=owner[i]; k+=1
  return i
RULES=[("code/App/Shell/Assistant","Assistent"),("code/App/Shell/AppSession+Assistant","Assistent"),("code/Sources/Assistant/","Assistent"),
 ("code/App/Mail/","Mail"),("code/Sources/Mail/","Mail"),("code/App/Settings/","Einstellungen"),("code/Sources/Hub/","Hub"),
 ("code/App/Shell/","Hülle"),("code/Sources/Shell/","Hülle"),("code/Sources/Calculation/","Kalkulation"),("code/Sources/Integrations/","Dienste"),
 ("code/App/Components/","Grundlage"),("code/App/Design/","Grundlage"),("code/Sources/Design/","Grundlage"),("code/Sources/Core/","Grundlage"),("code/Sources/Storage/","Grundlage"),
 ("design/","Design-Laufzeit (Hülle, Bausteine)")]
NAMES=[b for _,b in RULES]; NAMES=list(dict.fromkeys(NAMES))
def ber(f):
  for p,b in RULES:
    if f.startswith(p): return b
  return None
types={}
for i,x in n.items():
  if not x.get("source_file") or i in files: continue
  t=typ(i)
  if t==i:
    b=ber(x["source_file"])
    if b: types[i]=b
agg=collections.defaultdict(lambda: dict(w=0,rel=collections.Counter(),ex=False,loc=None))
for e in E:
  if e["relation"] in ("method","contains","case_of"): continue
  s,t=typ(e["source"]),typ(e["target"])
  if s==t or s not in types or t not in types: continue
  a=agg[(s,t)]; a["w"]+=1; a["rel"][e["relation"]]+=1; a["ex"]|= e.get("confidence")=="EXTRACTED"
  if a["loc"] is None: a["loc"]=(e.get("source_file"),e.get("source_location"))
nodes=[]
for i,b in types.items():
  x=n[i]; nodes.append(dict(id=i,label=x["label"],file_type="code",source_file=x["source_file"].split("/",1)[1] if x["source_file"].startswith("code/") else "Design Etappe I/"+x["source_file"].split("/",1)[1],
    source_location=x.get("source_location"),community=NAMES.index(b),community_name=b))
links=[]
for (s,t),a in agg.items():
  rel=a["rel"].most_common(1)[0][0]
  links.append(dict(source=s,target=t,relation=rel,confidence="EXTRACTED" if a["ex"] else "INFERRED",confidence_score=1.0 if a["ex"] else 0.8,weight=float(a["w"]),
    source_file=(a["loc"][0] or "").split("/",1)[-1],source_location=a["loc"][1],context="; ".join(f"{k} ×{v}" for k,v in a["rel"].most_common())))
G=dict(g); G["nodes"]=nodes; G["links"]=links; G["hyperedges"]=[]
json.dump(G,open(out+"/graph.json","w"),ensure_ascii=False)
json.dump({str(k):v for k,v in enumerate(NAMES)},open(out+"/labels.json","w"),ensure_ascii=False)
# matrix
M=collections.Counter(); R=collections.defaultdict(collections.Counter)
for (s,t),a in agg.items():
  bs,bt=types[s],types[t]
  if bs!=bt: M[(bs,bt)]+=1; R[(bs,bt)].update(a["rel"])
print("Typen",len(nodes),"Kanten",len(links),"quer",sum(M.values()))
json.dump(dict(namen=NAMES,matrix=[dict(von=a,an=b,typ_paare=c,kanten=dict(R[(a,b)])) for (a,b),c in M.most_common()]),open(out+"/bereichsmatrix.json","w"),ensure_ascii=False,indent=1)
print(collections.Counter(types.values()))
