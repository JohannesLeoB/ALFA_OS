import Foundation

public enum WorkshopFactors {
    public static let storageKey = "estimate.workshopFactors"

    public static var current: [String: Double] {
        (UserDefaults.standard.dictionary(forKey: storageKey) as? [String: Double]) ?? [:]
    }

    public static var isConfigured: Bool {
        UserDefaults.standard.object(forKey: storageKey) != nil
    }

    public static func save(_ factors: [String: Double]) {
        UserDefaults.standard.set(factors, forKey: storageKey)
    }
}
