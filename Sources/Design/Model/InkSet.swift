public struct InkSet {
    public let primary: KeyPath<Colors, ColorValue>
    public let secondary: KeyPath<Colors, ColorValue>
    public let tertiary: KeyPath<Colors, ColorValue>
    public let line: KeyPath<Colors, ColorValue>

    public static var lane: InkSet { InkSet(primary: \.ink, secondary: \.inkSecondary, tertiary: \.inkTertiary, line: \.lineStrong) }
    public static var inverse: InkSet { InkSet(primary: \.onInverse, secondary: \.onInverseSecondary, tertiary: \.onInverseTertiary, line: \.onInverseLine) }

    public static func of(_ inverted: Bool) -> InkSet { inverted ? .inverse : .lane }
}
