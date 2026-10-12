import SwiftUI
import AppKit
import AppTheme
import BoardModel

/// The start window: the rows of the first start. It shows while no document is open and closes when one opens.
struct StartWindowView: View {
    static let windowID = "start"

    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismissWindow) private var dismissWindow
    @State private var recent: [URL] = []

    var body: some View {
        VStack(alignment: .leading, spacing: theme.space(.s3)) {
            Text("start.window.title")
                .themeText(theme.text(.heading))
            row(.new) { NSDocumentController.shared.newDocument(nil) }
            row(.open) { NSDocumentController.shared.openDocument(nil) }
            row(.example) { StarterOpener.open(StarterOpener.exampleName) }
            if !recent.isEmpty {
                Text(LocalizedStringKey(StartRow.recent.titleKey))
                    .themeText(theme.text(.caption))
                    .foregroundStyle(theme.color(.textMuted, scheme))
                ForEach(recent, id: \.self) { url in
                    Button(url.deletingPathExtension().lastPathComponent) {
                        NSDocumentController.shared.openDocument(withContentsOf: url, display: true) { _, _, error in
                            if let error { NSApplication.shared.presentError(error) }
                        }
                    }
                    .buttonStyle(.link)
                }
            }
        }
        .padding(theme.space(.s5))
        .onAppear {
            recent = Array(NSDocumentController.shared.recentDocumentURLs.prefix(StartWindow.recentLimit))
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in
            // A document window that comes to the front ends the start window.
            if !StartWindow.isShown(openDocuments: NSDocumentController.shared.documents.count) {
                dismissWindow(id: Self.windowID)
            }
        }
    }

    /// One row of the start window. The recent row is disabled while the list is empty.
    private func row(_ kind: StartRow, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(LocalizedStringKey(kind.titleKey))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .controlSize(.large)
        .disabled(!kind.isEnabled(recentCount: recent.count))
    }
}
