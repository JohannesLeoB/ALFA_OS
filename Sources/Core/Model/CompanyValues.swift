import Foundation

public enum CompanyValues {
    private static let values: [String: String] = load()

    public static func valueOrEmpty(_ key: String) -> String {
        values[key] ?? ""
    }

    private static func load() -> [String: String] {
        guard let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return [:] }
        let url = base.appendingPathComponent(AppIdentity.name, isDirectory: true).appendingPathComponent("company.json")
        guard let data = try? Data(contentsOf: url),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [:] }
        return object.compactMapValues { $0 as? String }
    }
}

public enum AppIdentity {
    public static let name = "ALFA_OS"
    static let bundleID = "com.johannesleoberger.alfaos"
    public static let keychainPrefix = "\(bundleID)."
}
