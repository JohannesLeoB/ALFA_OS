import Foundation

enum MemoryEngine {
    static let windowDays = 28
    static let maxMessages = 120
    static let tailSize = 8
    static let minBatch = 12

    enum Plan: Equatable {
        case passthrough
        case reuse(tail: [Message], summary: String)
        case distill(tail: [Message], batch: [Message], existing: String?, coveredThrough: String)
    }

    static func window(_ messages: [Message], now: Date) -> [Message] {
        let cutoff = now.addingTimeInterval(-Double(windowDays) * 24 * 3600)
        var windowed = messages.filter { $0.createdAt >= cutoff }
        if windowed.count > maxMessages { windowed = Array(windowed.suffix(maxMessages)) }
        return trimToUserStart(windowed)
    }

    static func trimToUserStart(_ messages: [Message]) -> [Message] {
        var trimmed = messages
        while let first = trimmed.first, first.role != .user { trimmed.removeFirst() }
        return trimmed
    }

    static func plan(windowed: [Message], existing: MemorySummary?) -> Plan {
        guard windowed.count > tailSize else { return .passthrough }
        let tailStart = windowed.count - tailSize
        let coveredIndex = existing.flatMap { summary in
            windowed.firstIndex { $0.id.uuidString == summary.coveredThroughMessageID }
        } ?? -1
        let batch = coveredIndex + 1 < tailStart ? Array(windowed[(coveredIndex + 1)..<tailStart]) : []
        let tail = trimToUserStart(Array(windowed[tailStart...]))
        if batch.count >= minBatch, let last = batch.last {
            return .distill(tail: tail, batch: batch, existing: existing?.summaryText, coveredThrough: last.id.uuidString)
        }
        if let existing { return .reuse(tail: tail, summary: existing.summaryText) }
        return .passthrough
    }

    static func transcript(_ batch: [Message], text: any TextPort) -> String {
        batch.map { message in
            let role = text.text(message.role == .user ? "assistant.memory.roleUser" : "assistant.memory.roleAssistant", [])
            return "\(role): \(message.text)"
        }.joined(separator: "\n")
    }
}
