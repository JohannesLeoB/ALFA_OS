/* Export 21.10.2026 · T7: werte-abgleich.json aus den Dateien (W-01, W-08). Aufruf: new Function('files', 'contract', code)(files, contract) → doc.
   files = { "ALFA Mail.dc.html": Text, "alfa-shell.js": Text, … }, contract = { "base.tokens.json": …, … }. Vergleicht jede px-, ms-, em- und Hexangabe in style-Attributen (dc.html) bzw. im Text (js, css) mit den Tokenwerten; var(…) und der GESPERRT-Stempel zählen nicht. */
const walk = (o, f) => { if (o && typeof o === "object" && !Array.isArray(o)) { if ("$value" in o) { f(o); return; } for (const [k, v] of Object.entries(o)) if (!k.startsWith("$")) walk(v, f); } };
const px = {}, ms = {}, em = {}, hex = {};
const path = (o, p, f) => { if (o && typeof o === "object" && !Array.isArray(o)) { if ("$value" in o) { f(o, p); return; } for (const [k, v] of Object.entries(o)) if (!k.startsWith("$")) path(v, p ? p + "." + k : k, f); } };
for (const [name, data] of Object.entries(contract)) if (name.endsWith(".tokens.json")) path(data, "", (t, p) => { const id = (name.startsWith("base") ? "" : name.replace(".tokens.json", "") + ":") + p; const v = t.$value;
  if (v && typeof v === "object" && "unit" in v) (v.unit === "px" ? px : ms)[v.value] = (v.unit === "px" ? px : ms)[v.value] || [], (v.unit === "px" ? px : ms)[v.value].push(id);
  else if (typeof v === "number" && p.startsWith("typography.tracking.")) (em[v] = em[v] || []).push(id);
  else if (typeof v === "string" && /^#[0-9a-fA-F]{6}$/.test(v)) { const k = v.toLowerCase(); (hex[k] = hex[k] || []).push(id); } });
const kindOf = f => f.endsWith(".dc.html") ? "bogen" : "code";
const entries = [], zus = {};
for (const [f, text] of Object.entries(files)) {
  const lines = text.split("\n"); let n = 0, ohne = 0;
  const scan = (s, i) => { s = s.replace(/var\([^)]*\)/g, "").replace(/\{\{[^}]*\}\}/g, "");
    for (const m of s.matchAll(/(?<![\w.-])(-?\d*\.?\d+)(px|ms|em)\b/g)) { const v = parseFloat(m[1]), t = m[2], map = t === "px" ? px : t === "ms" ? ms : em; const hit = map[v] || map[Math.abs(v)]; n++; if (!hit) ohne++; entries.push({ datei: f, zeile: i + 1, typ: t, wert: v, status: hit ? "token" : "ohneToken", tokenNachWert: hit || [] }); }
    for (const m of s.matchAll(/#[0-9a-fA-F]{6}\b/g)) { const k = m[0].toLowerCase(), hit = hex[k]; n++; if (!hit) ohne++; entries.push({ datei: f, zeile: i + 1, typ: "hex", wert: k, status: hit ? "token" : "ohneToken", tokenNachWert: hit || [] }); } };
  lines.forEach((l, i) => { if (l.includes("data-alfa-sperre")) return;
    if (f.endsWith(".dc.html")) { for (const m of l.matchAll(/\sstyle(?:-hover|-active|-focus|-before|-after)?="([^"]*)"/g)) scan(m[1], i); } else scan(l, i); });
  zus[f] = { kind: kindOf(f), werte: n, ohneToken: ohne };
}
return { export: "2026-10-21", stand: "2026-10-21", methode: "Jede px-, ms-, em-Angabe und 6-stellige Hexfarbe in style-Attributen (dc.html) bzw. im Text (js, css) gegen alle Tokenwerte in contract/*.tokens.json verglichen. status token heißt: Ein Token mit gleichem Wert existiert, nicht dass es das richtige ist. var(--…) zählt nicht. Der GESPERRT-Stempel ist ausgenommen. Nicht erfasst: Zahlen ohne Einheit in der Logik, rgba(), Verläufe, Deckkraft, SVG-Koordinaten.", zusammenfassung: zus, werte: entries };
