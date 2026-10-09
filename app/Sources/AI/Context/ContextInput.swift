import Foundation

/// One piece of the document as the assistant sees it. Only these fields go out; nothing else of a piece is read.
public struct ContextPiece: Sendable, Equatable {
    public var id: String
    public var title: String
    /// The kind of the piece, for example code, note, image or swatch.
    public var kind: String
    /// The name of the room that holds the piece.
    public var room: String
    public var tags: [String]
    /// The texts of the notes on the piece, in order.
    public var notes: [String]

    public init(id: String, title: String, kind: String, room: String, tags: [String] = [], notes: [String] = []) {
        self.id = id
        self.title = title
        self.kind = kind
        self.room = room
        self.tags = tags
        self.notes = notes
    }
}

/// Something the user attaches to a message. It goes out with the message; the view shows it as a chip.
public enum ContextAttachment: Sendable, Equatable {
    /// The pieces the user marked with the mouse (frame, lasso or click).
    case selection([ContextPiece])
    /// A text with its label, such as a token set or the name of a room.
    case text(label: String, body: String)
    /// A picture with its label.
    case image(label: String, AIImage)
}

/// One message as the user writes it: the text, what is attached, and the directory of the whole document when it is attached.
public struct ContextInput: Sendable, Equatable {
    public var text: String
    public var attachments: [ContextAttachment]
    /// All pieces of the document, in every room. Nil sends no directory.
    public var directory: [ContextPiece]?

    public init(text: String, attachments: [ContextAttachment] = [], directory: [ContextPiece]? = nil) {
        self.text = text
        self.attachments = attachments
        self.directory = directory
    }
}
