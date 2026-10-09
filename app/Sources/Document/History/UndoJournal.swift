import Foundation
import ALFAcolorCore

/// The last undo steps of a document, kept in the package as `history/undo.json`.
///
/// Each step holds the board as it was before the change, so that undo can go back to it after a crash or a restart.
/// At most `capacity` steps are kept, the newest ones; a file that is larger than `maximumBytes` is not read.
/// The journal travels with the document as a carried file: the package code needs no knowledge of it.
public struct UndoJournal: Equatable, Sendable {
    /// The most steps that are kept.
    public static let capacity = 20
    /// A journal file above this size is not read at all.
    public static let maximumBytes = 8 * 1024 * 1024
    /// The path inside the package.
    public static let path = "history/undo.json"
    static let formatVersion = 1

    /// One undo step: its name, when it was made, and the board before it.
    public struct Step: Codable, Equatable, Sendable {
        public var name: String
        public var at: Date
        public var board: Board

        public init(name: String, at: Date, board: Board) {
            self.name = name; self.at = at; self.board = board
        }
    }

    /// Why a journal file was not read. Nil when it was read, or when there was no file.
    public enum Problem: Equatable, Sendable {
        /// The file is not a journal of this format version.
        case unreadable
        /// The file is larger than `maximumBytes`.
        case tooLarge
    }

    /// The result of reading a journal file.
    public struct ReadResult: Equatable, Sendable {
        public var journal: UndoJournal
        /// Steps that could not be read and were left out.
        public var skipped: Int
        public var problem: Problem?
    }

    /// The steps, oldest first.
    public private(set) var steps: [Step]

    public init(steps: [Step] = []) {
        self.steps = Array(steps.suffix(Self.capacity))
    }

    /// Adds a step after the others. The oldest step falls out when there are more than `capacity`.
    public mutating func record(name: String, at date: Date, before board: Board) {
        steps.append(Step(name: name, at: date, board: board))
        if steps.count > Self.capacity {
            steps.removeFirst(steps.count - Self.capacity)
        }
    }

    // MARK: File

    /// The file bytes: a JSON object with the format version and the steps, oldest first.
    static func data(for journal: UndoJournal) throws -> Data {
        try PackageJSON.data(File(version: formatVersion, steps: journal.steps))
    }

    /// Reads the file bytes. A step that cannot be read is counted and left out; the rest is kept.
    static func read(_ data: Data) -> ReadResult {
        guard data.count <= maximumBytes else {
            return ReadResult(journal: UndoJournal(), skipped: 0, problem: .tooLarge)
        }
        guard let file = try? PackageJSON.decoder().decode(LossyFile.self, from: data), file.version == formatVersion else {
            return ReadResult(journal: UndoJournal(), skipped: 0, problem: .unreadable)
        }
        let decoded = file.steps.compactMap(\.step)
        let skipped = file.steps.count - decoded.count
        return ReadResult(journal: UndoJournal(steps: decoded), skipped: skipped, problem: nil)
    }

    /// Puts the journal into the document as a carried file. An empty journal removes the file.
    public func store(in document: inout ALFAcolorDocument) throws {
        if steps.isEmpty {
            document.carriedFiles[Self.path] = nil
        } else {
            document.carriedFiles[Self.path] = try Self.data(for: self)
        }
    }

    /// The journal of a document. A document without the file has an empty journal and no problem.
    public static func load(from document: ALFAcolorDocument) -> ReadResult {
        guard let data = document.carriedFiles[path] else {
            return ReadResult(journal: UndoJournal(), skipped: 0, problem: nil)
        }
        return read(data)
    }

    private struct File: Codable {
        var version: Int
        var steps: [Step]
    }

    /// A step that is read leniently: a broken one becomes nil instead of failing the whole file.
    private struct LossyStep: Decodable {
        let step: Step?

        init(from decoder: Decoder) throws {
            step = try? Step(from: decoder)
        }
    }

    private struct LossyFile: Decodable {
        let version: Int?
        let steps: [LossyStep]

        enum CodingKeys: String, CodingKey { case version, steps }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            version = try container.decodeIfPresent(Int.self, forKey: .version)
            steps = try container.decode([LossyStep].self, forKey: .steps)
        }
    }
}
