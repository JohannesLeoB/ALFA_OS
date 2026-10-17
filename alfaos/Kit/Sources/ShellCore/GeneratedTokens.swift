public extension ThemeKey {
    static let colorBackgroundContainer = ThemeKey("color-background-container")
    static let paletteGray400 = ThemeKey("palette-gray-400")
    static let spaceXxs = ThemeKey("space-xxs")
    static let spaceXs = ThemeKey("space-xs")
    static let spaceS = ThemeKey("space-s")
    static let spaceM = ThemeKey("space-m")
    static let spaceL = ThemeKey("space-l")
    static let componentLaneRadius = ThemeKey("component-lane-radius")
    static let componentLaneHandleRadius = ThemeKey("component-lane-handle-radius")
    static let componentLaneHeaderHeight = ThemeKey("component-lane-header-height")
    static let componentLaneHandleWidth = ThemeKey("component-lane-handle-width")
    static let componentLaneHandleThickness = ThemeKey("component-lane-handle-thickness")
    static let componentLaneHandleLength = ThemeKey("component-lane-handle-length")
    static let componentLaneHandleLengthActive = ThemeKey("component-lane-handle-length-active")
    static let componentBlobHeight = ThemeKey("component-blob-height")
    static let componentLaneEdge = ThemeKey("component-lane-edge")
    static let sizeControlS = ThemeKey("size-control-s")
    static let sizeControlM = ThemeKey("size-control-m")
    static let componentMenuWidth = ThemeKey("component-menu-width")
    static let componentMenuRowHeight = ThemeKey("component-menu-row-height")
    static let componentMenuPadding = ThemeKey("component-menu-padding")
    static let componentFieldHeight = ThemeKey("component-field-height")
    static let componentFieldCompactHeight = ThemeKey("component-field-compact-height")
    static let layoutReadingMaxWidth = ThemeKey("layout-reading-max-width")
    static let motionCurveStandard = ThemeKey("motion-curve-standard")
    static let strokeHairline = ThemeKey("stroke-hairline")
    static let strokeRing = ThemeKey("stroke-ring")
    static let fontSans = ThemeKey("font-sans")
    static let fontDisplay = ThemeKey("font-display")
    static let fontMono = ThemeKey("font-mono")

    static let all: [ThemeKey] = [
        colorBackgroundContainer,
        paletteGray400,
        spaceXxs,
        spaceXs,
        spaceS,
        spaceM,
        spaceL,
        componentLaneRadius,
        componentLaneHandleRadius,
        componentLaneHeaderHeight,
        componentLaneHandleWidth,
        componentLaneHandleThickness,
        componentLaneHandleLength,
        componentLaneHandleLengthActive,
        componentBlobHeight,
        componentLaneEdge,
        sizeControlS,
        sizeControlM,
        componentMenuWidth,
        componentMenuRowHeight,
        componentMenuPadding,
        componentFieldHeight,
        componentFieldCompactHeight,
        layoutReadingMaxWidth,
        motionCurveStandard,
        strokeHairline,
        strokeRing,
        fontSans,
        fontDisplay,
        fontMono,
    ]
}

public extension TextKey {
    static let areaTitle = TextKey("area-title")
    static let readingTitle = TextKey("reading-title")
    static let body = TextKey("body")
    static let callout = TextKey("callout")
    static let name = TextKey("name")
    static let listPreview = TextKey("list-preview")
    static let caption = TextKey("caption")
    static let textButton = TextKey("text-button")
    static let monoDetail = TextKey("mono-detail")
    static let cardMark = TextKey("card-mark")
    static let mark = TextKey("mark")

    static let all: [TextKey] = [
        areaTitle,
        readingTitle,
        body,
        callout,
        name,
        listPreview,
        caption,
        textButton,
        monoDetail,
        cardMark,
        mark,
    ]
}

public enum TokenStamp {
    public static let delivery = "Arbeitswelt ALFA Interface Zugang (13).zip, sha256 6c3a927e1b5bae51eee3f12e03fb196c1ddd35ce5ed59fb16eec67d7904d3e4f"
    public static let deliveredAt = "2026-10-16T02:05"
    public static let adoptedAt = "2026-10-16T16:42"
    public static let state = "Legacy token sheet. The delivered sheet design.json is the source; unused tokens are in quarantine.json."
    public static let content = "d16ec19d93e7e5cca28a5d933e03124a7c8e0cbad0efb1ea7ae1280603fe61b1"
}
