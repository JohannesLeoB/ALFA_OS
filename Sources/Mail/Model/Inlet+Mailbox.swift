import Foundation
import Hub

extension Inlet {
    public var ownName: String { title.trimmingCharacters(in: .whitespaces) }

    public func mailboxName(_ display: MailboxDisplay) -> String {
        display.text(title: title, account: account)
    }

    public var mailboxInitials: String {
        let address = account.trimmingCharacters(in: .whitespaces)
        let parts = address.split(separator: "@", maxSplits: 1, omittingEmptySubsequences: false)
        let local = parts.first?.first.map(String.init) ?? ""
        let domain = parts.count > 1 ? parts[1].first.map(String.init) ?? "" : ""
        let initials = local + domain
        return (initials.isEmpty ? ownName.first.map(String.init) ?? "" : initials).uppercased()
    }
}
