import Foundation

public struct DatenschutzPraeferenzen: Codable, Equatable, Sendable {
    public var teileMailMitAssistent: Bool

    public var teileKalenderMitAssistent: Bool
    public var teileKontakteMitAssistent: Bool
    public var teileDriveMitAssistent: Bool
    public var teileClickUpMitAssistent: Bool
    public var teileNotizenMitAssistent: Bool
    public var teileAufgabenMitAssistent: Bool
    public var teileKatalogKalkulationMitAssistent: Bool
    public var teileStudioWissenMitAssistent: Bool
    public var teileChatMitAssistent: Bool

    public var teileClockodoMitAssistent: Bool
    public var kiKomplettAus: Bool
    public var updatedAt: Date

    public init(
        teileMailMitAssistent: Bool = true,
        teileKalenderMitAssistent: Bool = true,
        teileKontakteMitAssistent: Bool = true,
        teileDriveMitAssistent: Bool = true,
        teileClickUpMitAssistent: Bool = true,
        teileNotizenMitAssistent: Bool = true,
        teileAufgabenMitAssistent: Bool = true,
        teileKatalogKalkulationMitAssistent: Bool = true,
        teileStudioWissenMitAssistent: Bool = true,
        teileChatMitAssistent: Bool = true,
        teileClockodoMitAssistent: Bool = true,
        kiKomplettAus: Bool = false,
        updatedAt: Date = Date()
    ) {
        self.teileMailMitAssistent = teileMailMitAssistent
        self.teileKalenderMitAssistent = teileKalenderMitAssistent
        self.teileKontakteMitAssistent = teileKontakteMitAssistent
        self.teileDriveMitAssistent = teileDriveMitAssistent
        self.teileClickUpMitAssistent = teileClickUpMitAssistent
        self.teileNotizenMitAssistent = teileNotizenMitAssistent
        self.teileAufgabenMitAssistent = teileAufgabenMitAssistent
        self.teileKatalogKalkulationMitAssistent = teileKatalogKalkulationMitAssistent
        self.teileStudioWissenMitAssistent = teileStudioWissenMitAssistent
        self.teileChatMitAssistent = teileChatMitAssistent
        self.teileClockodoMitAssistent = teileClockodoMitAssistent
        self.kiKomplettAus = kiKomplettAus
        self.updatedAt = updatedAt
    }

    public static let standard = DatenschutzPraeferenzen()

    public static let chatFilesDefaultsKey = "assistent.dateienImChat"

    public static let externeBilderDefaultsKey = "mail.externeBilderLaden"
}
