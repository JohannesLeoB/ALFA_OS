/// The zoom of the preview: fit the frame, or show the page at a fixed factor.
public enum LabZoom: String, CaseIterable, Sendable {
    case fit, half, actual, double

    /// The factor of a fixed zoom. nil for fit.
    public var factor: Double? {
        switch self {
        case .fit: nil
        case .half: 0.5
        case .actual: 1
        case .double: 2
        }
    }
}

/// The geometry of the preview: the widths it offers and the factor and width that a page is shown with.
public enum LabStage {
    /// The widths the preview offers in points. 0 fills the frame.
    public static let widths: [Double] = [0, 390, 768, 1280, 1440]

    /// The factor of the page in the frame. Fit shrinks a wider page to the frame and never enlarges it.
    public static func scale(zoom: LabZoom, pageWidth: Double, frameWidth: Double) -> Double {
        if let factor = zoom.factor { return factor }
        guard pageWidth > 0 else { return 1 }
        return min(1, frameWidth / pageWidth)
    }

    /// The width of the page in points. A width of 0 fills the frame at the zoom.
    public static func pageWidth(width: Double, zoom: LabZoom, frameWidth: Double) -> Double {
        if width > 0 { return width }
        return (frameWidth / (zoom.factor ?? 1)).rounded()
    }
}

/// The guides over the preview: an 8-point grid and reference sizes for a button, a touch target, text and a line.
public enum LabGuides {
    public static let gridStep = 8.0
    /// The height of a button.
    public static let button = 28.0
    /// The side of a touch target.
    public static let touchTarget = 44.0
    /// The size of body text.
    public static let text = 13.0
    /// The length of the reference line.
    public static let line = 100.0
}
