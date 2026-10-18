import Foundation

public enum ArtikelPreisLuecke: Sendable, Equatable {
    case ekFehlt(vkBekannt: Double)
    case vkFehlt(ekBekannt: Double)

    public static func erkenne(ekNetto: Double?, vkNetto: Double?) -> ArtikelPreisLuecke? {
        switch (ekNetto, vkNetto) {
        case (.none, .some(let vk)): return .ekFehlt(vkBekannt: vk)
        case (.some(let ek), .none): return .vkFehlt(ekBekannt: ek)
        default: return nil
        }
    }
}

public struct ArtikelManuelleMarge: Sendable, Equatable {
    public let rabattProzent: Double
    public let gap: ArtikelPreisLuecke

    public init?(rabattProzent: Double, gap: ArtikelPreisLuecke) {
        guard rabattProzent > 0, rabattProzent < 100 else { return nil }
        self.rabattProzent = rabattProzent
        self.gap = gap
    }

    public var berechneterWert: Double {
        let faktor = 1 - (rabattProzent / 100)
        switch gap {
        case .ekFehlt(let vk): return (vk * faktor * 100).rounded() / 100
        case .vkFehlt(let ek): return (ek / faktor * 100).rounded() / 100
        }
    }

    public var betrifftEK: Bool {
        if case .ekFehlt = gap { return true }
        return false
    }
}
