public enum MenuEngine {
    private static let printableExtensions: Set<String> = ["pdf", "png", "jpg", "jpeg", "gif", "heic", "txt"]

    public static func row(unread: Bool, draft: Bool, folders: Bool = true, trashes: Bool = true, purges: Bool = false) -> [MenuLine] {
        if draft { return [.item(.openDraft)] }
        let bin: [MenuLine] = trashes ? [.separator, .item(.trash)] : purges ? [.separator, .item(.purge)] : []
        return [.item(.reply), .item(.forward), .separator] + (folders ? [.item(.archive)] : [])
            + [.item(unread ? .markRead : .markUnread)] + (folders ? [.item(.move)] : []) + bin
    }

    public static func readingMore(starred: Bool, original: Bool, folders: Bool = true, spam: Bool = true) -> [MenuLine] {
        let marks: [MenuLine] = [.item(starred ? .unstar : .star), .item(.markUnread)] + (folders ? [.item(.move)] : [])
        let more: [MenuLine] = (original ? [.item(.original)] : []) + (folders && spam ? [.item(.spam)] : [])
        return more.isEmpty ? marks : marks + [.separator] + more
    }

    public static func draftMore(receipt: Bool) -> [MenuLine] {
        [.item(.receipt, checked: receipt), .separator, .item(.print)]
    }

    public static func person(address: String, contact: Bool) -> [MenuLine] {
        [.head(address), .item(.copyAddress), .item(.writeMail), .item(contact ? .editContact : .saveContact)]
    }

    public static func attachment(name: String, project: Bool = true) -> [MenuLine] {
        let printable = printableExtensions.contains(name.split(separator: ".").last.map { $0.lowercased() } ?? "")
        return [.item(.preview)] + (printable ? [.item(.print), .item(.pdf)] : []) + [.separator] + (project ? [.item(.otherProject)] : []) + [.item(.saveAs)]
    }
}
