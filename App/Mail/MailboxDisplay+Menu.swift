import AppKit
import Hub
import SwiftUI

extension MailboxDisplay {
    @MainActor
    static func showMenu(for account: Inlet, current: MailboxDisplay, at point: NSPoint, appearance: Appearance,
                         choose: @escaping (MailboxDisplay) -> Void) {
        let own = account.title.trimmingCharacters(in: .whitespaces)
        let entries: [MenuEntry] = [.head(id: "mailbox.display", label: appearance.text("mail.account.show"))] + allCases.map { option in
            let label: Text
            var meta: Text?
            switch option {
            case .ownName:
                label = own.isEmpty ? appearance.text("mail.account.show.own") : Text(verbatim: own)
                meta = own.isEmpty ? appearance.text("mail.account.show.inSettings") : nil
            case .localPart: label = Text(verbatim: local(account.account))
            case .domain: label = Text(verbatim: domain(account.account))
            }
            return .row(MenuItem(id: option.rawValue, label: label, meta: meta,
                                 check: option == current ? appearance.text("mail.menu.check") : nil) { choose(option) })
        }
        MenuPanel.shared.show(entries: entries, anchor: .point(point), window: NSApp.keyWindow)
    }
}
