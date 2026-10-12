import Foundation

public struct CatalogObjectID: Hashable, Sendable, Codable, CustomStringConvertible {
    public let raw: String

    public init(_ raw: String) {
        self.raw = raw
    }

    public var description: String { raw }
}

public enum CatalogMatrix: String, Hashable, Sendable, Codable, CaseIterable {
    case customer
    case projekt
    case artikel
    case material
    case lager
    case image
    case zeichnung
    case textblock
    case dienstleistung
    case eingangsangebot

    case angebot

    case aufgabe
    case notiz
    case sonstige
}

public enum InhaltsArt: String, Hashable, Sendable, Codable, CaseIterable {
    case artikel
    case images
    case material
    case zeichnungen
    case textbausteine
    case dokumente

    case kontakte
    case aufgaben
    case gemischt
}

public struct PickSnapshot: Hashable, Sendable, Codable {
    enum CodingKeys: String, CodingKey { case label = "bezeichnung", quantity = "menge", ekEinzel, vkEinzel, attribute }

    public let label: String

    public let quantity: Int

    public let ekEinzel: Double?

    public let vkEinzel: Double?

    public let attribute: [String: String]

    public init(
        label: String,
        quantity: Int = 1,
        ekEinzel: Double? = nil,
        vkEinzel: Double? = nil,
        attribute: [String: String] = [:]
    ) {
        self.label = label
        self.quantity = quantity
        self.ekEinzel = ekEinzel
        self.vkEinzel = vkEinzel
        self.attribute = attribute
    }
}

public enum PickContent: Sendable, Equatable, Codable {
    case text(String)

    case file(URL)

    case bytes(Data, mimeType: String)

    case kontaktkarte(String)

    case keiner
}

public protocol Pick: Sendable {
    var matrix: CatalogMatrix { get }

    var objektID: CatalogObjectID { get }

    var snapshot: PickSnapshot { get }

    func resolve() async throws -> PickContent
}

public struct BasicPick: Pick {
    public let matrix: CatalogMatrix
    public let objektID: CatalogObjectID
    public let snapshot: PickSnapshot

    public let content: PickContent

    public init(
        matrix: CatalogMatrix,
        objektID: CatalogObjectID,
        snapshot: PickSnapshot,
        content: PickContent = .keiner
    ) {
        self.matrix = matrix
        self.objektID = objektID
        self.snapshot = snapshot
        self.content = content
    }

    public func resolve() async throws -> PickContent {
        content
    }
}

public struct WorkBasketID: Hashable, Sendable, Codable, CustomStringConvertible {
    public let raw: String

    public init(_ raw: String) {
        self.raw = raw
    }

    public var description: String { raw }
}

public enum WorkBasketStatus: Sendable, Equatable {
    case kalkulation

    case bestaetigt

    case nachtrag(zu: WorkBasketID)

    case gutschrift(zu: WorkBasketID)

    public var istEingefroren: Bool {
        switch self {
        case .kalkulation:
            return false
        case .bestaetigt, .nachtrag, .gutschrift:
            return true
        }
    }

    public func darfWechselnZu(_ target: WorkBasketStatus) -> Bool {
        switch (self, target) {
        case (.kalkulation, .bestaetigt):
            return true
        case (.bestaetigt, .nachtrag), (.bestaetigt, .gutschrift):
            return true
        default:
            return false
        }
    }
}

public struct WorkBasket {
    public let id: WorkBasketID

    public let projectNumber: String

    public var inhaltsArt: InhaltsArt

    public var picks: [any Pick]

    public var version: Int

    public var status: WorkBasketStatus

    public let erstellt: Date

    public init(
        id: WorkBasketID,
        projectNumber: String,
        inhaltsArt: InhaltsArt,
        picks: [any Pick] = [],
        version: Int = 1,
        status: WorkBasketStatus = .kalkulation,
        erstellt: Date = Date()
    ) {
        self.id = id
        self.projectNumber = projectNumber
        self.inhaltsArt = inhaltsArt
        self.picks = picks
        self.version = version
        self.status = status
        self.erstellt = erstellt
    }
}

public struct PortID: Hashable, Sendable, Codable, CustomStringConvertible {
    public let raw: String

    public init(_ raw: String) {
        self.raw = raw
    }

    public var description: String { raw }
}

public struct PortZiel: Hashable, Sendable, Codable {
    public let kind: String

    public let parameter: [String: String]

    public init(kind: String, parameter: [String: String] = [:]) {
        self.kind = kind
        self.parameter = parameter
    }
}

public struct CheckoutPreview: Sendable, Equatable {
    public let zusammenfassung: String

    public let warnungen: [String]

    public init(zusammenfassung: String, warnungen: [String] = []) {
        self.zusammenfassung = zusammenfassung
        self.warnungen = warnungen
    }
}

public struct CheckoutResult: Sendable, Equatable {
    public let erfolg: Bool

    public let referenz: String?

    public let message: String?

    public let nutzlast: Data?

    public init(
        erfolg: Bool,
        referenz: String? = nil,
        message: String? = nil,
        nutzlast: Data? = nil
    ) {
        self.erfolg = erfolg
        self.referenz = referenz
        self.message = message
        self.nutzlast = nutzlast
    }
}

public protocol CheckoutPort: Sendable {
    var id: PortID { get }

    var name: String { get }

    func erlaubteInhaltsArten() -> Set<InhaltsArt>

    func preview(basket: WorkBasket, target: PortZiel) async throws -> CheckoutPreview

    func execute(basket: WorkBasket, target: PortZiel) async throws -> CheckoutResult
}

public protocol PortRightsProviding: Sendable {
    func erlaubtePorts(userID: String) -> Set<PortID>
}

public struct AllowAllPortRights: PortRightsProviding {
    private let alle: Set<PortID>

    public init(alleBekanntenPorts: Set<PortID>) {
        self.alle = alleBekanntenPorts
    }

    public func erlaubtePorts(userID: String) -> Set<PortID> {
        alle
    }
}

public struct PortRegistry {
    public private(set) var ports: [any CheckoutPort]

    public init(ports: [any CheckoutPort] = []) {
        self.ports = ports
    }

    public mutating func registriere(_ port: any CheckoutPort) {
        ports.append(port)
    }

    public var alleBekanntenPortIDs: Set<PortID> {
        Set(ports.map(\.id))
    }

    public func ports(
        fuer inhaltsArt: InhaltsArt,
        userID: String,
        rechte: PortRightsProviding
    ) -> [any CheckoutPort] {
        let erlaubte = rechte.erlaubtePorts(userID: userID)
        return ports.filter { port in
            port.erlaubteInhaltsArten().contains(inhaltsArt)
                && erlaubte.contains(port.id)
        }
    }
}
