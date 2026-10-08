import SwiftUI
import AppTheme

@main
struct ALFAcolorApp: App {
    /// Startgröße des Hauptfensters, konzept/05-OBERFLAECHE.txt Abschnitt 2.3.
    private static let defaultSize = CGSize(width: 1280, height: 800)

    /// Der Vertrag aus dem App-Paket, falls der Bau ihn mitgibt; sonst gilt der Platzhalter (Chef, B-102).
    private let theme: Theme = {
        guard let url = Theme.vertragsdatei(), let vertrag = try? Theme.laden(aus: url) else { return .platzhalter }
        return vertrag
    }()

    var body: some Scene {
        WindowGroup {
            ShellView()
                .environment(\.theme, theme)
        }
        .defaultSize(width: Self.defaultSize.width, height: Self.defaultSize.height)
        .defaultWindowPlacement { _, context in
            // Wunsch: Mitte der sichtbaren Fläche des Hauptbildschirms, Größe nie über die sichtbare Fläche hinaus.
            // Beobachtet (macOS 26.6): Die Lage setzt das System selbst; ein hier angegebener Punkt änderte sie nicht.
            let sichtbar = context.defaultDisplay.visibleRect
            let breite = min(Self.defaultSize.width, sichtbar.width)
            let hoehe = min(Self.defaultSize.height, sichtbar.height)
            return WindowPlacement(
                CGPoint(x: sichtbar.midX - breite / 2, y: sichtbar.midY - hoehe / 2),
                size: CGSize(width: breite, height: hoehe)
            )
        }
        .commands { ALFAcolorCommands() }

        // Tastenkarte (B-106): Übersicht aller Kürzel, geöffnet über Hilfe ▸ Tastenkarte.
        Window("Tastenkarte", id: TastenkarteView.fensterID) {
            TastenkarteView()
                .environment(\.theme, theme)
        }
        .defaultSize(width: 460, height: 640)
    }
}
