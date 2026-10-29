/* Export 19.10.2026 · Port von DESIGN/brief/check_contract.py. Aufruf: new Function(code)() liefert check(files, areas, drafts) → findings[]. files: { name: parsed JSON }, drafts: { name: text } */
const ALIAS = /^\{([A-Za-z0-9.]+)\}$/;
const tokenPaths = (n, prefix, out) => { if (n && typeof n === "object" && !Array.isArray(n)) { if ("$value" in n) { out.add(prefix); return; } for (const [k, s] of Object.entries(n)) if (!k.startsWith("$")) tokenPaths(s, prefix ? prefix + "." + k : k, out); } };
const check = (files, areas, drafts) => {
  const f = [];
  const res = files["alfa.resolver.json"];
  if (res) { let refs = []; for (const s of Object.values(res.sets || {})) refs = refs.concat(s.sources || []); for (const m of Object.values(res.modifiers || {})) for (const srcs of Object.values(m.contexts || {})) refs = refs.concat(srcs); for (const r of refs) if (!(r.$ref in files)) f.push("resolver source missing: " + r.$ref); }
  const tokens = new Set(); let tokAliases = new Set();
  for (const [name, data] of Object.entries(files)) if (name.endsWith(".tokens.json")) { tokenPaths(data, "", tokens); for (const m of JSON.stringify(data).matchAll(/"(\{[A-Za-z0-9.]+\})"/g)) tokAliases.add(m[1]); }
  const comps = (files["components.json"] || {}).components || [], views = (files["views.json"] || {}).views || [], texts = new Set(((files["texts.json"] || {}).texts || []).map(t => t.key));
  const ids = [], keys = new Set(), aliases = new Set();
  for (const c of comps) { for (const v of Object.values(c.measures || {}).concat([c.layer || ""])) aliases.add(v); for (const s of c.states || []) for (const v of Object.values(s.tokens || {})) aliases.add(v); for (const m of c.mechanics || []) aliases.add(m.transition || ""); for (const e of c.elements || []) { ids.push(e.id); if (e.textKey) keys.add(e.textKey); } }
  for (const d of [...new Set(ids.filter(i => ids.filter(j => j === i).length > 1))].sort()) f.push("element id twice in components.json: " + d);
  const idset = new Set(ids);
  for (const v of views) { for (const lane of Object.values(v.lanes || {})) for (const i of (lane.header || []).concat(lane.footer || [])) if (!idset.has(i)) f.push("views.json " + v.area + ": element " + i + " not in components.json"); for (const a of v.actions || []) { if (!idset.has(a.element)) f.push("views.json " + v.area + ": action " + a.id + " element " + a.element + " not in components.json"); if (a.feedbackKey) keys.add(a.feedbackKey); } for (const k of v.textKeys || []) keys.add(k); }
  for (const k of [...keys].filter(k => !texts.has(k)).sort()) f.push("text key not in texts.json: " + k);
  const found = new Set(views.map(v => v.area)); for (const a of areas || []) if (!found.has(a)) f.push("views.json: area " + a + " missing");
  if (tokens.size) { for (const a of [...new Set([...aliases, ...tokAliases])].sort()) { const m = ALIAS.exec(a || ""); if (a && (!m || !tokens.has(m[1]))) f.push("token alias does not resolve: " + a); } } else f.push("no *.tokens.json");
  const drawn = new Set(), parts = new Set();
  const dr = drafts || {};
  for (const text of Object.values(dr)) { for (const m of text.matchAll(/data-id="([^"{}]+)"/g)) drawn.add(m[1]); for (const m of text.matchAll(/data-part="([^"{}]+)"/g)) parts.add(m[1]); for (const m of text.matchAll(/part:\s*"([a-z0-9-]+)"/g)) parts.add(m[1]); }
  if (Object.keys(dr).length) { const known = new Set(comps.map(c => c.part)); for (const p of [...parts].filter(p => !known.has(p)).sort()) f.push("data-part in drafts not in components.json: " + p); for (const p of [...known].filter(p => !parts.has(p)).sort()) f.push("component has no data-part in drafts: " + p); for (const p of [...new Set(comps.map(c => c.part).filter((p, i, a) => a.indexOf(p) !== i))].sort()) f.push("part twice in components.json: " + p); for (const i of [...drawn].filter(i => !idset.has(i)).sort()) f.push("data-id in drafts not in components.json: " + i); for (const i of [...idset].filter(i => !drawn.has(i)).sort()) f.push("element id has no data-id in drafts: " + i); }
  return f;
};
return { check };
