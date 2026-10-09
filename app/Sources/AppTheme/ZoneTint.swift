import Tokens

/// The seven zone colours and the ink of their titles. The table is the zone rule of the design contract.
public enum ZoneTint {
    /// The zone colours in the order of the inspector.
    public static let all: [ColorToken] = [.zoneStone, .zonePlum, .zoneNight, .zoneApricot, .zoneRose, .zonePaper, .zoneBlack]

    /// The zone colour for a token name. Any other name gives the paper colour, the standard zone colour.
    public static func token(named name: String?) -> ColorToken {
        guard let name, let token = ColorToken(rawValue: name), all.contains(token) else { return .zonePaper }
        return token
    }

    /// Ink of the title: white on plum, night and black; black on stone, apricot, rose and paper.
    public static func ink(on zone: ColorToken) -> RGB {
        switch zone {
        case .zonePlum, .zoneNight, .zoneBlack: white
        default: black
        }
    }

    static let black = RGB(r: 0, g: 0, b: 0)
    static let white = RGB(r: 1, g: 1, b: 1)
}
