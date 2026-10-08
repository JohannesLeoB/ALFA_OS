import SwiftUI
import ALFAcolorCore

/// Alle Menüs der App (B-106). Die Einträge stehen in `Tastenkarte` (ALFAcolorCore).
/// Systemmenüs bleiben System: nur die eigenen Einträge werden angehängt oder ersetzen den Platz von `Neues Dokument`.
struct ALFAcolorCommands: Commands {
    var body: some Commands {
        ShellCommands()
        AblageCommands()
        BearbeitenCommands()
        ObjektCommands()
        FensterCommands()
        HilfeCommands()
    }
}

struct AblageCommands: Commands {
    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            MenuePosten(menue: .ablage, funktionen: MenueFunktionen())
        }
    }
}

struct BearbeitenCommands: Commands {
    var body: some Commands {
        CommandGroup(after: .pasteboard) {
            MenuePosten(menue: .bearbeiten, funktionen: MenueFunktionen())
        }
    }
}

struct ObjektCommands: Commands {
    var body: some Commands {
        CommandMenu("Objekt") {
            MenuePosten(menue: .objekt, funktionen: MenueFunktionen())
        }
    }
}

struct FensterCommands: Commands {
    var body: some Commands {
        CommandGroup(after: .windowArrangement) {
            MenuePosten(menue: .fenster, funktionen: MenueFunktionen())
        }
    }
}

struct HilfeCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(after: .help) {
            MenuePosten(
                menue: .hilfe,
                funktionen: MenueFunktionen(zeigeTastenkarte: { openWindow(id: TastenkarteView.fensterID) })
            )
        }
    }
}
