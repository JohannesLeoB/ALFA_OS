import Foundation

public struct PapersAssetKandidat: Equatable, Sendable {
    public let fileName: String

    public let dateiendung: String

    public let hash: String
    public let pixelBreite: Int?
    public let pixelHoehe: Int?

    public init(fileName: String, dateiendung: String, hash: String,
                pixelBreite: Int? = nil, pixelHoehe: Int? = nil) {
        self.fileName = fileName
        self.dateiendung = dateiendung.lowercased()
        self.hash = hash
        self.pixelBreite = pixelBreite
        self.pixelHoehe = pixelHoehe
    }

    var aufloesungFlaeche: Int? {
        guard let b = pixelBreite, let h = pixelHoehe else { return nil }
        return b * h
    }
}

public enum PapersAssetEntscheidung: Equatable, Sendable {
    case exaktesDuplikat

    case neueErsetztBestehende

    case bestehendeBleibt

    case manuellPruefen

    public var erfordertMenschlichePruefung: Bool { self == .manuellPruefen }
}

public enum PapersAssetAbgleich {
    public static func entscheide(
        bestehende: PapersAssetKandidat, neue: PapersAssetKandidat
    ) -> PapersAssetEntscheidung {
        if bestehende.dateiendung == neue.dateiendung, bestehende.hash == neue.hash {
            return .exaktesDuplikat
        }
        guard let bestehendeFlaeche = bestehende.aufloesungFlaeche,
              let neueFlaeche = neue.aufloesungFlaeche else {
            return .manuellPruefen
        }
        if neueFlaeche > bestehendeFlaeche { return .neueErsetztBestehende }
        if neueFlaeche < bestehendeFlaeche { return .bestehendeBleibt }
        return .manuellPruefen
    }
}
