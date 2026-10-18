import Foundation

public struct FolderNode: Codable, Hashable, Sendable, Identifiable {
    public let id: UUID
    public var name: String
    public var children: [FolderNode]

    public init(id: UUID = UUID(), _ name: String, children: [FolderNode] = []) {
        self.id = id
        self.name = name
        self.children = children
    }
}

public struct FolderSchema: Codable, Hashable, Sendable {
    public var version: Int

    public var rootTemplate: String
    public var children: [FolderNode]

    public var rootDateien: [String]

    public init(version: Int, rootTemplate: String, children: [FolderNode], rootDateien: [String]) {
        self.version = version
        self.rootTemplate = rootTemplate
        self.children = children
        self.rootDateien = rootDateien
    }

    public static let v1 = FolderSchema(
        version: 1,
        rootTemplate: "<JJJJ_NNN_Kunde_STR-Nr>",
        children: [
            FolderNode("01 INFOS", children: [
                FolderNode("01 Pläne"),
                FolderNode("02 Fotos Bestand"),
                FolderNode("03 Recherche | Zubehör"),
                FolderNode("04 ausgehende Angebote"),
                FolderNode("05 eingehende Angebote"),
                FolderNode("06 Fotos Baustelle"),
                FolderNode("07 Fragebogen"),
                FolderNode("08 Werkszeichnung"),
                FolderNode("09 Fotos Mängel")
            ]),
            FolderNode("02 CAD", children: [
                FolderNode("VectorWorks")
            ]),
            FolderNode("03 PRÄSENTATION", children: [
                FolderNode("Moodboards"),
                FolderNode("PDF"),
                FolderNode("Renderings"),
                FolderNode("Vorplanung | Screenshots")
            ])
        ],
        rootDateien: ["MYKILOS_Abnahmeprotokoll BLANKO.pdf"]
    )

    public static let v2: FolderSchema = {
        var schema = v1
        schema.version = 2
        schema.children.insert(FolderNode("00 EINGANG"), at: 0)
        return schema
    }()

    public func allePfade() -> [String] {
        var pfade: [String] = []
        func walk(_ node: FolderNode, prefix: String) {
            let pfad = prefix.isEmpty ? node.name : prefix + "/" + node.name
            pfade.append(pfad)
            for child in node.children { walk(child, prefix: pfad) }
        }
        for child in children { walk(child, prefix: "") }
        return pfade
    }
}

public enum OrdnerSlot: String, Codable, Sendable, CaseIterable {
    case infos
    case angeboteAusgehend
    case angeboteEingehend
    case fragebogen
    case praesentationPDF
    case cad

    case inbox
}

public struct OrdnerKonnektor: Codable, Hashable, Sendable, Identifiable {
    public var id: String { slot.rawValue }
    public var slot: OrdnerSlot
    public var ordnername: String
    public var relativerPfad: String
    public var schemaVersion: Int

    public init(slot: OrdnerSlot, ordnername: String, relativerPfad: String, schemaVersion: Int) {
        self.slot = slot
        self.ordnername = ordnername
        self.relativerPfad = relativerPfad
        self.schemaVersion = schemaVersion
    }

    public static let v1Defaults: [OrdnerKonnektor] = [
        OrdnerKonnektor(slot: .infos, ordnername: "01 INFOS", relativerPfad: "01 INFOS", schemaVersion: 1),
        OrdnerKonnektor(slot: .angeboteAusgehend, ordnername: "04 ausgehende Angebote", relativerPfad: "01 INFOS/04 ausgehende Angebote", schemaVersion: 1),
        OrdnerKonnektor(slot: .angeboteEingehend, ordnername: "05 eingehende Angebote", relativerPfad: "01 INFOS/05 eingehende Angebote", schemaVersion: 1),
        OrdnerKonnektor(slot: .fragebogen, ordnername: "07 Fragebogen", relativerPfad: "01 INFOS/07 Fragebogen", schemaVersion: 1),
        OrdnerKonnektor(slot: .praesentationPDF, ordnername: "PDF", relativerPfad: "03 PRÄSENTATION/PDF", schemaVersion: 1),
        OrdnerKonnektor(slot: .cad, ordnername: "VectorWorks", relativerPfad: "02 CAD/VectorWorks", schemaVersion: 1)
    ]

    public static let v2Defaults: [OrdnerKonnektor] = v1Defaults + [
        OrdnerKonnektor(slot: .inbox, ordnername: "00 EINGANG", relativerPfad: "00 EINGANG", schemaVersion: 2)
    ]
}
