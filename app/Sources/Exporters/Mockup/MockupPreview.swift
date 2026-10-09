import Foundation
import Tokens

/// preview.html: each frame drawn at its size, and the items without a frame on a free sheet.
enum MockupPreview {
    static func html(title: String, frames: [MockupManifest.Frame], entries: [MockupManifest.Entry], files: [String: Data]) -> String {
        var out = """
        <!doctype html>
        <html lang="en">
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>\(escape(title))</title>
        <style>
        body{margin:0;padding:48px;background:whitesmoke;color:black;font:13px -apple-system,system-ui,sans-serif}
        h2{font-weight:400;font-size:13px;margin:48px 0 8px}
        .sheet{position:relative;background:white;box-shadow:0 1px 2px gray}
        .item{position:absolute;overflow:hidden;box-sizing:border-box}
        .item iframe{border:0;transform-origin:0 0;background:white}
        .item img{width:100%;height:100%;object-fit:contain}
        .item pre{margin:0;padding:12px;font:12px/1.5 ui-monospace,Menlo,monospace;white-space:pre-wrap;height:100%;box-sizing:border-box;overflow:auto;background:whitesmoke}
        .item .text{margin:0;padding:12px;white-space:pre-wrap;height:100%;box-sizing:border-box}
        .item .shape{width:100%;height:100%;box-sizing:border-box}
        .item .card-head{height:32px;padding:0 12px;line-height:32px;font:12px -apple-system,system-ui,sans-serif;color:gray;white-space:nowrap;overflow:hidden;background:white}
        </style>
        </head>
        <body>
        <p>Draft, not contract. The values on this page are drafts.</p>

        """
        for frame in frames {
            out += section(caption: frame.title, width: frame.width, height: frame.height,
                           items: entries.filter { $0.frame == frame.id }, files: files)
        }
        let free = entries.filter { $0.frame == nil }
        if !free.isEmpty {
            let width = free.map { $0.x + $0.width }.max() ?? 0
            let height = free.map { $0.y + $0.height }.max() ?? 0
            out += section(caption: "Free sheet", width: width, height: height, items: free, files: files)
        }
        return out + "</body>\n</html>\n"
    }

    static func escape(_ text: String) -> String {
        var out = ""
        for character in text {
            switch character {
            case "&": out += "&amp;"
            case "<": out += "&lt;"
            case ">": out += "&gt;"
            case "\"": out += "&quot;"
            case "'": out += "&#39;"
            default: out.append(character)
            }
        }
        return out
    }

    private static func section(caption: String, width: Double, height: Double,
                                items: [MockupManifest.Entry], files: [String: Data]) -> String {
        var out = "<h2>\(escape(caption)) · \(width) x \(height)</h2>\n"
        out += "<div class=\"sheet\" style=\"width:\(width)px;height:\(height)px\">\n"
        // The items come in canvas order (layer, then z), so their place in the list is their stacking order.
        for (index, entry) in items.enumerated() {
            out += "<div class=\"item\" style=\"left:\(entry.x)px;top:\(entry.y)px;width:\(entry.width)px;height:\(entry.height)px;z-index:\(index)\">"
            out += body(of: entry, files: files)
            out += "</div>\n"
        }
        return out + "</div>\n"
    }

    private static func body(of entry: MockupManifest.Entry, files: [String: Data]) -> String {
        switch entry.type {
        case "code":
            let code = entry.file.flatMap { files[$0] }.map { String(decoding: $0, as: UTF8.self) } ?? ""
            guard let mode = entry.mode, mode == "html" || mode == "tailwind" else {
                return pre(entry.title + "\n\n" + code)
            }
            return card(code, entry)
        case "image":
            if let file = entry.file {
                return "<img src=\"\(escape(file))\" alt=\"\(escape(entry.title))\">"
            }
            return pre("Link: \(entry.url ?? "none")\nLicense: \(entry.license ?? "none")")
        case "note", "text":
            return "<p class=\"text\">\(escape(entry.text ?? ""))</p>"
        case "swatch":
            let fill = cssColor(entry.color) ?? "none"
            return "<div style=\"width:100%;height:100%;background:\(fill)\"></div>"
        case "shape":
            let fill = cssColor(entry.fill) ?? "none"
            let border = cssColor(entry.stroke).map { "1px solid \($0)" } ?? "none"
            let radius = entry.mode == "ellipse" ? "50%" : (entry.mode == "capsule" ? "999px" : "0")
            return "<div class=\"shape\" style=\"background:\(fill);border:\(border);border-radius:\(radius)\"></div>"
        case "link":
            let text = escape(entry.text ?? entry.url ?? "")
            if let url = entry.url, url.lowercased().hasPrefix("https://") || url.lowercased().hasPrefix("http://") {
                return "<a class=\"text\" href=\"\(escape(url))\">\(text)</a>"
            }
            return "<p class=\"text\">\(text)</p>"
        default:
            return pre(entry.title)
        }
    }

    /// Height of the header band of a code card on the canvas, in points. The page starts below it.
    static let cardHeader = 32.0

    /// A card with a page of HTML, drawn at its design width and scaled to the item, below the header band.
    private static func card(_ code: String, _ entry: MockupManifest.Entry) -> String {
        let design = entry.previewWidth.flatMap { $0 > 0 ? $0 : nil } ?? entry.width
        let scale = entry.width > 0 && design > 0 ? entry.width / design : 1
        let height = (max(0, entry.height - cardHeader) / scale).rounded(.up)
        return "<div class=\"card-head\" style=\"height:\(cardHeader)px\">\(escape(entry.title))</div>"
            + "<iframe sandbox=\"allow-scripts\" srcdoc=\"\(escape(code))\" "
            + "style=\"position:absolute;left:0;top:\(cardHeader)px;width:\(design)px;height:\(height)px;transform:scale(\(scale))\"></iframe>"
    }

    private static func pre(_ text: String) -> String {
        "<pre>\(escape(text))</pre>"
    }

    /// A colour as CSS, only when it is a valid hex colour. Otherwise nil.
    private static func cssColor(_ hex: String?) -> String? {
        guard let hex, let rgb = RGB(hex: hex) else { return nil }
        return rgb.hex
    }
}
