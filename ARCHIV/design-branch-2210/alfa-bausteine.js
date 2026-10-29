/* Export 19.10.2026 · ALFA Bausteine
   Gemeinsame Teile von ALFA Mail v2 und ALFA Einstellungen v2, genau einmal (global wie alfa-shell.js):
   Symbole, Ebenen der Karten, Gruppen, Dienste mit Zustand, Zustandswörter (csOf), Zeile/Hinweis/Textknopf,
   Menü (Breite, Lage, Öffnen, Eintrag), Toast, Kanten-Haarlinie, Falten/Ruhemaß (mem, setMem, lay, grow), Übersicht (ovAnim), Namen (ini, mid).
   Seiten setzen AREA, CARDS, FANNED und rufen mixInto(prototype) auf. */
(function () {
  const P = {
    search: "M7 12.5a5.5 5.5 0 1 0 0-11 5.5 5.5 0 0 0 0 11ZM11 11l3.5 3.5", filter: "M2.5 3.5h11l-4.25 5v4.5l-2.5-1.25V8.5Z",
    compose: "M11 2.5l2.5 2.5L6 12.5H3.5V10ZM9.5 4l2.5 2.5", inbox: "M2.5 9.5l1.5-6h8l1.5 6v3.5h-11ZM2.5 9.5h3l1 1.5h3l1-1.5h3",
    flag: "M4 14V2.5M4 3h7.5l-1.5 2.75L11.5 8.5H4", sent: "M14 2L7 9M14 2l-4.5 12-2.5-5-5-2.5Z", allMail: "M2.5 6.5h11v6h-11ZM4 4.5h8M5.5 2.5h5",
    archive: "M2.5 3.5h11v3h-11ZM3.5 6.5v6h9v-6M6.5 9h3", junk: "M5.5 2.5h5l3 3v5l-3 3h-5l-3-3v-5ZM8 5.5v3M8 10.75v.5",
    trash: "M3 4.5h10M6.5 4.5V3h3v1.5M4.5 4.5l.7 9h5.6l.7-9", tag: "M2.5 2.5h5.5l5.5 5.5-5.5 5.5-5.5-5.5ZM5.5 5.25v.5",
    reply: "M6.5 4L2.5 8l4 4M2.5 8h7a4 4 0 0 1 4 4v.5", replyAll: "M9 4L5 8l4 4M5 8h4.5a4 4 0 0 1 4 4v.5M5.5 4l-4 4 4 4",
    forward: "M9.5 4l4 4-4 4M13.5 8h-7a4 4 0 0 0-4 4v.5", fan: "M4.5 5.5h7v8h-7ZM5.5 3.5h5M6.5 1.5h3", send: "M8 13V3.5M4 7.5l4-4 4 4",
    close: "M4.5 4.5l7 7M11.5 4.5l-7 7", pin: "M8 10.5V14.5M5 10.5h6M5.75 10.5l.75-5h3l.75 5M6 2.5h4", more: "M5 8a1 1 0 1 1-2 0 1 1 0 0 1 2 0ZM9 8a1 1 0 1 1-2 0 1 1 0 0 1 2 0ZM13 8a1 1 0 1 1-2 0 1 1 0 0 1 2 0Z",
    gridS: "M2.5 2.5h3v3h-3ZM6.5 2.5h3v3h-3ZM10.5 2.5h3v3h-3ZM2.5 6.5h3v3h-3ZM6.5 6.5h3v3h-3ZM10.5 6.5h3v3h-3ZM2.5 10.5h3v3h-3ZM6.5 10.5h3v3h-3ZM10.5 10.5h3v3h-3Z", gridL: "M2.5 2.5h11v11h-11Z", grid: "M2.5 2.5h4.5v4.5h-4.5ZM9 2.5h4.5v4.5H9ZM2.5 9h4.5v4.5h-4.5ZM9 9h4.5v4.5H9Z", print: "M4.5 5.5v-3h7v3M4.5 11.5h-2v-5h11v5h-2M4.5 9h7v4.5h-7Z", export: "M8 2.5V10M4.5 6.5L8 10l3.5-3.5M3 13h10", attach: "M12.5 7.5l-4.75 4.75a3 3 0 0 1-4.25-4.25L8.5 3a2 2 0 0 1 2.83 2.83L6.5 10.66a1 1 0 0 1-1.41-1.41L9.5 4.83",
    folder: "M2.5 4.5h4l1.5 1.5h5.5v6.5h-11Z", person: "M8 7.5a2.5 2.5 0 1 0 0-5 2.5 2.5 0 0 0 0 5ZM3 13.5c.5-2.75 2.5-4 5-4s4.5 1.25 5 4",
    personAdd: "M6.5 7.5a2.5 2.5 0 1 0 0-5 2.5 2.5 0 0 0 0 5ZM2 13.5c.5-2.5 2.25-3.75 4.5-3.75s4 1.25 4.5 3.75M12.5 4.5v4M10.5 6.5h4",
    people: "M6 7a2 2 0 1 0 0-4 2 2 0 0 0 0 4ZM2.5 12.5c.4-2 1.75-3 3.5-3s3.1 1 3.5 3M10.5 7a2 2 0 1 0 0-4M11.5 9.6c1.2.3 2 1.2 2.25 2.9",
    bold: "M5 3h3.5a2.5 2.5 0 0 1 0 5H5ZM5 8h4a2.5 2.5 0 0 1 0 5H5Z", italic: "M7 3h5M4 13h5M10 3L6 13", underline: "M4.5 2.5v5a3.5 3.5 0 0 0 7 0v-5M3.5 13.5h9",
    list: "M6 4.5h7.5M6 8h7.5M6 11.5h7.5M2.5 4.5h1M2.5 8h1M2.5 11.5h1", numbered: "M6.5 4.5h7M6.5 8h7M6.5 11.5h7M2.5 3.5l1-.5v3",
    link: "M7 9a2.5 2.5 0 0 0 3.5 0l2-2A2.5 2.5 0 0 0 9 3.5l-.7.7M9 7a2.5 2.5 0 0 0-3.5 0l-2 2A2.5 2.5 0 0 0 7 12.5l.7-.7",
    textSize: "M2 12.5l3-8 3 8M3 10h4M10.5 12.5V9.5a1.75 1.75 0 0 1 3.5 0v3M10.5 11h3.5", save: "M8 2.5v7M5 6.5l3 3 3-3M2.5 10.5v3h11v-3",
    expand: "M9.5 2.5h4v4M6.5 13.5h-4v-4M13.5 2.5L9 7M2.5 13.5L7 9", shrink: "M13.5 2.5L10 6M10 3v3h3M2.5 13.5L6 10M6 13v-3H3", minus: "M4 8h8",
    check: "M3.5 8.5l3 3 6-7", building: "M3.5 13.5V2.5h6v11M9.5 6.5h3v7M2.5 13.5h11M5.5 5h2M5.5 8h2M5.5 11h2", docText: "M4 2h5l3 3v9H4ZM9 2v3h3M6.5 8h3M6.5 10.5h3",
    chevron: "M4.5 6.5L8 10l3.5-3.5", lock: "M4.5 7.5h7v6h-7ZM6 7.5V5.5a2 2 0 0 1 4 0v2", plug: "M5.5 2.5v3M10.5 2.5v3M4 5.5h8v2.5a4 4 0 0 1-8 0ZM8 12v1.5",
    contrast: "M8 13.5a5.5 5.5 0 1 0 0-11 5.5 5.5 0 0 0 0 11ZM8 2.5v11",
    system: "M8 10a2 2 0 1 0 0-4 2 2 0 0 0 0 4ZM8 1.5v2M8 12.5v2M1.5 8h2M12.5 8h2M3.4 3.4l1.4 1.4M11.2 11.2l1.4 1.4M3.4 12.6l1.4-1.4M11.2 4.8l1.4-1.4",
    envelope: "M2.5 4h11v8h-11ZM2.5 4.5L8 9l5.5-4.5", doc: "M4 2h5l3 3v9H4ZM9 2v3h3", alert: "M8 2.5l6 11H2ZM8 6.5v3M8 11.5v.25", key: "M5.5 10.5a3 3 0 1 0 0-6 3 3 0 0 0 0 6ZM8.5 7.5h5v2M11.5 7.5v2"
  };
  const LEVELS = {
    grau: { light: [["#f5f5f5", "#171717"], ["#ebebeb", "#171717"], ["#d9d9d9", "#171717"], ["#a3a3a3", "#171717"], ["#6b6b6b", "#ffffff"]], dark: [["#1f1f1f", "#fafafa"], ["#2e2e2e", "#fafafa"], ["#3a3a3a", "#fafafa"], ["#4d4d4d", "#fafafa"], ["#6b6b6b", "#fafafa"]] }
  };
  const GROUPS = [["Kommunikation", [["Mail", []]]], ["Kern", [["Einstellungen", []]]]];
  const SVC = [
    { id: "google", n: "Google", g: "Persönlich", use: "Mail, Dateien, Kalender, Kontakte", access: "Anmeldung im Browser", checks: true, fields: [], areas: [["Mail", "vor 4 Minuten", "Alle 5 Minuten"], ["Kontakte", "vor 1 Stunde", "Jede Stunde"], ["Dateien", "vor 12 Minuten", "Alle 15 Minuten"]], extras: [["Drive-Ordner der Projekte", "Jetzt abgleichen"]], mixed: "connected" },
    { id: "mailkonten", n: "Mail-Konten", g: "Persönlich", use: "Weitere Postfächer über IMAP und SMTP", access: "Benutzer und Passwort", fields: [], mixed: "notConnected", accounts: true },
    { id: "clickup", n: "ClickUp", g: "Persönlich", use: "Aufgaben", access: "Schlüssel", fields: [["Zugriffsschlüssel", "secret"]], areas: [["Phasen", "Noch nicht abgeglichen", "Manuell"], ["Aufgabenfelder", "Noch nicht abgeglichen", "Manuell"]], mixed: "connecting" },
    { id: "clockodo", n: "Clockodo", g: "Persönlich", use: "Zeiten", access: "E-Mail und Schlüssel", privat: true, fields: [["E-Mail", "jonas@studio-brenner.de"], ["Schlüssel", "secret"], ["Clockodo-Nutzer", "10482"]], mixed: "working" },
    { id: "claude", n: "Claude", g: "Persönlich", use: "Assistent", ai: true, access: "Schlüssel", fields: [["Schlüssel", "secret"], ["Modell", "Standard"]], mixed: "failed", reason: "Schlüssel abgelehnt (401)" },
    { id: "airtable", n: "Airtable", g: "Firma", use: "Projekte und Kunden", access: "Schlüssel", firma: true, fields: [["Base", "appR3x9Lm27Kq"], ["Zugriffsschlüssel", "secret"]], areas: [["Projekte", "vor 2 Stunden", "Manuell"]], extras: [["Zwischenspeicher", "Leeren"]], mixed: "stored" },
    { id: "sevdesk", n: "sevDesk", g: "Firma", use: "Belege und Angebote", access: "Schlüssel", firma: true, fields: [["Zugriffsschlüssel", "empty"]], mixed: "notConnected" },
    { id: "dhl", n: "DHL", g: "Firma", use: "Sendungen verfolgen, Etiketten kaufen", access: "Schlüssel", firma: true, fields: [["Tracking-Schlüssel", "secret"], ["Versand-Schlüssel", "secret"], ["Secret", "secret"], ["Benutzer", "empty"], ["Passwort", "secret"], ["Abrechnungsnummer", "empty"]], mixed: "stored" },
    { id: "happa", n: "Happa Happa", g: "Firma", use: "Speiseplan", access: "Schlüssel", firma: true, fields: [["Schlüssel", "secret"]], mixed: "connected" }
  ];
  const ME = ["Jonas Brenner", "jonas@studio-brenner.de"];
  const MAIL_UNREAD = { "Demo": 3, "Eine": 1, "Schlimmster Fall": 2, "1.284": 899 };
  const methods = {
    get P() { return P; }, get LEVELS() { return LEVELS; }, get GROUPS() { return GROUPS; },
    get K() { return window.AlfaShell.K; },
  still() { try { return matchMedia("(prefers-reduced-motion: reduce)").matches; } catch (e) { return false; } },
  root() { const w = this.winRef.current; return w ? w.closest('[data-part="area-page"]') : null; },
  anim() { const r = this.root(); if (r && !this.still()) r.querySelectorAll("[data-spin]").forEach(el => { if (!el._a && el.animate) el._a = el.animate([{ transform: "rotate(0deg)" }, { transform: "rotate(360deg)" }], { duration: this.tm("thinking"), iterations: Infinity }); }); },
  frame() { return window.AlfaShell.frame(this.props); },
  geo() { return window.AlfaShell.geo(this.frame()); },
  sc() { const r = this.root().getBoundingClientRect(); return { r, k: (r.width / this.geo().W) || 1 }; },
  pt(e) { const { r, k } = this.sc(); return [(e.clientX - r.left) / k, (e.clientY - r.top) / k]; },
  A() { return window.AlfaShell.AREA[this.AREA]; },
  D0() { return window.AlfaShell.D0(this.AREA); },
  mem() { return Object.assign(this.D0(), this.state.mem[this.AREA] || {}); },
  setMem(p) { this.setState(st => ({ mem: Object.assign({}, st.mem, { [this.AREA]: Object.assign(window.AlfaShell.D0(this.AREA), st.mem[this.AREA] || {}, p) }) })); },
  noCards() { return !this.state[this.CARDS].length; },
  lay() { return window.AlfaShell.layout(this.AREA, this.mem(), this.geo(), this.noCards() && this.state.ebb); },
  grow(side, v, w0) { this.setMem(window.AlfaShell.grow(this.AREA, side, v, w0)); },
  sync() {
    if (this.state.syncing) return;
    this.setState({ syncing: true });
    setTimeout(() => this.setState(st => Object.assign({ syncing: false }, this.onSynced ? this.onSynced(st) : null)), this.still() ? 400 : 2000);
  },
  tm(n) { return parseFloat(getComputedStyle(document.documentElement).getPropertyValue("--motion-duration-" + n)) || 0; },
  ez(n) { return getComputedStyle(document.documentElement).getPropertyValue("--motion-easing-" + n).trim() || "ease"; },
  toastIt(t, undo) { clearTimeout(this.tt); this.setState({ toast: t, toastUndo: undo || null, toastFail: false }); this.tt = setTimeout(() => this.setState({ toast: null, toastUndo: null }), this.tm(undo ? "toastUndo" : "toast")); },
  failIt(t, retry, label) { clearTimeout(this.tt); this.setState({ toast: t, toastUndo: retry || null, toastFail: true, toastAct: label || "Erneut versuchen" }); this.tt = setTimeout(() => this.setState({ toast: null, toastUndo: null, toastFail: false }), this.tm("toastFail")); },
  menuW(items) {
    const c = this._mc || (this._mc = document.createElement("canvas").getContext("2d")), fam = (this.props.typeface ?? "Geist") === "Geist" ? "Geist" : "-apple-system";
    let need = 0; for (const it of items) { if (!it.item && !it.head) continue; c.font = "400 13px " + fam; let n = c.measureText(it.label || "").width + 8; if (it.meta) { c.font = "400 11.5px " + fam; n += c.measureText(it.meta).width; } need = Math.max(need, n); }
    const R = 56, full = Math.ceil(4 + 12 + 12 + 8 + need + 12 + 4);
    return Math.min(5 * R, Math.max(3 * R, Math.ceil(full / R) * R));
  },
  menuX(ax, aw, w) {
    const g = this.geo(), K = this.K, wl = this.lay(), lefts = [K.m, K.m + wl[0] + K.gap, K.m + wl[0] + wl[1] + 2 * K.gap];
    const i = [2, 1, 0].find(j => ax >= lefts[j]) ?? 0, L0 = lefts[i], L1 = lefts[i] + wl[i], mid = ax + aw / 2;
    let x = mid < (L0 + L1) / 2 ? ax : ax + aw - w;
    if (x < L0 && L0 + w <= L1) x = L0; if (x + w > L1 && L1 - w >= L0) x = L1 - w;
    return Math.max(K.m, Math.min(x, g.W - w - K.m));
  },
  openMenu(e, items) {
    e.stopPropagation(); this._anchor = e.currentTarget; const w = this.menuW(items);
    const { r, k } = this.sc(), b = e.currentTarget.getBoundingClientRect(), g = this.geo(), h = items.length * 28 + 8;
    let y = (b.bottom - r.top) / k + 4; const x = this.menuX((b.left - r.left) / k, b.width / k, w);
    if (y + h > g.H - 16) y = (b.top - r.top) / k - h - 4;
    this.setState({ menu: { x, y, w, items } });
  },
  DRIVES: [["Mein Drive", ["Projekte", "Buchhaltung", "Vorlagen"]], ["Geteiltes Drive", ["Projekte", "Buchhaltung", "Material"]]],
  PFOLDERS: ["Pläne", "Angebote", "Fotos"],
  PFILES: { "Pläne": [["Grundriss_EG.pdf", "1,2 MB"], ["Schnitt_A.pdf", "640 KB"]], "Angebote": [], "Fotos": Array.from({ length: 11 }, (_, i) => ["Foto_" + String(i + 1).padStart(2, "0") + ".jpg", "2,4 MB"]) },
  tok(n, d) { const v = parseFloat(getComputedStyle(document.documentElement).getPropertyValue("--" + n)); return isNaN(v) ? d : v; },
  sub(items, w) { this.openMenu({ stopPropagation() {}, currentTarget: this._anchor }, items, w || 280); },
  projRoot() { const v = this.state.projectRoot; return v !== undefined ? v : (this.props.projectRoot === "nicht gewählt" ? null : "Geteiltes Drive · Projekte"); },
  pickRoot(e) { this.openMenu(e, [{ head: true, label: "Laufwerk" }].concat(this.DRIVES.map(d => this.mi(d[0], () => this.sub([{ head: true, label: d[0] }].concat(d[1].map(f => this.mi(f, () => { this.setState({ projectRoot: d[0] + " · " + f }); this.toastIt("Projektordner · " + d[0] + " · " + f); }, { check: this.projRoot() === d[0] + " · " + f }))), 260)))), 260); },
  noRoot(title) { this.sub([{ head: true, label: title }, this.mi("Kein Projektordner gewählt"), this.mi("Projektordner wählen …", () => this.goSettings("google"))], 280); },
  chooseProject(then, title) { const P = (this.LABELS || []).map(l => l[1]); this.sub([{ head: true, label: title || "Projekt" }].concat(P.map(p => this.mi(p, () => then(p)))), 260); },
  pickFile(onPick) { if (!this.projRoot()) { this.noRoot("Aus Projektordner"); return; }
    this.chooseProject(p => this.sub([{ head: true, label: p }].concat(this.PFOLDERS.map(f => this.mi(f, () => this.loadFiles(p, f, onPick), { meta: String(this.PFILES[f].length) }))), 260), "Aus Projektordner"); },
  loadFiles(p, f, onPick) { const head = { head: true, label: p + " · " + f }; this.sub([head, this.mi("Lädt …")]);
    clearTimeout(this._lf); this._lf = setTimeout(() => { if (!this.state.menu) return; const max = this.tok("count-projectFilesMax", 8), all = this.PFILES[f];
      if ((this.props.failure ?? "keine") === "Projektordner") { this.sub([head, this.mi("Ordner nicht geladen"), this.mi("Erneut versuchen", () => this.loadFiles(p, f, onPick))]); return; }
      if (!all.length) { this.sub([head, this.mi("Keine Dateien")]); return; }
      this.sub([head].concat(all.slice(0, max).map(x => this.mi(x[0], () => onPick(x), { meta: x[1] })), all.length > max ? [this.mi((all.length - max) + " weitere im Projektordner")] : [])); }, 600); },
  edgePulse(k) { if (!this.state[k + "Edge"]) this.setState({ [k + "Edge"]: true }); clearTimeout(this["_ep" + k]); this["_ep" + k] = setTimeout(() => this.setState({ [k + "Edge"]: false }), this.K.scrollLineRest); },
  edgeTr(on) { return "opacity " + (on ? this.K.scrollLineIn : this.K.scrollLineOut) + "ms cubic-bezier(.2,.8,.2,1)"; },
  mi(label, fn, o) { o = o || {}; return { item: true, label, check: o.check ? "✓" : "", meta: o.meta || "", fg: o.danger ? "var(--c-signal)" : "var(--c-ink)", go: e => { e.stopPropagation(); this.setState({ menu: null }); fn && fn(); } }; },
  tb(label, kind, go, o) {
    o = o || {};
    const v = { accent: ["var(--c-inv)", "var(--c-on-inv)", "none"], neutral: ["transparent", "var(--c-ink)", "inset 0 0 0 1px var(--c-line-strong)"], signal: ["transparent", "var(--c-signal)", "inset 0 0 0 1px var(--c-signal)"], plain: ["transparent", "var(--c-ink-2)", "none"] }[kind || "neutral"];
    return { label, state: o.off ? "disabled" : kind || "neutral", bg: v[0], fg: v[1], ring: v[2], op: o.off ? .4 : 1, cur: o.off ? "default" : "pointer", go: e => { if (e) e.stopPropagation(); if (!o.off && go) go(); } };
  },
  ini(n) { const w = String(n || "").trim().replace(/^An\s+(?=\S+\s+\S)/, "").split(/\s+/).filter(x => /\p{L}/u.test(x) && !/^(II|III|IV|Jr\.?|Sr\.?|de|la|del|y|von|van|der|den|da|di|du)$/i.test(x)); if (!w.length) return ""; const f = x => (this.gr(x.replace(/^[^\p{L}]+/u, ""))[0] || "").toUpperCase(); return w.length === 1 ? f(w[0]) : f(w[0]) + f(w[w.length - 1]); },
  gr(s) { try { return Array.from(new Intl.Segmenter("de", { granularity: "grapheme" }).segment(s), x => x.segment); } catch (e) { return Array.from(s); } },
  nf(n) { return new Intl.NumberFormat("de-DE").format(n || 0); },
  mid(s, n) { s = String(s || ""); const g = this.gr(s); if (g.length <= n) return s; const a = Math.ceil((n - 1) * .55), b = n - 1 - a; return g.slice(0, a).join("") + "…" + g.slice(g.length - b).join(""); },
  slowly() { const K = window.AlfaShell.K; clearTimeout(this._ovT); this.setState({ slowLane: true }); this._ovT = setTimeout(() => this.setState({ slowLane: false }), K.ebbSlow + 80); },
  ovAnim() { const st0 = this.state, FN = this.FANNED, mail = this.AREA === "Mail"; if (st0[FN] && !(mail && st0.ovMode === "folder") && !st0[this.CARDS].length) { this.setState({ [FN]: false }); return; } const o = !!st0[FN], was = !!this._ovO; if (o === was) return; this._ovO = o; const AS = window.AlfaShell;
    this.slowly();
    if (o) { this._ovPrev = Object.assign({}, this.mem()); const need = this.ovNeed ? this.ovNeed() : 0; let pick = { max: 2 };
      if (need) { const g = this.geo(), base = { max: -1, Rf: false, R: Math.max(this._ovPrev.R || 0, need) }, Y = (AS.AREA[this.AREA].yield || [0, 1]).filter(i => i !== 2), tries = [{}]; let acc = {}; Y.forEach(i => { acc = Object.assign({}, acc, { [["Lf", "Mf"][i]]: true }); tries.push(acc); });
        const hit = tries.find(t => { const c = Object.assign({}, this._ovPrev, base, t); return AS.layout(this.AREA, c, g)[2] >= need - 1; }); if (hit) pick = Object.assign({}, base, hit); }
      this.setMem(pick); }
    else { const p = this._ovPrev || AS.D0(this.AREA); this.setMem({ max: -1, L: p.L, M: p.M, R: p.R, Lf: p.Lf, Mf: p.Mf, Rf: p.Rf, pin: p.pin }); }
    if (o && !this.still()) { const r = this.root(); r && r.querySelectorAll('[data-part="overview-tile"]').forEach((el, i) => el.animate && el.animate([{ opacity: 0, transform: "translateY(6px)" }, { opacity: 1, transform: "none" }], { duration: this.tm("overviewEnter"), delay: this.tm("overviewDelay") + Math.min(i, 8) * this.tm("overviewStagger"), easing: "cubic-bezier(.33,0,.15,1)", fill: "backwards" })); } },
  csOf(st) {
    const M = {
      connected: ["Verbunden", "var(--c-ink)", "1px solid var(--c-ink)", "var(--c-ink-2)"],
      stored: ["Schlüssel gespeichert", "linear-gradient(90deg,var(--c-ink) 50%,transparent 50%)", "1px solid var(--c-ink)", "var(--c-ink-2)"],
      connecting: ["Verbindet …", "transparent", "1px solid var(--c-line-strong)", "var(--c-ink-2)", true],
      working: ["Gleicht ab …", "transparent", "1px solid var(--c-line-strong)", "var(--c-ink-2)", true],
      notConnected: ["Nicht verbunden", "transparent", "1px solid var(--c-line-strong)", "var(--c-ink-3)"],
      failed: ["Fehler", "var(--c-signal)", "1px solid var(--c-signal)", "var(--c-signal)"],
      unreadable: ["Schlüsselbund nicht lesbar", "transparent", "1px solid var(--c-signal)", "var(--c-signal)"]
    }[st] || ["", "transparent", "none", "var(--c-ink-3)"];
    return { state: st, text: M[0], fill: M[1], border: M[2], fg: M[3], spin: !!M[4] };
  },
  row(label, o) { return Object.assign({ isRow: true, label, line: true, state: "rest", hasSub: !!(o && o.sub), hasCs: !!(o && o.cs), hasVal: !!(o && o.val != null && o.val !== ""), vFg: "var(--c-ink-2)", vFont: "inherit", vSize: "13px", hasKeys: !!(o && o.keys), hasPill: !!(o && o.pill), hasSeg: !!(o && o.seg), hasToggle: !!(o && o.toggle), hasBtns: !!(o && o.btns && o.btns.length), hasInput: !!(o && o.onIn), inType: "text", hasConfirm: !!(o && o.cq), cd: this.P.trash }, o || {}); },
  toggleRow(label, k, sub) { const on = !!this.state.toggles[k]; return this.row(label, { sub, toggle: () => this.tog(k), tState: on ? "on" : "off", tBg: on ? "var(--c-ink)" : "transparent", tRing: on ? "none" : "inset 0 0 0 1px var(--c-line-strong)", tX: on ? "14px" : "2px", kBg: on ? "var(--c-lane)" : "var(--c-ink-3)" }); },
  notice(kind, title, text, btns) { const fg = kind === "failure" ? "var(--c-signal)" : kind === "success" ? "var(--c-ink)" : "var(--c-ink-2)"; return { isNotice: true, kind, title, text, fg, d: kind === "success" ? this.P.check || "M3.5 8.5l3 3 6-7" : this.P.alert, hasBtns: !!(btns && btns.length), btns: btns || [] }; },
  svc(id) { return this.SVC.find(x => x.id === id); },
  svcStates(mode) { const o = {}; this.SVC.forEach(x => { o[x.id] = mode === "Erststart" ? "notConnected" : x.mixed; }); return o; },
  onLScroll(e) { const sc = e.currentTarget.scrollTop > 0; if (sc) this.edgePulse("l"); if (sc !== !!this.state.lScrolled) this.setState({ lScrolled: sc }); },
  mark() { const r = this.root(); if (!r) return; r.querySelectorAll("[data-mark]").forEach(e => { e.style.outline = ""; e.style.outlineOffset = ""; e.removeAttribute("data-mark"); }); const sel = this.props.highlight; if (!sel) return; try { r.querySelectorAll(sel).forEach(e => { e.setAttribute("data-mark", "1"); e.style.outline = "2px solid var(--c-focus)"; e.style.outlineOffset = "-2px"; }); } catch (x) {} }
  };
  window.AlfaBausteine = { P, LEVELS, GROUPS, SVC, ME, methods, mailUnread(d) { return MAIL_UNREAD[d] ?? MAIL_UNREAD.Demo; },
    mixInto(proto) { Object.defineProperties(proto, Object.getOwnPropertyDescriptors(methods)); } };
})();
