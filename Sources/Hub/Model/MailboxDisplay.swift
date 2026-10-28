import Foundation

public enum MailboxDisplay: String, CaseIterable, Sendable {
    case ownName
    case localPart
    case domain

    public func text(title: String, account: String) -> String {
        switch self {
        case .ownName:
            let name = title.trimmingCharacters(in: .whitespaces)
            return name.isEmpty ? Self.local(account) : name
        case .localPart: return Self.local(account)
        case .domain: return Self.domain(account)
        }
    }

    public static func local(_ account: String) -> String {
        let part = account.split(separator: "@", omittingEmptySubsequences: false).first.map(String.init) ?? ""
        return (part.isEmpty ? account : part) + "@"
    }

    public static func domain(_ account: String) -> String {
        let parts = account.split(separator: "@", maxSplits: 1, omittingEmptySubsequences: false)
        let part = parts.count > 1 ? String(parts[1]) : ""
        return "@" + (part.isEmpty ? account : part)
    }
}
