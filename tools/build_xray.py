import datetime
import html
import json
import pathlib
import subprocess
import sys

root = pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0, str(root / "rules"))

import drawer  # noqa: E402

EVIDENCE = ["verified", "extracted", "derived", "master_data", "owner", "interpretation", "uncertain"]
EVIDENCE_LABEL = {
    "verified": "verified",
    "extracted": "extracted",
    "owner": "owner",
    "derived": "derived",
    "master_data": "master data",
    "interpretation": "interpretation",
    "uncertain": "uncertain",
}

SAMPLE = {"runner": "blum_movento_760h", "inside_width_mm": 562, "inside_depth_mm": 520, "side_thickness_mm": 12}

LIMITS = [
    ("Drawings", "The Blum drilling drawings were read as text only. Hole positions are not assigned to parts yet."),
    ("Licence", "Blum gives no terms of use for technical data. Vendor entries stay setup_only."),
    ("Approval", "No value is decided yet. Johannes confirms the studio values first."),
    ("Skill", "No skill package is built yet. This branch is preparatory work for the Fusion kitchen skill."),
]


def load_jsonl(pattern):
    items = []
    for path in sorted(root.glob(pattern)):
        for line in path.read_text(encoding="utf-8").splitlines():
            if line.strip():
                items.append(json.loads(line))
    return items


def load_json(pattern):
    return [json.loads(path.read_text(encoding="utf-8")) for path in sorted(root.glob(pattern))]


def commit():
    try:
        return subprocess.run(["git", "-C", str(root), "rev-parse", "--short", "HEAD"],
                              capture_output=True, text=True, check=True).stdout.strip()
    except (OSError, subprocess.CalledProcessError):
        return "uncommitted"


def count_tests():
    text = (root / "rules" / "test_drawer.py").read_text(encoding="utf-8")
    return text.count("    def test_")


def e(value):
    return html.escape(str(value), quote=True)


def chip(kind, value):
    return f'<span class="chip {kind}-{e(value)}">{e(EVIDENCE_LABEL.get(value, value))}</span>'


def bar(counts):
    total = sum(counts.values()) or 1
    parts = "".join(f'<i class="ev-{k}" style="width:{counts.get(k, 0) / total * 100:.1f}%"></i>'
                    for k in EVIDENCE if counts.get(k))
    return f'<div class="bar" role="img" aria-label="evidence share">{parts}</div>'


def evidence_counts(records, key="evidence"):
    counts = {}
    for record in records:
        value = record.get(key)
        if value:
            counts[value] = counts.get(value, 0) + 1
    return counts


def trace(sources_by_id):
    item = drawer.runner(SAMPLE["runner"])
    nominal = drawer.select_nominal_length(item.key, SAMPLE["inside_depth_mm"])
    parts = drawer.wooden_drawer(item.key, SAMPLE["inside_width_mm"], int(nominal.mm), SAMPLE["side_thickness_mm"])
    steps = [
        ("Read the carcass", f"Inside width {SAMPLE['inside_width_mm']} mm, inside depth {SAMPLE['inside_depth_mm']} mm, "
         f"drawer sides {SAMPLE['side_thickness_mm']} mm.", None, "input", "setups/SET-STUDIO-EXAMPLE.json"),
        ("Choose the nominal length", "Largest nominal length with nominal length + 3 mm inside the depth.",
         nominal, "ATM-DRW-0008", "rules/drawer.py:select_nominal_length"),
        ("Check the depth", "Depth requirement = nominal length + 3 mm.",
         parts["depth_requirement"], "ATM-DRW-0005", "rules/drawer.py:depth_requirement"),
        ("Drawer inside width", "Inside width of the carcass minus 42 mm, tolerance +0 / -1.5 mm.",
         parts["drawer_inside_width"], "ATM-DRW-0003", "rules/drawer.py:wooden_drawer"),
        ("Drawer length", "Nominal length minus 10 mm.",
         parts["drawer_length"], "ATM-DRW-0004", "rules/drawer.py:wooden_drawer"),
        ("Drawer outside width", "Drawer inside width plus two drawer sides.",
         parts["drawer_outside_width"], "own calculation", "rules/drawer.py:wooden_drawer"),
    ]
    rows = []
    for number, (title, text, value, atom, ref) in enumerate(steps, 1):
        value_html = f'<b class="mm">{value.mm:g}<small> mm</small></b>{chip("ev", value.evidence)}' if value else ""
        sources = ""
        if value:
            sources = " · ".join(f'<span title="{e(sources_by_id[s]["title"])}">{e(s)}</span>'
                                 for s in value.sources if s in sources_by_id)
        rows.append(f"""<li><span class="num">{number}</span><div class="step">
<div class="step-head"><h3>{e(title)}</h3>{value_html}</div>
<p>{e(text)}</p>
<div class="refs"><code>{e(ref)}</code><span>{e(atom)}</span>{f'<span>{sources}</span>' if sources else ''}</div>
</div></li>""")
    return item, "\n".join(rows)


def main():
    sources = load_jsonl("sources/*.jsonl")
    atoms = load_jsonl("atoms/*.jsonl")
    libraries = load_json("libraries/*/*.json")
    setups = load_json("setups/*.json")
    sources_by_id = {s["id"]: s for s in sources}
    setup_values = [v for s in setups for v in s["values"].values()]
    rule_functions = sum(1 for path in (root / "rules").glob("[!t]*.py")
                         for line in path.read_text(encoding="utf-8").splitlines() if line.startswith("def "))
    tests = count_tests()
    sha = commit()

    stats = [
        (len(sources), "sources"),
        (len(atoms), "atoms"),
        (len(libraries), "library entries"),
        (rule_functions, "rule functions"),
        (tests, "tests"),
        (len(setup_values), "setup values"),
    ]
    stats_html = "".join(f'<div class="stat"><b>{n}</b><span>{e(label)}</span></div>' for n, label in stats)

    trust_counts = {"original": 0, "third_party": 0, "studio": 0}
    for s in sources:
        trust_counts[s["trust"]] = trust_counts.get(s["trust"], 0) + 1
    layers = [
        ("Sources", "sources/", len(sources), f"{trust_counts['original']} original, {trust_counts['third_party']} third party", None),
        ("Atoms", "atoms/", len(atoms), "One checkable statement each", evidence_counts(atoms)),
        ("Libraries", "libraries/", len(libraries), "Hardware entries, setup_only", None),
        ("Rules", "rules/", rule_functions, f"Python functions, {tests} tests pass", None),
        ("Setups", "setups/", len(setup_values), "Studio values, waiting for approval", evidence_counts(setup_values)),
        ("Skills", "skills/", 0, "Generated from the layers above. Not built yet.", None),
    ]
    layer_html = "".join(f"""<div class="layer{' empty' if n == 0 else ''}">
<div class="layer-name"><h3>{e(name)}</h3><code>{e(folder)}</code></div>
<div class="layer-n">{n}</div>
<div class="layer-note"><span>{e(note)}</span>{bar(counts) if counts else ''}</div></div>""" for name, folder, n, note, counts in layers)

    runner_item, trace_html = trace(sources_by_id)

    atom_rows = "".join(f"""<tr><td><code>{e(a['id'])}</code></td><td>{e(a['statement'])}</td>
<td>{chip('ev', a['evidence'])}</td><td>{chip('st', a['status'])}</td>
<td class="srcs">{e(', '.join(s['id'].replace('SRC-', '') for s in a['sources']))}</td></tr>""" for a in atoms)

    open_items = [(a["id"], a["statement"]) for a in atoms if a["status"] == "open"]
    open_items += [(f"{s['id']} · {k}", v.get("note") or f"Value {v['value']} waits for approval.")
                   for s in setups for k, v in s["values"].items() if v["status"] == "open"]
    open_items += [(lib["id"], lib["note"]) for lib in libraries if lib.get("note")]
    open_html = "".join(f"<li><code>{e(i)}</code><span>{e(t)}</span></li>" for i, t in open_items)

    limits_html = "".join(f'<div class="limit"><h3>{e(t)}</h3><p>{e(x)}</p></div>' for t, x in LIMITS)

    legend = "".join(f'<span><i class="ev-{k}"></i>{e(EVIDENCE_LABEL[k])}</span>' for k in EVIDENCE)
    today = datetime.date.today().isoformat()

    page = TEMPLATE.format(
        sha=e(sha), today=e(today), stats=stats_html, layers=layer_html, legend=legend,
        runner=e(f"{runner_item.maker} {runner_item.series} {runner_item.model}"),
        trace=trace_html, atoms=atom_rows, open=open_html, limits=limits_html,
    )
    out = root / "build" / "xray.html"
    out.parent.mkdir(exist_ok=True)
    out.write_text(page, encoding="utf-8")
    print(f"Wrote {out.relative_to(root)} from commit {sha}.")


TEMPLATE = """<title>Kitchen Knowledge X-ray</title>
<meta name="claude:viewport-fit-sides" content="cover">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Geist:wght@400;500;600&family=Geist+Mono:wght@400;500&display=swap">
<style>
/* Layout: one reading column in ALFA_OS tokens; layers as a stack from source to skill, then one drawer traced through the rules. */
:root{{
  --ground:#ffffff;--lane:#ffffff;--well:#f5f5f5;--line:#e8e8e8;--line-strong:#d9d9d9;
  --ink:#171717;--ink-2:#4d4d4d;--ink-3:#6b6b6b;--inv:#171717;--on-inv:#ffffff;
  --signal:#b3412e;--coral:#f95c4b;--apricot:#f39f5a;--rose:#e8bcb9;
  --ev-verified:#171717;--ev-derived:#6b6b6b;--ev-master:#f39f5a;--ev-interp:#e8bcb9;--ev-uncertain:#f95c4b;
  --font:Geist,"SF Pro Text",system-ui,-apple-system,"Helvetica Neue",sans-serif;
  --mono:"Geist Mono","SF Mono",ui-monospace,Menlo,monospace;
}}
@media (prefers-color-scheme: dark){{:root:not([data-theme="light"]){{
  --ground:#0d0d0d;--lane:#141414;--well:#1f1f1f;--line:#2a2a2a;--line-strong:#3a3a3a;
  --ink:#fafafa;--ink-2:#d9d9d9;--ink-3:#a3a3a3;--inv:#2e2e2e;--on-inv:#fafafa;
  --signal:#e08a74;--ev-verified:#fafafa;--ev-derived:#8a8a8a;--ev-interp:#a8706c;color-scheme:dark}}}}
:root[data-theme="dark"]{{
  --ground:#0d0d0d;--lane:#141414;--well:#1f1f1f;--line:#2a2a2a;--line-strong:#3a3a3a;
  --ink:#fafafa;--ink-2:#d9d9d9;--ink-3:#a3a3a3;--inv:#2e2e2e;--on-inv:#fafafa;
  --signal:#e08a74;--ev-verified:#fafafa;--ev-derived:#8a8a8a;--ev-interp:#a8706c;color-scheme:dark}}
*{{box-sizing:border-box}}
body{{background:var(--ground);color:var(--ink);font:400 14px/1.55 var(--font);-webkit-font-smoothing:antialiased}}
main{{max-width:1040px;margin:0 auto;padding-block:48px 96px;padding-left:max(16px,env(safe-area-inset-left,0px));padding-right:max(16px,env(safe-area-inset-right,0px));display:grid;gap:64px}}
h1{{font-size:36px;line-height:1.1;font-weight:600;letter-spacing:-.02em;margin:0;text-wrap:balance}}
h2{{font-size:22px;line-height:1.25;font-weight:600;letter-spacing:-.02em;margin:0;text-wrap:balance}}
h3{{font-size:14px;font-weight:600;margin:0}}
p{{margin:0;color:var(--ink-2);max-width:68ch}}
code{{font-family:var(--mono);font-size:12px;color:var(--ink-2)}}
section{{display:grid;gap:16px}}
.kicker{{font-size:11.5px;font-weight:500;letter-spacing:.06em;text-transform:uppercase;color:var(--ink-3)}}
header{{display:grid;gap:14px}}
.lede{{font-size:16px}}
.stats{{display:grid;grid-template-columns:repeat(auto-fit,minmax(120px,1fr));gap:1px;background:var(--line);border:1px solid var(--line);border-radius:20px;overflow:hidden;margin-top:12px}}
.stat{{background:var(--lane);padding:14px 16px;display:grid;gap:2px}}
.stat b{{font-size:24px;font-weight:600;letter-spacing:-.02em;font-variant-numeric:tabular-nums}}
.stat span{{font-size:11.5px;color:var(--ink-3)}}
.stack{{display:grid;border:1px solid var(--line);border-radius:20px;overflow:hidden;background:var(--lane)}}
.layer{{display:grid;grid-template-columns:minmax(0,180px) 56px minmax(0,1fr);gap:16px;align-items:center;padding:14px 18px;border-top:1px solid var(--line)}}
.layer:first-child{{border-top:0}}
.layer.empty{{background:repeating-linear-gradient(135deg,transparent 0 8px,var(--well) 8px 9px)}}
.layer-name{{display:grid;gap:2px;min-width:0}}
.layer-n{{font-size:22px;font-weight:600;font-variant-numeric:tabular-nums;text-align:right}}
.layer-note{{display:grid;gap:6px;font-size:12.5px;color:var(--ink-2);min-width:0}}
.bar{{display:flex;height:6px;border-radius:3px;background:var(--well);overflow:hidden;max-width:320px}}
.bar i,.legend i{{display:block;height:100%}}
.ev-verified{{background:var(--ev-verified)}}.ev-derived{{background:var(--ev-derived)}}.ev-master_data{{background:var(--ev-master)}}
.ev-interpretation{{background:var(--ev-interp)}}.ev-uncertain{{background:var(--ev-uncertain)}}
.ev-extracted{{background:var(--ev-derived);opacity:.6}}.ev-owner{{background:var(--signal)}}
.legend{{display:flex;flex-wrap:wrap;gap:14px;font-size:11.5px;color:var(--ink-3)}}
.legend span{{display:inline-flex;align-items:center;gap:6px}}
.legend i{{width:14px;height:6px;border-radius:3px}}
.trace{{list-style:none;margin:0;padding:0;display:grid;gap:12px}}
.trace li{{display:grid;grid-template-columns:36px minmax(0,1fr);gap:14px;position:relative}}
.trace li:not(:last-child)::before{{content:"";position:absolute;left:17px;top:30px;bottom:-12px;border-left:2px solid var(--line-strong)}}
.num{{width:36px;height:28px;border-radius:14px;background:var(--inv);color:var(--on-inv);display:flex;align-items:center;justify-content:center;font-size:12px;font-weight:600}}
.step{{background:var(--lane);border:1px solid var(--line);border-radius:12px;padding:12px 14px;display:grid;gap:6px;min-width:0}}
.step-head{{display:flex;flex-wrap:wrap;align-items:baseline;gap:10px}}
.step-head h3{{flex:1 1 200px}}
.mm{{font-family:var(--mono);font-size:18px;font-weight:500;font-variant-numeric:tabular-nums}}
.mm small{{font-size:11px;color:var(--ink-3)}}
.refs{{display:flex;flex-wrap:wrap;gap:6px 14px;font-size:11.5px;color:var(--ink-3)}}
.chip{{font-size:11px;font-weight:500;border-radius:999px;padding:1px 8px;border:1px solid var(--line-strong);color:var(--ink-2);white-space:nowrap}}
.chip.ev-verified,.chip.ev-derived,.chip.ev-master_data,.chip.ev-interpretation,.chip.ev-uncertain{{background:transparent}}
.chip.ev-verified{{border-color:var(--ink)}}.chip.ev-uncertain{{border-color:var(--coral);color:var(--signal)}}
.chip.ev-master_data{{border-color:var(--apricot)}}.chip.ev-interpretation{{border-style:dashed}}
.chip.st-open{{border-color:var(--coral);color:var(--signal)}}.chip.st-decided{{background:var(--inv);color:var(--on-inv);border-color:var(--inv)}}
.table{{overflow-x:auto;border:1px solid var(--line);border-radius:12px;background:var(--lane)}}
table{{border-collapse:collapse;width:100%;min-width:640px;font-size:12.5px}}
th{{text-align:left;font-weight:500;color:var(--ink-3);font-size:11.5px;letter-spacing:.04em;text-transform:uppercase}}
th,td{{padding:9px 12px;border-top:1px solid var(--line);vertical-align:top}}
thead th{{border-top:0}}
td:nth-child(2){{color:var(--ink-2);max-width:52ch}}
td.srcs{{font-family:var(--mono);font-size:11px;color:var(--ink-3)}}
.open{{list-style:none;margin:0;padding:0;display:grid;border:1px solid var(--line);border-radius:12px;background:var(--lane)}}
.open li{{display:grid;grid-template-columns:minmax(0,260px) minmax(0,1fr);gap:12px;padding:10px 14px;border-top:1px solid var(--line);font-size:12.5px;color:var(--ink-2)}}
.open li:first-child{{border-top:0}}
.limits{{display:grid;grid-template-columns:repeat(auto-fit,minmax(220px,1fr));gap:12px}}
.limit{{border:1px solid var(--line);border-radius:12px;padding:14px;display:grid;gap:4px;align-content:start}}
.limit p{{font-size:12.5px}}
footer{{font-size:12px;color:var(--ink-3);border-top:1px solid var(--line);padding-top:14px}}
@media (max-width:640px){{h1{{font-size:28px}}.layer{{grid-template-columns:minmax(0,1fr) 48px}}.layer-note{{grid-column:1 / -1}}.open li{{grid-template-columns:1fr}}}}
</style>
<main>
<header>
<div class="kicker">X-ray · branch knowledge @ {sha} · built {today}</div>
<h1>Kitchen knowledge under the hood</h1>
<p class="lede">What the kitchen CAD session knows, where each value comes from, and how sure it is. Every number on this page is read from the files of the branch, and the drawer below is calculated by the real rules.</p>
<div class="stats">{stats}</div>
</header>

<section>
<div class="kicker">1 · Layers</div>
<h2>From the source document to the skill</h2>
<p>Each layer reads only the layer above it. The bars show the share of each evidence level.</p>
<div class="stack">{layers}</div>
<div class="legend">{legend}</div>
</section>

<section>
<div class="kicker">2 · One drawer, calculated</div>
<h2>A standard base cabinet with a {runner} runner</h2>
<p>The steps run the functions in <code>rules/drawer.py</code> on sample values. Each result names its rule, its atom and its sources.</p>
<ol class="trace">{trace}</ol>
</section>

<section>
<div class="kicker">3 · Atoms</div>
<h2>Every statement with its evidence and status</h2>
<div class="table"><table><thead><tr><th>Id</th><th>Statement</th><th>Evidence</th><th>Status</th><th>Sources</th></tr></thead><tbody>{atoms}</tbody></table></div>
</section>

<section>
<div class="kicker">4 · Open</div>
<h2>What waits for a check or a decision</h2>
<ul class="open">{open}</ul>
</section>

<section>
<div class="kicker">5 · Limits</div>
<h2>What this page cannot show yet</h2>
<div class="limits">{limits}</div>
</section>

<footer>Generated by <code>tools/build_xray.py</code> from the branch <code>knowledge</code> of ALFA_OS. Strand: <code>S-kitchen-knowledge</code> in ALFA-Knowledge. Do not edit this page by hand.</footer>
</main>
"""


if __name__ == "__main__":
    main()
