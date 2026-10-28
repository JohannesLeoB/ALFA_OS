enum TileGroup: String, CaseIterable {
    case integrations
    case keys

    var key: String {
        switch self {
        case .integrations: "settings.tiles.integrations"
        case .keys: "settings.tiles.keys"
        }
    }
}
