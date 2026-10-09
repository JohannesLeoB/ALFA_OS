import Foundation

/// The words printed on the sheet. The app takes them from the string catalog; tests pass their own.
public struct SheetLabels: Sendable {
    /// Heading of the colour legend.
    public var legend: String
    /// Title of the page for items that no frame holds.
    public var freeSheet: String
    /// Page number. Two integers: the page and the page count.
    public var pageOf: String
    /// Colours that do not fit into the legend. One integer.
    public var moreColours: String
    /// Text in place of an image whose bytes are missing.
    public var image: String

    public init(legend: String, freeSheet: String, pageOf: String, moreColours: String, image: String) {
        self.legend = legend
        self.freeSheet = freeSheet
        self.pageOf = pageOf
        self.moreColours = moreColours
        self.image = image
    }

    /// The words of the string catalog, in the language of the Mac.
    public static var localized: SheetLabels {
        SheetLabels(legend: String(localized: "sheet.legend"),
                    freeSheet: String(localized: "sheet.freeSheet"),
                    pageOf: String(localized: "sheet.pageOf"),
                    moreColours: String(localized: "sheet.moreColours"),
                    image: String(localized: "sheet.image"))
    }
}
