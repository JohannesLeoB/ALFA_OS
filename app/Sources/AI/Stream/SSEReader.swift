import Foundation

/// One server-sent event: its name, when the stream gives one, and its data.
struct SSEFrame: Sendable, Equatable {
    let event: String?
    let data: String
}

/// Turns the lines of a server-sent event stream into frames. A blank line ends a frame. A new `event:` line
/// ends the frame before it, even without the blank line. Comment lines and other fields are ignored.
struct SSEReader {
    private var event: String?
    private var data: [String] = []
    private var open = false

    /// Feeds one line and returns the frames that it ends.
    mutating func feed(_ line: String) -> [SSEFrame] {
        if line.isEmpty {
            return flush()
        }
        if line.hasPrefix(":") {
            return []
        }
        if line.hasPrefix("event:") {
            let ended = flush()
            event = Self.value(of: line, after: "event:")
            open = true
            return ended
        }
        if line.hasPrefix("data:") {
            data.append(Self.value(of: line, after: "data:"))
            open = true
        }
        return []
    }

    /// Ends the stream and returns the frame that is still open, if any.
    mutating func finish() -> [SSEFrame] {
        flush()
    }

    private mutating func flush() -> [SSEFrame] {
        guard open else { return [] }
        let frame = SSEFrame(event: event, data: data.joined(separator: "\n"))
        event = nil
        data = []
        open = false
        return [frame]
    }

    /// The text after the field name, without one leading space.
    private static func value(of line: String, after prefix: String) -> String {
        var text = line.dropFirst(prefix.count)
        if text.first == " " {
            text = text.dropFirst()
        }
        return String(text)
    }
}
