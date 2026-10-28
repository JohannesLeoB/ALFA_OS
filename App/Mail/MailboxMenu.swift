import AppKit
import Hub
import Mail
import SwiftUI

@MainActor
enum MailboxMenu {
    static func entries(for account: Inlet, current: MailboxDisplay, appearance: Appearance,
                        choose: @escaping (MailboxDisplay) -> Void) -> [MenuEntry] {
        let own = account.ownName
        return [.head(id: "mailbox.display", label: appearance.text("mail.account.show"))] + MailboxDisplay.allCases.map { option in
            let label: Text
            var meta: Text?
            switch option {
            case .ownName:
                label = own.isEmpty ? appearance.text("mail.account.show.own") : Text(verbatim: own)
                meta = own.isEmpty ? appearance.text("mail.account.show.inSettings") : nil
            case .localPart: label = Text(verbatim: MailboxDisplay.local(account.account))
            case .domain: label = Text(verbatim: MailboxDisplay.domain(account.account))
            }
            return .row(MenuItem(id: option.rawValue, label: label, meta: meta,
                                 check: option == current ? appearance.text("mail.menu.check") : nil) { choose(option) })
        }
    }

    static func show(for account: Inlet, current: MailboxDisplay, at point: NSPoint, appearance: Appearance,
                     choose: @escaping (MailboxDisplay) -> Void) {
        MenuPanel.shared.show(entries: entries(for: account, current: current, appearance: appearance, choose: choose),
                              anchor: .point(point), window: NSApp.keyWindow)
    }
}
