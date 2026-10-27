public struct Moods: Sendable, Equatable {
    public let coral: ColorValue
    public let apricot: ColorValue
    public let rose: ColorValue
}

public extension Moods {
    static let light = Moods(coral: ColorValue(0.9765, 0.3608, 0.2941, 1.0), apricot: ColorValue(0.9529, 0.6235, 0.3529, 1.0), rose: ColorValue(0.9098, 0.7373, 0.7255, 1.0))
    static let dark = Moods(coral: ColorValue(0.9765, 0.3608, 0.2941, 1.0), apricot: ColorValue(0.9529, 0.6235, 0.3529, 1.0), rose: ColorValue(0.9098, 0.7373, 0.7255, 1.0))
}
