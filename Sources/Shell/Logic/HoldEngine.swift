import Design
import Foundation

public struct EraseStop: Equatable, Sendable {
    public let opacity: Double
    public let location: Double
}

public struct HoldEngine: Equatable, Sendable {
    let from: Double
    public let forward: Bool
    let start: Date

    public init(from: Double, forward: Bool, start: Date) {
        self.from = from
        self.forward = forward
        self.start = start
    }

    public var length: Double {
        forward ? Tokens.Duration.confirmHold * (1 - from) : Tokens.Duration.confirmRelease * from
    }

    public func fill(at date: Date) -> Double {
        let k = length <= 0 ? 1 : min(1, max(0, date.timeIntervalSince(start) / length))
        return forward ? from + (1 - from) * k : from - from * k
    }

    public static func eraseStops(fill: Double) -> [EraseStop] {
        guard fill > 0 else { return [EraseStop(opacity: 1, location: 0), EraseStop(opacity: 1, location: 1)] }
        let edge = Tokens.Confirm.eraseEdge
        let low = fill * (1 + edge) - edge
        let high = fill * (1 + edge)
        func alpha(_ x: Double) -> Double { min(1, max(0, (x - low) / edge)) }
        let a = min(1, max(0, low))
        let b = min(1, max(0, high))
        return [
            EraseStop(opacity: alpha(0), location: 0),
            EraseStop(opacity: alpha(a), location: a),
            EraseStop(opacity: alpha(b), location: b),
            EraseStop(opacity: alpha(1), location: 1)
        ]
    }

    public static func shake(fill: Double) -> Double {
        let start = Tokens.Confirm.shakeFrom
        guard fill > start else { return 0 }
        return sin(fill * Tokens.Confirm.shakeFrequency) * Tokens.Confirm.shakeAmplitude * (fill - start) / (1 - start)
    }
}
