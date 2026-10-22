import Foundation

struct Dial: Sendable {
    let low: Double
    let high: Double
    let step: Double

    func clamp(_ v: Double) -> Double {
        min(high, max(low, (v / step).rounded() * step))
    }

    func share(_ v: Double) -> Double {
        high > low ? (v - low) / (high - low) : 0
    }
}

enum Proto {
    static let grid = 10.0
    static let gridMajor = 50.0
    static let deskPadding = 48.0
    static let zoomMin = 0.25
    static let zoomMax = 4.0
    static let zoomStep = 1.25
    static let perspectiveDistance = 4.5
    static let snap = 6.0
    static let minCell = 40.0
    static let customerShare = 0.64
    static let stepsRatio = 1.6
    static let glyph = 14.0
    static let chevron = 12.0
    static let emptyWidth = 300.0
    static let assistantWidth = 340.0
    static let tileHeight = 56.0
    static let disabled = 0.4
    static let hidden = 0.45
    static let busy = 0.6
    static let underlay = 0.35
    static let underlaySide = 2400
    static let pressed = 0.88
    static let azimuth = Dial(low: 0, high: 355, step: 5)
    static let elevation = Dial(low: 0, high: 90, step: 5)
    static let edge = Dial(low: 0, high: 1, step: 0.02)
    static let outline = Dial(low: 0, high: 2, step: 0.05)
    static let shadow = Dial(low: 0, high: 60, step: 2)
    static let pose = Dial(low: 0, high: 1, step: 0.02)
    static let glideSteps = 8
    static let photoWidth = 1600
    static let photoHeight = 1000
    static let photoBackdrop = true
    static let photoMargin = 0.1
    static let tile = Dial(low: 50, high: 2000, step: 50)
    static let roughness = Dial(low: 0, high: 1, step: 0.05)
    static let previewDPI = 80.0
    static let liveRounds = 40
    static let liveTokens = 150_000
    static let moveRows = 4.0
    static let voiceLines = 4
}
