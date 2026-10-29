/* Export 18.10.2026 */
/* ALFA Shell · Rechenregeln der Hülle · Stand 27.10.2026. Werte nur aus alfa-theme.css (Tokens). Minima 280/280/280 (Johannes 15.10.: „Bitte vereinheitlichen auf 280“). Einzige Quelle der Rechenregeln. Gelesen von ALFA Shell.dc.html und von jedem Bereich, der in die Hülle gesetzt wird. */
(function () {
  /* 27.10.: alle Maße und Zeiten aus alfa-theme.css (Tokens, Brief A1); keine Zahl mehr hier. Liest beim Zugriff, merkt sich gültige Werte. */
  var V = {};
  function rd(n) { var v = V[n]; if (v === undefined || isNaN(v)) { v = parseFloat(getComputedStyle(document.documentElement).getPropertyValue("--" + n)); if (!isNaN(v)) V[n] = v; else wait(); } return v; }
  /* alfa-theme.css noch nicht geladen: warten, dann einmal "alfa-tokens" melden, damit Hülle und Bereiche neu rechnen */
  var waiting = false;
  function wait() { if (waiting) return; waiting = true; (function poll() { if (isNaN(parseFloat(getComputedStyle(document.documentElement).getPropertyValue("--size-edge")))) return setTimeout(poll, 16); waiting = false; window.dispatchEvent(new Event("alfa-tokens")); setTimeout(function () { document.documentElement.removeAttribute("data-alfa-boot"); }, 600); })(); }
  var KN = { m: "size-edge", gap: "size-gutter", bh: "size-blobHeight", bw: "size-blobWidth", awake: "size-blobAwakeWidth", dock: "size-blobDockDistance", rest: "size-laneRestWidth", fold: "size-foldedWidth", foldAt: "size-foldThreshold", snap: "size-laneSnap", hy: "size-laneHysteresis", safe: "size-safeAreaTop", ebbDelay: "motion-duration-ebbDelay", ebbSlow: "motion-duration-ebbSlow", scrollLineIn: "motion-duration-scrollLineIn", scrollLineRest: "motion-duration-scrollLineRest", scrollLineOut: "motion-duration-scrollLineOut" };
  var K = {}; Object.keys(KN).forEach(function (k) { Object.defineProperty(K, k, { enumerable: true, get: function () { return rd(KN[k]); } }); });
  var MINS = function () { return [rd("size-laneMinimumLeft"), rd("size-middleMinimumWidth"), rd("size-laneMinimumRight")]; };
  var AREA = {
    Mail: { get L() { return [K.rest]; }, get R() { return [K.rest]; }, get min() { var m = MINS(); return [rd("size-mailLaneMinimumLeft"), m[1], m[2]]; }, get max() { return [rd("size-mailLaneMaximumLeft"), 0, 0]; }, yield: [0, 1, 2] },
    Einstellungen: { get L() { return [K.rest]; }, get R() { return [K.rest]; }, get min() { return MINS(); }, yield: [0, 1, 2] }
  };
  function frame(p) {
    if (p.windowWidth && p.windowHeight) return { W: p.windowWidth, H: p.windowHeight, safe: 0 };
    if (p.window === "1512 × 982") return { W: rd("size-previewWindowWidth"), H: rd("size-previewWindowHeight"), safe: K.safe };
    return { W: Math.max(rd("size-previewMinWidth"), window.innerWidth), H: Math.max(rd("size-previewMinHeight"), window.innerHeight), safe: 0 };
  }
  function geo(f) {
    var top = f.safe + K.m;
    return Object.assign({}, f, { top: top, lt: top + K.bh + K.gap, lh: f.H - (top + K.bh + K.gap) - K.m, avail: f.W - 2 * K.m - 2 * K.gap });
  }
  function D0(area) { var A = AREA[area]; return { L: A.L[0], M: 0, R: A.R[0], Lf: false, Mf: false, Rf: false, pin: false, max: -1 }; }
  function layout(area, s, g, foldRight) {
    var A = AREA[area];
    if (s.max >= 0) { var w0 = [K.fold, K.fold, K.fold]; w0[s.max] = g.avail - 2 * K.fold; return w0; }
    var FL = A.min, pref = [s.L, s.M, s.R];
    function solve(fd) {
      var open = [0, 1, 2].filter(function (i) { return !fd[i]; }), w = [K.fold, K.fold, K.fold];
      if (!open.length) return w;
      var av = g.avail - K.fold * (3 - open.length), flex = open.includes(1) ? 1 : open.includes(2) ? 2 : 0, p = {};
      var used = 0; open.forEach(function (i) { if (i !== flex && pref[i] > 0) { p[i] = pref[i]; used += p[i]; } });
      open.forEach(function (i) { if (p[i] === undefined) p[i] = Math.max(av - used, FL[i]); });
      if (s.pin && p[flex] === undefined) p[flex] = av;
      var free = open.slice(), rem = av;
      for (var n = 0; n < 4 && free.length; n++) {
        var f = rem / free.reduce(function (q, i) { return q + p[i]; }, 0), hit = false;
        free.slice().forEach(function (i) { var fl = Math.min(p[i], FL[i]); if (p[i] * f < fl) { w[i] = fl; rem -= fl; free = free.filter(function (x) { return x !== i; }); hit = true; } });
        if (!hit) { free.forEach(function (i) { w[i] = p[i] * f; }); free = []; }
      }
      if (rem < -.5 && open.length > 1) { var nf = fd.slice(); nf[A.yield.find(function (i) { return !fd[i]; })] = true; return solve(nf); }
      var r = w.map(Math.round), fx = open.includes(flex) ? flex : open[0];
      open.forEach(function (i) { if (i !== fx) r[i] = Math.max(FL[i], r[i]); });
      r[fx] = g.avail - r.reduce(function (q, x, i) { return q + (i === fx ? 0 : x); }, 0);
      if (r[fx] < FL[fx] - .5 && open.length > 1) { var nf2 = fd.slice(); nf2[A.yield.find(function (i) { return !fd[i]; })] = true; return solve(nf2); }
      return r;
    }
    var fd = [s.Lf, s.Mf, s.Rf || !!foldRight];
    if (fd[0] && fd[1] && fd[2]) fd[1] = false; /* nie alle drei gefaltet: die Mitte bleibt offen (Johannes 24.10., Fund Ebbe) */
    return solve(fd);
  }
  /* Akkordeon nach Arbeit: die unwichtigste Bahn gibt zuerst nach. Liefert den Patch für den Speicher der Bahnen. */
  function grow(area, side, v, w0) {
    var A = AREA[area], MIN = A.min, o = side === "L" ? 0 : 2, nm = ["L", "M", "R"], fk = ["Lf", "Mf", "Rf"], HY = K.hy, q;
    if (v < K.foldAt) { q = { max: -1 }; q[fk[o]] = true; return q; }
    var oo = 2 - o; if (w0[oo] > K.fold && Math.abs(v - w0[oo]) < K.snap) v = w0[oo];
    if (A.max && A.max[o] && v > A.max[o]) v = A.max[o];
    var order = A.yield.filter(function (i) { return i !== o; }), w = w0.slice(), f = w0.map(function (x) { return x <= K.fold; });
    w[o] = Math.round(v); f[o] = false;
    var need = w[o] - w0[o];
    if (need > 0) {
      for (var a = 0; a < order.length; a++) { var i = order[a]; if (need <= 0) break; if (f[i]) continue;
        var room = w[i] - MIN[i], take = Math.min(room, need); w[i] -= take; need -= take;
        if (need > HY) { need -= w[i] - K.fold; w[i] = K.fold; f[i] = true; } else if (need > 0) { w[o] -= need; need = 0; } }
      if (need > 0) w[o] -= need;
    } else {
      var give = -need, rev = order.slice().reverse();
      for (var b = 0; b < rev.length; b++) { var j = rev[b]; if (!f[j] || j === o) continue; if (give >= MIN[j] - K.fold + HY) { give -= MIN[j] - K.fold; w[j] = MIN[j]; f[j] = false; } }
    }
    var p = { pin: true, max: -1 };
    [0, 1, 2].forEach(function (k) { p[nm[k]] = f[k] ? (w0[k] > K.fold ? w0[k] : MIN[k]) : Math.round(w[k]); p[fk[k]] = f[k]; });
    if (!f[1]) p.M = 0;
    return p;
  }
  /* Ebbe: die rechte Bahn faltet, wenn der Stapel leer ist (nach ebbDelay), Übergang langsam für ebbSlow. Schreibt ebb / slowLane in den State des Besitzers. */
  function ebb(host, empty, still) {
    if (empty === host._ebE) return; host._ebE = empty; clearTimeout(host._ebT); clearTimeout(host._ebT2);
    var slow = function () { host.setState({ slowLane: true }); host._ebT2 = setTimeout(function () { host.setState({ slowLane: false }); }, K.ebbSlow); };
    if (empty && !still) host._ebT = setTimeout(function () { host.setState({ ebb: true }); slow(); }, K.ebbDelay);
    else if (empty) host.setState({ ebb: true });
    else if (host.state.ebb) { host.setState({ ebb: false }); slow(); }
  }
  /* Start: bis die Tokens da sind und einmal gerechnet ist, keine Übergänge (sonst fahren Bahnen sichtbar aus 0 auf) */
  document.documentElement.setAttribute("data-alfa-boot", ""); wait();
  /* 28.10.: tok(name) liest einen Token aus alfa-theme.css als Zahl (name ohne „--“), für die Logik der Bögen (Brief A1) */
  /* 29.10.: Bildlaufleiste nur beim Scrollen (Johannes 29.10.: „ja, bei inaktivität oder wenn scrollen garnicht vorgesehen ist“). Ruhe: scrollbar-color transparent (inline in den Bögen); beim Scrollen Linie in --c-line-strong, nach motion.duration.scrollLineRest wieder aus. */
  if (!window.__alfaBar) { window.__alfaBar = true; var bt = new WeakMap(); document.addEventListener("scroll", function (e) { var el = e.target; if (!el || el.nodeType !== 1 || !el.hasAttribute("data-alfa-bar")) return; el.style.scrollbarColor = "var(--c-line-strong) transparent"; clearTimeout(bt.get(el)); bt.set(el, setTimeout(function () { el.style.scrollbarColor = "transparent transparent"; }, rd("motion-duration-scrollLineRest") || 600)); }, true); }
  window.AlfaShell = { ebb: ebb, K: K, AREA: AREA, frame: frame, geo: geo, D0: D0, layout: layout, grow: grow, tok: rd };
})();
