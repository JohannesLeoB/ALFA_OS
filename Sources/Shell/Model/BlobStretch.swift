import Design
import Foundation

public struct PointerSample: Equatable, Sendable {
    public let point: BlobPoint
    public let time: Double

    public init(point: BlobPoint, time: Double) {
        self.point = point
        self.time = time
    }
}

public struct BlobStretch: Equatable, Sendable {
    public let angle: Double
    public let amount: Double

    public static let none = BlobStretch(angle: 0, amount: 0)

    init(angle: Double, amount: Double) {
        self.angle = angle
        self.amount = amount
    }

    public init(history: [PointerSample]) {
        let pair = history.suffix(2)
        guard pair.count == 2, let a = pair.first, let b = pair.last else {
            self = .none
            return
        }
        let span = max(ShellValues.pointerStep, b.time - a.time)
        let vx = (b.point.x - a.point.x) / span
        let vy = (b.point.y - a.point.y) / span
        angle = atan2(vy, vx)
        amount = min(Tokens.Size.blobStretchMax, hypot(vx, vy) * ShellValues.stretchPerSpeed)
    }
}
