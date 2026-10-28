import Hub

extension Inlet {
    var mailboxName: String {
        let name = title.trimmingCharacters(in: .whitespaces)
        if !name.isEmpty { return name }
        return account.split(separator: "@", omittingEmptySubsequences: false).first.map(String.init) ?? account
    }

    var mailboxInitials: String {
        let parts = account.split(separator: "@", maxSplits: 1, omittingEmptySubsequences: false)
        let local = parts.first?.first.map(String.init) ?? ""
        let domain = parts.count > 1 ? parts[1].first.map(String.init) ?? "" : ""
        let initials = local + domain
        return (initials.isEmpty ? String(mailboxName.prefix(1)) : initials).uppercased()
    }
}
