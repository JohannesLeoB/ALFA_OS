import Foundation

/// The reasons why a change to the places is refused.
public enum PlaceError: Error, Equatable, Sendable {
    case unknownPlace
    case noRole
    case emptyName
    case nameTooLong
    case tooManyPlaces
}

/// The list of places, in the order the user set. Pure data: it does not touch the disk or the sandbox.
/// A place is identified by its id. Two places never have the same path: adding a known path merges the roles.
public struct PlaceRegistry: Codable, Equatable, Sendable {
    public static let maxPlaces = 64
    public static let maxNameLength = 120

    public private(set) var places: [Place]
    /// The place that is the app folder, nil when none is chosen yet.
    public private(set) var appFolderID: UUID?
    /// Top-level fields that this version does not know. They are written back unchanged.
    public var extra: [String: PlaceJSON]

    public init() {
        places = []
        appFolderID = nil
        extra = [:]
    }

    private enum CodingKeys: String, CodingKey {
        case places, appFolder
    }

    public init(from decoder: Decoder) throws {
        let known = try decoder.container(keyedBy: CodingKeys.self)
        places = Self.mergingDuplicates(try known.decode([Place].self, forKey: .places))
        appFolderID = try known.decodeIfPresent(UUID.self, forKey: .appFolder)
        extra = try UnknownFields.read(from: decoder, skipping: ["places", "appFolder"])
    }

    public func encode(to encoder: Encoder) throws {
        var known = encoder.container(keyedBy: CodingKeys.self)
        try known.encode(places, forKey: .places)
        try known.encodeIfPresent(appFolderID, forKey: .appFolder)
        try UnknownFields.write(extra, to: encoder, skipping: ["places", "appFolder"])
    }

    /// The place with this id, nil when there is none.
    public func place(_ id: UUID) -> Place? {
        places.first { $0.id == id }
    }

    /// Adds a place, or merges the roles into the place with the same path. Returns the place as it now is.
    /// A new place needs a name of 1 to 120 characters and at least one role, and the list holds at most 64 places.
    @discardableResult
    public mutating func add(name: String, kind: PlaceKind, roles: Set<PlaceRole>, path: String?,
                             bookmark: Data?, at date: Date) throws -> Place {
        let cleanName = try Self.checkedName(name)
        guard !roles.isEmpty else { throw PlaceError.noRole }
        let cleanPath = path.map(Self.standardized)
        if let cleanPath, let index = places.firstIndex(where: { $0.path == cleanPath }) {
            places[index].roles.formUnion(roles)
            places[index].bookmark = bookmark ?? places[index].bookmark
            return places[index]
        }
        guard places.count < Self.maxPlaces else { throw PlaceError.tooManyPlaces }
        let place = Place(name: cleanName, kind: kind, roles: roles, bookmark: bookmark, path: cleanPath, addedAt: date)
        places.append(place)
        return place
    }

    /// Removes a place from the list. The folder on the disk is not touched. Removing the app folder clears the choice.
    public mutating func remove(_ id: UUID) throws {
        let index = try indexOf(id)
        places.remove(at: index)
        if appFolderID == id { appFolderID = nil }
    }

    /// Makes a place the app folder. It gets the roles of storage and source library, which the app folder always has.
    public mutating func chooseAppFolder(_ id: UUID) throws {
        let index = try indexOf(id)
        places[index].roles.formUnion([.storage, .sourceLibrary])
        appFolderID = id
    }

    /// Replaces the roles of a place. An empty set is refused.
    public mutating func setRoles(_ roles: Set<PlaceRole>, for id: UUID) throws {
        guard !roles.isEmpty else { throw PlaceError.noRole }
        places[try indexOf(id)].roles = roles
    }

    /// Changes the name of a place.
    public mutating func rename(_ id: UUID, to name: String) throws {
        let index = try indexOf(id)
        places[index].name = try Self.checkedName(name)
    }

    /// Changes the kind of a place. The user may override the detected kind.
    public mutating func setKind(_ kind: PlaceKind, for id: UUID) throws {
        places[try indexOf(id)].kind = kind
    }

    /// Moves a place to a new position in the list.
    public mutating func move(_ id: UUID, to position: Int) throws {
        let index = try indexOf(id)
        guard places.indices.contains(position) else { throw PlaceError.unknownPlace }
        let place = places.remove(at: index)
        places.insert(place, at: position)
    }

    /// Gives a place a new location, for example after the user chose the folder again. The id and roles stay.
    public mutating func relocate(_ id: UUID, path: String, bookmark: Data?) throws {
        let index = try indexOf(id)
        places[index].path = Self.standardized(path)
        places[index].bookmark = bookmark
    }

    private func indexOf(_ id: UUID) throws -> Int {
        guard let index = places.firstIndex(where: { $0.id == id }) else { throw PlaceError.unknownPlace }
        return index
    }

    /// The name without the surrounding spaces. It must have 1 to 120 characters.
    private static func checkedName(_ name: String) throws -> String {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { throw PlaceError.emptyName }
        guard clean.count <= maxNameLength else { throw PlaceError.nameTooLong }
        return clean
    }

    /// The path with its trailing slash and `.` or `..` parts resolved, so that one folder has one spelling.
    private static func standardized(_ path: String) -> String {
        URL(fileURLWithPath: path).standardizedFileURL.path
    }

    /// Places with the same path become one place. The first one keeps its name and id; the roles are joined.
    private static func mergingDuplicates(_ list: [Place]) -> [Place] {
        var result: [Place] = []
        for place in list {
            if let path = place.path, let index = result.firstIndex(where: { $0.path == path }) {
                result[index].roles.formUnion(place.roles)
                result[index].bookmark = result[index].bookmark ?? place.bookmark
            } else {
                result.append(place)
            }
        }
        return result
    }
}
