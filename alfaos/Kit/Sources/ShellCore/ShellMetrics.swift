import Foundation

public struct ShellMetrics: Sendable, Decodable, Equatable {
    public let laneMin: Double
    public let laneMax: Double
    public let centerMin: Double
    public let blobWidth: Double
    public let blobThrow: Double
    public let shadowBlurFactor: Double
    public let assistantWidth: Double
    public let windowMinWidth: Double
    public let windowMinHeight: Double

    enum CodingKeys: String, CodingKey {
        case laneMin = "lane-min"
        case laneMax = "lane-max"
        case centerMin = "center-min"
        case blobWidth = "blob-width"
        case blobThrow = "blob-throw"
        case shadowBlurFactor = "shadow-blur-factor"
        case assistantWidth = "assistant-width"
        case windowMinWidth = "window-min-width"
        case windowMinHeight = "window-min-height"
    }

    public init(laneMin: Double, laneMax: Double, centerMin: Double, blobWidth: Double, blobThrow: Double, shadowBlurFactor: Double, assistantWidth: Double, windowMinWidth: Double, windowMinHeight: Double) {
        self.laneMin = laneMin
        self.laneMax = laneMax
        self.centerMin = centerMin
        self.blobWidth = blobWidth
        self.blobThrow = blobThrow
        self.shadowBlurFactor = shadowBlurFactor
        self.assistantWidth = assistantWidth
        self.windowMinWidth = windowMinWidth
        self.windowMinHeight = windowMinHeight
    }

    public init(data: Data) throws {
        self = try JSONDecoder().decode(ShellMetrics.self, from: data)
    }
}

public struct ShellGeometry: Sendable, Equatable {
    public let margin: Double
    public let gap: Double
    public let strip: Double
    public let laneHeader: Double
    public let laneRest: Double
    public let laneFolded: Double
    public let foldAt: Double
    public let laneMin: Double
    public let laneMax: Double
    public let centerMin: Double
    public let blobWidth: Double
    public let blobAwakeWidth: Double
    public let blobHeight: Double
    public let blobThrow: Double
    public let menuWidth: Double
    public let menuGap: Double
    public let shadowBlurFactor: Double
    public let assistantWidth: Double
    public let windowMin: Size

    public init(theme: TokenTheme, metrics: ShellMetrics) {
        margin = theme.length(.layoutWindowMargin)
        gap = theme.length(.layoutRegionGap)
        strip = theme.length(.componentBlobBarHeight)
        laneHeader = theme.length(.componentLaneHeaderHeight)
        laneRest = theme.length(.componentLaneRestingWidth)
        laneFolded = theme.length(.componentLaneCollapsedWidth)
        foldAt = theme.length(.componentLaneCollapseThreshold)
        laneMin = metrics.laneMin
        laneMax = metrics.laneMax
        centerMin = metrics.centerMin
        blobWidth = metrics.blobWidth
        blobAwakeWidth = theme.length(.componentBlobAwakeWidth)
        blobHeight = theme.length(.componentBlobHeight)
        blobThrow = metrics.blobThrow
        menuWidth = theme.length(.componentMenuWidth)
        menuGap = theme.length(.spaceS)
        shadowBlurFactor = metrics.shadowBlurFactor
        assistantWidth = metrics.assistantWidth
        windowMin = Size(width: metrics.windowMinWidth, height: metrics.windowMinHeight)
    }
}
