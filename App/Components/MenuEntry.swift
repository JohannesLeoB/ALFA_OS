import SwiftUI

enum MenuEntry: Identifiable {
    case row(MenuItem)
    case head(id: String, label: Text)
    case separator(id: String)

    var id: String {
        switch self {
        case .row(let row): row.id
        case .head(let id, _): id
        case .separator(let id): id
        }
    }
}

struct MenuItem: Identifiable {
    let id: String
    let label: Text
    var meta: Text?
    var check: Text?
    var danger = false
    let action: () -> Void
}
