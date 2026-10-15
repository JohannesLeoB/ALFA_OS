/* @ds-bundle: {"format":4,"namespace":"ALFA","components":[{"name":"Shell"},{"name":"Lane"},{"name":"LaneHandle"},{"name":"Blob"},{"name":"TileMenu"},{"name":"MessageRow"},{"name":"SyncButton"},{"name":"PersonMark"},{"name":"TextButton"},{"name":"SymbolButton"},{"name":"Chip"},{"name":"SearchField"},{"name":"Symbol"},{"name":"ArcBars"},{"name":"PillStack"},{"name":"Tooltip"},{"name":"DotSphere"},{"name":"GlowButton"},{"name":"AgentPill"},{"name":"NumberRoll"},{"name":"SpotlightGrid"},{"name":"StackedCards"},{"name":"KanbanBoard"},{"name":"CardTower"},{"name":"ReadingPane"},{"name":"HubTile"},{"name":"EditSheet"},{"name":"BlobMenu"},{"name":"AssistantCard"},{"name":"ThinkingOrb"}]} */
(function () {
  "use strict";
  var R = window.React;
  var h = R.createElement;
  var useState = R.useState, useEffect = R.useEffect, useRef = R.useRef;

  function cx() { return Array.prototype.filter.call(arguments, Boolean).join(" "); }
  function still() { try { return window.matchMedia("(prefers-reduced-motion: reduce)").matches; } catch (e) { return false; } }
  function px(name, fallback) {
    var v = parseFloat(getComputedStyle(document.documentElement).getPropertyValue("--" + name));
    return isFinite(v) ? v : fallback;
  }
  function omit(o, keys) { var r = {}; for (var k in o) { if (keys.indexOf(k) < 0) r[k] = o[k]; } return r; }

  /* ---------- Symbol ---------- */
  var PATHS = {
    search: "M7 12.5a5.5 5.5 0 1 0 0-11 5.5 5.5 0 0 0 0 11ZM11 11l3.5 3.5",
    sync: "M13 8a5 5 0 0 1-8.6 3.5M3 8a5 5 0 0 1 8.6-3.5M11.6 1.8v2.7H8.9M4.4 14.2v-2.7h2.7",
    compose: "M11 2.5l2.5 2.5L6 12.5H3.5V10ZM9.5 4l2.5 2.5",
    archive: "M2.5 3.5h11v3h-11ZM3.5 6.5v6h9v-6M6.5 9h3",
    trash: "M3 4.5h10M6.5 4.5V3h3v1.5M4.5 4.5l.7 9h5.6l.7-9",
    reply: "M6.5 4L3 7.5 6.5 11M3 7.5h6a4 4 0 0 1 4 4v1",
    more: "M4 8h.01M8 8h.01M12 8h.01",
    close: "M4.5 4.5l7 7M11.5 4.5l-7 7",
    star: "M8 2.5l1.7 3.5 3.8.5-2.8 2.6.7 3.8L8 11.1l-3.4 1.8.7-3.8-2.8-2.6 3.8-.5Z",
    inbox: "M2.5 9.5l1.5-6h8l1.5 6v3.5h-11ZM2.5 9.5h3l1 1.5h3l1-1.5h3",
    attach: "M10.5 5L6 9.5a1.4 1.4 0 0 0 2 2L13 6.5a2.8 2.8 0 0 0-4-4L4 7.5a4.2 4.2 0 0 0 6 6l3-3",
    chevron: "M6 4l4 4-4 4",
    check: "M3.5 8.5l3 3 6-7",
    sidebar: "M2.5 3.5h11v9h-11ZM6 3.5v9",
    minus: "M4 8h8",
    expand: "M9.5 2.5h4v4M6.5 13.5h-4v-4M13.5 2.5L9 7M2.5 13.5L7 9",
    shrink: "M13.5 2.5L10 6M10 3v3h3M2.5 13.5L6 10M6 13v-3H3",
    link: "M7 9a2.5 2.5 0 0 0 3.5 0l2-2A2.5 2.5 0 0 0 9 3.5l-.7.7M9 7a2.5 2.5 0 0 0-3.5 0l-2 2A2.5 2.5 0 0 0 7 12.5l.7-.7",
    send: "M8 13V3.5M4 7.5l4-4 4 4",
    eye: "M1.5 8s2.5-4.5 6.5-4.5S14.5 8 14.5 8 12 12.5 8 12.5 1.5 8 1.5 8ZM8 10a2 2 0 1 0 0-4 2 2 0 0 0 0 4Z",
    plus: "M8 3v10M3 8h10"
  };
  function Symbol(p) {
    var s = p.size || 16;
    return h("svg", { className: cx("ai-sym", p.name === "more" && "ai-sym-dots", p.className), width: s, height: s, viewBox: "0 0 16 16", "aria-hidden": "true", focusable: "false" },
      h("path", { d: PATHS[p.name] || "" }));
  }
  Symbol.names = Object.keys(PATHS);

  /* ---------- Buttons ---------- */
  function TextButton(p) {
    var rest = omit(p, ["variant", "size", "className", "children"]);
    return h("button", Object.assign({ type: "button" }, rest, { className: cx("ai-tbtn", "ai-tbtn-" + (p.variant || "well"), p.size && p.size !== "regular" && "ai-" + p.size, p.className) }), p.children);
  }
  function SymbolButton(p) {
    var rest = omit(p, ["symbol", "variant", "size", "className", "label"]);
    return h("button", Object.assign({ type: "button", "aria-label": p.label, title: p.label }, rest, { className: cx("ai-sbtn", p.variant && p.variant !== "plain" && "ai-" + p.variant, p.size && p.size !== "regular" && "ai-" + p.size, p.className) }),
      h(Symbol, { name: p.symbol, size: p.size === "large" ? 18 : p.size === "small" ? 14 : 16 }));
  }
  function Chip(p) {
    var cls = cx("ai-chip", p.selected && "ai-on", p.inRow && "ai-in-row", p.onRemove && "ai-removable", p.className);
    var kids = [h("span", { key: "t" }, p.children)];
    if (p.onRemove) kids.push(h("span", { key: "x", role: "button", tabIndex: 0, className: "ai-chip-x", "aria-label": "Entfernen", onClick: function (e) { e.stopPropagation(); p.onRemove(); }, onKeyDown: function (e) { if (e.key === "Enter" || e.key === " ") { e.preventDefault(); e.stopPropagation(); p.onRemove(); } } }, h(Symbol, { name: "close", size: 12 })));
    return h("button", { type: "button", className: cls, "aria-pressed": !!p.selected, onClick: p.onClick }, kids);
  }

  /* ---------- SearchField ---------- */
  function SearchField(p) {
    var own = useState(p.defaultValue || ""), v = p.value != null ? p.value : own[0];
    function set(x) { if (p.value == null) own[1](x); if (p.onChange) p.onChange(x); }
    return h("label", { className: cx("ai-field", p.compact && "ai-compact", p.className) },
      h(Symbol, { name: "search", size: 14 }),
      h("input", { id: p.id, type: "search", value: v, placeholder: p.placeholder || "Suchen", "aria-label": p.label || p.placeholder || "Suchen", onChange: function (e) { set(e.target.value); }, onKeyDown: function (e) { if (e.key === "Escape") set(""); } }),
      v ? h("button", { type: "button", className: "ai-chip-x", "aria-label": "Suche leeren", onClick: function () { set(""); } }, h(Symbol, { name: "close", size: 12 })) : null);
  }

  /* ---------- PersonMark und SyncButton ---------- */
  function PersonMark(p) {
    return h("span", { className: cx("ai-person", p.className), role: "img", "aria-label": p.name || p.initials }, (p.initials || "").slice(0, 2).toUpperCase());
  }
  var SYNC_TEXT = { fresh: "Neu laden · gerade abgeglichen", aged: "Neu laden · länger nicht abgeglichen", syncing: "Gleicht ab …", error: "Abgleich fehlgeschlagen. Zum Wiederholen drücken." };
  function SyncButton(p) {
    var state = p.state || "fresh";
    return h("button", { type: "button", className: cx("ai-sync", p.className), "data-state": state, "aria-label": p.label || SYNC_TEXT[state], title: p.label || SYNC_TEXT[state], onClick: p.onClick },
      h("svg", { viewBox: "0 0 28 28", "aria-hidden": "true" },
        h("circle", { className: "ai-ring", cx: 14, cy: 14, r: 12.75 }),
        h("path", { className: "ai-arc", d: "M14 1.25A12.75 12.75 0 0 1 26.75 14" })),
      h(Symbol, { name: "sync", size: 12 }));
  }

  /* ---------- Lane ---------- */
  function Lane(p) {
    if (p.folded) {
      return h("section", { className: cx("ai-lane", "ai-folded", p.className), "aria-label": p.title },
        h("button", { type: "button", className: "ai-strip", onClick: p.onUnfold, "aria-label": p.title + " aufklappen" },
          p.dot ? h("span", { className: "ai-strip-dot", "aria-hidden": "true" }) : null,
          h("span", { className: "ai-strip-word" }, p.title)));
    }
    return h("section", { className: cx("ai-lane", p.className), "aria-label": p.title },
      h("header", { className: "ai-lane-head" },
        h("span", { className: "ai-lane-title" }, p.title),
        p.count != null ? h("span", { className: "ai-lane-count" }, p.count) : null,
        p.actions ? h("div", { className: "ai-lane-actions" }, p.actions) : null),
      h("div", { className: "ai-lane-body" }, p.children));
  }

  /* ---------- LaneHandle ---------- */
  function LaneHandle(p) {
    var st = useState(false), active = st[0], setActive = st[1];
    var start = useRef(null);
    function down(e) { e.preventDefault(); e.currentTarget.setPointerCapture(e.pointerId); start.current = e.clientX; setActive(true); if (p.onStart) p.onStart(); }
    function move(e) { if (start.current == null) return; if (p.onDrag) p.onDrag(e.clientX - start.current); }
    function up() { if (start.current == null) return; start.current = null; setActive(false); if (p.onEnd) p.onEnd(); }
    function key(e) { var d = e.key === "ArrowLeft" ? -8 : e.key === "ArrowRight" ? 8 : 0; if (d && p.onStep) { e.preventDefault(); p.onStep(e.shiftKey ? d * 4 : d); } if (e.key === "Enter" && p.onReset) p.onReset(); }
    return h("div", { className: cx("ai-handle", active && "ai-active", p.className), role: "separator", "aria-orientation": "vertical", "aria-label": p.label || "Breite ändern", "aria-valuenow": p.value, tabIndex: 0,
      onPointerDown: down, onPointerMove: move, onPointerUp: up, onPointerCancel: up, onDoubleClick: p.onReset, onKeyDown: key },
      h("span", { className: "ai-handle-grip" }),
      active && p.value != null ? h("span", { className: "ai-handle-label" }, Math.round(p.value) + " pt") : null);
  }

  /* ---------- Shell ---------- */
  function Shell(p) {
    var lanes = p.lanes || [];
    var rest = px("component-lane-resting-width", 300), folded = px("component-lane-folded-width", 56), at = px("component-lane-fold-threshold", 120), max = px("component-lane-leading-max-width", 420);
    var w = useState([lanes[0] && lanes[0].width || rest, lanes[2] && lanes[2].width || rest]), widths = w[0], setWidths = w[1];
    var d = useState(-1), dragging = d[0], setDragging = d[1];
    var base = useRef([0, 0]);
    function clamp(v) { return Math.max(folded, Math.min(max, v)); }
    function snap(v) { return v < at ? folded : v; }
    function onStart(i) { return function () { base.current = widths.slice(); setDragging(i); }; }
    function onDrag(i) { return function (dx) { var n = widths.slice(); n[i] = clamp(base.current[i] + (i === 0 ? dx : -dx)); setWidths(n); }; }
    function onEnd(i) { return function () { var n = widths.slice(); n[i] = snap(n[i]); setWidths(n); setDragging(-1); }; }
    function onStep(i) { return function (dx) { var n = widths.slice(); n[i] = snap(clamp(n[i] + (i === 0 ? dx : -dx))); setWidths(n); }; }
    function onReset(i) { return function () { var n = widths.slice(); n[i] = rest; setWidths(n); }; }
    function unfold(i) { return function () { var n = widths.slice(); n[i] = rest; setWidths(n); }; }
    function lane(i) {
      var l = lanes[i]; if (!l) return h("div", { key: "l" + i });
      var foldable = i !== 1, isFolded = foldable && widths[i === 0 ? 0 : 1] <= folded;
      return h(Lane, { key: "l" + i, title: l.title, count: l.count, actions: l.actions, dot: l.dot, folded: isFolded, onUnfold: unfold(i === 0 ? 0 : 1) }, l.content);
    }
    var cols = widths[0] + "px var(--component-lane-handle-width) minmax(0,1fr) var(--component-lane-handle-width) " + widths[1] + "px";
    return h("div", { className: cx("ai-root", "ai-shell", p.className), style: p.style },
      h("div", { className: "ai-blobbar", role: "toolbar", "aria-label": "Fensterleiste" }, p.blob || null, p.trailing || null),
      h("div", { className: cx("ai-lanes", dragging >= 0 && "ai-dragging"), style: { gridTemplateColumns: cols } },
        lane(0),
        h(LaneHandle, { value: widths[0], label: "Breite der linken Bahn", onStart: onStart(0), onDrag: onDrag(0), onEnd: onEnd(0), onStep: onStep(0), onReset: onReset(0) }),
        lane(1),
        h(LaneHandle, { value: widths[1], label: "Breite der rechten Bahn", onStart: onStart(1), onDrag: onDrag(1), onEnd: onEnd(1), onStep: onStep(1), onReset: onReset(1) }),
        lane(2)));
  }

  /* ---------- Blob ---------- */
  function smooth(t) { t = Math.max(0, Math.min(1, t)); return t * t * (3 - 2 * t); }
  function Blob(p) {
    var areas = p.areas || ["Mail", "Einstellungen"];
    var host = useRef(null), blob = useRef(null), eyes = useRef([]);
    var s1 = useState(p.side || "leading"), side = s1[0], setSide = s1[1];
    var s2 = useState(0), wake = s2[0], setWake = s2[1];
    var s3 = useState(false), open = s3[0], setOpen = s3[1];
    var s4 = useState(false), pressed = s4[0], setPressed = s4[1];
    var s5 = useState(null), drag = s5[0], setDrag = s5[1];
    var s6 = useState(""), query = s6[0], setQuery = s6[1];
    var s7 = useState(0), hot = s7[0], setHot = s7[1];
    var rest = px("component-lane-folded-width", 56), awake = px("component-blob-awake-width", 124), menuW = px("component-menu-width", 216), margin = 0;
    var pointer = useRef({ x: -1e4, y: -1e4 });
    var dragInfo = useRef(null), dragged = useRef(false);

    useEffect(function () {
      var raf = 0, lastBlink = performance.now(), nextBlink = 3200 + Math.random() * 2600, open01 = 0.42, cur = [0, 0];
      function frame(t) {
        var el = blob.current; if (!el) { raf = requestAnimationFrame(frame); return; }
        var face = el.querySelector(".ai-blob-face"); if (!face) { raf = requestAnimationFrame(frame); return; }
        var r = face.getBoundingClientRect(), cxp = r.left + r.width / 2, cyp = r.top + r.height / 2;
        var dx = pointer.current.x - cxp, dy = pointer.current.y - cyp, dist = Math.hypot(dx, dy);
        var w = open ? 1 : smooth(1 - (dist - 12) / 200);
        setWake(function (o) { return Math.abs(o - w) > 0.01 ? w : o; });
        var travel = 2, k = dist > 0 ? Math.min(1, dist / 200) : 0;
        var tx = dist > 0 ? dx / dist * travel * k : 0, ty = dist > 0 ? dy / dist * travel * k * 0.8 : 0;
        cur[0] += (tx - cur[0]) * 0.18; cur[1] += (ty - cur[1]) * 0.18;
        var target = 0.42 + 0.58 * w;
        if (!still() && t - lastBlink > nextBlink) { lastBlink = t; nextBlink = 3200 + Math.random() * 2600; }
        var blinking = !still() && t - lastBlink < 140;
        open01 += ((blinking ? 0.08 : target) - open01) * (blinking ? 0.6 : 0.15);
        eyes.current.forEach(function (e) { if (e) e.style.transform = "translate(" + cur[0].toFixed(2) + "px," + cur[1].toFixed(2) + "px) scaleY(" + open01.toFixed(3) + ")"; });
        raf = requestAnimationFrame(frame);
      }
      function mv(e) { pointer.current = { x: e.clientX, y: e.clientY }; }
      window.addEventListener("pointermove", mv);
      raf = requestAnimationFrame(frame);
      return function () { cancelAnimationFrame(raf); window.removeEventListener("pointermove", mv); };
    }, [open]);

    useEffect(function () {
      if (!open) return;
      function away(e) { if (blob.current && !blob.current.contains(e.target)) setOpen(false); }
      function esc(e) { if (e.key === "Escape") setOpen(false); }
      document.addEventListener("pointerdown", away); document.addEventListener("keydown", esc);
      return function () { document.removeEventListener("pointerdown", away); document.removeEventListener("keydown", esc); };
    }, [open]);

    var shown = areas.filter(function (a) { return !query || a.toLowerCase().indexOf(query.toLowerCase()) >= 0; });
    function choose(a) { setOpen(false); setQuery(""); if (p.onSelect) p.onSelect(a); }
    function down(e) {
      if (open || e.button > 0) return;
      dragInfo.current = { start: e.clientX, moved: false };
      setPressed(true);
      function move(ev) {
        var d = dragInfo.current; if (!d) return;
        if (!d.moved && Math.abs(ev.clientX - d.start) > 2) d.moved = true;
        if (d.moved) setDrag(ev.clientX - d.start);
      }
      function up(ev) {
        window.removeEventListener("pointermove", move); window.removeEventListener("pointerup", up); window.removeEventListener("pointercancel", up);
        var d = dragInfo.current; dragInfo.current = null; setPressed(false);
        if (!d || !d.moved) return;
        var hr = host.current.getBoundingClientRect(), br = blob.current.getBoundingClientRect();
        var mid = br.left + br.width / 2 - hr.left;
        var ns = mid < hr.width * 0.5 ? "leading" : "trailing";
        dragged.current = true; setTimeout(function () { dragged.current = false; }, 0);
        setSide(ns); setDrag(null); if (p.onDock) p.onDock(ns);
      }
      window.addEventListener("pointermove", move); window.addEventListener("pointerup", up); window.addEventListener("pointercancel", up);
    }
    var width = open ? menuW : rest + (awake - rest) * wake;
    var left = side === "leading" ? margin : null, right = side === "trailing" ? margin : null;
    var style = { left: left != null ? left : "auto", right: right != null ? "var(--blob-trailing-inset, 0px)" : "auto", transform: drag != null ? "translateX(" + drag + "px)" : "none", transition: drag != null || still() ? "none" : "left var(--motion-duration-snap) var(--motion-curve-standard), right var(--motion-duration-snap) var(--motion-curve-standard)" };
    var pillStyle = { width: width + "px", height: open ? "auto" : null, minHeight: open ? "var(--component-blob-height)" : null };
    var flagOut = wake > 0.3 && !open;
    var current = p.area || areas[0];
    return h("div", { ref: host, className: cx("ai-root", "ai-blob-host", p.className) },
      h("div", { ref: blob, className: cx("ai-blob", "ai-side-" + side, flagOut && "ai-flag", open && "ai-open", pressed && "ai-pressed"), style: style,
        onPointerDown: down },
        h("div", { className: "ai-blob-pill", style: pillStyle },
          h("button", { type: "button", className: "ai-blob-face", "aria-label": "Assistent öffnen", onClick: function () { if (!dragged.current && p.onAssistant) p.onAssistant(); } },
            h("span", { ref: function (e) { eyes.current[0] = e; }, className: "ai-blob-eye", style: { left: "7.75px" } }),
            h("span", { ref: function (e) { eyes.current[1] = e; }, className: "ai-blob-eye", style: { left: "14.75px" } })),
          h("button", { type: "button", className: "ai-blob-cover", "aria-haspopup": "menu", "aria-expanded": open, tabIndex: 0,
            style: { opacity: open ? 1 : Math.max(0, (wake - 0.3) / 0.7), pointerEvents: open || wake >= 0.3 ? "auto" : "none" },
            onClick: function () { if (dragged.current) return; setOpen(!open); setHot(0); },
            onKeyDown: function (e) { if (e.key === "ArrowDown") { e.preventDefault(); setOpen(true); } } },
            current),
          p.notice && !open ? h("span", { className: "ai-blob-notice", style: side === "leading" ? { left: (rest - 10) + "px" } : { right: (rest - 10) + "px" }, "aria-label": "Ungelesenes" }) : null,
          open ? h("div", { className: "ai-blob-menu", role: "menu", "aria-label": "Bereiche",
            onKeyDown: function (e) {
              if (e.key === "ArrowDown") { e.preventDefault(); setHot(Math.min(shown.length - 1, hot + 1)); }
              if (e.key === "ArrowUp") { e.preventDefault(); setHot(Math.max(0, hot - 1)); }
              if (e.key === "Enter" && shown[hot]) { e.preventDefault(); choose(shown[hot]); }
            } },
            h("label", { className: "ai-blob-search" }, h(Symbol, { name: "search", size: 14 }),
              h("input", { id: "ai-blob-suche", autoFocus: true, value: query, placeholder: "Finden", "aria-label": "Bereich finden", onChange: function (e) { setQuery(e.target.value); setHot(0); } })),
            shown.map(function (a, i) {
              return h("button", { key: a, type: "button", role: "menuitem", className: cx("ai-blob-row", a === current && "ai-current", i === hot && "ai-hot"), onMouseEnter: function () { setHot(i); }, onClick: function () { choose(a); } },
                h("span", null, a), p.noticeArea === a ? h("span", { className: "ai-blob-rowdot", "aria-label": "Ungelesenes" }) : null);
            })) : null)));
  }

  /* ---------- TileMenu ---------- */
  var CORNERS = [
    "var(--radius-container) var(--radius-dialog) var(--component-lane-radius) var(--radius-dialog)",
    "var(--radius-dialog) var(--component-lane-radius) var(--radius-dialog) var(--radius-container)",
    "var(--component-lane-radius) var(--radius-container) var(--radius-dialog) var(--component-lane-radius)"
  ];
  function Tile(p) {
    var hv = useState(false), hover = hv[0], setHover = hv[1];
    var pr = useState(false), press = pr[0], setPress = pr[1];
    var up = hover || p.open;
    var state = press ? "pressed" : p.open ? "open" : hover ? "hover" : "rest";
    return h("div", { ref: p.setRef, className: cx("ai-tile", up && "ai-up"), "data-state": state, style: { borderRadius: CORNERS[p.index % 3] },
      role: "button", tabIndex: 0, "aria-expanded": up, "aria-label": p.item.name + ", " + p.item.count,
      onPointerEnter: function () { setHover(true); }, onPointerLeave: function () { setHover(false); setPress(false); },
      onPointerDown: function () { setPress(true); }, onPointerUp: function () { setPress(false); p.onToggle(p.index); },
      onKeyDown: function (e) { if (e.key === "Enter" || e.key === " ") { e.preventDefault(); p.onToggle(p.index); } } },
      h("div", { className: "ai-tile-name" }, p.item.name),
      h("div", { className: "ai-tile-count" }, p.item.count),
      h("span", { className: "ai-tile-ear", "aria-hidden": "true" }),
      h("nav", { className: "ai-tile-note", "aria-hidden": !up }, (p.item.links || []).map(function (l) {
        return h("button", { key: l, type: "button", tabIndex: up ? 0 : -1, onPointerUp: function (e) { e.stopPropagation(); }, onClick: function (e) { e.stopPropagation(); if (p.onPick) p.onPick(p.item.name, l); } }, l);
      })));
  }
  function TileMenu(p) {
    var items = p.items || [];
    var field = useRef(null), refs = useRef([]);
    var o = useState(null), open = o[0], setOpen = o[1];
    useEffect(function () {
      if (still()) return;
      var S = items.map(function () { return { x: 0, y: 0, vx: 0, vy: 0 }; });
      var mx = -1e4, my = -1e4, raf = 0, t0 = performance.now();
      var m = p.mass || 3.2, k = p.stiffness || 14, c = p.damping || 7.5, reach = 240, push = 420, roll = 0.1;
      var f = field.current;
      function mv(e) { var r = f.getBoundingClientRect(); mx = e.clientX - r.left; my = e.clientY - r.top; }
      function lv() { mx = my = -1e4; }
      function step(t) {
        var dt = Math.min(0.033, (t - t0) / 1000); t0 = t;
        refs.current.forEach(function (el, i) {
          if (!el) return; var s = S[i];
          var cxp = el.offsetLeft + el.offsetWidth / 2 + s.x, cyp = el.offsetTop + el.offsetHeight / 2 + s.y;
          var dx = cxp - mx, dy = cyp - my, d = Math.hypot(dx, dy) || 1, fx = 0, fy = 0;
          if (d < reach && el.dataset.state === "rest") { var q = 1 - d / reach; fx = dx / d * push * q * q; fy = dy / d * push * q * q; }
          s.vx += (fx - k * s.x - c * s.vx) / m * dt; s.vy += (fy - k * s.y - c * s.vy) / m * dt;
          s.x += s.vx * dt; s.y += s.vy * dt;
          el.style.setProperty("--x", s.x.toFixed(2) + "px"); el.style.setProperty("--y", s.y.toFixed(2) + "px"); el.style.setProperty("--r", (s.x * roll).toFixed(2) + "deg");
        });
        raf = requestAnimationFrame(step);
      }
      f.addEventListener("pointermove", mv); f.addEventListener("pointerleave", lv);
      raf = requestAnimationFrame(step);
      return function () { cancelAnimationFrame(raf); f.removeEventListener("pointermove", mv); f.removeEventListener("pointerleave", lv); };
    }, [items.length]);
    return h("div", { ref: field, className: cx("ai-root", "ai-tiles", p.className) }, items.map(function (it, i) {
      return h(Tile, { key: it.name, item: it, index: i, open: open === i, setRef: function (el) { refs.current[i] = el; }, onToggle: function (j) { setOpen(open === j ? null : j); }, onPick: p.onPick });
    }));
  }

  /* ---------- MessageRow ---------- */
  function initials(name) { var parts = String(name || "").trim().split(/\s+/); return ((parts[0] || "")[0] || "").concat((parts[1] || "")[0] || "").toUpperCase(); }
  function MessageRow(p) {
    return h("button", { type: "button", className: cx("ai-root", "ai-row", p.unread && "ai-unread", p.selected && "ai-on", p.className), "aria-pressed": !!p.selected, onClick: p.onClick },
      h("span", { className: "ai-row-mark", "aria-hidden": "true" }, initials(p.from)),
      h("span", { className: "ai-row-from" }, p.from),
      h("span", { className: "ai-row-date" }, p.attachments ? h(Symbol, { name: "attach", size: 12 }) : null, p.date, p.unread ? h("span", { className: "ai-row-dot", "aria-label": "Ungelesen" }) : null),
      h("span", { className: "ai-row-subject" }, p.subject),
      h("span", { className: "ai-row-preview" }, p.preview));
  }

  /* ---------- Ausdrucksfarben: Wahl aus palette-* für Ausdrucksflächen ---------- */
  var EXPRESSION = {
    "red-200": ["palette-red-200", "color-text-on-expression-light"], "red-400": ["palette-red-400", "color-text-on-expression-light"],
    "red-500": ["palette-red-500", "color-text-on-expression-dark"], "red-700": ["palette-red-700", "color-text-on-expression-dark"],
    "red-800": ["palette-red-800", "color-text-on-expression-dark"], "orange-400": ["palette-orange-400", "color-text-on-expression-light"],
    "cyan-900": ["palette-cyan-900", "color-text-on-expression-dark"], "gray-950": ["palette-gray-950", "color-text-on-expression-dark"]
  };
  function colorStyle(name) { var m = EXPRESSION[name] || EXPRESSION["red-400"]; return { background: "var(--" + m[0] + ")", color: "var(--" + m[1] + ")" }; }

  /* ---------- ArcBars ---------- */
  function ArcBars(p) {
    var data = p.data || [];
    var max = Math.max.apply(null, data.map(function (d) { return d.value; }).concat([1]));
    var cols = { gridTemplateColumns: "repeat(" + Math.max(1, data.length) + ", minmax(0, 1fr))" };
    var summary = data.map(function (d) { return d.label + ": " + d.value; }).join(", ");
    return h("figure", { className: cx("ai-root", "ai-arcs", p.className) },
      p.title ? h("figcaption", { className: "ai-arcs-head" }, h("span", { className: "reading-title" }, p.title), p.caption ? h("span", { className: "caption ai-arcs-cap" }, p.caption) : null) : null,
      h("div", { className: "ai-arcs-bars", style: cols, role: "img", "aria-label": summary },
        data.map(function (d) { return h("i", { key: d.label, style: { height: Math.max(2, d.value / max * 100) + "%" } }); })),
      h("div", { className: "ai-arcs-nums mono-detail", style: cols, "aria-hidden": "true" },
        data.map(function (d) { return h("span", { key: d.label }, d.label); })));
  }

  /* ---------- PillStack ---------- */
  function PillStack(p) {
    return h("div", { className: cx("ai-root", "ai-pills", p.className), role: "list" },
      (p.items || []).map(function (it) {
        return h("div", { key: it.label, role: "listitem", className: "ai-pill mono-detail", style: colorStyle(it.color) }, it.label);
      }));
  }

  /* ---------- Tooltip ---------- */
  function Tooltip(p) {
    return h("div", { role: "note", className: cx("ai-root", "ai-tip", p.tone === "dark" ? "ai-tip-dark" : "ai-tip-light", p.tail === false && "ai-notail", p.className) },
      p.title ? h("span", { className: "name ai-tip-title" }, p.title) : null,
      h("span", { className: "callout ai-tip-text" }, p.children));
  }

  /* ---------- DotSphere ---------- */
  function DotSphere(p) {
    var ref = useRef(null), size = p.size || 240, count = p.count || 420;
    useEffect(function () {
      var c = ref.current; if (!c) return;
      var dpr = Math.min(2, window.devicePixelRatio || 1), ctx = c.getContext("2d"), k = size / 320, raf = 0, pts = [], i;
      c.width = size * dpr; c.height = size * dpr; ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
      for (i = 0; i < count; i++) { var y = 1 - 2 * (i + 0.5) / count, r = Math.sqrt(1 - y * y), a = i * Math.PI * (3 - Math.sqrt(5)); pts.push([Math.cos(a) * r, y, Math.sin(a) * r]); }
      function frame(t) {
        ctx.clearRect(0, 0, size, size);
        var s = Math.sin(t / 1800), co = Math.cos(t / 1800);
        ctx.fillStyle = getComputedStyle(c).color;
        pts.map(function (q) { return [q[0] * co + q[2] * s, q[1], -q[0] * s + q[2] * co]; })
          .sort(function (u, v) { return u[2] - v[2]; })
          .forEach(function (q) {
            var d = (q[2] + 1) / 2;
            ctx.globalAlpha = 0.2 + 0.8 * d;
            ctx.beginPath(); ctx.arc(size / 2 + q[0] * 140 * k, size / 2 + q[1] * 140 * k, (1 + d * 2.6) * k, 0, 7); ctx.fill();
          });
        if (!still()) raf = requestAnimationFrame(frame);
      }
      frame(0);
      if (!still()) raf = requestAnimationFrame(frame);
      return function () { cancelAnimationFrame(raf); };
    }, [size, count]);
    return h("canvas", { ref: ref, className: cx("ai-root", "ai-sphere", p.className), style: { width: size, height: size }, role: "img", "aria-label": p.label || "Punktkugel dreht sich" });
  }

  /* ---------- GlowButton ---------- */
  function GlowButton(p) {
    var rest = omit(p, ["children", "className"]);
    return h("button", Object.assign({ type: "button" }, rest, { className: cx("ai-root", "ai-glow", p.className) }),
      h("span", { className: "ai-glow-in text-button" }, p.children));
  }

  /* ---------- AgentPill ---------- */
  var gooCount = 0;
  function AgentPill(p) {
    var id = useRef(null);
    if (!id.current) { gooCount += 1; id.current = "ai-goo-" + gooCount; }
    return h("div", { className: cx("ai-root", "ai-agent", p.paused && "ai-paused", p.className), role: "img", "aria-label": p.label || "Agent arbeitet" },
      h("svg", { width: 0, height: 0, "aria-hidden": "true", style: { position: "absolute" } },
        h("filter", { id: id.current }, h("feGaussianBlur", { in: "SourceGraphic", stdDeviation: 8 }), h("feColorMatrix", { values: "1 0 0 0 0  0 1 0 0 0  0 0 1 0 0  0 0 0 20 -9" }))),
      h("div", { className: "ai-agent-goo", style: { filter: "url(#" + id.current + ")" } }, h("i"), h("i"), h("i")));
  }

  /* ---------- NumberRoll ---------- */
  function NumberRoll(p) {
    var digits = p.digits || 6;
    var s = String(Math.max(0, Math.round(p.value || 0))).padStart(digits, "0").slice(-digits).split("");
    return h("span", { className: cx("ai-root", "ai-roll", p.className), role: "img", "aria-label": String(p.value), style: p.size ? { fontSize: p.size } : undefined },
      s.map(function (ch, i) {
        var strip = [], k;
        for (k = 0; k < 10; k++) strip.push(h("b", { key: k }, k));
        return h("span", { key: i, className: "ai-roll-col", "aria-hidden": "true" }, h("i", { style: { transform: "translateY(-" + ch + "em)" } }, strip));
      }));
  }

  /* ---------- SpotlightGrid ---------- */
  function SpotlightGrid(p) {
    var ref = useRef(null), cols = p.columns || 4;
    var items = p.items || new Array(p.count || 16).join(",").split(",").map(function () { return null; });
    function aim(x, y) {
      var kids = ref.current ? ref.current.children : [], i;
      for (i = 0; i < kids.length; i++) {
        var r = kids[i].getBoundingClientRect();
        kids[i].style.setProperty("--x", x == null ? "-200px" : x - r.left + "px");
        kids[i].style.setProperty("--y", y == null ? "-200px" : y - r.top + "px");
      }
    }
    return h("div", { ref: ref, className: cx("ai-root", "ai-spot", p.className), style: { gridTemplateColumns: "repeat(" + cols + ", var(--ai-spot-size))" },
      onPointerMove: function (e) { aim(e.clientX, e.clientY); }, onPointerLeave: function () { aim(null, null); } },
      items.map(function (it, i) { return h("div", { key: i, className: "ai-spot-tile callout", "aria-hidden": it == null ? "true" : undefined }, it); }));
  }

  /* ---------- StackedCards ---------- */
  function StackedCards(p) {
    var refs = useRef([]), items = p.items || [];
    useEffect(function () {
      function up() {
        var cs = refs.current;
        cs.forEach(function (c, i) {
          var n = cs[i + 1], k = 0;
          if (c && n && !still()) { var a = c.getBoundingClientRect(), b = n.getBoundingClientRect(); k = Math.max(0, Math.min(1, (a.bottom - b.top) / a.height)); }
          if (c) c.style.transform = k ? "scale(" + (1 - 0.05 * k) + ")" : "";
        });
      }
      window.addEventListener("scroll", up, { passive: true }); up();
      return function () { window.removeEventListener("scroll", up); };
    }, [items.length]);
    return h("div", { className: cx("ai-root", "ai-stack", p.className) },
      items.map(function (it, i) {
        return h("div", { key: it.title, ref: function (el) { refs.current[i] = el; }, className: "ai-stack-card", style: Object.assign({ "--i": i }, colorStyle(it.color)) },
          (function () { var m = /^(\d+)\s+(.*)$/.exec(it.title); return m ? h("span", { className: "ai-stack-title" }, h("span", { className: "ai-stack-num" }, m[1]), h("span", { className: "area-title" }, m[2])) : h("span", { className: "area-title" }, it.title); })(), it.note ? h("span", { className: "mono-detail ai-stack-note" }, it.note) : null);
      }));
  }

  /* ---------- KanbanBoard ---------- */
  function moveCard(cols, id, to, beforeId) {
    var card = null;
    var next = cols.map(function (c) { return { id: c.id, title: c.title, cards: c.cards.filter(function (k) { if (k.id === id) { card = k; return false; } return true; }) }; });
    if (!card) return cols;
    next.forEach(function (c) {
      if (c.id !== to) return;
      var at = -1, j;
      for (j = 0; j < c.cards.length; j++) if (c.cards[j].id === beforeId) at = j;
      if (at < 0) c.cards.push(card); else c.cards.splice(at, 0, card);
    });
    return next;
  }
  function KanbanBoard(p) {
    var st = useState(p.columns || []), cols = st[0], setCols = st[1];
    var dr = useState(null), drag = dr[0], setDrag = dr[1];
    var ov = useState(null), over = ov[0], setOver = ov[1];
    var focusId = useRef(null);
    function commit(next) { setCols(next); if (p.onChange) p.onChange(next); }
    useEffect(function () {
      if (focusId.current) { var el = document.querySelector('[data-card="' + focusId.current + '"]'); if (el) el.focus(); focusId.current = null; }
    });
    function onDrop(e, col) {
      e.preventDefault(); setOver(null);
      if (!drag) return;
      var cards = e.currentTarget.querySelectorAll(".ai-kcard:not(.ai-drag)"), before = null, i;
      for (i = 0; i < cards.length; i++) { var r = cards[i].getBoundingClientRect(); if (!before && e.clientY < r.top + r.height / 2) before = cards[i].getAttribute("data-card"); }
      commit(moveCard(cols, drag, col.id, before)); setDrag(null);
    }
    function onKey(e, col, card, idx) {
      if (!e.altKey) return;
      var ci = cols.indexOf(col), to = null, before = null;
      if (e.key === "ArrowRight" && ci < cols.length - 1) to = cols[ci + 1].id;
      else if (e.key === "ArrowLeft" && ci > 0) to = cols[ci - 1].id;
      else if (e.key === "ArrowUp" && idx > 0) { to = col.id; before = col.cards[idx - 1].id; }
      else if (e.key === "ArrowDown" && idx < col.cards.length - 1) { to = col.id; before = col.cards[idx + 2] ? col.cards[idx + 2].id : null; }
      if (!to) return;
      e.preventDefault(); focusId.current = card.id; commit(moveCard(cols, card.id, to, before));
    }
    return h("div", { className: cx("ai-root", "ai-kanban", p.className), style: { "--ai-cols": cols.length } },
      cols.map(function (col) {
        return h("section", { key: col.id, className: cx("ai-kcol", over === col.id && "ai-over"), "aria-label": col.title,
          onDragOver: function (e) { e.preventDefault(); setOver(col.id); }, onDragLeave: function () { setOver(null); }, onDrop: function (e) { onDrop(e, col); } },
          h("h3", { className: "ai-kcol-title name" }, col.title, h("span", { className: "mono-detail ai-kcol-count" }, col.cards.length)),
          col.cards.map(function (card, idx) {
            return h("div", { key: card.id, "data-card": card.id, tabIndex: 0, draggable: true, className: cx("ai-kcard callout", drag === card.id && "ai-drag"),
              onDragStart: function (e) { setDrag(card.id); e.dataTransfer.setData("text/plain", card.id); }, onDragEnd: function () { setDrag(null); setOver(null); },
              onKeyDown: function (e) { onKey(e, col, card, idx); } }, card.text);
          }));
      }));
  }

  /* ---------- ReadingPane ---------- */
  function ReadingPane(p) {
    return h("article", { className: cx("ai-root", "ai-reading", p.className) },
      h("header", { className: "ai-reading-head" }, h("h2", { className: "reading-title ai-reading-subject" }, p.subject), p.tag ? h("span", { className: "caption ai-reading-tag" }, p.tag) : null),
      h("div", { className: "ai-reading-from" },
        h("span", { className: "ai-reading-mark card-mark", "aria-hidden": "true" }, initials(p.from)),
        h("div", null, h("div", { className: "name" }, p.from), p.meta ? h("div", { className: "caption ai-reading-meta" }, p.meta) : null)),
      h("div", { className: "ai-reading-body body" }, p.children),
      p.actions && p.actions.length ? h("div", { className: "ai-reading-actions" }, p.actions.map(function (a, i) {
        return h(TextButton, { key: a.label, variant: i === 0 ? "selected" : "well", onClick: a.onClick }, a.label);
      })) : null);
  }

  /* ---------- HubTile ---------- */
  function HubTile(p) {
    var st = p.status;
    return h("button", { type: "button", className: cx("ai-root", "ai-tile", p.className), onClick: p.onClick },
      h("span", { className: "ai-tile-top" },
        h("span", { className: "caption ai-tile-eyebrow" }, p.eyebrow),
        st ? h("span", { className: cx("caption", "ai-tile-status", st === "error" && "ai-error") }, h("i", { className: "ai-tile-dot", "aria-hidden": "true" }), p.statusLabel || (st === "error" ? "Fehler" : "verbunden")) : null),
      h("span", { className: "name ai-tile-title" }, p.title),
      p.subtitle ? h("span", { className: "callout ai-tile-sub" }, p.subtitle) : null);
  }

  /* ---------- EditSheet: drei Bahnen ohne Kopf ---------- */
  function EditSheet(p) {
    var lanes = p.lanes || [];
    var rest = px("component-lane-resting-width", 300), folded = px("component-lane-folded-width", 56), at = px("component-lane-fold-threshold", 120), maxW = px("component-lane-leading-max-width", 420);
    var w = useState([lanes[0] && lanes[0].width || rest, lanes[2] && lanes[2].width || rest]), widths = w[0], setWidths = w[1];
    var mf = useState(false), midFolded = mf[0], setMidFolded = mf[1];
    var mx = useState(-1), maxed = mx[0], setMaxed = mx[1];
    var d = useState(-1), dragging = d[0], setDragging = d[1];
    var base = useRef([0, 0]), memory = useRef([widths[0], widths[1]]);
    function sideOf(i) { return i === 0 ? 0 : 1; }
    function lo(s) { var l = lanes[s === 0 ? 0 : 2] || {}; return l.min || at; }
    function hi(s) { var l = lanes[s === 0 ? 0 : 2] || {}; return l.max || maxW; }
    function clamp(s, v) { return Math.max(folded, Math.min(hi(s), v)); }
    function snap(s, v) { return v < Math.max(at, lo(s)) ? folded : v; }
    function setW(s, v) { var n = widths.slice(); n[s] = v; if (v > folded) memory.current[s] = v; setWidths(n); }
    function isFolded(i) { if (maxed >= 0) return maxed !== i; if (i === 1) return midFolded; return widths[sideOf(i)] <= folded; }
    function openCount() { var c = 0; for (var i = 0; i < 3; i++) if (!isFolded(i)) c++; return c; }
    function fold(i) { setMaxed(-1); if (i === 1) { setMidFolded(true); return; } var n = widths.slice(); n[sideOf(i)] = folded; setWidths(n); }
    function unfold(i) {
      setMaxed(-1);
      if (i === 1) { setMidFolded(false); return; }
      var s = sideOf(i); if (widths[s] > folded) return;
      var n = widths.slice(); n[s] = Math.max(memory.current[s] || rest, lo(s)); setWidths(n);
    }
    function handle(s) {
      return h(LaneHandle, { key: "h" + s, value: widths[s], label: s === 0 ? "Breite der linken Bahn" : "Breite der rechten Bahn",
        onStart: function () { base.current = widths.slice(); setMaxed(-1); setDragging(s); },
        onDrag: function (dx) { var n = widths.slice(); n[s] = clamp(s, base.current[s] + (s === 0 ? dx : -dx)); setWidths(n); },
        onEnd: function () { setW(s, snap(s, widths[s])); setDragging(-1); },
        onStep: function (dx) { setMaxed(-1); setW(s, snap(s, clamp(s, widths[s] + (s === 0 ? dx : -dx)))); },
        onReset: function () { setMaxed(-1); setW(s, Math.max(rest, lo(s))); } });
    }
    function col(i) {
      if (isFolded(i)) return folded + "px";
      if (maxed === i || i === 1) return "minmax(0,1fr)";
      var v = widths[sideOf(i)];
      return midFolded ? "minmax(" + v + "px,1fr)" : v + "px";
    }
    function lane(i) {
      var l = lanes[i]; if (!l) return h("div", { key: "l" + i });
      var big = maxed === i;
      var ctl = h("span", { key: "ctl", className: "ai-es-ctl" },
        openCount() > 1 ? h(SymbolButton, { symbol: "minus", size: "small", label: l.title + " falten", onClick: function () { fold(i); } }) : null,
        h(SymbolButton, { symbol: big ? "shrink" : "expand", size: "small", label: big ? "Zurück" : l.title + " groß", onClick: function () { setMaxed(big ? -1 : i); } }));
      return h(Lane, { key: "l" + i, title: l.title, count: l.count, dot: l.dot, folded: isFolded(i), onUnfold: function () { unfold(i); },
        actions: [l.actions ? h(R.Fragment, { key: "a" }, l.actions) : null, ctl] }, l.content);
    }
    var cols = col(0) + " var(--component-lane-handle-width) " + col(1) + " var(--component-lane-handle-width) " + col(2);
    return h("div", { className: cx("ai-root", "ai-edit-sheet", p.className), style: p.style },
      h("div", { className: cx("ai-es-lanes", dragging >= 0 && "ai-dragging"), style: { gridTemplateColumns: cols } },
        lane(0), handle(0), lane(1), handle(1), lane(2)),
      p.blob || null);
  }

  /* ---------- BlobMenu: schwebender Blob, Walzenmenü, Doppelklick ruft den Assistenten ---------- */
  function clampN(v, a, b) { return Math.max(a, Math.min(b, v)); }
  function BlobMenu(p) {
    var items = p.items || [];
    var host = useRef(null), el = useRef(null), rows = useRef([]);
    var s1 = useState(p.dock || { edge: "left", at: 0 }), dock = s1[0], setDock = s1[1];
    var s2 = useState(false), open = s2[0], setOpen = s2[1];
    var s3 = useState(false), talk = s3[0], setTalk = s3[1];
    var s4 = useState(null), drag = s4[0], setDrag = s4[1];
    var s5 = useState(-1), hot = s5[0], setHot = s5[1];
    var s6 = useState({ w: 0, h: 0 }), box = s6[0], setBox = s6[1];
    var clickT = useRef(0), hoverT = useRef(0), moved = useRef(false), flip = useRef(null);
    var inset = px("space-xs", 4), bw = px("component-lane-folded-width", 56), bh = px("component-blob-height", 36), gap = px("space-s", 8);
    var current = p.current || (items[0] && items[0].name) || "";

    useEffect(function () {
      var n = host.current; if (!n) return;
      function m() { setBox({ w: n.clientWidth, h: n.clientHeight }); }
      m();
      var ro = window.ResizeObserver ? new ResizeObserver(m) : null;
      if (ro) ro.observe(n); else window.addEventListener("resize", m);
      return function () { if (ro) ro.disconnect(); else window.removeEventListener("resize", m); clearTimeout(clickT.current); clearTimeout(hoverT.current); };
    }, []);

    function restXY() {
      var W = box.w, H = box.h, a = dock.at;
      var x = dock.edge === "left" ? inset : dock.edge === "right" ? W - bw - inset : clampN(a, inset, W - bw - inset);
      var y = dock.edge === "top" ? inset : dock.edge === "bottom" ? H - bh - inset : clampN(a, inset, H - bh - inset);
      return [x, y];
    }
    var xy = drag || restXY();
    var toEnd = xy[0] + bw / 2 > box.w / 2, toUp = xy[1] + bh / 2 > box.h / 2;

    useEffect(function () {
      var parent = host.current && host.current.parentElement; if (!parent || drag || !box.w) return;
      var c = [];
      if (xy[1] < px("component-lane-header-height", 44) + inset) { if (xy[0] < bw + inset * 2) c.push("tl"); if (xy[0] > box.w - bw * 2 - inset) c.push("tr"); }
      parent.setAttribute("data-blob-corner", c.join(" "));
    });
    R.useLayoutEffect(function () {
      var f = flip.current; flip.current = null;
      if (!f || !el.current || still() || !el.current.animate) return;
      var r = el.current.getBoundingClientRect(), dx = f[0] - r.left, dy = f[1] - r.top;
      if (Math.abs(dx) + Math.abs(dy) < 1) return;
      el.current.animate([{ transform: "translate(" + dx + "px," + dy + "px)" }, { transform: "none" }], { duration: px("motion-duration-snap", 260) * 1.6, easing: "cubic-bezier(0.2, 0.8, 0.2, 1)" });
    }, [dock]);
    useEffect(function () {
      if (!open && !talk) return;
      function away(e) { if (open && el.current && !el.current.contains(e.target)) setOpen(false); }
      function esc(e) { if (e.key === "Escape") { if (open) setOpen(false); else setTalk(false); } }
      document.addEventListener("pointerdown", away); document.addEventListener("keydown", esc);
      return function () { document.removeEventListener("pointerdown", away); document.removeEventListener("keydown", esc); };
    }, [open, talk]);

    function down(e) {
      if (open || e.button > 0) return;
      var r = host.current.getBoundingClientRect(), x0 = xy[0], y0 = xy[1], sx = e.clientX, sy = e.clientY, last = [x0, y0];
      moved.current = false;
      function mv(ev) {
        var dx = ev.clientX - sx, dy = ev.clientY - sy;
        if (!moved.current && Math.hypot(dx, dy) > 3) moved.current = true;
        if (moved.current) { last = [clampN(x0 + dx, 0, r.width - bw), clampN(y0 + dy, 0, r.height - bh)]; setDrag(last); }
      }
      function up() {
        window.removeEventListener("pointermove", mv); window.removeEventListener("pointerup", up); window.removeEventListener("pointercancel", up);
        if (!moved.current) return;
        var x = last[0], y = last[1], dl = x, dr = r.width - x - bw, dt = y, db = r.height - y - bh, m = Math.min(dl, dr, dt, db);
        var nd = m === dl ? { edge: "left", at: y } : m === dr ? { edge: "right", at: y } : m === dt ? { edge: "top", at: x } : { edge: "bottom", at: x };
        flip.current = [r.left + x, r.top + y];
        setDrag(null); setDock(nd); if (p.onDock) p.onDock(nd);
      }
      window.addEventListener("pointermove", mv); window.addEventListener("pointerup", up); window.addEventListener("pointercancel", up);
    }
    function click() {
      if (moved.current) { moved.current = false; return; }
      clearTimeout(clickT.current);
      clickT.current = setTimeout(function () { setOpen(function (o) { return !o; }); setHot(-1); }, 240);
    }
    function assistant() { clearTimeout(clickT.current); setOpen(false); setTalk(function (t) { return !t; }); if (p.onAssistant) p.onAssistant(); }
    function choose(name, link) { setOpen(false); setHot(-1); if (p.onSelect) p.onSelect(name, link); }
    function aim(i) { clearTimeout(hoverT.current); hoverT.current = setTimeout(function () { setHot(i); }, 160); }
    function keys(e) {
      var n = items.length;
      if (e.key === "ArrowDown") { e.preventDefault(); setHot(clampN(hot + (toUp ? -1 : 1), 0, n - 1)); }
      if (e.key === "ArrowUp") { e.preventDefault(); setHot(clampN(hot + (toUp ? 1 : -1), 0, n - 1)); }
      if (e.key === "Enter" && items[hot] && e.target === e.currentTarget) { e.preventDefault(); choose(items[hot].name); }
    }

    var style;
    if (drag || !open) style = { left: xy[0], top: xy[1] };
    else style = Object.assign({}, toEnd ? { right: box.w - xy[0] - bw } : { left: xy[0] }, toUp ? { bottom: box.h - xy[1] - bh } : { top: xy[1] });
    if (!box.w) style.visibility = "hidden";
    var hr = hot >= 0 && rows.current[hot];
    var glide = hr ? { transform: "translateY(" + hr.offsetTop + "px)", height: hr.offsetHeight + "px", opacity: 1 } : { opacity: 0 };

    var card = null;
    if (talk && p.assistant && box.w) {
      var cs = Object.assign({}, toEnd ? { right: Math.max(inset, box.w - xy[0] - bw) } : { left: xy[0] },
        toUp ? { bottom: box.h - xy[1] + gap, maxHeight: Math.max(160, xy[1] - gap - inset) } : { top: xy[1] + bh + gap, maxHeight: Math.max(160, box.h - xy[1] - bh - gap - inset) });
      cs.maxWidth = box.w - inset * 2;
      card = h("div", { className: cx("ai-bm-card", toUp && "ai-up"), style: cs },
        R.isValidElement(p.assistant) ? R.cloneElement(p.assistant, { onClose: function () { setTalk(false); if (p.assistant.props.onClose) p.assistant.props.onClose(); } }) : p.assistant);
    }

    return h("div", { ref: host, className: cx("ai-root", "ai-bm-layer", p.className) },
      h("div", { ref: el, className: cx("ai-bm", open && "ai-open", drag && "ai-dragging", toEnd && "ai-end", toUp && "ai-up", talk && "ai-talking"), style: style },
        h("div", { className: "ai-bm-pill", onPointerDown: down },
          h("button", { type: "button", className: "ai-bm-top", "aria-haspopup": "menu", "aria-expanded": open,
            "aria-label": "Menü, " + current + ". Doppelklick oder Alt und Enter öffnet den Assistenten.",
            onClick: click, onDoubleClick: assistant,
            onKeyDown: function (e) { if (e.key === "Enter" && e.altKey) { e.preventDefault(); assistant(); } else if (e.key === "ArrowDown" && !open) { e.preventDefault(); setOpen(true); setHot(0); } } },
            h("span", { className: "ai-bm-face", "aria-hidden": "true" }, h("i", { className: "ai-bm-eye" }), h("i", { className: "ai-bm-eye" })),
            h("span", { className: "ai-bm-label" }, current),
            p.notice ? h("span", { className: "ai-bm-notice", "aria-label": "Ungelesenes" }) : null),
          open ? h("div", { className: "ai-reel", role: "menu", "aria-label": "Bereiche", tabIndex: -1, onKeyDown: keys, onPointerLeave: function () { clearTimeout(hoverT.current); } },
            h("span", { className: "ai-reel-glide", style: glide, "aria-hidden": "true" }),
            items.map(function (it, i) {
              var on = i === hot;
              return h("div", { key: it.name, className: cx("ai-reel-item", on && "ai-hot"), style: { "--i": i }, onPointerEnter: function () { aim(i); } },
                h("button", { ref: function (b) { rows.current[i] = b; }, type: "button", role: "menuitem", className: cx("ai-reel-row", it.name === current && "ai-current"),
                  onFocus: function () { setHot(i); }, onClick: function () { choose(it.name); } },
                  h("span", null, it.name), it.count != null ? h("span", { className: "ai-reel-count" }, it.count) : null),
                it.links && it.links.length ? h("div", { className: "ai-reel-sub", "aria-hidden": !on },
                  h("div", null, it.links.map(function (l, j) {
                    return h("button", { key: l, type: "button", role: "menuitem", tabIndex: on ? 0 : -1, className: "ai-reel-link", style: { "--j": j }, onClick: function () { choose(it.name, l); } }, l);
                  }))) : null);
            }),
            p.assistant ? h("div", { className: "ai-reel-item", style: { "--i": items.length } },
              h("span", { className: "ai-reel-sep", "aria-hidden": "true" }),
              h("button", { type: "button", role: "menuitem", className: "ai-reel-row", onClick: assistant },
                h("span", null, "Assistent"), h("span", { className: "ai-reel-count" }, "2×"))) : null) : null)),
      card);
  }

  /* ---------- ThinkingOrb ---------- */
  function ThinkingOrb(p) {
    var s = p.size || 56;
    return h("span", { className: cx("ai-root", "ai-orb", p.thinking && "ai-thinking", p.className), style: { "--orb": s + "px" }, role: "img", "aria-label": p.label || (p.thinking ? "Denkt nach" : "Assistent") },
      h("i"), h("i"), h("i"), h("b"));
  }

  /* ---------- AssistantCard ---------- */
  var attSeq = 0;
  var URL_ONE = /^https?:\/\/\S+$/i, URL_ALL = /https?:\/\/[^\s<>"']+/g;
  function fmtSize(n) { n = n || 0; return n < 1024 ? n + " B" : n < 1048576 ? (n / 1024).toFixed(1).replace(".", ",") + " kB" : (n / 1048576).toFixed(1).replace(".", ",") + " MB"; }
  function hostOf(u) { try { return new URL(u).hostname.replace(/^www\./, ""); } catch (e) { return u; } }
  function looksHtml(t) { return /^\s*<(!doctype|html|head|body|div|section|article|main|svg|table|style|p|h[1-6]|ul|ol|span|img)\b/i.test(t) && /<\/[a-z0-9]+>|\/>/i.test(t); }
  function readFile(f) {
    return new Promise(function (res) {
      var a = { id: ++attSeq, kind: "file", name: f.name || "eingefügt", type: f.type || "", size: f.size };
      var isImg = /^image\//.test(a.type), isHtml = /html/.test(a.type) || /\.html?$/i.test(a.name), isPdf = a.type === "application/pdf" || /\.pdf$/i.test(a.name);
      var isText = isHtml || /^text\/|json|xml|csv|markdown|javascript/.test(a.type) || /\.(txt|md|csv|json|js|ts|css|xml|log|yml|yaml)$/i.test(a.name);
      var rd = new FileReader();
      rd.onerror = function () { res(a); };
      if (isImg) {
        a.kind = "image";
        rd.onload = function () { a.url = rd.result; var im = new Image(); im.onload = function () { a.w = im.naturalWidth; a.h = im.naturalHeight; res(a); }; im.onerror = function () { res(a); }; im.src = a.url; };
        rd.readAsDataURL(f);
      } else if (isText) {
        a.kind = isHtml ? "html" : "text";
        rd.onload = function () { a.text = String(rd.result).slice(0, 200000); a.lines = a.text.split("\n").length; res(a); };
        rd.readAsText(f);
      } else if (isPdf) { a.kind = "pdf"; a.url = URL.createObjectURL(f); res(a); }
      else res(a);
    });
  }
  function readScope(node) {
    var scope = (node && node.closest && node.closest(".ai-edit-sheet")) || document.body;
    var lanes = Array.prototype.map.call(scope.querySelectorAll(".ai-lane"), function (l) {
      return { title: l.getAttribute("aria-label") || "", folded: l.classList.contains("ai-folded"), text: String(l.innerText || "").replace(/\n{3,}/g, "\n\n").trim().slice(0, 4000) };
    });
    var shots = [];
    Array.prototype.forEach.call(scope.querySelectorAll("canvas"), function (c, i) {
      if (c.closest(".ai-assist")) return;
      var name = c.getAttribute("aria-label") || "Canvas " + (i + 1);
      try { shots.push({ name: name, url: c.toDataURL("image/png"), w: c.width, h: c.height }); } catch (e) { shots.push({ name: name, blocked: true }); }
    });
    return { id: ++attSeq, kind: "scope", name: "Bogen", lanes: lanes, canvases: shots };
  }
  function describe(a) {
    if (a.kind === "image") return "Bild " + a.name + (a.w ? ", " + a.w + " × " + a.h + " px" : "") + ", " + fmtSize(a.size) + ".";
    if (a.kind === "text") return "Text " + a.name + ", " + a.lines + " Zeilen, beginnt mit „" + a.text.trim().split(/\s+/).slice(0, 8).join(" ") + " …“.";
    if (a.kind === "html") return "HTML " + a.name + ", " + a.lines + " Zeilen, oben gerendert.";
    if (a.kind === "pdf") return "PDF " + a.name + ", " + fmtSize(a.size) + ", oben angezeigt.";
    if (a.kind === "link") return "Link zu " + hostOf(a.url) + ". Öffnen kann die Karte ihn nicht, das macht das verbundene Modell.";
    if (a.kind === "scope") {
      var chars = a.lanes.reduce(function (s, l) { return s + l.text.length; }, 0);
      return "Bogen: " + a.lanes.length + " Bahnen (" + a.lanes.map(function (l) { return l.title + (l.folded ? ", gefaltet" : ""); }).join("; ") + "), " + chars + " Zeichen Text, " + a.canvases.length + " Canvas" + (a.canvases.length ? " (" + a.canvases.map(function (c) { return c.blocked ? c.name + " gesperrt" : c.name + " " + c.w + " × " + c.h; }).join(", ") + ")" : "") + ".";
    }
    return "Datei " + a.name + ", " + fmtSize(a.size) + ", Art unbekannt.";
  }
  function localReply(msg) {
    var lines = ["Kein Modell verbunden. So kommt es hier an:"];
    if (msg.text) lines.push("Text: " + msg.text.length + " Zeichen.");
    msg.atts.forEach(function (a) { lines.push("· " + describe(a)); });
    if (!msg.atts.length && !msg.text) lines.push("Nichts.");
    lines.push("Mit onSend antwortet hier das echte Modell.");
    return lines.join("\n");
  }
  function splitHtml(text) {
    var m = /```html\s*\n([\s\S]*?)```/i.exec(text || "");
    return m ? { text: (text.slice(0, m.index) + text.slice(m.index + m[0].length)).trim(), html: m[1] } : { text: text, html: null };
  }
  function Att(p) {
    var a = p.a;
    if (a.kind === "image") return h("figure", { className: "ai-att" }, h("img", { src: a.url, alt: a.name }), h("figcaption", { className: "caption" }, a.name + (a.w ? " · " + a.w + " × " + a.h : "")));
    if (a.kind === "html") return h("figure", { className: "ai-att" }, h("iframe", { title: a.name, sandbox: "allow-scripts", srcDoc: a.text }), h("figcaption", { className: "caption" }, a.name + " · gerendert"));
    if (a.kind === "pdf") return h("figure", { className: "ai-att" }, h("iframe", { title: a.name, src: a.url }), h("figcaption", { className: "caption" }, a.name + " · " + fmtSize(a.size)));
    if (a.kind === "text") return h("figure", { className: "ai-att" }, h("pre", { className: "ai-att-pre" }, a.text.split("\n").slice(0, 8).join("\n")), h("figcaption", { className: "caption" }, a.name + " · " + a.lines + " Zeilen"));
    if (a.kind === "link") return h("a", { className: "ai-att-link", href: a.url, target: "_blank", rel: "noopener noreferrer" }, h(Symbol, { name: "link", size: 14 }), h("span", { className: "name" }, hostOf(a.url)), h("span", { className: "ai-att-url" }, a.url));
    if (a.kind === "scope") return h("figure", { className: "ai-att" },
      h("div", { className: "ai-att-scope" },
        h("span", { className: "name" }, "Bogen gelesen"),
        h("span", null, a.lanes.map(function (l) { return l.title; }).join(" · ")),
        a.canvases.length ? h("span", { className: "ai-att-shots" }, a.canvases.map(function (c, i) { return c.blocked ? h("span", { key: i }, c.name + " gesperrt") : h("img", { key: i, src: c.url, alt: c.name }); })) : null));
    return h("span", { className: "ai-att-link" }, h(Symbol, { name: "attach", size: 14 }), h("span", { className: "name" }, a.name), h("span", { className: "ai-att-url" }, fmtSize(a.size)));
  }
  function AssistantCard(p) {
    var card = useRef(null), log = useRef(null), input = useRef(null), picker = useRef(null);
    var s1 = useState(p.messages || []), msgs = s1[0], setMsgs = s1[1];
    var s2 = useState(""), draft = s2[0], setDraft = s2[1];
    var s3 = useState([]), pending = s3[0], setPending = s3[1];
    var s4 = useState(false), thinking = s4[0], setThinking = s4[1];
    var s5 = useState(false), dropping = s5[0], setDropping = s5[1];
    useEffect(function () { if (log.current) log.current.scrollTop = log.current.scrollHeight; }, [msgs.length, thinking]);
    useEffect(function () { if (input.current) input.current.focus(); }, []);
    function add(list) { setPending(function (cur) { return cur.concat(list); }); }
    function addFiles(files) { Promise.all(Array.prototype.map.call(files, readFile)).then(add); }
    function onPaste(e) {
      var cd = e.clipboardData; if (!cd) return;
      if (cd.files && cd.files.length) { e.preventDefault(); addFiles(cd.files); return; }
      var t = cd.getData("text/plain") || "";
      if (URL_ONE.test(t.trim())) { e.preventDefault(); add([{ id: ++attSeq, kind: "link", url: t.trim(), name: hostOf(t.trim()) }]); return; }
      if (looksHtml(t)) { e.preventDefault(); add([{ id: ++attSeq, kind: "html", name: "eingefügt.html", text: t, lines: t.split("\n").length }]); }
    }
    function onDrop(e) {
      e.preventDefault(); setDropping(false);
      var dt = e.dataTransfer; if (!dt) return;
      if (dt.files && dt.files.length) { addFiles(dt.files); return; }
      var u = (dt.getData("text/uri-list") || dt.getData("text/plain") || "").trim();
      if (URL_ONE.test(u)) add([{ id: ++attSeq, kind: "link", url: u, name: hostOf(u) }]);
    }
    function send() {
      var text = draft.trim();
      if ((!text && !pending.length) || thinking) return;
      var atts = pending.slice();
      (text.match(URL_ALL) || []).forEach(function (u) { if (!atts.some(function (a) { return a.url === u; })) atts.push({ id: ++attSeq, kind: "link", url: u, name: hostOf(u) }); });
      var msg = { id: ++attSeq, role: "user", text: text, atts: atts }, next = msgs.concat([msg]);
      setMsgs(next); setDraft(""); setPending([]); setThinking(true);
      var pr = p.onSend ? Promise.resolve().then(function () { return p.onSend(text, atts, next); })
        : new Promise(function (res) { setTimeout(function () { res(localReply(msg)); }, 1600); });
      pr.then(function (r) {
        var t = typeof r === "string" ? r : (r && r.text) || "", sp = splitHtml(t);
        setMsgs(function (cur) { return cur.concat([{ id: ++attSeq, role: "assistant", text: sp.text, html: (r && r.html) || sp.html, atts: [] }]); });
      }, function (err) {
        setMsgs(function (cur) { return cur.concat([{ id: ++attSeq, role: "assistant", text: "Antwort fehlgeschlagen. " + (err && err.message ? err.message : "Bitte noch einmal senden."), atts: [], error: true }]); });
      }).then(function () { setThinking(false); });
    }
    function bubble(m) {
      var body = [
        m.text ? h("div", { key: "t", className: cx("ai-msg-text", m.error && "ai-error") }, m.text) : null,
        m.html ? h(Att, { key: "h", a: { kind: "html", name: "Antwort.html", text: m.html } }) : null,
        m.atts.length ? h("div", { key: "a", className: "ai-msg-atts" }, m.atts.map(function (a) { return h(Att, { key: a.id, a: a }); })) : null
      ];
      if (m.role === "user") return h("div", { key: m.id, className: "ai-msg ai-msg-user" }, body);
      return h("div", { key: m.id, className: "ai-msg ai-msg-bot" }, h(ThinkingOrb, { size: 20, label: "Assistent" }), h("div", { className: "ai-msg-col" }, body));
    }
    return h("section", { ref: card, className: cx("ai-root", "ai-assist", dropping && "ai-dropping", p.className), role: "dialog", "aria-label": p.title || "Assistent", style: p.style,
      onDragOver: function (e) { e.preventDefault(); if (!dropping) setDropping(true); }, onDragLeave: function (e) { if (!card.current.contains(e.relatedTarget)) setDropping(false); }, onDrop: onDrop,
      onKeyDown: function (e) { if (e.key === "Escape" && p.onClose) { e.stopPropagation(); p.onClose(); } } },
      h("div", { className: "ai-assist-head" },
        h(ThinkingOrb, { size: 32, thinking: thinking }),
        h("div", { className: "ai-assist-name" }, h("span", { className: "name" }, p.title || "Assistent"), h("span", { className: "caption ai-assist-status", "aria-live": "polite" }, thinking ? "Denkt nach …" : p.status || "Bereit")),
        p.onClose ? h(SymbolButton, { symbol: "close", label: "Schließen", onClick: p.onClose }) : null),
      h("div", { ref: log, className: "ai-assist-log", "aria-live": "polite" },
        msgs.length ? msgs.map(bubble) : h("div", { className: "ai-assist-empty" },
          h(ThinkingOrb, { size: 88, thinking: thinking }),
          h("span", { className: "callout" }, "Frag etwas. Dateien, Bilder, Links und HTML einfügen oder hineinziehen. „Bogen lesen“ gibt mir, was gerade offen ist.")),
        thinking ? h("div", { className: "ai-assist-thinking caption" }, h(ThinkingOrb, { size: 20, thinking: true }), "denkt …") : null),
      h("div", { className: "ai-assist-compose" },
        pending.length ? h("div", { className: "ai-assist-pending" }, pending.map(function (a) {
          return h(Chip, { key: a.id, inRow: true, onRemove: function () { setPending(function (cur) { return cur.filter(function (x) { return x.id !== a.id; }); }); } }, a.kind === "link" ? hostOf(a.url) : a.name);
        })) : null,
        h("textarea", { ref: input, rows: 2, value: draft, placeholder: "Fragen, Datei oder Link einfügen", "aria-label": "Nachricht",
          onChange: function (e) { setDraft(e.target.value); }, onPaste: onPaste,
          onKeyDown: function (e) { if (e.key === "Enter" && !e.shiftKey && !e.nativeEvent.isComposing) { e.preventDefault(); send(); } } }),
        h("div", { className: "ai-assist-tools" },
          h("input", { ref: picker, type: "file", multiple: true, hidden: true, onChange: function (e) { addFiles(e.target.files); e.target.value = ""; } }),
          h(SymbolButton, { symbol: "attach", size: "small", label: "Datei anhängen", onClick: function () { picker.current.click(); } }),
          h(SymbolButton, { symbol: "eye", size: "small", label: "Bogen lesen", onClick: function () { add([readScope(card.current)]); } }),
          h("span", { className: "ai-spacer" }),
          h(SymbolButton, { symbol: "send", size: "small", variant: "selected", label: "Senden", disabled: thinking || (!draft.trim() && !pending.length), onClick: send }))));
  }

  /* ---------- CardTower: starre Körper ---------- */
  /* Eine Karte ist ein Kasten mit Ort, Winkel und Geschwindigkeit, in einem Raum aus Boden und Wänden.
     Nichts darin weiß, was ein Turm ist: eine Karte kippt, weil ihr Schwerpunkt über die Kante der Unterlage ragt.
     Fester Schritt mit 240 Hz, Kontakte werden von Schritt zu Schritt behalten (das hält den Stapel), y zeigt nach oben. */
  function twAxes(b) { var c = Math.cos(b.a), s = Math.sin(b.a); return [[c, s], [-s, c]]; }
  function twExt(b, n) { var a = twAxes(b); return Math.abs(a[0][0] * n[0] + a[0][1] * n[1]) * b.hw + Math.abs(a[1][0] * n[0] + a[1][1] * n[1]) * b.hh; }
  function twVerts(b) {
    var a = twAxes(b), sx = [-1, 1, 1, -1], sy = [-1, -1, 1, 1], r = [], i;
    for (i = 0; i < 4; i++) r.push([b.x + a[0][0] * sx[i] * b.hw + a[1][0] * sy[i] * b.hh, b.y + a[0][1] * sx[i] * b.hw + a[1][1] * sy[i] * b.hh]);
    return r;
  }
  function twCollide(A, B) {
    var dx = B.x - A.x, dy = B.y - A.y, best = 1e9, bn = null, bref = 0, bk = 0, ri, k, R, ax, n, d, nn, ov, out = [];
    for (ri = 0; ri < 2; ri++) {
      R = ri ? B : A; ax = twAxes(R);
      for (k = 0; k < 2; k++) {
        n = ax[k]; d = dx * n[0] + dy * n[1]; nn = d < 0 ? [-n[0], -n[1]] : [n[0], n[1]];
        ov = twExt(A, nn) + twExt(B, nn) - Math.abs(d);
        if (ov < 0) return out;
        if (ov < best - 0.01) { best = ov; bn = nn; bref = ri; bk = k; }
      }
    }
    var Rb = bref ? B : A, Ib = bref ? A : B, nr = bref ? [-bn[0], -bn[1]] : bn, t = [-nr[1], nr[0]];
    var dR = Rb.x * nr[0] + Rb.y * nr[1] + twExt(Rb, nr), eT = twExt(Rb, t);
    var iv = twVerts(Ib).map(function (v, i) { return { v: v, i: i, d: v[0] * nr[0] + v[1] * nr[1] }; }).sort(function (p, q) { return p.d - q.d; }).slice(0, 2);
    var pts = iv.map(function (o) { return { v: o.v, i: o.i, t: (o.v[0] - Rb.x) * t[0] + (o.v[1] - Rb.y) * t[1] }; });
    var p1 = pts[0], p2 = pts[1], j, res = [];
    [p1, p2].forEach(function (p, idx) {
      var q = idx ? p1 : p2;
      if (p.t > eT || p.t < -eT) {
        var lim = p.t > eT ? eT : -eT;
        if ((q.t > eT && p.t > eT) || (q.t < -eT && p.t < -eT)) return;
        var f = (lim - p.t) / (q.t - p.t);
        res.push({ v: [p.v[0] + (q.v[0] - p.v[0]) * f, p.v[1] + (q.v[1] - p.v[1]) * f], i: p.i });
      } else res.push({ v: p.v, i: p.i });
    });
    for (j = 0; j < res.length; j++) {
      var sep = res[j].v[0] * nr[0] + res[j].v[1] * nr[1] - dR;
      if (sep < 1) out.push({ a: A, b: B, n: bn, p: res[j].v, sep: sep, pn: 0, pt: 0, id: (bref * 2 + bk) * 8 + res[j].i });
    }
    return out;
  }
  function twWorld(W, H, sizes, opts) {
    var bodies = [], g = opts.gravity, i;
    function mk(x, y, hw, hh, dyn) {
      var m = dyn ? hw * hh * 4 / 1000 : 0, b = { x: x, y: y, a: 0, vx: 0, vy: 0, w: 0, hw: hw, hh: hh, invM: dyn ? 1 / m : 0, invI: dyn ? 12 / (m * (4 * hw * hw + 4 * hh * hh)) : 0, fr: 0.6, dyn: dyn };
      b.invM0 = b.invM; b.invI0 = b.invI; b.i = bodies.length; bodies.push(b); return b;
    }
    mk(W / 2, 16 - 50, W, 50, false); mk(16 - 50, 2000, 50, 4000, false); mk(W - 16 + 50, 2000, 50, 4000, false);
    var cards = [];
    function stack() {
      var yy = 16;
      sizes.forEach(function (s, k) {
        var c = cards[k] || (cards[k] = mk(0, 0, s.w / 2, s.h / 2, true));
        c.x = W / 2 + ((k * 7919) % 5 - 2) * 0.6; c.y = yy + s.h / 2 + 0.5; yy += s.h + 0.5; c.a = 0; c.vx = c.vy = c.w = 0; c.invM = c.invM0; c.invI = c.invI0; c.fr = 0.6;
      });
      memory = {};
    }
    var memory = {}, held = null, target = [0, 0];
    stack();
    function step(dt) {
      var pairs = [], x, y, k, it, cs = [], A, B;
      for (x = 0; x < bodies.length; x++) for (y = x + 1; y < bodies.length; y++) {
        A = bodies[x]; B = bodies[y]; if (!A.dyn && !B.dyn) continue;
        if (Math.hypot(A.x - B.x, A.y - B.y) > Math.hypot(A.hw, A.hh) + Math.hypot(B.hw, B.hh) + 4) continue;
        var key = x * 100 + y, found = twCollide(A, B), old = memory[key] || [];
        found.forEach(function (c) { old.forEach(function (o) { if (o.id === c.id) { c.pn = o.pn; c.pt = o.pt; } }); });
        pairs.push([key, found]); cs = cs.concat(found);
      }
      var nm = {}; pairs.forEach(function (p) { nm[p[0]] = p[1]; }); memory = nm;
      bodies.forEach(function (b) { if (b.dyn && b !== held) b.vy -= g * dt; });
      if (held) {
        var dx = target[0] - held.x, dy = target[1] - held.y, vx = dx * 18, vy = dy * 18, sp = Math.hypot(vx, vy);
        if (sp > 1800) { vx *= 1800 / sp; vy *= 1800 / sp; }
        var ax = vx - held.vx, ay = vy - held.vy, al = Math.hypot(ax, ay), mx = 16000 * dt;
        if (al > mx) { ax *= mx / al; ay *= mx / al; }
        held.vx += ax; held.vy += ay; held.w += (-held.a * 40 - held.w * 10) * dt;
      }
      cs.forEach(function (c) {
        var A2 = c.a, B2 = c.b, n = c.n, t = [n[1], -n[0]];
        c.r1 = [c.p[0] - A2.x, c.p[1] - A2.y]; c.r2 = [c.p[0] - B2.x, c.p[1] - B2.y]; c.t = t;
        var r1n = c.r1[0] * n[1] - c.r1[1] * n[0], r2n = c.r2[0] * n[1] - c.r2[1] * n[0], r1t = c.r1[0] * t[1] - c.r1[1] * t[0], r2t = c.r2[0] * t[1] - c.r2[1] * t[0];
        c.mn = 1 / (A2.invM + B2.invM + A2.invI * r1n * r1n + B2.invI * r2n * r2n);
        c.mt = 1 / (A2.invM + B2.invM + A2.invI * r1t * r1t + B2.invI * r2t * r2t);
        c.bias = 0.2 / dt * Math.max(0, -c.sep - 0.5);
        c.fric = Math.min(A2.fr, B2.fr);
        push(c, c.pn * n[0] + c.pt * t[0], c.pn * n[1] + c.pt * t[1]);
      });
      function push(c, px_, py_) {
        var A2 = c.a, B2 = c.b;
        A2.vx -= px_ * A2.invM; A2.vy -= py_ * A2.invM; A2.w -= A2.invI * (c.r1[0] * py_ - c.r1[1] * px_);
        B2.vx += px_ * B2.invM; B2.vy += py_ * B2.invM; B2.w += B2.invI * (c.r2[0] * py_ - c.r2[1] * px_);
      }
      function rel(c) {
        var A2 = c.a, B2 = c.b;
        return [B2.vx - B2.w * c.r2[1] - A2.vx + A2.w * c.r1[1], B2.vy + B2.w * c.r2[0] - A2.vy - A2.w * c.r1[0]];
      }
      for (it = 0; it < 12; it++) cs.forEach(function (c) {
        var dv = rel(c), vn = dv[0] * c.n[0] + dv[1] * c.n[1], d = c.mn * (-vn + c.bias), np = Math.max(c.pn + d, 0);
        d = np - c.pn; c.pn = np; push(c, d * c.n[0], d * c.n[1]);
        dv = rel(c); var vt = dv[0] * c.t[0] + dv[1] * c.t[1], dt2 = -c.mt * vt, mxp = c.fric * c.pn, nt = Math.max(-mxp, Math.min(mxp, c.pt + dt2));
        dt2 = nt - c.pt; c.pt = nt; push(c, dt2 * c.t[0], dt2 * c.t[1]);
      });
      bodies.forEach(function (b) { if (b.dyn) { b.w *= 1 - 0.4 * dt; b.x += b.vx * dt; b.y += b.vy * dt; b.a += b.w * dt; } });
    }
    return {
      bodies: bodies, cards: cards, step: step, stack: stack,
      grab: function (b, tx, ty) { held = b; target = [tx, ty]; b.invM = b.invM0 * 0.35; b.invI = b.invI0 * 0.35; b.fr = 0; },
      aim: function (tx, ty) { target = [tx, ty]; },
      drop: function () { if (held) { held.invM = held.invM0; held.invI = held.invI0; held.fr = 0.6; held = null; } },
      held: function () { return held; },
      speed: function () { var m = 0; cards.forEach(function (c) { m = Math.max(m, Math.abs(c.vx) + Math.abs(c.vy) + Math.abs(c.w) * 40); }); return m; }
    };
  }
  function CardTower(p) {
    var host = useRef(null), els = useRef([]), api = useRef(null), dn = useState({}), done = dn[0], setDone = dn[1];
    var items = p.items || ["Flüge buchen", "Icons exportieren", "Rechnung zahlen", "Vermieter anrufen", "Aufmaß prüfen", "Angebot senden"];
    var H = p.height || 420, ch = p.cardHeight || 52;
    useEffect(function () {
      var el = host.current, W = el.clientWidth, cw = Math.min(p.cardWidth || 260, W * 0.7);
      var sizes = items.map(function () { return { w: cw, h: ch }; });
      var world = twWorld(W, H, sizes, { gravity: p.gravity || 2400 }); api.current = world;
      var acc = 0, last = performance.now(), raf = 0, rest = 0, asleep = false, grabOff = [0, 0], idx = -1, down = null;
      function draw() { world.cards.forEach(function (c, k) { var e = els.current[k]; if (e) e.style.transform = "translate(" + (c.x - c.hw) + "px," + (H - (c.y + c.hh)) + "px) rotate(" + (-c.a) + "rad)"; }); }
      function loop(now) {
        raf = requestAnimationFrame(loop);
        var dt = Math.min(0.05, (now - last) / 1000); last = now;
        if (!asleep) {
          acc += dt; var n = 0; while (acc >= 1 / 240 && n < 20) { world.step(1 / 240); acc -= 1 / 240; n++; }
          if (!world.held() && world.speed() < 3) { rest++; if (rest > 90) asleep = true; } else rest = 0;
        }
        draw();
      }
      function pt(e) { var r = el.getBoundingClientRect(); return [e.clientX - r.left, H - (e.clientY - r.top)]; }
      function wake() { asleep = false; rest = 0; }
      function onDown(e) {
        var card = e.target.closest ? e.target.closest(".ai-tw-card") : null; if (!card) return;
        idx = els.current.indexOf(card); if (idx < 0) return;
        var q = pt(e), b = world.cards[idx]; grabOff = [q[0] - b.x, q[1] - b.y]; down = [e.clientX, e.clientY, e.target];
        world.grab(b, b.x, b.y); wake(); card.classList.add("ai-held"); el.setPointerCapture(e.pointerId);
      }
      function onMove(e) { if (idx < 0) return; var q = pt(e); world.aim(Math.max(16, Math.min(W - 16, q[0] - grabOff[0])), Math.max(16, q[1] - grabOff[1])); wake(); }
      function onUp(e) {
        if (idx < 0) return;
        var k = idx; idx = -1; world.drop(); wake(); els.current[k].classList.remove("ai-held");
        if (down && Math.hypot(e.clientX - down[0], e.clientY - down[1]) < 4 && down[2].closest && down[2].closest(".ai-tw-box")) setDone(function (d) { var o = Object.assign({}, d); o[k] = !o[k]; return o; });
      }
      el.addEventListener("pointerdown", onDown); el.addEventListener("pointermove", onMove); el.addEventListener("pointerup", onUp); el.addEventListener("pointercancel", onUp);
      el._tidy = function () { world.stack(); wake(); };
      draw(); raf = requestAnimationFrame(loop);
      return function () { cancelAnimationFrame(raf); el.removeEventListener("pointerdown", onDown); el.removeEventListener("pointermove", onMove); el.removeEventListener("pointerup", onUp); el.removeEventListener("pointercancel", onUp); };
    }, []);
    var cw0 = p.cardWidth || 260;
    return h("div", { ref: host, className: cx("ai-root", "ai-tower", p.className), style: Object.assign({ height: H }, p.style) },
      items.map(function (t, i) {
        return h("div", { key: i, ref: function (e) { els.current[i] = e; }, className: cx("ai-tw-card", done[i] && "ai-done"), style: { width: Math.min(cw0, 9999), height: ch } },
          h("span", { className: "ai-tw-box" }), h("span", { className: "ai-tw-label" }, t));
      }),
      h("button", { className: "ai-tbtn ai-tbtn-well ai-tw-tidy", type: "button", onClick: function () { host.current && host.current._tidy && host.current._tidy(); } }, "Ordnen"));
  }

  window.ALFA = Object.assign(window.ALFA || {}, {
    CardTower: CardTower, EditSheet: EditSheet, BlobMenu: BlobMenu, AssistantCard: AssistantCard, ThinkingOrb: ThinkingOrb,
    Shell: Shell, Lane: Lane, LaneHandle: LaneHandle, Blob: Blob, TileMenu: TileMenu, MessageRow: MessageRow,
    SyncButton: SyncButton, PersonMark: PersonMark, TextButton: TextButton, SymbolButton: SymbolButton, Chip: Chip, SearchField: SearchField, Symbol: Symbol,
    ArcBars: ArcBars, PillStack: PillStack, Tooltip: Tooltip, DotSphere: DotSphere, GlowButton: GlowButton, AgentPill: AgentPill, NumberRoll: NumberRoll, SpotlightGrid: SpotlightGrid, StackedCards: StackedCards, KanbanBoard: KanbanBoard, ReadingPane: ReadingPane, HubTile: HubTile
  });
})();
