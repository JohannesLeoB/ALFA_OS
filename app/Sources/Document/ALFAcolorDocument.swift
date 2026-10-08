import Foundation
import ALFAcolorCore
import Tokens

/// A document in memory: the board with spaces, layers and items, the images, the token sets,
/// and everything this version does not understand but must not lose.
///
/// On disk it is a folder package. See `DocumentPackage`.
public struct ALFAcolorDocument: Equatable, Sendable {
    public var board: Board
    public var assets: AssetStore
    public var tokenSets: [TokenSet]
    /// Files in the package that the package does not manage itself: `history/`, `inbox/`, additions from later versions.
    /// Relative path (with "/") to bytes. They are written back unchanged.
    public var carriedFiles: PackageFiles = [:]
    /// Fields this version does not know (manifest, space, layer, item, token file).
    var preserved = PreservedFields()

    public init(board: Board = Board(title: String(localized: "document.untitled")), assets: AssetStore = AssetStore(), tokenSets: [TokenSet] = []) {
        self.board = board
        self.assets = assets
        self.tokenSets = tokenSets
    }

    /// Images that an item refers to and that are missing from the document.
    public func missingAssets() -> [ReadReport.MissingAsset] {
        var out: [ReadReport.MissingAsset] = []
        for space in board.spaces {
            for item in space.items {
                if case .image(let assetID, _) = item.content, assets[assetID] == nil {
                    out.append(.init(assetID: assetID, itemID: item.id, spaceID: space.id))
                }
            }
        }
        return out
    }
}

struct LayerKey: Hashable, Sendable {
    var space: String
    var layer: String
}

/// Unknown JSON fields per file. The key is the ID, not the path, so renaming and moving change nothing.
struct PreservedFields: Equatable, Sendable {
    var manifest: [String: JSONValue] = [:]
    var spaces: [String: [String: JSONValue]] = [:]
    var layers: [LayerKey: [String: JSONValue]] = [:]
    var items: [ItemID: [String: JSONValue]] = [:]
    /// Token set name to the part of the DTCG file that `TokenSet` cannot represent.
    var tokenFiles: [String: [String: JSONValue]] = [:]
}

// MARK: - File contents

/// An item with its unknown fields. `Item` writes the known fields, `extras` the rest.
struct ItemEnvelope: Codable {
    var item: Item
    var extras: [String: JSONValue]

    static let knownKeys: Set<String> = ["id", "title", "content", "rect", "z", "layerID", "locked", "hidden", "tags", "source"]

    init(_ item: Item, extras: [String: JSONValue] = [:]) { self.item = item; self.extras = extras }
    init(from decoder: Decoder) throws {
        item = try Item(from: decoder)
        extras = try Extras.decode(from: decoder, known: Self.knownKeys)
    }
    func encode(to encoder: Encoder) throws {
        try item.encode(to: encoder)
        try Extras.encode(extras, known: Self.knownKeys, to: encoder)
    }
}

/// manifest.json
struct ManifestFile: Codable {
    var formatVersion: Int
    var lastWrittenByAppVersion: String?
    var documentID: UUID
    var createdAt: Date
    var title: String
    /// Order of the spaces (tabs).
    var spaces: [String]
    /// Order of the token sets.
    var tokenSets: [String]
    var extras: [String: JSONValue] = [:]

    enum K: String, CodingKey, CaseIterable { case formatVersion, lastWrittenByAppVersion, documentID, createdAt, title, spaces, tokenSets }
    static let known = Set(K.allCases.map(\.rawValue))

    init(formatVersion: Int, lastWrittenByAppVersion: String?, documentID: UUID, createdAt: Date, title: String,
         spaces: [String], tokenSets: [String], extras: [String: JSONValue]) {
        self.formatVersion = formatVersion; self.lastWrittenByAppVersion = lastWrittenByAppVersion
        self.documentID = documentID; self.createdAt = createdAt; self.title = title
        self.spaces = spaces; self.tokenSets = tokenSets; self.extras = extras
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: K.self)
        formatVersion = try c.decode(Int.self, forKey: .formatVersion)
        lastWrittenByAppVersion = try c.decodeIfPresent(String.self, forKey: .lastWrittenByAppVersion)
        documentID = try c.decode(UUID.self, forKey: .documentID)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        title = try c.decode(String.self, forKey: .title)
        spaces = try c.decodeIfPresent([String].self, forKey: .spaces) ?? []
        tokenSets = try c.decodeIfPresent([String].self, forKey: .tokenSets) ?? []
        extras = try Extras.decode(from: decoder, known: Self.known)
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: K.self)
        try c.encode(formatVersion, forKey: .formatVersion)
        try c.encodeIfPresent(lastWrittenByAppVersion, forKey: .lastWrittenByAppVersion)
        try c.encode(documentID, forKey: .documentID)
        try c.encode(createdAt, forKey: .createdAt)
        try c.encode(title, forKey: .title)
        try c.encode(spaces, forKey: .spaces)
        try c.encode(tokenSets, forKey: .tokenSets)
        try Extras.encode(extras, known: Self.known, to: encoder)
    }
}

/// spaces/<space>/space.json
struct SpaceFile: Codable {
    var schema: Int
    var id: String
    var name: String
    /// Layer IDs from bottom to top.
    var layers: [String]
    /// Set only when the items of a space are not ordered by layer in memory. For each item, the position of its layer in `layers`.
    /// This keeps the order of `Space.items` without the layer files knowing about it.
    var layerSequence: [Int]?
    var extras: [String: JSONValue] = [:]

    enum K: String, CodingKey, CaseIterable { case schema, id, name, layers, layerSequence }
    static let known = Set(K.allCases.map(\.rawValue))

    init(schema: Int, id: String, name: String, layers: [String], layerSequence: [Int]?, extras: [String: JSONValue]) {
        self.schema = schema; self.id = id; self.name = name; self.layers = layers; self.layerSequence = layerSequence; self.extras = extras
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: K.self)
        schema = try c.decodeIfPresent(Int.self, forKey: .schema) ?? 1
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        layers = try c.decodeIfPresent([String].self, forKey: .layers) ?? []
        layerSequence = try c.decodeIfPresent([Int].self, forKey: .layerSequence)
        extras = try Extras.decode(from: decoder, known: Self.known)
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: K.self)
        try c.encode(schema, forKey: .schema)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(layers, forKey: .layers)
        try c.encodeIfPresent(layerSequence, forKey: .layerSequence)
        try Extras.encode(extras, known: Self.known, to: encoder)
    }
}

/// spaces/<space>/layers/<layer>.json
struct LayerFile: Codable {
    var schema: Int
    var id: String
    var name: String
    var visible: Bool
    var locked: Bool
    var items: [ItemEnvelope]
    var extras: [String: JSONValue] = [:]

    enum K: String, CodingKey, CaseIterable { case schema, id, name, visible, locked, items }
    static let known = Set(K.allCases.map(\.rawValue))

    init(schema: Int, layer: Layer, items: [ItemEnvelope], extras: [String: JSONValue]) {
        self.schema = schema; id = layer.id; name = layer.name; visible = layer.visible; locked = layer.locked
        self.items = items; self.extras = extras
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: K.self)
        schema = try c.decodeIfPresent(Int.self, forKey: .schema) ?? 1
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        visible = try c.decodeIfPresent(Bool.self, forKey: .visible) ?? true
        locked = try c.decodeIfPresent(Bool.self, forKey: .locked) ?? false
        items = try c.decodeIfPresent([ItemEnvelope].self, forKey: .items) ?? []
        extras = try Extras.decode(from: decoder, known: Self.known)
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: K.self)
        try c.encode(schema, forKey: .schema)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(visible, forKey: .visible)
        try c.encode(locked, forKey: .locked)
        try c.encode(items, forKey: .items)
        try Extras.encode(extras, known: Self.known, to: encoder)
    }
    var layer: Layer {
        var l = Layer(id: id, name: name)
        l.visible = visible; l.locked = locked
        return l
    }
}
