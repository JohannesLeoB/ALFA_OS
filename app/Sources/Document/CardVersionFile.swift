import Foundation
import ALFAcolorCore

/// The file `history/<item>.jsonl`: one version per line, oldest first. Each line is one JSON object,
/// so an editor or a diff shows one version per line, and a broken line costs only that version.
enum CardVersionFile {
    /// A line as the file keeps it.
    private struct Line: Codable {
        var at: Date
        var reason: CardVersion.Reason
        var language: CodeLanguage
        var files: [String: String]
    }

    /// The versions as lines, each ended by LF.
    static func data(for versions: [CardVersion]) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .custom { date, encoder in
            guard let text = ISODate.string(from: date) else {
                throw EncodingError.invalidValue(date, .init(codingPath: encoder.codingPath, debugDescription: String(localized: "package.reason.dateOutOfRange")))
            }
            var container = encoder.singleValueContainer()
            try container.encode(text)
        }
        var out = Data()
        for version in versions {
            let line = Line(at: version.date, reason: version.reason, language: version.language, files: version.files)
            out += try encoder.encode(line)
            out.append(UInt8(ascii: "\n"))
        }
        return out
    }

    /// The versions of a file, oldest first. A line that cannot be read is counted in `skipped` and left out.
    /// Empty lines are not lines and are not counted.
    static func read(_ data: Data) -> (versions: [CardVersion], skipped: Int) {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let text = try container.decode(String.self)
            guard let date = ISODate.date(from: text) else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: String(localized: "package.reason.notISODate \(text)"))
            }
            return date
        }
        var versions: [CardVersion] = []
        var skipped = 0
        for line in data.split(separator: UInt8(ascii: "\n")) {
            guard let decoded = try? decoder.decode(Line.self, from: Data(line)) else {
                skipped += 1
                continue
            }
            versions.append(CardVersion(date: decoded.at, reason: decoded.reason, language: decoded.language, files: decoded.files))
        }
        return (versions, skipped)
    }
}
