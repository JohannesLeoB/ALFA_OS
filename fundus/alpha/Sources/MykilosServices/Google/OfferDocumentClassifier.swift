import Foundation

public enum OfferDocumentType: Int, CaseIterable, Sendable {
    case angebot          = 0
    case auftrag          = 1
    case abschlagsrechnung = 2
    case schlussrechnung  = 3

    case eingehendesAngebot = 4
    case order       = 5

    case sonstiges        = 99

    public var label: String {
        switch self {
        case .angebot:            "Angebote"
        case .auftrag:            "Aufträge"
        case .abschlagsrechnung:  "Abschlagsrechnungen"
        case .schlussrechnung:    "Schlussrechnungen"
        case .eingehendesAngebot: "Eingehende Angebote"
        case .order:         "Bestellungen"
        case .sonstiges:          "Sonstige Dokumente"
        }
    }
}

public struct ClassifiedOffer: Identifiable, Sendable, Equatable {
    public var file: GoogleDriveFile
    public var type: OfferDocumentType
    public var belegNummer: String?
    public var kundenNummer: String?
    public var version: String?

    public var id: String { file.id }

    public init(file: GoogleDriveFile, type: OfferDocumentType,
                belegNummer: String? = nil, kundenNummer: String? = nil, version: String? = nil) {
        self.file = file
        self.type = type
        self.belegNummer = belegNummer
        self.kundenNummer = kundenNummer
        self.version = version
    }
}

public enum OfferDocumentClassifier {
    static let prefixLexicon: [String: OfferDocumentType] = [
        "AN": .angebot,
        "AB": .auftrag,
        "TR": .abschlagsrechnung,
        "ARE": .abschlagsrechnung,
        "SR": .schlussrechnung,
        "BE": .order,
        "BS": .order
    ]

    public static func classify(
        _ file: GoogleDriveFile,
        isIncoming: Bool,
        folderName: String? = nil
    ) -> ClassifiedOffer {
        let prefix = extractPrefix(from: file.name)
        let belegNummer = extractBelegNummer(from: file.name)
        let kundenNummer = extractKundenNummer(from: file.name)
        let version = extractVersion(from: file.name)
        let folder = (folderName ?? "").lowercased()

        let type = resolveType(isIncoming: isIncoming, folder: folder, prefix: prefix)
        return ClassifiedOffer(file: file, type: type,
                               belegNummer: belegNummer, kundenNummer: kundenNummer, version: version)
    }

    static func resolveType(isIncoming: Bool, folder: String, prefix: String) -> OfferDocumentType {
        if isIncoming {
            if folder.contains("bestell") { return .order }
            if prefixLexicon[prefix] == .order { return .order }
            return .eingehendesAngebot
        }

        if folder.contains("rechnung") {
            switch prefix {
            case "SR": return .schlussrechnung
            case "TR", "ARE": return .abschlagsrechnung
            default:   return .schlussrechnung
            }
        }
        if folder.contains("angebot") { return .angebot }
        if folder.contains("auftrag") { return .auftrag }

        return prefixLexicon[prefix] ?? .sonstiges
    }

    static func extractPrefix(from name: String) -> String {
        let base = name.split(separator: ".").first.map(String.init) ?? name

        let firstToken = base.prefix { $0 != "-" && $0 != "_" }
        return String(firstToken).uppercased()
    }

    static func extractBelegNummer(from name: String) -> String? {
        firstMatch(in: name, pattern: #"(\d{4}-\d{3,4})(?!\d)"#)
    }

    static func extractKundenNummer(from name: String) -> String? {
        firstMatch(in: name, pattern: #"Kdnr-(\d+)"#, group: 1)
    }

    static func extractVersion(from name: String) -> String? {
        firstMatch(in: name, pattern: #"_(v\d+)"#, group: 1)
    }

    private static func firstMatch(in text: String, pattern: String, group: Int = 1) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              match.numberOfRanges > group,
              let r = Range(match.range(at: group), in: text) else { return nil }
        return String(text[r])
    }
}
