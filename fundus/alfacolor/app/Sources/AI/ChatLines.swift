import Foundation

/// The lines of a saved chat: one JSON object per message, with its role and its blocks as the API wrote them.
/// A picture is not saved; its place keeps a short text, so that the file stays within its limit.
public enum ChatLines {
    /// The text that takes the place of a picture in a saved chat.
    public static let pictureNote = "[picture not kept in the saved chat]"

    /// The line of one message: one line of text without a line break. Nil when a block cannot be written.
    public static func line(for message: AIMessage) -> Data? {
        var blocks: [JSONValue] = []
        for block in message.blocks {
            let kept: AIBlock
            switch block {
            case .image:
                kept = .text(pictureNote)
            default:
                kept = block
            }
            guard let wire = try? AnthropicWire.wireValue(for: kept) else { return nil }
            blocks.append(wire)
        }
        let object: JSONValue = .object([
            "role": .string(message.role.rawValue),
            "blocks": .array(blocks),
        ])
        return try? JSONEncoder().encode(object)
    }

    /// The message of one line. Nil when the line is not a message.
    public static func message(from line: Data) -> AIMessage? {
        guard let value = try? JSONDecoder().decode(JSONValue.self, from: line) else { return nil }
        let roleText = value["role"]?.string
        guard let roleText, let role = AIMessage.Role(rawValue: roleText),
              case let .array(items)? = value["blocks"] else {
            return nil
        }
        return AIMessage(role: role, blocks: items.map { AIBlock(wire: $0) })
    }

    /// The lines of all messages. A message that cannot be written is left out.
    public static func lines(for messages: [AIMessage]) -> [Data] {
        messages.compactMap { line(for: $0) }
    }

    /// The messages of the lines, in order. A line that is not a message is left out.
    public static func messages(from lines: [Data]) -> [AIMessage] {
        lines.compactMap { message(from: $0) }
    }
}
