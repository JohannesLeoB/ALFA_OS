import Foundation

/// Reads the HTML bookmark file of Safari, Firefox and Edge. The format is not XML, so the file is read by hand:
/// tags are found by their angle brackets, and open tags and missing closing tags are tolerated.
struct NetscapeReader {
    private struct Frame {
        var folder: BookmarkFolder
        /// True for a list that belongs to a named folder. An unnamed list hands its contents to the folder above.
        var named: Bool
        /// The number of named folders from the top down to this list.
        var depth: Int
        /// True inside a folder cut at the depth limit. Its contents are read past and left out.
        var dropped: Bool
    }

    private enum Capture {
        case folderName
        case link(url: String?, added: String?)
    }

    private var stack: [Frame] = [Frame(folder: BookmarkFolder(name: ""), named: false, depth: 0, dropped: false)]
    private var pendingName: String?
    private var capture: Capture?
    private var captured = ""
    private var budget = BookmarkBudget()

    static func read(_ html: String) -> BookmarkTree {
        var reader = NetscapeReader()
        reader.scan(Array(html.utf8))
        reader.finishCapture()
        while reader.stack.count > 1 {
            reader.closeList()
        }
        return BookmarkTree(root: reader.stack[0].folder, skipped: reader.budget.skipped, truncated: reader.budget.truncated)
    }

    // MARK: - Scanning

    private mutating func scan(_ bytes: [UInt8]) {
        var i = 0
        var textStart = 0
        while i < bytes.count {
            guard bytes[i] == UInt8(ascii: "<"), i + 1 < bytes.count, Self.startsTag(bytes[i + 1]) else {
                i += 1
                continue
            }
            if Self.matches(bytes, at: i, "<!--") {
                addText(bytes, textStart, i)
                let end = Self.find(bytes, "-->", from: i + 4) ?? bytes.count
                i = min(end + 3, bytes.count)
                textStart = i
                continue
            }
            guard let close = bytes[(i + 1)...].firstIndex(of: UInt8(ascii: ">")) else {
                break
            }
            addText(bytes, textStart, i)
            handleTag(bytes[(i + 1)..<close])
            i = close + 1
            textStart = i
        }
        addText(bytes, textStart, bytes.count)
    }

    private mutating func addText(_ bytes: [UInt8], _ start: Int, _ end: Int) {
        guard capture != nil, start < end else { return }
        captured += BookmarkText.decodingEntities(String(decoding: bytes[start..<end], as: UTF8.self))
    }

    private mutating func handleTag(_ content: ArraySlice<UInt8>) {
        guard let first = content.first, first != UInt8(ascii: "!"), first != UInt8(ascii: "?") else { return }
        let isClosing = first == UInt8(ascii: "/")
        let body = isClosing ? content.dropFirst() : content
        let nameBytes = body.prefix { Self.isNameByte($0) }
        let name = String(decoding: nameBytes, as: UTF8.self).lowercased()
        let attributes = isClosing ? [:] : Self.attributes(body.dropFirst(nameBytes.count))

        switch name {
        case "h3":
            if isClosing {
                if case .folderName? = capture { finishCapture() }
            } else {
                finishCapture()
                capture = .folderName
                captured = ""
            }
        case "a":
            if isClosing {
                if case .link? = capture { finishCapture() }
            } else {
                finishCapture()
                capture = .link(url: attributes["href"], added: attributes["add_date"])
                captured = ""
            }
        case "dt", "dl":
            finishCapture()
            if name == "dl" {
                if isClosing { closeList() } else { openList() }
            }
        default:
            break
        }
    }

    // MARK: - Folders and links

    private mutating func openList() {
        let name = pendingName
        pendingName = nil
        let parentDepth = stack[stack.count - 1].depth
        let parentDropped = stack[stack.count - 1].dropped
        if name != nil, parentDropped || parentDepth + 1 > BookmarkLimit.maxDepth {
            if !parentDropped { budget.truncated = true }
            stack.append(Frame(folder: BookmarkFolder(name: ""), named: name != nil, depth: parentDepth, dropped: true))
            return
        }
        let depth = name == nil ? parentDepth : parentDepth + 1
        stack.append(Frame(folder: BookmarkFolder(name: name ?? ""), named: name != nil, depth: depth, dropped: parentDropped))
    }

    private mutating func closeList() {
        guard stack.count > 1 else { return }
        let frame = stack.removeLast()
        guard !frame.dropped else { return }
        let last = stack.count - 1
        if frame.named {
            stack[last].folder.folders.append(frame.folder)
        } else {
            stack[last].folder.folders += frame.folder.folders
            stack[last].folder.links += frame.folder.links
        }
    }

    /// Ends the text that is being read, if any: a folder name becomes the pending name, a link becomes a link.
    private mutating func finishCapture() {
        guard let current = capture else { return }
        let text = captured
        capture = nil
        captured = ""
        switch current {
        case .folderName:
            pendingName = BookmarkText.clip(text)
        case .link(let href, let added):
            guard !stack[stack.count - 1].dropped else { return }
            guard let href, let url = BookmarkText.webURL(href) else {
                budget.skipped += 1
                return
            }
            guard budget.links < BookmarkLimit.maxLinks else {
                budget.truncated = true
                return
            }
            budget.links += 1
            let link = BookmarkLink(title: BookmarkText.linkTitle(text, url: url), url: url,
                                    added: BookmarkText.date(unixSeconds: added))
            stack[stack.count - 1].folder.links.append(link)
        }
    }

    // MARK: - Bytes

    private static func startsTag(_ byte: UInt8) -> Bool {
        isNameByte(byte) || byte == UInt8(ascii: "/") || byte == UInt8(ascii: "!") || byte == UInt8(ascii: "?")
    }

    private static func isNameByte(_ byte: UInt8) -> Bool {
        (byte >= 65 && byte <= 90) || (byte >= 97 && byte <= 122) || (byte >= 48 && byte <= 57)
    }

    private static func isSpace(_ byte: UInt8) -> Bool {
        byte == 32 || byte == 9 || byte == 10 || byte == 13
    }

    private static func matches(_ bytes: [UInt8], at index: Int, _ text: String) -> Bool {
        let pattern = Array(text.utf8)
        guard index + pattern.count <= bytes.count else { return false }
        return Array(bytes[index..<(index + pattern.count)]) == pattern
    }

    private static func find(_ bytes: [UInt8], _ text: String, from start: Int) -> Int? {
        let pattern = Array(text.utf8)
        var i = start
        while i + pattern.count <= bytes.count {
            if matches(bytes, at: i, text) { return i }
            i += 1
        }
        return nil
    }

    /// The attributes of a tag, with names in lower case and the first value of each name. Values are decoded.
    private static func attributes(_ bytes: ArraySlice<UInt8>) -> [String: String] {
        var result: [String: String] = [:]
        var i = bytes.startIndex
        let end = bytes.endIndex
        while i < end {
            while i < end, isSpace(bytes[i]) || bytes[i] == UInt8(ascii: "/") { i += 1 }
            let keyStart = i
            while i < end, !isSpace(bytes[i]), bytes[i] != UInt8(ascii: "=") { i += 1 }
            let key = String(decoding: bytes[keyStart..<i], as: UTF8.self).lowercased()
            while i < end, isSpace(bytes[i]) { i += 1 }
            var value = ""
            if i < end, bytes[i] == UInt8(ascii: "=") {
                i += 1
                while i < end, isSpace(bytes[i]) { i += 1 }
                if i < end, bytes[i] == UInt8(ascii: "\"") || bytes[i] == UInt8(ascii: "'") {
                    let quote = bytes[i]
                    i += 1
                    let valueStart = i
                    while i < end, bytes[i] != quote { i += 1 }
                    value = String(decoding: bytes[valueStart..<i], as: UTF8.self)
                    if i < end { i += 1 }
                } else {
                    let valueStart = i
                    while i < end, !isSpace(bytes[i]) { i += 1 }
                    value = String(decoding: bytes[valueStart..<i], as: UTF8.self)
                }
            }
            if !key.isEmpty, result[key] == nil {
                result[key] = BookmarkText.decodingEntities(value)
            }
        }
        return result
    }
}
