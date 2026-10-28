import Hub

extension Inlet {
    func mailboxName(_ display: MailboxDisplay) -> String {
        display.text(title: title, account: account)
    }

    var mailboxInitials: String {
        let parts = account.split(separator: "@", maxSplits: 1, omittingEmptySubsequences: false)
        let local = parts.first?.first.map(String.init) ?? ""
        let domain = parts.count > 1 ? parts[1].first.map(String.init) ?? "" : ""
        let initials = local + domain
        return (initials.isEmpty ? String(mailboxName(.ownName).prefix(1)) : initials).uppercased()
    }
}
