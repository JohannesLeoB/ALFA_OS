import Foundation

public protocol LaserMeasuring: Sendable {
    var status: AsyncStream<LaserVerbindungsStatus> { get }

    var letztesMass: AsyncStream<Double> { get }
    func verbinde() async throws
    func trenne() async
}

public enum LaserVerbindungsStatus: Equatable, Sendable {
    case getrennt
    case sucht
    case gekoppelt(geraetename: String)
    case error(String)
}
