import SwiftUI
import AppKit
import UniformTypeIdentifiers
import AppTheme
import ALFAcolorCore
import BoardModel
import Importers

/// Paste and drop on the canvas. A paste lands in the middle of the visible part of the board, a drop where it is released.
/// The pieces are read and placed by `ImportCoordinator`; this modifier passes the point on and shows what the coordinator asks or reports.
struct ImportTargets: ViewModifier {
    let controller: CanvasController
    let importer: ImportCoordinator
    /// Holds the clipboard of the canvas, and the request of the toolbar to choose files.
    let interaction: CanvasInteraction

    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var scheme
    @State private var isTargeted = false
    @State private var showsChooser = false

    /// The kinds the canvas takes: files, images, addresses and text.
    private static let kinds: [UTType] = [.fileURL, .image, .url, .plainText]

    func body(content: Self.Content) -> some View {
        content
            .onPasteCommand(of: Self.kinds) { providers in
                let visible = controller.viewport.visibleRect(in: controller.size)
                let centerX = visible.x + visible.w / 2, centerY = visible.y + visible.h / 2
                // Pieces copied on this canvas paste as pieces, as long as the pasteboard still holds their mark.
                if !interaction.clipboardMark.isEmpty, NSPasteboard.general.string(forType: .string) == interaction.clipboardMark {
                    interaction.pasteClipboard(atX: centerX, y: centerY)
                    return
                }
                Task {
                    await importer.handle(providers, entry: .paste, centerX: centerX, centerY: centerY)
                }
            }
            .onChange(of: interaction.importRequest) { showsChooser = true }
            .background {
                // Own host for the chooser: the canvas already presents a file chooser for image replacement.
                Color.clear.fileImporter(isPresented: $showsChooser, allowedContentTypes: [.item], allowsMultipleSelection: true) { result in
                    guard case .success(let urls) = result, !urls.isEmpty else { return }
                    let visible = controller.viewport.visibleRect(in: controller.size)
                    Task { await Self.importFiles(urls, into: importer, centerX: visible.x + visible.w / 2, centerY: visible.y + visible.h / 2) }
                }
            }
            .onDrop(of: Self.kinds, isTargeted: $isTargeted) { providers, location in
                let point = controller.viewport.boardPoint(canvasX: location.x, canvasY: location.y)
                Task { await importer.handle(providers, entry: .drop, centerX: point.x, centerY: point.y) }
                return true
            }
            .overlay {
                if isTargeted {
                    RoundedRectangle(cornerRadius: theme.radius(.m))
                        .strokeBorder(theme.color(.accent, scheme), lineWidth: SelectionStyle.outlineWidth)
                }
            }
            .onChange(of: theme.space(.s6), initial: true) { importer.headerHeight = theme.space(.s6) }
            .alert("import.large.title", isPresented: largeBinding) {
                Button("import.large.confirm") { importer.confirmLarge() }
                Button("import.large.cancel", role: .cancel) { importer.declineLarge() }
            } message: {
                Text("import.large.message \(importer.question?.files.count ?? 0)")
            }
            .alert("import.skipped.title", isPresented: skippedBinding) {
                Button("import.dismiss", role: .cancel) { importer.acknowledge() }
            } message: {
                Text("import.skipped.message \(importer.skipped.count)")
            }
            .alert("import.error.title", isPresented: failureBinding) {
                Button("import.dismiss", role: .cancel) { importer.dismissFailure() }
            } message: {
                Text(verbatim: (importer.failure as? LocalizedError)?.errorDescription ?? "")
            }
    }

    private var largeBinding: Binding<Bool> {
        Binding(get: { importer.question != nil }, set: { if !$0 { importer.declineLarge() } })
    }

    private var skippedBinding: Binding<Bool> {
        Binding(get: { !importer.skipped.isEmpty }, set: { if !$0 { importer.acknowledge() } })
    }

    private var failureBinding: Binding<Bool> {
        Binding(get: { importer.failure != nil }, set: { if !$0 { importer.dismissFailure() } })
    }

    /// Reads chosen files in the scope the chooser gives them, and places them like a paste.
    @MainActor
    private static func importFiles(_ urls: [URL], into importer: ImportCoordinator, centerX: Double, centerY: Double) async {
        let scoped = urls.filter { $0.startAccessingSecurityScopedResource() }
        defer { scoped.forEach { $0.stopAccessingSecurityScopedResource() } }
        await importer.handle(urls.map { ImportSource.file($0) }, entry: .paste, centerX: centerX, centerY: centerY)
    }
}
