import Mail
import SwiftUI

extension MenuLine {
    @MainActor
    static func entries(_ lines: [MenuLine], appearance: Appearance, warns: Bool = true, run: @escaping (Action) -> Void) -> [MenuEntry] {
        lines.enumerated().map { index, line in
            let id = String(index)
            switch line {
            case .separator: return .separator(id: id)
            case .head(let text): return .head(id: id, label: Text(verbatim: text))
            case .item(let action, let checked):
                return .row(MenuItem(id: id, label: appearance.text(action.key), check: checked ? appearance.text("mail.menu.check") : nil,
                                     danger: warns && action.danger) { run(action) })
            }
        }
    }
}
