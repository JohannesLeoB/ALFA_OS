import Foundation

public enum ProduktbildDateiname {
    public static func articleNumber(ausDateiname name: String) -> String? {
        let ohneEndung = (name as NSString).deletingPathExtension
        guard ohneEndung.isEmpty == false else { return nil }
        guard let letztes = ohneEndung.components(separatedBy: "_").last?
            .trimmingCharacters(in: .whitespaces), letztes.isEmpty == false else { return nil }

        guard letztes.contains(where: \.isNumber),
              letztes.contains(",") == false,
              letztes.contains(" ") == false else { return nil }
        return letztes
    }

    public static func key(ausDateiname name: String) -> String? {
        guard let roh = articleNumber(ausDateiname: name) else { return nil }
        let norm = LagerItem.normalisiereArtikelnummer(roh)
        return norm.isEmpty ? nil : norm
    }

    public static func baueIndex(aus entries: [(fileName: String, url: URL)]) -> [String: URL] {
        var index: [String: URL] = [:]
        for entry in entries {
            guard let key = key(ausDateiname: entry.fileName) else { continue }
            if index[key] == nil { index[key] = entry.url }
        }
        return index
    }
}
