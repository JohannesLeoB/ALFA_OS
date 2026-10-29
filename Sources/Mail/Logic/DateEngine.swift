import Foundation

enum DateEngine {
    private static let messagePatterns = [
        ["EEE,", "d", "MMM", "yyyy", "HH:mm:ss", "Z"], ["d", "MMM", "yyyy", "HH:mm:ss", "Z"],
        ["EEE,", "d", "MMM", "yyyy", "HH:mm", "Z"], ["d", "MMM", "yyyy", "HH:mm", "Z"]
    ]
    private static let zones = ["GMT", "UTC", "UT", "Z"]

    private static func formatter(_ pattern: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = pattern
        return formatter
    }

    static func parseMessageDate(_ text: String) -> Date? {
        var value = text
        while let open = value.firstIndex(of: "("), let close = value.lastIndex(of: ")"), open < close {
            value.removeSubrange(open...close)
        }
        value = value.trimmingCharacters(in: .whitespaces)
        for zone in zones where value.hasSuffix(" " + zone) {
            value = String(value.dropLast(zone.count)) + "+0000"
        }
        for pattern in messagePatterns {
            if let date = formatter(pattern.joined(separator: " ")).date(from: value) { return date }
        }
        return nil
    }

    static func parseInternalDate(_ text: String) -> Date? {
        formatter("d-MMM-yyyy HH:mm:ss Z").date(from: text.trimmingCharacters(in: .whitespaces))
    }

    static func formatSearchDate(_ date: Date) -> String {
        formatter("d-MMM-yyyy").string(from: date)
    }

    static func formatMessageDate(_ date: Date) -> String {
        formatter(["EEE,", "dd", "MMM", "yyyy", "HH:mm:ss", "Z"].joined(separator: " ")).string(from: date)
    }
}
