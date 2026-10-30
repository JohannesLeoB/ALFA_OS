(() => {
  const root = document.getElementById("root");
  const syncTheme = () => {
    const forced = document.documentElement.getAttribute("data-theme");
    const dark = forced ? forced === "dark" : matchMedia("(prefers-color-scheme: dark)").matches;
    root.setAttribute("data-theme", dark ? "dark" : "light");
  };
  syncTheme();
  matchMedia("(prefers-color-scheme: dark)").addEventListener("change", syncTheme);
  new MutationObserver(syncTheme).observe(document.documentElement, { attributes: true, attributeFilter: ["data-theme"] });

  const svg = root.querySelector(".iso-stage svg");
  const mods = [...svg.querySelectorAll(".mod")];
  const cabs = [...svg.querySelectorAll(".cab")];
  const bosses = [...svg.querySelectorAll(".boss")];
  const readout = root.querySelector("[data-readout]");
  const dTitle = document.getElementById("d-title"), dSub = document.getElementById("d-sub"), dBody = document.getElementById("d-body");
  const linkById = Object.fromEntries(DATA.links.map((l) => [l.id, l]));
  const modOf = Object.fromEntries(DATA.modules.map((m) => [m.key, m]));
  const order = DATA.modules.filter((m) => m.side === "code").sort((a, b) => b.types - a.types).map((m) => m.key)
    .concat(DATA.modules.filter((m) => m.side === "design" && m.kind !== "entwurf").map((m) => m.key));
  const allKeys = DATA.modules.map((m) => m.key);
  const still = matchMedia("(prefers-reduced-motion: reduce)");
  const esc = (s) => String(s ?? "").replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]));
  const linksOf = (key) => DATA.links.filter((l) => l.a === key || l.b === key).sort((x, y) => y.n - x.n);
  const say = (t) => { if (readout.textContent !== t) readout.textContent = t; };
  const sum = (o) => Object.values(o || {}).reduce((s, v) => s + v, 0);
  let sel = { kind: "mod", key: order[0] };

  function paint() {
    const ids = sel.kind === "mod" ? linksOf(sel.key).map((l) => l.id) : [sel.id];
    const on = new Set(ids);
    const lit = new Set(sel.kind === "mod" ? [sel.key] : [linkById[sel.id].a, linkById[sel.id].b]);
    const near = new Set(sel.kind === "mod" ? linksOf(sel.key).flatMap((l) => [l.a, l.b]) : []);
    for (const g of cabs) { const o = on.has(g.dataset.link); g.classList.toggle("on", o); g.classList.toggle("dim", !o); }
    for (const g of bosses) g.classList.toggle("on", on.has(g.dataset.link));
    for (const g of mods) { const n = g.dataset.mod; g.classList.toggle("lit", lit.has(n)); g.classList.toggle("dim", !lit.has(n) && !near.has(n)); }
  }
  const rowBtn = (l, label, why, max) => '<button class="row" data-link="' + l.id + '"><b>' + esc(label) + '</b><span class="n">' + l.n + '</span><span class="bar"><i style="width:' + (100 * l.n / max).toFixed(1) + '%"></i></span><span class="why">' + why + "</span></button>";
  function showMod(key) {
    const m = modOf[key];
    const list = linksOf(key);
    const code = list.filter((l) => l.kind === "code"), bridges = list.filter((l) => l.kind === "bridge");
    const max = Math.max(1, ...list.map((l) => l.n));
    const other = (l) => modOf[l.a === key ? l.b : l.a];
    dTitle.textContent = m.label;
    let html = "";
    if (m.side === "code") {
      dSub.textContent = m.types + " Typen · " + (m.paths || []).join(" + ") + (m.deps.length ? " · baut auf " + m.deps.join(", ") : " · Grundlage ohne Abhängigkeit");
      html += '<div class="chips"><span class="chip">' + (m.kind === "view" ? "Ansichts-Modul" : m.kind === "integration" ? "Dienst-Anbindung" : "Modul") + '</span><span class="chip">Tiefe ' + m.depth + "</span>" + (bridges.length ? '<span class="chip">' + bridges.reduce((s, l) => s + l.n, 0) + " Vertragseinträge vom Design</span>" : '<span class="chip warn">nichts vom Design-Vertrag</span>') + "</div>";
      if (code.length) html += '<p class="sub">Code-Verbindungen</p><div class="rows">' + code.map((l) => { const o = other(l); const a = l.dir[m.name + ">" + o.name] || 0, b = l.dir[o.name + ">" + m.name] || 0; return rowBtn(l, o.label, esc(m.label) + " nutzt " + esc(o.label) + ": " + a + " · umgekehrt: " + b + (l.drawn ? "" : " · nicht gezeichnet"), max); }).join("") + "</div>";
      if (bridges.length) html += '<p class="sub">Vom Design</p><div class="rows">' + bridges.map((l) => rowBtn(l, other(l).label, Object.entries(l.kinds || {}).map(([k, v]) => k + " " + v).join(" · "), max)).join("") + "</div>";
      say(m.label + " · " + m.types + " Typen · " + list.length + " Verbindungen");
    } else if (m.kind === "entwurf") {
      dSub.textContent = "Werkstatt-Entwurf aus Etappe II · " + m.lines + " Zeilen";
      html = '<p class="muted">Kein Vertrag, keine Leitung: Für diesen Entwurf gibt es weder Einträge in <code>contract/</code> noch Code. Er wartet auf das Werkstatt-Modul.</p>';
      say(m.label + " · Entwurf ohne Vertrag");
    } else {
      const total = sum(m.entries), unused = sum(m.unused);
      dSub.textContent = (m.lines ? m.lines + " Zeilen · " : "") + total + " Vertragseinträge · " + (total - unused) + " im Code gefunden";
      html += '<div class="chips">' + Object.entries(m.entries || {}).map(([k, v]) => '<span class="chip">' + k + " " + (v - ((m.unused || {})[k] || 0)) + " / " + v + "</span>").join("") + "</div>";
      if (bridges.length) html += '<p class="sub">Kommt an in</p><div class="rows">' + bridges.map((l) => rowBtn(l, other(l).label, Object.entries(l.kinds || {}).map(([k, v]) => k + " " + v).join(" · "), max)).join("") + "</div>";
      if ((m.unusedEx || []).length) html += '<p class="sub">Im Code nicht gefunden (Auswahl)</p><div class="tablewrap"><table class="ex"><tbody>' + m.unusedEx.map((e) => "<tr><td>" + esc(e.kind) + "</td><td><code>" + esc(e.id) + "</code></td></tr>").join("") + "</tbody></table></div>";
      if (!total) html += '<p class="muted">Dieser Bogen hat keine eigenen Einträge im Vertrag.</p>';
      say(m.label + " · " + total + " Einträge · " + (total - unused) + " im Code");
    }
    dBody.innerHTML = html;
    dBody.querySelectorAll(".row").forEach((b) => b.addEventListener("click", () => pick({ kind: "link", id: b.dataset.link })));
  }
  function showLink(id) {
    const l = linkById[id], a = modOf[l.a], b = modOf[l.b];
    if (l.kind === "code") {
      dTitle.textContent = a.label + " ↔ " + b.label;
      dSub.textContent = l.n + " Typ-Paare · " + a.label + " nutzt " + b.label + ": " + (l.dir[a.name + ">" + b.name] || 0) + " · " + b.label + " nutzt " + a.label + ": " + (l.dir[b.name + ">" + a.name] || 0);
      dBody.innerHTML = '<div class="tablewrap"><table class="ex"><tbody>' + l.ex.map((e) => "<tr><td>" + esc(e.von) + " → " + esc(e.an) + "</td><td><code>" + esc(e.ort) + '</code></td><td class="muted">' + esc(e.art) + "</td></tr>").join("") + "</tbody></table></div>";
    } else {
      dTitle.textContent = a.label + " → " + b.label;
      dSub.textContent = l.n + " Vertragseinträge kommen in " + b.label + " an · " + Object.entries(l.kinds || {}).map(([k, v]) => k + " " + v).join(" · ");
      dBody.innerHTML = '<div class="tablewrap"><table class="ex"><tbody>' + l.ex.map((e) => '<tr><td class="muted">' + esc(e.kind) + "</td><td><code>" + esc(e.id) + "</code></td><td><code>" + esc(e.ort) + "</code></td></tr>").join("") + "</tbody></table></div>";
    }
    say(dTitle.textContent + " · " + l.n);
  }
  function pick(next, user = true) {
    sel = next;
    if (user) { touring = false; clearTimeout(idle); idle = setTimeout(() => { touring = !still.matches; tourClock = 0; }, 14000); }
    paint();
    if (sel.kind === "mod") showMod(sel.key); else showLink(sel.id);
  }
  for (const g of mods) {
    g.addEventListener("click", (e) => { e.stopPropagation(); pick({ kind: "mod", key: g.dataset.mod }); });
    g.addEventListener("keydown", (e) => { if (e.key === "Enter" || e.key === " ") { e.preventDefault(); pick({ kind: "mod", key: g.dataset.mod }); } });
  }
  for (const g of cabs) g.addEventListener("click", (e) => { e.stopPropagation(); pick({ kind: "link", id: g.dataset.link }); });
  root.querySelector(".iso-stage").addEventListener("keydown", (e) => {
    if (!["ArrowRight", "ArrowLeft", "ArrowUp", "ArrowDown"].includes(e.key)) return;
    e.preventDefault();
    const cur = sel.kind === "mod" ? allKeys.indexOf(sel.key) : 0;
    const step = e.key === "ArrowRight" || e.key === "ArrowDown" ? 1 : -1;
    pick({ kind: "mod", key: allKeys[(cur + step + allKeys.length) % allKeys.length] });
  });
  const pulses = cabs.map((g) => ({ g, p: g.querySelector(".pulse"), off: +g.querySelector(".pulse").dataset.off, l: linkById[g.dataset.link] }));
  let touring = !still.matches, tourClock = 0, idle = 0, frame = 0, last = 0, visible = true, t = 0;
  function tick(now) {
    const dt = last ? Math.min((now - last) / 1000, 1 / 20) : 1 / 60; last = now;
    if (touring) { tourClock += dt; if (tourClock > 3.6) { tourClock = 0; const cur = sel.kind === "mod" ? order.indexOf(sel.key) : -1; pick({ kind: "mod", key: order[(cur + 1) % order.length] }, false); } }
    t += dt;
    for (const q of pulses) {
      if (!q.g.classList.contains("on")) continue;
      const a = modOf[q.l.a], b = modOf[q.l.b];
      const fwd = q.l.kind === "bridge" ? 1 : ((q.l.dir[a.name + ">" + b.name] || 0) >= (q.l.dir[b.name + ">" + a.name] || 0) ? 1 : -1);
      q.p.style.strokeDashoffset = (q.off - fwd * t * 22).toFixed(1);
    }
    frame = visible && !still.matches ? requestAnimationFrame(tick) : 0;
  }
  const run = () => { if (!frame && visible && !still.matches) { last = 0; frame = requestAnimationFrame(tick); } };
  new IntersectionObserver((en) => { visible = en[en.length - 1].isIntersecting; run(); }).observe(svg);
  still.addEventListener("change", () => { touring = !still.matches; run(); });
  pick(sel, false);
  run();
})();
