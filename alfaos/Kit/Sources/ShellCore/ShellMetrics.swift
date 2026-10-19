import Foundation

public struct ShellGeometry: Sendable, Equatable {
    public let margin: Double
    public let gap: Double
    public let strip: Double
    public let blobTop: Double
    public let laneHeader: Double
    public let laneRest: Double
    public let laneFolded: Double
    public let foldAt: Double
    public let minimum: [Double]
    public let blobWidth: Double
    public let blobAwakeWidth: Double
    public let blobHeight: Double
    public let blobDock: Double
    public let menuWidth: Double
    public let assistantWidth: Double
    public let windowMin: Size

    public init() {
        margin = Design.Size.edge
        gap = Design.Size.gutter
        blobTop = Design.Size.edge
        strip = Design.Size.edge + Design.Size.blobHeight + Design.Size.gutter
        laneHeader = Design.Size.headerHeight
        laneRest = Design.Size.laneRestWidth
        laneFolded = Design.Size.foldedWidth
        foldAt = Design.Size.foldThreshold
        minimum = [Design.Size.laneMinimumLeft, Design.Size.middleMinimumWidth, Design.Size.laneMinimumRight]
        blobWidth = Design.Size.blobWidth
        blobAwakeWidth = Design.Size.blobAwakeWidth
        blobHeight = Design.Size.blobHeight
        blobDock = Design.Size.blobDockDistance
        menuWidth = Design.Size.blobPopupFallbackWidth
        assistantWidth = Design.Size.blobPopupFallbackWidth
        windowMin = ShellGeometry.windowMin(margin: margin, gap: gap, minimum: minimum, screen: SheetValues.previewScreen)
    }

    public func windowMin(screen: Size) -> Size {
        ShellGeometry.windowMin(margin: margin, gap: gap, minimum: minimum, screen: screen)
    }

    private static func windowMin(margin: Double, gap: Double, minimum: [Double], screen: Size) -> Size {
        let width = 2 * margin + 2 * gap + minimum.reduce(0, +)
        guard screen.width > 0, screen.height > 0 else { return Size(width: width, height: width) }
        return Size(width: width, height: (width * screen.height / screen.width).rounded(.up))
    }

    public func laneHeight(_ window: Size) -> Double {
        window.height - strip - margin
    }
}
