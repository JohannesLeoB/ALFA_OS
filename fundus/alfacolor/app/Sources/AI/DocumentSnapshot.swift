import Foundation

/// The IDs that the tools may refer to: the pieces of the whole document and the tokens of the design set.
/// The app builds it from the document; the tools check every ID against it.
public struct DocumentSnapshot: Sendable, Equatable {
    public var pieceIDs: Set<String>
    public var tokenIDs: Set<String>

    public init(pieceIDs: Set<String>, tokenIDs: Set<String>) {
        self.pieceIDs = pieceIDs
        self.tokenIDs = tokenIDs
    }

    public init(pieces: [ContextPiece], tokenIDs: Set<String>) {
        self.init(pieceIDs: Set(pieces.map(\.id)), tokenIDs: tokenIDs)
    }
}

/// The design texts that `design_read` may return, such as the canon and the contract. The app provides them.
public protocol DesignSource: Sendable {
    /// The names that can be read, in a fixed order.
    var names: [String] { get }
    /// The text of one name, or nil when the name is not known.
    func text(of name: String) -> String?
}
