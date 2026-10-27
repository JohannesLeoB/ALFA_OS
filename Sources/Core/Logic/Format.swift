import Foundation

public enum Format {
    public static func number(_ value: Int) -> String {
        value.formatted(.number.locale(Locale(identifier: "de_DE")))
    }

    public static func bytes(_ count: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.zeroPadsFractionDigits = false
        return formatter.string(fromByteCount: Int64(count))
    }
}
