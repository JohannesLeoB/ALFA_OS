import Foundation
import Shell

public enum CardRef: Hashable, Sendable {
    case message(String)
    case draft(UUID)

    public var id: String {
        switch self {
        case .message(let id): id
        case .draft(let id): id.uuidString
        }
    }
}

public enum OverviewMode: Equatable, Sendable, CaseIterable {
    case stack
    case folder
}

public struct Overview: Equatable, Sendable {
    public var open = false
    public var mode = OverviewMode.stack
    public var size = OverviewSize.medium
    public var hot: CardRef?
}

public struct StripMark: Identifiable, Equatable, Sendable {
    public enum Run: Equatable, Sendable {
        case folder(String)
        case compose
        case row(String)
        case reply(String)
        case forward(String)
        case card(CardRef)
    }

    public let id: String
    public let face: StripFace
    public let help: FolderName
    public let selected: Bool
    public let dot: Bool
    public let run: Run
}
