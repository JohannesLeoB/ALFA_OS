import Foundation

public protocol KostenstellenProviding: Sendable {
    func kostenstellen(fuer projectNumber: String) -> [Kostenstelle]
}

public struct DefaultKostenstellenProvider: KostenstellenProviding {
    private let overrides: [String: [Kostenstelle]]
    public init(overrides: [String: [Kostenstelle]] = [:]) {
        self.overrides = overrides
    }
    public func kostenstellen(fuer projectNumber: String) -> [Kostenstelle] {
        if let o = overrides[projectNumber], o.isEmpty == false { return o }
        return Kostenstelle.defaults
    }
}
