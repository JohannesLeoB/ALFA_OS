import Foundation

/// The port for the chat of a document that is kept on this Mac, not in the package.
public protocol LocalChatStore: Sendable {
    func data(for documentID: UUID) -> Data?
    func setData(_ data: Data?, for documentID: UUID)
}

/// The chat on this Mac, in the defaults of the app, under `assistant.chat.<documentID>`.
/// `UserDefaults` is thread-safe by its documentation; the store holds no other state.
public struct UserDefaultsChatStore: LocalChatStore, @unchecked Sendable {
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func data(for documentID: UUID) -> Data? {
        defaults.data(forKey: Self.key(for: documentID))
    }

    public func setData(_ data: Data?, for documentID: UUID) {
        if let data {
            defaults.set(data, forKey: Self.key(for: documentID))
        } else {
            defaults.removeObject(forKey: Self.key(for: documentID))
        }
    }

    static func key(for documentID: UUID) -> String {
        "assistant.chat.\(documentID.uuidString)"
    }
}

/// Loads and saves the chat of a document where the document says it is kept.
/// In the package the chat is the file `chat/main.jsonl`; a chat without lines writes no file.
public enum ChatHistoryStore {
    /// The name of the one chat of a document.
    public static let conversationName = "main"
    static let packagePath = "chat/\(conversationName).jsonl"

    public static func load(_ document: ALFAcolorDocument, local: any LocalChatStore) -> ChatHistory {
        let data: Data?
        switch document.chatStorage {
        case .document:
            data = document.carriedFiles[packagePath]
        case .local:
            data = local.data(for: document.board.documentID)
        }
        guard let data else { return ChatHistory() }
        return ChatHistory.decode(data)
    }

    public static func save(_ history: ChatHistory, in document: inout ALFAcolorDocument, local: any LocalChatStore) {
        let data: Data? = history.lines.isEmpty ? nil : history.encoded()
        switch document.chatStorage {
        case .document:
            document.carriedFiles[packagePath] = data
        case .local:
            local.setData(data, for: document.board.documentID)
        }
    }

    /// Changes where the chat is kept. The chat moves with the change, and the old place is cleared.
    public static func setStorage(_ storage: ChatStorage, in document: inout ALFAcolorDocument, local: any LocalChatStore) {
        guard storage != document.chatStorage else { return }
        let history = load(document, local: local)
        save(ChatHistory(), in: &document, local: local)
        document.chatStorage = storage
        save(history, in: &document, local: local)
    }
}
