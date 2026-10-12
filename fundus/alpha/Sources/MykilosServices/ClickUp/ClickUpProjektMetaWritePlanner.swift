import Foundation
import MykilosKit

public enum ClickUpProjektMetaWritePlanner {
    public static func feldID(
        fuerKlemme slot: ClickUpMetaSlot, liveFields: [ClickUpCustomFieldRef],
        routes: ClickUpFieldRouteRegistry = .default, erfordertTextSchreiben: Bool = true
    ) -> String? {
        guard let source = routes.routes.first(where: { $0.isActive && $0.target == slot })?.source,
              let feld = try? ClickUpCustomFieldRef.eindeutig(in: liveFields, name: source) else { return nil }
        return (erfordertTextSchreiben == false || feld.unterstuetztSchreiben) ? feld.id : nil
    }

    public static func planeTextSchreibungen(
        knownValues: [ClickUpMetaSlot: String], liveFields: [ClickUpCustomFieldRef],
        routes: ClickUpFieldRouteRegistry = .default
    ) -> [(fieldID: String, value: String)] {
        knownValues.compactMap { slot, value in
            feldID(fuerKlemme: slot, liveFields: liveFields, routes: routes).map { ($0, value) }
        }
    }

    public enum TypisierterWert: Equatable, Sendable {
        case text(String)
        case date(Date)
        case checkbox(Bool)

        case dropdownLabel(String)
    }

    public enum GeplanteSchreibung: Equatable, Sendable {
        case text(fieldID: String, value: String)
        case date(fieldID: String, value: Date)
        case checkbox(fieldID: String, value: Bool)
        case dropdown(fieldID: String, optionID: String)
    }

    public static func planeTypisiert(
        feldName: String, value: TypisierterWert, liveFields: [ClickUpCustomFieldRef]
    ) -> GeplanteSchreibung? {
        guard let feld = try? ClickUpCustomFieldRef.eindeutig(in: liveFields, name: feldName) else { return nil }
        switch (feld.typisierterSchreibPfad, value) {
        case (.text, .text(let s)):
            return s.isEmpty ? nil : .text(fieldID: feld.id, value: s)
        case (.date, .date(let d)):
            return .date(fieldID: feld.id, value: d)
        case (.checkbox, .checkbox(let b)):
            return .checkbox(fieldID: feld.id, value: b)
        case (.dropdown, .dropdownLabel(let label)):
            guard let optionID = (try? feld.optionIDStreng(forLabel: label)) ?? nil else { return nil }
            return .dropdown(fieldID: feld.id, optionID: optionID)
        default:
            return nil
        }
    }
}
