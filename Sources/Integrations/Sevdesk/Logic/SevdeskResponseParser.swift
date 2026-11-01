import Foundation

enum SevdeskResponseParser {
    static func contact(from data: Data) throws -> Contact? {
        guard let entity = try decode(ContactEntity.self, from: data).first else { return nil }
        return Contact(id: entity.id ?? "", name: entity.name ?? "", customerNumber: entity.customerNumber)
    }

    static func orders(from data: Data) throws -> [Order] {
        try decode(OrderEntity.self, from: data).map { entity in
            Order(
                id: entity.id ?? "",
                orderNumber: entity.orderNumber,
                orderType: entity.orderType ?? "",
                rawStatus: entity.status ?? "",
                sumNet: double(from: entity.sumNet),
                sumTax: double(from: entity.sumTax),
                sumGross: double(from: entity.sumGross),
                contactID: entity.contact?.id,
                customerInternalNote: entity.customerInternalNote,
                header: entity.header)
        }
    }

    static func version(from data: Data) -> String? {
        guard let root = object(data) else { return nil }
        if let single = root["objects"] as? [String: Any] { return text(single["version"]) }
        if let list = root["objects"] as? [[String: Any]] { return text(list.first?["version"]) }
        return nil
    }

    static func template(from data: Data) -> TenantFinding.Template? {
        guard let root = object(data),
              let objects = root["objects"] as? [[String: Any]],
              let order = objects.first,
              let orderID = text(order["id"]) else { return nil }
        return TenantFinding.Template(
            orderID: orderID,
            orderNumber: text(order["orderNumber"]),
            contactID: text((order["contact"] as? [String: Any])?["id"]),
            contactPersonID: text((order["contactPerson"] as? [String: Any])?["id"]),
            addressCountryID: text((order["addressCountry"] as? [String: Any])?["id"]),
            taxRuleID: text((order["taxRule"] as? [String: Any])?["id"]),
            taxRate: number(order["taxRate"]),
            taxType: text(order["taxType"]),
            currency: text(order["currency"]))
    }

    static func units(from data: Data) -> [TenantFinding.Unit] {
        guard let root = object(data), let objects = root["objects"] as? [[String: Any]] else { return [] }
        var seen = Set<String>()
        var result: [TenantFinding.Unit] = []
        for position in objects {
            guard let unity = position["unity"] as? [String: Any], let id = text(unity["id"]) else { continue }
            guard let name = text(unity["name"]) ?? text(unity["translationCode"]), name.isEmpty == false else { continue }
            if seen.insert(id).inserted { result.append(TenantFinding.Unit(id: id, name: name)) }
        }
        return result
    }

    static func nextNumber(from data: Data) -> String? {
        guard let root = object(data) else { return nil }
        if let direct = root["objects"] as? String, direct.isEmpty == false { return direct }
        if let single = root["objects"] as? [String: Any] {
            for key in ["orderNumber", "nextOrderNumber", "number", "value"] {
                if let value = text(single[key]) { return value }
            }
        }
        if let list = root["objects"] as? [String], let first = list.first, first.isEmpty == false { return first }
        return nil
    }

    static func positionTaxRate(from data: Data) -> Double? {
        guard let root = object(data), let objects = root["objects"] as? [[String: Any]] else { return nil }
        let rates = objects.compactMap { number($0["taxRate"]) }
        guard rates.isEmpty == false else { return nil }
        let counts = rates.reduce(into: [Double: Int]()) { $0[$1, default: 0] += 1 }
        return counts.max { a, b in a.value != b.value ? a.value < b.value : a.key < b.key }?.key
    }

    static func match(byNumber requested: String, from data: Data) -> ContactMatch {
        guard let list = contactList(data) else { return .none }
        let wanted = requested.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidates: [ContactMatch.Candidate] = list.compactMap { object in
            guard let id = text(object["id"]), id.isEmpty == false else { return nil }
            guard let reported = text(object["customerNumber"]),
                  reported.trimmingCharacters(in: .whitespacesAndNewlines) == wanted else { return nil }
            return ContactMatch.Candidate(id: id, name: contactName(object), isContactPerson: hasParent(object))
        }
        return resolve(candidates)
    }

    static func match(byName requested: String, from data: Data) -> ContactMatch {
        guard let list = contactList(data) else { return .none }
        let wanted = requested.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidates: [ContactMatch.Candidate] = list.compactMap { object in
            guard let id = text(object["id"]), id.isEmpty == false,
                  let name = contactName(object),
                  name.caseInsensitiveCompare(wanted) == .orderedSame else { return nil }
            return ContactMatch.Candidate(id: id, name: name, isContactPerson: hasParent(object))
        }
        return resolve(candidates)
    }

    private static func resolve(_ candidates: [ContactMatch.Candidate]) -> ContactMatch {
        switch candidates.count {
        case 0: return .none
        case 1:
            let only = candidates[0]
            return only.isContactPerson ? .contactPersonOnly(only) : .unique(id: only.id, name: only.name)
        default: return .ambiguous(candidates)
        }
    }

    private static func contactList(_ data: Data) -> [[String: Any]]? {
        object(data)?["objects"] as? [[String: Any]]
    }

    private static func hasParent(_ object: [String: Any]) -> Bool {
        let parent = (object["parent"] as? [String: Any]).flatMap { text($0["id"]) }
        return parent?.isEmpty == false
    }

    private static func contactName(_ object: [String: Any]) -> String? {
        if let name = text(object["name"]), name.isEmpty == false { return name }
        let parts = [text(object["surename"]), text(object["familyname"])].compactMap { $0 }.filter { $0.isEmpty == false }
        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }

    private static func object(_ data: Data) -> [String: Any]? {
        (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }

    private static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> [T] {
        do {
            return try JSONDecoder().decode(Objects<T>.self, from: data).objects
        } catch {
            throw SevdeskFailure.decoding
        }
    }

    static func text(_ value: Any?) -> String? {
        if let string = value as? String { return string.isEmpty ? nil : string }
        if let integer = value as? Int { return String(integer) }
        if let double = value as? Double { return double == double.rounded() ? String(Int(double)) : String(double) }
        return nil
    }

    static func number(_ value: Any?) -> Double? {
        if let double = value as? Double { return double }
        if let integer = value as? Int { return Double(integer) }
        if let string = value as? String { return Double(string) }
        return nil
    }

    private static func double(from value: String?) -> Double {
        guard let value, let parsed = Double(value) else { return 0 }
        return parsed
    }

    private struct Objects<T: Decodable>: Decodable {
        var objects: [T]
    }

    private struct ContactEntity: Decodable {
        var id: String?
        var name: String?
        var customerNumber: String?
    }

    private struct OrderEntity: Decodable {
        var id: String?
        var orderNumber: String?
        var orderType: String?
        var status: String?
        var sumNet: String?
        var sumTax: String?
        var sumGross: String?
        var contact: ContactRef?
        var customerInternalNote: String?
        var header: String?
    }

    private struct ContactRef: Decodable {
        var id: String?
    }
}
