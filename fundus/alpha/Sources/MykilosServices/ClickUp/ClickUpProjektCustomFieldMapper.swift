import Foundation
import MykilosKit

public struct ClickUpCustomField: Sendable, Equatable {
    public let name: String
    public let raw: ClickUpCustomFieldValue

    public init(name: String, raw: ClickUpCustomFieldValue) {
        self.name = name
        self.raw = raw
    }
}

public enum ClickUpCustomFieldValue: Decodable, Sendable, Equatable {
    case none
    case zahl(Double)
    case text(String)
    case list([String])

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .none
            return
        }
        do { self = .zahl(try container.decode(Double.self)); return } catch {  }
        do { self = .text(try container.decode(String.self)); return } catch {  }
        do { self = .list(try container.decode([String].self)); return } catch {  }
        do {
            let labels = try container.decode([LabelEntity].self)
            let namen = labels.compactMap { $0.label ?? $0.name }
            self = namen.isEmpty ? .none : .list(namen)
            return
        } catch {  }

        self = .none
    }

    private struct LabelEntity: Decodable {
        var name: String?
        var label: String?
    }
}

public enum ClickUpProjektCustomFieldMapper {
    public static func parse(
        from data: Data,
        routes: ClickUpFieldRouteRegistry = .default
    ) throws -> ClickUpProjektMeta {
        let decoded: MetaTasksResponse
        do {
            decoded = try JSONDecoder().decode(MetaTasksResponse.self, from: data)
        } catch {
            throw ClickUpError.decodingFailed
        }
        guard let fields = decoded.tasks.first(where: { ($0.customFields?.isEmpty == false) })?.customFields else {
            return .empty
        }
        let paare = fields.map { ClickUpCustomField(name: $0.name, raw: $0.value) }
        return map(fields: paare, routes: routes)
    }

    public static func map(
        fields: [ClickUpCustomField],
        routes: ClickUpFieldRouteRegistry = .default
    ) -> ClickUpProjektMeta {
        var meta = ClickUpProjektMeta.empty
        for field in fields {
            guard let route = routes.route(fuerQuelle: field.name) else { continue }
            lege(field.raw, aufKlemme: route.target, in: &meta)
        }
        return meta
    }

    private static func lege(
        _ raw: ClickUpCustomFieldValue,
        aufKlemme slot: ClickUpMetaSlot,
        in meta: inout ClickUpProjektMeta
    ) {
        switch slot.kind {
        case .zahl:
            if let keyPath = slot.doubleKeyPath, let value = zahl(raw) { meta[keyPath: keyPath] = value }
        case .date:
            if let keyPath = slot.dateKeyPath, let value = date(raw) { meta[keyPath: keyPath] = value }
        case .text:
            if let keyPath = slot.textKeyPath, let value = text(raw) { meta[keyPath: keyPath] = value }
        case .textListe:
            if let keyPath = slot.listKeyPath, let value = list(raw) { meta[keyPath: keyPath] = value }
        }
    }

    private static func zahl(_ raw: ClickUpCustomFieldValue) -> Double? {
        switch raw {
        case .zahl(let value): return value
        case .text(let value): return Double(value)
        default:               return nil
        }
    }

    private static func date(_ raw: ClickUpCustomFieldValue) -> Date? {
        switch raw {
        case .text(let value):
            guard let millis = Double(value) else { return nil }
            return Date(timeIntervalSince1970: millis / 1000.0)
        case .zahl(let millis):
            return Date(timeIntervalSince1970: millis / 1000.0)
        default:
            return nil
        }
    }

    private static func text(_ raw: ClickUpCustomFieldValue) -> String? {
        switch raw {
        case .text(let value):
            let getrimmt = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return getrimmt.isEmpty ? nil : getrimmt
        default:
            return nil
        }
    }

    private static func list(_ raw: ClickUpCustomFieldValue) -> [String]? {
        switch raw {
        case .list(let values):
            let sauber = values
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { $0.isEmpty == false }
            return sauber.isEmpty ? nil : sauber
        case .text(let value):
            let getrimmt = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return getrimmt.isEmpty ? nil : [getrimmt]
        default:
            return nil
        }
    }
}

private struct MetaTasksResponse: Decodable {
    var tasks: [MetaTaskEntity]
}

private struct MetaTaskEntity: Decodable {
    var customFields: [MetaFieldEntity]?

    enum CodingKeys: String, CodingKey {
        case customFields = "custom_fields"
    }
}

private struct MetaFieldEntity: Decodable {
    var name: String
    var value: ClickUpCustomFieldValue

    private enum CodingKeys: String, CodingKey { case name, value }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)

        value = try container.decodeIfPresent(ClickUpCustomFieldValue.self, forKey: .value) ?? .none
    }
}
