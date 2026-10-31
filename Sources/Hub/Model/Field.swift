import Foundation

public struct Field: Identifiable, Equatable, Sendable {
    public typealias ID = String
    public var id: ID
    public var title: String
    public var secret: Bool
    public var optional: Bool
    var holdsAccount: Bool

    public init(id: ID, title: String, secret: Bool = false, optional: Bool = false, holdsAccount: Bool = false) {
        self.id = id
        self.title = title
        self.secret = secret
        self.optional = optional
        self.holdsAccount = holdsAccount
    }
}

public enum Input: Equatable, Sendable {
    public static let expectedAccountKey = "expectedAccount"
    public static let renewsKey = "renews"

    case none
    case fields([Field.ID: String])

    var values: [Field.ID: String] {
        switch self {
        case .none: [:]
        case .fields(let values): values
        }
    }

    var renews: String? {
        let text = values[Self.renewsKey] ?? ""
        return text.isEmpty ? nil : text
    }

    var expectedAccount: String? {
        let text = (values[Self.expectedAccountKey] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }
}
