import Foundation

public enum LinkEngine {
    private static let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
    private static let schemes: Set<String> = ["http", "https", "mailto"]

    public static func attributed(_ text: String) -> AttributedString {
        var result = AttributedString(text)
        guard let detector else { return result }
        for match in detector.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
            guard let url = match.url, schemes.contains(url.scheme?.lowercased() ?? ""),
                  let found = Range(match.range, in: text), let range = Range(found, in: result) else { continue }
            result[range].link = url
        }
        return result
    }
}
