public struct Shadows: Sendable, Equatable {
    public let lane: [ShadowLayer]
    public let knob: [ShadowLayer]
    public let segment: [ShadowLayer]
    public let floating: [ShadowLayer]
}

public extension Shadows {
    static let light = Shadows(lane: [ShadowLayer(inset: false, x: 0.0, y: 0.0, blur: 0.0, spread: 1.0, color: ColorValue(0.9098, 0.9098, 0.9098, 1.0))], knob: [ShadowLayer(inset: false, x: 0.0, y: 1.0, blur: 2.0, spread: 0.0, color: ColorValue(0.0, 0.0, 0.0, 0.2))], segment: [ShadowLayer(inset: false, x: 0.0, y: 1.0, blur: 2.0, spread: 0.0, color: ColorValue(0.0, 0.0, 0.0, 0.12))], floating: [ShadowLayer(inset: false, x: 0.0, y: 0.0, blur: 0.0, spread: 1.0, color: ColorValue(0.0, 0.0, 0.0, 0.08)), ShadowLayer(inset: false, x: 0.0, y: 8.0, blur: 24.0, spread: 0.0, color: ColorValue(0.0, 0.0, 0.0, 0.1))])
    static let dark = Shadows(lane: [ShadowLayer(inset: false, x: 0.0, y: 0.0, blur: 0.0, spread: 1.0, color: ColorValue(0.1647, 0.1647, 0.1647, 1.0))], knob: [ShadowLayer(inset: false, x: 0.0, y: 1.0, blur: 2.0, spread: 0.0, color: ColorValue(0.0, 0.0, 0.0, 0.2))], segment: [ShadowLayer(inset: false, x: 0.0, y: 1.0, blur: 2.0, spread: 0.0, color: ColorValue(0.0, 0.0, 0.0, 0.12))], floating: [ShadowLayer(inset: false, x: 0.0, y: 0.0, blur: 0.0, spread: 1.0, color: ColorValue(1.0, 1.0, 1.0, 0.1)), ShadowLayer(inset: false, x: 0.0, y: 8.0, blur: 24.0, spread: 0.0, color: ColorValue(0.0, 0.0, 0.0, 0.5))])
    static let overviewHoverLight: [ShadowLayer] = [ShadowLayer(inset: false, x: 0.0, y: 14.0, blur: 28.0, spread: -18.0, color: ColorValue(0.0, 0.0, 0.0, 0.4))]
}
