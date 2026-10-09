import Foundation
import Observation
import ALFAcolorCore
import BoardModel

/// Runs pastes and drops for one window: reads the sources, puts the pieces on the board in one undo step,
/// and keeps what the user must be told or asked.
@MainActor
@Observable
public final class ImportCoordinator {
    /// Files above the size limit that wait for the user's answer.
    public struct Question: Equatable, Sendable {
        public var files: [LargeFile]
        public var entry: ImportEntry
        public var centerX: Double
        public var centerY: Double
    }

    public let store: BoardStore
    /// The height of the header band of a card. The view sets it from the theme.
    public var headerHeight: Double = 0
    public private(set) var question: Question?
    /// Files that were not taken. The view shows them once and then calls `acknowledge()`.
    public private(set) var skipped: [SkippedFile] = []
    /// The error of the last insert, nil after a good one.
    public private(set) var failure: (any Error)?

    public init(store: BoardStore) { self.store = store }

    /// Imports the sources around a point of the board.
    public func handle(_ sources: [ImportSource], entry: ImportEntry, centerX: Double, centerY: Double,
                       allowLarge: Set<URL> = []) async {
        let outcome = await Importer.read(sources, entry: entry, allowLarge: allowLarge)
        place(outcome, entry: entry, centerX: centerX, centerY: centerY)
    }

    /// Imports what the system gives for a paste or a drop.
    public func handle(_ providers: [NSItemProvider], entry: ImportEntry, centerX: Double, centerY: Double) async {
        let sources = await ProviderReader.sources(from: providers)
        await handle(sources, entry: entry, centerX: centerX, centerY: centerY)
    }

    /// The user agreed to take the large files. The question is taken at once, so that a dismissed alert cannot undo the answer.
    /// The import runs in the returned task.
    @discardableResult
    public func confirmLarge() -> Task<Void, Never>? {
        guard let question else { return nil }
        self.question = nil
        let files = question.files.map { $0.url }
        return Task {
            await handle(files.map { .file($0) }, entry: question.entry,
                         centerX: question.centerX, centerY: question.centerY, allowLarge: Set(files))
        }
    }

    public func declineLarge() { question = nil }

    /// The user has read which files were not taken.
    public func acknowledge() { skipped = [] }

    /// The user has read the error of the last insert.
    public func dismissFailure() { failure = nil }

    private func place(_ outcome: ImportOutcome, entry: ImportEntry, centerX: Double, centerY: Double) {
        skipped += outcome.skipped
        if !outcome.large.isEmpty {
            question = Question(files: outcome.large, entry: entry, centerX: centerX, centerY: centerY)
        }
        guard !outcome.pieces.isEmpty else { return }
        do {
            try BoardImporter(store: store).insert(outcome.pieces, centerX: centerX, centerY: centerY,
                                                   headerHeight: headerHeight, nameKey: entry.undoKey)
            failure = nil
        } catch {
            failure = error
        }
    }
}

extension ImportEntry {
    /// The key of the name of the undo step in the string catalog.
    var undoKey: String { self == .paste ? "undo.paste" : "undo.drop" }

    /// Both keys, for the check against the string catalog.
    public static let undoKeys = ["undo.paste", "undo.drop"]
}
