import { readFileSync, writeFileSync } from "node:fs";
import * as k from "/Users/johannesleoberger/.claude/skills/anatomy/kit/iso-kit.mjs";
import * as G from "/Users/johannesleoberger/.claude/skills/anatomy/kit/lathe.mjs";
import * as A from "/Users/johannesleoberger/.claude/skills/anatomy/kit/audit.mjs";
import { tubePieces, tubeSvg } from "/Users/johannesleoberger/.claude/skills/anatomy/kit/tube.mjs";

const arg = (name) => { const i = process.argv.indexOf(name); return i > 0 ? process.argv[i + 1] : undefined; };
const MODEL = JSON.parse(readFileSync(arg("--model"), "utf8"));
const OUT = arg("--out");
const META = MODEL.meta;
const DRAW_CODE = 8, DRAW_BRIDGE = 5;

const WIDTH = 820, HEIGHT = 560;
const COL = 104, ROW = 94;

const code = MODEL.code.map((m) => ({ ...m, side: "code" }));
const rows = new Map();
const rowOf = (m) => m.kind === "integration" ? 100 : m.kind === "view" ? 50 : m.depth;
for (const m of code) { const r = rowOf(m); if (!rows.has(r)) rows.set(r, []); rows.get(r).push(m); }
for (const [r, list] of [...rows]) if (list.length > 3 && r === 100) { rows.set(100, list.slice(0, 3)); rows.set(101, list.slice(3)); }
const depths = [...rows.keys()].sort((a, b) => a - b);
const placed = new Map();
const depths2 = [...rows.keys()].sort((a, b) => a - b);
for (const d of depths2) {
  const list = rows.get(d);
  const bary = (m) => { const xs = m.deps.map((n) => placed.get(n)).filter((v) => v !== undefined); return xs.length ? xs.reduce((s, v) => s + v, 0) / xs.length : 0; };
  list.sort((a, b) => bary(a) - bary(b) || a.name.localeCompare(b.name));
  list.forEach((m, i) => { m.cx = (i - (list.length - 1) / 2) * COL; m.row = depths.indexOf(d); placed.set(m.name, m.cx); });
}
for (const m of code) {
  m.cy = m.row * ROW;
  const w = Math.round(44 + Math.sqrt(m.types) * 2.8), dd = Math.round(w * 0.84);
  m.plan = { x: m.cx - w / 2, y: m.cy - dd / 2, w, d: dd, r: 4 };
  m.h = Math.round(14 + m.types * 0.3);
}
const codeBox = { x0: Math.min(...code.map((m) => m.plan.x)) - 22, x1: Math.max(...code.map((m) => m.plan.x + m.plan.w)) + 22, y0: Math.min(...code.map((m) => m.plan.y)) - 22, y1: Math.max(...code.map((m) => m.plan.y + m.plan.d)) + 30 };
const CODE_PLATE = { x: codeBox.x0, y: codeBox.y0, w: codeBox.x1 - codeBox.x0, d: codeBox.y1 - codeBox.y0, r: 10 };

const entriesOf = (d) => Object.values(d.entries).reduce((s, v) => s + v, 0);
const design = MODEL.design.filter((d) => d.source === "E2" || entriesOf(d) > 0 || /^ALFA /.test(d.name)).map((d) => ({ ...d, side: "design", total: entriesOf(d) }));
design.sort((a, b) => (a.source === "E2") - (b.source === "E2") || b.total - a.total || a.name.localeCompare(b.name));
const DCOLS = 3, DCOL = 74, DROW = 66;
const dx0 = CODE_PLATE.x - 40 - DCOLS * DCOL;
design.forEach((d, i) => {
  d.cx = dx0 + (i % DCOLS) * DCOL + DCOL / 2;
  d.cy = CODE_PLATE.y + 26 + Math.floor(i / DCOLS) * DROW;
  d.plan = { x: d.cx - 28, y: d.cy - 22, w: 56, d: 44, r: 3 };
  d.h = d.source === "E2" ? 7 : Math.round(7 + d.total * 0.1);
});
const dBox = { x0: Math.min(...design.map((m) => m.plan.x)) - 16, x1: Math.max(...design.map((m) => m.plan.x + m.plan.w)) + 16, y0: Math.min(...design.map((m) => m.plan.y)) - 16, y1: Math.max(...design.map((m) => m.plan.y + m.plan.d)) + 26 };
const DESIGN_PLATE = { x: dBox.x0, y: dBox.y0, w: dBox.x1 - dBox.x0, d: dBox.y1 - dBox.y0, r: 8 };
const ALL = [...code, ...design];
for (const m of ALL) { m.top = 5 + m.h; m.label = m.side === "design" ? m.name.replace(/^ALFA /, "") : m.name; }
const byName = Object.fromEntries(ALL.map((m) => [`${m.side}:${m.name}`, m]));

const links = new Map();
for (const l of MODEL.codeLinks) {
  const key = [l.von, l.an].sort().join("|");
  const e = links.get(key) ?? { kind: "code", a: `code:${[l.von, l.an].sort()[0]}`, b: `code:${[l.von, l.an].sort()[1]}`, n: 0, dir: {}, ex: [] };
  e.n += l.n; e.dir[`${l.von}>${l.an}`] = l.n; e.ex.push(...l.ex.map((x) => ({ ...x, from: l.von, to: l.an })));
  links.set(key, e);
}
for (const b of MODEL.bridges) links.set(`d|${b.von}|${b.an}`, { kind: "bridge", a: `design:${b.von}`, b: `code:${b.an}`, n: b.n, kinds: b.kinds, dir: {}, ex: b.ex });
const LINKS = [...links.values()].filter((l) => byName[l.a] && byName[l.b]).sort((x, y) => y.n - x.n);
LINKS.forEach((l, i) => { l.id = `c${i}`; l.drawn = l.n >= (l.kind === "code" ? DRAW_CODE : DRAW_BRIDGE); l.r = 0.5 + Math.sqrt(l.n) * 0.17; });
const DRAWN = LINKS.filter((l) => l.drawn);

const BOSS_H = 2.4;
for (const m of ALL) {
  const key = `${m.side}:${m.name}`;
  const own = DRAWN.filter((l) => l.a === key || l.b === key);
  const angle = (l) => { const o = byName[l.a === key ? l.b : l.a]; return Math.atan2(o.cy - m.cy, o.cx - m.cx); };
  own.sort((x, y) => angle(x) - angle(y));
  own.forEach((l, i) => {
    const a = angle(l), lane = (i % 3) * 6;
    const reach = Math.max(4, Math.min(m.plan.w, m.plan.d) / 2 - 7 - lane);
    l.ports = l.ports ?? {};
    l.ports[key] = [m.cx + Math.cos(a) * reach, m.cy + Math.sin(a) * reach];
  });
  for (let it = 0; it < 30; it++) for (let i = 0; i < own.length; i++) for (let j = i + 1; j < own.length; j++) {
    const p = own[i].ports[key], q = own[j].ports[key];
    const need = own[i].r + own[j].r + 3.6, d = Math.hypot(p[0] - q[0], p[1] - q[1]);
    if (d < need) { const ux = (q[0] - p[0]) / (d || 1), uy = (q[1] - p[1]) / (d || 1), push = (need - d) / 2; p[0] -= ux * push; p[1] -= uy * push; q[0] += ux * push; q[1] += uy * push; }
  }
  for (const l of own) { const p = l.ports[key]; p[0] = Math.max(m.plan.x + 4, Math.min(m.plan.x + m.plan.w - 4, p[0])); p[1] = Math.max(m.plan.y + 4, Math.min(m.plan.y + m.plan.d - 4, p[1])); }
}

const tallest = Math.max(...ALL.map((m) => m.top));
const P = k.fitProjection(
  [...k.boxCorners(CODE_PLATE, -18, 0), ...k.boxCorners(DESIGN_PLATE, -18, 0), ...k.boxCorners(CODE_PLATE, 0, tallest + 46), ...k.boxCorners(DESIGN_PLATE, 0, tallest + 46)],
  WIDTH, HEIGHT, { pad: 22, azimuth: 38, elevation: 38 },
);
const at = (p) => k.iso(p, P);
const S = (paths, style) => k.solidSvg(paths, style);
const L = (d, style) => k.lineSvg(d, style);
const D = (points, style) => k.dotsSvg(points, style);
const V = G.viewOf(P);
const depthOf = (p) => G.dot3(p, V);
const byDepth = (points) => [...points].sort((a, b) => depthOf([a[0], a[1], 0]) - depthOf([b[0], b[1], 0]));
const R = A.recorder(P);

function plate(plan, name, ruler) {
  const out = [`<path class="iso-halo" d="${k.haloOf(plan, -18, 12, P)}"/>`];
  for (const [x, y] of byDepth(k.corners(plan, 18))) {
    out.push(S(k.cylinder(x, y, 6, -18, 1.6, P, 26), { tone: "lo" }));
    out.push(S(k.cylinder(x, y, 4.6, -16.4, 4.4, P, 26), { tone: "mid" }));
  }
  out.push(S(k.slabOf(plan, -12, 12, P, 8, 1.6), { tone: "mid" }));
  out.push(L(k.planOutline(k.insetPlan(plan, 5), 0, P), { tone: "lo" }));
  const screws = k.corners(plan, 10);
  out.push(L(screws.map(([x, y]) => k.ring(x, y, 2.2, 0, P, 16)).join(""), { tone: "lo" }));
  out.push(D(screws.map(([x, y]) => at([x, y, 0])), { size: 0.5 }));
  if (ruler) {
    const strip = { x: plan.x + 20, y: plan.y + plan.d - 13, w: plan.w - 40, d: 6, r: 1 };
    out.push(S(k.slabOf(strip, 0, 0.6, P, 3), { tone: "lo", crease: "none" }));
    const t = k.topTicks(strip.x + 4, strip.x + strip.w - 4, 4, 5, strip.y + 0.8, 0.6, [1.8, 3.2], P);
    out.push(L(t.minor, { tone: "lo" }), L(t.major, { tone: "mid" }));
  }
  out.push(k.faceTextSvg(k.sideMatrix([plan.x + plan.w / 2, plan.y + plan.d], -8, P, "left"), name, { size: 5.4, tone: "mid", anchor: "middle" }));
  R.solid(A.slab(plan, -12, 12, { name: "stand." + name, ground: true }));
  return out.join("");
}

function moduleSvg(m) {
  const out = [], { plan } = m, top = m.top, key = `${m.side}:${m.name}`, draft = m.source === "E2";
  out.push(`<path class="iso-halo" d="${k.haloOf(k.insetPlan(plan, 2), 0, 0.1, P)}" style="filter:blur(3px)"/>`);
  out.push(S(k.slabOf(k.insetPlan(plan, -2), 0, 5, P, 4, 0.5), { tone: "mid" }));
  const bodyH = Math.max(1, m.h - 3.5);
  const bands = m.side === "design" && !draft ? Math.min(5, Math.floor(m.h / 7)) : (m.h > 26 ? 2 : 0);
  const seams = Array.from({ length: bands }, (_, i) => k.sideSeam(plan, 5 + (bodyH * (i + 1)) / (bands + 1), P, 6)).join("");
  out.push(S(k.slabOf(plan, 5, bodyH, P, 6, 0.6), { tone: draft ? "mid" : "hi", crease: "lo", inner: seams ? L(seams, { tone: "faint" }) : "" }));
  const lid = k.insetPlan(plan, 1.2);
  out.push(S(k.slabOf(lid, top - 3.5, 3.5, P, 6, 0.8), { tone: draft ? "mid" : "hi", crease: "lo" }));
  out.push(L(k.planOutline(k.insetPlan(lid, 3.5), top, P, 6), { tone: "faint" }));
  const screws = k.corners(lid, 4.5);
  out.push(L(screws.map(([x, y]) => k.ring(x, y, 1.4, top, P, 12)).join(""), { tone: "lo" }));
  out.push(D(screws.map(([x, y]) => at([x, y, top])), { size: 0.42 }));
  const yF = plan.y + plan.d, x0 = plan.x + 5, x1 = plan.x + plan.w - 5;
  if (m.h >= 14) {
    const size = Math.min(6, (x1 - x0 - 6) / (m.label.length * 0.62));
    const zf = Math.min(15, m.h - 4);
    out.push(L(k.pathOf([[x0, yF, zf - size * 1.05], [x1, yF, zf - size * 1.05], [x1, yF, zf + size * 0.5], [x0, yF, zf + size * 0.5]].map(at), true), { tone: "lo" }));
    out.push(k.faceTextSvg(k.sideMatrix([(x0 + x1) / 2, yF], zf - size * 0.62, P, "left"), m.label, { size, tone: "hi", anchor: "middle" }));
  } else {
    const size = Math.min(5, (plan.w - 12) / (m.label.length * 0.62));
    out.push(k.faceTextSvg(k.topMatrix([m.cx, plan.y + plan.d - 8], top, P, "x"), m.label, { size, tone: draft ? "mid" : "hi", anchor: "middle" }));
  }
  const led = [plan.x + plan.w - 8, plan.y + 8];
  out.push(S(k.cylinder(led[0], led[1], 1.9, top, 1.2, P, 16), { tone: "mid" }));
  out.push(`<path class="led" d="${k.ring(led[0], led[1], 1, top + 1.2, P, 12)}"/>`);
  for (const l of DRAWN) if (l.ports?.[key]) {
    const [x, y] = l.ports[key];
    out.push(`<g class="boss" data-link="${l.id}">${S(k.cylinder(x, y, l.r + 1.1, top, BOSS_H, P, 18), { tone: "mid" })}${L(k.ring(x, y, l.r + 0.15, top + BOSS_H, P, 18), { tone: "lo" })}</g>`);
  }
  return out.join("");
}

for (const m of ALL) {
  const key = `${m.side}:${m.name}`;
  const shapes = [A.slab(k.insetPlan(m.plan, -2), 0, 5, { name: key + ".skirt" }), A.slab(m.plan, 5, Math.max(1, m.h - 3.5), { name: key + ".body" }), A.slab(k.insetPlan(m.plan, 1.2), m.top - 3.5, 3.5, { name: key + ".lid" })];
  for (const l of DRAWN) if (l.ports?.[key]) { const [x, y] = l.ports[key]; shapes.push(A.cylinder(x, y, l.r + 1.1, m.top, BOSS_H, { name: key + ".port." + l.id })); }
  R.put({ at: [m.cx, m.cy, m.h / 2], svg: `<g class="mod" data-mod="${key}" data-side="${m.side}" tabindex="0" role="button" aria-label="${m.label}">${moduleSvg(m)}</g>`, shapes: shapes.map((s) => R.solid(s)) });
}
DRAWN.forEach((l, index) => {
  const ma = byName[l.a], mb = byName[l.b], pa = l.ports[l.a], pb = l.ports[l.b];
  const za = ma.top + BOSS_H, zb = mb.top + BOSS_H;
  const span = Math.hypot(pb[0] - pa[0], pb[1] - pa[1]);
  const lift = 12 + span * 0.18 + (index % 5) * 2.5;
  const c1 = [pa[0], pa[1], za + lift], c2 = [pb[0], pb[1], zb + lift];
  const route = Array.from({ length: 40 }, (_, i) => { const t = i / 39, u = 1 - t; return [0, 1, 2].map((j) => u * u * u * [pa[0], pa[1], za][j] + 3 * u * u * t * c1[j] + 3 * u * t * t * c2[j] + t * t * t * [pb[0], pb[1], zb][j]); });
  const rings = l.kind === "bridge" ? { pitch: 4.2, twist: 1.4, fade: [0.15, 0.6] } : null;
  const pieces = tubePieces(route, l.r, P, { maxLength: 26, rings });
  let walked = 0;
  for (const piece of pieces) {
    const flat = piece.points.map(at);
    const len = flat.reduce((s, p, j) => (j ? s + Math.hypot(p[0] - flat[j - 1][0], p[1] - flat[j - 1][1]) : 0), 0);
    R.put({ at: piece.mid, svg: `<g class="cab" data-link="${l.id}" data-kind="${l.kind}">${tubeSvg(piece, { tone: l.kind === "bridge" ? "mid" : "hi" })}<path class="pulse" data-off="${walked.toFixed(1)}" d="${k.pathOf(flat)}"/></g>`, route: l.id, shapes: [] });
    walked += len;
  }
  R.route(`cable.${l.id}`, G.resample(route, 1.2), l.r, { limp: true });
});
A.settle(R, P);
R.items.sort((a, b) => a.key - b.key);

const svg = k.figureSvg({
  width: WIDTH, height: HEIGHT,
  label: `ALFA OS als Werkbank aus zwei Platten. Rechts der Code: ${code.length} Module aus Package.swift und App, Höhe nach Typen, Reihen nach Abhängigkeitstiefe. Links das Design: die Bögen und der Vertrag. Glatte Leitungen sind Code-Verbindungen, umflochtene Leitungen sind Vertragseinträge des Designs, die im Code ankommen.`,
  body: [plate(CODE_PLATE, "Code · main", true), plate(DESIGN_PLATE, "Design · Etappe I und II", false), ...R.items.map((i) => i.svg)],
});

const DATA = {
  meta: META,
  modules: ALL.map((m) => ({ key: `${m.side}:${m.name}`, name: m.name, label: m.label, side: m.side, kind: m.kind ?? (m.source === "E2" ? "entwurf" : "bogen"), types: m.types, paths: m.paths, deps: m.deps, depth: m.depth, source: m.source, lines: m.lines, entries: m.entries, unused: m.unused, unusedEx: m.unusedEx })),
  links: LINKS.map((l) => ({ id: l.id, kind: l.kind, a: l.a, b: l.b, n: l.n, dir: l.dir, kinds: l.kinds, drawn: l.drawn, ex: l.ex.slice(0, 14) })),
  textMatch: MODEL.textMatch, unplaced: MODEL.unplaced, entriesTotal: MODEL.entriesTotal,
};
const live = readFileSync(new URL("./live.js", import.meta.url), "utf8");
const css = readFileSync(new URL("./page.css", import.meta.url), "utf8");
const codeSum = LINKS.filter((l) => l.kind === "code").reduce((s, l) => s + l.n, 0);
const bridgeSum = LINKS.filter((l) => l.kind === "bridge").reduce((s, l) => s + l.n, 0);
const typesTotal = code.reduce((s, m) => s + m.types, 0);
const tm = MODEL.textMatch || {};
const html = `<title>ALFA Schaltschrank</title>
<meta name="claude:viewport-fit-sides" content="cover">
<style>${k.ISO_CSS}${css}</style>
<main class="iso page" id="root">
  <header class="head">
    <p class="eyebrow">ALFA OS · Code und Design</p>
    <h1>Wer im Code wen braucht und was vom Design ankommt</h1>
    <p class="lede">Rechts der Code: jedes Modul aus <code>Package.swift</code> und <code>App/</code>, so hoch wie es Typen hat, hinten die Grundlagen, vorne was auf ihnen aufbaut. Links das Design: die Bögen und der Vertrag. Glatte Leitungen verbinden Code-Module, umflochtene Leitungen führen Texte, Tokens und Bauteile des Vertrags dorthin, wo sie im Code ankommen.</p>
  </header>
  <figure class="iso-plate card">
    <div class="corner tl">Fig 1</div><div class="corner tr">Werkbank ALFA</div>
    <div class="iso-stage" tabindex="0" aria-label="Werkbank: Modul oder Leitung anklicken">${svg}</div>
    <div class="corner bl">Modul oder Leitung anklicken · Pfeiltasten wechseln</div>
    <div class="corner br" data-readout>${code.length} Code-Module · ${design.length} Design-Teile</div>
  </figure>
  <section class="stats">
    <div><b>${typesTotal}</b><span>Swift-Typen in ${code.length} Modulen</span></div>
    <div><b>${codeSum}</b><span>Typ-Paare über Modulgrenzen</span></div>
    <div><b>${bridgeSum}</b><span>Vertragseinträge im Code gefunden</span></div>
    <div><b>${MODEL.entriesTotal}</b><span>Einträge im Vertrag</span></div>
  </section>
  <section class="detail" aria-live="polite">
    <div class="detail-head"><h2 id="d-title"></h2><p id="d-sub"></p></div>
    <div id="d-body"></div>
  </section>
  <footer class="foot">
    <p>Stand: <code>main</code> @ <code>${META.sha.slice(0, 8)}</code> vom ${META.commitDate}; Design: <code>DESIGNCHANNEL</code> @ <code>${(META.designSha || "").slice(0, 8)}</code>. Gemessen ${META.measured}. Neu gemessen nach jedem Commit auf <code>main</code>.</p>
    <p class="muted">So wird gemessen: Typen und ihre Verbindungen liest graphify aus dem Swift-Code, ohne Sprachmodell. Module kommen aus den Zielen in <code>Package.swift</code>; ein Ordner <code>App/X</code> gehört zum Modul X, sonst ist er ein eigenes Ansichts-Modul. Ein Vertragstext gilt als angekommen, wenn sein Schlüssel oder sein deutscher Wortlaut im Code-Katalog steht und der Schlüssel im Swift-Code wörtlich vorkommt (${tm["Schlüssel"] || 0} per Schlüssel, ${tm["Wortlaut"] || 0} per Wortlaut, ${tm["fehlt im Katalog"] || 0} nicht im Katalog). Ein Bauteil, wenn es einen Swift-Typ gleichen Namens gibt. Ein Token, wenn sein Name als <code>Tokens.…</code>, <code>Colors.…</code> oder ähnlich im Code steht. Zur Laufzeit zusammengesetzte Schlüssel findet die Messung nicht; „nicht gefunden“ heißt deshalb nicht sicher „unbenutzt“. Die Werkstatt-Entwürfe der Etappe II haben keinen Vertrag und darum keine Leitung.</p>
  </footer>
</main>
<script>const DATA = ${JSON.stringify(DATA)};
${live}</script>`;
writeFileSync(OUT, html);
console.log("wrote", OUT, (html.length / 1024).toFixed(0), "KB", "items", R.items.length, "drawn", DRAWN.length, "of", LINKS.length);
