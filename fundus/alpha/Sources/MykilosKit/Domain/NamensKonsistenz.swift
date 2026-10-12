import Foundation

public enum NamensKonsistenzBefund: Equatable, Sendable {
    case hubPraefixFalsch(hub: String, erwartet: String)

    case driveWeichtAb(hub: String, drive: String)

    case clickUpWeichtAb(hub: String, list: String)

    case clickUpFremdeNummer(list: String, erwartet: String)

    public var klartext: String {
        switch self {
        case .hubPraefixFalsch(let hub, let erwartet):
            "Hub-Ordnername „\(hub)\" passt nicht zur Projektnummer (erwartet Präfix \(erwartet)_…)"
        case .driveWeichtAb(let hub, let drive):
            "Drive-Ordner heißt „\(drive)\", Hub sagt „\(hub)\""
        case .clickUpWeichtAb(let hub, let list):
            "ClickUp-Liste heißt „\(list)\", Hub sagt „\(hub)\""
        case .clickUpFremdeNummer(let list, let erwartet):
            "ClickUp-Liste „\(list)\" trägt eine FREMDE Projektnummer (erwartet \(erwartet))"
        }
    }
}

public enum NamensKonsistenz {
    public static func pruefe(
        projektNummerApp: String,
        hubOrdnername: String?,
        driveOrdnernameLokal: String?,
        clickUpListenName: String?
    ) -> [NamensKonsistenzBefund] {
        guard let number = Projektnummer(parsing: projektNummerApp) else { return [] }
        let praefix = number.driveFormat
        var befunde: [NamensKonsistenzBefund] = []

        let hub = leerZuNil(hubOrdnername)
        if let hub, hub.hasPrefix(praefix + "_") == false, hub != praefix {
            befunde.append(.hubPraefixFalsch(hub: hub, erwartet: praefix))
        }
        if let hub, let drive = leerZuNil(driveOrdnernameLokal), drive != hub {
            befunde.append(.driveWeichtAb(hub: hub, drive: drive))
        }
        if let list = leerZuNil(clickUpListenName) {
            if let listenNummer = fuehrendeNummer(list), listenNummer != praefix {
                befunde.append(.clickUpFremdeNummer(list: list, erwartet: praefix))
            } else if let hub, list != hub {
                befunde.append(.clickUpWeichtAb(hub: hub, list: list))
            }
        }
        return befunde
    }

    public static func fuehrendeNummer(_ name: String) -> String? {
        let teile = name.split(separator: "_", maxSplits: 2, omittingEmptySubsequences: false)
        guard teile.count >= 2,
              teile[0].count == 4, teile[0].allSatisfy(\.isNumber),
              teile[1].isEmpty == false, teile[1].allSatisfy(\.isNumber) else { return nil }

        guard let lauf = Int(teile[1]) else { return nil }
        return "\(teile[0])_\(String(format: "%03d", lauf))"
    }

    private static func leerZuNil(_ value: String?) -> String? {
        guard let w = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              w.isEmpty == false else { return nil }
        return w
    }
}
