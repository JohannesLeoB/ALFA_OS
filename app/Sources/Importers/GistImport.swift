import Foundation
import ALFAcolorCore

/// Why a gist response could not be read.
public enum GistError: Error, Equatable, Sendable {
    /// The data is not a gist response, for example not JSON.
    case notReadable
}

/// A file of a gist that is not taken, and why.
public struct GistSkippedFile: Equatable, Sendable {
    public enum Reason: String, Equatable, Sendable {
        /// GitHub cut the content short; the full file is fetched from its raw address later.
        case truncated
        /// The file is larger than the limit.
        case tooLarge
        /// The gist has more files than the limit.
        case tooMany
        /// The response has no content for the file.
        case noContent
    }

    public var name: String
    public var reason: Reason

    public init(name: String, reason: Reason) {
        self.name = name
        self.reason = reason
    }
}

/// What a gist response gives: one piece with the taken files as tabs, and the files that were left out.
public struct GistResult: Equatable, Sendable {
    public var pieces: [Piece]
    public var skippedFiles: [GistSkippedFile]

    public init(pieces: [Piece], skippedFiles: [GistSkippedFile]) {
        self.pieces = pieces
        self.skippedFiles = skippedFiles
    }
}

/// Reads a public gist from the GitHub API. Nothing here fetches from the network.
public enum GistImport {
    /// The most files that one gist piece takes.
    public static let maxFiles = 50
    /// The largest file, in bytes, that is taken.
    public static let maxFileBytes = 512 * 1024

    /// The piece for the response of `GET /gists/<id>`. The first file in name order gives the language.
    public static func pieces(fromAPIResponse data: Data, now: Date) throws -> GistResult {
        let response: Response
        do {
            response = try JSONDecoder().decode(Response.self, from: data)
        } catch {
            throw GistError.notReadable
        }
        var files: [String: String] = [:]
        var skipped: [GistSkippedFile] = []
        var firstName: String?
        for (name, file) in (response.files ?? [:]).sorted(by: { $0.key < $1.key }) {
            guard files.count < maxFiles else {
                skipped.append(GistSkippedFile(name: name, reason: .tooMany))
                continue
            }
            guard file.truncated != true else {
                skipped.append(GistSkippedFile(name: name, reason: .truncated))
                continue
            }
            guard let content = file.content else {
                skipped.append(GistSkippedFile(name: name, reason: .noContent))
                continue
            }
            guard (file.size ?? content.utf8.count) <= maxFileBytes else {
                skipped.append(GistSkippedFile(name: name, reason: .tooLarge))
                continue
            }
            files[name] = content
            if firstName == nil { firstName = name }
        }
        guard let first = firstName else {
            return GistResult(pieces: [], skippedFiles: skipped)
        }
        let description = (response.description ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let source = Source(url: response.htmlURL.flatMap { URL(string: $0) }, license: nil, via: "gist", importedAt: now)
        let content = Content.code(language: language(forFileNamed: first), files: files, previewWidth: nil)
        let piece = Piece(title: description.isEmpty ? first : description, body: .content(content), source: source)
        return GistResult(pieces: [piece], skippedFiles: skipped)
    }

    /// The language of a file, by its extension. Files that are not code have the language `other`.
    private static func language(forFileNamed name: String) -> CodeLanguage {
        let fileExtension = URL(fileURLWithPath: name).pathExtension
        if case .code(let language)? = FileKind.kind(forExtension: fileExtension) {
            return language
        }
        return .other
    }

    /// The gist ID of `https://gist.github.com/<user>/<id>` or `gist.github.com/<id>`, or nil for any other text.
    /// An ID is 20 to 40 hexadecimal characters.
    public static func id(from text: String) -> String? {
        var value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        for scheme in ["https://", "http://"] where value.lowercased().hasPrefix(scheme) {
            value = String(value.dropFirst(scheme.count))
            break
        }
        let host = "gist.github.com/"
        guard value.lowercased().hasPrefix(host) else { return nil }
        let parts = value.dropFirst(host.count).split(separator: "/", omittingEmptySubsequences: false)
        let candidate: Substring
        switch parts.count {
        case 1:
            candidate = parts[0]
        case 2 where isUserName(parts[0]):
            candidate = parts[1]
        default:
            return nil
        }
        guard (20...40).contains(candidate.count), candidate.allSatisfy(\.isHexDigit) else { return nil }
        return String(candidate)
    }

    private static func isUserName(_ text: Substring) -> Bool {
        !text.isEmpty && text.count <= 39 && text.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-") }
    }

    private struct Response: Decodable {
        let description: String?
        let htmlURL: String?
        let files: [String: File]?

        enum CodingKeys: String, CodingKey {
            case description
            case htmlURL = "html_url"
            case files
        }
    }

    private struct File: Decodable {
        let content: String?
        let truncated: Bool?
        let size: Int?
    }
}
