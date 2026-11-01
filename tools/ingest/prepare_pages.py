import json,re,subprocess,sys,os,datetime
pdf,cat,first,last=sys.argv[1],sys.argv[2],int(sys.argv[3]),int(sys.argv[4])
render=len(sys.argv)<6 or sys.argv[5]!="norender"
base=os.path.expanduser(f"~/mnt/creative claude/Training/05_Eingang_Quellen/verarbeitet/{cat}")
png=os.path.join(base,"png"); os.makedirs(png,exist_ok=True)
now=lambda: datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
texts={}
with open(os.path.join(base,"pages.jsonl"),encoding="utf-8") as h:
    for l in h:
        r=json.loads(l)
        if first<=r["pdf_page"]<=last: texts[r["pdf_page"]]=r["text"]
if render: subprocess.run(["pdftoppm","-q","-r","110","-png","-f",str(first),"-l",str(last),pdf,os.path.join(png,"p")],check=False)
imgs={}
for l in subprocess.run(["pdfimages","-list","-f",str(first),"-l",str(last),pdf],capture_output=True,text=True).stdout.splitlines()[2:]:
    p=l.split()
    if p and p[0].isdigit(): imgs[int(p[0])]=imgs.get(int(p[0]),0)+1
R={"haefele_article":re.compile(r"\b\d{3}\.\d{2}\.\d{3}\b"),"ref":re.compile(r"►\s*MB\s*(\d{1,2}\.\d{1,3})"),
   "webcode":re.compile(r"(?:Webcode|Short-URL)\s*[:\-]?\s*(\S+)",re.I),"packaging":re.compile(r"(?:Abpackung|VPE|Verpackungseinheit)\s*:?\s*([^\n]{1,40})"),
   "delivery":re.compile(r"(?:Lieferzeit|Lieferbar|lieferbar ab|auf Anfrage|Mindestbestellmenge)[^\n]{0,60}",re.I),"price":re.compile(r"[^\n]{0,40}(?:€|EUR\b)[^\n]{0,40}")}
with open(os.path.join(base,"pages_meta.jsonl"),"a",encoding="utf-8",buffering=1) as meta, open(os.path.join(base,"status.jsonl"),"a",encoding="utf-8",buffering=1) as st:
    for p in range(first,last+1):
        t=texts.get(p,"")
        f=f"p-{p:04d}.png"
        rec={"catalog":cat,"pdf_page":p,"extracted_at":now(),"chars":len(t),"images":imgs.get(p,0),"png":f if os.path.exists(os.path.join(png,f)) else None}
        for k,rx in R.items():
            found=[m.group(0).strip() for m in rx.finditer(t)] if k in ("delivery","price") else rx.findall(t)
            rec[k]=sorted(set(x.strip() for x in found))[:200]
        meta.write(json.dumps(rec,ensure_ascii=False)+"\n")
        st.write(json.dumps({"catalog":cat,"pdf_page":p,"stage":"machine_extracted","at":rec["extracted_at"],"by":"prepare.py v2"},ensure_ascii=False)+"\n")
print(cat,first,last,"done")
