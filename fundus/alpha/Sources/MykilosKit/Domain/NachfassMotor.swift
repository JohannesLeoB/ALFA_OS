import Foundation

public enum NachfassBefund: Equatable, Sendable {
    case faellig(seitTagen: Int)

    case ohneTerminUeberfaellig(angebotAlterTage: Int)

    case geplant(inTagen: Int)

    public var istHandlungsbedarf: Bool {
        switch self {
        case .faellig, .ohneTerminUeberfaellig: true
        case .geplant: false
        }
    }
}

public enum NachfassMotor {
    public static let standardSchwelleTage = 14

    public static func bewerte(
        angebotsdatum: Date?,
        naechstesNachfassen: Date?,
        auftragsdatum: Date?,
        heute: Date = Date(),
        schwelleTage: Int = standardSchwelleTage
    ) -> NachfassBefund? {
        let kalender = Calendar.current

        if auftragsdatum != nil {
            if let appointment = naechstesNachfassen,
               let inTagen = kalender.dateComponents([.day],
                                                     from: kalender.startOfDay(for: heute),
                                                     to: kalender.startOfDay(for: appointment)).day,
               inTagen > 0 {
                return .geplant(inTagen: inTagen)
            }
            return nil
        }

        if let appointment = naechstesNachfassen {
            let tage = kalender.dateComponents([.day],
                                               from: kalender.startOfDay(for: appointment),
                                               to: kalender.startOfDay(for: heute)).day ?? 0
            return tage >= 0 ? .faellig(seitTagen: tage) : .geplant(inTagen: -tage)
        }

        if let angebot = angebotsdatum {
            let alter = kalender.dateComponents([.day],
                                                from: kalender.startOfDay(for: angebot),
                                                to: kalender.startOfDay(for: heute)).day ?? 0
            if alter >= schwelleTage, schwelleTage > 0 {
                return .ohneTerminUeberfaellig(angebotAlterTage: alter)
            }
        }

        return nil
    }

    public static func text(_ befund: NachfassBefund) -> String {
        switch befund {
        case .faellig(let seit):
            seit == 0 ? "Nachfassen HEUTE fällig (ClickUp-Termin)"
                      : "Nachfassen seit \(seit) Tag\(seit == 1 ? "" : "en") überfällig (ClickUp-Termin)"
        case .ohneTerminUeberfaellig(let alter):
            "Angebot seit \(alter) Tagen draußen — KEIN Nachfass-Termin gesetzt"
        case .geplant(let inTagen):
            inTagen == 1 ? "Nachfassen morgen" : "Nachfassen in \(inTagen) Tagen"
        }
    }
}
