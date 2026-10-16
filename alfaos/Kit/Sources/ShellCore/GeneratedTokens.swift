// tokens.json version 1 sha256 cbf6897891cdbf69dee89c2f99b9e8236cec6e3728875fd85045326dc9d21500

public extension ThemeKey {
    static let colorBackgroundContainer = ThemeKey("color-background-container")
    static let paletteGray400 = ThemeKey("palette-gray-400")
    static let shadowFloating = ThemeKey("shadow-floating")
    static let spaceXxs = ThemeKey("space-xxs")
    static let spaceXs = ThemeKey("space-xs")
    static let spaceS = ThemeKey("space-s")
    static let spaceM = ThemeKey("space-m")
    static let spaceL = ThemeKey("space-l")
    static let componentLaneRadius = ThemeKey("component-lane-radius")
    static let componentLaneHandleRadius = ThemeKey("component-lane-handle-radius")
    static let componentLaneHeaderHeight = ThemeKey("component-lane-header-height")
    static let componentLaneFoldedWidth = ThemeKey("component-lane-folded-width")
    static let componentLaneRestingWidth = ThemeKey("component-lane-resting-width")
    static let componentLaneLeadingMaxWidth = ThemeKey("component-lane-leading-max-width")
    static let componentLaneFoldThreshold = ThemeKey("component-lane-fold-threshold")
    static let componentLaneHandleWidth = ThemeKey("component-lane-handle-width")
    static let componentLaneHandleThickness = ThemeKey("component-lane-handle-thickness")
    static let componentLaneHandleLength = ThemeKey("component-lane-handle-length")
    static let componentLaneHandleLengthActive = ThemeKey("component-lane-handle-length-active")
    static let componentBlobBarHeight = ThemeKey("component-blob-bar-height")
    static let componentBlobHeight = ThemeKey("component-blob-height")
    static let componentBlobAwakeWidth = ThemeKey("component-blob-awake-width")
    static let componentLaneEdge = ThemeKey("component-lane-edge")
    static let componentLaneGap = ThemeKey("component-lane-gap")
    static let sizeControlS = ThemeKey("size-control-s")
    static let sizeControlM = ThemeKey("size-control-m")
    static let componentMenuWidth = ThemeKey("component-menu-width")
    static let componentMenuRowHeight = ThemeKey("component-menu-row-height")
    static let componentMenuPadding = ThemeKey("component-menu-padding")
    static let componentFieldHeight = ThemeKey("component-field-height")
    static let componentFieldCompactHeight = ThemeKey("component-field-compact-height")
    static let layoutReadingMaxWidth = ThemeKey("layout-reading-max-width")
    static let motionDurationChange = ThemeKey("motion-duration-change")
    static let motionDurationSnap = ThemeKey("motion-duration-snap")
    static let motionDurationStack = ThemeKey("motion-duration-stack")
    static let motionCurveStandard = ThemeKey("motion-curve-standard")
    static let strokeHairline = ThemeKey("stroke-hairline")
    static let strokeRing = ThemeKey("stroke-ring")
    static let fontSans = ThemeKey("font-sans")
    static let fontDisplay = ThemeKey("font-display")
    static let fontMono = ThemeKey("font-mono")

    static let all: [ThemeKey] = [
        colorBackgroundContainer,
        paletteGray400,
        shadowFloating,
        spaceXxs,
        spaceXs,
        spaceS,
        spaceM,
        spaceL,
        componentLaneRadius,
        componentLaneHandleRadius,
        componentLaneHeaderHeight,
        componentLaneFoldedWidth,
        componentLaneRestingWidth,
        componentLaneLeadingMaxWidth,
        componentLaneFoldThreshold,
        componentLaneHandleWidth,
        componentLaneHandleThickness,
        componentLaneHandleLength,
        componentLaneHandleLengthActive,
        componentBlobBarHeight,
        componentBlobHeight,
        componentBlobAwakeWidth,
        componentLaneEdge,
        componentLaneGap,
        sizeControlS,
        sizeControlM,
        componentMenuWidth,
        componentMenuRowHeight,
        componentMenuPadding,
        componentFieldHeight,
        componentFieldCompactHeight,
        layoutReadingMaxWidth,
        motionDurationChange,
        motionDurationSnap,
        motionDurationStack,
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
    public static let adoptedAt = "2026-10-16T14:27"
    public static let state = "Hülle: Ruhebreite 280. 80 ungenutzte Tokens in die Quarantäne (quarantine.json). Verbleibend sind die Tokens, die der Code noch liest; die Werte der Ansichten kommen aus design.json."
}
