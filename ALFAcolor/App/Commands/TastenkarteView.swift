import SwiftUI
import AppTheme
import ALFAcolorCore

/// Tastenkarte (B-106): alle Befehle mit Kürzel, nach Menü geordnet. Liest die Tabelle aus ALFAcolorCore.
/// Öffnet über Hilfe ▸ Tastenkarte. Werte kommen aus dem Theme, keine festen Farben.
struct TastenkarteView: View {
    static let fensterID = "tastenkarte"

    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.space(.s5)) {
                ForEach(Menue.allCases, id: \.self) { menue in
                    VStack(alignment: .leading, spacing: theme.space(.s2)) {
                        Text(menue.titel)
                            .font(theme.text(.kopf).font)
                            .foregroundStyle(theme.color(.text, scheme))
                        ForEach(Tastenkarte.befehle.filter { $0.menue == menue }) { befehl in
                            zeile(befehl)
                        }
                    }
                }
            }
            .padding(theme.space(.s5))
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(theme.color(.grund, scheme))
        .frame(minWidth: 420, minHeight: 480)
    }

    private func zeile(_ befehl: Befehl) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: theme.space(.s3)) {
            Text(befehl.titel)
                .foregroundStyle(theme.color(.text, scheme))
            if befehl.geltung == .nurLeinwand {
                Text("nur Leinwand")
                    .foregroundStyle(theme.color(.textLeise, scheme))
            }
            Spacer(minLength: theme.space(.s2))
            Text(befehl.kuerzel?.anzeige ?? "")
                .foregroundStyle(theme.color(.textLeise, scheme))
        }
        .font(theme.text(.fliesstext).font)
        .accessibilityElement(children: .combine)
    }
}
