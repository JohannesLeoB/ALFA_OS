/* Export 19.10.2026 · T4: texts.json aus Vorlagen und Logik der vier Bögen. Aufruf: new Function('src', code)(src) → { doc, elementText, notes } */
const AREA = { "ALFA Mail.dc.html": "mail", "ALFA Einstellungen.dc.html": "settings", "ALFA Shell.dc.html": "shell", "ALFA Bestaetigen.dc.html": "shell" };
const camel = s => s.replace(/[^A-Za-z0-9]+(.)/g, (m, c) => c.toUpperCase()).replace(/^[A-Z]/, c => c.toLowerCase());
const decode = s => s.replace(/&amp;/g, "&").replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&quot;/g, '"');
const looks = s => /[A-Za-zÄÖÜäöüß]{2}/.test(s) && !/^(var\(|#|rgba?\(|M[0-9. -]|http|\d)/.test(s) && !/[{}=;]|px\b|\.js|\.css|dc\.html/.test(s) && s.length < 220;
const items = []; const dedupe = {}; const counters = {};
const add = (area, de, kind, o) => { de = decode(de).trim(); if (!de || !looks(de)) return; const dk = area + "|" + kind + "|" + de; if (dedupe[dk]) { const t = dedupe[dk]; if (o.element && !t.element) t.element = o.element; if (o.hint && !t.hint) t.hint = o.hint; return; } const t = { area, de, kind, element: o.element, hint: o.hint, where: o.where, via: o.via }; dedupe[dk] = t; items.push(t); };
const gaps = [];
for (const [f, text] of Object.entries(src)) {
  const area = AREA[f]; const a = text.indexOf("<x-dc>"), b = text.indexOf("</x-dc>"); const tpl = text.slice(a, b); const lineAt = idx => text.slice(0, a + idx).split("\n").length;
  const stack = []; const VOID = /^(input|br|img|path|i|circle|rect|svg|polyline|line)$/i;
  for (const m of tpl.matchAll(/<\/?[a-zA-Z][^>]*>|[^<]+/g)) { const tok = m[0]; const idx = m.index;
    if (tok[0] === "<") { if (tok[1] === "/") { stack.pop(); continue; }
      const tag = tok.match(/^<([a-zA-Z][\w-]*)/)[1]; const id = (tok.match(/data-id="([^"{}]+)"/) || [])[1];
      for (const am of tok.matchAll(/\s(title|aria-label|placeholder)="([^"]*)"/g)) { if (am[2].includes("{{")) { gaps.push(f + ":" + lineAt(idx) + " " + am[1] + " dynamisch"); continue; } if (am[1] === "aria-label" && stack.length && false) continue; add(area, am[2], am[1] === "placeholder" ? "placeholder" : "tooltip", { element: id || [...stack].reverse().map(s => s.id).find(Boolean), where: f + ":" + lineAt(idx), via: am[1] }); }
      if (!/\/>$/.test(tok) && !/^<(sc-if|sc-for|dc-import|svg|path|i|input|br)\b/i.test(tok) || /^<(sc-if|sc-for|dc-import|svg|input)\b/i.test(tok)) stack.push({ tag, id }); else if (/^<(path|i|br)\b/i.test(tok)) { /* explizit geschlossen */ stack.push({ tag, id }); }
    } else { const s = tok.replace(/\s+/g, " ").trim(); if (!s) continue; if (s.includes("{{")) { const st = s.replace(/\{\{[^}]*\}\}/g, "").trim(); if (/[A-Za-zÄÖÜäöüß]{3}/.test(st)) gaps.push(f + ":" + lineAt(idx) + " zusammengesetzt: " + s.slice(0, 50)); continue; }
      const owner = [...stack].reverse().find(x => x.id); add(area, s, owner && /button|a|label/.test(owner.tag) ? "button" : "label", { element: owner && owner.id, where: f + ":" + lineAt(idx), via: "text" }); }
  }
  const s0 = text.indexOf('<script type="text/x-dc"'); const logic = text.slice(s0); const lineL = idx => text.slice(0, s0 + idx).split("\n").length;
  const CALLS = [["mi", "menu"], ["tb", "button"], ["hb", "button"], ["toastIt", "feedback"], ["row", "label"], ["toggleRow", "label"], ["notice", "title"]];
  for (const [fn, kind] of CALLS) for (const m of logic.matchAll(new RegExp("(?:this\\.|\\b)" + fn + "\\((?:\"[a-z]+\", )?\"((?:[^\"\\\\]|\\\\.)*)\"(?:, (?:\"[a-z]+\", )?\"((?:[^\"\\\\]|\\\\.)*)\")?", "g"))) { if (fn === "notice") { const nm = logic.slice(m.index).match(/^notice\(\s*"[a-z]+",\s*"((?:[^"\\]|\\.)*)",\s*"((?:[^"\\]|\\.)*)"/) || logic.slice(m.index).match(/^this\.notice\(\s*"[a-z]+",\s*"((?:[^"\\]|\\.)*)",\s*"((?:[^"\\]|\\.)*)"/); if (nm) { add(area, nm[1], "title", { where: f + ":" + lineL(m.index) }); add(area, nm[2], "label", { where: f + ":" + lineL(m.index) }); } continue; } if (fn === "toggleRow") { const tm = logic.slice(m.index).match(/toggleRow\("((?:[^"\\]|\\.)*)", "[^"]*"(?:, ("(?:[^"\\]|\\.)*"))?/); if (tm) { add(area, tm[1], "label", { where: f + ":" + lineL(m.index) }); if (tm[2] && tm[2][0] === '"') add(area, tm[2].slice(1, -1), "label", { where: f + ":" + lineL(m.index) }); } continue; } add(area, m[1], kind, { where: f + ":" + lineL(m.index) }); }
  for (const m of logic.matchAll(/\b(label|text|title|sub|act|name|frage|question|ja|confirmLabel):\s*"((?:[^"\\]|\\.)*)"/g)) add(area, m[2].replace(/\\n/g, "\n"), /act|ja|confirmLabel/.test(m[1]) ? "button" : m[1] === "title" ? "title" : "label", { where: f + ":" + lineL(m.index) });
  for (const m of logic.matchAll(/\[(?:"[a-zA-Z0-9]+", )"((?:[^"\\]|\\.)*)"(?:, "[^"]*")?\]/g)) if (/^[A-ZÄÖÜ]/.test(m[1])) add(area, m[1], "label", { where: f + ":" + lineL(m.index) });
}
// keys
const used = new Set(); const texts = []; const elementText = {};
for (const t of items) { let key; if (t.element) { const rest = t.element.split(".").slice(1).map(camel).join("."); key = t.area + "." + rest + "." + (t.via === "title" ? "tooltip" : t.via === "aria-label" ? "aria" : t.via === "placeholder" ? "placeholder" : "text"); } else { counters[t.area + t.kind] = (counters[t.area + t.kind] || 0) + 1; key = t.area + "." + t.kind + ".s" + String(counters[t.area + t.kind]).padStart(3, "0"); }
  let k = key, n = 2; while (used.has(k)) k = key + n++; used.add(k);
  const o = { key: k, de: t.de, area: t.area, kind: t.kind, status: "set-by-design" }; if (t.element) o.element = t.element; texts.push(o);
  if (t.element && (t.via === "text") && !elementText[t.element]) elementText[t.element] = k; }
return { doc: { version: "2026-10-19", sourceLanguage: "de", texts }, elementText, notes: { gaps } };
