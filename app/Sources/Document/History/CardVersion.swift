import Foundation
import ALFAcolorCore

/// One earlier state of a code card: when it was kept, why, and its code.
/// A version holds the language and the files only. The width and the preview are not kept.
public struct CardVersion: Equatable, Sendable {
    /// Why a version was kept.
    public enum Reason: String, Codable, Sendable, CaseIterable {
        /// The lab saved a new draft to the card, so the code before it is kept.
        case lab
        /// The user kept a version by hand, or restored one, so the code before it is kept.
        case manual

        /// The catalog key of the name of the reason.
        public var nameKey: String {
            switch self {
            case .lab: "version.reason.lab"
            case .manual: "version.reason.manual"
            }
        }
    }

    public var date: Date
    public var reason: Reason
    public var language: CodeLanguage
    public var files: [String: String]

    public init(date: Date, reason: Reason, language: CodeLanguage, files: [String: String]) {
        // The package keeps milliseconds, so the date is rounded the same way here. Then a saved version reads back equal.
        self.date = Date(timeIntervalSince1970: (date.timeIntervalSince1970 * 1000).rounded() / 1000)
        self.reason = reason
        self.language = language
        self.files = files
    }

    /// The bytes of the code: file names and texts, in UTF-8.
    public var size: Int {
        files.reduce(0) { $0 + $1.key.utf8.count + $1.value.utf8.count }
    }

    /// True when both hold the same code, whatever their dates and reasons.
    public func hasSameCode(as other: CardVersion) -> Bool {
        language == other.language && files == other.files
    }
}
