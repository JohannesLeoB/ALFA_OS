import Foundation

/// One card of the starter document: an upstream component, its demo and the page it runs in.
public struct StarterCard: Equatable, Sendable {
    /// File name without extension, as in the upstream repository. The source files are named the same way.
    public let name: String
    /// Name of the component that the page draws.
    public let render: String
    /// File name of the upstream demo in app/docs. The copy in the resources keeps the name of the component.
    /// Nil when the component is its own demo.
    public let demo: String?
    /// Runtime files beyond the shared ones, relative to source/runtime.
    public let extraRuntime: [String]

    public init(name: String, render: String, demo: String?, extraRuntime: [String]) {
        self.name = name
        self.render = render
        self.demo = demo
        self.extraRuntime = extraRuntime
    }

    /// The title on the canvas: the name with spaces, and the first letter in capitals.
    public var title: String {
        let words = name.replacing("-", with: " ")
        guard let first = words.first else { return words }
        return first.uppercased() + String(words.dropFirst())
    }
}

/// Where the cards of one room come from.
public struct StarterOrigin: Equatable, Sendable {
    /// Address of the repository on the web.
    public let repository: String
    /// Author as the licence names them.
    public let author: String
    /// The full licence text, copied from the repository.
    public let licence: String

    public init(repository: String, author: String, licence: String) {
        self.repository = repository
        self.author = author
        self.licence = licence
    }
}

/// The rooms of the starter document. Each room is a space (tab) of the board.
public enum StarterRoom: String, CaseIterable, Sendable {
    /// Motion-primitives components: motion, placement and text effects.
    case movement = "bewegung"

    /// The id of the space.
    public var spaceID: String { rawValue }

    /// The folder of the room's sources under source/.
    public var folder: String {
        switch self {
        case .movement: "motion"
        }
    }

    /// The name of the space, as the user sees it.
    public var name: String {
        switch self {
        case .movement: "Bewegung"
        }
    }
}

/// Failures while the starter document is built from the source files.
public enum StarterError: Error, Equatable {
    /// A source file is missing or cannot be read as UTF-8 text. The message names the file.
    case unreadable(String)
}
