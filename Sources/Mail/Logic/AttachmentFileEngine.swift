import CryptoKit
import Foundation

enum AttachmentFileEngine {
    static let nameLimit = 96
    static let extensionLimit = 16
    static let digestBytes = 8
    static let fallbackName = "attachment"
    private static let forbidden = CharacterSet(charactersIn: "/:\\").union(.controlCharacters)

    static func total(_ files: [StoredAttachment]) -> Int {
        files.reduce(0) { $0 + $1.size }
    }

    static func oldestFirst(_ files: [StoredAttachment]) -> [StoredAttachment] {
        files.sorted { left, right in
            if left.age != right.age { return left.age < right.age }
            if left.storedAt != right.storedAt { return left.storedAt < right.storedAt }
            return left.identity < right.identity
        }
    }

    static func evictions(_ files: [StoredAttachment], limit: Int?) -> [StoredAttachment] {
        guard let limit else { return [] }
        var remaining = total(files)
        var gone: [StoredAttachment] = []
        for file in oldestFirst(files) where remaining > limit {
            gone.append(file)
            remaining -= file.size
        }
        return gone
    }

    static func admits(_ incoming: StoredAttachment, among files: [StoredAttachment], limit: Int?) -> Bool {
        let others = files.filter { $0.identity != incoming.identity }
        return !evictions(others + [incoming], limit: limit).contains { $0.identity == incoming.identity }
    }

    static func relativePath(inlet: String, message: String, attachment: String, filename: String) -> String {
        [digest(inlet), digest(message), digest(attachment), safeName(filename)].joined(separator: "/")
    }

    static func inletDirectory(_ inlet: String) -> String {
        digest(inlet)
    }

    static func digest(_ text: String) -> String {
        SHA256.hash(data: Data(text.utf8)).prefix(digestBytes).map { String(format: "%02x", $0) }.joined()
    }

    static func safeName(_ name: String) -> String {
        let replaced = String(String.UnicodeScalarView(name.unicodeScalars.map { forbidden.contains($0) ? "_" : $0 }))
        var cleaned = replaced.trimmingCharacters(in: .whitespacesAndNewlines)
        while cleaned.hasPrefix(".") { cleaned.removeFirst() }
        if cleaned.isEmpty { return fallbackName }
        guard cleaned.utf8.count > nameLimit else { return cleaned }
        let suffix = (cleaned as NSString).pathExtension
        let tail = suffix.isEmpty || suffix.utf8.count > extensionLimit ? "" : "." + suffix
        var stem = String(cleaned.dropLast(tail.count))
        while !stem.isEmpty, stem.utf8.count + tail.utf8.count > nameLimit { stem.removeLast() }
        return stem.isEmpty ? fallbackName + tail : stem + tail
    }
}
