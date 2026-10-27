public struct Colors: Sendable, Equatable {
    public let ground: ColorValue
    public let line: ColorValue
    public let lineStrong: ColorValue
    public let ink: ColorValue
    public let inkSecondary: ColorValue
    public let inkTertiary: ColorValue
    public let mark: ColorValue
    public let well: ColorValue
    public let hover: ColorValue
    public let selection: ColorValue
    public let focus: ColorValue
    public let handle: ColorValue
    public let inverse: ColorValue
    public let onInverse: ColorValue
    public let inverseHot: ColorValue
    public let inverseLine: ColorValue
    public let inverseField: ColorValue
    public let safeArea: ColorValue
    public let menu: ColorValue
    public let signal: ColorValue
    public let sheet: ColorValue
    public let sheetInk: ColorValue
    public let sheetInkSecondary: ColorValue
    public let sheetInkTertiary: ColorValue
    public let sheetLine: ColorValue
    public let glaze: ColorValue
    public let sheetWell: ColorValue
    public let sheetLineStrong: ColorValue
    public let onSignal: ColorValue
    public let onInverseSecondary: ColorValue
    public let onInverseTertiary: ColorValue
    public let onInverseLine: ColorValue
    public let orb: ColorValue
    public let orbRim: ColorValue
    public let orbGloss: ColorValue
    public let lane: ColorValue
    public let stackGlossFront: ColorValue
    public let stackGlossLight: ColorValue
    public let stackGlossDark: ColorValue
    public let stackSeamFront: ColorValue
    public let stackSeamBack: ColorValue
    public let stackDrop: ColorValue
    public let stackRing: ColorValue
    public let stackFlatDrop: ColorValue
    public let stackFlatFront: ColorValue
    public let dhlYellow: ColorValue
}

public extension Colors {
    static let light = Colors(ground: ColorValue(1.0, 1.0, 1.0, 1.0), line: ColorValue(0.9098, 0.9098, 0.9098, 1.0), lineStrong: ColorValue(0.851, 0.851, 0.851, 1.0), ink: ColorValue(0.0902, 0.0902, 0.0902, 1.0), inkSecondary: ColorValue(0.302, 0.302, 0.302, 1.0), inkTertiary: ColorValue(0.4196, 0.4196, 0.4196, 1.0), mark: ColorValue(0.5412, 0.5412, 0.5412, 1.0), well: ColorValue(0.9608, 0.9608, 0.9608, 1.0), hover: ColorValue(0.0, 0.0, 0.0, 0.05), selection: ColorValue(0.0, 0.0, 0.0, 0.05), focus: ColorValue(0.4196, 0.4196, 0.4196, 1.0), handle: ColorValue(0.6392, 0.6392, 0.6392, 1.0), inverse: ColorValue(0.0902, 0.0902, 0.0902, 1.0), onInverse: ColorValue(1.0, 1.0, 1.0, 1.0), inverseHot: ColorValue(1.0, 1.0, 1.0, 0.12), inverseLine: ColorValue(1.0, 1.0, 1.0, 0.2), inverseField: ColorValue(1.0, 1.0, 1.0, 0.08), safeArea: ColorValue(0.0, 0.0, 0.0, 1.0), menu: ColorValue(1.0, 1.0, 1.0, 1.0), signal: ColorValue(0.702, 0.2549, 0.1804, 1.0), sheet: ColorValue(1.0, 1.0, 1.0, 1.0), sheetInk: ColorValue(0.0902, 0.0902, 0.0902, 1.0), sheetInkSecondary: ColorValue(0.302, 0.302, 0.302, 1.0), sheetInkTertiary: ColorValue(0.4196, 0.4196, 0.4196, 1.0), sheetLine: ColorValue(0.9098, 0.9098, 0.9098, 1.0), glaze: ColorValue(1.0, 1.0, 1.0, 0.75), sheetWell: ColorValue(0.9608, 0.9608, 0.9608, 1.0), sheetLineStrong: ColorValue(0.851, 0.851, 0.851, 1.0), onSignal: ColorValue(1.0, 1.0, 1.0, 1.0), onInverseSecondary: ColorValue(1.0, 1.0, 1.0, 0.8), onInverseTertiary: ColorValue(1.0, 1.0, 1.0, 0.6), onInverseLine: ColorValue(1.0, 1.0, 1.0, 0.3), orb: ColorValue(0.051, 0.051, 0.051, 1.0), orbRim: ColorValue(1.0, 1.0, 1.0, 0.12), orbGloss: ColorValue(1.0, 1.0, 1.0, 0.28), lane: ColorValue(1.0, 1.0, 1.0, 1.0), stackGlossFront: ColorValue(1.0, 1.0, 1.0, 1.0), stackGlossLight: ColorValue(1.0, 1.0, 1.0, 0.9), stackGlossDark: ColorValue(1.0, 1.0, 1.0, 0.22), stackSeamFront: ColorValue(0.0, 0.0, 0.0, 0.14), stackSeamBack: ColorValue(0.0, 0.0, 0.0, 0.2), stackDrop: ColorValue(0.0, 0.0, 0.0, 0.16), stackRing: ColorValue(0.0, 0.0, 0.0, 0.06), stackFlatDrop: ColorValue(0.0, 0.0, 0.0, 0.18), stackFlatFront: ColorValue(0.0, 0.0, 0.0, 0.22), dhlYellow: ColorValue(1.0, 0.7961, 0.0039, 1.0))
    static let dark = Colors(ground: ColorValue(0.051, 0.051, 0.051, 1.0), line: ColorValue(0.1647, 0.1647, 0.1647, 1.0), lineStrong: ColorValue(0.2275, 0.2275, 0.2275, 1.0), ink: ColorValue(0.9804, 0.9804, 0.9804, 1.0), inkSecondary: ColorValue(0.851, 0.851, 0.851, 1.0), inkTertiary: ColorValue(0.6392, 0.6392, 0.6392, 1.0), mark: ColorValue(0.5412, 0.5412, 0.5412, 1.0), well: ColorValue(0.1216, 0.1216, 0.1216, 1.0), hover: ColorValue(1.0, 1.0, 1.0, 0.08), selection: ColorValue(1.0, 1.0, 1.0, 0.08), focus: ColorValue(0.6392, 0.6392, 0.6392, 1.0), handle: ColorValue(0.4196, 0.4196, 0.4196, 1.0), inverse: ColorValue(0.9608, 0.9608, 0.9608, 1.0), onInverse: ColorValue(0.051, 0.051, 0.051, 1.0), inverseHot: ColorValue(0.0, 0.0, 0.0, 0.08), inverseLine: ColorValue(0.0, 0.0, 0.0, 0.14), inverseField: ColorValue(0.0, 0.0, 0.0, 0.05), safeArea: ColorValue(0.0, 0.0, 0.0, 1.0), menu: ColorValue(0.1216, 0.1216, 0.1216, 1.0), signal: ColorValue(0.8784, 0.5412, 0.4549, 1.0), sheet: ColorValue(1.0, 1.0, 1.0, 1.0), sheetInk: ColorValue(0.0902, 0.0902, 0.0902, 1.0), sheetInkSecondary: ColorValue(0.302, 0.302, 0.302, 1.0), sheetInkTertiary: ColorValue(0.4196, 0.4196, 0.4196, 1.0), sheetLine: ColorValue(0.9098, 0.9098, 0.9098, 1.0), glaze: ColorValue(1.0, 1.0, 1.0, 0.07), sheetWell: ColorValue(0.9608, 0.9608, 0.9608, 1.0), sheetLineStrong: ColorValue(0.851, 0.851, 0.851, 1.0), onSignal: ColorValue(0.050980392156862744, 0.050980392156862744, 0.050980392156862744, 1.0), onInverseSecondary: ColorValue(0.0, 0.0, 0.0, 0.72), onInverseTertiary: ColorValue(0.0, 0.0, 0.0, 0.55), onInverseLine: ColorValue(0.0, 0.0, 0.0, 0.22), orb: ColorValue(0.051, 0.051, 0.051, 1.0), orbRim: ColorValue(1.0, 1.0, 1.0, 0.12), orbGloss: ColorValue(1.0, 1.0, 1.0, 0.28), lane: ColorValue(0.0784, 0.0784, 0.0784, 1.0), stackGlossFront: ColorValue(1.0, 1.0, 1.0, 0.14), stackGlossLight: ColorValue(1.0, 1.0, 1.0, 0.9), stackGlossDark: ColorValue(1.0, 1.0, 1.0, 0.22), stackSeamFront: ColorValue(0.0, 0.0, 0.0, 0.7), stackSeamBack: ColorValue(0.0, 0.0, 0.0, 0.7), stackDrop: ColorValue(0.0, 0.0, 0.0, 0.55), stackRing: ColorValue(0.0, 0.0, 0.0, 0.06), stackFlatDrop: ColorValue(0.0, 0.0, 0.0, 0.18), stackFlatFront: ColorValue(0.0, 0.0, 0.0, 0.22), dhlYellow: ColorValue(1.0, 0.7961, 0.0039, 1.0))
    static let lightGray = Colors(ground: ColorValue(0.949, 0.949, 0.949, 1.0), line: ColorValue(0.9098, 0.9098, 0.9098, 1.0), lineStrong: ColorValue(0.851, 0.851, 0.851, 1.0), ink: ColorValue(0.0902, 0.0902, 0.0902, 1.0), inkSecondary: ColorValue(0.302, 0.302, 0.302, 1.0), inkTertiary: ColorValue(0.4196, 0.4196, 0.4196, 1.0), mark: ColorValue(0.5412, 0.5412, 0.5412, 1.0), well: ColorValue(0.9608, 0.9608, 0.9608, 1.0), hover: ColorValue(0.0, 0.0, 0.0, 0.05), selection: ColorValue(0.0, 0.0, 0.0, 0.05), focus: ColorValue(0.4196, 0.4196, 0.4196, 1.0), handle: ColorValue(0.6392, 0.6392, 0.6392, 1.0), inverse: ColorValue(0.0902, 0.0902, 0.0902, 1.0), onInverse: ColorValue(1.0, 1.0, 1.0, 1.0), inverseHot: ColorValue(1.0, 1.0, 1.0, 0.12), inverseLine: ColorValue(1.0, 1.0, 1.0, 0.2), inverseField: ColorValue(1.0, 1.0, 1.0, 0.08), safeArea: ColorValue(0.0, 0.0, 0.0, 1.0), menu: ColorValue(1.0, 1.0, 1.0, 1.0), signal: ColorValue(0.702, 0.2549, 0.1804, 1.0), sheet: ColorValue(1.0, 1.0, 1.0, 1.0), sheetInk: ColorValue(0.0902, 0.0902, 0.0902, 1.0), sheetInkSecondary: ColorValue(0.302, 0.302, 0.302, 1.0), sheetInkTertiary: ColorValue(0.4196, 0.4196, 0.4196, 1.0), sheetLine: ColorValue(0.9098, 0.9098, 0.9098, 1.0), glaze: ColorValue(1.0, 1.0, 1.0, 0.75), sheetWell: ColorValue(0.9608, 0.9608, 0.9608, 1.0), sheetLineStrong: ColorValue(0.851, 0.851, 0.851, 1.0), onSignal: ColorValue(1.0, 1.0, 1.0, 1.0), onInverseSecondary: ColorValue(1.0, 1.0, 1.0, 0.8), onInverseTertiary: ColorValue(1.0, 1.0, 1.0, 0.6), onInverseLine: ColorValue(1.0, 1.0, 1.0, 0.3), orb: ColorValue(0.051, 0.051, 0.051, 1.0), orbRim: ColorValue(1.0, 1.0, 1.0, 0.12), orbGloss: ColorValue(1.0, 1.0, 1.0, 0.28), lane: ColorValue(1.0, 1.0, 1.0, 1.0), stackGlossFront: ColorValue(1.0, 1.0, 1.0, 1.0), stackGlossLight: ColorValue(1.0, 1.0, 1.0, 0.9), stackGlossDark: ColorValue(1.0, 1.0, 1.0, 0.22), stackSeamFront: ColorValue(0.0, 0.0, 0.0, 0.14), stackSeamBack: ColorValue(0.0, 0.0, 0.0, 0.2), stackDrop: ColorValue(0.0, 0.0, 0.0, 0.16), stackRing: ColorValue(0.0, 0.0, 0.0, 0.06), stackFlatDrop: ColorValue(0.0, 0.0, 0.0, 0.18), stackFlatFront: ColorValue(0.0, 0.0, 0.0, 0.22), dhlYellow: ColorValue(1.0, 0.7961, 0.0039, 1.0))
}
