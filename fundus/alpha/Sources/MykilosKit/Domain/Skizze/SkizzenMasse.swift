import Foundation

public struct MassAnker: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var von: BildPunkt
    public var bis: BildPunkt
    public var realMillimeter: Double
    public var label: String

    public init(id: UUID = UUID(), von: BildPunkt, bis: BildPunkt, realMillimeter: Double, label: String) {
        self.id = id
        self.von = von
        self.bis = bis
        self.realMillimeter = realMillimeter
        self.label = label
    }

    public var laengeNormiert: Double {
        let dx = bis.x - von.x, dy = bis.y - von.y
        return (dx * dx + dy * dy).squareRoot()
    }

    public var mmProNorm: Double? {
        let n = laengeNormiert
        guard n > 0 else { return nil }
        return realMillimeter / n
    }

    public var beschreibung: String {
        let f = NumberFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        let zahl = f.string(from: NSNumber(value: realMillimeter)) ?? String(Int(realMillimeter))
        let name = label.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "\(zahl) mm" : "\(name): \(zahl) mm"
    }
}
