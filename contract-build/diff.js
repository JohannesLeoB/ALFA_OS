/* Export 19.10.2026 · Port von DESIGN/brief/diff_contract.py. Aufruf: new Function(code)() → { entries, diff, check(oldFiles, newFiles) → { findings, difference, logged }, makeBlock(oldFiles, newFiles, stamp, reasons) } */
const walkTok = (files) => { const out = {}; const w = (n, p, th) => { if (n && typeof n === "object" && !Array.isArray(n)) { if ("$value" in n) { out[th + p] = n.$value; return; } for (const [k, v] of Object.entries(n)) if (!k.startsWith("$")) w(v, p ? p + "." + k : k, th); } };
  for (const name of Object.keys(files).sort()) if (name.endsWith(".tokens.json")) { const theme = name.slice(0, -".tokens.json".length); w(files[name], "", theme === "base" ? "" : theme + ":"); } return out; };
const entries = files => { const f = {}; for (const [k, v] of Object.entries(walkTok(files))) f["token\u0000" + k] = v;
  for (const c of (files["components.json"] || {}).components || []) { const body = {}; for (const [k, v] of Object.entries(c)) if (k !== "elements") body[k] = v; f["component\u0000" + c.part] = body; for (const e of c.elements || []) f["element\u0000" + e.id] = e; }
  for (const t of (files["texts.json"] || {}).texts || []) f["text\u0000" + t.key] = t;
  for (const v of (files["views.json"] || {}).views || []) f["view\u0000" + v.area] = v; return f; };
const eq = (a, b) => JSON.stringify(a) === JSON.stringify(b);
const diff = (o, n) => { const d = {}; for (const k of new Set([...Object.keys(o), ...Object.keys(n)])) { if (!(k in n)) d[k] = "remove"; else if (!(k in o)) d[k] = "add"; else if (!eq(o[k], n[k])) d[k] = "change"; } return d; };
const check = (oldF, newF) => { const d = diff(entries(oldF), entries(newF)); const log = newF["changes.json"], oldLog = oldF["changes.json"]; const logged = {}, findings = [];
  /* 27.10.: wie diff_contract.py:85–96 — nur angehängte Blöcke zählen; kein Block = Vertrag muss gleich sein */ const before = (oldLog || {}).blocks || [], blocks = (log || {}).blocks || [];
  if (!eq(blocks.slice(0, before.length), before)) findings.push("changed old block: blocks before the new one differ from old changes.json");
  const appended = blocks.slice(before.length); if (appended.length > 1) findings.push("more than one block appended to old changes.json");
  if (appended.length) for (const ch of appended[appended.length - 1].changes) { logged[ch.kind + "\u0000" + ch.id] = ch.op; if (ch.op === "rename" && ch.from) logged[ch.kind + "\u0000" + ch.from] = "rename"; }
  for (const [k, op] of Object.entries(d).sort()) { const [kind, id] = k.split("\u0000"); if (!(k in logged)) findings.push("silent change: " + kind + " " + id + " (" + op + ")"); else if (logged[k] !== op && logged[k] !== "rename") findings.push("wrong op: " + kind + " " + id + " (difference " + op + ", logged " + logged[k] + ")"); }
  for (const [k, op] of Object.entries(logged).sort()) if (!(k in d)) { const [kind, id] = k.split("\u0000"); findings.push("ghost entry: " + kind + " " + id + " (" + op + ")"); }
  return { findings: findings.map((x, i) => "C-" + String(i + 1).padStart(3, "0") + " " + x), difference: Object.keys(d).length, logged: Object.keys(logged).length }; };
const makeBlock = (oldF, newF, stamp, reason) => { const d = diff(entries(oldF), entries(newF)); const prev = ((oldF["changes.json"] || {}).blocks || []).slice(-1)[0]; const changes = Object.entries(d).sort().map(([k, op]) => { const [kind, id] = k.split("\u0000"); return { kind, id: id.slice(0, 120), op, reason: (reason(kind, id, op) || "Änderung im Vertrag").slice(0, 120) }; }); return { export: stamp, previous: prev ? prev.export : "none", changes }; };
return { entries, diff, check, makeBlock };
