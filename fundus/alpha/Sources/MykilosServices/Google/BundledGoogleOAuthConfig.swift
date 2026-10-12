import Foundation

public enum BundledGoogleOAuthConfig {
    private static let clientIDKey = "MykGoogleClientID"
    private static let clientSecretKey = "MykGoogleClientSecret"

    public static var clientID: String? { value(fuerKey: clientIDKey) }
    public static var clientSecret: String? { value(fuerKey: clientSecretKey) }

    public static var istVerfuegbar: Bool { clientID != nil }

    static func value(fuerKey key: String, aus dict: [String: Any]? = Bundle.main.infoDictionary) -> String? {
        guard let roh = dict?[key] as? String else { return nil }
        let getrimmt = roh.trimmingCharacters(in: .whitespacesAndNewlines)
        return getrimmt.isEmpty ? nil : getrimmt
    }
}
