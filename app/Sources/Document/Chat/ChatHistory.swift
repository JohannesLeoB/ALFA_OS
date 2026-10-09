import Foundation

/// Where the chat of a document is kept: in the package, or only on this Mac.
public enum ChatStorage: String, Sendable, Equatable {
    case document
    case local
}

/// The lines of the chat of one document. One line is one JSON object, kept byte for byte as the caller wrote it,
/// so that fields that this version does not know come back unchanged.
/// The limits: at most `maxMessages` lines and `maxBytes` bytes with line breaks. The oldest lines go first.
public struct ChatHistory: Equatable, Sendable {
    /// The most messages that one chat keeps.
    public static let maxMessages = 200
    /// The most bytes that one chat keeps, with the line breaks.
    public static let maxBytes = 1_000_000

    /// The lines, oldest first.
    public private(set) var lines: [Data]
    /// Lines that were not JSON objects. They were dropped when the history was read or appended.
    public private(set) var skipped: Int

    public init(lines: [Data] = []) {
        let valid = lines.filter(Self.isObjectLine)
        self.lines = Self.limited(valid)
        self.skipped = lines.count - valid.count
    }

    /// Adds a line at the end. A line that is not a JSON object is counted as skipped.
    public mutating func append(_ line: Data) {
        guard Self.isObjectLine(line) else {
            skipped += 1
            return
        }
        lines = Self.limited(lines + [line])
    }

    /// The bytes of the file: each line followed by a line break. Empty when there are no lines.
    public func encoded() -> Data {
        var data = Data()
        for line in lines {
            data.append(line)
            data.append(Self.lineBreak)
        }
        return data
    }

    /// Reads the bytes of the file. Empty lines are ignored, broken lines are dropped and counted, and the limits apply.
    public static func decode(_ data: Data) -> ChatHistory {
        var valid: [Data] = []
        var skipped = 0
        for part in data.split(separator: lineBreak, omittingEmptySubsequences: true) {
            let line = Data(part)
            if isObjectLine(line) {
                valid.append(line)
            } else {
                skipped += 1
            }
        }
        var history = ChatHistory(lines: valid)
        history.skipped += skipped
        return history
    }

    private static let lineBreak: UInt8 = 0x0A

    /// A line is one JSON object on one line of text.
    static func isObjectLine(_ line: Data) -> Bool {
        guard !line.isEmpty, !line.contains(lineBreak) else { return false }
        return (try? JSONSerialization.jsonObject(with: line)) is [String: Any]
    }

    /// The newest lines that fit both limits, in their order.
    static func limited(_ lines: [Data]) -> [Data] {
        var kept: [Data] = []
        var bytes = 0
        for line in lines.reversed() {
            let size = line.count + 1
            guard kept.count < maxMessages, bytes + size <= maxBytes else { break }
            kept.append(line)
            bytes += size
        }
        return Array(kept.reversed())
    }
}
