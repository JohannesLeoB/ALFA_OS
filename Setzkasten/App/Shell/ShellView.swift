import SwiftUI
import AppTheme

/// Hauptfenster (B-102): Seitenleiste, Leinwand, Inspektor, Werkzeugleiste, Statusleiste.
/// Glas für Seitenleiste, Inspektor und Werkzeugleiste zeichnet das System; hier steht kein eigener Hintergrund dafür.
struct ShellView: View {
    /// Mindestgröße des Hauptfensters, konzept/05-OBERFLAECHE.txt Abschnitt 2.3.
    static let minimumSize = CGSize(width: 1000, height: 640)

    @State private var shell = ShellState()

    var body: some View {
        NavigationSplitView(columnVisibility: $shell.columnVisibility) {
            SidebarView()
        } detail: {
            VStack(spacing: 0) {
                CanvasView(shell: shell)
                if shell.statusBarVisible {
                    StatusBarView()
                }
            }
            .inspector(isPresented: $shell.inspectorVisible) {
                InspectorView()
            }
        }
        .toolbar { ShellToolbar(shell: shell) }
        .focusedSceneValue(\.shell, shell)
        .frame(minWidth: Self.minimumSize.width, minHeight: Self.minimumSize.height)
    }
}
