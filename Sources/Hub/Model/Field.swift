import Foundation

public struct Field: Identifiable, Equatable, Sendable {
    public typealias ID = String
    public var id: ID
    public var title: String
    public var secret: Bool
    var holdsAccount: Bool

    public init(id: ID, title: String, secret: Bool = false, holdsAccount: Bool = false) {
        self.id = id
        self.title = title
        self.secret = secret
        self.holdsAccount = holdsAccount
    }
}

public enum Input: Equatable, Sendable {
    public static let expectedAccountKey = "expectedAccount"

    case none
    case fields([Field.ID: String])

    var values: [Field.ID: String] {
        switch self {
        case .none: [:]
        case .fields(let values): values
        }
    }

    var expectedAccount: String? {
        let text = (values[Self.expectedAccountKey] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }
}
