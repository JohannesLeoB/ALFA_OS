import CoreGraphics
import Foundation

public struct Region: Sendable, Equatable {
    public var state: String
    public var polygon: [CGPoint]
    public var current: Bool

    public init(state: String, polygon: [CGPoint], current: Bool = false) {
        self.state = state; self.polygon = polygon; self.current = current
    }
}

public struct Interactive: Sendable {
    public var title: String
    public var language: String
    public var base: Page
    public var order: [String]
    public var states: [String: Page]
    public var regions: [Region]
    public var captions: [String: String]
    public var idle: String
    public var fade: Double
    public var fonts: [FontFace]

    public init(title: String, language: String = "", base: Page, order: [String], states: [String: Page],
                regions: [Region], captions: [String: String] = [:], idle: String = "", fade: Double = 0,
                fonts: [FontFace] = []) {
        self.title = title; self.language = language; self.base = base; self.order = order; self.states = states
        self.regions = regions; self.captions = captions; self.idle = idle; self.fade = fade; self.fonts = fonts
    }

    public var ids: [String] {
        var seen = Set<String>()
        return order.filter { states[$0] != nil && seen.insert($0).inserted }
    }

    public func html() -> String {
        let w = SVGRenderer.f(base.size.width), h = SVGRenderer.f(base.size.height)
        let sans = Interactive.name(FontFace.family(.sans, in: fonts))
        let live = Set(ids)
        var out: [String] = ["<!doctype html>"]
        out.append("<html\(language.isEmpty ? "" : " lang=\"\(SVGRenderer.esc(language))\"")>")
        out.append("<head><meta charset=\"utf-8\"><meta name=\"viewport\" content=\"width=device-width,initial-scale=1\">")
        out.append("<title>\(SVGRenderer.esc(title))</title>")
        out.append("<style>\(css(sans))</style></head>")
        out.append("<body><main id=\"view\">")
        out.append("<svg id=\"sheet\" xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 \(w) \(h)\" "
                   + "font-family=\"\(SVGRenderer.esc(FontFace.family(.sans, in: fonts)))\" role=\"img\" aria-label=\"\(SVGRenderer.esc(title))\">")
        out.append("<g class=\"base\">")
        out += SVGRenderer.elements(base, fonts, scope: "k-")
        out.append("</g>")
        for (index, id) in ids.enumerated() {
            guard let page = states[id] else { continue }
            out.append("<g class=\"layer\" data-state=\"\(SVGRenderer.esc(id))\" "
                       + "data-caption=\"\(SVGRenderer.esc(captions[id] ?? ""))\" aria-hidden=\"true\">")
            out += SVGRenderer.elements(page, fonts, scope: "k\(index)-")
            out.append("</g>")
        }
        out.append("<g class=\"hits\">")
        let shown = regions.filter { live.contains($0.state) && $0.polygon.count > 2 }
        for region in shown.filter({ !$0.current }) + shown.filter(\.current) {
            let points = region.polygon.map { "\(SVGRenderer.f($0.x)),\(SVGRenderer.f($0.y))" }.joined(separator: " ")
            out.append("<polygon class=\"hit\" data-state=\"\(SVGRenderer.esc(region.state))\" "
                       + "data-current=\"\(region.current ? 1 : 0)\" points=\"\(points)\"/>")
        }
        out.append("</g>")
        out.append("</svg>")
        out.append("<p id=\"readout\" role=\"status\" aria-live=\"polite\" data-idle=\"\(SVGRenderer.esc(idle))\">\(SVGRenderer.esc(idle))</p>")
        out.append("</main>")
        out.append("<script>\(Interactive.script)</script>")
        out.append("</body></html>")
        return out.joined(separator: "\n")
    }

    func css(_ family: String) -> String {
        let move = fade > 0 ? ";transition:opacity \(SVGRenderer.f(fade))s" : ""
        var rules = [
            "body{margin:0;padding:1rem;font-family:\"\(family)\",sans-serif}",
            "#view{margin:0 auto}",
            "#sheet{display:block;width:100%;height:auto;max-height:85vh}",
            ".layer{pointer-events:none;opacity:0\(move)}",
            ".layer.on{opacity:1}",
            ".hit{fill:transparent;pointer-events:all;cursor:pointer}",
            ".hit[data-live=\"0\"]{pointer-events:none;cursor:default}",
            "#readout{margin:0.75rem 0 0;min-height:1.5em;font-variant-numeric:tabular-nums}"
        ]
        if fade > 0 { rules.append("@media (prefers-reduced-motion:reduce){.layer{transition:none}}") }
        return rules.joined(separator: "\n")
    }

    static func name(_ family: String) -> String {
        String(family.filter { $0.isLetter || $0.isNumber || " -_.".contains($0) })
    }

    static let script = #"""
    (function () {
      var root = document.getElementById("view");
      var read = document.getElementById("readout");
      var idle = read.getAttribute("data-idle") || "";
      var layers = Array.prototype.slice.call(root.querySelectorAll(".layer"));
      var hits = Array.prototype.slice.call(root.querySelectorAll(".hit"));
      var ids = layers.map(function (layer) { return layer.getAttribute("data-state"); });
      var active = null;
      function show(id) {
        active = id;
        layers.forEach(function (layer) {
          layer.classList.toggle("on", layer.getAttribute("data-state") === id);
        });
        hits.forEach(function (hit) {
          var mine = hit.getAttribute("data-state") === id;
          var current = hit.getAttribute("data-current") === "1";
          hit.setAttribute("data-live", current === mine ? "1" : "0");
        });
        var at = ids.indexOf(id);
        read.textContent = at < 0 ? idle : layers[at].getAttribute("data-caption");
        root.dispatchEvent(new CustomEvent("statechange", { bubbles: true, detail: { state: id } }));
      }
      hits.forEach(function (hit) {
        hit.addEventListener("click", function () {
          var id = hit.getAttribute("data-state");
          show(active === id ? null : id);
        });
      });
      document.addEventListener("keydown", function (event) {
        if (event.key === "Escape") { show(null); return; }
        var step = 0;
        if (event.key === "ArrowRight" || event.key === "ArrowDown") { step = 1; }
        if (event.key === "ArrowLeft" || event.key === "ArrowUp") { step = -1; }
        if (step === 0 || ids.length === 0) { return; }
        event.preventDefault();
        var at = ids.indexOf(active);
        var next = at < 0 ? (step > 0 ? 0 : ids.length - 1) : (at + step + ids.length) % ids.length;
        show(ids[next]);
      });
      show(null);
    })();
    """#
}
