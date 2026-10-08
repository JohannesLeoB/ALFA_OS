import SwiftUI
import ALFAcolorCore

/// Was ein Menüeintrag beim Auslösen tut.
typealias Aktion = @MainActor () -> Void

/// Die Funktionen hinter den Menüeinträgen. Ein Befehl ohne Eintrag hier bleibt sichtbar und ausgegraut (B-106).
struct MenueFunktionen {
    var shell: ShellState?
    var zeigeTastenkarte: Aktion?

    @MainActor
    func aktion(fuer befehl: Befehl) -> Aktion? {
        switch befehl.id {
        case "darstellung.seitenleiste": return mit { $0.toggleSidebar() }
        case "darstellung.inspektor": return mit { $0.toggleInspector() }
        case "darstellung.alle": return mit { $0.togglePanels() }
        case "darstellung.statusleiste": return mit { $0.toggleStatusBar() }
        case "hilfe.tastenkarte": return zeigeTastenkarte
        default: return nil
        }
    }

    /// Verbindet eine Schalter-Funktion mit dem Zustand des Fensters. Ohne Fenster bleibt der Eintrag ausgegraut.
    @MainActor
    private func mit(_ tu: @escaping @MainActor (ShellState) -> Void) -> Aktion? {
        guard let shell else { return nil }
        return { tu(shell) }
    }
}

/// Die Glieder eines Menüs aus der Tastenkarte. Nur Einträge mit `herkunft == .eigen` erscheinen;
/// was macOS selbst liefert, bleibt bei macOS.
struct MenuePosten: View {
    let menue: Menue
    let funktionen: MenueFunktionen

    var body: some View {
        ForEach(Tastenkarte.posten(menue, herkunft: .eigen)) { posten in
            switch posten {
            case .trenner:
                Divider()
            case .eintrag(let befehl):
                MenueEintrag(befehl: befehl, aktion: funktionen.aktion(fuer: befehl))
            case .untermenue(let titel, let eintraege):
                Menu(titel) {
                    ForEach(eintraege) { befehl in
                        MenueEintrag(befehl: befehl, aktion: funktionen.aktion(fuer: befehl))
                    }
                }
            }
        }
    }
}

/// Ein Menüeintrag. Das Kürzel liegt nur auf Befehlen, die überall gelten; Einzeltasten der Werkzeuge
/// bindet B-305 bei Fokus auf der Leinwand. So fangen Menüs keine Buchstaben aus Textfeldern ab.
struct MenueEintrag: View {
    let befehl: Befehl
    let aktion: Aktion?

    var body: some View {
        if let kuerzel = befehl.kuerzel, befehl.geltung == .immer, let taste = tasteAlsKeyEquivalent(kuerzel.taste) {
            Button(befehl.titel) { aktion?() }
                .keyboardShortcut(taste, modifiers: ereignisse(kuerzel.modifikatoren))
                .disabled(aktion == nil)
        } else {
            Button(befehl.titel) { aktion?() }
                .disabled(aktion == nil)
        }
    }
}

/// Übersetzt die Taste aus der Tabelle in die SwiftUI-Form. Buchstaben werden klein geschrieben, wie SwiftUI sie erwartet.
func tasteAlsKeyEquivalent(_ text: String) -> KeyEquivalent? {
    if text == "⌫" { return .delete }
    guard text.count == 1, let zeichen = text.lowercased().first else { return nil }
    return KeyEquivalent(zeichen)
}

func ereignisse(_ modifikatoren: Modifikatoren) -> EventModifiers {
    var ergebnis: EventModifiers = []
    if modifikatoren.contains(.control) { ergebnis.insert(.control) }
    if modifikatoren.contains(.option) { ergebnis.insert(.option) }
    if modifikatoren.contains(.umschalt) { ergebnis.insert(.shift) }
    if modifikatoren.contains(.befehl) { ergebnis.insert(.command) }
    return ergebnis
}
