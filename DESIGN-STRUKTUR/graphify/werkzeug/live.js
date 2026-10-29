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
  const typesOf = Object.fromEntries(DATA.modules.map((m) => [m.name, m.types]));
  const order = ["Grundlage", "Mail", "Hub", "Einstellungen", "Hülle", "Assistent", "Dienste", "Kalkulation", "Design-Skripte"];
  const still = matchMedia("(prefers-reduced-motion: reduce)");
  const esc = (s) => String(s).replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]));
  const linksOf = (name) => DATA.links.filter((l) => l.a === name || l.b === name).sort((x, y) => y.n - x.n);
  const say = (t) => { if (readout.textContent !== t) readout.textContent = t; };
  let sel = { kind: "mod", name: "Mail" };

  function paint() {
    const onLinks = new Set(sel.kind === "mod" ? linksOf(sel.name).map((l) => l.id) : [sel.id]);
    const litMods = new Set(sel.kind === "mod" ? [sel.name] : [linkById[sel.id].a, linkById[sel.id].b]);
    const near = new Set(sel.kind === "mod" ? linksOf(sel.name).flatMap((l) => [l.a, l.b]) : []);
    for (const g of cabs) { const on = onLinks.has(g.dataset.link); g.classList.toggle("on", on); g.classList.toggle("dim", !on); }
    for (const g of bosses) g.classList.toggle("on", onLinks.has(g.dataset.link));
    for (const g of mods) { const n = g.dataset.mod; g.classList.toggle("lit", litMods.has(n)); g.classList.toggle("dim", !litMods.has(n) && !near.has(n)); }
  }
  function showMod(name) {
    const list = linksOf(name);
    const sum = list.reduce((s, l) => s + l.n, 0);
    const max = Math.max(1, ...list.map((l) => l.n));
    dTitle.textContent = name;
    if (!list.length) {
      dSub.textContent = typesOf[name] + " Funktionen in alfa-shell.js und alfa-bausteine.js";
      dBody.innerHTML = '<p class="muted">Keine Leitung: Die Design-Skripte (JavaScript aus Etappe I) haben keine messbare Kante zum Swift-Code. Was der Code aus dem Design übernimmt, steht in Tokens und Texten, nicht in Aufrufen.</p>';
      say(name + " · " + typesOf[name] + " Funktionen · keine Leitung");
      return;
    }
    dSub.textContent = typesOf[name] + " Typen · " + list.length + " Leitungen · " + sum + " Typ-Paare";
    dBody.innerHTML = '<div class="rows">' + list.map((l) => {
      const other = l.a === name ? l.b : l.a;
      const out = l.dir[name + ">" + other] || 0, inn = l.dir[other + ">" + name] || 0;
      return '<button class="row" data-link="' + l.id + '"><b>' + esc(other) + '</b><span class="n">' + l.n + '</span><span class="bar"><i style="width:' + (100 * l.n / max).toFixed(1) + '%"></i></span><span class="why">' + esc(name) + " nutzt " + esc(other) + ": " + out + " · " + esc(other) + " nutzt " + esc(name) + ": " + inn + "</span></button>";
    }).join("") + "</div>";
    dBody.querySelectorAll(".row").forEach((b) => b.addEventListener("click", () => pick({ kind: "link", id: b.dataset.link })));
    say(name + " · " + typesOf[name] + " Typen · " + list.length + " Leitungen · " + sum + " Typ-Paare");
  }
  function showLink(id) {
    const l = linkById[id];
    const ab = l.dir[l.a + ">" + l.b] || 0, ba = l.dir[l.b + ">" + l.a] || 0;
    dTitle.textContent = l.a + " ↔ " + l.b;
    dSub.innerHTML = l.n + " Typ-Paare · " + esc(l.a) + " nutzt " + esc(l.b) + ": " + ab + " · " + esc(l.b) + " nutzt " + esc(l.a) + ": " + ba;
    dBody.innerHTML = '<div class="tablewrap"><table class="ex"><tbody>' + l.examples.map((e) =>
      "<tr><td>" + esc(e.von) + " → " + esc(e.an) + '</td><td><code>' + esc(e.ort) + "</code></td><td class=\"muted\">" + esc(e.art) + "</td></tr>").join("") +
      '</tbody></table></div><p class="muted" style="margin:8px 0 0;font-size:12px">Die ' + l.examples.length + " stärksten Paare, Fundstelle im Code.</p>";
    say(l.a + " ↔ " + l.b + " · " + l.n + " Typ-Paare");
  }
  function pick(next, user = true) {
    sel = next;
    if (user) { touring = false; clearTimeout(idle); idle = setTimeout(() => { touring = !still.matches; tourClock = 0; }, 14000); }
    paint();
    if (sel.kind === "mod") showMod(sel.name); else showLink(sel.id);
  }

  for (const g of mods) {
    g.addEventListener("click", (e) => { e.stopPropagation(); pick({ kind: "mod", name: g.dataset.mod }); });
    g.addEventListener("keydown", (e) => { if (e.key === "Enter" || e.key === " ") { e.preventDefault(); pick({ kind: "mod", name: g.dataset.mod }); } });
  }
  for (const g of cabs) g.addEventListener("click", (e) => { e.stopPropagation(); pick({ kind: "link", id: g.dataset.link }); });
  root.querySelector(".iso-stage").addEventListener("keydown", (e) => {
    if (!["ArrowRight", "ArrowLeft", "ArrowUp", "ArrowDown"].includes(e.key)) return;
    e.preventDefault();
    const cur = sel.kind === "mod" ? order.indexOf(sel.name) : 0;
    const step = e.key === "ArrowRight" || e.key === "ArrowDown" ? 1 : -1;
    pick({ kind: "mod", name: order[(cur + step + order.length) % order.length] });
  });

  const pulses = cabs.map((g) => ({ g, p: g.querySelector(".pulse"), off: +g.querySelector(".pulse").dataset.off, l: linkById[g.dataset.link] }));
  let touring = !still.matches, tourClock = 0, idle = 0, frame = 0, last = 0, visible = true, t = 0;
  function tick(now) {
    const dt = last ? Math.min((now - last) / 1000, 1 / 20) : 1 / 60; last = now;
    if (touring) {
      tourClock += dt;
      if (tourClock > 3.4) { tourClock = 0; const cur = sel.kind === "mod" ? order.indexOf(sel.name) : -1; pick({ kind: "mod", name: order[(cur + 1) % order.length] }, false); }
    }
    t += dt;
    for (const q of pulses) {
      if (!q.g.classList.contains("on")) continue;
      const fwd = (q.l.dir[q.l.a + ">" + q.l.b] || 0) >= (q.l.dir[q.l.b + ">" + q.l.a] || 0) ? 1 : -1;
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
