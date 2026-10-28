import Hub

extension Inlet {
    func shownTitle(_ appearance: Appearance) -> String {
        appearance.string(title).trimmingCharacters(in: .whitespaces)
    }

    func shownName(_ display: MailboxDisplay, appearance: Appearance) -> String {
        display.text(title: shownTitle(appearance), account: account)
    }
}
