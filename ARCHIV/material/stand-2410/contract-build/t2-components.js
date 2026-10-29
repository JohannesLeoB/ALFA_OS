/* Export 19.10.2026 · T2: components.json aus den vier Bögen, bauteile.json, TOKENBOGEN.json. Aufruf: new Function('src','B','T','side',code)(src, bauteile, tokenbogen, side) */
const AREA = { "ALFA Mail.dc.html": "mail", "ALFA Einstellungen.dc.html": "settings", "ALFA Shell.dc.html": "shell", "ALFA Bestaetigen.dc.html": "confirm" };
const pascal = s => s.split("-").map(w => w[0].toUpperCase() + w.slice(1)).join("");
const camel = s => s.replace(/[^A-Za-z0-9]+(.)/g, (m, c) => c.toUpperCase()).replace(/^[A-Z]/, c => c.toLowerCase());
const parts = {}; const P = n => parts[n] || (parts[n] = { elements: [], where: [] });
for (const [f, text] of Object.entries(src)) {
  const lines = text.split("\n"); const x0 = text.indexOf("<x-dc>");
  lines.forEach((ln, i) => { const lineNo = i + 1;
    for (const m of ln.matchAll(/data-part="([^"{}]+)"(?:[^>]*?\sdata-id="([^"{}]+)")?/g)) { const p = P(m[1]); const w = f + ":" + lineNo; if (!p.where.includes(w)) p.where.push(w); if (m[2]) p.elements.push({ id: m[2], part: m[1], where: w, tag: ln }); }
    for (const m of ln.matchAll(/part:\s*"([a-z0-9-]+)"/g)) { const p = P(m[1]); const w = f + ":" + lineNo; if (!p.where.includes(w)) p.where.push(w); }
  });
}
for (const b of B.bauteile) P(b.name);
const byBau = Object.fromEntries(B.bauteile.map(b => [b.name, b]));
const LAYER = { blob: "blob", "blob-face": "blob", "thinking-orb": "blob", assistant: "blob", "assistant-input": "blob", "anchored-menu": "menu", "menu-row": "menu", menu: "menu", toast: "toast", handle: "handle", "sync-button": "syncButton", "safe-area": "safeArea", lane: "lane", "lane-strip": "lane", "area-page": "lane" };
const PATTERN = { blob: { states: ["rest", "awake", "menuOpen", "assistant", "docked", "dragging"], events: ["approach", "leave", "click", "doubleClick", "drag", "drop", "close"], transitions: [["rest", "approach", "awake"], ["awake", "leave", "rest"], ["awake", "click", "menuOpen"], ["awake", "doubleClick", "assistant"], ["menuOpen", "close", "rest"], ["assistant", "close", "rest"], ["rest", "drag", "dragging"], ["dragging", "drop", "docked"], ["docked", "drag", "dragging"], ["dragging", "drop", "rest"]] },
  lane: { states: ["open", "folded", "maximized"], events: ["fold", "unfold", "maximize", "restore", "doubleClick"], transitions: [["open", "fold", "folded"], ["folded", "unfold", "open"], ["folded", "doubleClick", "open"], ["open", "maximize", "maximized"], ["maximized", "restore", "open"]] },
  "card-stack": { states: ["stacked", "fanned"], events: ["overview", "back", "select"], transitions: [["stacked", "overview", "fanned"], ["fanned", "back", "stacked"], ["fanned", "select", "stacked"]] },
  card: { states: ["stacked", "open", "fanned"], events: ["select", "overview", "back", "close"], transitions: [["stacked", "select", "open"], ["open", "overview", "fanned"], ["fanned", "select", "open"], ["fanned", "back", "stacked"]] },
  toast: { states: ["hidden", "shown"], events: ["show", "undo", "timeout"], transitions: [["hidden", "show", "shown"], ["shown", "undo", "hidden"], ["shown", "timeout", "hidden"]] },
  "anchored-menu": { states: ["closed", "open"], events: ["open", "choose", "dismiss"], transitions: [["closed", "open", "open"], ["open", "choose", "closed"], ["open", "dismiss", "closed"]] },
  "confirm-pill": { states: ["idle", "asking", "erasing", "done"], events: ["open", "cancel", "press", "release", "timeout", "undo"], transitions: [["idle", "open", "asking"], ["asking", "cancel", "idle"], ["asking", "press", "erasing"], ["erasing", "release", "asking"], ["erasing", "timeout", "done"], ["done", "undo", "idle"]] } };
const CAT = (n, hasEl) => PATTERN[n] ? "pattern" : /^(symbol-button|text-button|toggle|choice|mark|counter|divider|handle|notice|thinking-orb|scroll-line|connection-status|input-field|segmented-control)$/.test(n) ? "primitive" : "composite";
// token lookup for measures by value
const flat = {}; const walk = (o, p) => { if (o && typeof o === "object" && !Array.isArray(o)) { if ("$value" in o) { flat[p] = o; return; } for (const [k, v] of Object.entries(o)) if (!k.startsWith("$")) walk(v, p ? p + "." + k : k); } };
walk(T, ""); const px = tok => tok && tok.$value && typeof tok.$value === "object" && tok.$value.unit === "px" ? tok.$value.value : null;
const heightTok = {}; const radiusTok = {};
for (const [p, tok] of Object.entries(flat)) { const v = px(tok); if (v === null) continue; if (/^size\./.test(p) && /Height$|^size\.(blobHeight|chipHeight)/.test(p)) (heightTok[v] = heightTok[v] || []).push(p); if (/^radius\./.test(p)) (radiusTok[v] = radiusTok[v] || []).push(p); }
const PICK = { "assistant-input": "size.assistantFieldHeight", "blob-face": "size.blobHeight", "sync-button": "size.blobHeight", "card-footer": "size.footerHeight", "card-header": "size.headerHeight", "lane-header": "size.headerHeight", "formatting-bar": "size.footerHeight", "recipient-row": "size.suggestionRowHeight" };
const out = []; const notes = { measuresAmbiguous: [], noElements: [] };
for (const name of Object.keys(parts).sort()) { const p = parts[name], b = byBau[name]; const cat = CAT(name);
  const measures = {};
  if (b) { for (const s of b.inlineSizes || []) { const m = s.match(/^height (\d+)$/); if (m) { const c = heightTok[m[1]]; if (c && c.length === 1) measures.height = "{" + c[0] + "}"; else if (c) { const o = PICK[name]; if (o && c.includes(o)) measures.height = "{" + o + "}"; else notes.measuresAmbiguous.push(name + " height " + m[1] + ": " + c.join(" | ")); } } }
    const r = (b.radius || []).map(x => x.replace("px", "")).find(x => radiusTok[x] && radiusTok[x].length === 1); if (r) measures.radius = "{" + radiusTok[r][0] + "}"; }
  const sn = (b && b.states && b.states.length ? b.states : ["rest"]).map(s => camel(String(s))).filter(Boolean);
  const comp = { part: name, name: pascal(name), category: cat, role: (b ? b.role : name.replace(/-/g, " ")).slice(0, 120), layer: "{layer." + (LAYER[name] || "lane") + "}", measures, states: [...new Set(sn)].map(s => ({ name: s, tokens: {} })), where: p.where.slice(0, 20), status: name === "confirm-pill" || name === "confirm" ? "approved-provisional" : "set-by-design" };
  if (name === "confirm-pill") { comp.source = "Johannes 18.10.: „2 ist erstmal als FREIGABE ORANGE Status abgenommen.“ Tooltip: " + (side.confirmTooltip ? side.confirmTooltip.$value : "system title") + " (Johannes 17.10.: „Komplett wie bei MacOS machen“)"; }
  if (cat === "pattern") comp.flow = PATTERN[name] || undefined;
  const seen = new Set(); const els = p.elements.filter(e => !seen.has(e.id) && seen.add(e.id)).map(e => ({ id: e.id, part: e.part, where: e.where }));
  if (els.length) comp.elements = els; else notes.noElements.push(name);
  out.push(comp); }
return { doc: { version: "2026-10-19", components: out }, notes };
