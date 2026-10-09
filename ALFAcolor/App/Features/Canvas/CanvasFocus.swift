import SwiftUI
import BoardModel

extension FocusedValues {
    /// The canvas of the window in focus. Menu commands reach it through this value.
    @Entry var canvas: CanvasController?
    /// The selection and editing of the canvas of the window in focus.
    @Entry var interaction: CanvasInteraction?
}
