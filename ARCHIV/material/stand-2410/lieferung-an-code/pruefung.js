/* Export 19.10.2026 · ALFA Prüfskript. Prüft die Design-Akte gegen TOKENBOGEN.json. Ändert nichts.
   Node:    node lieferung-an-code/pruefung.js            (im Projektordner)
   Browser: pruefe(async p => (await fetch(p)).text()).then(console.log)
   Ergebnis: { gruen, fehler: [...], hinweise: [...], zahlen: {...} } */
(function (root) {
  const APP = ["ALFA Mail.dc.html", "ALFA Einstellungen.dc.html", "alfa-bausteine.js", "ALFA Shell.dc.html", "ALFA Bestaetigen.dc.html"];
  const BOGEN = ["ALFA Designsystem.dc.html", "ALFA Dienste.dc.html", "ALFA Entscheidungen.dc.html", "ALFA Farbsystem.dc.html", "ALFA Huelle.dc.html", "ALFA Tokenbogen.dc.html"];
  const DOKU = ["entscheidungen.md", "alfa-shell.js", "alfa-theme.css", "TOKENBOGEN.json", "INHALT.json", "lieferung-an-code/akte.json", "lieferung-an-code/motion-springs.json", "lieferung-an-code/settings-sections.json", "lieferung-an-code/werte-abgleich.json"];
  const STATUS = ["approved", "approved-provisional", "set-by-design"];
  const DE = /[äöüÄÖÜß]|(?:^|[A-Z_.-])(?:breite|hoehe|zeile|kopf|rand|fuge|bereich|licht|grund|schrift|griff|stapel|gesicht|einstellung|dienste|daten|vorne|entwurf|empfaenger|markiere|symbole|oberflaeche)/i;

  async function pruefe(read) {
    const fehler = [], hinweise = [], zahlen = {};
    const T = JSON.parse(await read("TOKENBOGEN.json"));
    const tokens = [];
    (function walk(o, p) { if (!o || typeof o !== "object") return; if ("$value" in o) { tokens.push([p, o]); return; } for (const k in o) if (k[0] !== "$") walk(o[k], p ? p + "." + k : k); })(T, "");
    zahlen.tokens = tokens.length;
    const num = new Set(), hex = new Set(), layer = new Set();
    for (const [p, o] of tokens) if (p.startsWith("layer.")) layer.add(o.$value);
    for (const [, o] of tokens) {
      const v = o.$value;
      if (typeof v === "number") num.add(v);
      else if (v && typeof v === "object") {
        if (typeof v.value === "number") num.add(v.value);
        if (v.hex) hex.add(v.hex.toLowerCase());
        if (Array.isArray(v)) v.forEach(s => { for (const q of ["offsetY", "blur", "spread"]) if (s && s[q]) num.add(Math.abs(s[q].value)); });
        if (typeof v.light === "string") hex.add(v.light.toLowerCase());
        if (Array.isArray(v)) v.forEach(s => s && s.color && s.color.hex && hex.add(s.color.hex.toLowerCase()));
      }
    }
    // 1 Beleg je Token
    const ohneBeleg = [], status = {};
    for (const [p, o] of tokens) {
      const a = (o.$extensions && o.$extensions.alfa) || {};
      if (a.status) { status[a.status] = (status[a.status] || 0) + 1; if (!STATUS.includes(a.status)) fehler.push("Status unbekannt: " + p + " = " + a.status); }
      if (a.status === "set-by-design" && !a.where) fehler.push("set-by-design ohne Fundstelle: " + p);
    }
    zahlen.status = status;
    const worte = (await read("entscheidungen.md")).replace(/\s+/g, " ");
    const norm = x => x.replace(/\s+/g, " ");
    let belegt = 0, unbelegt = [];
    for (const [p, o] of tokens) {
      const a = (o.$extensions && o.$extensions.alfa) || {};
      if (a.status !== "approved" && a.status !== "approved-provisional") continue;
      const txt = [a.source, a.approval].filter(Boolean).join(" ");
      const quotes = [...txt.matchAll(/„([^“]{12,})“/g)].map(m => norm(m[1]).replace(/ …$/, "").split(" … ")[0].split("…")[0].trim());
      if (!quotes.length) { unbelegt.push(p + " (kein Zitat im Feld source)"); continue; }
      if (quotes.some(q => worte.includes(q))) belegt++; else unbelegt.push(p + " (Zitat nicht wörtlich in entscheidungen.md)");
    }
    zahlen.belegt = belegt; zahlen.unbelegt = unbelegt.length;
    for (const u of unbelegt) hinweise.push("Beleg prüfen: " + u);
    // 2 Namen englisch
    for (const [p] of tokens) if (DE.test(p.split(".").pop())) fehler.push("Token-Name nicht englisch: " + p);
    // 3 Werte im Markup der App-Bögen
    let werte = 0, ohneToken = 0;
    for (const f of APP) {
      const L = (await read(f)).split("\n");
      L.forEach((l, i) => {
        if (/data-props=/.test(l)) {
          const m = l.match(/data-props="([^"]*)"/); if (m) { const j = JSON.parse(m[1].replace(/&quot;/g, '"').replace(/&amp;/g, "&")); for (const k in j) if (k[0] !== "$" && DE.test(k)) fehler.push("Prop nicht englisch: " + f + " " + k); }
          return;
        }
        for (const m of l.matchAll(/(-?\d+(?:\.\d+)?)px/g)) { const v = Math.abs(+m[1]); if (!v) continue; werte++; if (!num.has(v)) { ohneToken++; fehler.push("px ohne Token: " + f + ":" + (i + 1) + " " + v); } }
        for (const m of l.matchAll(/(\d+)ms\b/g)) { werte++; if (!num.has(+m[1])) { ohneToken++; fehler.push("ms ohne Token: " + f + ":" + (i + 1) + " " + m[1]); } }
        for (const m of l.matchAll(/#[0-9a-fA-F]{6}\b/g)) { werte++; if (!hex.has(m[0].toLowerCase())) { ohneToken++; fehler.push("Farbe ohne Token: " + f + ":" + (i + 1) + " " + m[0]); } }
        for (const m of l.matchAll(/z-index:\s*(\d+)/g)) { werte++; if (!layer.has(+m[1])) { ohneToken++; fehler.push("Ebene ohne layer-Token: " + f + ":" + (i + 1) + " z " + m[1]); } }
        for (const m of l.matchAll(/data-part="([^"{]+)"/g)) if (DE.test(m[1])) fehler.push("data-part nicht englisch: " + f + ":" + (i + 1) + " " + m[1]);
      });
    }
    zahlen.werteApp = werte; zahlen.werteOhneToken = ohneToken;
    // 4 alfa-theme.css gegen Tokenbogen
    const css = await read("alfa-theme.css");
    for (const m of css.matchAll(/(--c-[\w-]+):(#[0-9a-fA-F]{6})/g)) if (!hex.has(m[2].toLowerCase())) fehler.push("alfa-theme.css " + m[1] + " " + m[2] + " nicht im Tokenbogen");
    // 5 Exportvermerk
    for (const f of APP.concat(BOGEN)) if (!/name="alfa-export"|Export 19\.10\.2026/.test(await read(f))) fehler.push("Exportvermerk fehlt: " + f);
    for (const f of DOKU) { const s = await read(f); if (!/Export:? ?(1[89]|2[01])\.10\.2026|"export":\s*"2026-10-(1[89]|2[01])"|Export (1[89]|2[01])\.10\.2026/.test(s)) fehler.push("Exportvermerk fehlt: " + f); }
    hinweise.push("Nicht geprüft: Rolle eines Werts (nur Wertgleichheit), Zahlen ohne Einheit in der Logik (siehe werte-abgleich.json Teil logik), Bild und Maße im Render.");
    return { gruen: fehler.length === 0, fehler, hinweise, zahlen };
  }
  if (typeof module !== "undefined" && module.exports) {
    module.exports = { pruefe };
    if (require.main === module) { const fs = require("fs"); pruefe(async p => fs.readFileSync(p, "utf8")).then(r => { console.log(JSON.stringify(r, null, 1)); process.exit(r.gruen ? 0 : 1); }); }
  } else root.pruefe = pruefe;
})(typeof window !== "undefined" ? window : globalThis);
