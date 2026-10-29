import { readFileSync, writeFileSync } from "node:fs";
import * as k from "/Users/johannesleoberger/.claude/skills/anatomy/kit/iso-kit.mjs";
import * as G from "/Users/johannesleoberger/.claude/skills/anatomy/kit/lathe.mjs";
import * as A from "/Users/johannesleoberger/.claude/skills/anatomy/kit/audit.mjs";
import { tubePieces, tubeSvg } from "/Users/johannesleoberger/.claude/skills/anatomy/kit/tube.mjs";

const arg = (name, fallback) => { const i = process.argv.indexOf(name); return i > 0 ? process.argv[i + 1] : fallback; };
const PAIRS = JSON.parse(readFileSync(arg("--pairs"), "utf8"));
const META = JSON.parse(readFileSync(arg("--meta"), "utf8"));
const OUT = arg("--out");

const WIDTH = 760;
const HEIGHT = 500;
const CELL = 132;
const FOOT = { w: 78, d: 66 };
const MODULES = [
  { name: "Einstellungen", at: [0, 0] },
  { name: "Grundlage", at: [1, 0] },
  { name: "Hülle", at: [2, 0] },
  { name: "Hub", at: [0, 1] },
  { name: "Mail", at: [1, 1] },
  { name: "Assistent", at: [2, 1] },
  { name: "Kalkulation", at: [0, 2] },
  { name: "Dienste", at: [1, 2] },
];
const ISLAND = { name: "Design-Skripte", center: [CELL * 2 + 10, CELL * 2 + 6] };
const typesOf = (name) => META.types[name] ?? 0;
const heightOf = (name) => Math.round(16 + typesOf(name) * 0.27);

for (const m of MODULES) {
  m.center = [(m.at[0] - 1) * CELL, (m.at[1] - 1) * CELL];
  m.plan = { x: m.center[0] - FOOT.w / 2, y: m.center[1] - FOOT.d / 2, w: FOOT.w, d: FOOT.d, r: 4 };
  m.h = heightOf(m.name);
  m.top = 6 + m.h;
}
ISLAND.plan = { x: ISLAND.center[0] - 30, y: ISLAND.center[1] - 26, w: 60, d: 52, r: 4 };
ISLAND.h = heightOf("Design-Skripte");
ISLAND.top = 6 + ISLAND.h;
const byName = Object.fromEntries(MODULES.map((m) => [m.name, m]));

const PLATE = { x: -CELL * 1.5 - 4, y: -CELL * 1.5 - 4, w: CELL * 3 + 8, d: CELL * 3 + 8, r: 10 };
const SIDE = { x: ISLAND.plan.x - 12, y: ISLAND.plan.y - 12, w: ISLAND.plan.w + 24, d: ISLAND.plan.d + 24, r: 6 };

const links = new Map();
for (const p of PAIRS) {
  if (!byName[p.von] || !byName[p.an]) continue;
  const key = [p.von, p.an].sort().join("|");
  const link = links.get(key) ?? { a: [p.von, p.an].sort()[0], b: [p.von, p.an].sort()[1], n: 0, dir: {}, examples: [] };
  link.n += p.n;
  link.dir[`${p.von}>${p.an}`] = p.n;
  link.examples.push(...p.bsp.map((b) => ({ ...b, von: b.von, an: b.an, from: p.von, to: p.an })));
  links.set(key, link);
}
const LINKS = [...links.values()].sort((x, y) => y.n - x.n);
LINKS.forEach((l, i) => { l.id = `c${i}`; l.r = 0.6 + Math.sqrt(l.n) * 0.2; l.examples.sort((x, y) => y.w - x.w); l.examples = l.examples.slice(0, 14); });

const tallest = Math.max(...MODULES.map((m) => m.top));
LINKS.forEach((l, i) => { l.cruise = tallest + 16 + (i % 8) * 5.5 + Math.floor(i / 8) * 1.8; });

const portsOf = new Map(MODULES.map((m) => [m.name, []]));
for (const l of LINKS) { portsOf.get(l.a).push(l); portsOf.get(l.b).push(l); }
for (const m of MODULES) {
  const list = portsOf.get(m.name);
  const angle = (l) => { const o = byName[l.a === m.name ? l.b : l.a]; return Math.atan2(o.center[1] - m.center[1], o.center[0] - m.center[0]); };
  list.sort((x, y) => angle(x) - angle(y));
  const n = list.length;
  list.forEach((l, i) => {
    const a = angle(l);
    const lane = (i % 2) * 7;
    const reach = Math.min(FOOT.w, FOOT.d) / 2 - 9 - lane;
    const spread = (i - (n - 1) / 2) * 0;
    const p = [m.center[0] + Math.cos(a + spread) * reach, m.center[1] + Math.sin(a + spread) * reach];
    l.ports = l.ports ?? {};
    l.ports[m.name] = p;
  });
}
const BOSS_H = 2.6;
for (const m of MODULES) {
  const list = portsOf.get(m.name);
  for (let i = 0; i < list.length; i++) for (let j = i + 1; j < list.length; j++) {
    const p = list[i].ports[m.name], q = list[j].ports[m.name];
    const need = list[i].r + list[j].r + 4.4;
    const d = Math.hypot(p[0] - q[0], p[1] - q[1]);
    if (d < need) {
      const ux = (q[0] - p[0]) / (d || 1), uy = (q[1] - p[1]) / (d || 1), push = (need - d) / 2;
      p[0] -= ux * push; p[1] -= uy * push; q[0] += ux * push; q[1] += uy * push;
    }
  }
}

const P = k.fitProjection(
  [...k.boxCorners(PLATE, -18, 0), ...k.boxCorners(SIDE, -18, 0), [0, 0, tallest + 60], ...k.boxCorners(PLATE, 0, tallest + 30)],
  WIDTH, HEIGHT, { pad: 26, azimuth: 40, elevation: 36 },
);
const at = (p) => k.iso(p, P);
const S = (paths, style) => k.solidSvg(paths, style);
const L = (d, style) => k.lineSvg(d, style);
const D = (points, style) => k.dotsSvg(points, style);
const V = G.viewOf(P);
const depth = (p) => G.dot3(p, V);
const byDepth = (points) => [...points].sort((a, b) => depth([a[0], a[1], 0]) - depth([b[0], b[1], 0]));

const R = A.recorder(P);
const put = (item) => R.put(item);

function base() {
  const out = [];
  for (const [plan, name] of [[PLATE, "stand.plate"], [SIDE, "stand.side"]]) {
    out.push(`<path class="iso-halo" d="${k.haloOf(plan, -18, 12, P)}"/>`);
    for (const [x, y] of byDepth(k.corners(plan, plan === PLATE ? 26 : 14))) {
      out.push(S(k.cylinder(x, y, 7, -18, 1.6, P, 28), { tone: "lo" }));
      out.push(S(k.cylinder(x, y, 5.4, -16.4, 4.4, P, 28), { tone: "mid" }));
    }
    out.push(S(k.slabOf(plan, -12, 12, P, 8, 1.6), { tone: "mid" }));
    out.push(L(k.planOutline(k.insetPlan(plan, 5), 0, P), { tone: "lo" }));
    const screws = k.corners(plan, 11);
    out.push(L(screws.map(([x, y]) => k.ring(x, y, 2.4, 0, P, 16)).join(""), { tone: "lo" }));
    out.push(D(screws.map(([x, y]) => at([x, y, 0])), { size: 0.5 }));
    R.solid(A.slab(plan, -12, 12, { name, ground: true }));
  }
  for (let i = 1; i < 3; i++) {
    const g = PLATE.x + 4 + i * CELL;
    out.push(L(k.lineOnTop([g, PLATE.y + 5], [g, PLATE.y + PLATE.d - 5], 0, P), { tone: "faint" }));
    const h = PLATE.y + 4 + i * CELL;
    out.push(L(k.lineOnTop([PLATE.x + 5, h], [PLATE.x + PLATE.w - 5, h], 0, P), { tone: "faint" }));
  }
  const strip = { x: PLATE.x + 24, y: PLATE.y + PLATE.d - 15, w: PLATE.w - 48, d: 7, r: 1 };
  out.push(S(k.slabOf(strip, 0, 0.6, P, 3), { tone: "lo", crease: "none" }));
  const ticks = k.topTicks(strip.x + 4, strip.x + strip.w - 4, 4, 5, strip.y + 0.8, 0.6, [2, 3.6], P);
  out.push(L(ticks.minor, { tone: "lo" }), L(ticks.major, { tone: "mid" }));
  out.push(D([at([strip.x + 2, strip.y + 3.5, 0.6]), at([strip.x + strip.w - 2, strip.y + 3.5, 0.6])], { size: 0.45 }));
  const label = { x: PLATE.x + PLATE.w - 70, y: PLATE.y + 10, w: 52, d: 16, r: 1.5 };
  out.push(S(k.slabOf(label, 0, 0.8, P, 4), { tone: "lo", crease: "none" }));
  out.push(L(k.planOutline(k.insetPlan(label, 1.6), 0.8, P), { tone: "faint" }));
  [[34], [26], [18]].forEach(([len], i) => out.push(L(k.lineOnTop([label.x + 6, label.y + 5 + i * 3], [label.x + 6 + len, label.y + 5 + i * 3], 0.8, P), { tone: "lo", free: true })));
  return out.join("");
}

function moduleSvg(m, { island = false } = {}) {
  const out = [];
  const { plan } = m;
  const top = m.top;
  out.push(`<path class="iso-halo" d="${k.haloOf(k.insetPlan(plan, 2), 0, 0.1, P)}" style="filter:blur(3px)"/>`);
  const skirt = k.insetPlan(plan, -2);
  out.push(S(k.slabOf(skirt, 0, 6, P, 4, 0.5), { tone: "mid" }));
  const body = k.slabOf(plan, 6, m.h - 4, P, 6, 0.6);
  const seams = [0.33, 0.66].map((f) => k.sideSeam(plan, 6 + (m.h - 4) * f, P, 6)).join("");
  out.push(S(body, { tone: "hi", crease: "lo", inner: L(seams, { tone: "faint" }) }));
  const lid = k.insetPlan(plan, 1.2);
  out.push(S(k.slabOf(lid, top - 4, 4, P, 6, 0.8), { tone: "hi", crease: "lo" }));
  out.push(L(k.planOutline(k.insetPlan(lid, 4), top, P, 6), { tone: "faint" }));
  const screws = k.corners(lid, 5.5);
  out.push(L(screws.map(([x, y]) => k.ring(x, y, 1.6, top, P, 14)).join(""), { tone: "lo" }));
  out.push(D(screws.map(([x, y]) => at([x, y, top])), { size: 0.45 }));
  const vent = { x: plan.x + 10, y: plan.y + plan.d, w: plan.w - 20, d: 0, r: 0 };
  for (let i = 0; i < 3; i++) {
    const z = 9 + i * 3.2;
    const ring = [[vent.x, vent.y, z], [vent.x + vent.w, vent.y, z], [vent.x + vent.w, vent.y, z + 1.2], [vent.x, vent.y, z + 1.2]];
    out.push(L(k.pathOf(ring.map((p) => at(p)), true), { tone: "lo" }));
  }
  const yF = plan.y + plan.d, x0 = plan.x + 8, x1 = plan.x + plan.w - 8, z0 = 20, z1 = 29.5;
  out.push(L(k.pathOf([[x0, yF, z0], [x1, yF, z0], [x1, yF, z1], [x0, yF, z1]].map((p) => at(p)), true), { tone: "lo" }));
  out.push(D([at([x0 + 2.4, yF, (z0 + z1) / 2]), at([x1 - 2.4, yF, (z0 + z1) / 2])], { size: 0.45 }));
  out.push(k.faceTextSvg(k.sideMatrix([(x0 + x1) / 2, yF], z0 + 2.6, P, "left"), m.name, { size: Math.min(6.4, (x1 - x0 - 8) / (m.name.length * 0.62)), tone: "hi", anchor: "middle" }));
  const led = [plan.x + plan.w - 12, plan.y + 10];
  out.push(S(k.cylinder(led[0], led[1], 2.2, top, 1.4, P, 18), { tone: "mid" }));
  out.push(`<path class="led" d="${k.ring(led[0], led[1], 1.2, top + 1.4, P, 14)}"/>`);
  if (!island) {
    for (const l of portsOf.get(m.name)) {
      const [x, y] = l.ports[m.name];
      out.push(`<g class="boss" data-link="${l.id}">${S(k.cylinder(x, y, l.r + 1.3, top, BOSS_H, P, 22), { tone: "mid" })}${L(k.ring(x, y, l.r + 0.2, top + BOSS_H, P, 22), { tone: "lo" })}</g>`);
    }
  }
  return out.join("");
}

const shapesOf = (m, island) => {
  const list = [
    A.slab(k.insetPlan(m.plan, -2), 0, 6, { name: `${m.name}.skirt` }),
    A.slab(m.plan, 6, m.h - 4, { name: `${m.name}.body` }),
    A.slab(k.insetPlan(m.plan, 1.2), m.top - 4, 4, { name: `${m.name}.lid` }),
  ];
  if (!island) for (const l of portsOf.get(m.name)) { const [x, y] = l.ports[m.name]; list.push(A.cylinder(x, y, l.r + 1.3, m.top, BOSS_H, { name: `${m.name}.port.${l.id}` })); }
  return list;
};

for (const m of MODULES) {
  put({ at: [m.center[0], m.center[1], m.h / 2], svg: `<g class="mod" data-mod="${m.name}" tabindex="0" role="button" aria-label="${m.name}, ${typesOf(m.name)} Typen">${moduleSvg(m)}</g>`, shapes: shapesOf(m).map((s) => R.solid(s)) });
}
put({ at: [ISLAND.center[0], ISLAND.center[1], ISLAND.h / 2], svg: `<g class="mod" data-mod="${ISLAND.name}" tabindex="0" role="button" aria-label="${ISLAND.name}, ${typesOf(ISLAND.name)} Funktionen, keine Verbindung zum Swift-Code">${moduleSvg(ISLAND, { island: true })}</g>`, shapes: shapesOf(ISLAND, true).map((s) => R.solid(s)) });

for (const l of LINKS) {
  const ma = byName[l.a], mb = byName[l.b];
  const pa = l.ports[l.a], pb = l.ports[l.b];
  const za = ma.top + BOSS_H, zb = mb.top + BOSS_H;
  const span = Math.hypot(pb[0] - pa[0], pb[1] - pa[1]);
  const lift = 14 + span * 0.2 + (LINKS.indexOf(l) % 5) * 3;
  const c1 = [pa[0], pa[1], za + lift], c2 = [pb[0], pb[1], zb + lift];
  const route = Array.from({ length: 48 }, (_, i) => { const t = i / 47, u = 1 - t; return [0, 1, 2].map((j) => u * u * u * [pa[0], pa[1], za][j] + 3 * u * u * t * c1[j] + 3 * u * t * t * c2[j] + t * t * t * [pb[0], pb[1], zb][j]); });
  const pieces = tubePieces(route, l.r, P, { maxLength: 14 });
  const dense = G.resample(route, 1.2);
  let walked = 0;
  pieces.forEach((piece, i) => {
    const flat = piece.points.map((p) => at(p));
    const d = k.pathOf(flat);
    const len = flat.reduce((s, p, j) => (j ? s + Math.hypot(p[0] - flat[j - 1][0], p[1] - flat[j - 1][1]) : 0), 0);
    const svg = `<g class="cab" data-link="${l.id}">${tubeSvg(piece, { tone: "hi" })}<path class="pulse" data-off="${walked.toFixed(1)}" d="${d}"/></g>`;
    walked += len;
    put({ at: piece.mid, svg, route: l.id, shapes: [] });
  });
  R.route(`cable.${l.id}`, dense, l.r, { limp: true });
}

A.settle(R, P);
R.items.sort((a, b) => a.key - b.key);
A.auditOrExit(R, P, { crowd: [] });
if (process.argv.includes("--audit")) process.exit();

const svg = k.figureSvg({
  width: WIDTH,
  height: HEIGHT,
  label: `Die App ALFA OS als Schaltschrank: acht Module auf einer Grundplatte, Höhe nach Zahl der Typen, ${LINKS.length} Leitungen zwischen ihnen, Dicke nach Zahl der Typ-Paare. Daneben auf eigenem Sockel die Design-Skripte ohne Leitung.`,
  body: [base(), ...R.items.map((item) => item.svg)],
});

const DATA = {
  modules: [...MODULES.map((m) => ({ name: m.name, types: typesOf(m.name) })), { name: ISLAND.name, types: typesOf(ISLAND.name) }],
  links: LINKS.map((l) => ({ id: l.id, a: l.a, b: l.b, n: l.n, dir: l.dir, examples: l.examples })),
  meta: META,
};

const live = readFileSync(new URL("./live.js", import.meta.url), "utf8");
const css = readFileSync(new URL("./page.css", import.meta.url), "utf8");
const total = LINKS.reduce((s, l) => s + l.n, 0);
const html = `<title>ALFA Schaltschrank</title>
<meta name="claude:viewport-fit-sides" content="cover">
<style>${k.ISO_CSS}${css}</style>
<main class="iso page" id="root">
  <header class="head">
    <p class="eyebrow">ALFA OS · Code-Verflechtung</p>
    <h1>Wer im Code wen braucht</h1>
    <p class="lede">Jedes Modul ist ein Bereich der App, so hoch wie er Typen hat. Jede Leitung ist so dick, wie viele Typen der beiden Bereiche einander nutzen. Gemessen mit graphify aus dem echten Code, ohne Sprachmodell.</p>
  </header>
  <figure class="iso-plate card">
    <div class="corner tl">Fig 1</div><div class="corner tr">Schaltschrank ALFA</div>
    <div class="iso-stage" tabindex="0" aria-label="Schaltschrank: Modul oder Leitung anklicken">${svg}</div>
    <div class="corner bl">Modul oder Leitung anklicken · Pfeiltasten wechseln</div>
    <div class="corner br" data-readout>${MODULES.length} Module · ${LINKS.length} Leitungen · ${total} Typ-Paare</div>
  </figure>
  <section class="detail" aria-live="polite">
    <div class="detail-head"><h2 id="d-title">Mail</h2><p id="d-sub"></p></div>
    <div id="d-body"></div>
  </section>
  <footer class="foot">
    <p>Stand: <code>main</code> @ <code>${META.sha.slice(0, 8)}</code> vom ${META.commitDate}, gemessen ${META.measured}. ${META.files} Swift-Dateien, ${META.typesTotal} Typen, ${total} Typ-Paare über Bereichsgrenzen. Neu gemessen nach jedem Commit auf <code>main</code>.</p>
    <p class="muted">Grenzen: Die Bögen (<code>*.dc.html</code>) und der Werkstatt-Brief sind nicht enthalten; graphify liest sie nur mit Sprachmodell. Zwischen den Design-Skripten (JavaScript) und dem Swift-Code gibt es keine messbaren Kanten. Bereiche nach Ordner: Assistent = <code>Sources/Assistant</code> und <code>App/Shell/Assistant*</code>, Hülle = übrige <code>App/Shell</code> und <code>Sources/Shell</code>, Grundlage = <code>Core</code>, <code>Design</code>, <code>Storage</code>, <code>App/Components</code>, <code>App/Design</code>.</p>
  </footer>
</main>
<script>const DATA = ${JSON.stringify(DATA)};
${live}</script>`;
writeFileSync(OUT, html);
console.log("wrote", OUT, (html.length / 1024).toFixed(0), "KB", "items", R.items.length);
