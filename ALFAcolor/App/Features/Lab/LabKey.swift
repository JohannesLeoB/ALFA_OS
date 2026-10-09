import SwiftUI
import BoardModel

/// The L key on the canvas. It opens the lab of the selected code card, or of a new empty card.
/// It works only while the canvas has the keyboard focus, and only when no lab is open.
struct LabKey: ViewModifier {
    /// True while the canvas has the keyboard focus.
    var isFocused: Bool

    @FocusedValue(\.shell) private var shell
    @FocusedValue(\.canvas) private var canvas

    func body(content: Content) -> some View {
        content.onKeyPress(characters: CharacterSet(charactersIn: "l")) { press in
            guard isFocused, press.modifiers.isEmpty, let shell, let canvas, shell.openLabModel == nil else { return .ignored }
            guard let card = try? LabEntry.card(in: canvas) else { return .ignored }
            // A card that is not web code gets the notice of the status bar instead.
            shell.openLab(for: card, store: canvas.store)
            return .handled
        }
    }
}
