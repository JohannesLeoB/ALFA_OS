import Foundation

public struct DuplikatKandidat: Sendable, Equatable {
    public var name: String?
    public var firma: String?
    public var email: String?
    public var telefon: String?
    public var customerNumber: String?

    public init(name: String? = nil, firma: String? = nil, email: String? = nil,
                telefon: String? = nil, customerNumber: String? = nil) {
        self.name = name; self.firma = firma; self.email = email
        self.telefon = telefon; self.customerNumber = customerNumber
    }
}

public struct DuplikatTreffer: Sendable, Equatable, Identifiable {
    public var id: String { customerNumber + ":" + ground.rawValue }
    public enum Grund: String, Sendable { case customerNumber, email, telefon, name, firma }
    public let customerNumber: String
    public let name: String
    public let ground: Grund
    public let detail: String

    public init(customerNumber: String, name: String, ground: Grund, detail: String) {
        self.customerNumber = customerNumber; self.name = name; self.ground = ground; self.detail = detail
    }
}

public enum AntiDuplikat {
    public static func pruefeKunde(_ kandidat: DuplikatKandidat, stock: [Customer], kontakte: [StudioContact] = []) -> [DuplikatTreffer] {
        var match: [DuplikatTreffer] = []

        if let kdnr = nonEmpty(kandidat.customerNumber) {
            for c in stock where c.customerNumber.caseInsensitiveCompare(kdnr) == .orderedSame {
                match.append(DuplikatTreffer(customerNumber: c.customerNumber, name: c.name, ground: .customerNumber, detail: "Kundennummer \(kdnr) existiert bereits"))
            }
        }

        if let mail = nonEmpty(kandidat.email)?.lowercased() {
            for k in kontakte where k.email?.lowercased() == mail {
                match.append(DuplikatTreffer(customerNumber: k.projekt ?? k.id, name: k.name, ground: .email, detail: "E-Mail \(mail) ist bereits bei \(k.name) hinterlegt"))
            }
        }
        if let tel = nonEmpty(kandidat.telefon).map(nurZiffern), tel.isEmpty == false {
            for k in kontakte where k.telefon.map(nurZiffern) == tel {
                match.append(DuplikatTreffer(customerNumber: k.projekt ?? k.id, name: k.name, ground: .telefon, detail: "Telefon ist bereits bei \(k.name) hinterlegt"))
            }
        }

        if let name = nonEmpty(kandidat.name).map(normalisiere) {
            for c in stock where normalisiere(c.name) == name {
                match.append(DuplikatTreffer(customerNumber: c.customerNumber, name: c.name, ground: .name, detail: "Name „\(c.name)“ existiert bereits"))
            }

            for k in kontakte where normalisiere(k.name) == name {
                match.append(DuplikatTreffer(customerNumber: k.projekt ?? k.id, name: k.name, ground: .name, detail: "Kontakt „\(k.name)“ existiert bereits"))
            }
        }
        if let firma = nonEmpty(kandidat.firma).map(normalisiere) {
            for c in stock where normalisiere(c.name) == firma {
                match.append(DuplikatTreffer(customerNumber: c.customerNumber, name: c.name, ground: .firma, detail: "Firma „\(c.name)“ existiert bereits"))
            }
            for k in kontakte where k.organisation.map(normalisiere) == firma {
                match.append(DuplikatTreffer(customerNumber: k.projekt ?? k.id, name: k.name, ground: .firma, detail: "Firma „\(k.organisation ?? k.name)“ existiert bereits"))
            }
        }

        let rang: [DuplikatTreffer.Grund: Int] = [.customerNumber: 0, .email: 1, .telefon: 2, .name: 3, .firma: 4]
        var gesehen = Set<String>()
        return match
            .sorted { (rang[$0.ground] ?? 9) < (rang[$1.ground] ?? 9) }
            .filter { gesehen.insert($0.customerNumber + ":" + $0.ground.rawValue).inserted }
    }

    static func nonEmpty(_ s: String?) -> String? {
        guard let v = s?.trimmingCharacters(in: .whitespacesAndNewlines), v.isEmpty == false else { return nil }
        return v
    }
    static func nurZiffern(_ s: String) -> String { String(s.filter(\.isNumber)) }
    static func normalisiere(_ s: String) -> String {
        s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
