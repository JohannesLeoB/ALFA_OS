import SwiftUI
import AppKit
import struct ALFAcolorCore.ItemID
import AppTheme
import BoardModel
import Document
import UniformTypeIdentifiers

/// Connects the pointer, the keys and the feedback of the canvas to `CanvasInteraction`.
/// The view only passes events on; what they mean is decided in the model.
/// Space plus drag grabs the canvas (`panning`), and then the pointer does not select.
struct SelectionInput: ViewModifier {
    var interaction: CanvasInteraction
    /// True while the canvas has the keyboard focus. The keys are for the canvas only then.
    var isFocused: Bool
    var panning: Bool

    @Environment(\.theme) private var theme
    @State private var pressed = false
    @State private var searchTarget: ItemID?
    @State private var showsFilePanel = false

    func body(content: Content) -> some View {
        content
            .simultaneousGesture(drag)
            .simultaneousGesture(SpatialTapGesture(count: 2).onEnded { tap in
                guard !panning else { return }
                interaction.doubleClick(atCanvasX: tap.location.x, y: tap.location.y)
            })
            .onContinuousHover { phase in
                switch phase {
                case .active(let point): interaction.hover(atCanvasX: point.x, y: point.y)
                case .ended: interaction.hover(atCanvasX: .nan, y: .nan)
                }
            }
            .onModifierKeysChanged(mask: .option, initial: true) { _, keys in
                interaction.optionHeld = keys.contains(.option)
            }
            .onChange(of: interaction.snapTick) {
                NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
            }
            .onKeyPress(keys: [.leftArrow, .rightArrow, .upArrow, .downArrow]) { press in
                guard isFocused, press.modifiers.isDisjoint(with: [.command, .option, .control]) else { return .ignored }
                let arrow: Arrow = switch press.key {
                case .leftArrow: .left
                case .rightArrow: .right
                case .upArrow: .up
                default: .down
                }
                return interaction.nudge(arrow, large: press.modifiers.contains(.shift)) ? .handled : .ignored
            }
            .onKeyPress(keys: [.delete, .deleteForward]) { _ in
                guard isFocused else { return .ignored }
                return interaction.deleteSelection() ? .handled : .ignored
            }
            .onKeyPress(.escape) {
                guard isFocused else { return .ignored }
                return interaction.escape() ? .handled : .ignored
            }
            .onKeyPress(characters: CharacterSet(charactersIn: "a")) { press in
                guard isFocused, press.modifiers == .command else { return .ignored }
                interaction.selectAll()
                return .handled
            }
            .onCommand(#selector(NSResponder.selectAll(_:))) { interaction.selectAll() }
            .onAppear(perform: configure)
            .onChange(of: theme) { configure() }
            .onChange(of: interaction.fileSearchRequest) { _, request in
                guard let request else { return }
                searchTarget = request
                showsFilePanel = true
            }
            .onChange(of: showsFilePanel) { _, shown in
                if !shown { interaction.fileSearchRequest = nil }
            }
            .fileImporter(isPresented: $showsFilePanel, allowedContentTypes: [.image]) { result in
                guard let target = searchTarget, case .success(let url) = result else { return }
                replaceImage(of: target, from: url)
            }
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard !panning else { return }
                if !pressed {
                    pressed = true
                    interaction.pointerDown(atCanvasX: value.startLocation.x, y: value.startLocation.y, modifiers: Self.modifiers())
                }
                interaction.pointerDragged(toCanvasX: value.location.x, y: value.location.y, modifiers: Self.modifiers())
            }
            .onEnded { value in
                guard pressed else { return }
                pressed = false
                interaction.pointerUp(atCanvasX: value.location.x, y: value.location.y, modifiers: Self.modifiers())
            }
    }

    /// The sizes and tokens of the theme go to the model, which works in points and has no theme.
    private func configure() {
        interaction.bandHeight = theme.space(.s6)
        interaction.handleSize = theme.space(.s2)
        interaction.spacingStops = SpaceToken.allCases.map { SpacingStop(name: "space.\($0.rawValue)", value: theme.space($0)) }
    }

    private func replaceImage(of id: ItemID, from url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else { return }
        interaction.replaceImage(of: id, with: data, fileExtension: url.pathExtension)
    }

    private static func modifiers() -> PointerModifiers {
        let flags = NSEvent.modifierFlags
        var result: PointerModifiers = []
        if flags.contains(.shift) { result.insert(.shift) }
        if flags.contains(.command) { result.insert(.command) }
        if flags.contains(.option) { result.insert(.option) }
        return result
    }
}

extension View {
    /// Selecting, moving, resizing and editing on the canvas.
    func selectionInput(_ interaction: CanvasInteraction, isFocused: Bool, panning: Bool) -> some View {
        modifier(SelectionInput(interaction: interaction, isFocused: isFocused, panning: panning))
    }
}
