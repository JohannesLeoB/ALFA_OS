import Foundation

public enum MailNames {
    private static let particles: Set<String> = ["ii", "iii", "iv", "jr", "jr.", "sr", "sr.", "de", "la", "del", "y", "von", "van", "der", "den", "da", "di", "du"]

    public static func initials(_ name: String) -> String {
        let words = name.trimmingCharacters(in: .whitespacesAndNewlines)
            .split(whereSeparator: { $0.isWhitespace })
            .map(String.init)
            .filter { word in word.contains(where: \.isLetter) && !particles.contains(word.lowercased()) }
        guard let first = words.first, let last = words.last else { return "" }
        func head(_ word: String) -> String {
            let trimmed = word.drop(while: { !$0.isLetter })
            return trimmed.first.map { String($0).uppercased() } ?? ""
        }
        return words.count == 1 ? head(first) : head(first) + head(last)
    }

    public static func middle(_ text: String, limit: Int) -> String {
        let letters = Array(text)
        guard letters.count > limit else { return text }
        let head = Int((Double(limit - 1) * 0.55).rounded(.up))
        let tail = limit - 1 - head
        return String(letters.prefix(head)) + "…" + String(letters.suffix(tail))
    }

    public static func display(_ raw: String) -> (name: String, address: String) {
        let entry = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let open = entry.lastIndex(of: "<"), let close = entry.lastIndex(of: ">"), open < close else {
            return ("", entry)
        }
        var name = entry[entry.startIndex..<open].trimmingCharacters(in: .whitespaces)
        if name.hasPrefix("\""), name.hasSuffix("\""), name.count >= 2 { name = String(name.dropFirst().dropLast()) }
        return (name, String(entry[entry.index(after: open)..<close]))
    }

    public static func number(_ value: Int) -> String {
        value.formatted(.number.locale(Locale(identifier: "de_DE")))
    }
}
