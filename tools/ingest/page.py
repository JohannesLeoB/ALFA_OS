import json,sys
base="/mnt/user-data/uploads/creative claude/Training/05_Eingang_Quellen/verarbeitet/"
cat,page=sys.argv[1],int(sys.argv[2])
for l in open(base+cat+"/pages.jsonl",encoding="utf-8"):
    r=json.loads(l)
    if r["pdf_page"]==page: print(r["text"]); break
meta=None
for l in open(base+cat+"/pages_meta.jsonl",encoding="utf-8"):
    r=json.loads(l)
    if r["pdf_page"]==page: meta=r
print("\n#### MACHINE META:",json.dumps(meta,ensure_ascii=False))
