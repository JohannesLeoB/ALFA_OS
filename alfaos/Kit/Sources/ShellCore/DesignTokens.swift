// design.json sha256 3fa6287aead9a14dc74cf899618ba1bcaa457d9ae6432cfc92c0a2a6ebf8994f

public enum Design {
    public enum Size {
        public static let edge = 16.0
        public static let gutter = 12.0
        public static let blobHeight = 40.0
        public static let blobWidth = 56.0
        public static let blobAwakeWidth = 124.0
        public static let blobDockDistance = 36.0
        public static let foldedWidth = 56.0
        public static let foldThreshold = 112.0
        public static let middleMinimumWidth = 480.0
        public static let headerHeight = 44.0
        public static let rowHeight = 36.0
        public static let symbolSize = 28.0
        public static let cardInset = 0.0
        public static let laneRestWidth = 280.0
        public static let laneMinimumRight = 280.0
        public static let blobPopupFallbackWidth = 280.0
        public static let footerHeight = 44.0
        public static let blobEyeWidth = 4.0
        public static let blobEyeHeight = 8.0
        public static let blobEyeGap = 4.0
        public static let suggestionRowHeight = 44.0
        public static let chipHeight = 24.0
        public static let overviewTileHeightSmall = 144.0
        public static let overviewTileHeightMedium = 176.0
        public static let overviewTileHeightLarge = 248.0
        public static let overviewTileMinWidthSmall = 200.0
        public static let overviewTileMinWidthMedium = 232.0
        public static let overviewTileMinWidthLarge = 320.0
    }
    public enum Spacing {
        public static let step4 = 4.0
        public static let step8 = 8.0
        public static let step12 = 12.0
        public static let step16 = 16.0
        public static let step20 = 20.0
        public static let step24 = 24.0
        public static let step28 = 28.0
        public static let step32 = 32.0
        public static let step36 = 36.0
        public static let step40 = 40.0
        public static let step44 = 44.0
        public static let step56 = 56.0
        public static let statusDot = 6.0
        public static let blobInset = 6.0
    }
    public enum Radius {
        public static let lane = 20.0
        public static let blob = 20.0
        public static let contextMenu = 16.0
        public static let card = 20.0
        public static let row = 12.0
        public static let notice = 8.0
        public static let field = 4.0
        public static let stroke = 2.0
        public static let capsule = 999.0
        public static let cardBottom = 0.0
    }
    public enum Duration {
        public static let hover = 0.16
        public static let short = 0.15
        public static let toggle = 0.2
        public static let chevron = 0.24
        public static let lane = 0.26
        public static let recipientList = 0.28
        public static let blobEyes = 0.32
        public static let stackBackground = 0.32
        public static let rowSequence = 0.36
        public static let blobFlight = 0.416
        public static let stackLift = 0.42
        public static let stack = 0.52
        public static let searchUnderline = 0.48
        public static let fold = 0.72
        public static let thinking = 1.0
        public static let pulse = 1.8
        public static let blink = 1.7
        public static let blobWidth = 0.24
        public static let overviewDelay = 0.3
        public static let overviewEnter = 0.64
        public static let overviewStagger = 0.06
        public static let tileHover = 0.32
        public static let tileActions = 0.24
    }
    public enum Easing {
        public static let standard = CubicBezier(x1: 0.2, y1: 0.8, x2: 0.2, y2: 1.0)
        public static let blobFlight = CubicBezier(x1: 0.2, y1: 1.15, x2: 0.3, y2: 1.0)
        public static let stack = CubicBezier(x1: 0.22, y1: 1.08, x2: 0.36, y2: 1.0)
        public static let fold = CubicBezier(x1: 0.65, y1: 0.0, x2: 0.25, y2: 1.0)
    }
    public enum TextSize {
        public static let small = 11.5
        public static let body = 13.0
        public static let title = 18.0
        public static let blobFace = 9.0
    }
    public enum Weight {
        public static let light = 300
        public static let regular = 400
        public static let medium = 500
    }
    public enum LineHeight {
        public static let small = 16.0
        public static let notice = 20.0
        public static let body = 1.35
        public static let title = 1.25
        public static let mailBody = 1.6
        public static let counter = 1.0
    }
    public enum Component {
        public static let laneRadius = Radius.lane
        public static let laneEdge = Size.edge
        public static let laneGap = Size.gutter
        public static let laneHeaderHeight = Size.headerHeight
        public static let laneFoldedWidth = Size.foldedWidth
        public static let laneFoldThreshold = Size.foldThreshold
        public static let laneMiddleMinimumWidth = Size.middleMinimumWidth
        public static let rowHeight = Size.rowHeight
        public static let rowRadius = Radius.row
        public static let symbolSize = Size.symbolSize
        public static let blobHeight = Size.blobHeight
        public static let blobWidth = Size.blobWidth
        public static let blobAwakeWidth = Size.blobAwakeWidth
        public static let blobDockDistance = Size.blobDockDistance
        public static let blobRadius = Radius.blob
        public static let menuRadius = Radius.contextMenu
        public static let cardRadius = Radius.card
        public static let cardInset = Size.cardInset
        public static let noticeRadius = Radius.notice
        public static let fieldRadius = Radius.field
        public static let capsuleRadius = Radius.capsule
        public static let laneRestWidth = Size.laneRestWidth
        public static let laneMinimumRightWidth = Size.laneMinimumRight
        public static let blobPopupFallbackWidth = Size.blobPopupFallbackWidth
        public static let cardFooterHeight = Size.footerHeight
        public static let cardRadiusBottom = Radius.cardBottom
        public static let blobEyeWidth = Size.blobEyeWidth
        public static let blobEyeHeight = Size.blobEyeHeight
        public static let blobEyeGap = Size.blobEyeGap
        public static let suggestionRowHeight = Size.suggestionRowHeight
        public static let chipHeight = Size.chipHeight
        public static let overviewTileHeightMedium = Size.overviewTileHeightMedium
        public static let overviewTileMinWidthMedium = Size.overviewTileMinWidthMedium
    }
}

public struct DesignColors: Sendable, Equatable {
    public let ground: RGB
    public let line: RGB
    public let lineStrong: RGB
    public let ink: RGB
    public let inkSecondary: RGB
    public let inkTertiary: RGB
    public let mark: RGB
    public let well: RGB
    public let hover: RGB
    public let selection: RGB
    public let focus: RGB
    public let handle: RGB
    public let inverse: RGB
    public let onInverse: RGB
    public let inverseHot: RGB
    public let inverseLine: RGB
    public let inverseField: RGB
    public let safeArea: RGB
    public let menu: RGB
    public let signal: RGB
    public let sheet: RGB
    public let sheetInk: RGB
    public let sheetInkSecondary: RGB
    public let sheetInkTertiary: RGB
    public let sheetLine: RGB
    public let glaze: RGB
    public let sheetWell: RGB
    public let sheetLineStrong: RGB
    public let onSignal: RGB
    public let onInverseSecondary: RGB
    public let onInverseTertiary: RGB
    public let onInverseLine: RGB
    public let orb: RGB
    public let orbRim: RGB
    public let orbGloss: RGB
}

public extension DesignColors {
    static let light = DesignColors(ground: RGB(1.0, 1.0, 1.0, 1.0), line: RGB(0.9098, 0.9098, 0.9098, 1.0), lineStrong: RGB(0.851, 0.851, 0.851, 1.0), ink: RGB(0.0902, 0.0902, 0.0902, 1.0), inkSecondary: RGB(0.302, 0.302, 0.302, 1.0), inkTertiary: RGB(0.4196, 0.4196, 0.4196, 1.0), mark: RGB(0.5412, 0.5412, 0.5412, 1.0), well: RGB(0.9608, 0.9608, 0.9608, 1.0), hover: RGB(0.0, 0.0, 0.0, 0.05), selection: RGB(0.0, 0.0, 0.0, 0.05), focus: RGB(0.4196, 0.4196, 0.4196, 1.0), handle: RGB(0.6392, 0.6392, 0.6392, 1.0), inverse: RGB(0.0902, 0.0902, 0.0902, 1.0), onInverse: RGB(1.0, 1.0, 1.0, 1.0), inverseHot: RGB(1.0, 1.0, 1.0, 0.12), inverseLine: RGB(1.0, 1.0, 1.0, 0.2), inverseField: RGB(1.0, 1.0, 1.0, 0.08), safeArea: RGB(0.0, 0.0, 0.0, 1.0), menu: RGB(1.0, 1.0, 1.0, 1.0), signal: RGB(0.702, 0.2549, 0.1804, 1.0), sheet: RGB(1.0, 1.0, 1.0, 1.0), sheetInk: RGB(0.0902, 0.0902, 0.0902, 1.0), sheetInkSecondary: RGB(0.302, 0.302, 0.302, 1.0), sheetInkTertiary: RGB(0.4196, 0.4196, 0.4196, 1.0), sheetLine: RGB(0.9098, 0.9098, 0.9098, 1.0), glaze: RGB(1.0, 1.0, 1.0, 0.75), sheetWell: RGB(0.9608, 0.9608, 0.9608, 1.0), sheetLineStrong: RGB(0.851, 0.851, 0.851, 1.0), onSignal: RGB(1.0, 1.0, 1.0, 1.0), onInverseSecondary: RGB(1.0, 1.0, 1.0, 0.8), onInverseTertiary: RGB(1.0, 1.0, 1.0, 0.6), onInverseLine: RGB(1.0, 1.0, 1.0, 0.3), orb: RGB(0.051, 0.051, 0.051, 1.0), orbRim: RGB(1.0, 1.0, 1.0, 0.12), orbGloss: RGB(1.0, 1.0, 1.0, 0.28))
    static let dark = DesignColors(ground: RGB(0.051, 0.051, 0.051, 1.0), line: RGB(0.1647, 0.1647, 0.1647, 1.0), lineStrong: RGB(0.2275, 0.2275, 0.2275, 1.0), ink: RGB(0.9804, 0.9804, 0.9804, 1.0), inkSecondary: RGB(0.851, 0.851, 0.851, 1.0), inkTertiary: RGB(0.6392, 0.6392, 0.6392, 1.0), mark: RGB(0.5412, 0.5412, 0.5412, 1.0), well: RGB(0.1216, 0.1216, 0.1216, 1.0), hover: RGB(1.0, 1.0, 1.0, 0.08), selection: RGB(1.0, 1.0, 1.0, 0.08), focus: RGB(0.6392, 0.6392, 0.6392, 1.0), handle: RGB(0.4196, 0.4196, 0.4196, 1.0), inverse: RGB(0.9608, 0.9608, 0.9608, 1.0), onInverse: RGB(0.051, 0.051, 0.051, 1.0), inverseHot: RGB(0.0, 0.0, 0.0, 0.08), inverseLine: RGB(0.0, 0.0, 0.0, 0.14), inverseField: RGB(0.0, 0.0, 0.0, 0.05), safeArea: RGB(0.0, 0.0, 0.0, 1.0), menu: RGB(0.1216, 0.1216, 0.1216, 1.0), signal: RGB(0.8784, 0.5412, 0.4549, 1.0), sheet: RGB(1.0, 1.0, 1.0, 1.0), sheetInk: RGB(0.0902, 0.0902, 0.0902, 1.0), sheetInkSecondary: RGB(0.302, 0.302, 0.302, 1.0), sheetInkTertiary: RGB(0.4196, 0.4196, 0.4196, 1.0), sheetLine: RGB(0.9098, 0.9098, 0.9098, 1.0), glaze: RGB(1.0, 1.0, 1.0, 0.07), sheetWell: RGB(0.9608, 0.9608, 0.9608, 1.0), sheetLineStrong: RGB(0.851, 0.851, 0.851, 1.0), onSignal: RGB(1.0, 1.0, 1.0, 1.0), onInverseSecondary: RGB(0.0, 0.0, 0.0, 0.72), onInverseTertiary: RGB(0.0, 0.0, 0.0, 0.55), onInverseLine: RGB(0.0, 0.0, 0.0, 0.22), orb: RGB(0.051, 0.051, 0.051, 1.0), orbRim: RGB(1.0, 1.0, 1.0, 0.12), orbGloss: RGB(1.0, 1.0, 1.0, 0.28))
    static let lightGray = DesignColors(ground: RGB(0.949, 0.949, 0.949, 1.0), line: RGB(0.9098, 0.9098, 0.9098, 1.0), lineStrong: RGB(0.851, 0.851, 0.851, 1.0), ink: RGB(0.0902, 0.0902, 0.0902, 1.0), inkSecondary: RGB(0.302, 0.302, 0.302, 1.0), inkTertiary: RGB(0.4196, 0.4196, 0.4196, 1.0), mark: RGB(0.5412, 0.5412, 0.5412, 1.0), well: RGB(0.9608, 0.9608, 0.9608, 1.0), hover: RGB(0.0, 0.0, 0.0, 0.05), selection: RGB(0.0, 0.0, 0.0, 0.05), focus: RGB(0.4196, 0.4196, 0.4196, 1.0), handle: RGB(0.6392, 0.6392, 0.6392, 1.0), inverse: RGB(0.0902, 0.0902, 0.0902, 1.0), onInverse: RGB(1.0, 1.0, 1.0, 1.0), inverseHot: RGB(1.0, 1.0, 1.0, 0.12), inverseLine: RGB(1.0, 1.0, 1.0, 0.2), inverseField: RGB(1.0, 1.0, 1.0, 0.08), safeArea: RGB(0.0, 0.0, 0.0, 1.0), menu: RGB(1.0, 1.0, 1.0, 1.0), signal: RGB(0.702, 0.2549, 0.1804, 1.0), sheet: RGB(1.0, 1.0, 1.0, 1.0), sheetInk: RGB(0.0902, 0.0902, 0.0902, 1.0), sheetInkSecondary: RGB(0.302, 0.302, 0.302, 1.0), sheetInkTertiary: RGB(0.4196, 0.4196, 0.4196, 1.0), sheetLine: RGB(0.9098, 0.9098, 0.9098, 1.0), glaze: RGB(1.0, 1.0, 1.0, 0.75), sheetWell: RGB(0.9608, 0.9608, 0.9608, 1.0), sheetLineStrong: RGB(0.851, 0.851, 0.851, 1.0), onSignal: RGB(1.0, 1.0, 1.0, 1.0), onInverseSecondary: RGB(1.0, 1.0, 1.0, 0.8), onInverseTertiary: RGB(1.0, 1.0, 1.0, 0.6), onInverseLine: RGB(1.0, 1.0, 1.0, 0.3), orb: RGB(0.051, 0.051, 0.051, 1.0), orbRim: RGB(1.0, 1.0, 1.0, 0.12), orbGloss: RGB(1.0, 1.0, 1.0, 0.28))
}

public struct DesignShadows: Sendable, Equatable {
    public let lane: [ShadowLayer]
    public let knob: [ShadowLayer]
    public let segment: [ShadowLayer]
    public let floating: [ShadowLayer]
}

public extension DesignShadows {
    static let light = DesignShadows(lane: [ShadowLayer(inset: false, x: 0.0, y: 0.0, blur: 0.0, spread: 1.0, color: RGB(0.9098, 0.9098, 0.9098, 1.0))], knob: [ShadowLayer(inset: false, x: 0.0, y: 1.0, blur: 2.0, spread: 0.0, color: RGB(0.0, 0.0, 0.0, 0.2))], segment: [ShadowLayer(inset: false, x: 0.0, y: 1.0, blur: 2.0, spread: 0.0, color: RGB(0.0, 0.0, 0.0, 0.12))], floating: [ShadowLayer(inset: false, x: 0.0, y: 0.0, blur: 0.0, spread: 1.0, color: RGB(0.0, 0.0, 0.0, 0.08)), ShadowLayer(inset: false, x: 0.0, y: 8.0, blur: 24.0, spread: 0.0, color: RGB(0.0, 0.0, 0.0, 0.1))])
    static let dark = DesignShadows(lane: [ShadowLayer(inset: false, x: 0.0, y: 0.0, blur: 0.0, spread: 1.0, color: RGB(0.1647, 0.1647, 0.1647, 1.0))], knob: [ShadowLayer(inset: false, x: 0.0, y: 1.0, blur: 2.0, spread: 0.0, color: RGB(0.0, 0.0, 0.0, 0.2))], segment: [ShadowLayer(inset: false, x: 0.0, y: 1.0, blur: 2.0, spread: 0.0, color: RGB(0.0, 0.0, 0.0, 0.12))], floating: [ShadowLayer(inset: false, x: 0.0, y: 0.0, blur: 0.0, spread: 1.0, color: RGB(1.0, 1.0, 1.0, 0.1)), ShadowLayer(inset: false, x: 0.0, y: 8.0, blur: 24.0, spread: 0.0, color: RGB(0.0, 0.0, 0.0, 0.5))])
}

public struct DesignStackStep: Sendable, Equatable {
    public let surface: RGB
    public let ink: RGB
}

public extension Design {
    static let stackLight: [DesignStackStep] = [DesignStackStep(surface: RGB(0.9608, 0.9608, 0.9608, 1.0), ink: RGB(0.0902, 0.0902, 0.0902, 1.0)), DesignStackStep(surface: RGB(0.9216, 0.9216, 0.9216, 1.0), ink: RGB(0.0902, 0.0902, 0.0902, 1.0)), DesignStackStep(surface: RGB(0.851, 0.851, 0.851, 1.0), ink: RGB(0.0902, 0.0902, 0.0902, 1.0)), DesignStackStep(surface: RGB(0.6392, 0.6392, 0.6392, 1.0), ink: RGB(0.0902, 0.0902, 0.0902, 1.0)), DesignStackStep(surface: RGB(0.4196, 0.4196, 0.4196, 1.0), ink: RGB(1.0, 1.0, 1.0, 1.0))]
    static let stackDark: [DesignStackStep] = [DesignStackStep(surface: RGB(0.1216, 0.1216, 0.1216, 1.0), ink: RGB(0.9804, 0.9804, 0.9804, 1.0)), DesignStackStep(surface: RGB(0.1804, 0.1804, 0.1804, 1.0), ink: RGB(0.9804, 0.9804, 0.9804, 1.0)), DesignStackStep(surface: RGB(0.2275, 0.2275, 0.2275, 1.0), ink: RGB(0.9804, 0.9804, 0.9804, 1.0)), DesignStackStep(surface: RGB(0.302, 0.302, 0.302, 1.0), ink: RGB(0.9804, 0.9804, 0.9804, 1.0)), DesignStackStep(surface: RGB(0.4196, 0.4196, 0.4196, 1.0), ink: RGB(0.9804, 0.9804, 0.9804, 1.0))]
}

public enum DesignStamp {
    public static let delivery = "Arbeitswelt ALFA Interface Zugang (13).zip, sha256 6c3a927e1b5bae51eee3f12e03fb196c1ddd35ce5ed59fb16eec67d7904d3e4f, Datei TOKENBOGEN.json"
    public static let deliveredAt = "2026-10-16T02:05"
    public static let adoptedAt = "2026-10-16T13:29"
    public static let state = "Maße, Radien, Abstände, Bewegung, Schrift, Farben, Schatten und Kartenstapel erzeugt; Oberflächen (Lack, Glas) und Verbrauch im Code offen."
}
