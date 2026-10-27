import Mail
import SwiftUI

extension Action {
    var shortcut: KeyboardShortcut? {
        switch self {
        case .reply: KeyboardShortcut("r", modifiers: .command)
        case .replyAll: KeyboardShortcut("r", modifiers: [.command, .shift])
        case .forward: KeyboardShortcut("f", modifiers: [.command, .shift])
        case .saveDraft: KeyboardShortcut("s", modifiers: .command)
        case .print: KeyboardShortcut("p", modifiers: .command)
        default: nil
        }
    }
}
