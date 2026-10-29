/* Export 19.10.2026 · T7 (Teil): akte.json-Felder aus den Dateien. Aufruf: new Function('akte','sizes','contract','answered', code)(...) → akte. W-01 Tokenzahl = Zählung im Vertrag, W-02 Bytes = Dateigrößen. werte-abgleich.json wird hier nicht erzeugt. */
const count = (o) => { let n = 0; const w = x => { if (x && typeof x === "object" && !Array.isArray(x)) { if ("$value" in x) { n++; return; } for (const [k, v] of Object.entries(x)) if (!k.startsWith("$")) w(v); } }; w(o); return n; };
akte.tokens = Object.entries(contract).filter(([k]) => k.endsWith(".tokens.json")).reduce((a, [, v]) => a + count(v), 0);
const paths = new Set(); for (const [k, v] of Object.entries(contract)) if (k.endsWith(".tokens.json")) { const w = (x, p) => { if (x && typeof x === "object" && !Array.isArray(x)) { if ("$value" in x) { paths.add(p); return; } for (const [kk, vv] of Object.entries(x)) if (!kk.startsWith("$")) w(vv, p ? p + "." + kk : kk); } }; w(v, ""); }
akte.tokensPfade = paths.size;
akte.vertrag = { tokenPfade: paths.size, ordner: "contract/", dateien: Object.keys(contract).length, tokens: akte.tokens, bauteile: contract["components.json"].components.length, elemente: contract["components.json"].components.reduce((a, c) => a + (c.elements || []).length, 0), texte: contract["texts.json"].texts.length, ansichten: contract["views.json"].views.length };
for (const s of akte.seiten) if (sizes[s.datei] !== undefined) s.bytes = sizes[s.datei];
akte.answered = answered;
akte.export = "2026-10-21";
return akte;
