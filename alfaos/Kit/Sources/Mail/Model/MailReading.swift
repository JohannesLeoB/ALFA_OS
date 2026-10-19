import Foundation
import struct AlfaServices.MailAttachmentInfo
import struct AlfaServices.MailMessageSummary

public enum MailThreadDate: Equatable, Sendable {
    case today(Date)
    case dated(Date, withYear: Bool)

    public static func of(_ date: Date?, now: Date, calendar: Calendar = .current) -> MailThreadDate? {
        guard let date else { return nil }
        if calendar.isDate(date, inSameDayAs: now) { return .today(date) }
        return .dated(date, withYear: calendar.component(.year, from: date) != calendar.component(.year, from: now))
    }
}

public struct MailQuote: Equatable, Sendable {
    public let text: String
    public let lines: Int
}

public struct MailThreadItem: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let address: String
    public let date: MailThreadDate?
    public let text: String
    public let quote: MailQuote?
    public let quoteOpen: Bool
    public let current: Bool
}

public struct MailAttachmentRow: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let size: String
}

public struct MailRecipientList: Equatable, Sendable {
    public let to: [MailPerson]
    public let cc: [MailPerson]

    public var all: [MailPerson] { to + cc }

    public var summary: String { MailRecipients.summary(all) }

    public var more: Int? { all.count > MailSheet.recipientsInline ? all.count - 1 : nil }

    public func group(at index: Int) -> MailRecipientGroup {
        if index == 0 { return .to }
        return index == to.count && !cc.isEmpty ? .cc : .none
    }
}

public enum MailRecipientGroup: Equatable, Sendable {
    case to
    case cc
    case none
}

public enum MailSize {
    public static func label(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.zeroPadsFractionDigits = false
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

public enum MailQuoting {
    public static func split(_ text: String) -> (body: String, quote: MailQuote?) {
        let lines = text.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n")
        guard let first = lines.firstIndex(where: { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            return trimmed.hasPrefix(">") || trimmed.hasPrefix("›")
        }) else { return (text, nil) }
        var start = first
        var look = first - 1
        while look >= 0, lines[look].trimmingCharacters(in: .whitespaces).isEmpty { look -= 1 }
        if look >= 0 {
            let head = lines[look].trimmingCharacters(in: .whitespaces)
            let lower = head.lowercased()
            if head.hasSuffix(":"), lower.contains("schrieb") || lower.contains("wrote") { start = look }
        }
        let body = lines[..<start].joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        let quote = lines[start...].joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        return (body, MailQuote(text: quote, lines: lines[start...].filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.count))
    }
}

extension ReadingCard {
    public var plainText: String? {
        switch content {
        case .text(let text): text
        case .html(let html, _): MailText.plain(html)
        case .bodyLoading, .conversation, .draftNotice: nil
        }
    }

    public var recipients: MailRecipientList {
        MailRecipientList(to: MailRecipients.parse(summary.toRaw), cc: MailRecipients.parse(summary.ccRaw))
    }

    public var attachmentRows: [MailAttachmentRow] {
        attachments.map { MailAttachmentRow(id: $0.id, name: $0.filename, size: MailSize.label($0.sizeBytes)) }
    }

    public var hasConversation: Bool { conversation.count > 1 }
}

extension MailModel {
    public func thread(_ id: String) -> [MailThreadItem] {
        guard let card = card(id) else { return [] }
        let source = card.conversation.isEmpty ? [card.summary] : card.conversation.sorted {
            ($0.receivedAt ?? .distantPast) < ($1.receivedAt ?? .distantPast)
        }
        let now = clock()
        return source.map { item in
            let current = item.id == id
            let raw = current ? (card.plainText ?? item.snippet) : (card.threadTexts[item.id] ?? item.snippet)
            let parts = MailQuoting.split(raw)
            let party = Self.sender(item)
            return MailThreadItem(id: item.id, name: party.name.isEmpty ? party.address : party.name, address: party.address,
                                  date: MailThreadDate.of(item.receivedAt, now: now), text: parts.body, quote: parts.quote,
                                  quoteOpen: card.quotesOpen.contains(item.id), current: current)
        }
    }

    public func toggleQuote(_ id: String, message: String) {
        update(id) { card in
            if card.quotesOpen.contains(message) { card.quotesOpen.remove(message) } else { card.quotesOpen.insert(message) }
        }
    }

    public func loadThreadTexts(_ id: String) async {
        await loadThread(id)
        guard let card = card(id) else { return }
        for item in card.conversation.suffix(MailSheet.threadBodyLimit) where item.id != id {
            guard let inlet = cardInlet(id) ?? selectedInlet,
                  let body = try? await engine.body(inlet, messageID: item.id) else { continue }
            let text = body.text ?? body.html.map(MailAddresses.plainText) ?? item.snippet
            update(id) { $0.threadTexts[item.id] = text }
        }
    }
}
