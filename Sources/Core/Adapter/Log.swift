import os

public enum Log {
    public static let subsystem = AppIdentity.bundleID

    public static let lifecycle = Logger(subsystem: subsystem, category: "lifecycle")

    private static let failures = Logger(subsystem: subsystem, category: "failure")

    public static func failure(_ key: String, detail: String?) {
        failures.error("\(key, privacy: .public) \(detail ?? "", privacy: .private)")
    }
}
