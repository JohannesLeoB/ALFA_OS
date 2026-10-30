public enum MenuEngine {
    private static let printableExtensions: Set<String> = ["pdf", "png", "jpg", "jpeg", "gif", "heic", "txt"]

    public static func row(unread: Bool, draft: Bool) -> [MenuLine] {
        if draft { return [.item(.openDraft)] }
        return [.item(.reply), .item(.forward), .separator, .item(.archive),
                .item(unread ? .markRead : .markUnread), .item(.move), .separator, .item(.trash)]
    }

    public static func readingMore(starred: Bool, original: Bool) -> [MenuLine] {
        [.item(starred ? .unstar : .star), .item(.markUnread), .item(.move), .separator] + (original ? [.item(.original)] : []) + [.item(.spam)]
    }

    public static func draftMore(receipt: Bool) -> [MenuLine] {
        [.item(.receipt, checked: receipt)]
    }

    public static func person(address: String, contact: Bool) -> [MenuLine] {
        [.head(address), .item(.copyAddress), .item(.writeMail), .item(contact ? .editContact : .saveContact)]
    }

    public static func attachment(name: String) -> [MenuLine] {
        let printable = printableExtensions.contains(name.split(separator: ".").last.map { $0.lowercased() } ?? "")
        return [.item(.preview)] + (printable ? [.item(.print), .item(.pdf)] : []) + [.separator, .item(.otherProject), .item(.saveAs)]
    }
}
