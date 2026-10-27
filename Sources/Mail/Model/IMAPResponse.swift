import Foundation

indirect enum IMAPValue: Equatable, Sendable {
    case null
    case atom(String)
    case number(Int)
    case bytes(Data)
    case list([IMAPValue])

    var string: String? {
        switch self {
        case .atom(let text): text
        case .number(let number): String(number)
        case .bytes(let data): MIME.string(from: data, charset: nil)
        case .null, .list: nil
        }
    }

    var data: Data? {
        switch self {
        case .bytes(let data): data
        case .atom(let text): Data(text.utf8)
        case .number(let number): Data(String(number).utf8)
        case .null, .list: nil
        }
    }

    var int: Int? {
        switch self {
        case .number(let number): number
        case .atom(let text): Int(text)
        default: nil
        }
    }

    var items: [IMAPValue]? {
        if case .list(let items) = self { return items }
        return nil
    }
}

enum IMAPStatus: String, Sendable {
    case ok = "OK"
    case no = "NO"
    case bad = "BAD"
    case preauth = "PREAUTH"
    case bye = "BYE"
}

struct IMAPResponseCode: Equatable, Sendable {
    var name: String
    var values: [IMAPValue]
}

enum IMAPResponse: Equatable, Sendable {
    case tagged(tag: String, status: IMAPStatus, code: IMAPResponseCode?, text: String)
    case status(IMAPStatus, code: IMAPResponseCode?, text: String)
    case data([IMAPValue])
    case continuation(String)
}

struct IMAPListEntry: Equatable, Sendable {
    var attributes: Set<String>
    var delimiter: String?
    var path: String

    static func parse(_ values: [IMAPValue]) -> IMAPListEntry? {
        guard values.count >= 4, values[0].string?.uppercased() == "LIST",
              let attributes = values[1].items, let path = values[3].string else { return nil }
        return IMAPListEntry(
            attributes: Set(attributes.compactMap { $0.string?.lowercased() }),
            delimiter: values[2].string,
            path: IMAPFolderNameCodec.decode(path))
    }

    var isSelectable: Bool {
        !attributes.contains("\\noselect") && !attributes.contains("\\nonexistent")
    }

    var displayName: String {
        guard let delimiter, !delimiter.isEmpty,
              let last = path.components(separatedBy: delimiter).last, !last.isEmpty else { return path }
        return last
    }

    var role: FolderRole {
        if path.uppercased() == "INBOX" { return .inbox }
        if attributes.contains("\\sent") { return .sent }
        if attributes.contains("\\drafts") { return .drafts }
        if attributes.contains("\\trash") { return .trash }
        if attributes.contains("\\junk") { return .spam }
        if attributes.contains("\\archive") { return .archive }
        switch displayName.lowercased().filter({ !$0.isWhitespace }) {
        case "sent", "sentitems", "sentmessages", "sentmail", "gesendet", "gesendeteelemente", "gesendeteobjekte":
            return .sent
        case "drafts", "draft", "entw\u{FC}rfe", "entwurf":
            return .drafts
        case "trash", "deleteditems", "deletedmessages", "papierkorb", "gel\u{F6}scht", "gel\u{F6}schteelemente",
             "gel\u{F6}schteobjekte":
            return .trash
        case "spam", "junk", "junke-mail", "junk-e-mail", "bulkmail":
            return .spam
        case "archive", "archives", "archiv":
            return .archive
        default:
            return .other
        }
    }
}
