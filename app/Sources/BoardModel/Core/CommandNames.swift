import Foundation
import ALFAcolorCore

extension Command {
    /// Key of the undo name in the string catalog. Nil for a command that gives no undo step.
    public var nameKey: String? {
        switch self {
        case .insert: "undo.insert"
        case .delete: "undo.delete"
        case .move: "undo.move"
        case .resize: "undo.resize"
        case .reorder(_, let how): "undo.reorder.\(how.rawValue)"
        case .setContent: "undo.setContent"
        case .group: "undo.group"
        case .ungroup: "undo.ungroup"
        case .setLocked(_, let value): value ? "undo.lock" : "undo.unlock"
        case .setHidden(_, let value): value ? "undo.hide" : "undo.show"
        case .moveToLayer: "undo.layer"
        case .arrange(let how, _, _, _): "undo.arrange.\(how.rawValue)"
        case .switchSpace: nil
        case .batch(_, let key): key ?? "undo.batch"
        }
    }

    /// The name that the Edit menu shows after "Undo", in the language of the app.
    public var undoName: String? { nameKey.map(Self.localized) }

    static func localized(_ key: String) -> String {
        Bundle.main.localizedString(forKey: key, value: nil, table: nil)
    }

    /// All keys that a command can use by itself. The string catalog must have all of them.
    public static var allNameKeys: [String] {
        ["undo.insert", "undo.delete", "undo.move", "undo.resize", "undo.group", "undo.ungroup",
         "undo.lock", "undo.unlock", "undo.hide", "undo.show", "undo.layer", "undo.batch", "undo.setContent", "undo.duplicate"]
            + StackMove.allCases.map { "undo.reorder.\($0.rawValue)" }
            + Arrangement.allCases.map { "undo.arrange.\($0.rawValue)" }
    }
}
