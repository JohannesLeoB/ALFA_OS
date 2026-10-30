import Foundation

extension HTMLEngine {
    private enum Trigger {
        case container
        case tail
        case conditional
    }

    private static let containerClasses = ["gmail_quote", "yahoo_quoted", "protonmail_quote"]
    private static let tailIDs: Set<String> = ["divrplyfwdmsg", "appendonsend", "olk_src_body_section"]
    private static let forwardMarks = ["forwarded message", "weitergeleitete nachricht"]
    private static let attributionWindow = 40
    private static let attributionLength = 300

    static func parts(_ html: String) -> HTMLParts {
        let tokens = HTMLTokenizer.tokens(html)
        guard let fold = fold(tokens) else {
            return HTMLParts(body: html, blockedBody: blocked(tokens), quote: nil, remote: hasRemote(tokens))
        }
        let body = Array(tokens[..<fold.cut])
        let lines = fold.text.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.count
        return HTMLParts(body: body.map(\.raw).joined(), blockedBody: blocked(body), quote: Quote(text: fold.text, lines: lines),
                         remote: hasRemote(tokens))
    }

    private static func fold(_ tokens: [HTMLToken]) -> (cut: Int, text: String)? {
        for (index, token) in tokens.enumerated() where token.kind == .start {
            guard let trigger = trigger(token) else { continue }
            let end = trigger == .tail ? tokens.count : endIndex(tokens, at: index)
            let inner = HTMLPlainWriter.render(Array(tokens[index..<end]))
            if trigger == .container, isForward(inner) { continue }
            var cut = index
            var head = ""
            if !Quoting.isAttribution(inner.components(separatedBy: "\n").first ?? ""),
               let found = attribution(tokens, before: index) {
                cut = found.start
                head = found.text + "\n"
            } else if trigger == .conditional {
                continue
            }
            if hasContent(Array(tokens[end...])) { return nil }
            guard !(head + inner).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
            return (rule(tokens, before: cut), (head + inner).trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return nil
    }

    private static func trigger(_ token: HTMLToken) -> Trigger? {
        let classes = token.attributes["class"]?.lowercased() ?? ""
        if tailIDs.contains(token.attributes["id"]?.lowercased() ?? "") { return .tail }
        if containerClasses.contains(where: classes.contains) { return .container }
        guard token.name == "blockquote" else { return nil }
        return token.attributes["type"]?.lowercased() == "cite" ? .container : .conditional
    }

    private static func isForward(_ text: String) -> Bool {
        let head = text.prefix(80).lowercased()
        return head.hasPrefix("---") && forwardMarks.contains(where: head.contains)
    }

    private static func endIndex(_ tokens: [HTMLToken], at start: Int) -> Int {
        let name = tokens[start].name
        guard !tokens[start].isVoid else { return start + 1 }
        var depth = 0
        for index in start..<tokens.count where tokens[index].name == name {
            if tokens[index].kind == .start, !tokens[index].isVoid { depth += 1 }
            if tokens[index].kind == .end { depth -= 1 }
            if depth == 0 { return index + 1 }
        }
        return tokens.count
    }

    private static func attribution(_ tokens: [HTMLToken], before cut: Int) -> (start: Int, text: String)? {
        var index = cut - 1
        let floor = max(0, cut - attributionWindow)
        while index >= floor {
            let text = Quoting.flat(HTMLPlainWriter.render(Array(tokens[index..<cut])))
            if text.count > attributionLength { return nil }
            if Quoting.isAttribution(text) { return (index, text) }
            index -= 1
        }
        return nil
    }

    private static func rule(_ tokens: [HTMLToken], before cut: Int) -> Int {
        var index = cut - 1
        while index >= 0, tokens[index].kind == .text, tokens[index].raw.allSatisfy(\.isWhitespace) { index -= 1 }
        guard index >= 0, tokens[index].kind == .start, tokens[index].name == "hr" else { return cut }
        return index
    }

    private static func hasContent(_ tokens: [HTMLToken]) -> Bool {
        tokens.contains { $0.kind == .start && $0.name == "img" } || !HTMLPlainWriter.render(tokens).isEmpty
    }
}
