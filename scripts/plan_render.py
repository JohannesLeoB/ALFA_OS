#!/usr/bin/env python3
# plan_render.py: builds ausgang/bauzeitenplan.html from plan/BAUZEITENPLAN.md (deterministic, no network).
import html
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PLAN = os.path.join(ROOT, "plan", "BAUZEITENPLAN.md")
OUT = os.path.join(ROOT, "ausgang", "bauzeitenplan.html")

CLASS = {"erledigt": "s-done", "läuft": "s-run", "geplant": "s-plan",
         "wartet auf Johannes": "s-john", "wartet auf Design": "s-design"}
LEGEND = ["erledigt", "läuft", "geplant", "wartet auf Johannes", "wartet auf Design"]

CSS = """
:root{--bg:#eceff3;--panel:#f7f9fb;--fg:#18212b;--muted:#556170;--line:#cdd5de;--done:#1d7658;--run:#245fae;--plan:#55657a;--john:#a8650a;--design:#ae2f58;--on-solid:#f7f9fb;color-scheme:light}
@media (prefers-color-scheme:dark){:root:not([data-theme="light"]){--bg:#0f141a;--panel:#171f28;--fg:#e3e8ee;--muted:#98a4b2;--line:#2c3744;--done:#43b88d;--run:#6aa3ee;--plan:#8e9cae;--john:#e2a444;--design:#e46b92;--on-solid:#0d1812;color-scheme:dark}}
:root[data-theme="dark"]{--bg:#0f141a;--panel:#171f28;--fg:#e3e8ee;--muted:#98a4b2;--line:#2c3744;--done:#43b88d;--run:#6aa3ee;--plan:#8e9cae;--john:#e2a444;--design:#e46b92;--on-solid:#0d1812;color-scheme:dark}
*{box-sizing:border-box;margin:0;padding:0}
html,body{height:100%}
body{background:var(--bg);color:var(--fg);font-family:"IBM Plex Sans",system-ui,-apple-system,"Segoe UI",sans-serif;font-size:clamp(10.5px,.74vw,13px);line-height:1.25;font-variant-numeric:tabular-nums;overflow-x:hidden}
.page{height:100%;display:grid;grid-template-rows:auto auto minmax(0,1fr) auto auto;gap:8px;padding:10px 16px;padding-inline:max(16px,1vw)}
.card{background:var(--panel);border:1px solid var(--line);border-radius:6px}
h1{font-size:1.9em;line-height:1.1;font-weight:600}
h2{font-size:.78em;text-transform:uppercase;letter-spacing:.07em;color:var(--muted);font-weight:600;margin-bottom:6px}
.muted{color:var(--muted)}
.head{display:grid;grid-template-columns:minmax(0,1fr) auto;gap:16px;align-items:start}
.head .sub{margin-top:3px}
.stand{text-align:right}
.stand .big{font-size:2.1em;font-weight:600;line-height:1.1;white-space:nowrap}
.stand .lab{font-size:.78em;text-transform:uppercase;letter-spacing:.07em;color:var(--muted)}
.next{margin-top:3px;max-width:44ch;margin-left:auto}
.kpis{display:grid;grid-template-columns:repeat(5,minmax(0,1fr));gap:8px}
.kpi{padding:6px 10px}
.kpi b{display:block;font-size:.78em;text-transform:uppercase;letter-spacing:.06em;color:var(--muted);font-weight:600}
.kpi .v{font-weight:500}
.main{display:grid;grid-template-columns:minmax(0,1fr) minmax(0,3fr);gap:8px;min-height:0}
.panel{padding:8px 10px;min-height:0;overflow:auto}
.tl{list-style:none;position:relative;border-left:2px solid var(--line);margin-left:5px}
.tl li{position:relative;padding:0 0 4px 12px}
.tl li::before{content:"";position:absolute;left:-7px;top:.3em;width:10px;height:10px;border-radius:50%;background:var(--panel);border:2px solid var(--plan)}
.tl time{display:block;font-weight:600;font-size:.92em}
.tl span{display:block}
.tl small{display:block;color:var(--muted);font-size:.8em}
.gantt{display:flex;flex-direction:column;min-height:0;height:100%;--lab:clamp(170px,16vw,320px)}
.ghead,.row{display:grid;grid-template-columns:var(--lab) repeat(5,minmax(0,1fr))}
.ghead{margin-left:30px;font-size:.82em;color:var(--muted);font-weight:600;border-bottom:1px solid var(--line);padding-bottom:3px}
.ghead div{padding-inline:4px}
.gb{display:flex;flex-direction:column;flex:1 1 0;min-height:0}
.grp{display:grid;grid-template-columns:30px minmax(0,1fr);border-bottom:1px solid var(--line)}
.gname{writing-mode:vertical-rl;transform:rotate(180deg);font-size:.78em;font-weight:600;color:var(--muted);text-align:center;padding:3px 0;border-right:1px solid var(--line)}
.rows{display:flex;flex-direction:column}
.row{min-height:21px;align-items:center;border-top:1px dotted var(--line);position:relative}
.row:first-child{border-top:0}
.lab{padding:1px 6px;grid-column:1;grid-row:1;display:flex;flex-direction:column;min-width:0}
.lab b{display:block;font-weight:500;font-size:.9em;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.lab i{display:block;font-style:normal;font-size:.72em;color:var(--muted);white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.cell{grid-row:1;height:100%;border-left:1px solid var(--line)}
.bar{grid-row:1;align-self:center;height:16px;margin-inline:2px;border-radius:4px;display:flex;align-items:center;padding-inline:3px;font-size:.82em;font-weight:600;white-space:nowrap;overflow:hidden;position:relative;z-index:1}
.bar span{background:var(--panel);color:var(--fg);padding:0 4px;border-radius:3px;overflow:hidden;text-overflow:ellipsis}
.s-done{background:var(--done);border:1.5px solid var(--done)}
.s-done span{background:transparent;color:var(--on-solid)}
.s-run{background:repeating-linear-gradient(135deg,var(--run) 0 4px,color-mix(in srgb,var(--run) 22%,var(--panel)) 4px 8px);border:1.5px solid var(--run)}
.s-plan{background:transparent;border:1.5px solid var(--plan)}
.s-plan span{background:transparent}
.s-john{background:radial-gradient(var(--john) 1.1px,transparent 1.6px) 0 0/6px 6px,color-mix(in srgb,var(--john) 14%,var(--panel));border:1.5px solid var(--john)}
.s-design{background:color-mix(in srgb,var(--design) 10%,transparent);border:1.5px dashed var(--design)}
.s-design span{background:transparent}
.legend{display:flex;flex-wrap:wrap;gap:4px 14px;padding-top:6px;font-size:.85em;color:var(--muted)}
.legend span{display:inline-flex;align-items:center;gap:5px}
.legend i{display:inline-block;width:22px;height:12px;border-radius:3px}
.bottom{display:grid;grid-template-columns:minmax(0,3fr) minmax(0,1fr);gap:8px}
.chain{list-style:none;display:grid;grid-template-columns:repeat(var(--n),minmax(0,1fr));gap:6px}
.chain li{position:relative;padding-top:20px}
.chain li::before{content:"";position:absolute;left:0;right:-6px;top:6px;height:2px;background:var(--line)}
.chain li:last-child::before{right:0}
.chain .mk{position:absolute;left:0;top:0;width:14px;height:14px;border-radius:50%;z-index:1}
.chain b{display:block;font-weight:600;font-size:.95em}
.chain small{display:block;font-size:.82em;color:var(--muted)}
.chain .mk.s-run{background:repeating-linear-gradient(135deg,var(--run) 0 3px,var(--panel) 3px 6px)}
.box ul{margin-left:1.1em}
.foot{font-size:.85em;color:var(--muted);padding:2px 0}
@media (max-width:1099px){
html,body{height:auto}
.page{height:auto;grid-template-rows:none}
.head,.main,.bottom{grid-template-columns:minmax(0,1fr)}
.kpis{grid-template-columns:repeat(2,minmax(0,1fr))}
.stand{text-align:left}.next{margin-left:0}
.panel{overflow:visible}
.chain{grid-template-columns:minmax(0,1fr);gap:10px}
.chain li{padding-top:0;padding-left:22px}
.chain li::before{left:6px;right:auto;top:0;bottom:-10px;width:2px;height:auto}
.gantt{--lab:130px}
.bar{font-size:.7em}
}
@media (prefers-reduced-motion:reduce){*{animation:none!important;transition:none!important}}
"""


def e(text):
    return html.escape(text, quote=True)


def parse(text):
    head, rows = {}, []
    for line in text.splitlines():
        if line.startswith("|"):
            if line.startswith("|---") or line.startswith("| Kennung"):
                continue
            cells = [c.strip() for c in line.strip().strip("|").split("|")]
            keys = ["key", "name", "group", "window", "paths", "state", "done_when", "source", "checked", "session"]
            rows.append(dict(zip(keys, cells)))
        elif ":" in line:
            label, value = line.split(":", 1)
            head[label.strip()] = value.strip()
    return head, rows


def window(value):
    m = re.match(r"^(\d)(?:-(\d))?$", value)
    if not m:
        return 2, 3
    start = int(m.group(1))
    end = int(m.group(2) or start)
    return start + 1, end + 2


def german(stamp):
    m = re.match(r"^(\d{4})-(\d{2})-(\d{2})(?: (\d{2}:\d{2}))?", stamp)
    if not m:
        return stamp
    return f"{m.group(3)}.{m.group(2)}.{m.group(1)}" + (f" {m.group(4)}" if m.group(4) else "")


def render(head, rows):
    stand = head.get("Stand", "")
    stand_time, _, stand_session = stand.partition("·")
    columns = [c.strip() for c in head.get("Spalten", "").split("|")]
    packages = [r for r in rows if r["group"] not in ("Meilenstein", "Design")]
    milestones = [r for r in rows if r["group"] == "Meilenstein"]
    count = lambda items, state: sum(1 for r in items if r["state"] == state)
    upcoming = next((m for m in milestones if m["state"] != "erledigt"), None)

    out = ['<title>ALFA_OS Bauzeitenplan</title>',
           '<link rel="preconnect" href="https://fonts.googleapis.com"><link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=IBM+Plex+Sans:wght@400;500;600&display=swap">',
           f"<style>{CSS.strip()}</style>", '<div class="page">']
    nxt = f'<p class="next"><b>Nächster Meilenstein:</b> {e(upcoming["name"])} ({e(upcoming["done_when"])}).</p>' if upcoming else ""
    out.append('<header class="head card" style="padding:8px 12px"><div><h1>ALFA_OS Bauzeitenplan</h1>'
               '<p class="sub muted">Eine App für das Studio, aus dem laufenden Code, Gestalt nach Johannes\' „so“. '
               'Erzeugt aus plan/BAUZEITENPLAN.md.</p></div>'
               f'<div class="stand"><div class="lab">Stand · {e(stand_session.strip())}</div>'
               f'<div class="big">{e(german(stand_time.strip()))}</div>{nxt}</div></header>')

    kpis = [("Pakete", f"{len(packages)} im Plan"),
            ("Erledigt", f"{count(packages, 'erledigt')}"),
            ("Läuft", f"{count(packages, 'läuft')}"),
            ("Wartet auf Johannes", f"{count(rows, 'wartet auf Johannes')}"),
            ("Meilensteine erreicht", f"{count(milestones, 'erledigt')} von {len(milestones)}")]
    out.append('<section class="kpis" aria-label="Kennzahlen">' + "".join(
        f'<div class="kpi card"><b>{e(k)}</b><span class="v">{e(v)}</span></div>' for k, v in kpis) + "</section>")

    out.append('<main class="main">')
    stamped = sorted((r for r in rows if r["checked"]), key=lambda r: (r["checked"], r["key"]))
    out.append('<section class="panel card"><h2>Zeitstrahl</h2><ol class="tl">' + "".join(
        f'<li><time>{e(german(r["checked"]))}</time><span>{e(r["key"])} {e(r["name"])} · {e(r["state"])}</span>'
        f'<small>{e(r["session"])}</small></li>' for r in stamped) + "</ol></section>")

    out.append('<section class="panel card gantt"><h2>Bauzeitenplan</h2><div class="ghead"><div></div>'
               + "".join(f"<div>{e(c)}</div>" for c in columns) + '</div><div class="gb">')
    groups = []
    for r in rows:
        if r["group"] == "Meilenstein":
            continue
        if not groups or groups[-1][0] != r["group"]:
            groups.append((r["group"], []))
        groups[-1][1].append(r)
    for name, items in groups:
        out.append(f'<div class="grp" style="flex:{len(items)} 1 0"><div class="gname">{e(name)}</div><div class="rows">')
        for r in items:
            start, end = window(r["window"])
            cells = "".join(f'<div class="cell" style="grid-column:{i}"></div>' for i in range(2, 7))
            sub = r["state"] + (f" · {german(r['checked'])}" if r["checked"] else "")
            out.append(f'<div class="row"><div class="lab"><b>{e(r["key"])} {e(r["name"])}</b><i>{e(sub)}</i></div>{cells}'
                       f'<div class="bar {CLASS.get(r["state"], "s-plan")}" style="grid-column:{start}/{end}" title="{e(r["state"])}">'
                       f'<span>{e(r["state"])}</span></div></div>')
        out.append("</div></div>")
    out.append('</div><div class="legend">' + "".join(
        f'<span><i class="bar {CLASS[s]}" style="height:12px;margin:0;padding:0"></i>{e(s)}</span>' for s in LEGEND)
        + "</div></section></main>")

    out.append(f'<section class="bottom"><div class="card" style="padding:8px 10px"><h2>Meilensteine</h2>'
               f'<ol class="chain" style="--n:{max(len(milestones), 1)}">' + "".join(
                   f'<li><span class="mk {CLASS.get(m["state"], "s-plan")}"></span><b>{e(m["name"])}</b>'
                   f'<small>{e(m["state"])}' + (f' · {e(german(m["checked"]))}' if m["checked"] else "") + "</small></li>"
                   for m in milestones) + "</ol></div>")
    waiting = [r for r in rows if r["state"] == "wartet auf Johannes" and r["group"] != "Meilenstein"]
    out.append('<aside class="box card" style="padding:8px 10px"><h2>Was Johannes als Nächstes tut</h2><ul>' + "".join(
        f'<li>{e(r["name"])}: {e(r["done_when"].split(";")[-1].strip())}</li>' for r in waiting)
        + "<li>Mit Design die Mail-Fläche bis „so“ bringen.</li></ul></aside></section>")
    out.append(f'<footer class="foot">Quelle: plan/BAUZEITENPLAN.md · {e(stand)}</footer></div>')
    return "\n".join(out) + "\n"


def main():
    head, rows = parse(open(PLAN, encoding="utf-8").read())
    page = render(head, rows)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8") as handle:
        handle.write(page)
    print(OUT)
    return 0


if __name__ == "__main__":
    sys.exit(main())
