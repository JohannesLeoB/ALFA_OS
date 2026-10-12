import Foundation

public enum NachfassAlertPreferences {
    private static let enabledKey = "nachfass.global"
    private static let schwelleKey = "nachfass.schwelle.tage"

    public static var isActive: Bool {
        get { UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: enabledKey) }
    }

    public static var schwelleInTagen: Int {
        get {
            let stored = UserDefaults.standard.object(forKey: schwelleKey) as? Int
            return stored ?? 14
        }
        set { UserDefaults.standard.set(newValue, forKey: schwelleKey) }
    }
}

public enum NachfassAlertComputer {
    public static func istFaellig(
        _ offer: AllOffersCollector.AggregatedOffer, schwelleInTagen: Int, now: Date = Date()
    ) -> Bool {
        guard offer.direction == .outgoing, schwelleInTagen > 0 else { return false }
        guard let modifiedAt = offer.offer.file.modifiedAt else { return false }
        let tageSeitAenderung = Calendar.current.dateComponents([.day], from: modifiedAt, to: now).day ?? 0
        return tageSeitAenderung >= schwelleInTagen
    }

    public static func tageSeitAenderung(_ offer: AllOffersCollector.AggregatedOffer, now: Date = Date()) -> Int? {
        guard let modifiedAt = offer.offer.file.modifiedAt else { return nil }
        return Calendar.current.dateComponents([.day], from: modifiedAt, to: now).day
    }
}

public enum BitteReagierenAlertPreferences {
    private static let enabledKey = "bittereagieren.global"
    private static let schwelleKey = "bittereagieren.schwelle.tage"

    public static var isActive: Bool {
        get { UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: enabledKey) }
    }

    public static var schwelleInTagen: Int {
        get {
            let stored = UserDefaults.standard.object(forKey: schwelleKey) as? Int
            return stored ?? 14
        }
        set { UserDefaults.standard.set(newValue, forKey: schwelleKey) }
    }
}

public enum BitteReagierenAlertComputer {
    public static func istFaellig(
        _ offer: AllOffersCollector.AggregatedOffer, schwelleInTagen: Int, now: Date = Date()
    ) -> Bool {
        guard offer.direction == .incoming, schwelleInTagen > 0 else { return false }
        guard let modifiedAt = offer.offer.file.modifiedAt else { return false }
        let tageSeitEingang = Calendar.current.dateComponents([.day], from: modifiedAt, to: now).day ?? 0
        return tageSeitEingang >= schwelleInTagen
    }
}
