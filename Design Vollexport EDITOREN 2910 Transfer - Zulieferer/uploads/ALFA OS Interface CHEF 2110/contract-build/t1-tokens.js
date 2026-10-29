/* Export 19.10.2026 · T1: TOKENBOGEN.json → contract/*.tokens.json (DTCG, Brief v9). Eingabe T (geparstes TOKENBOGEN.json). Ergebnis { files, side, log } */
const clone = o => JSON.parse(JSON.stringify(o));
const STAT = { designSet: "set-by-design", provisionalApproval: "approved-provisional", approved: "approved", freigegeben: "approved", "freigabe-orange": "approved-provisional", "von-design-gesetzt": "set-by-design" };
const log = { statusMapped: 0, statusAdded: 0, typeAdded: 0, aliasWrapped: 0, dropped: [], moved: [] };
const hex2c = h => { const n = parseInt(h.slice(1), 16); const c = [(n >> 16) & 255, (n >> 8) & 255, n & 255].map(v => Math.round(v / 255 * 10000) / 10000); return { colorSpace: "srgb", components: c, alpha: 1, hex: h.toLowerCase() }; };
const fix = (tok, inherited, path) => {
  if (!tok.$type) { if (inherited) { tok.$type = inherited; log.typeAdded++; } }
  tok.$extensions = tok.$extensions || {}; const a = tok.$extensions.alfa = tok.$extensions.alfa || {};
  if (a.status !== undefined) { if (!STAT[a.status] && !["approved", "approved-provisional", "set-by-design"].includes(a.status)) throw new Error("status? " + path + " " + a.status); if (STAT[a.status]) { a.status = STAT[a.status]; log.statusMapped++; } }
  else if (!a.source) { a.status = "set-by-design"; log.statusAdded++; }
  return tok;
};
const aliasRe = /\{(color|shadow)\.(light|dark|lightGrayOverrides)\.([A-Za-z0-9.]+)\}/g;
const rewrite = v => JSON.parse(JSON.stringify(v).replace(aliasRe, (m, g, th, rest) => "{" + g + "." + rest + "}"));
const refType = (T, alias) => { const p = alias.slice(1, -1).split("."); let n = T; for (const k of p) { n = n && n[k]; } return n && n.$type; };
// walk a group, converting it into tokens; theme-specific groups are handled by the caller
const walk = (node, inherited, path, out) => {
  if (typeof node === "string" && /^\{[A-Za-z0-9.]+\}$/.test(node)) { return { $type: null, $value: node, $extensions: { alfa: {} }, __bare: true }; }
  if (node === null || typeof node !== "object" || Array.isArray(node)) return undefined;
  if ("$value" in node) { return clone(node); }
  const g = {}; const ty = node.$type || inherited;
  for (const [k, v] of Object.entries(node)) {
    if (k === "$type") continue;
    if (k.startsWith("$")) { g[k] = v; continue; }
    const r = walk(v, ty, path + "." + k, out); if (r !== undefined) g[k] = r;
  }
  return g;
};
const SINK = {}; const finish = (g, inherited, path, T) => {
  if (g === null || typeof g !== "object") return g;
  if ("$value" in g) { if (g.__bare) { delete g.__bare; g.$type = refType(T, g.$value); if (!g.$type) throw new Error("bare alias without type: " + path); } if (g.$type === "string") { log.dropped.push(path); SINK[path] = g; return undefined; } return fix(g, inherited, path); }
  const out = {}; for (const [k, v] of Object.entries(g)) { if (k.startsWith("$")) { out[k] = v; continue; } const r = finish(v, inherited, path ? path + "." + k : k, T); if (r !== undefined) out[k] = r; }
  return out;
};
const T = clone(arguments[0]);
const base = {}, light = {}, dark = {}, gray = {}, side = {};
// meta
const meta = clone(T.$extensions || {}); meta.alfa = Object.assign({}, meta.alfa || {}, { export: T.export, paket: T.paket, references: "Alias: Pfad des Tokens in geschweiften Klammern, z. B. size.edge" });
const SKIP = new Set(["export", "paket", "$description", "$extensions", "color", "shadow", "stack", "surface", "component", "confirm"]);
for (const [k, v] of Object.entries(T)) { if (SKIP.has(k)) continue; base[k] = v; }
// groups with $type inheritance handled by finish; first walk to wrap bare strings
const prep = (obj) => walk(obj, null, "", null);
for (const k of Object.keys(base)) base[k] = prep(base[k]);
// component: bare alias strings
base.component = prep(T.component);
// confirm
const conf = clone(T.confirm); if (conf.tooltip) { side.confirmTooltip = conf.tooltip; delete conf.tooltip; log.dropped.push("confirm.tooltip"); } base.confirm = prep(conf);
// color: light, dark, lightGrayOverrides, mood
light.color = rewrite(prep(T.color.light)); dark.color = rewrite(prep(T.color.dark)); gray.color = rewrite(prep(T.color.lightGrayOverrides));
for (const [name, tok] of Object.entries(T.color.mood)) { const mk = th => { const t = clone(tok); t.$value = hex2c(tok.$value[th]); return t; }; light.color[name] = mk("light"); dark.color[name] = mk("dark"); }
// shadow
light.shadow = rewrite(prep(T.shadow.light)); dark.shadow = rewrite(prep(T.shadow.dark)); gray.shadow = rewrite(prep(T.shadow.lightGrayOverrides));
// stack
for (const [th, tgt] of [["light", light], ["dark", dark]]) { tgt.stack = {}; for (const row of T.stack[th]) { tgt.stack["depth" + row.depth] = { surface: clone(row.surface), ink: clone(row.ink) }; } }
// surface
const lq = T.surface.lacquer; const sl = { lacquer: {}, glass: {} }; const sd = { lacquer: {}, glass: {} }; const sb = { lacquer: {} };
for (const layer of lq.layers) { const n = layer.name; sl.lacquer[n] = {}; sd.lacquer[n] = {}; sb.lacquer[n] = {};
  for (const [k, v] of Object.entries(layer)) { if (k === "name" || k === "$type") continue; if (typeof v === "string") { (sl.lacquer[n].$description = sd.lacquer[n].$description = sb.lacquer[n].$description = v); continue; }
    const mkTok = val => ({ $type: "shadow", $value: val });
    if (v && !Array.isArray(v) && (v.light || v.dark)) { if (v.light) sl.lacquer[n][k] = mkTok(v.light); if (v.dark) sd.lacquer[n][k] = mkTok(v.dark); }
    else sb.lacquer[n][k] = mkTok(v); } }
const gl = T.surface.glass; sl.glass.card = { $type: "shadow", $value: gl.light }; sd.glass.card = { $type: "shadow", $value: gl.dark }; sl.glass.$description = sd.glass.$description = gl.note;
sl.$description = sd.$description = (T.surface.$description || "") + " Füllregel hell: " + T.surface.lightFillRule + ". flach: " + (T.surface.flat && T.surface.flat.$description || "");
light.surface = sl; dark.surface = sd; base.surface = sb;
// finish all
const FX = (obj, T0) => { const o = {}; for (const [k, v] of Object.entries(obj)) { if (k.startsWith("$")) { o[k] = v; continue; } const r = finish(v, null, k, T0); if (r !== undefined) o[k] = r; } return o; };
const flat = Object.assign({}, T, { _x: 1 });
const all = clone(T); // for refType lookups: component aliases refer to size.* etc.
const bF = FX(base, all), lF = FX(light, all), dF = FX(dark, all), gF = FX(gray, all);
bF.$extensions = meta;
{ const dur = T.motion.duration, eas = T.motion.easing; const tr = {}; for (const k of Object.keys(dur)) if (!k.startsWith("$") && eas[k] && !k.startsWith("$")) tr[k] = { $type: "transition", $value: { duration: "{motion.duration." + k + "}", delay: { value: 0, unit: "ms" }, timingFunction: "{motion.easing." + k + "}" }, $extensions: { alfa: { status: "set-by-design", where: "gleichnamige motion.duration und motion.easing" } } }; if (Object.keys(tr).length) bF.motion.transition = tr; }
if (T.$description) bF.$description = T.$description;
const sc = (th, f) => { for (const t of []) {} return f; };
side.dropped = SINK; return { files: { "base.tokens.json": bF, "theme-light.tokens.json": lF, "theme-dark.tokens.json": dF, "ground-lightGray.tokens.json": gF }, side, log };
