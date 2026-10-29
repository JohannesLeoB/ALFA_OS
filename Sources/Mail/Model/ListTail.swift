import Foundation

public enum ListTail: Equatable, Sendable {
    case older
    case moreResults

    public var key: String {
        switch self {
        case .older: "mail.list.older"
        case .moreResults: "mail.list.moreResults"
        }
    }
}
