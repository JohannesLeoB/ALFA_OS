public enum RichTextEngine {
    public static func marker(_ kind: ListKind, position: Int) -> String {
        switch kind {
        case .bullet: "\u{2022} "
        case .number: String(position) + ". "
        }
    }

    public static func html(_ paragraphs: [RichParagraph]) -> String? {
        guard paragraphs.contains(where: { $0.list != nil || $0.runs.contains { !$0.plain } }) else { return nil }
        var out = ""
        var open: ListKind?
        for paragraph in paragraphs {
            if paragraph.list != open {
                if let open { out += "</" + tag(open) + ">" }
                if let next = paragraph.list { out += "<" + tag(next) + ">" }
                open = paragraph.list
            }
            let inner = paragraph.runs.map(run).joined()
            if open != nil {
                out += "<li>" + inner + "</li>"
            } else {
                out += "<div>" + (inner.isEmpty ? "<br>" : inner) + "</div>"
            }
        }
        if let open { out += "</" + tag(open) + ">" }
        return out
    }

    private static func tag(_ kind: ListKind) -> String {
        kind == .bullet ? "ul" : "ol"
    }

    private static func run(_ run: RichRun) -> String {
        var text = escape(run.text)
        if run.underline { text = "<u>" + text + "</u>" }
        if run.italic { text = "<i>" + text + "</i>" }
        if run.bold { text = "<b>" + text + "</b>" }
        if let link = run.link { text = "<a href=\"" + escape(link) + "\">" + text + "</a>" }
        return text
    }

    static func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;").replacingOccurrences(of: "\"", with: "&quot;")
    }
}
