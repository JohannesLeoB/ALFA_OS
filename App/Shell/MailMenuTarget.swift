import Mail
import SwiftUI

struct MailMenuTarget {
    let front: CardRef?
    let commands: CommandSet
    let read: Bool
    let starred: Bool
    let perform: (Action) -> Void
    var extra: [Action] = []

    var isMessage: Bool {
        if case .message = front { return true }
        return false
    }

    func allows(_ action: Action) -> Bool {
        let slots = commands.main + commands.fan + commands.fold + commands.footLeft + commands.footRight
        return extra.contains(action) || slots.contains { $0.action == action && !$0.off }
    }
}

extension FocusedValues {
    @Entry var mailMenu: MailMenuTarget?
}
