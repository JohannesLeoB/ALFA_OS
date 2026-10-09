import Foundation

/// A place the user chose: a folder, a drive or a repository, with the roles it plays.
/// The bookmark lets the app open the place again in the sandbox. The path is for display only.
public struct Place: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var kind: PlaceKind
    public var roles: Set<PlaceRole>
    /// The security-scoped bookmark. nil for a place inside the app's own container.
    public var bookmark: Data?
    /// The path, for display only. The app never opens a place by this path.
    public var path: String?
    public var addedAt: Date
    /// Fields that this version does not know. They are written back unchanged.
    public var extra: [String: PlaceJSON]

    public init(id: UUID = UUID(), name: String, kind: PlaceKind, roles: Set<PlaceRole>,
                bookmark: Data? = nil, path: String? = nil, addedAt: Date = .now, extra: [String: PlaceJSON] = [:]) {
        self.id = id
        self.name = name
        self.kind = kind
        self.roles = roles
        self.bookmark = bookmark
        self.path = path
        self.addedAt = addedAt
        self.extra = extra
    }

    /// The names of the declared fields in the file.
    static let declaredFields: Set<String> = ["id", "name", "kind", "roles", "bookmark", "path", "addedAt"]

    private enum CodingKeys: String, CodingKey {
        case id, name, kind, roles, bookmark, path, addedAt
    }

    public init(from decoder: Decoder) throws {
        let known = try decoder.container(keyedBy: CodingKeys.self)
        id = try known.decode(UUID.self, forKey: .id)
        name = try known.decode(String.self, forKey: .name)
        kind = try known.decode(PlaceKind.self, forKey: .kind)
        roles = try known.decode(Set<PlaceRole>.self, forKey: .roles)
        bookmark = try known.decodeIfPresent(Data.self, forKey: .bookmark)
        path = try known.decodeIfPresent(String.self, forKey: .path)
        addedAt = try known.decode(Date.self, forKey: .addedAt)
        extra = try UnknownFields.read(from: decoder, skipping: Self.declaredFields)
    }

    public func encode(to encoder: Encoder) throws {
        var known = encoder.container(keyedBy: CodingKeys.self)
        try known.encode(id, forKey: .id)
        try known.encode(name, forKey: .name)
        try known.encode(kind, forKey: .kind)
        try known.encode(roles.sorted { $0.rawValue < $1.rawValue }, forKey: .roles)
        try known.encodeIfPresent(bookmark, forKey: .bookmark)
        try known.encodeIfPresent(path, forKey: .path)
        try known.encode(addedAt, forKey: .addedAt)
        try UnknownFields.write(extra, to: encoder, skipping: Self.declaredFields)
    }
}

/// What a place is used for. A place may have several roles, and a place has at least one.
public enum PlaceRole: String, Codable, CaseIterable, Sendable {
    /// A project folder, added by the user.
    case projectFolder
    /// The folder where documents lie and open.
    case workFolder
    /// Storage or backup.
    case storage
    /// A source or library.
    case sourceLibrary
    /// The target for downloads and exports.
    case exportTarget

    /// The roles a newly added place gets; the user may change them later.
    public static let defaultsForNewPlace: Set<PlaceRole> = [.projectFolder, .workFolder]
}

/// The kind of a place. The app detects it when a place is added; the user may change it.
public enum PlaceKind: String, Codable, CaseIterable, Sendable {
    case folder
    case drive
    case repo

    /// The kind of a location. A folder with a git entry is a repository. A location outside the user folder,
    /// and a location in iCloud Drive, is a drive. Everything else is a folder.
    public static func detect(path: String, home: String, containsGitEntry: Bool) -> PlaceKind {
        if containsGitEntry { return .repo }
        if path.contains("/Library/Mobile Documents/") { return .drive }
        let inHome = path == home || path.hasPrefix(home + "/")
        return inHome ? .folder : .drive
    }
}
