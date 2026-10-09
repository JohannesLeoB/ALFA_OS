import Foundation

/// Builds the request of one message: the text, the attachments, and the directory of the document.
/// Nothing is filtered here. The user decides what goes in; the builder only checks the limits of the API.
public enum ContextBuilder {
    /// The largest request that the API takes, in bytes of text and base64 images.
    public static let maxRequestBytes = 32 * 1024 * 1024
    /// The longest answer that one request asks for.
    public static let maxTokens = 4096

    /// The instruction of the assistant. It is the first part of the system text, which stays the same between messages.
    static let baseInstruction = """
        You help a designer in a design app. The user writes a message and may attach pieces of the \
        document, texts and pictures. Change nothing yourself: propose changes with the tools, and the \
        user accepts them. Answer briefly.
        """

    /// The request for one message. The history comes before the new message, unchanged.
    public static func request(
        for input: ContextInput,
        model: String,
        tools: [AITool],
        history: [AIMessage]
    ) throws -> AIRequest {
        let request = AIRequest(
            model: model,
            system: systemText(directory: input.directory),
            messages: history + [try message(for: input)],
            maxTokens: maxTokens,
            tools: tools
        )
        try checkSize(request)
        return request
    }

    /// The user message: the text first, then each attachment in the order the user attached it.
    public static func message(for input: ContextInput) throws -> AIMessage {
        var blocks: [AIBlock] = []
        if !input.text.isEmpty {
            blocks.append(.text(input.text))
        }
        for attachment in input.attachments {
            switch attachment {
            case let .selection(pieces):
                guard !pieces.isEmpty else { continue }
                blocks.append(.text(selectionText(pieces)))
            case let .text(label, body):
                blocks.append(.text("\(label):\n\(body)"))
            case let .image(label, image):
                try AIImageRules.check(image)
                blocks.append(.text("Picture: \(label)"))
                blocks.append(.image(image))
            }
        }
        return AIMessage(role: .user, blocks: blocks)
    }

    /// The system text: the instruction, then the directory of the document when it is attached.
    /// The pieces are sorted by ID, so the same document gives the same text and the cache keeps it.
    static func systemText(directory: [ContextPiece]?) -> String {
        guard let directory else { return baseInstruction }
        if directory.isEmpty {
            return baseInstruction + "\n\nDocument pieces: none."
        }
        let lines = directory.sorted { $0.id < $1.id }.map(describe)
        return baseInstruction + "\n\nDocument pieces (all rooms, sorted by id):\n" + lines.joined(separator: "\n")
    }

    static func selectionText(_ pieces: [ContextPiece]) -> String {
        "Selected pieces (\(pieces.count)):\n" + pieces.map(describe).joined(separator: "\n")
    }

    /// One line per piece: id, kind, room, title, tags and notes.
    static func describe(_ piece: ContextPiece) -> String {
        var line = "- \(piece.id) | \(piece.kind) | room: \(piece.room) | title: \(piece.title)"
        if !piece.tags.isEmpty {
            line += " | tags: " + piece.tags.joined(separator: ", ")
        }
        if !piece.notes.isEmpty {
            line += " | notes: " + piece.notes.joined(separator: "; ")
        }
        return line
    }

    /// Throws when the text and the images of the request are larger than the API takes.
    static func checkSize(_ request: AIRequest) throws {
        var bytes = request.system.utf8.count
        for message in request.messages {
            for block in message.blocks {
                switch block {
                case let .text(text):
                    bytes += text.utf8.count
                case let .image(image):
                    bytes += AIImageRules.base64Length(of: image.data.count)
                default:
                    continue
                }
            }
        }
        guard bytes <= maxRequestBytes else {
            throw AIError.contextTooLarge(bytes: bytes)
        }
    }
}
