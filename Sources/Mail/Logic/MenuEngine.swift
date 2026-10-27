public enum MenuEngine {
    public static func row(unread: Bool, draft: Bool) -> [MenuLine] {
        if draft { return [.item(.openDraft)] }
        return [.item(.reply), .item(.forward), .separator, .item(.archive),
                .item(unread ? .markRead : .markUnread), .separator, .item(.trash)]
    }

    public static func readingMore(starred: Bool) -> [MenuLine] {
        [.item(starred ? .unstar : .star), .item(.markUnread), .separator, .item(.spam)]
    }

    public static func person(address: String, contact: Bool) -> [MenuLine] {
        [.head(address), .item(.copyAddress), .item(.writeMail), .item(contact ? .editContact : .saveContact)]
    }

    public static func attachment() -> [MenuLine] {
        [.item(.saveAs)]
    }
}
