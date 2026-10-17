import Foundation

public enum ShellMeasure: String, CaseIterable, Sendable {
    case laneHeaderPaddingEnd = "lane-header-padding-end"
    case menuFieldPadding = "menu-field-padding"
    case menuGroupPadding = "menu-group-padding"
    case menuRowPaddingStart = "menu-row-padding-start"
    case menuRowPaddingEnd = "menu-row-padding-end"
}

public struct ShellMetrics: Sendable, Decodable, Equatable {
    public let minimum: [Double]
    public let blobWidth: Double
    public let blobThrow: Double
    public let shadowBlurFactor: Double
    public let assistantWidth: Double
    public let windowMinWidth: Double
    public let windowMinHeight: Double
    private let measures: [ShellMeasure: Double]

    public func measure(_ key: ShellMeasure) -> Double { measures[key, default: 0] }

    enum CodingKeys: String, CodingKey {
        case minimum
        case blobWidth = "blob-width"
        case blobThrow = "blob-throw"
        case shadowBlurFactor = "shadow-blur-factor"
        case assistantWidth = "assistant-width"
        case windowMinWidth = "window-min-width"
        case windowMinHeight = "window-min-height"
        case measures
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        minimum = try container.decode([Double].self, forKey: .minimum)
        blobWidth = try container.decode(Double.self, forKey: .blobWidth)
        blobThrow = try container.decode(Double.self, forKey: .blobThrow)
        shadowBlurFactor = try container.decode(Double.self, forKey: .shadowBlurFactor)
        assistantWidth = try container.decode(Double.self, forKey: .assistantWidth)
        windowMinWidth = try container.decode(Double.self, forKey: .windowMinWidth)
        windowMinHeight = try container.decode(Double.self, forKey: .windowMinHeight)
        let raw = try container.decode([String: Double].self, forKey: .measures)
        var values: [ShellMeasure: Double] = [:]
        for key in ShellMeasure.allCases {
            guard let value = raw[key.rawValue] else {
                throw DecodingError.keyNotFound(
                    DynamicKey(key.rawValue),
                    DecodingError.Context(codingPath: container.codingPath + [CodingKeys.measures], debugDescription: key.rawValue))
            }
            values[key] = value
        }
        measures = values
    }

    public init(data: Data) throws {
        self = try JSONDecoder().decode(ShellMetrics.self, from: data)
    }
}

private struct DynamicKey: CodingKey {
    let stringValue: String
    let intValue: Int? = nil

    init(_ value: String) { stringValue = value }
    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { return nil }
}

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
    public let blobThrow: Double
    public let menuWidth: Double
    public let menuGap: Double
    public let shadowBlurFactor: Double
    public let assistantWidth: Double
    public let windowMin: Size

    public init(theme: TokenTheme, metrics: ShellMetrics) {
        margin = Design.Size.edge
        gap = Design.Size.gutter
        blobTop = Design.Size.edge
        strip = Design.Size.edge + Design.Size.blobHeight + Design.Size.gutter
        laneHeader = Design.Size.headerHeight
        laneRest = Design.Size.laneRestWidth
        laneFolded = Design.Size.foldedWidth
        foldAt = Design.Size.foldThreshold
        minimum = metrics.minimum
        blobWidth = Design.Size.blobWidth
        blobAwakeWidth = Design.Size.blobAwakeWidth
        blobHeight = Design.Size.blobHeight
        blobThrow = metrics.blobThrow
        menuWidth = theme.length(.componentMenuWidth)
        menuGap = theme.length(.spaceS)
        shadowBlurFactor = metrics.shadowBlurFactor
        assistantWidth = metrics.assistantWidth
        windowMin = Size(width: metrics.windowMinWidth, height: metrics.windowMinHeight)
    }
}
