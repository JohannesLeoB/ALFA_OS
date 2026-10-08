import Foundation
import ALFAcolorCore
import Tokens

/// Ein Dokument im Speicher: das Brett mit Räumen, Ebenen und Stücken, die Bilder, die Tokensätze
/// und alles, was dieses Programm nicht versteht, aber nicht verlieren darf.
///
/// Auf der Platte ist es ein Ordnerpaket, siehe `DocumentPackage`.
public struct ALFAcolorDocument: Equatable, Sendable {
    public var board: Board
    public var assets: AssetStore
    public var tokenSets: [TokenSet]
    /// Dateien im Paket, die das Paket selbst nicht verwaltet: `history/`, `inbox/`, Neues aus späteren Fassungen.
    /// Pfad (relativ, mit "/") -> Bytes. Sie werden unverändert wieder geschrieben.
    public var carriedFiles: PackageFiles = [:]
    /// Felder, die diese Fassung nicht kennt (Manifest, Raum, Ebene, Stück, Tokendatei).
    var preserved = PreservedFields()

    public init(board: Board = Board(title: "Unbenannt"), assets: AssetStore = AssetStore(), tokenSets: [TokenSet] = []) {
        self.board = board
        self.assets = assets
        self.tokenSets = tokenSets
    }

    /// Bilder, auf die ein Stück verweist und die im Dokument fehlen.
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

/// Unbekannte JSON-Felder je Datei. Der Schlüssel ist die ID, nicht der Pfad: Umbenennen und Verschieben ändern nichts.
struct PreservedFields: Equatable, Sendable {
    var manifest: [String: JSONValue] = [:]
    var spaces: [String: [String: JSONValue]] = [:]
    var layers: [LayerKey: [String: JSONValue]] = [:]
    var items: [ItemID: [String: JSONValue]] = [:]
    /// Tokensatz (Name) -> der Teil der DTCG-Datei, den die App nicht in `TokenSet` abbilden kann.
    var tokenFiles: [String: [String: JSONValue]] = [:]
}

// MARK: - Dateiinhalte

/// Ein Stück samt seinen unbekannten Feldern. Bekannte Felder schreibt `Item`, die übrigen `extras`.
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
    var title: String
    /// Reihenfolge der Räume (Reiter).
    var spaces: [String]
    /// Reihenfolge der Tokensätze.
    var tokenSets: [String]
    var extras: [String: JSONValue] = [:]

    enum K: String, CodingKey, CaseIterable { case formatVersion, lastWrittenByAppVersion, title, spaces, tokenSets }
    static let known = Set(K.allCases.map(\.rawValue))

    init(formatVersion: Int, lastWrittenByAppVersion: String?, title: String, spaces: [String], tokenSets: [String], extras: [String: JSONValue]) {
        self.formatVersion = formatVersion; self.lastWrittenByAppVersion = lastWrittenByAppVersion; self.title = title
        self.spaces = spaces; self.tokenSets = tokenSets; self.extras = extras
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: K.self)
        formatVersion = try c.decode(Int.self, forKey: .formatVersion)
        lastWrittenByAppVersion = try c.decodeIfPresent(String.self, forKey: .lastWrittenByAppVersion)
        title = try c.decode(String.self, forKey: .title)
        spaces = try c.decodeIfPresent([String].self, forKey: .spaces) ?? []
        tokenSets = try c.decodeIfPresent([String].self, forKey: .tokenSets) ?? []
        extras = try Extras.decode(from: decoder, known: Self.known)
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: K.self)
        try c.encode(formatVersion, forKey: .formatVersion)
        try c.encodeIfPresent(lastWrittenByAppVersion, forKey: .lastWrittenByAppVersion)
        try c.encode(title, forKey: .title)
        try c.encode(spaces, forKey: .spaces)
        try c.encode(tokenSets, forKey: .tokenSets)
        try Extras.encode(extras, known: Self.known, to: encoder)
    }
}

/// spaces/<raum>/space.json
struct SpaceFile: Codable {
    var schema: Int
    var id: String
    var name: String
    /// Ebenen-IDs von unten nach oben.
    var layers: [String]
    /// Nur wenn die Stücke des Raums nicht nach Ebenen geordnet im Speicher liegen: je Stück die Position seiner Ebene in `layers`.
    /// So bleibt die Reihenfolge von `Space.items` erhalten, ohne dass die Ebenendateien davon wissen.
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

/// spaces/<raum>/layers/<ebene>.json
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
