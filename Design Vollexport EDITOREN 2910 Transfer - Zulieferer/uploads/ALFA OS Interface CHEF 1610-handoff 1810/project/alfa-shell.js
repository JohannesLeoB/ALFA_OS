/* Export 18.10.2026 */
/* ALFA Shell · Maße und Rechenregeln der Hülle · Stand 17.10.2026. Werte = TOKENBOGEN.json (Abgleich 17.10.: 13 Konstanten gleich). Minima 280/280/280 (Johannes 15.10.: „Bitte vereinheitlichen auf 280“). Einzige Quelle der Rechenregeln. Gelesen von ALFA Shell.dc.html und von jedem Bereich, der in die Hülle gesetzt wird. */
(function () {
  var K = { m: 16, gap: 12, bh: 40, bw: 56, awake: 124, dock: 36, rest: 280, fold: 56, foldAt: 112, center: 280, head: 44, ebbDelay: 420, ebbSlow: 900, laneMs: 260, laneSlowMs: 720, headPad: { list: [0, 8, 0, 16], main: [0, 8, 0, 16], stack: [0, 8, 0, 8] }, headGap: { list: 8, main: 8, stack: 4 } };
  var AREA = {
    Mail: { L: [280], R: [280], min: [280, 280, 280], yield: [0, 1, 2] },
    Einstellungen: { L: [280], R: [280], min: [280, 280, 280], yield: [0, 1, 2] }
  };
  function frame(p) {
    if (p.breite && p.hoehe) return { W: p.breite, H: p.hoehe, safe: 0 };
    if (p.fenster === "1512 × 982") return { W: 1512, H: 982, safe: 32 };
    return { W: Math.max(640, window.innerWidth), H: Math.max(480, window.innerHeight), safe: 0 };
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
    return solve([s.Lf, s.Mf, s.Rf || !!foldRight]);
  }
  /* Akkordeon nach Arbeit: die unwichtigste Bahn gibt zuerst nach. Liefert den Patch für den Speicher der Bahnen. */
  function grow(area, side, v, w0) {
    var A = AREA[area], MIN = A.min, o = side === "L" ? 0 : 2, nm = ["L", "M", "R"], fk = ["Lf", "Mf", "Rf"], HY = 64, q;
    if (v < K.foldAt) { q = { max: -1 }; q[fk[o]] = true; return q; }
    var oo = 2 - o; if (w0[oo] > K.fold && Math.abs(v - w0[oo]) < 12) v = w0[oo];
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
  window.AlfaShell = { ebb: ebb, K: K, AREA: AREA, frame: frame, geo: geo, D0: D0, layout: layout, grow: grow };
})();
