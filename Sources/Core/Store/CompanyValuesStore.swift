import Foundation

public enum CompanyValuesStore {
    private static let values: [String: String] = load()

    public static func valueOrEmpty(_ key: String) -> String {
        values[key] ?? ""
    }

    private static func load() -> [String: String] {
        guard let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return [:] }
        let url = base.appendingPathComponent(AppIdentity.name, isDirectory: true).appendingPathComponent("company.json")
        guard FileManager.default.fileExists(atPath: url.path) else { return [:] }
        do {
            let data = try Data(contentsOf: url)
            guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [:] }
            return object.compactMapValues { $0 as? String }
        } catch {
            Log.failure("CompanyValuesUnreadable", detail: String(describing: error))
            return [:]
        }
    }
}
