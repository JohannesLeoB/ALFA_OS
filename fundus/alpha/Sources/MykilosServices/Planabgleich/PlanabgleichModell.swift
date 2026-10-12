import Foundation
import CoreGraphics

public enum PlanFundArt: String, Codable, Sendable, CaseIterable, Identifiable {
    case neu, weg, geaendert
    public var id: String { rawValue }
    public var title: String {
        switch self { case .neu: "neu"; case .weg: "weg"; case .geaendert: "geändert" }
    }
}

public struct PlanFund: Codable, Sendable, Identifiable, Equatable {
    enum CodingKeys: String, CodingKey { case nr, x, y, b, h, art, pixel, nurA, nurB, mmX, mmY, mmB, mmH, group = "gruppe" }

    public var nr: Int
    public var x: Int, y: Int, b: Int, h: Int
    public var art: PlanFundArt
    public var pixel: Int, nurA: Int, nurB: Int
    public var mmX: Double, mmY: Double, mmB: Double, mmH: Double
    public var group: Int = 0
    public var id: Int { nr }
    public var mitte: CGPoint { CGPoint(x: Double(x) + Double(b) / 2, y: Double(y) + Double(h) / 2) }
}

public struct PlanTransform: Codable, Sendable, Equatable {
    public var skala: Double, grad: Double, dy: Int, dx: Int, guete: Double, gueteLogPolar: Double
}

public struct PlanSymbolgruppe: Codable, Sendable, Identifiable, Equatable {
    public var nr: Int, count: Int, art: PlanFundArt, b: Int, h: Int, mitglieder: [Int]
    public var id: Int { nr }
}

public struct PlanSeitenPaar: Codable, Sendable, Identifiable, Equatable {
    enum CodingKeys: String, CodingKey { case aSeite, bSeite, naehe, width = "breite", height = "hoehe", transform, funde, groups = "gruppen" }

    public var aSeite: Int
    public var bSeite: Int?
    public var naehe: Double?
    public var width: Int, height: Int
    public var transform: PlanTransform?
    public var funde: [PlanFund]
    public var groups: [PlanSymbolgruppe]
    public var id: Int { aSeite }
    public func count(_ art: PlanFundArt) -> Int { funde.filter { $0.art == art }.count }
}

public struct PlanabgleichErgebnis: Codable, Sendable, Equatable {
    enum CodingKeys: String, CodingKey { case dpi, mmJePx, schwelle, aName, bName, aSeiten, bSeiten, pages = "seiten", bOhneGegenstueck, gerechnetAm }

    public var dpi: Int
    public var mmJePx: Double
    public var schwelle: Int
    public var aName: String, bName: String
    public var aSeiten: Int, bSeiten: Int
    public var pages: [PlanSeitenPaar]
    public var bOhneGegenstueck: [Int]
    public var gerechnetAm: Date

    public var alleFunde: Int { pages.reduce(0) { $0 + $1.funde.count } }
    public func count(_ art: PlanFundArt) -> Int { pages.reduce(0) { $0 + $1.count(art) } }
}

public struct GrauBild: Sendable {
    public var w: Int, h: Int
    public var px: [Float]
    public init(w: Int, h: Int, px: [Float]) { self.w = w; self.h = h; self.px = px }
    public init(w: Int, h: Int, fuell: Float = 255) { self.w = w; self.h = h; self.px = Array(repeating: fuell, count: w * h) }
    @inline(__always) public subscript(y: Int, x: Int) -> Float { px[y * w + x] }
    public var mittel: Float { px.isEmpty ? 0 : px.reduce(0, +) / Float(px.count) }
}

public final class PlanSeitenBilder: @unchecked Sendable {
    public let a: CGImage
    public let b: CGImage?
    public let bAusgerichtet: CGImage?
    public let diff: CGImage?
    public let scan2: CGImage?
    public init(a: CGImage, b: CGImage?, bAusgerichtet: CGImage?, diff: CGImage?, scan2: CGImage?) {
        self.a = a; self.b = b; self.bAusgerichtet = bAusgerichtet; self.diff = diff; self.scan2 = scan2
    }
}

public final class PlanabgleichResultat: @unchecked Sendable {
    public let result: PlanabgleichErgebnis
    public let images: [Int: PlanSeitenBilder]
    public let bSeitenBilder: [Int: CGImage]
    public init(result: PlanabgleichErgebnis, images: [Int: PlanSeitenBilder], bSeitenBilder: [Int: CGImage]) {
        self.result = result; self.images = images; self.bSeitenBilder = bSeitenBilder
    }
}

public enum PlanabgleichFehler: LocalizedError {
    case dateiNichtLesbar(URL)
    case keineSeiten(URL)
    public var errorDescription: String? {
        switch self {
        case .dateiNichtLesbar(let u): "Kann \(u.lastPathComponent) nicht lesen (PDF, PNG oder JPG erwartet)."
        case .keineSeiten(let u): "\(u.lastPathComponent) enthält keine Seiten."
        }
    }
}
