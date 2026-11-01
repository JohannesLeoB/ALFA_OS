import json,re,subprocess,sys
pdf,first,last,out=sys.argv[1],int(sys.argv[2]),int(sys.argv[3]),sys.argv[4]
txt=subprocess.run(["pdftotext","-q","-layout","-f",str(first),"-l",str(last),pdf,"-"],capture_output=True,text=True,errors="replace").stdout
pages=txt.split("\f")
lab=re.compile(r"(?:^|\s)(\d{1,2}\.\d{1,3}|V\.\d+)\s*$")
with open(out,"a",encoding="utf-8") as h:
    for i,t in enumerate(pages[:last-first+1]):
        lines=[l.rstrip() for l in t.splitlines() if l.strip()]
        label=None
        for l in lines[-4:]+lines[:3]:
            m=lab.search(l)
            if m: label=m.group(1); break
        h.write(json.dumps({"pdf_page":first+i,"label":label,"chars":len(t),"text":"\n".join(lines)},ensure_ascii=False)+"\n")
print(first,last,len(pages))
