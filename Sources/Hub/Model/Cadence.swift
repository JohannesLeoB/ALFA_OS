public enum Cadence: Codable, Equatable, Sendable {
    case off
    case manual
    case every(Duration)
    case push
    case hook
}

public enum CadenceChoice: String, CaseIterable, Sendable {
    case automatic
    case off
    case manual
    case seconds30
    case minute1
    case minutes5
    case minutes15
    case minutes30
    case hour1

    public var key: String { "settings.cadence." + rawValue }

    public var cadence: Cadence {
        switch self {
        case .automatic: .push
        case .off: .off
        case .manual: .manual
        case .seconds30: .every(.seconds(30))
        case .minute1: .every(.seconds(60))
        case .minutes5: .every(.seconds(300))
        case .minutes15: .every(.seconds(900))
        case .minutes30: .every(.seconds(1800))
        case .hour1: .every(.seconds(3600))
        }
    }

    public static func offered(for capability: Capability) -> [CadenceChoice] {
        if capability == .mail { return [.automatic, .minute1, .minutes5, .minutes15, .minutes30, .hour1, .manual] }
        return allCases.filter { $0 != .automatic }
    }

    init?(_ cadence: Cadence) {
        guard let match = Self.allCases.first(where: { $0.cadence == cadence }) else { return nil }
        self = match
    }
}
