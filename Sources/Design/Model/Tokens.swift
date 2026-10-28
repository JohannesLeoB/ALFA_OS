public enum Tokens {
    public enum Size {
        public static let edge = 16.0
        public static let gutter = 12.0
        public static let blobHeight = 40.0
        public static let blobWidth = 56.0
        public static let blobAwakeWidth = 124.0
        public static let blobDockDistance = 36.0
        public static let foldedWidth = 56.0
        public static let foldThreshold = 112.0
        public static let middleMinimumWidth = 280.0
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
        public static let headPadRight = 8.0
        public static let headPadLeftList = 16.0
        public static let headPadLeftStack = 8.0
        public static let headGapList = 8.0
        public static let headGapStack = 4.0
        public static let menuEdge = 8.0
        public static let menuRowHeight = 28.0
        public static let menuRowPadding = 12.0
        public static let menuRowGap = 8.0
        public static let menuSeparatorInset = 12.0
        public static let menuSeparatorSpace = 4.0
        public static let assistantFieldHeight = 40.0
        public static let blobStretchMax = 0.16
        public static let blobWakeDistance = 212.0
        public static let laneMinimumLeft = 280.0
        public static let trailingTextInset = 12.0
        public static let hairline = 1.0
        public static let handleLength = 64.0
        public static let handleLengthActive = 96.0
        public static let handleThicknessActive = 2.0
        public static let fieldLabelWidth = 48.0
        public static let recipientListMaxHeight = 308.0
        public static let recipientInputMinWidth = 64.0
        public static let composeSheetMinHeight = 192.0
        public static let composeTextMinHeight = 120.0
        public static let composeColumnMinWidth = 96.0
        public static let settingsTileHeight = 112.0
        public static let settingsTileMinWidth = 112.0
        public static let toggleKnobOffsetOn = 14.0
        public static let toggleKnobOffsetOff = 2.0
        public static let selectionRingWidth = 2.0
        public static let overviewHoverLift = 3.0
        public static let menuReelPerspective = 600.0
        public static let orbGlowBlur = 2.4
        public static let blobLidOffset = 1.4
        public static let confirmEnterBlur = 3.0
        public static let blobDragThreshold = 3.0
        public static let blobFlingMinDistance = 48.0
        public static let blobEyeFollowDistance = 200.0
        public static let blobEyeFollowRamp = 40.0
        public static let blobEyeTravelX = 2.0
        public static let blobEyeTravelY = 1.6
        public static let blobHomeRadius = 200.0
        public static let blobLabelPadding = 22.0
        public static let blobMenuMinHeight = 160.0
        public static let laneSnap = 12.0
        public static let laneHysteresis = 64.0
        public static let breakpointStack = 440.0
        public static let breakpointFilterLabel = 340.0
        public static let breakpointAttachments = 560.0
        public static let breakpointNarrowCard = 480.0
        public static let breakpointSendLabel = 300.0
        public static let mailRowEstimate = 88.0
        public static let stripReserveTop = 24.0
        public static let stripReserveBottom = 96.0
        public static let stackFanStep = 52.0
        public static let overviewActionsOffset = 6.0
        public static let safeAreaTop = 32.0
        public static let tileLogoSize = 18.0
        public static let focusRingWidth = 2.0
        public static let focusRingOffset = 1.0
        public static let quoteBarWidth = 2.0
        public static let markSeparatorRing = 2.0
        public static let spinnerStroke = 1.5
        public static let tileHoverLift = 1.0
        public static let recipientLabelColumn = 40.0
        public static let recipientMarkColumn = 24.0
        public static let menuWidthStep = 56.0
        public static let menuMinWidth = 168.0
        public static let menuMaxWidth = 280.0
        public static let reelTopOffset = 8.0
        public static let accountFanWidth = 220.0
        public static let accountClosedWidth = 260.0
        public static let cardStateTextMaxWidth = 320.0
        public static let confirmPillWidth = 96.0
        public static let confirmPillOffset = 3.0
        public static let fieldLabelMinWidth = 96.0
        public static let signatureEditorMinHeight = 144.0
        public static let lockMarkSize = 56.0
        public static let lockFieldWidth = 240.0
        public static let imageTileStripe = 8.0
        public static let hintRadius = 7.0
        public static let stackDropOffset = 8.0
        public static let stackDropBlur = 16.0
        public static let stackDropSpread = -12.0
        public static let stackFlatDropOffset = 6.0
        public static let stackFlatDropBlur = 16.0
        public static let stackFlatDropSpread = -10.0
        public static let stackFlatFrontOffset = 8.0
        public static let stackFlatFrontBlur = 24.0
        public static let stackFlatFrontSpread = -12.0
        public static let overviewTileEnter = 10.0
        public static let mailLaneMaximumLeft = 280.0
        public static let previewWindowWidth = 1512.0
        public static let previewWindowHeight = 982.0
        public static let previewMinWidth = 640.0
        public static let previewMinHeight = 480.0
        public static let ghostShadowOffset = 8.0
        public static let ghostShadowBlur = 24.0
        public static let ghostShadowSpread = -12.0
        public static let envelopeStroke = 1.15
        public static let mailLaneMinimumLeft = 224.0
    }
    public enum Spacing {
        public static let step2 = 2.0
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
        public static let statusDot = 8.0
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
        public static let labelDelay = 0.08
        public static let reelStagger = 0.04
        public static let ebbDelay = 0.42
        public static let ebbSlow = 0.9
        public static let confirmHold = 1.0
        public static let confirmRelease = 0.18
        public static let menuReelTransform = 0.6
        public static let spinner = 0.8
        public static let orbOrbitFirst = 7.0
        public static let orbOrbitSecond = 9.0
        public static let orbOrbitThird = 11.0
        public static let blobBlinkClose = 0.14
        public static let blobBlinkInterval = 3.0
        public static let syncSpin = 2.0
        public static let menuReelDelay = 0.034
        public static let menuFocusDelay = 0.08
        public static let menuHoverDelay = 0.16
        public static let clickGuard = 0.05
        public static let toast = 1.8
        public static let searchFocusDelay = 0.04
        public static let confirmDoneDelay = 0.9
        public static let toastUndo = 4.0
        public static let scrollLineIn = 0.32
        public static let scrollLineRest = 0.42
        public static let scrollLineOut = 0.9
        public static let toastFail = 6.0
        public static let switchIn = 0.36
        public static let switchOut = 0.76
        public static let hintDwell = 3.0
        public static let deckClose = 0.38
        public static let switchLift = 0.62
        public static let deckOpen = 0.56
        public static let deckOpenStagger = 0.045
        public static let deckCloseStagger = 0.03
        public static let envelopeFirst = 0.42
        public static let envelopeSecond = 0.48
        public static let envelopeThird = 0.54
        public static let envelopeSecondDelayOpen = 0.04
        public static let envelopeThirdDelayOpen = 0.08
        public static let envelopeSecondDelayClose = 0.02
        public static let flapOpen = 0.52
        public static let flapOpenDelay = 0.12
        public static let flapClose = 0.26
        public static let switchFade = 0.42
        public static let switchGhostFade = 0.32
        public static let switchContentFade = 0.52
        public static let glassDelay = 0.04
    }
    public enum Easing {
        public static let standard = CubicBezier(x1: 0.2, y1: 0.8, x2: 0.2, y2: 1.0)
        public static let blobFlight = CubicBezier(x1: 0.2, y1: 1.15, x2: 0.3, y2: 1.0)
        public static let stack = CubicBezier(x1: 0.22, y1: 1.08, x2: 0.36, y2: 1.0)
        public static let fold = CubicBezier(x1: 0.65, y1: 0.0, x2: 0.25, y2: 1.0)
        public static let deckOpen = CubicBezier(x1: 0.3, y1: 1.32, x2: 0.5, y2: 1.0)
        public static let deckClose = CubicBezier(x1: 0.4, y1: 0.0, x2: 0.2, y2: 1.0)
        public static let envelopeSpring = CubicBezier(x1: 0.34, y1: 1.56, x2: 0.64, y2: 1.0)
        public static let glassIn = CubicBezier(x1: 0.37, y1: 0.0, x2: 0.63, y2: 1.0)
        public static let glassOut = CubicBezier(x1: 0.33, y1: 0.0, x2: 0.15, y2: 1.0)
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
        public static let semibold = 600
    }
    public enum LineHeight {
        public static let small = 16.0
        public static let notice = 20.0
        public static let body = 1.35
        public static let title = 1.25
        public static let mailBody = 1.6
        public static let counter = 1.0
        public static let control = 18.0
        public static let heading = 24.0
    }
    public enum Family {
        public static let text = ["Geist", "SF Pro Text", "system-ui"]
    }
    public enum Count {
        public static let stackMaxCards = 6
        public static let overviewLinesSmall = 3
        public static let overviewLinesMedium = 4
        public static let overviewLinesLarge = 8
        public static let contactSuggestions = 5
        public static let senderSuggestions = 8
        public static let attachmentsNarrow = 2
        public static let attachmentsWide = 3
        public static let stackHeads = 3
        public static let menuStaggerMax = 14
        public static let projectFilesMax = 8
        public static let chatDocumentByteLimit = 20000000
        public static let chatTextCharacterLimit = 120000
    }
    public enum Opacity {
        public static let ringOnColor = 0.3
        public static let ringOnMark = 0.22
        public static let cardMeta = 0.72
        public static let cardMetaDeep = 0.95
        public static let switchGlass = 0.72
        public static let disabled = 0.4
    }
    public enum Confirm {
        public static let eraseEdge = 0.2
        public static let eraseBlur = 0.6
        public static let shakeFrom = 0.7
        public static let shakeAmplitude = 1.5
        public static let shakeFrequency = 160.0
        public static let originDefault = 40.0
    }
    public enum Motion {
        public static let deceleration = 0.998
        public static let menuReelTilt = 60.0
        public static let blobFlingSpeed = 900.0
    }
    public enum Layer {
        public static let lane = 1
        public static let handle = 2
        public static let syncButton = 3
        public static let toast = 4
        public static let menu = 5
        public static let blob = 6
        public static let safeArea = 7
        public static let inLaneOverview = 2
        public static let inLaneToast = 3
        public static let switchGlass = 30
        public static let hint = 40
        public static let lockScreen = 40
    }
    public enum Tracking {
        public static let control = 0.01
        public static let mark = 0.06
        public static let title = -0.02
    }
    public enum Scale {
        public static let pressTile = 0.98
    }
    public enum Ratio {
        public static let imageTile = 1.3333
    }
    public enum TextStyle {
        public static let body = TypeStyle(size: TextSize.body, weight: Weight.regular, tracking: 0.0, lineHeight: LineHeight.body * TextSize.body)
        public static let bodyEmphasis = TypeStyle(size: TextSize.body, weight: Weight.medium, tracking: 0.0, lineHeight: LineHeight.body * TextSize.body)
        public static let caption = TypeStyle(size: TextSize.small, weight: Weight.regular, tracking: 0.0, lineHeight: LineHeight.small)
        public static let captionEmphasis = TypeStyle(size: TextSize.small, weight: Weight.medium, tracking: 0.0, lineHeight: LineHeight.small)
        public static let control = TypeStyle(size: TextSize.small, weight: Weight.medium, tracking: Tracking.control, lineHeight: LineHeight.small)
        public static let mark = TypeStyle(size: TextSize.small, weight: Weight.medium, tracking: Tracking.mark, lineHeight: LineHeight.counter * TextSize.small)
        public static let markSmall = TypeStyle(size: TextSize.blobFace, weight: Weight.medium, tracking: Tracking.mark, lineHeight: LineHeight.counter * TextSize.blobFace)
        public static let title = TypeStyle(size: TextSize.title, weight: Weight.medium, tracking: Tracking.title, lineHeight: LineHeight.title * TextSize.title)
        public static let mailBody = TypeStyle(size: TextSize.body, weight: Weight.regular, tracking: 0.0, lineHeight: LineHeight.mailBody * TextSize.body)
    }
    public enum Transition {
        public static let blobFlight = Timing(duration: Duration.blobFlight, delay: 0.0, easing: Easing.blobFlight)
        public static let stack = Timing(duration: Duration.stack, delay: 0.0, easing: Easing.stack)
        public static let fold = Timing(duration: Duration.fold, delay: 0.0, easing: Easing.fold)
        public static let deckClose = Timing(duration: Duration.deckClose, delay: 0.0, easing: Easing.deckClose)
        public static let deckOpen = Timing(duration: Duration.deckOpen, delay: 0.0, easing: Easing.deckOpen)
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

public struct TypeStyle: Sendable, Equatable {
    public let size: Double
    public let weight: Int
    public let tracking: Double
    public let lineHeight: Double
}

public struct Timing: Sendable, Equatable {
    public let duration: Double
    public let delay: Double
    public let easing: CubicBezier
}

public struct StackStep: Sendable, Equatable {
    public let surface: ColorValue
    public let ink: ColorValue
}

public extension Tokens {
    static let stackLight: [StackStep] = [StackStep(surface: ColorValue(0.9608, 0.9608, 0.9608, 1.0), ink: ColorValue(0.0902, 0.0902, 0.0902, 1.0)), StackStep(surface: ColorValue(0.9216, 0.9216, 0.9216, 1.0), ink: ColorValue(0.0902, 0.0902, 0.0902, 1.0)), StackStep(surface: ColorValue(0.851, 0.851, 0.851, 1.0), ink: ColorValue(0.0902, 0.0902, 0.0902, 1.0)), StackStep(surface: ColorValue(0.6392, 0.6392, 0.6392, 1.0), ink: ColorValue(0.0902, 0.0902, 0.0902, 1.0)), StackStep(surface: ColorValue(0.4196, 0.4196, 0.4196, 1.0), ink: ColorValue(1.0, 1.0, 1.0, 1.0))]
    static let stackDark: [StackStep] = [StackStep(surface: ColorValue(0.1216, 0.1216, 0.1216, 1.0), ink: ColorValue(0.9804, 0.9804, 0.9804, 1.0)), StackStep(surface: ColorValue(0.1804, 0.1804, 0.1804, 1.0), ink: ColorValue(0.9804, 0.9804, 0.9804, 1.0)), StackStep(surface: ColorValue(0.2275, 0.2275, 0.2275, 1.0), ink: ColorValue(0.9804, 0.9804, 0.9804, 1.0)), StackStep(surface: ColorValue(0.302, 0.302, 0.302, 1.0), ink: ColorValue(0.9804, 0.9804, 0.9804, 1.0)), StackStep(surface: ColorValue(0.4196, 0.4196, 0.4196, 1.0), ink: ColorValue(0.9804, 0.9804, 0.9804, 1.0))]
}
