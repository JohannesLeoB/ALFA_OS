import Mail
import SwiftUI

@MainActor
enum MoveFolderList {
    static func entries(_ inbox: InboxState, appearance: Appearance, message id: String) -> [MenuEntry] {
        let rows = inbox.moveTargets(id).map { folder in
            MenuEntry.row(MenuItem(id: folder.id, label: Text(verbatim: FolderTitle.text(inbox.folderName(folder.id)) { appearance.string($0) })) {
                ActionRouter(state: inbox).move(id, to: folder.id)
            })
        }
        return [.head(id: "head", label: appearance.text("mail.action.move"))] + rows
    }
}
