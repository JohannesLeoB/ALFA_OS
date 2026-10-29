/* ALFA Designsystem · Tokens (Arbeitsstand, nicht freigegeben). Je Token: [Wert, Quelle, Stand]. Stand "belegt" = aus Messung, Johannes' Wort oder bestehender Quelle; "vorschlag" = von Design gesetzt, wartet auf Johannes. Namen strikt englisch (entscheidungen.md: „2 - alles strikt englisch“). */
(function () {
  var IMG = "Bildschirmfoto 2026-09-20 um 17.29.32.png", RED = "a04779de….jpg", GLASS = "eba85170….jpg", GRAIN = "b3492d61….jpg";
  var T = {
    "color": {
      "ladder-1": ["#fbfbfb", IMG + " x300 y120", "belegt"],
      "ladder-2": ["#d4dbe3", IMG + " x300 y280", "belegt"],
      "ladder-3": ["#829cb3", IMG + " x300 y480", "belegt"],
      "ladder-4": ["#37506c", IMG + " x300 y580", "belegt"],
      "ladder-5": ["#091a2d", IMG + " x300 y720", "belegt"],
      "ladder-6": ["#02040d", IMG + " x300 y900", "belegt"],
      "rim-light": ["#dfe1e5", IMG + " Plattenkante x300 y214", "belegt"],
      "rim-shade": ["#c1c8cf", IMG + " Plattenschatten x300 y230", "belegt"],
      "edge": ["#59738e", IMG + " Kante Platte 3 x300 y377", "belegt"],
      "deep": ["#1f374e", IMG + " Kante Platte 4 x300 y521", "belegt"],
      "night-line": ["#202e45", IMG + " Kante Platte 5 x300 y649", "belegt"],
      "night-well": ["#102034", IMG + " Kante Platte 5 x300 y652", "belegt"],
      "air": ["#f3f7f8", IMG + " Grund x20 y500", "belegt"],
      "white": ["#ffffff", "entscheidungen.md 13L „Grund weiß“", "belegt"],
      "signal": ["#df2914", RED + " Balken x555 y300", "belegt"],
      "signal-soft": ["#d45c40", GRAIN + " x470 y420 · 4,51 : 1 auf ladder-5", "belegt"],
      "on-signal": ["#ffffff", "alfa-theme.css --c-on-signal", "belegt"],
      "type-blue": ["#4f78b1", GRAIN + " x1050 y560", "belegt"],
      "type-indigo": ["#544bbe", GRAIN + " x930 y520", "belegt"],
      "type-violet": ["#9452ac", GRAIN + " x800 y470", "belegt"],
      "type-teal": ["#547d85", GLASS + " x420 y420", "belegt"],
      "type-petrol": ["#173138", GLASS + " x80 y600", "belegt"],
      "type-amber": ["#f1bd64", GRAIN + " x100 y560", "belegt"],
      "orb-1": ["#050b25", GRAIN + " x600 y120", "belegt"],
      "orb-2": ["#155c69", GRAIN + " x820 y120", "belegt"],
      "orb-3": ["#9452ac", GRAIN + " x800 y470", "belegt"],
      "orb-4": ["#ce651d", GRAIN + " x90 y460", "belegt"],
      "orb-5": ["#f1bd64", GRAIN + " x100 y560", "belegt"]
    },
    "role-light": {
      "ground": ["white", "13L Grund weiß", "belegt"], "lane": ["white", "alfa-theme.css --c-lane", "belegt"],
      "well": ["air", "Vorschlag: Grund des Plattenbilds", "vorschlag"], "line": ["rim-light", "Plattenkante", "vorschlag"], "line-strong": ["rim-shade", "Plattenschatten", "vorschlag"],
      "ink": ["ladder-5", "16,95 : 1 auf ladder-1", "vorschlag"], "ink-2": ["ladder-4", "8,03 : 1", "vorschlag"], "ink-3": ["edge", "4,92 : 1 auf Weiß", "vorschlag"],
      "mark": ["edge", "Zeichen brauchen 3 : 1, ladder-3 hat nur 2,86", "vorschlag"], "grip": ["rim-shade", "Griff Haarlinie (13E)", "vorschlag"], "focus": ["edge", "", "vorschlag"],
      "hover": ["rgba(9,26,45,.05)", "ladder-5 · 5 %", "vorschlag"], "sel": ["rgba(9,26,45,.07)", "ladder-5 · 7 %", "vorschlag"],
      "inv": ["ladder-5", "Blob", "vorschlag"], "on-inv": ["ladder-1", "", "vorschlag"], "signal": ["signal", "nur Destruktives", "belegt"], "signal-ink": ["signal", "4,70 : 1 auf Weiß", "belegt"]
    },
    "role-dark": {
      "ground": ["ladder-6", "", "vorschlag"], "lane": ["ladder-5", "", "vorschlag"], "well": ["night-well", "", "vorschlag"],
      "line": ["night-line", "", "vorschlag"], "line-strong": ["ladder-4", "", "vorschlag"],
      "ink": ["ladder-1", "16,95 : 1 auf ladder-5", "vorschlag"], "ink-2": ["ladder-2", "12,56 : 1", "vorschlag"], "ink-3": ["ladder-3", "6,14 : 1", "vorschlag"],
      "mark": ["ladder-3", "3,56 : 1", "vorschlag"], "grip": ["ladder-4", "", "vorschlag"], "focus": ["ladder-3", "", "vorschlag"],
      "hover": ["rgba(251,251,251,.06)", "", "vorschlag"], "sel": ["rgba(251,251,251,.09)", "", "vorschlag"],
      "inv": ["ladder-1", "", "vorschlag"], "on-inv": ["ladder-5", "", "vorschlag"], "signal": ["signal", "nur Destruktives, als Fläche mit Weiß 4,70 : 1", "belegt"], "signal-ink": ["signal-soft", "Signal als Schrift: #df2914 hat auf ladder-5 nur 3,73 : 1", "vorschlag"]
    },
    "space": {
      "1": [4, "4er Leiter (13.10.)", "belegt"], "2": [8, "4er Leiter", "belegt"], "3": [12, "4er Leiter · Fuge", "belegt"], "4": [16, "4er Leiter · Rand", "belegt"],
      "5": [20, "4er Leiter", "belegt"], "6": [24, "4er Leiter", "belegt"], "7": [28, "Symbolknopf", "belegt"], "8": [32, "4er Leiter", "belegt"],
      "10": [40, "Blob Höhe", "belegt"], "11": [44, "Kopf", "belegt"], "12": [48, "4er Leiter", "belegt"], "14": [56, "Modul", "belegt"]
    },
    "grid": {
      "module": [56, "„56er Raster“ (13.10.)", "belegt"], "fold": [56, "1 Modul", "belegt"], "fold-at": [112, "„fold/unfold bei 56*2“", "belegt"],
      "lane-min-left": [224, "4 Module", "belegt"], "lane-rest-left": [280, "„Ruhe reiten 280“ · 5 Module", "belegt"], "lane-min-mid": [280, "5 Module", "belegt"],
      "lane-min-right": [280, "= Ruhe, damit links und rechts gleich sind · 5 Module", "belegt"], "lane-rest-right": [280, "Johannes 15.10.: „Wieso Rechts-Links unterschiedlich? Bitte vereinheitlichen auf 280“ · 5 Module", "belegt"],
      "window-1512": [1512, "27 Module", "belegt"], "avail-1512": [1456, "1512 − 2·16 − 2·12 = 26 Module", "belegt"]
    },
    "shell": {
      "margin": [16, "alfa-shell.js K.m", "belegt"], "gap": [12, "K.gap = Griffbreite", "belegt"], "safe-top": [32, "frame 1512 × 982", "belegt"],
      "blob-height": [40, "K.bh", "belegt"], "blob-width": [56, "K.bw", "belegt"], "blob-awake": [124, "K.awake · Mindestbreite, wächst mit dem Bereichsnamen", "belegt"], "blob-menu": [280, "ALFA Shell: offen = Breite der Bahn darunter (w[0] bzw. w[2]); Ruhe 280 = 5 × 56", "belegt"], "blob-menu-folded": [280, "Bahn darunter gefaltet: Ruhebreite K.rest, für Menü und Assistent · 5 × 56", "belegt"], "blob-dock": [36, "K.dock", "belegt"], "blob-face": [28, "Ring um die Augen", "belegt"], "blob-eye-w": [4, "Johannes 16.10.: Auge 4 × 8, Abstand 4 (Antwort zu „auf 4 bringen?“) · war 3,5", "belegt"], "blob-eye-h": [8, "Johannes 16.10.: Auge 4 × 8, Abstand 4 (Antwort zu „auf 8 heben?“) · war 7", "belegt"], "menu-row": [28, "Menüzeile", "belegt"], "menu-inset": [8, "Menü Innenrand", "belegt"], "assist-input": [40, "Eingabe Assistent", "belegt"], "orb": [20, "Denk-Orb", "belegt"],
      "lane-top": [100, "32 + 16 + 40 + 12", "belegt"], "head": [44, "Mail-Markup :14 :36 :125", "belegt"], "row": [36, "Kartenliste", "belegt"],
      "row-mail": [56, "1 Modul", "vorschlag"], "symbol": [28, "Symbolknopf", "belegt"], "inset": [8, "Kopf rechts, Karten, Knöpfe", "belegt"],
      "text-inset": [20, "inset 8 + Zeile 12: eine Textflucht für Kopf und Zeile", "vorschlag"],
      "grip-line": [1, "Haarlinie 13E", "belegt"], "grip-line-h": [64, "Handoff §3", "belegt"], "grip-active": [2, "Handoff §3", "belegt"], "grip-active-h": [96, "Handoff §3", "belegt"],
      "stack-step": [44, "Kartenkopf", "belegt"], "foot": [44, "Johannes 15.10.: Kartenfuß „genau den gleichen Kopf“", "belegt"], "chip": [24, "Kapsel, Anhang, Suchbereich", "belegt"], "suggestion-row": [44, "wie Empfängerzeile", "belegt"], "overview-tile-s": [144, "Übersicht Klein", "vorschlag"], "overview-tile-m": [176, "Übersicht Mittel", "vorschlag"], "overview-tile-l": [248, "Übersicht Groß", "vorschlag"], "overview-min-s": [200, "Übersicht Klein", "vorschlag"], "overview-min-m": [232, "Übersicht Mittel", "vorschlag"], "overview-min-l": [320, "Übersicht Groß", "vorschlag"], "blob-eye-gap": [4, "Johannes 16.10.: Abstand 4 · war 3,5", "belegt"]
    },
    "radius": {
      "lane": [20, "component-lane-radius", "belegt"], "blob": [20, "„BLOB mit 20er … gleichem Radius wie die Spalten“", "belegt"],
      "card": [20, "Johannes 15.10.: Karten im Stapel wie der Kopf, „als würde ein Stapel Skat-Karten leicht gegeneinander verschoben übereinander liegen“ · oben 20, unten 0", "belegt"], "row": [12, "lane 20 − inset 8", "vorschlag"],
      "symbol": [14, "28 rund", "belegt"], "chip": [6, "row 12 − 6", "vorschlag"], "pill": [999, "Bestätigen", "belegt"]
    },
    "type": {
      "family": ["Geist", "13N", "belegt"],
      "size-label": [11.5, "Knöpfe, Bestand", "belegt"], "size-body": [13, "Fenster 13 / 1,35", "belegt"], "size-title": [15, "", "vorschlag"],
      "size-heading": [20, "", "vorschlag"], "size-display": [28, "", "vorschlag"], "leading": [1.35, "Bestand", "belegt"],
      "weight-regular": [400, "", "belegt"], "weight-medium": [500, "", "belegt"], "tracking-display": ["-0.01em", "", "vorschlag"]
    },
    "stroke": { "hairline": [1, "13E", "belegt"], "icon": ["18.4 / size", "Handoff §2.4", "belegt"], "icon-16": [1.15, "Handoff §2.4", "belegt"] },
    "elevation": {
      "lane": ["0 0 0 1px var(--ds-line)", "--sh-lane", "belegt"],
      "float": ["0 0 0 1px rgba(9,26,45,.08), 0 8px 24px rgba(9,26,45,.12)", "--sh-float, Ton aus ladder-5", "vorschlag"],
      "plate": ["inset 0 1px 0 rgba(255,255,255,.7), inset 0 -1px 0 rgba(2,4,13,.10), 0 -1px 0 rgba(2,4,13,.06), 0 -10px 24px -14px rgba(9,26,45,.35)", "8a „gewölbter, getöpferter Rand“ nach " + IMG, "vorschlag"],
      "knob": ["0 1px 2px rgba(2,4,13,.2)", "--sh-knob", "belegt"]
    },
    "motion": {
      "overview-delay": [[0.3, "cubic-bezier(.2,.8,.2,1)"], "Kacheln warten auf die gefalteten Bahnen", "vorschlag"],
      "overview-enter": [[0.64, "cubic-bezier(.2,.8,.2,1)"], "Kachel blendet ein, 60 ms Versatz je Kachel", "vorschlag"],
      "tile-hover": [[0.32, "cubic-bezier(.2,.8,.2,1)"], "Kachel hebt sich, andere dimmen", "vorschlag"],
      "step-1": [[0.16, "cubic-bezier(.2,.8,.2,1)"], "Vorschlag, 4 Stufen statt 13. Ersetzt: fade 160, grip 150, label 200, press, snap", "vorschlag"],
      "step-2": [[0.26, "cubic-bezier(.2,.8,.2,1)"], "Vorschlag. Ersetzt: blob-width 240, lane 260, lids 320", "vorschlag"],
      "step-3": [[0.42, "cubic-bezier(.2,.8,.2,1)"], "Vorschlag. Ersetzt: reel-fade 360, fly 416, tape 480, stack 520", "vorschlag"],
      "step-4": [[0.72, "cubic-bezier(.2,.8,.2,1)"], "Vorschlag. Ersetzt: reel-tilt 600, ebb 720", "vorschlag"],
      "fade": [[0.16, "cubic-bezier(.2,.8,.2,1)"], "alfa-theme.css Faltschichten", "belegt"],
      "grip": [[0.15, "cubic-bezier(.2,.8,.2,1)"], "ALFA Shell.dc.html Griffstrich", "belegt"],
      "label": [[0.2, "cubic-bezier(.2,.8,.2,1)"], "ALFA Shell.dc.html Bereichsname im wachen Blob, Verzug 80 ms", "belegt"],
      "blob-width": [[0.24, "cubic-bezier(.2,.8,.2,1)"], "ALFA Shell.dc.html bTrans width, border-radius", "belegt"],
      "lane": [[0.26, "cubic-bezier(.2,.8,.2,1)"], "ALFA Shell.dc.html laneTrans", "belegt"],
      "lids": [[0.32, "cubic-bezier(.2,.8,.2,1)"], "ALFA Shell.dc.html Lider", "belegt"],
      "reel-fade": [[0.36, "cubic-bezier(.2,.8,.2,1)"], "ALFA Shell.dc.html Menüzeilen, Staffel 40 ms je Zeile", "belegt"],
      "fly": [[0.416, "cubic-bezier(.2,1.15,.3,1)"], "ALFA Shell.dc.html bTrans left, right, top", "belegt"],
      "tape": [[0.48, "cubic-bezier(.2,.8,.2,1)"], "ALFA Shell.dc.html Maßband der Suche", "belegt"],
      "stack": [[0.52, "cubic-bezier(.22,1.08,.36,1)"], "ALFA Mail.dc.html stackTrans", "belegt"],
      "reel-tilt": [[0.6, "cubic-bezier(.2,.8,.2,1)"], "ALFA Shell.dc.html Menüzeilen rotateX 60°, Perspektive 600", "belegt"],
      "ebb": [[0.72, "cubic-bezier(.65,0,.25,1)"], "ALFA Shell.dc.html laneTrans slow", "belegt"],
      "sync": [[2, "cubic-bezier(.2,.8,.2,1)"], "ALFA Shell.dc.html Bogen des Abgleichs", "belegt"],
      "press": [[0.18, 0.3], "Drücken, scale .92", "vorschlag"]
    },
    "z": { "page": [0, "", "belegt"], "lane": [1, "", "belegt"], "grip": [2, "", "belegt"], "sync": [9, "", "belegt"], "blob": [10, "", "belegt"], "safe": [30, "", "belegt"], "toast": [40, "", "belegt"] }
  };
  /* SwiftUI spring(duration, bounce) als CSS linear(); Dauer bis Ruhe. */
  function spring(d, b) {
    var w = 2 * Math.PI / d, z = 1 - b, wd = w * Math.sqrt(Math.max(0, 1 - z * z));
    function x(t) { return z >= 1 ? 1 - Math.exp(-w * t) * (1 + w * t) : 1 - Math.exp(-z * w * t) * (Math.cos(wd * t) + (z * w / wd) * Math.sin(wd * t)); }
    var T = d; while (T < d * 4) { var ok = true; for (var k = 0; k < 6; k++) if (Math.abs(1 - x(T + k * d / 20)) > 0.002) ok = false; if (ok) break; T += d / 20; }
    var n = 40, pts = []; for (var i = 0; i <= n; i++) pts.push(+(i === n ? 1 : x(T * i / n)).toFixed(4));
    return { ms: Math.round(T * 1000), ease: "linear(" + pts.join(", ") + ")", pts: pts };
  }
  /* Belegte Bewegung: feste Zeit und Kurve aus der Quelle. Feder (duration, bounce) nur für Vorschläge. */
  function bezier(d, curve) {
    var c = curve === "ease" ? [.25, .1, .25, 1] : curve === "linear" ? [0, 0, 1, 1] : String(curve).replace(/[^0-9.,\-]/g, "").split(",").map(Number), x1 = c[0], y1 = c[1], x2 = c[2], y2 = c[3];
    function b(t, a, c) { return 3 * a * t * (1 - t) * (1 - t) + 3 * c * t * t * (1 - t) + t * t * t; }
    var n = 40, pts = []; for (var i = 0; i <= n; i++) { var X = i / n, lo = 0, hi = 1; for (var k = 0; k < 30; k++) { var m = (lo + hi) / 2; if (b(m, x1, x2) < X) lo = m; else hi = m; } pts.push(+b((lo + hi) / 2, y1, y2).toFixed(4)); }
    return { ms: Math.round(d * 1000), ease: curve, pts: pts };
  }
  function motion(k) { var v = T.motion[k]; return typeof v[0][1] === "string" ? bezier(v[0][0], v[0][1]) : spring(v[0][0], v[0][1]); }
  /* Einzige Quelle für Maße, Radien, Abstände und Zeiten: TOKENBOGEN.json. Diese Datei hält nur Namen, Belege und Bilder. Abweichungen stehen in ALFA_DS.parity. */
  var MAP = {
    grid: { "fold": "size.foldedWidth", "fold-at": "size.foldThreshold", "lane-rest-left": "size.laneRestWidth", "lane-min-mid": "size.middleMinimumWidth", "lane-min-right": "size.laneMinimumRight", "lane-rest-right": "size.laneRestWidth" },
    shell: { "margin": "size.edge", "gap": "size.gutter", "blob-height": "size.blobHeight", "blob-width": "size.blobWidth", "blob-awake": "size.blobAwakeWidth", "blob-dock": "size.blobDockDistance", "blob-eye-w": "size.blobEyeWidth", "blob-eye-h": "size.blobEyeHeight", "blob-eye-gap": "size.blobEyeGap", "head": "size.headerHeight", "row": "size.rowHeight", "symbol": "size.symbolSize", "foot": "size.footerHeight", "chip": "size.chipHeight", "suggestion-row": "size.suggestionRowHeight", "overview-tile-s": "size.overviewTileHeightSmall", "overview-tile-m": "size.overviewTileHeightMedium", "overview-tile-l": "size.overviewTileHeightLarge", "overview-min-s": "size.overviewTileMinWidthSmall", "overview-min-m": "size.overviewTileMinWidthMedium", "overview-min-l": "size.overviewTileMinWidthLarge" },
    radius: { "lane": "radius.lane", "blob": "radius.blob", "card": "radius.card", "row": "radius.row", "pill": "radius.capsule" },
    space: { "1": "spacing.step4", "2": "spacing.step8", "3": "spacing.step12", "4": "spacing.step16", "5": "spacing.step20", "6": "spacing.step24", "7": "spacing.step28", "8": "spacing.step32", "10": "spacing.step40", "11": "spacing.step44", "14": "spacing.step56" }
  };
  var parity = { source: "TOKENBOGEN.json", read: false, changed: [], missing: [] };
  try {
    var x = new XMLHttpRequest(); x.open("GET", "TOKENBOGEN.json?v=" + Date.now(), false); x.send();
    if (x.status === 200 || x.responseText) {
      var TB = JSON.parse(x.responseText); parity.read = true;
      var get = function (p) { var o = TB; p.split(".").forEach(function (k) { o = o && o[k]; }); return o && o.$value && typeof o.$value === "object" ? o.$value.value : undefined; };
      Object.keys(MAP).forEach(function (g) { Object.keys(MAP[g]).forEach(function (k) {
        var v = get(MAP[g][k]), e = T[g] && T[g][k];
        if (v === undefined || !e) { parity.missing.push(g + "." + k + " ← " + MAP[g][k]); return; }
        if (e[0] !== v) { parity.changed.push(g + "." + k + ": " + e[0] + " → " + v); e[0] = v; }
        if (String(e[1]).indexOf("TOKENBOGEN.json") < 0) e[1] = e[1] + " · TOKENBOGEN.json " + MAP[g][k];
      }); });
    }
  } catch (err) { parity.error = String(err); }
  window.ALFA_DS = { T: T, spring: spring, bezier: bezier, motion: motion, parity: parity };
})();
