import Design

public struct Measure: Sendable, Equatable {
    public let margin: Double
    public let gap: Double
    public let strip: Double
    public let blobTop: Double
    let laneRest: Double
    public let laneFolded: Double
    public let foldAt: Double
    public let minimum: [Double]
    public let blobWidth: Double
    public let blobHeight: Double
    let blobDock: Double
    let menuWidth: Double
    public let windowMin: BlobSize

    public init() {
        margin = Tokens.Size.edge
        gap = Tokens.Size.gutter
        blobTop = Tokens.Size.edge
        strip = Tokens.Size.edge + Tokens.Size.blobHeight + Tokens.Size.gutter
        laneRest = Tokens.Size.laneRestWidth
        laneFolded = Tokens.Size.foldedWidth
        foldAt = Tokens.Size.foldThreshold
        minimum = [Tokens.Size.laneMinimumLeft, Tokens.Size.middleMinimumWidth, Tokens.Size.laneMinimumRight]
        blobWidth = Tokens.Size.blobWidth
        blobHeight = Tokens.Size.blobHeight
        blobDock = Tokens.Size.blobDockDistance
        menuWidth = Tokens.Size.blobPopupFallbackWidth
        windowMin = Self.windowMin(margin: Tokens.Size.edge, gap: Tokens.Size.gutter, minimum: minimum, screen: ShellValues.previewScreen)
    }

    public func windowMin(screen: BlobSize) -> BlobSize {
        Self.windowMin(margin: margin, gap: gap, minimum: minimum, screen: screen)
    }

    public func laneHeight(_ window: BlobSize) -> Double {
        window.height - strip - margin
    }

    private static func windowMin(margin: Double, gap: Double, minimum: [Double], screen: BlobSize) -> BlobSize {
        let width = 2 * margin + 2 * gap + minimum.reduce(0, +)
        guard screen.width > 0, screen.height > 0 else { return BlobSize(width: width, height: width) }
        return BlobSize(width: width, height: (width * screen.height / screen.width).rounded(.up))
    }
}
