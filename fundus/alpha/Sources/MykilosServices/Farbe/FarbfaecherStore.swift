import Foundation
import MykilosKit

public final class FarbfaecherStore: @unchecked Sendable {
    private let url: URL
    public private(set) var katalog: FarbfaecherKatalog

    public init(url: URL? = nil) {
        self.url = url ?? Self.defaultUrl()
        self.katalog = FarbfaecherKatalog(faecher: [])
    }

    public func load() {
        if let loaded = Self.load(von: url) { katalog = loaded }
    }

    @discardableResult
    public func einhaengen(_ faecher: Farbfaecher) -> Bool {
        katalog.einhaengen(faecher)
        return save()
    }

    @discardableResult
    public func entfernen(faechername: String) -> Bool {
        katalog.entfernen(faechername: faechername)
        return save()
    }

    @discardableResult
    private func save() -> Bool {
        do {
            let data = try JSONEncoder().encode(katalog)
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: url, options: .atomic)
            return true
        } catch {
            return false
        }
    }

    private static func load(von url: URL) -> FarbfaecherKatalog? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(FarbfaecherKatalog.self, from: data)
    }

    private static func defaultUrl() -> URL {
        let basis = (try? FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true)) ?? FileManager.default.temporaryDirectory
        return basis
            .appendingPathComponent(AppKennung.name, isDirectory: true)
            .appendingPathComponent("farbfaecher.json", isDirectory: false)
    }
}
