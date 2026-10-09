/// The size of the page of a code card. The page has a fixed width and is scaled to the frame of the card.
public enum CodeCardLayout {
    /// The width of a page when the card does not name one.
    public static let defaultPageWidth = 1280.0

    /// The page width in points. nil and 0 use the default width.
    public static func pageWidth(previewWidth: Double?) -> Double {
        guard let previewWidth, previewWidth > 0 else { return defaultPageWidth }
        return previewWidth
    }

    /// The factor that fits a page of `pageWidth` into a frame of `frameWidth`.
    public static func scale(frameWidth: Double, pageWidth: Double) -> Double {
        guard pageWidth > 0 else { return 1 }
        return frameWidth / pageWidth
    }
}
