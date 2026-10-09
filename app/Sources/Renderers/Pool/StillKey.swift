import CryptoKit
import Foundation

/// The cache key of a still image: a SHA-256 digest of the card content and the width.
public enum StillKey {
    /// Raise this when the drawing changes, so that old stills are not served.
    public static let version = 1

    private struct Input: Encodable {
        let version: Int
        let language: String
        let files: [String: String]
        let width: Double
    }

    /// The same content and width give the same key, whatever the order of the files.
    public static func make(card: CodeCard, width: Double) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let input = Input(version: version, language: card.language.rawValue, files: card.files, width: width)
        let data = (try? encoder.encode(input)) ?? Data()
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
