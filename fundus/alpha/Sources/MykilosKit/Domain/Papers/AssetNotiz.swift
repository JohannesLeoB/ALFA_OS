import Foundation

public struct AssetNotiz: Codable, Equatable, Sendable, Identifiable {
    enum CodingKeys: String, CodingKey { case key = "schluessel", eigeneTags, notiz, geaendertAm }

    public var key: String
    public var eigeneTags: [String]
    public var notiz: String
    public var geaendertAm: Date

    public var id: String { key }

    public init(key: String, eigeneTags: [String] = [], notiz: String = "",
                geaendertAm: Date = Date()) {
        self.key = key
        self.eigeneTags = eigeneTags
        self.notiz = notiz
        self.geaendertAm = geaendertAm
    }

    public var isEmpty: Bool {
        eigeneTags.isEmpty && notiz.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public static func key(fuerDateiname name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    public func mitTag(_ roh: String) -> AssetNotiz {
        let tag = roh.trimmingCharacters(in: .whitespacesAndNewlines)
        guard tag.isEmpty == false,
              eigeneTags.contains(where: { $0.caseInsensitiveCompare(tag) == .orderedSame }) == false
        else { return self }
        var kopie = self
        kopie.eigeneTags.append(tag)
        return kopie
    }

    public func ohneTag(_ tag: String) -> AssetNotiz {
        var kopie = self
        kopie.eigeneTags.removeAll { $0.caseInsensitiveCompare(tag) == .orderedSame }
        return kopie
    }
}
