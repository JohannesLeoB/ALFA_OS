import Foundation

public struct Projektnummer: Codable, Hashable, Sendable, Comparable, CustomStringConvertible {
    public let jahr: Int
    public let laufendeNummer: Int

    public init(jahr: Int, laufendeNummer: Int) {
        self.jahr = jahr
        self.laufendeNummer = laufendeNummer
    }

    public init?(parsing raw: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        let groups = trimmed
            .split(whereSeparator: { !$0.isNumber })
            .map(String.init)
        guard groups.count >= 2,
              let jahr = Int(groups[0]), jahr >= 2000, jahr < 3000,
              let nr = Int(groups[1]), nr >= 0 else { return nil }
        self.jahr = jahr
        self.laufendeNummer = nr
    }

    public var appFormat: String { String(format: "%04d-%03d", jahr, laufendeNummer) }

    public var driveFormat: String { String(format: "%04d_%03d", jahr, laufendeNummer) }
    public var description: String { appFormat }

    public static func < (lhs: Projektnummer, rhs: Projektnummer) -> Bool {
        lhs.jahr != rhs.jahr ? lhs.jahr < rhs.jahr : lhs.laufendeNummer < rhs.laufendeNummer
    }

    public static func next(jahr: Int, vorhandene: [Projektnummer]) -> Projektnummer {
        let maxImJahr = vorhandene.filter { $0.jahr == jahr }.map(\.laufendeNummer).max() ?? 0
        return Projektnummer(jahr: jahr, laufendeNummer: maxImJahr + 1)
    }

    public static func ersteImText(_ text: String) -> Projektnummer? {
        guard let regex = try? NSRegularExpression(
            pattern: "(?<![0-9])(2[0-9]{3})[ _/-]([0-9]{1,3})(?![0-9])") else { return nil }
        let area = NSRange(text.startIndex..., in: text)
        for match in regex.matches(in: text, range: area) {
            guard let jahrBereich = Range(match.range(at: 1), in: text),
                  let nrBereich = Range(match.range(at: 2), in: text),
                  let jahr = Int(text[jahrBereich]), let laufend = Int(text[nrBereich]) else { continue }
            return Projektnummer(jahr: jahr, laufendeNummer: laufend)
        }
        return nil
    }
}
