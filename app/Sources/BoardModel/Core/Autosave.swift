import Foundation
import Document

/// How and when the store saves the document by itself.
public struct Autosave: Sendable {
    /// Quiet time after the last change before the document is saved.
    public static let defaultDelay: Duration = .seconds(2)

    public var delay: Duration
    /// Writes the document. Runs off the main actor.
    public var save: @Sendable (ALFAcolorDocument) async throws -> Void
    /// Waits for the delay. Tests replace it with a clock they control.
    public var sleep: @Sendable (Duration) async throws -> Void

    public init(delay: Duration = Autosave.defaultDelay,
                sleep: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) },
                save: @escaping @Sendable (ALFAcolorDocument) async throws -> Void) {
        self.delay = delay; self.sleep = sleep; self.save = save
    }

    /// Saves into a document package.
    public static func package(at url: URL, appVersion: String, delay: Duration = Autosave.defaultDelay) -> Autosave {
        Autosave(delay: delay) { document in
            try DocumentPackage.write(document, to: url, appVersion: appVersion)
        }
    }
}
