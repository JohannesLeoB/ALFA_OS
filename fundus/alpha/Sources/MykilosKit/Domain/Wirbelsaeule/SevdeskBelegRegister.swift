import Foundation

public struct SevdeskBelegEintrag: Sendable, Equatable, Codable, Identifiable {
    enum CodingKeys: String, CodingKey { case sevdeskOrderID, belegArt, belegnummer, projectNumber = "projektNummer", customerNumber = "kundennummer", customersName = "kundenName", contactID, angelegtAm, letzterStatus, letztesUpdate, pdfAbgelegt }

    public var id: String { sevdeskOrderID }

    public let sevdeskOrderID: String

    public let belegArt: String
    public let belegnummer: String
    public let projectNumber: String
    public let customerNumber: String?
    public let customersName: String?

    public let contactID: String
    public let angelegtAm: Date

    public var letzterStatus: Int

    public var letztesUpdate: String?

    public var pdfAbgelegt: Bool

    public init(sevdeskOrderID: String, belegArt: String = "AN", belegnummer: String,
                projectNumber: String,
                customerNumber: String?, customersName: String?, contactID: String,
                angelegtAm: Date, letzterStatus: Int = 100,
                letztesUpdate: String? = nil, pdfAbgelegt: Bool = false) {
        self.sevdeskOrderID = sevdeskOrderID
        self.belegArt = belegArt
        self.belegnummer = belegnummer
        self.projectNumber = projectNumber
        self.customerNumber = customerNumber
        self.customersName = customersName
        self.contactID = contactID
        self.angelegtAm = angelegtAm
        self.letzterStatus = letzterStatus
        self.letztesUpdate = letztesUpdate
        self.pdfAbgelegt = pdfAbgelegt
    }

    public var istRechnung: Bool { belegArt == "RE" }

    public var istBezahlt: Bool { istRechnung && letzterStatus >= 1000 }

    public var statusLabel: String {
        switch letzterStatus {
        case ..<200: return "Entwurf"
        case 200..<1000: return "zugestellt"
        default: return istRechnung ? "bezahlt" : "Status \(letzterStatus)"
        }
    }

    public func brauchtAblage(neuerStatus: Int, neuesUpdate: String?) -> Bool {
        let versendet = neuerStatus >= 200
        guard versendet else { return false }
        if pdfAbgelegt == false { return true }
        return neuesUpdate != nil && neuesUpdate != letztesUpdate
    }
}

public struct SevdeskBelegRegisterSpeicher: Sendable {
    public static let key = "sevdesk.belegregister"

    private static let schreibLock = NSRecursiveLock()

    private let defaults: UserDefaults
    public init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    public func alle() -> [SevdeskBelegEintrag] {
        guard let data = defaults.data(forKey: Self.key) else { return [] }

        return (try? JSONDecoder().decode([SevdeskBelegEintrag].self, from: data)) ?? []
    }

    public func registriere(_ entry: SevdeskBelegEintrag) throws {
        Self.schreibLock.lock(); defer { Self.schreibLock.unlock() }
        var list = alle()
        guard list.contains(where: { $0.sevdeskOrderID == entry.sevdeskOrderID }) == false else { return }
        list.append(entry)
        try save(list)
    }

    public func aktualisiere(_ entry: SevdeskBelegEintrag) throws {
        Self.schreibLock.lock(); defer { Self.schreibLock.unlock() }
        var list = alle()
        guard let index = list.firstIndex(where: { $0.sevdeskOrderID == entry.sevdeskOrderID })
        else { return }
        list[index] = entry
        try save(list)
    }

    public func uebernimm(_ remote: SevdeskBelegEintrag) throws {
        Self.schreibLock.lock(); defer { Self.schreibLock.unlock() }
        guard var lokal = entry(orderID: remote.sevdeskOrderID) else {
            try registriere(remote)
            return
        }
        var geaendert = false
        if remote.letzterStatus > lokal.letzterStatus {
            lokal.letzterStatus = remote.letzterStatus
            lokal.letztesUpdate = remote.letztesUpdate
            geaendert = true
        }
        if remote.pdfAbgelegt && lokal.pdfAbgelegt == false {
            lokal.pdfAbgelegt = true
            geaendert = true
        }
        if geaendert { try aktualisiere(lokal) }
    }

    public func entry(orderID: String) -> SevdeskBelegEintrag? {
        alle().first { $0.sevdeskOrderID == orderID }
    }

    private func save(_ list: [SevdeskBelegEintrag]) throws {
        defaults.set(try JSONEncoder().encode(list), forKey: Self.key)
    }
}
