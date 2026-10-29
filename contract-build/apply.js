/* Export 21.10.2026, ergänzt 23.10.; 28.10.: renameTexts [[alt, neu]] (formerKey, Zusammenlegen bei gleichem de, views.json …Key/…Keys folgen; schon umbenannt = nur Verweise); 28.10.: tokens ty "easing" (cubicBezier); 27.10.: dropTokens, tokens [v,d,ty,where], colors hex/where; 24.10.: liest nur vorhandene Bögen (ALFA PDF gelöscht); Token-Typ "ms" (duration), Text mit en als 5. Eintrag, dropComponents, colors (Themenfarbe light/dark) · Vertrag nach einer Bogenänderung nachziehen. Aufruf in run_script:
   const r = await new AsyncFunction('io', 'spec', code)({ readFile, saveFile, ls }, spec);
   spec = { stamp:"2026-10-21T21:00", reason:"…≤120", texts:[[key,de,kind,element?]], dropTexts:[key], tokens:{ "size.name":[px,"Beschreibung"] | "spacing.x" … }, components:[{part,name,category,role,layer,measures,states,where,status,elements:[{id,part,where}]}], elements:[{part,id,where}], write:true }
   Erst P1/P2/P3 (JS-Ports), dann Schreiben; bei Fund nichts schreiben. TOKENBOGEN.json wird bei tokens ergänzt, t1 erzeugt contract/*.tokens.json, t9 den Block in alfa-theme.css. */
const { readFile, saveFile, ls } = io;
const J = async f => JSON.parse(await readFile(f));
const cur = {}; for (const n of await ls("contract")) if (n.endsWith(".json")) cur[n] = await J("contract/" + n);
const prev = JSON.parse(JSON.stringify(cur));
let T = null, theme = null;
if ((spec.tokens && Object.keys(spec.tokens).length) || (spec.dropTokens && spec.dropTokens.length) || (spec.ext && Object.keys(spec.ext).length) || (spec.colors && Object.keys(spec.colors).length)) {
  T = await J("TOKENBOGEN.json");
  const at = p => { const q = p.split("."), k = q.pop(); let g = T; for (const s of q) g = g[s] = g[s] || {}; return [g, k]; };
  for (const [p, ex] of Object.entries(spec.ext || {})) { const [g, k] = at(p); if (!g[k]) throw new Error("Token fehlt: " + p); g[k].$extensions = g[k].$extensions || {}; g[k].$extensions.alfa = Object.assign(g[k].$extensions.alfa || {}, ex); }
  for (const p of spec.dropTokens || []) { const [g, k] = at(p); if (!g[k]) throw new Error("Token fehlt: " + p); delete g[k]; }
  for (const [p, [v, d, ty, wh]] of Object.entries(spec.tokens || {})) { const [g, k] = at(p); if (g[k]) throw new Error("Token existiert: " + p); g[k] = { $type: ty === "easing" ? "cubicBezier" : ty === "number" ? "number" : ty === "ms" ? "duration" : "dimension", $value: ty === "easing" || ty === "number" ? v : { value: v, unit: ty === "ms" ? "ms" : "px" }, $description: d, $extensions: { alfa: Object.assign({ status: "set-by-design", source: spec.reason }, wh ? { where: wh } : {}) } }; }
  for (const [n, c] of Object.entries(spec.colors || {})) for (const th of ["light", "dark"]) { if (T.color[th][n]) throw new Error("Farbe existiert: " + th + "." + n); T.color[th][n] = { $type: "color", $value: Object.assign({ colorSpace: "srgb", components: c[th].slice(0, 3), alpha: c[th][3] }, c.hex ? { hex: c.hex } : {}), $description: c.desc, $extensions: { alfa: Object.assign({ css: "--c-" + n, status: "set-by-design", source: spec.reason }, c.where ? { where: c.where } : {}) } }; }
  const t1 = new Function(await readFile("contract-build/t1-tokens.js"))(T);
  Object.assign(cur, t1.files);
  const css = new Function("base", await readFile("contract-build/t9-css.js"))(cur["base.tokens.json"]);
  theme = (await readFile("alfa-theme.css")).replace(/(\/\* alfa:tokens:begin[^\n]*\n)[\s\S]*?(\n\/\* alfa:tokens:end \*\/)/, (m, a, b) => a + css + b);
}
const tx = cur["texts.json"].texts;
for (const k of spec.dropTexts || []) { const i = tx.findIndex(x => x.key === k); if (i >= 0) tx.splice(i, 1); }
/* renameTexts [[alt, neu]] (28.10.): Schlüssel umbenennen, Bereich bleibt, formerKey = alte Schlüssel; trifft neu auf einen bestehenden Eintrag mit gleichem de, wird zusammengelegt; textKeys in views.json folgen. */
const RN = {}; for (const [a, b] of spec.renameTexts || []) { const i = tx.findIndex(x => x.key === a); if (i < 0) { const d = tx.find(x => x.key === b && (x.formerKey || "").split(", ").includes(a)); if (!d) throw new Error("Text fehlt: " + a); RN[a] = b; continue; } const o = tx[i]; const j = tx.findIndex(x => x.key === b); if (j >= 0 && j !== i) { if (tx[j].de.replace(/\s*…$/, "") !== o.de.replace(/\s*…$/, "")) throw new Error("gleicher Schlüssel, anderes de: " + a + " → " + b); tx[j].formerKey = [tx[j].formerKey, a].filter(Boolean).join(", "); tx.splice(i, 1); } else { o.formerKey = [o.formerKey, a].filter(Boolean).join(", "); o.key = b; } RN[a] = b; }
if (Object.keys(RN).length) { const vw = cur["views.json"]; const walk = o => { if (Array.isArray(o)) return o.forEach(walk); if (o && typeof o === "object") for (const [k, v] of Object.entries(o)) { if (/Keys$/.test(k) && Array.isArray(v)) o[k] = [...new Set(v.map(x => RN[x] || x))]; else if (/Key$/.test(k) && typeof v === "string" && RN[v]) o[k] = RN[v]; else walk(v); } }; walk(vw); }
for (const [key, de, kind, element, en] of spec.texts || []) { const i = tx.findIndex(x => x.key === key); const o = { key, de, area: key.split(".")[0], kind, status: "set-by-design" }; if (en) o.en = en; if (element) o.element = element; if (i >= 0) tx[i] = o; else tx.push(o); }
const comps = cur["components.json"].components;
for (const p of spec.dropComponents || []) { const i = comps.findIndex(x => x.part === p); if (i >= 0) comps.splice(i, 1); }
for (const c of spec.components || []) { const i = comps.findIndex(x => x.part === c.part); if (i >= 0) comps[i] = Object.assign({}, comps[i], c); else comps.push(c); }
for (const e of spec.elements || []) { const c = comps.find(x => x.part === e.part); if (!c) throw new Error("Bauteil fehlt: " + e.part); c.elements = c.elements || []; if (!c.elements.some(x => x.id === e.id)) c.elements.push({ id: e.id, part: e.part, where: e.where }); }
const DM = new Function(await readFile("contract-build/diff.js"))();
const blk = DM.makeBlock(prev, cur, spec.stamp, () => spec.reason.slice(0, 120));
if (blk.changes && blk.changes.length) cur["changes.json"] = { blocks: [...prev["changes.json"].blocks, blk] };
const V = new Function(await readFile("contract-build/validate.js"))();
const f1 = []; for (const [name, data] of Object.entries(cur)) { const m = V.MAP.find(([s]) => name.endsWith(s)); if (!m) continue; V.errors(await J("DESIGN/brief/" + m[1]), data).forEach(x => f1.push(name + ": " + x)); }
const dr = {}; const have = await ls(""); for (const n of ["ALFA Mail", "ALFA Einstellungen", "ALFA Shell", "ALFA Bestaetigen", "ALFA PDF"]) if (have.includes(n + ".dc.html")) dr[n + ".dc.html"] = await readFile(n + ".dc.html");
const f2 = new Function(await readFile("contract-build/check.js"))().check(cur, ["shell", "mail", "settings"], dr);
const f3 = DM.check(prev, cur);
const rep = { P1: f1, P2: f2, P3: f3.findings, changes: f3.difference, logged: f3.logged };
if (f1.length || f2.length || f3.findings.length) return Object.assign(rep, { written: false });
await saveFile("contract/texts.json", JSON.stringify(cur["texts.json"], null, 2) + "\n");
await saveFile("contract/components.json", JSON.stringify(cur["components.json"], null, 2) + "\n"); if (spec.renameTexts && spec.renameTexts.length) await saveFile("contract/views.json", JSON.stringify(cur["views.json"], null, 2) + "\n");
await saveFile("contract/changes.json", JSON.stringify(cur["changes.json"], null, 2) + "\n");
if (T) { T.export = "2026-10-21"; await saveFile("TOKENBOGEN.json", JSON.stringify(T, null, 1) + "\n"); for (const n of Object.keys(cur)) if (n.endsWith(".tokens.json") || n === "alfa.resolver.json") await saveFile("contract/" + n, JSON.stringify(cur[n], null, 2) + "\n"); await saveFile("alfa-theme.css", theme); }
return Object.assign(rep, { written: true });
