import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))

import argparse
import json
import re
import sqlite3

from data import by_id, load, resolve_setup, root

DB = root / "build" / "knowledge.sqlite"


def dump(value):
    return json.dumps(value, ensure_ascii=False)


def rows(loaded):
    tables = {name: [] for name in ("sources", "concepts", "atoms", "library_entries", "media",
                                    "setups", "setup_values", "edges")}
    edges = set()
    for _, s in loaded["source"]:
        tables["sources"].append((s["id"], s["kind"], s["publisher"], s["title"], s.get("edition"),
                                  s.get("location"), s["trust"], s["added"], s.get("note")))
    for _, c in loaded["concept"]:
        tables["concepts"].append((c["id"], c["label_en"], c["label_de"], " | ".join(c.get("synonyms_en", [])),
                                   " | ".join(c.get("synonyms_de", [])), c.get("broader"), c.get("part_of"),
                                   c.get("definition_en"), c.get("definition_de")))
        for rel in ("broader", "part_of"):
            if c.get(rel):
                edges.add((c["id"], rel, c[rel]))
    for _, a in loaded["atom"]:
        tables["atoms"].append((a["id"], a["kind"], a["domain"], a["statement_en"], a["statement_de"],
                                a.get("formula"), a["stage"], a["status"], a["evidence"], a.get("proposed_by"),
                                a.get("decided_by"), a["added"], a.get("checked"), dump(a)))
        for concept in a["concepts"]:
            edges.add((a["id"], "about", concept))
        for source in a["sources"]:
            edges.add((a["id"], "cites", source["id"]))
        for link in a.get("links", []):
            edges.add((a["id"], link["rel"], link["to"]))
    for _, entry in loaded["library-entry"]:
        tables["library_entries"].append((entry["id"], entry["library"], entry["maker"], entry["series"],
                                          entry["name"], entry["status"], entry["sharing"], dump(entry)))
        for source in entry["sources"]:
            edges.add((entry["id"], "cites", source["id"]))
    for _, m in loaded["media"]:
        tables["media"].append((m["id"], m["kind"], m["source"], m["locator"], m["caption_en"],
                                m.get("caption_de"), dump(m)))
        edges.add((m["id"], "cites", m["source"]))
        for concept in m["concepts"]:
            edges.add((m["id"], "shows", concept))
    for _, s in loaded["setup"]:
        tables["setups"].append((s["id"], s["level"], s.get("parent"), s.get("label"), s["status"]))
        for key, entry in s["values"].items():
            tables["setup_values"].append((s["id"], key, dump(entry["value"]), entry["status"],
                                           entry["evidence"], entry.get("note")))
    tables["edges"] = sorted(edges)
    return tables


def build():
    loaded = load()
    DB.parent.mkdir(exist_ok=True)
    if DB.exists():
        DB.unlink()
    db = sqlite3.connect(DB)
    db.executescript((root / "sql" / "schema.sql").read_text(encoding="utf-8"))
    for table, items in rows(loaded).items():
        if items:
            marks = ",".join("?" * len(items[0]))
            db.executemany(f"insert into {table} values ({marks})", items)
    db.execute("create virtual table search using fts5(id unindexed, kind unindexed, text_en, text_de, "
               "tokenize='unicode61 remove_diacritics 2')")
    db.execute("insert into search select id, 'atom', statement_en || ' ' || coalesce(formula, ''), statement_de from atoms")
    db.execute("insert into search select id, 'concept', label_en || ' ' || synonyms_en || ' ' || coalesce(definition_en, ''), "
               "label_de || ' ' || synonyms_de from concepts")
    db.execute("insert into search select id, 'library', maker || ' ' || series || ' ' || name, '' from library_entries")
    db.execute("insert into search select id, 'media', caption_en, coalesce(caption_de, '') from media")
    db.commit()
    counts = {t: db.execute(f"select count(*) from {t}").fetchone()[0] for t in ("atoms", "concepts", "edges")}
    print(f"Wrote {DB.relative_to(root)}: {counts['atoms']} atoms, {counts['concepts']} concepts, {counts['edges']} edges.")


def connect():
    if not DB.exists():
        build()
    return sqlite3.connect(DB)


def query(text, limit):
    db = connect()
    terms = [t for t in re.findall(r"\w+", text, re.UNICODE) if len(t) > 1]
    if not terms:
        return
    match = " OR ".join(f'"{t}"*' for t in terms)
    hits = db.execute("select id, kind from search where search match ? order by rank limit 40", (match,)).fetchall()
    concepts = [i for i, k in hits if k == "concept"]
    scores = {}
    for rank, (identifier, kind) in enumerate(hits):
        if kind != "concept":
            scores[identifier] = scores.get(identifier, 0) + 40 - rank
    for concept in concepts:
        for (atom,) in db.execute("select src from edges where rel = 'about' and dst = ?", (concept,)):
            scores[atom] = scores.get(atom, 0) + 5
    if concepts:
        names = db.execute(f"select id, label_en, label_de from concepts where id in ({','.join('?' * len(concepts))})",
                           concepts).fetchall()
        print("Concepts: " + "; ".join(f"{i} ({en} / {de})" for i, en, de in names))
    for identifier, _ in sorted(scores.items(), key=lambda item: -item[1])[:limit]:
        row = db.execute("select statement_en, statement_de, status, evidence from atoms where id = ?", (identifier,)).fetchone()
        if row:
            sources = [d for (d,) in db.execute("select dst from edges where src = ? and rel = 'cites'", (identifier,))]
            print(f"{identifier} [{row[2]}, {row[3]}] {row[0]}\n    de: {row[1]}\n    sources: {', '.join(sources)}")
            continue
        row = db.execute("select name, status, sharing from library_entries where id = ?", (identifier,)).fetchone()
        if row:
            print(f"{identifier} [library, {row[1]}, {row[2]}] {row[0]}")


def concept(identifier):
    db = connect()
    row = db.execute("select label_en, label_de, synonyms_en, synonyms_de, definition_en from concepts where id = ?",
                     (identifier,)).fetchone()
    if not row:
        print(f"Unknown concept {identifier}.")
        return
    print(f"{identifier}: {row[0]} / {row[1]}\n  synonyms: {row[2]} / {row[3]}\n  {row[4]}")
    for src, rel, dst in db.execute("select src, rel, dst from edges where src = ? or dst = ? order by rel, src",
                                    (identifier, identifier)):
        print(f"  {src} --{rel}--> {dst}")


def setup(identifier):
    values = resolve_setup(by_id(load(), "setup"), identifier)
    for key, entry in sorted(values.items()):
        print(f"{key} = {dump(entry['value'])} [{entry['status']}, {entry['evidence']}, from {entry['layer']}]")


def main():
    parser = argparse.ArgumentParser(description="Build and query the kitchen knowledge base.")
    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("build", help="Build build/knowledge.sqlite from the files.")
    q = sub.add_parser("query", help="Search atoms in English or German.")
    q.add_argument("text")
    q.add_argument("--limit", type=int, default=8)
    c = sub.add_parser("concept", help="Show a concept and its edges.")
    c.add_argument("id")
    s = sub.add_parser("setup", help="Show the resolved values of a setup and its parents.")
    s.add_argument("id")
    args = parser.parse_args()
    if args.command == "build":
        build()
    elif args.command == "query":
        query(args.text, args.limit)
    elif args.command == "concept":
        concept(args.id)
    else:
        setup(args.id)
    return 0


if __name__ == "__main__":
    sys.exit(main())
