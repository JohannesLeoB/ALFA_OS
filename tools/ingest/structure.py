import json,re,sys,collections
base="/mnt/user-data/uploads/creative claude/Training/05_Eingang_Quellen/verarbeitet/"
out=sys.argv[1]
def load(n): return [json.loads(l) for l in open(base+n+"/pages.jsonl",encoding="utf-8")]
# Haefele
H=load("haefele_moebelbeschlaege_2026")
foot=re.compile(r"MB\s+((?:\d{1,2}|V)\.\d{1,3})\b")
art=re.compile(r"\b\d{3}\.\d{2}\.\d{3}\b")
ref=re.compile(r"►MB\s*(\d{1,2}\.\d{1,3})")
toc_line=re.compile(r"^\s*(?:>\s*)?(.+?)\s*\x08\s*(.+)$")
pages=[]
for r in H:
    lines=r["text"].splitlines()
    label=None
    for l in reversed(lines[-3:]):
        m=foot.search(l)
        if m: label=m.group(1); break
    head=[l.strip() for l in lines[:3] if l.strip() and l.strip()!="​"]
    pages.append({"pdf_page":r["pdf_page"],"label":label,"chapter":label.split(".")[0] if label else None,
                  "heading":head[:2],"articles":sorted(set(art.findall(r["text"]))),"refs":sorted(set(ref.findall(r["text"])))})
# fill missing chapter from neighbours
for i,p in enumerate(pages):
    if p["chapter"] is None:
        prev=next((q["chapter"] for q in reversed(pages[:i]) if q["chapter"]),None)
        nxt=next((q["chapter"] for q in pages[i+1:] if q["chapter"]),None)
        p["chapter_inferred"]=prev if prev==nxt else None
json.dump(pages,open(out+"/haefele_pages.json","w"),ensure_ascii=False)
toc=[]
for r,p in zip(H,pages):
    if "Inhaltsverzeichnis" in r["text"][:600]:
        section=None
        for l in r["text"].splitlines():
            m=toc_line.match(l)
            if m:
                toc.append({"toc_pdf_page":r["pdf_page"],"toc_label":p["label"],"entry":re.sub(r"\s{2,}"," ",m.group(1)).strip(),"target":m.group(2).replace("_"," ").strip()})
json.dump(toc,open(out+"/haefele_toc.json","w"),ensure_ascii=False,indent=0)
c=collections.Counter(p["chapter"] or p.get("chapter_inferred") or "?" for p in pages)
print("haefele labels",sum(1 for p in pages if p["label"]),"chapters",dict(sorted(c.items(),key=lambda x:(len(x[0]),x[0]))),"toc entries",len(toc),"articles",len({a for p in pages for a in p["articles"]}))
# Blum
B=load("blum_katalog_2026")
crumb=re.compile("^\\s*(\\d{1,2})\\s*[〉〉]\\s*(.+)$")
num=re.compile(r"(?:^|\s)(\d{1,3})\s*(?:Katalog 2027/2028)?\s*$")
bp=[]
for r in B:
    lines=[l for l in r["text"].splitlines() if l.strip()]
    path=None
    for l in lines[:3]:
        m=crumb.match(l.strip())
        if m: path=[m.group(1)]+[x.strip() for x in re.split("[〉\u232a]",m.group(2))]; break
    printed=None
    for l in lines[-3:]:
        s=l.replace("Katalog 2027/2028","").strip()
        m=re.search(r"(?:^|\s)(\d{1,3})(?:\s+\d{1,2})?$",s) or re.match(r"^(\d{1,2})\s+(\d{1,3})$",s)
        if m: printed=m.group(len(m.groups())); 
    bp.append({"pdf_page":r["pdf_page"],"printed":printed,"path":path})
json.dump(bp,open(out+"/blum_pages.json","w"),ensure_ascii=False)
print("blum with path",sum(1 for p in bp if p["path"]),"of",len(bp))
